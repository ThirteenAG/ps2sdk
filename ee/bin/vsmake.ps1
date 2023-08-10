$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:PATH = "$scriptDirectory;$env:PATH"
make $args
exit $LASTEXITCODE