#!/usr/bin/env python3
"""Verify all native archives, then publish one immutable GitHub release."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import zipfile

from export_game import NOTICES, TARGETS, archive_name, version_number


def gh(*args, check=True, payload=None):
    result = subprocess.run(["gh", *args], input=payload, text=True, capture_output=True, timeout=300)
    if check and result.returncode:
        raise RuntimeError(result.stderr.strip())
    return result


def api(endpoint, method="GET", data=None):
    args = ["api", endpoint, "--method", method]
    if data is not None:
        args += ["--input", "-"]
    return json.loads(gh(*args, payload=json.dumps(data) if data is not None else None).stdout)


def find_release(repo, version):
    # The tag endpoint only finds published releases. Listing also includes
    # drafts for this authenticated writer, including a partially uploaded one.
    pages = json.loads(gh("api", f"repos/{repo}/releases?per_page=100", "--paginate", "--slurp").stdout)
    return next((release for page in pages for release in page if release["tag_name"] == version), None)


def verify_archives(dist, version, commit):
    version_number(version)
    archives = []
    lines = []
    for platform, (_, label, _) in TARGETS.items():
        name = archive_name(version, platform)
        path = dist / name
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        expected = Path(f"{path}.sha256").read_text().strip()
        if expected != f"{digest}  {name}":
            raise ValueError(f"Checksum mismatch: {name}")
        if path.suffix == ".dmg":
            # A disk image cannot be opened here. The macOS build mounted it, checked its
            # contents and signature, and left its build record beside it.
            info = json.loads(Path(f"{path}.json").read_text())
        else:
            with zipfile.ZipFile(path) as archive:
                if archive.testzip() is not None:
                    raise ValueError(f"Corrupt archive: {name}")
                info = json.loads(archive.read(f"{path.stem}/BUILD.json"))
                for notice in NOTICES:
                    if not archive.read(f"{path.stem}/{notice}"):
                        raise ValueError(f"Missing notice in {name}")
        if info["version"] != version or info["commit"] != commit or info["platform"] != label:
            raise ValueError(f"Build metadata mismatch: {name}")
        archives.append(path)
        lines.append(f"{digest}  {name}\n")
    if set(dist.glob("*.zip")) | set(dist.glob("*.dmg")) != set(archives):
        raise ValueError("Unexpected platform archives")
    checksum_file = dist / "SHA256SUMS"
    checksum_file.write_text("".join(lines))
    return archives + [checksum_file]


def publish(dist, version, commit, repo):
    assets = verify_archives(dist, version, commit)
    # Inspect both tag and release; never overwrite a published version or tag.
    release = find_release(repo, version)
    if release is not None and not release["draft"]:
        raise RuntimeError("That release already exists. Choose a new version.")
    tag = gh("api", f"repos/{repo}/git/ref/tags/{version}", check=False)
    if tag.returncode == 0:
        resolved = api(f"repos/{repo}/commits/{version}")["sha"]
        if resolved != commit:
            raise RuntimeError("Existing tag points at different source; it was not moved.")
    elif "HTTP 404" in tag.stderr:
        gh("api", f"repos/{repo}/git/refs", "--method", "POST", "-f", f"ref=refs/tags/{version}", "-f", f"sha={commit}")
    else:
        raise RuntimeError(tag.stderr.strip())
    notes = dist / "release-notes.md"
    notes.write_text(f'''Purr & Tangle {version}: a cozy collection of little cat games. The main
game is a cat-and-yarn puzzle with solo progression, local two-player versus,
controller support and three difficulty presets, with six smaller arcade-style
games beside it.

Download the file for your system:
- **Windows x64**: extract the ZIP and run `Purr-and-Tangle.exe` beside its `.pck` file.
- **Linux x64**: extract the ZIP and run `./Purr-and-Tangle` beside its `.pck` file.
- **macOS universal**: open the `.dmg` and drag `Purr-and-Tangle.app` onto Applications (Intel and Apple Silicon).

No engine installation or API keys are needed. Windows is unsigned; macOS is
ad-hoc signed and not Apple-notarized. If macOS blocks the first launch, use
System Settings → Privacy & Security → Open Anyway after checking the source.
Full instructions and license notices are inside each download.

Each package was built and smoke-tested on its native OS. Check downloads
against `SHA256SUMS` (`sha256sum -c SHA256SUMS` on Linux, or
`shasum -a 256 -c SHA256SUMS` on macOS, with all three files present).

Source: [{commit[:12]}](https://github.com/{repo}/commit/{commit}). Game license: MIT.
''')
    if release is None:
        release = api(f"repos/{repo}/releases", "POST", {
            "tag_name": version, "target_commitish": commit, "draft": True,
            "name": f"Purr & Tangle {version}", "body": notes.read_text()})
    expected = {path.name: "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest() for path in assets}
    existing = {item["name"]: item.get("digest") for item in release["assets"]}
    if any(name not in expected or digest != expected[name] for name, digest in existing.items()):
        raise RuntimeError("Existing draft assets differ; no files were overwritten.")
    missing = [str(path) for path in assets if path.name not in existing]
    if missing:
        gh("release", "upload", version, *missing, "--repo", repo)
    endpoint = f"repos/{repo}/releases/{release['id']}"
    uploaded = api(endpoint)
    actual = {item["name"]: item.get("digest") for item in uploaded["assets"]}
    if actual != expected:
        raise RuntimeError("Uploaded digests differ; release was left as a draft.")
    api(endpoint, "PATCH", {"draft": False, "make_latest": "true"})
    print(f"Published https://github.com/{repo}/releases/tag/{version}")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as summary:
            summary.write(f"[Download Purr & Tangle {version}](https://github.com/{repo}/releases/tag/{version})\n\n")
            summary.write("Verified all three platform downloads and SHA256SUMS against GitHub's uploaded digests.\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--dist", type=Path, default=Path("dist"))
    args = parser.parse_args()
    publish(args.dist, args.version, args.commit, args.repo)


if __name__ == "__main__":
    main()
