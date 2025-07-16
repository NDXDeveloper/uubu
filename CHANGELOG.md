# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2025-07-16

### 🚀 Added
- Initial release of uubu - Ubuntu/Debian system updater
- Multi-architecture support (AMD64 and ARM64)
- Internationalization support with 4 languages:
  - English (en) - default
  - French (fr)
  - German (de)
  - Spanish (es)
- System update functionality:
  - `apt update` and `apt upgrade`
  - Optional `apt dist-upgrade`
  - Automatic cleanup with `apt autoremove` and `apt autoclean`
- Package manager support:
  - Snap packages update (`snap refresh`)
  - Flatpak packages update (`flatpak update`)
- Safety features:
  - Timeshift integration for system snapshots
  - Root execution prevention (must use sudo)
  - Internet connectivity check
  - Reboot requirement detection and prompt
- Command-line options:
  - `-s, --snapshot`: Create Timeshift snapshot before updates
  - `--no-snap`: Skip Snap packages update
  - `--no-flatpak`: Skip Flatpak packages update
  - `--no-reboot`: Skip reboot requirement check
  - `--dist-upgrade`: Perform distribution upgrade
  - `-h, --help`: Show help information
  - `-v, --version`: Show version information
- Distribution packages:
  - DEB packages for AMD64 and ARM64
  - Standalone binaries for both architectures
  - Complete tar.gz archives with locales and documentation
- Build system:
  - Comprehensive Makefile with multi-architecture support
  - Automated testing for all supported languages
  - Code quality checks and validation
  - Automated package generation with nFPM

### 🔧 Technical Details
- Built with Go 1.22.2
- Embedded locales (no external dependencies)
- Static binaries (~13MB including all languages)
- MIT License
- Comprehensive test suite with locale validation

### 📦 Installation Methods
- DEB packages for easy installation on Ubuntu/Debian
- Standalone binaries for manual installation
- Complete distribution packages with documentation

[0.0.1]: https://github.com/NDXDeveloper/uubu/releases/tag/v0.0.1
