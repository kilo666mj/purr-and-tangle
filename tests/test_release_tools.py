import hashlib
import json
from pathlib import Path
import stat
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from export_game import TARGETS, version_number, zip_folder
from publish_release import verify_archives


class ReleaseTest(unittest.TestCase):
    def test_version_rejects_paths_and_shell_text(self):
        self.assertEqual(version_number("v0.1.0"), "0.1.0")
        for value in ["../v1.0.0", "v1.0.0\nextra", "$(id)", "1.0.0", "v1.0"]:
            with self.assertRaises(ValueError):
                version_number(value)

    def make_archives(self, root):
        for _, label, _ in TARGETS.values():
            folder = root / f"Purr-and-Tangle-v0.1.0-{label}"
            folder.mkdir()
            (folder / "BUILD.json").write_text(json.dumps({"version": "v0.1.0", "platform": label, "commit": "a" * 40}))
            for name in ("LICENSE", "PLAYING.txt", "THIRD_PARTY_NOTICES.txt"):
                (folder / name).write_text("included notice")
            binary = folder / "game"
            binary.write_bytes(b"executable content")
            binary.chmod(0o755)
            archive = root / (folder.name + ".zip")
            zip_folder(folder, archive)
            archive.with_suffix(".zip.sha256").write_text(f"{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n")

    def test_archive_permissions_and_complete_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_archives(root)
            assets = verify_archives(root, "v0.1.0", "a" * 40)
            self.assertEqual(len(assets), 4)
            self.assertEqual(len((root / "SHA256SUMS").read_text().splitlines()), 3)
            with zipfile.ZipFile(assets[0]) as archive:
                mode = archive.getinfo(assets[0].stem + "/game").external_attr >> 16
                self.assertTrue(mode & stat.S_IXUSR)
                self.assertNotIn(".publish", " ".join(archive.namelist()))

    def test_refuses_tampered_archive_or_different_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_archives(root)
            with self.assertRaisesRegex(ValueError, "metadata mismatch"):
                verify_archives(root, "v0.1.0", "b" * 40)
            archive = next(root.glob("*.zip"))
            with archive.open("ab") as stream:
                stream.write(b"tampered")
            with self.assertRaisesRegex(ValueError, "Checksum mismatch"):
                verify_archives(root, "v0.1.0", "a" * 40)

    def test_refuses_incomplete_release(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_archives(root)
            next(root.glob("*.zip")).unlink()
            with self.assertRaises(FileNotFoundError):
                verify_archives(root, "v0.1.0", "a" * 40)


if __name__ == "__main__":
    unittest.main()
