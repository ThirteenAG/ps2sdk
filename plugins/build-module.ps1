[CmdletBinding()]
param(
    [string]$Project,
    [string[]]$Sources = @(),
    [string]$Output,
    [string[]]$Defines = @(),
    [string[]]$IncludeDirectories = @(),
    [string[]]$LinkOptions = @(),
    [switch]$NoRuntime,
    [switch]$Clean
)
$ErrorActionPreference = 'Stop'
$sdkRoot = Split-Path -Parent $PSScriptRoot
$compilerDirectory = Join-Path $sdkRoot 'ee/bin'
$gcc = Join-Path $compilerDirectory 'mips64r5900el-ps2-elf-gcc.exe'
$gxx = Join-Path $compilerDirectory 'mips64r5900el-ps2-elf-g++.exe'
if (!(Test-Path -LiteralPath $gcc)) { throw "EE compiler missing: $gcc" }
if ($Project) {
    $projectPath = (Resolve-Path -LiteralPath $Project).Path
    $projectDirectory = Split-Path -Parent $projectPath
    $config = Get-Content -LiteralPath $projectPath -Raw | ConvertFrom-Json
    $Sources = @($config.sources | ForEach-Object { [IO.Path]::GetFullPath((Join-Path $projectDirectory $_)) })
    $Output = [IO.Path]::GetFullPath((Join-Path $projectDirectory $config.output))
    $Defines += @($config.defines)
    $IncludeDirectories += @($config.includes | ForEach-Object { [IO.Path]::GetFullPath((Join-Path $projectDirectory $_)) })
    $LinkOptions += @($config.link_options)
}
if (!$Sources.Count -or !$Output) { throw 'Supply a module.json project or Sources and Output.' }
$LinkOptions = @($LinkOptions | Where-Object { $_ })
$outputPath = [IO.Path]::GetFullPath($Output)
if ([IO.Path]::GetExtension($outputPath) -ne '.elf') { throw 'Module output must be an .elf file.' }
$objectDirectory = $outputPath + '.objects'
if ($Clean) {
    # All removals are bounded to the explicitly selected output and its sibling
    # object directory; never invoke another shell for filesystem operations.
    if ([IO.Path]::GetFullPath($objectDirectory) -ne $outputPath + '.objects') { throw 'Invalid object directory' }
    Remove-Item -LiteralPath $objectDirectory -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $outputPath, ($outputPath + '.map'), ($outputPath + '.tmp'), ($outputPath + '.map.tmp') -Force -ErrorAction SilentlyContinue
    return
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outputPath), $objectDirectory | Out-Null
$originalPath = $env:PATH
try {
    $env:PATH = $compilerDirectory + ';' + $env:PATH
    # The previous SDK make rules used EE_OPTFLAGS=-O2 (the projects' CFLAGS
    # variable was not consumed). Keep that effective optimization level.
    $flags = @('-O2', '-G0', '-Wall', '-gdwarf-2', '-D_EE', '-fno-common', '-fno-pic', '-mno-abicalls',
        '-fshort-wchar', '-mno-check-zero-division', '-fpack-struct=16',
        '-fno-strict-aliasing', '-fno-stack-protector', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables',
        ('-I' + $PSScriptRoot), ('-I' + (Join-Path $sdkRoot 'ps2sdk/ee/include')),
        ('-I' + (Join-Path $sdkRoot 'ps2sdk/common/include')))
    $targetOptions = & $gcc '-Q' '--help=target' 2>&1 | Out-String
    if ($targetOptions -match 'mpreferred-stack-boundary') { $flags += '-mpreferred-stack-boundary=4' }
    foreach ($include in $IncludeDirectories) { if ($include) { $flags += '-I' + [IO.Path]::GetFullPath($include) } }
    foreach ($define in $Defines) { if ($define) { $flags += '-D' + $define } }
    $hasCpp = @($Sources | Where-Object { [IO.Path]::GetExtension($_) -in @('.cpp', '.cc', '.cxx') }).Count -gt 0
    if (!$NoRuntime) {
        $Sources += Join-Path $PSScriptRoot 'module-runtime.c'
        if ($hasCpp) { $Sources += Join-Path $PSScriptRoot 'module-runtime.cpp' }
    }
    $objects = @()
    $index = 0
    foreach ($source in $Sources) {
        $sourcePath = (Resolve-Path -LiteralPath $source).Path
        $extension = [IO.Path]::GetExtension($sourcePath)
        $compiler = $gcc
        $compileFlags = $flags
        # GCC can fold malloc+memset into calloc. These are the allocator's
        # own definitions, so that substitution would recursively call itself.
        if ($sourcePath -eq (Join-Path $PSScriptRoot 'module-runtime.c')) { $compileFlags += '-fno-builtin' }
        if ($extension -in @('.cpp', '.cc', '.cxx')) {
            $compiler = $gxx
            $compileFlags += @('-std=gnu++17', '-fno-exceptions', '-fno-rtti', '-fno-threadsafe-statics')
        } elseif ($extension -notin @('.c', '.s', '.S')) { throw "Unsupported module source: $sourcePath" }
        $object = Join-Path $objectDirectory ($index.ToString() + '-' + [IO.Path]::GetFileNameWithoutExtension($sourcePath) + '.o')
        # Forward slashes survive both PowerShell's Windows argument quoting
        # and the toolchain driver's subprocess quoting, including spaces.
        $compileFlags = @($compileFlags | ForEach-Object { $_.Replace('\', '/') })
        & $compiler @compileFlags '-c' ($sourcePath.Replace('\', '/')) '-o' ($object.Replace('\', '/'))
        if ($LASTEXITCODE) { throw "Compilation failed: $sourcePath" }
        $objects += $object
        ++$index
    }
    $linkFlags = @('-nostdlib', '-G0', '-mno-abicalls', '-fno-pic', '-r', '-Wl,-d',
        ('-Wl,-Map,' + $outputPath + '.map.tmp'), '-Wl,--no-relax', ('-L' + (Join-Path $sdkRoot 'ps2sdk/ee/lib')))
    if (!$NoRuntime) { $linkFlags += '-Wl,-T,' + (Join-Path $PSScriptRoot 'module.ld') }
    $libraries = @('-Wl,--start-group')
    if ($hasCpp) { $libraries += '-lstdc++' }
    $libraries += @('-lm', '-lc', '-lcglue', '-lkernel', '-lgcc', '-Wl,--end-group')
    $temporaryOutput = $outputPath + '.tmp'
    $linkFlags = @($linkFlags | ForEach-Object { $_.Replace('\', '/') })
    $objects = @($objects | ForEach-Object { $_.Replace('\', '/') })
    & $gcc @linkFlags @objects @LinkOptions @libraries '-o' ($temporaryOutput.Replace('\', '/'))
    if ($LASTEXITCODE) { throw 'Relocatable module link failed.' }
    # -r permits undefined symbols; reject them before replacing a good module.
    $elf = [IO.File]::ReadAllBytes($temporaryOutput)
    if ($elf.Length -lt 52 -or [BitConverter]::ToUInt16($elf, 16) -ne 1) { throw 'Expected ET_REL module.' }
    $sectionTable = [BitConverter]::ToUInt32($elf, 32)
    $sectionCount = [BitConverter]::ToUInt16($elf, 48)
    for ($i = 0; $i -lt $sectionCount; ++$i) {
        $at = $sectionTable + $i * 40
        if ([BitConverter]::ToUInt32($elf, $at + 4) -ne 2) { continue }
        $start = [BitConverter]::ToUInt32($elf, $at + 16)
        $size = [BitConverter]::ToUInt32($elf, $at + 20)
        $stringsIndex = [BitConverter]::ToUInt32($elf, $at + 24)
        $strings = [BitConverter]::ToUInt32($elf, $sectionTable + $stringsIndex * 40 + 16)
        $undefined = @()
        for ($symbol = $start + 16; $symbol -lt $start + $size; $symbol += 16) {
            if ([BitConverter]::ToUInt16($elf, $symbol + 14) -ne 0 -or ($elf[$symbol + 12] -shr 4) -eq 2) { continue }
            $nameStart = $strings + [BitConverter]::ToUInt32($elf, $symbol)
            $nameEnd = $nameStart
            while ($elf[$nameEnd]) { ++$nameEnd }
            $undefined += [Text.Encoding]::UTF8.GetString($elf, $nameStart, $nameEnd - $nameStart)
        }
        if ($undefined.Count) { throw ('Unresolved module runtime symbols: ' + ($undefined -join ', ')) }
    }
    Move-Item -LiteralPath $temporaryOutput -Destination $outputPath -Force
    Move-Item -LiteralPath ($outputPath + '.map.tmp') -Destination ($outputPath + '.map') -Force
    Write-Host "Built relocatable PS2 module: $outputPath"
} finally {
    $env:PATH = $originalPath
    Remove-Item -LiteralPath ($outputPath + '.tmp'), ($outputPath + '.map.tmp') -Force -ErrorAction SilentlyContinue
}
