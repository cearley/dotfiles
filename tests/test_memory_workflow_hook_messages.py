"""Exercise recovery messaging without reading any real transcript or profile."""
import json
import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
HOOK = ROOT / 'home/dot_claude/skills/setup-memory-workflow/scripts/executable_crash-recovery-hook.sh'


class RecoveryMessage(unittest.TestCase):
    def test_detection_does_not_claim_session_end_or_authorize_recovery(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            prior = root / 'prior.jsonl'
            prior.write_text((json.dumps({'type': 'user', 'message': 'private'}) + '\n') * 6)
            payload = {'cwd': directory, 'session_id': 'current',
                       'transcript_path': str(root / 'current.jsonl'), 'source': 'clear'}
            result = subprocess.run(['bash', str(HOOK)], input=json.dumps(payload),
                                    text=True, capture_output=True, check=True,
                                    env={**os.environ, "HOME": directory, "CLAUDE_CONFIG_DIR": directory + "/profile"})
            self.assertIn('potentially unsaved work', result.stdout)
            self.assertIn('explicit recovery request', result.stdout)
            self.assertNotIn('SessionEnd was never logged', result.stdout)
            self.assertNotIn('so no in-session or SessionEnd save happened', result.stdout)
            self.assertIn('marker unchanged', result.stdout)
            self.assertFalse((root / '.claude').exists())

    def test_malformed_prior_transcript_fails_open(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            (root / 'prior.jsonl').write_text('{truncated')
            payload = {'cwd': directory, 'session_id': 'current',
                       'transcript_path': str(root / 'current.jsonl')}
            result = subprocess.run(['bash', str(HOOK)], input=json.dumps(payload),
                                    text=True, capture_output=True,
                                    env={**os.environ, "HOME": directory, "CLAUDE_CONFIG_DIR": directory + "/profile"})
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout, '')
            self.assertFalse((root / '.claude').exists())

    def test_reminder_invalid_input_or_directory_fails_open(self):
        reminder = HOOK.with_name('executable_session-reminder.sh')
        with tempfile.TemporaryDirectory() as directory:
            for payload in ('{truncated', json.dumps({'cwd': directory + '/missing'})):
                with self.subTest(payload=payload):
                    result = subprocess.run(['bash', str(reminder)], input=payload,
                                            text=True, capture_output=True, cwd=directory,
                                            env={**os.environ, "HOME": directory, "CLAUDE_CONFIG_DIR": directory + "/profile"})
                    self.assertEqual(result.returncode, 0)
                    self.assertEqual(result.stdout, '')
                    self.assertEqual(list(pathlib.Path(directory).iterdir()), [])


if __name__ == '__main__':
    unittest.main()
