# Changelog

## Unreleased

- Added a Doctor check for the local `claude` command, selected working directory, and AquaCloud `/models`.
- Changed Claude Code launch to pass secrets through the child process environment instead of writing a temporary `.ps1` file containing the API key.
- Documented compatibility boundaries for direct AquaCloud gateway use.
- Added a release build script that creates zh-CN and en zip files and prints SHA256 hashes.
