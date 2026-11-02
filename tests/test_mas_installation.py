"""Exercise rendered installers without invoking Homebrew or changing the Mac."""

import os
import pty
import plistlib
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "home/.chezmoiscripts"


class MacAppStoreInstallationTests(unittest.TestCase):
    def test_apps_are_attempted_without_legacy_icloud_preferences(self):
        for position in (23, 28):
            for failure in (False, True):
                with self.subTest(position=position, failure=failure):
                    self.check_installer(position, failure)

    def check_installer(self, position, failure):
        template = next(SCRIPTS.glob(f"*darwin-{position}-*.tmpl"))
        with tempfile.TemporaryDirectory() as directory:
            scratch = Path(directory)
            bin_dir = scratch / "bin"
            bin_dir.mkdir()
            preferences = scratch / "Library/Preferences"
            preferences.mkdir(parents=True)
            (preferences / "MobileMeAccounts.plist").write_bytes(
                plistlib.dumps({}, fmt=plistlib.FMT_BINARY)
            )
            # Empty account preferences must not veto App Store installs.
            defaults = bin_dir / "defaults"
            defaults.write_text("#!/bin/bash\nexit 1\n")
            defaults.chmod(0o755)
            brew = bin_dir / "brew"
            brew.write_text('''#!/bin/bash
if [[ "$1 $2" == "bundle check" ]]; then
    exit 1
elif [[ "$1 $2" == "bundle install" ]]; then
    if [[ "${HOMEBREW_BUNDLE_MAS_SKIP:-}" == 1 ]]; then
        exit 0
    fi
    for argument in "$@"; do
        case "$argument" in
            --file=*)
                input=$(cat "${argument#--file=}")
                printf '%s\\n' "$input" >> "$CAPTURE"
                if grep -q '^mas ' <<< "$input"; then
                    exit "$INSTALL_EXIT"
                fi
                ;;
        esac
    done
    exit 0
fi
''')
            brew.chmod(0o755)
            env = dict(os.environ, PATH=f"{bin_dir}:{os.environ['PATH']}")
            context = '''(dict "chezmoi" (dict "os" "darwin")
                "tag_choices" (list "core")
                "packages" (dict "darwin" (dict "core" (dict
                    "mas" (list "\\\"Test App\\\", id: 123456789")))))'''
            source = "{{ with merge " + context + " . }}" + template.read_text() + "{{ end }}"
            rendered = subprocess.run(
                [str(ROOT / "tests/run-template"), "--inline", source],
                env=env, text=True, capture_output=True, check=True, timeout=30,
            ).stdout
            brewfile = scratch / "Brewfile"
            brewfile.write_text('mas "Test App", id: 123456789\n')
            if position == 28:
                rendered = "\n".join(
                    f'brewfile="{brewfile}"' if line.startswith("brewfile=") else line
                    for line in rendered.splitlines()
                )
            script = scratch / "installer.sh"
            script.write_text(rendered)
            capture = scratch / "captured-brewfile"
            env.update(HOME=str(scratch), CAPTURE=str(capture),
                       INSTALL_EXIT="1" if failure else "0")
            env.pop("HOMEBREW_BUNDLE_MAS_SKIP", None)
            # The machine Brewfile installer requires a terminal and confirmation.
            master, slave = pty.openpty()
            try:
                result = subprocess.run(
                    ["bash", "-c", 'read() { REPLY=y; }; source "$1"',
                     "test", str(script)], stdin=slave,
                    env=env, text=True, capture_output=True, timeout=10,
                )
            finally:
                os.close(master)
                os.close(slave)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue(capture.exists(), result.stdout + result.stderr)
            self.assertIn('mas "Test App", id: 123456789', capture.read_text())
            self.assertNotIn("Not signed into iCloud", result.stdout)
            stamp = scratch / f".local/state/chezmoi-scripts/brew-{position}.pending"
            self.assertEqual(stamp.exists(), failure, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
