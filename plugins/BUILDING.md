# Injected EE modules on Windows

`build-module.ps1` builds C/C++ source into relocatable PS2 guest modules. It uses
the existing Windows compiler and SDK archives, supplies an injected-module
runtime, and does not run the standalone console CRT. See the injector repository's
`docs/guest-modules.md` for the ABI and supported runtime services.

```powershell
./plugins/build-module.ps1 -Project path/to/module.json
./plugins/build-module.ps1 -Project path/to/module.json -Clean
python -B plugins/test_build.py
```

The test compiles from a path containing spaces, checks ELF type, rejects a strong
unresolved import without replacing the previous ELF/map, and checks bounded clean.
Compiler/linker paths are normalized and allocator code disables built-in
substitutions so malloc/calloc definitions cannot be folded into recursive calls.

Commit and push this SDK before updating `external/ps2sdk` in consumer repositories.
Include the updated submodule pointer in each consumer's commit. No migration
helper is required.
