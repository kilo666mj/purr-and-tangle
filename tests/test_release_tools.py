import hashlib
import json
import os
import plistlib
from pathlib import Path
import shutil
import stat
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import zipfile
from xml.parsers.expat import ExpatError

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from export_game import TARGETS, archive_name, make_dmg, read_macos_info, resolve_godot, version_number, zip_folder
from publish_release import publish, verify_archives


class ReleaseTest(unittest.TestCase):
    def test_windows_extensionless_action_alias(self):
        with tempfile.TemporaryDirectory(prefix="engine path ") as directory:
            root = Path(directory)
            source = root / "godot"
            source.write_bytes(b"MZ engine executable")
            scratch = root / "build"
            scratch.mkdir()
            with patch.dict(os.environ, {"GODOT": str(source)}, clear=True), patch("export_game.sys.platform", "win32"):
                executable = Path(resolve_godot(None, scratch))
            self.assertEqual(executable, scratch / "godot.exe")
            self.assertEqual(executable.read_bytes(), source.read_bytes())
            self.assertTrue(source.exists())

    def test_explicit_engine_overrides_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "custom engine.exe"
            source.write_bytes(b"MZ engine")
            with patch.dict(os.environ, {"GODOT_BIN": "missing", "GODOT": "also missing"}):
                self.assertEqual(resolve_godot(str(source), directory), str(source.resolve()))

    def test_missing_engine_explains_configuration(self):
        with patch("export_game.shutil.which", return_value=None):
            with self.assertRaisesRegex(FileNotFoundError, "GODOT_BIN"):
                resolve_godot("nonexistent-godot-for-test", ".")

    def test_macos_executable_ampersand_preserves_display_name(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / "game.app"
            binary = app / "Contents/MacOS/Purr & Tangle"
            binary.parent.mkdir(parents=True)
            binary.write_bytes(b"executable")
            path = app / "Contents/Info.plist"
            valid = plistlib.dumps({"CFBundleExecutable": "Purr & Tangle", "CFBundleName": "Purr & Tangle"})
            path.write_bytes(valid.replace(b"Purr &amp; Tangle", b"Purr & Tangle", 1))
            info, repaired = read_macos_info(app)
            self.assertTrue(repaired)
            self.assertEqual(info["CFBundleExecutable"], binary.name)
            self.assertEqual(info["CFBundleName"], "Purr & Tangle")
            self.assertEqual(plistlib.loads(path.read_bytes()), info)
            self.assertEqual(read_macos_info(app), (info, False))

    def test_macos_unknown_invalid_metadata_is_not_rewritten(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / "game.app"
            (app / "Contents").mkdir(parents=True)
            path = app / "Contents/Info.plist"
            original = b'<plist><dict><key>Unknown</key><string>bad & text</string></dict></plist>'
            path.write_bytes(original)
            with self.assertRaises(ExpatError):
                read_macos_info(app)
            self.assertEqual(path.read_bytes(), original)

    def test_version_rejects_paths_and_shell_text(self):
        self.assertEqual(version_number("v0.1.0"), "0.1.0")
        for value in ["../v1.0.0", "v1.0.0\nextra", "$(id)", "1.0.0", "v1.0"]:
            with self.assertRaises(ValueError):
                version_number(value)

    def make_archives(self, root):
        for platform, (_, label, _) in TARGETS.items():
            folder = root / f"Purr-and-Tangle-v0.1.0-{label}"
            folder.mkdir()
            (folder / "BUILD.json").write_text(json.dumps({"version": "v0.1.0", "platform": label, "commit": "a" * 40}))
            if platform == "macos":
                # A stand-in image: only macOS can build or open a real one.
                archive = root / archive_name("v0.1.0", platform)
                archive.write_bytes(b"disk image content")
                shutil.copy2(folder / "BUILD.json", f"{archive}.json")
                Path(f"{archive}.sha256").write_text(f"{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n")
                continue
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
            self.assertEqual([path.suffix for path in assets[:3]], [".zip", ".zip", ".dmg"])
            self.assertEqual(len((root / "SHA256SUMS").read_text().splitlines()), 3)
            with zipfile.ZipFile(assets[0]) as archive:
                mode = archive.getinfo(assets[0].stem + "/game").external_attr >> 16
                source = root / assets[0].stem / "game"
                # Windows chmod has no Unix executable bit; preserve the
                # source filesystem's actual mode on each native platform.
                self.assertEqual(stat.S_IMODE(mode), stat.S_IMODE(source.stat().st_mode))
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

    def test_refuses_disk_image_from_different_source_or_unexpected_downloads(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_archives(root)
            record = next(root.glob("*.dmg.json"))
            record.write_text(record.read_text().replace("a" * 40, "b" * 40))
            with self.assertRaisesRegex(ValueError, "metadata mismatch: .*dmg"):
                verify_archives(root, "v0.1.0", "a" * 40)
            record.write_text(record.read_text().replace("b" * 40, "a" * 40))
            (root / "Extra.dmg").write_bytes(b"unexpected")
            with self.assertRaisesRegex(ValueError, "Unexpected"):
                verify_archives(root, "v0.1.0", "a" * 40)

    @unittest.skipIf(sys.platform == "win32", "symbolic links need extra privileges on Windows")
    def test_disk_image_gets_applications_shortcut_and_is_checked_mounted(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bundle = root / "bundle"
            (bundle / "Game.app").mkdir(parents=True)
            for name in ("LICENSE", "PLAYING.txt", "THIRD_PARTY_NOTICES.txt", "BUILD.json"):
                (bundle / name).write_text("included")
            calls = []
            def fake_run(*args, cwd=None):
                calls.append([str(arg) for arg in args])
                if args[1] == "attach":
                    # Stand in for mounting: the volume holds what the bundle held.
                    shutil.copytree(bundle, args[-1], symlinks=True, dirs_exist_ok=True)
                return ""
            with patch("export_game.run", side_effect=fake_run):
                make_dmg(bundle, "Game.app", root / "game.dmg", root)
                self.assertEqual(os.readlink(bundle / "Applications"), "/Applications")
                self.assertEqual([call[1] for call in calls if call[0] == "hdiutil"], ["create", "verify", "attach", "detach"])
                self.assertIn(str(root / "mounted" / "Game.app"), calls[-2])
                (bundle / "LICENSE").unlink()
                (bundle / "Applications").unlink()
                shutil.rmtree(root / "mounted")
                with self.assertRaisesRegex(RuntimeError, "missing LICENSE"):
                    make_dmg(bundle, "Game.app", root / "game.dmg", root)
                self.assertEqual(calls[-1][:2], ["hdiutil", "detach"])

    def test_refuses_incomplete_release(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_archives(root)
            next(root.glob("*.zip")).unlink()
            with self.assertRaises(FileNotFoundError):
                verify_archives(root, "v0.1.0", "a" * 40)

    def test_publisher_uses_draft_id_and_resumes_verified_uploads(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_archives(root)
            assets = verify_archives(root, "v0.1.0", "a" * 40)
            uploaded = [{"name": path.name, "digest": "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()} for path in assets]
            for resume in [False, True]:
                draft = {"id": 42, "tag_name": "v0.1.0", "draft": True, "assets": uploaded if resume else []}
                def fake_api(endpoint, method="GET", data=None):
                    self.assertNotIn("/releases/tags/", endpoint)
                    if "/commits/" in endpoint:
                        return {"sha": "a" * 40}
                    if method == "POST":
                        return draft
                    return dict(draft, assets=uploaded)
                with patch("publish_release.find_release", return_value=draft if resume else None), \
                     patch("publish_release.api", side_effect=fake_api) as api_mock, \
                     patch("publish_release.gh", return_value=SimpleNamespace(returncode=0, stdout="", stderr="")) as gh_mock, \
                     patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": ""}), patch("builtins.print"):
                    publish(root, "v0.1.0", "a" * 40, "owner/game")
                api_mock.assert_any_call("repos/owner/game/releases/42", "PATCH", {"draft": False, "make_latest": "true"})
                uploads = [call for call in gh_mock.call_args_list if call.args[:2] == ("release", "upload")]
                self.assertEqual(len(uploads), 0 if resume else 1)

    def test_publisher_refuses_mismatched_draft_assets(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_archives(root)
            draft = {"id": 42, "draft": True, "assets": [{"name": "SHA256SUMS", "digest": "sha256:wrong"}]}
            with patch("publish_release.find_release", return_value=draft), \
                 patch("publish_release.api", return_value={"sha": "a" * 40}) as api_mock, \
                 patch("publish_release.gh", return_value=SimpleNamespace(returncode=0, stdout="", stderr="")) as gh_mock:
                with self.assertRaisesRegex(RuntimeError, "no files were overwritten"):
                    publish(root, "v0.1.0", "a" * 40, "owner/game")
            self.assertFalse(any(call.args[:2] == ("release", "upload") for call in gh_mock.call_args_list))
            self.assertFalse(any(len(call.args) > 1 and call.args[1] == "PATCH" for call in api_mock.call_args_list))


if __name__ == "__main__":
    unittest.main()
