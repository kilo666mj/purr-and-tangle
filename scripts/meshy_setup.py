#!/usr/bin/env python3
"""Install/check Meshy MCP without putting API keys in arguments or output.

Run outside the agent sandbox:
    python3 scripts/meshy_setup.py install

The Codex settings contain an env-file path, not the key. The launcher reads
only MESHY_API_KEY from that file; it never executes/sources the file.
Requires Python 3.11+, Node 18+, npm and Codex.
"""

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tomllib


PACKAGE = "@meshy-ai/meshy-mcp-server"
VERSION = "0.6.11"
DEFAULT_INSTALL = Path.home() / ".local/share/meshy-mcp"


def read_key(path: Path) -> str:
    """Parse a literal dotenv assignment without shell expansion or execution."""
    values = []
    for line in path.read_text().splitlines():
        match = re.match(r"^\s*(?:export\s+)?MESHY_API_KEY\s*=\s*(.*)$", line)
        if not match:
            continue
        try:
            words = shlex.split(match.group(1), comments=True, posix=True)
        except ValueError:
            raise ValueError("Malformed MESHY_API_KEY assignment.") from None
        if len(words) != 1 or not re.fullmatch(r"msy_[A-Za-z0-9_-]+", words[0]):
            raise ValueError("MESHY_API_KEY must be a literal Meshy API key.")
        values.append(words[0])
    if len(values) != 1:
        raise ValueError("Expected exactly one MESHY_API_KEY assignment.")
    return values[0]


def server_entry(install: Path) -> Path:
    return install / "node_modules/@meshy-ai/meshy-mcp-server/dist/index.js"


def server_env(key: str) -> dict:
    # Do not forward other credentials from the client or the dotenv file.
    env = {k: os.environ[k] for k in ("PATH", "HOME", "TMPDIR") if k in os.environ}
    env.update(MESHY_API_KEY=key, TRANSPORT="stdio", MESHY_API_HOST="https://api.meshy.ai")
    return env


def check(install: Path, key: str) -> None:
    """Use the installed official MCP SDK; balance checks do not generate assets."""
    entry = server_entry(install)
    if not entry.is_file():
        raise ValueError("Meshy is not installed. Run the install command first.")
    source = r"""
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
const require = createRequire(process.env.MESHY_PACKAGE_JSON);
const { Client } = await import(pathToFileURL(require.resolve('@modelcontextprotocol/sdk/client/index.js')));
const { StdioClientTransport } = await import(pathToFileURL(require.resolve('@modelcontextprotocol/sdk/client/stdio.js')));
const transport = new StdioClientTransport({
  command: process.execPath,
  args: [process.env.MESHY_ENTRY],
  env: { PATH: process.env.PATH, HOME: process.env.HOME,
    MESHY_API_KEY: process.env.MESHY_API_KEY, TRANSPORT: 'stdio',
    MESHY_API_HOST: 'https://api.meshy.ai' },
  stderr: 'ignore'
});
const client = new Client({ name: 'purr-and-tangle-setup', version: '1.0.0' });
const timeout = setTimeout(() => process.exit(2), 60000);
try {
  await client.connect(transport);
  const { tools } = await client.listTools();
  if (!tools.some(t => t.name === 'meshy_image_to_3d') ||
      !tools.some(t => t.name === 'meshy_check_balance')) throw new Error();
  const balance = await client.callTool({ name: 'meshy_check_balance', arguments: {} });
  if (balance.isError) throw new Error();
  console.log(`Meshy authenticated; ${tools.length} MCP tools discovered.`);
} catch {
  console.error('Meshy connection/authentication failed. Check network access and the local key file.');
  process.exitCode = 1;
} finally {
  await client.close();
  clearTimeout(timeout);
}
"""
    env = server_env(key)
    env["MESHY_ENTRY"] = str(entry)
    env["MESHY_PACKAGE_JSON"] = str(entry.parent.parent / "package.json")
    result = subprocess.run(
        [shutil.which("node") or "node", "--input-type=module"], input=source,
        text=True, capture_output=True, env=env, timeout=75,
    )
    if result.returncode:
        raise ValueError("Meshy connection/authentication failed; check network access and the local key file.")
    # Print only our own success line, never arbitrary dependency output.
    for line in result.stdout.splitlines():
        if re.fullmatch(r"Meshy authenticated; \d+ MCP tools discovered\.", line):
            print(line)
            return
    raise ValueError("Meshy verification did not return a success result.")


