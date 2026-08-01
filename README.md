# Dotfiles

Minimal dotfiles manager for my configs.
Currently i'm using Arch and MacOS, but it should work with other distros.

## What it does

- Manages modules through `dot.sh`
- Installs and removes modules

## Layout

- `dot.sh` - entrypoint for install, uninstall, and status
- `.utils/` - shared helpers used by the module scripts

## Usage

Install a module:

```bash
./dot.sh install zsh
```

Remove a module:

```bash
./dot.sh uninstall zsh
```

Check installed modules:

```bash
./dot.sh status
```

