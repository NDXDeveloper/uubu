# uubu 🚀

**Update Upgrade Ubuntu** - An automated system update tool for Ubuntu/Kubuntu written in Go.

[![Go Report Card](https://goreportcard.com/badge/github.com/yourusername/uubu)](https://goreportcard.com/report/github.com/yourusername/uubu)
[![Release](https://img.shields.io/github/release/yourusername/uubu.svg)](https://github.com/yourusername/uubu/releases)

## 📋 Description

`uubu` automates comprehensive system updates for Ubuntu-based distributions. It handles APT packages, Snap packages, Flatpak applications, system cleanup, and offers optional Timeshift snapshots for safe rollback.

## ✨ Features

- 🔄 **Complete System Updates**: APT, Snap, and Flatpak packages
- 📸 **Timeshift Integration**: Optional system snapshots before updates
- 🧹 **Automatic Cleanup**: Removes obsolete packages and cleans cache
- 🔒 **Safety Checks**: Root prevention, internet connectivity verification
- 🎨 **Colored Output**: Clear, colored terminal messages
- ⚡ **Fast & Lightweight**: Single binary with no dependencies
- 🔧 **Configurable**: Flexible command-line options

## 🚀 Quick Start

### Installation

#### From Release (Recommended)
```bash
# Download latest release
wget https://github.com/yourusername/uubu/releases/latest/download/uubu
chmod +x uubu
sudo mv uubu /usr/local/bin/
```

#### From Source
```bash
git clone https://github.com/yourusername/uubu.git
cd uubu
make build
make install
```

### Usage

```bash
# Basic system update
uubu

# Update with Timeshift snapshot
uubu -s

# Update without Snap packages
uubu --no-snap

# Update with full system upgrade
uubu --dist-upgrade

# Show help
uubu --help

# Show version
uubu --version
```

## 📖 Command Line Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Display help information |
| `-v, --version` | Show version information |
| `-s, --snapshot` | Create Timeshift snapshot before update |
| `--dist-upgrade` | Perform full system upgrade (includes removing obsolete packages) |
| `--no-snap` | Skip Snap package updates |
| `--no-flatpak` | Skip Flatpak package updates |
| `--no-reboot` | Don't prompt for reboot |

## 🛠️ What uubu Does

1. **System Checks**: Verifies non-root execution and internet connectivity
2. **Optional Snapshot**: Creates Timeshift snapshot if requested
3. **APT Updates**: Updates package lists, upgrades packages, dist-upgrade
4. **Snap Updates**: Refreshes Snap packages (if installed)
5. **Flatpak Updates**: Updates Flatpak applications (if installed)
6. **System Cleanup**: Removes obsolete packages and cleans cache
7. **Reboot Check**: Detects if reboot is required and prompts user

## 📋 Requirements

- Ubuntu 20.04+ or Kubuntu 20.04+
- Go 1.19+ (for building from source)
- sudo privileges for system updates
- Optional: Timeshift (for snapshots)

## 🔧 Development

### Building

```bash
# Clone repository
git clone https://github.com/yourusername/uubu.git
cd uubu

# Build with version info
make build

# Run tests
make test

# Check code coverage
make test-coverage

# Development mode (auto-rebuild)
make dev
```

### Testing

```bash
# Run all tests
make test

# Run tests with race detection
make test-verbose

# Quick tests (no integration)
make test-short

# Benchmarks
make bench
```

## 📦 Project Structure

```
uubu/
├── main.go           # Main application
├── main_test.go      # Unit tests
├── Makefile          # Build automation
├── go.mod            # Go module file
├── README.md         # This file
└── LICENSE           # MIT license
```

## 🚦 Safety Features

- **Root Prevention**: Refuses to run as root user
- **Internet Check**: Verifies connectivity before updates
- **Error Handling**: Graceful handling of command failures
- **Snapshot Support**: Optional system backup via Timeshift
- **Reboot Detection**: Warns when restart is required

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Nicolas DEOUX**
**NDXDev** (NDXDev@gmail.com)

## 🙏 Acknowledgments

- Original bash script inspiration
- Ubuntu/Kubuntu community
- Go programming language team

---

⭐ **Star this repository if you find it useful!**
