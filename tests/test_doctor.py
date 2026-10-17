import json
from pathlib import Path
import runpy
import tempfile
import subprocess
import unittest
from unittest.mock import patch

doctor = runpy.run_path(str(Path(__file__).resolve().parents[1]/"bin/mirador-doctor"), run_name="doctor_tests")

class DoctorTests(unittest.TestCase):
    def test_settings_missing_invalid_and_bounded(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/"settings.json"
            self.assertEqual(doctor["settings_check"](path)["status"], "ok")
            for value in ["[]", "{broken", "x"*65537]:
                path.write_text(value)
                self.assertEqual(doctor["settings_check"](path)["status"], "warning")
            path.write_text('{"cycleUI":"full"}')
            self.assertEqual(doctor["settings_check"](path)["status"], "ok")

    def test_shortcut_routing_is_not_assumed_for_lua(self):
        rows = doctor["shortcut_checks"]([{"dispatcher":"__lua","arg":"7","key":"Tab","modmask":64}])
        self.assertEqual(rows[0]["status"], "warning")
        self.assertIn("hidden", rows[0]["detail"])

    def test_duplicate_shortcuts_and_release_bindings(self):
        first = {"key":"Tab","modmask":64,"arg":"mirador --cycle"}
        self.assertEqual(doctor["shortcut_checks"]([first])[0]["status"], "ok")
        self.assertEqual(doctor["shortcut_checks"]([first,dict(first)])[0]["status"], "warning")
        self.assertEqual(doctor["shortcut_checks"]([first,dict(first,release=True)])[0]["status"], "ok")

    def test_report_omits_raw_commands(self):
        secret = "sensitive-title-or-command"
        rows = doctor["shortcut_checks"]([{"arg":"mirador "+secret,"key":"Tab"}])
        self.assertNotIn(secret, json.dumps(rows))

    def test_ipc_failure_is_bounded(self):
        with patch("subprocess.run", side_effect=subprocess.TimeoutExpired("hyprctl",2)):
            self.assertIsNone(doctor["read_ipc"]("version"))
        with patch("subprocess.run", side_effect=OSError):
            self.assertIsNone(doctor["read_ipc"]("version"))

if __name__ == "__main__":
    unittest.main()
