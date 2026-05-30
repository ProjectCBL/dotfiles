#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
OBSIDIAN_VAULT_REPO="https://github.com/ProjectCBL/obsidian-vault.git"
OBSIDIAN_VAULT_DIR="$HOME/Documents/Obsidian Vault"

log() {
  printf "\n==> %s\n" "$1"
}

abort() {
  printf "error: %s\n" "$1" >&2
  exit 1
}

canonical_path() {
  local path="$1"
  local dir
  local base

  dir="$(dirname "$path")"
  base="$(basename "$path")"
  printf "%s/%s\n" "$(cd "$dir" && pwd -P)" "$base"
}

canonical_link_target() {
  local link="$1"
  local current

  current="$(readlink "$link")"
  if [[ "$current" != /* ]]; then
    current="$(dirname "$link")/$current"
  fi
  canonical_path "$current"
}

backup_target() {
  local target="$1"
  local source="$2"

  if [[ -L "$target" ]]; then
    local current
    current="$(canonical_link_target "$target")"
    [[ "$current" == "$(canonical_path "$source")" ]] && return 0
    abort "$target is already a symlink to $current"
  fi

  [[ -e "$target" ]] || return 0

  if [[ -d "$target" ]]; then
    if ! diff -qr "$source" "$target" >/dev/null; then
      abort "$target exists and differs from $source"
    fi
  else
    if ! cmp -s "$source" "$target"; then
      abort "$target exists and differs from $source"
    fi
  fi

  mkdir -p "$BACKUP_DIR$(dirname "$target")"
  mv "$target" "$BACKUP_DIR$target"
}

ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi

  log "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

load_homebrew() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

link_stow_packages() {
  local packages=(zsh git mise)

  backup_target "$HOME/.zshrc" "$DOTFILES_DIR/zsh/.zshrc"
  backup_target "$HOME/.zprofile" "$DOTFILES_DIR/zsh/.zprofile"
  backup_target "$HOME/.gitconfig" "$DOTFILES_DIR/git/.gitconfig"
  backup_target "$HOME/.config/mise/config.toml" "$DOTFILES_DIR/mise/dot-config/mise/config.toml"

  log "Linking shell, git, and mise config"
  stow --dir "$DOTFILES_DIR" --target "$HOME" --dotfiles --restow "${packages[@]}"
}

link_neovim() {
  local source="$DOTFILES_DIR/nvim"
  local target="$HOME/.config/nvim"

  [[ -d "$source" ]] || return 0

  backup_target "$target" "$source"
  [[ -e "$target" || -L "$target" ]] && return 0
  mkdir -p "$HOME/.config"

  log "Linking Neovim config"
  ln -s "$source" "$target"
}

clone_obsidian_vault() {
  if [[ -d "$OBSIDIAN_VAULT_DIR/.git" ]]; then
    log "Obsidian vault already exists"
    return 0
  fi

  if [[ -e "$OBSIDIAN_VAULT_DIR" ]]; then
    abort "$OBSIDIAN_VAULT_DIR exists but is not a Git checkout"
  fi

  mkdir -p "$(dirname "$OBSIDIAN_VAULT_DIR")"

  log "Cloning Obsidian vault"
  git clone "$OBSIDIAN_VAULT_REPO" "$OBSIDIAN_VAULT_DIR"
}

main() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    abort "this setup script currently supports macOS only"
  fi

  ensure_homebrew
  load_homebrew

  log "Installing Homebrew bundle"
  brew bundle --file "$DOTFILES_DIR/Brewfile"

  command -v stow >/dev/null 2>&1 || abort "stow was not installed"
  command -v mise >/dev/null 2>&1 || abort "mise was not installed"

  link_stow_packages
  link_neovim
  clone_obsidian_vault

  log "Installing mise tools"
  mise install

  log "Done"
  printf "Open a new terminal or run: source ~/.zshrc\n"
}

main "$@"
