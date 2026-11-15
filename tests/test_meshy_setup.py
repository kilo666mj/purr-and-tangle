import importlib.util
from pathlib import Path
import tempfile
import unittest


spec = importlib.util.spec_from_file_location("meshy_setup", Path(__file__).parents[1] / "scripts/meshy_setup.py")
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


class CredentialsTest(unittest.TestCase):
    def parse(self, text):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".env"
            path.write_text(text)
            return setup.read_key(path)

    def test_dotenv_literal_formats(self):
        for text in ["MESHY_API_KEY=msy_example", "export MESHY_API_KEY='msy_example' # comment",
                     'MESHY_API_KEY="msy_example"', "OTHER=ignored\nMESHY_API_KEY=msy_example"]:
            self.assertEqual(self.parse(text), "msy_example")

    def test_rejects_shell_code_duplicates_and_invalid_values_without_echoing(self):
        for value in ["$(touch /tmp/should-not-exist)", "`id`", "", "msy_secret extra",
                      '"unterminated', "bad_secret", "msy_secret\nMESHY_API_KEY=msy_second"]:
            with self.assertRaises(ValueError) as caught:
                self.parse("MESHY_API_KEY=" + value)
            self.assertNotIn("secret", str(caught.exception))

    def test_missing_key(self):
        with self.assertRaises(ValueError):
            self.parse("OTHER=example")

    def test_child_env_does_not_forward_other_credentials(self):
        import os
        from unittest.mock import patch
        with patch.dict(os.environ, {"UNRELATED_SECRET": "hidden", "MESHY_API_HOST": "https://example.org"}):
            env = setup.server_env("msy_example")
        self.assertNotIn("UNRELATED_SECRET", env)
        self.assertEqual(env["MESHY_API_HOST"], "https://api.meshy.ai")
        self.assertEqual(env["TRANSPORT"], "stdio")


if __name__ == "__main__":
    unittest.main()
