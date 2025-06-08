# dotfiles-bash-utils

My personal collection of bash utilities and shortcuts.

## Installation

```bash
git clone https://github.com/bababubudev/dotfiles-bash-utils.git
cd dotfiles-bash-utils

# Depending on the shell type
chmod +x install_zsh.sh
./install_zsh.sh

chmod +x install.sh
./install.sh

source ~/.bashrc

source ~/.zshrc
```

## What You Get

### Navigation
- **`ll`** :  `ls -la`
- **`cdup <dir>`** : Navigate up to find parent directory by name
- **`cddown <dir>`** : Navigate down to find subdirectory by name

### Data Display
- **`table <csv_file>`** - Display CSV files in neat tabular format

### Port Management
- **`lookport <port>`** - Show processes using specific port
- **`killport <port>`** - Kill processes on specific port (with confirmation)

### Extras
- **`tzone <time> <timezone>`** - Timezone conversion

## Usage Examples

```bash
# Navigate to parent 'project' directory from anywhere in the tree
cdup project

# Find and enter 'src' directory anywhere below current location
cddown src

# Display CSV data as a formatted table with custom delimiter
table data.csv
table data.tsv $'\t'

# Check what's running on port 3000
lookport 3000

# Kill processes on port 8080
killport 8080

# Timezone conversion from pst to eest or from local to pst
tzone 2:00 EST	        -Convert 2:00 EST to local time
tzone --to 2:00 EST UTC	-Convert 2:00 EST to UTC
tzone --to PST	        -Convert current local time to PST
```

## What It Does

The installer:
- Creates utilities in `~/.local/bin`
- Adds custom functions to `~/.bash_functions`
- Updates your `~/.bashrc` or `~/.zshrc` safely (no duplicates on re-runs)
- Installs required system packages (`net-tools`, `lsof`)
- Makes everything executable and ready to use

## Installation Notes

- **Personal setup**: Designed for my WSL Debian environment
- **Idempotent**: Run multiple times safely - no duplicate entries
- **Non-destructive**: Only adds, never modifies existing configurations
- **Confirmation prompts**: `killport` asks before terminating processes

## Requirements

- Debian/Ubuntu-based system (or WSL)
- Bash shell or Zsh shell
- `sudo` access for package installation

## File Structure

```
~/.local/bin/
├── table      # CSV table formatter
├── lookport   # Port process viewer
├── killport   # Port process killer
└── tzone      # Timezone converter

~/.bash_functions            # Navigation functions (cdup, cddown)
~/.bashrc | ~/.zshrc         # Updated with aliases and sourcing
```

## Personal Project

This is my personal dotfiles repository for bash utilities. Feel free to fork and adapt for your own use!

## License

MIT License - use freely in your projects.
