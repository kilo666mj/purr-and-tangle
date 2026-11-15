# Security

Please report vulnerabilities privately through
[GitHub private vulnerability reporting](https://github.com/kilo666mj/purr-and-tangle/security/advisories/new).
Do not include credentials or exploitable details in a public issue.

The latest published release receives fixes. The game plays locally and does
not need network access or API keys. Never commit credentials or real dotenv
files to the repository.

CodeQL scans the Python development tools and GitHub Actions workflows on
changes to `main`, pull requests, and weekly. CodeQL does not support GDScript;
Godot's import/script checks and the gameplay/controller tests cover that code.
Dependency review checks pull requests, and Dependabot updates pinned Actions.

Release jobs build and smoke-test native Windows, macOS and Linux packages.
Archives include SHA-256 checksums, source commit information and third-party
license notices. Windows builds are unsigned; macOS builds are ad-hoc signed
and are not Apple-notarized.
