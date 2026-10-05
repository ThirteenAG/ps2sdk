"""Exercise Windows module compilation and failed-build output preservation."""
from pathlib import Path
import json
import struct
import subprocess
import tempfile
import unittest

BUILDER = Path(__file__).with_name("build-module.ps1")


class ModuleBuild(unittest.TestCase):
    def test_build_failure_preserves_binary_and_map(self):
        with tempfile.TemporaryDirectory(prefix="ps2 module ") as directory:
            root = Path(directory)
            source = root / "main.c"
            source.write_text('int CompatibleCRCList[] = {0x4F32A11F};\nvoid init(void) {}\n')
            project = root / "module.json"
            project.write_text(json.dumps(dict(sources=["main.c"], output="plugin.elf")))
            command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(BUILDER), "-Project", str(project)]
            process = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
            binary = root / "plugin.elf"
            mapping = root / "plugin.elf.map"
            old_binary, old_map = binary.read_bytes(), mapping.read_bytes()
            self.assertEqual(old_binary[:7], b"\x7fELF\x01\x01\x01")
            self.assertEqual(struct.unpack_from("<H", old_binary, 16)[0], 1)
            source.write_text('int CompatibleCRCList[] = {0x4F32A11F};\nextern void missing_service(void);\nvoid init(void) {missing_service();}\n')
            process = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(process.returncode, 0)
            self.assertIn("missing_service", process.stderr)
            self.assertEqual(binary.read_bytes(), old_binary)
            self.assertEqual(mapping.read_bytes(), old_map)
            self.assertFalse((root / "plugin.elf.tmp").exists())
            self.assertFalse((root / "plugin.elf.map.tmp").exists())
            unrelated = root / "keep.txt"
            unrelated.write_text("preserve")
            process = subprocess.run(command + ["-Clean"], capture_output=True, text=True)
            self.assertEqual(process.returncode, 0, process.stderr)
            self.assertFalse(binary.exists())
            self.assertFalse((root / "plugin.elf.objects").exists())
            self.assertEqual(unrelated.read_text(), "preserve")


if __name__ == "__main__":
    unittest.main()