def install_server(install: Path, env_file: Path, key: str) -> None:
    codex_home = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex-home")))
    config = codex_home / "config.toml"
    if not config.is_file():
        raise ValueError("No Codex config found. Set CODEX_HOME to your intended existing Codex home.")
    settings = tomllib.loads(config.read_text())
    launcher = str(Path(__file__).resolve())
    python = str(Path(sys.executable).resolve())
    args = [launcher, "serve", "--install-dir", str(install)]
    existing = settings.get("mcp_servers", {}).get("meshy")
    if existing and not (
        existing.get("command") == python and existing.get("args") == args
        and existing.get("env", {}).get("MESHY_ENV_FILE") == str(env_file)
    ):
        raise ValueError("A different Meshy configuration already exists; leaving it unchanged.")
    for command in ("node", "npm", "codex"):
        if not shutil.which(command):
            raise ValueError(f"Required command not found: {command}")
    if not os.access(config, os.W_OK) or not os.access(codex_home, os.W_OK):
        raise ValueError("Codex settings are read-only here. Run this installer in your own terminal pane.")
    print(f"Installing {PACKAGE}@{VERSION} ...", flush=True)
    # npm never receives the API key.
    npm_env = dict(os.environ)
    npm_env.pop("MESHY_API_KEY", None)
    result = subprocess.run(
        ["npm", "install", "--prefix", str(install), "--ignore-scripts",
         "--no-audit", "--no-fund", "--save-exact", f"{PACKAGE}@{VERSION}"],
        capture_output=True, text=True, env=npm_env, timeout=240,
    )
    if result.returncode:
        raise ValueError("npm installation failed. Check Node/npm and network access to registry.npmjs.org.")
    check(install, key)
    if not existing:
        # No secret appears in argv or settings. Codex handles its own TOML updates.
        client_env = dict(os.environ, CODEX_HOME=str(codex_home))
        result = subprocess.run(
            ["codex", "mcp", "add", "meshy", "--env", f"MESHY_ENV_FILE={env_file}",
             "--", python, *args],
            capture_output=True, text=True, env=client_env, timeout=30,
        )
        if result.returncode:
            raise ValueError("Meshy verified, but Codex registration failed. Check settings permissions.")
    registered = tomllib.loads(config.read_text()).get("mcp_servers", {}).get("meshy", {})
    if registered.get("command") != python or registered.get("args") != args:
        raise ValueError("Codex registration verification failed.")
    print(f"Meshy registered in {config}. Restart/resume Codex to load the tools.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("install", "check", "serve", "preflight"))
    parser.add_argument("--install-dir", type=Path, default=DEFAULT_INSTALL)
    parser.add_argument("--env-file", type=Path, default=Path(
        os.environ.get("MESHY_ENV_FILE", str(Path.home() / "code/.env"))))
    options = parser.parse_args()
    try:
        env_file = options.env_file.expanduser().resolve()
        install = options.install_dir.expanduser().resolve()
        key = read_key(env_file)
        if options.action == "preflight":
            print("Local Meshy key found and parsed; value withheld.")
        elif options.action == "install":
            install_server(install, env_file, key)
        elif options.action == "check":
            check(install, key)
        else:
            entry = server_entry(install)
            node = shutil.which("node")
            if not node or not entry.is_file():
                raise ValueError("Meshy or Node is missing. Run the install command first.")
            os.execve(node, [node, str(entry)], server_env(key))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        # OSError/subprocess exceptions may embed argv or unexpected file contents.
        message = str(error) if type(error) is ValueError else "Setup could not finish; check local paths, permissions and network access."
        print(message, file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
