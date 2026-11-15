#!/usr/bin/env python3
"""Verify all native archives, then publish one immutable GitHub release."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import zipfile

from export_game import TARGETS, version_number


def gh(*args, check=True):
    result = subprocess.run(["gh", *args], text=True, capture_output=True, timeout=300)
    if check and result.returncode:
        raise RuntimeError(result.stderr.strip())
    return result


def api(endpoint):
    return json.loads(gh("api", endpoint).stdout)


def verify_archives(dist, version, commit):
    version_number(version)
    archives = []
    lines = []
    for _, label, _ in TARGETS.values():
        name = f"Purr-and-Tangle-{version}-{label}.zip"
        path = dist / name
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        expected = path.with_suffix(".zip.sha256").read_text().strip()
        if expected != f"{digest}  {name}":
            raise ValueError(f"Checksum mismatch: {name}")
        with zipfile.ZipFile(path) as archive:
            if archive.testzip() is not None:
                raise ValueError(f"Corrupt archive: {name}")
            info = json.loads(archive.read(f"{path.stem}/BUILD.json"))
            if info["version"] != version or info["commit"] != commit or info["platform"] != label:
                raise ValueError(f"Build metadata mismatch: {name}")
            for notice in ("LICENSE", "PLAYING.txt", "THIRD_PARTY_NOTICES.txt"):
                if not archive.read(f"{path.stem}/{notice}"):
                    raise ValueError(f"Missing notice in {name}")
        archives.append(path)
        lines.append(f"{digest}  {name}\n")
    if set(dist.glob("*.zip")) != set(archives):
        raise ValueError("Unexpected platform archives")
    checksum_file = dist / "SHA256SUMS"
    checksum_file.write_text("".join(lines))
    return archives + [checksum_file]


def publish(dist, version, commit, repo):
    assets = verify_archives(dist, version, commit)
    # Inspect both tag and release; never overwrite a published version or tag.
    release = gh("api", f"repos/{repo}/releases/tags/{version}", check=False)
    if release.returncode == 0:
        raise RuntimeError("That release already exists. Choose a new version.")
    if "HTTP 404" not in release.stderr:
        raise RuntimeError(release.stderr.strip())
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
    notes.write_text(f'''Purr & Tangle {version}: a cozy cat-and-yarn puzzle with solo progression,
local two-player versus, controller support, and three difficulty presets.

Download and extract the archive for your system:
- **Windows x64**: run `Purr-and-Tangle.exe` beside its `.pck` file.
- **Linux x64**: run `./Purr-and-Tangle` beside its `.pck` file.
- **macOS universal**: move `Purr-and-Tangle.app` to Applications (Intel and Apple Silicon).

No engine installation or API keys are needed. Windows is unsigned; macOS is
ad-hoc signed and not Apple-notarized. If macOS blocks the first launch, use
System Settings → Privacy & Security → Open Anyway after checking the source.
Full instructions and license notices are inside each archive.

Each package was built and smoke-tested on its native OS. Check downloaded
archives against `SHA256SUMS` (`sha256sum -c SHA256SUMS` on Linux, or
`shasum -a 256 -c SHA256SUMS` on macOS, with all three archives present).

Source: [{commit[:12]}](https://github.com/{repo}/commit/{commit}). Game license: MIT.
''')
    gh("release", "create", version, "--repo", repo, "--verify-tag", "--target", commit,
       "--draft", "--title", f"Purr & Tangle {version}", "--notes-file", str(notes))
    gh("release", "upload", version, *[str(path) for path in assets], "--repo", repo)
    uploaded = api(f"repos/{repo}/releases/tags/{version}")
    expected = {path.name: "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest() for path in assets}
    actual = {item["name"]: item.get("digest") for item in uploaded["assets"]}
    if actual != expected:
        raise RuntimeError("Uploaded digests differ; release was left as a draft.")
    gh("release", "edit", version, "--repo", repo, "--draft=false", "--latest")
    print(f"Published https://github.com/{repo}/releases/tag/{version}")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as summary:
            summary.write(f"[Download Purr & Tangle {version}](https://github.com/{repo}/releases/tag/{version})\n\n")
            summary.write("Verified all three platform ZIPs and SHA256SUMS against GitHub's uploaded digests.\n")


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
