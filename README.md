# oocat

> **Sovereign syntax-highlighting file viewer and pager for the openOODA era.**  
> *A drop-in `bat` / `cat` replacement written in pure openOODA, featuring negative-trust capability security, syntax highlighting via `oote` themes, line numbering, range windowing, and a first-class Model Context Protocol (MCP) surface.*

Part of [openOODA-tools](https://github.com/openOODA-tools).

---

## 1. Installation

`oocat` has zero runtime dependencies. It compiles to a standalone native binary linked directly with libc.

### Universal Web Installer
Installs the standalone native binary to `/usr/local/bin` (or `~/.local/bin`):

```bash
curl -fsSL https://openooda-tools.github.io/oocat/install.sh | bash
```

### Debian / Ubuntu (APT)
```bash
# Automated via installer
curl -fsSL https://openooda-tools.github.io/oocat/install.sh | bash -s -- --apt

# Or manual package install
sudo dpkg -i oocat_0.1.0-1_amd64.deb
```

### Fedora / RHEL / CentOS (DNF)
```bash
# Automated via installer
curl -fsSL https://openooda-tools.github.io/oocat/install.sh | bash -s -- --dnf

# Or manual RPM install
sudo dnf install ./oocat-0.1.0-1.x86_64.rpm
```

### Arch Linux (PKGBUILD)
```bash
# Automated via installer
curl -fsSL https://openooda-tools.github.io/oocat/install.sh | bash -s -- --arch

# Or manual build via packaging/PKGBUILD
cd packaging && makepkg -si
```

### Clean Uninstaller
To cleanly remove `oocat` and any installed package manager entries:

```bash
# Automated via standalone uninstaller
curl -fsSL https://openooda-tools.github.io/oocat/uninstall.sh | bash

# Or via installer flag
curl -fsSL https://openooda-tools.github.io/oocat/install.sh | bash -s -- --uninstall

# Or preview removal without making changes (dry-run)
curl -fsSL https://openooda-tools.github.io/oocat/uninstall.sh | bash -s -- --dry-run
```

---

## 2. CLI Usage

```
usage: oocat [options] [FILE]...

Concatenate FILE(s) to standard output with syntax highlighting and line numbers.
With no FILE, or when FILE is -, read standard input.

Options:
  -n, --number             number all output lines
  -b, --number-nonblank    number nonempty output lines, overrides -n
  -s, --squeeze-blank      suppress repeated empty output lines
  -A, --show-all           display $ at end of each line, show tabs as ^I
  -r, --line-range <R>     only output lines within range (e.g. 10:30, :20, 50:)
      --style <STYLE>      display style: plain, numbers, grid, full [default: full]
      --color <WHEN>       colorize output: auto, always, never [default: auto]
      --no-color           disable syntax highlighting
      --mcp                run as Model Context Protocol stdio server
  -h, --help               display this help and exit
  -v, --version            output version information and exit
```

### Common Examples

```bash
# Display source file with syntax highlighting, line numbers, and file header
oocat main.oo

# Display specific line range
oocat main.oo -r 10:30

# Simple cat mode without frames or line numbers
oocat main.oo --style plain

# Standard UNIX pipe processing
git diff | oocat - --style numbers

# Squeeze repeated blank lines and number non-empty lines
oocat -s -b script.sh
```

---

## 3. Theming Integration (`oote`)

`oocat` automatically discovers and synchronizes visual presentation with [oote](https://github.com/openOODA-tools/oote):

- **Configuration File**: Reads `~/.openooda/theme.oot` with `$HOME` fallback.
- **Environment Overrides**: Respects `OODA_THEME` and `NO_COLOR`.
- **Supported Languages**: Built-in lexers for `openOODA`, `Shell`, `C/C++`, `JSON`, `Python`, and `Markdown`.

---

## 4. Model Context Protocol (MCP)

`oocat` includes a built-in JSON-RPC 2.0 MCP server over standard I/O for LLM coding agents:

```bash
oocat --mcp
```

### Supported Tools:
1. `oocat_view`: Safely inspects a file with syntax highlighting and bounded line ranges (`path`, `line_range`).
2. `oocat_highlight`: Formats arbitrary code snippets with `oote` syntax tokens for terminal rendering (`code`, `language`).

---

## 5. Security & Architecture

- **Zero Ambient Authority**: Written in pure openOODA with capability-bounded tokens (`&FsReadCap`, `&EnvCap`).
- **No Shell Escapes**: Pure native execution without `/bin/sh` invocations.
- **Page Rule & Academy Governance**: 100% compliant with the openOODA Academy and House Laws codified in [`AGENTS.md`](./AGENTS.md).

---

## 6. License

Apache License, Version 2.0. See [`LICENSE`](./LICENSE) for full text.