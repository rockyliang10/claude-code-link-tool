# Changelog

## Unreleased

- Added a Doctor check for the local `claude` command, selected working directory, and AquaCloud `/models`.
- Added searchable model filtering for accounts with many AquaCloud models.
- Added optional pre-launch Claude Skills sync from a template `.claude` directory.
- Skill sync now starts empty and asks the user to browse for a local template folder instead of choosing a hard-coded default.
- Changed Claude Code launch to pass secrets through the child process environment instead of writing a temporary `.ps1` file containing the API key.
- Documented compatibility boundaries for direct AquaCloud gateway use.
- Added a release build script that creates zh-CN and en zip files and prints SHA256 hashes.
