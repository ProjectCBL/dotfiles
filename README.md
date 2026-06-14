# Dotfiles

Personal development setup for macOS and Linux/Unix systems.

## What This Manages

- macOS packages, casks, taps, and VS Code extensions via `Brewfile`
- Linux prerequisites via the local package manager where supported
- Shell config via `zsh/`
- Git config via `git/`
- mise global runtime versions via `mise/`
- Neovim config via `nvim/`
- Neovide app settings via `neovide/`
- Obsidian vault clone during setup

Language runtimes are managed by mise, not Homebrew:

- Node
- Bun
- Python
- Go
- Erlang
- Elixir

## Setup

Clone the repo:

```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
```

Run setup:

```bash
./setup.sh
```

The setup script will:

- on macOS, install Homebrew if needed and run `brew bundle`
- on Linux, install `curl`, `git`, `stow`, `zsh`, and `mise` where supported
- link dotfiles with GNU Stow
- link Neovim config
- clone the Obsidian vault if missing on macOS
- run `mise install`

On Linux, the Obsidian vault clone is opt-in because private GitHub
authentication is often not available in headless shell sessions:

```bash
INSTALL_OBSIDIAN_VAULT=1 ./setup.sh
```

On NixOS, `mise install` is skipped by default. Several configured runtimes
build from source or use generic Linux binaries, which requires system-level
build tools and often `nix-ld`. To force the runtime install:

```bash
INSTALL_MISE_TOOLS=1 ./setup.sh
```

## Dry Run

Check macOS Homebrew packages without installing:

```bash
brew bundle check --file ~/dotfiles/Brewfile --no-upgrade --verbose
```

Preview Stow links:

```bash
cd ~/dotfiles
stow --dotfiles --simulate --verbose zsh git mise
```

Preview mise installs:

```bash
mise install --dry-run
```

## Layout

```text
dotfiles/
  Brewfile
  setup.sh
  zsh/
    .zshrc
    .zprofile
  git/
    .gitconfig
  mise/
    dot-config/
      mise/
        config.toml
  neovide/
    Library/
      Application Support/
        neovide/
          neovide-settings.json
  nvim/
```

The mise package uses Stow's `--dotfiles` convention:

```text
dot-config/mise/config.toml -> ~/.config/mise/config.toml
```

## Notes

Do not commit secrets, private keys, API tokens, `.env` files, or machine-specific credentials.

SSH keys, AWS credentials, npm tokens, and app login state should stay outside this repo.
