#!/usr/bin/env python3
"""Export, smoke-test and package one native desktop target using Godot templates."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from xml.parsers.expat import ExpatError
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
TARGETS = {
    "linux": ("Linux", "linux-x86_64", "Purr-and-Tangle"),
    "windows": ("Windows", "windows-x86_64", "Purr-and-Tangle.exe"),
    "macos": ("macOS", "macos-universal", "Purr-and-Tangle.app"),
}


def version_number(value):
    if not re.fullmatch(r"v\d+\.\d+\.\d+", value):
        raise ValueError("Version must be vMAJOR.MINOR.PATCH, for example v0.1.0")
    return value[1:]


def run(*args, cwd=ROOT):
    result = subprocess.run([str(arg) for arg in args], cwd=cwd, text=True, encoding="utf-8", errors="replace",
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600)
    print(result.stdout, end="", flush=True)
    if result.returncode or re.search(r"SCRIPT ERROR|Parse Error|Failed to load script|ERROR:", result.stdout):
        raise RuntimeError(f"Command failed: {args[0]}")
    return result.stdout


def resolve_godot(requested, scratch):
    candidate = requested or os.environ.get("GODOT_BIN") or os.environ.get("GODOT") or "godot"
    path = Path(candidate).expanduser()
    if not path.is_file():
        found = shutil.which(candidate)
        if not found:
            raise FileNotFoundError("Godot executable not found. Set GODOT_BIN or pass --godot with its full path.")
        path = Path(found)
    path = path.resolve()
    if sys.platform == "win32" and not path.suffix:
        # setup-godot exposes an extensionless hard link. Bash can launch it,
        # but Windows executable lookup expects .exe. Keep the alias private
        # to this build; no installed engine files are renamed or modified.
        executable = Path(scratch) / "godot.exe"
        shutil.copyfile(path, executable)
        path = executable
    return str(path)


def zip_folder(folder, archive):
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as output:
        for path in sorted(folder.rglob("*")):
            if path.is_file():
                output.write(path, path.relative_to(folder.parent).as_posix())


def read_macos_info(app):
    path = app / "Contents/Info.plist"
    raw = path.read_bytes()
    try:
        return plistlib.loads(raw), False
    except ExpatError:
        # Godot 4.7.2 escapes display names but inserts CFBundleExecutable
        # without XML escaping. Repair only that value, bound to a real file.
        match = re.search(rb"<key>CFBundleExecutable</key>\s*<string>([^<]*)</string>", raw)
        if not match:
            raise
        name = match[1].decode("utf-8")
        if Path(name).name != name or not (app / "Contents/MacOS" / name).is_file():
            raise
        corrected = raw[:match.start(1)] + escape(name).encode("utf-8") + raw[match.end(1):]
        info = plistlib.loads(corrected)
        path.write_bytes(corrected)
        return info, True


def build(platform, version, godot):
    number = version_number(version)
    native = {"linux": "linux", "win32": "windows", "darwin": "macos"}.get(sys.platform)
    if platform != native:
        raise ValueError("Use the matching OS to build and smoke-test this platform")
    preset, label, app_name = TARGETS[platform]
    stage = Path(tempfile.mkdtemp(prefix="purr-release-"))
    bundle = stage / f"Purr-and-Tangle-{version}-{label}"
    bundle.mkdir()
    app = bundle / app_name
    project = ROOT / "project.godot"
    presets = ROOT / "export_presets.cfg"
    original_project, original_presets = project.read_text(), presets.read_text()
    try:
        godot = resolve_godot(godot, stage)
        print(f"Using Godot: {godot}", flush=True)
        engine_version = run(godot, "--version").strip()
        project.write_text(re.sub(r'^config/version="[^"]*"', f'config/version="{number}"', original_project, flags=re.M))
        edited = original_presets
        for key in ("application/file_version", "application/product_version", "application/short_version", "application/version"):
            value = number + ".0" if key in ("application/file_version", "application/product_version") else number
            edited = re.sub(rf'^{re.escape(key)}="[^"]*"', f'{key}="{value}"', edited, flags=re.M)
        presets.write_text(edited)
        run(godot, "--headless", "--path", ROOT, "--editor", "--import", "--quit")
        run(godot, "--headless", "--path", ROOT, "--export-release", preset, app)
        run(godot, "--headless", "--path", ROOT, "--script", "scripts/export_notices.gd", "--", bundle / "THIRD_PARTY_NOTICES.txt")
        if not app.exists():
            raise RuntimeError("Export did not produce the expected executable")
        if platform == "macos":
            info, repaired = read_macos_info(app)
            executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
            if repaired:
                # Changing Info.plist invalidates the bundle's ad-hoc signature.
                run("codesign", "--force", "--deep", "--sign", "-",
                    "--preserve-metadata=entitlements,flags", app)
            arches = run("lipo", "-archs", executable)
            if not {"arm64", "x86_64"}.issubset(arches.split()):
                raise RuntimeError("macOS export is not universal")
            run("codesign", "--verify", "--deep", "--strict", app)
        else:
            executable = app
            if not app.with_suffix(".pck").is_file():
                raise RuntimeError("Exported game data (.pck) is missing")
        # Run outside the source checkout so a missing exported resource cannot
        # accidentally fall back to a development file.
        run(executable, "--headless", "--quit-after", "10", cwd=bundle)
        for name in ("LICENSE", "PLAYING.txt"):
            shutil.copy2(ROOT / name, bundle / name)
        commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        (bundle / "BUILD.json").write_text(json.dumps({"version": version, "commit": commit,
            "platform": label, "godot": engine_version}, indent=2) + "\n")
        dist = ROOT / "dist"
        dist.mkdir(exist_ok=True)
        archive = dist / f"{bundle.name}.zip"
        if platform == "macos":
            run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", bundle, archive)
        else:
            zip_folder(bundle, archive)
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        archive.with_suffix(".zip.sha256").write_text(f"{digest}  {archive.name}\n")
        print(f"Packaged and smoke-tested {archive.name}")
    finally:
        project.write_text(original_project)
        presets.write_text(original_presets)
        shutil.rmtree(stage)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=TARGETS, required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--godot", help="Godot executable; defaults to GODOT_BIN, GODOT, then PATH")
    args = parser.parse_args()
    build(args.platform, args.version, args.godot)


if __name__ == "__main__":
    main()
