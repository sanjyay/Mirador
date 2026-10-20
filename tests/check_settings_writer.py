#!/usr/bin/env python3
"""Exercise the production writer with Quickshell's native FileView plugin.

Run alongside the QML suites: python3 tests/check_settings_writer.py
The Qt test runner cannot load Quickshell's statically linked IO plugin.
"""
import os
from pathlib import Path
import re
import subprocess
import tempfile


def main():
    source = (Path(__file__).resolve().parents[1] / "WorkspaceOverview.qml").read_text()
    helper = re.search(r"function writePreferencesDocument\(document\) \{[\s\S]*?\n  \}", source)
    if helper is None:
        raise RuntimeError("Production writer helper not found")
    with tempfile.TemporaryDirectory(prefix="mirador-settings-writer-") as folder:
        directory = Path(folder) / "preferences"
        directory.mkdir()
        harness = '''import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
  id: root
  property string preferencesDirectory: "DIRECTORY"
  property int stage: 0
  property string first: '{"backdropDim":0.5}'
  property string second: '{"backdropDim":0.75}'
  HELPER
  function fail(message) { console.error(message); Qt.exit(1) }
  function succeeded() {
    if (stage === 0) { stage = 1; writePreferencesDocument(first) }
    else if (stage === 1) { stage = 2; permissions.command = ["chmod", "500", preferencesDirectory]; permissions.running = true }
    else if (stage === 3) {
      verification.reload()
      if (verification.text() !== second) { fail("Retry did not save the intended document"); return }
      console.log("PASS settings writer: unchanged save, atomic failure, identical retry")
      Qt.quit()
    } else fail("Unexpected save completion at stage " + stage)
  }
  FileView {
    id: preferencesFile
    path: ""; preload: false; atomicWrites: true; printErrors: false
    onSaved: Qt.callLater(root.succeeded)
    onSaveFailed: {
      if (root.stage !== 2) { root.fail("Unexpected write failure"); return }
      verification.reload()
      if (verification.text() !== root.first) { root.fail("Atomic failure changed the committed file"); return }
      root.stage = 3
      permissions.command = ["chmod", "700", root.preferencesDirectory]
      permissions.running = true
    }
  }
  FileView {
    id: verification
    path: root.preferencesDirectory + "/settings.json"
    preload: false; blockAllReads: true; printErrors: false
  }
  Process {
    id: permissions
    onExited: function(code, status) {
      if (code !== 0) { root.fail("Permission fixture failed"); return }
      root.writePreferencesDocument(root.second)
    }
  }
  Timer { interval: 5000; running: true; onTriggered: root.fail("Writer stalled at stage " + root.stage) }
  Component.onCompleted: writePreferencesDocument(first)
}
'''
        harness = harness.replace("DIRECTORY", str(directory)).replace("HELPER", helper.group())
        (Path(folder) / "shell.qml").write_text(harness)
        environment = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software")
        try:
            result = subprocess.run(["quickshell", "-p", folder], env=environment,
                                    capture_output=True, text=True, timeout=15, check=False)
            output = result.stdout + result.stderr
            print(output, end="")
            if result.returncode or "PASS settings writer:" not in output:
                raise RuntimeError("Native settings writer regression check failed")
        finally:
            directory.chmod(0o700)


if __name__ == "__main__":
    main()
