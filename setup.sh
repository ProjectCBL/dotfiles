#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
OBSIDIAN_VAULT_REPO="https://github.com/ProjectCBL/obsidian-vault.git"
OBSIDIAN_VAULT_DIR="$HOME/Documents/Obsidian Vault"
OS_NAME="$(uname -s)"

log() {
  printf "\n==> %s\n" "$1"
}

abort() {
  printf "error: %s\n" "$1" >&2
  exit 1
}

is_nixos() {
  [[ -r /etc/os-release ]] && grep -q '^ID=nixos$' /etc/os-release
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

  if [[ -e "$target" && "$(canonical_path "$target")" == "$(canonical_path "$source")" ]]; then
    return 0
  fi

  if [[ -L "$target" ]]; then
    local current
    current="$(canonical_link_target "$target")"
    [[ "$current" == "$(canonical_path "$source")" ]] && return 0
    abort "$target is already a symlink to $current"
  fi

  [[ -e "$target" ]] || return 0

  mkdir -p "$BACKUP_DIR$(dirname "$target")"
  printf "Backing up %s to %s\n" "$target" "$BACKUP_DIR$target"
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

run_with_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

install_linux_packages() {
  local packages=(curl git stow zsh)

  if command -v nix-env >/dev/null 2>&1; then
    local nix_attrs=()

    command -v curl >/dev/null 2>&1 || nix_attrs+=(nixos.curl)
    command -v git >/dev/null 2>&1 || nix_attrs+=(nixos.git)
    command -v stow >/dev/null 2>&1 || nix_attrs+=(nixos.stow)
    command -v zsh >/dev/null 2>&1 || nix_attrs+=(nixos.zsh)

    [[ "${#nix_attrs[@]}" -eq 0 ]] && return 0

    log "Installing Linux packages with nix-env"
    nix-env -iA "${nix_attrs[@]}"
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    log "Installing Linux packages with apt"
    run_with_sudo apt-get update
    run_with_sudo apt-get install -y "${packages[@]}"
    return 0
  fi

  if command -v dnf >/dev/null 2>&1; then
    log "Installing Linux packages with dnf"
    run_with_sudo dnf install -y "${packages[@]}"
    return 0
  fi

  if command -v yum >/dev/null 2>&1; then
    log "Installing Linux packages with yum"
    run_with_sudo yum install -y "${packages[@]}"
    return 0
  fi

  if command -v pacman >/dev/null 2>&1; then
    log "Installing Linux packages with pacman"
    run_with_sudo pacman -Sy --needed --noconfirm "${packages[@]}"
    return 0
  fi

  if command -v apk >/dev/null 2>&1; then
    log "Installing Linux packages with apk"
    run_with_sudo apk add "${packages[@]}"
    return 0
  fi

  if command -v zypper >/dev/null 2>&1; then
    log "Installing Linux packages with zypper"
    run_with_sudo zypper install -y "${packages[@]}"
    return 0
  fi

  abort "could not find a supported Linux package manager; install curl, git, stow, and zsh, then rerun setup"
}

install_mise() {
  if command -v mise >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$OS_NAME" == "Linux" ]] && command -v nix-env >/dev/null 2>&1; then
    log "Installing mise with nix-env"
    nix-env -iA nixos.mise
    return 0
  fi

  command -v curl >/dev/null 2>&1 || abort "curl is required to install mise"

  log "Installing mise"
  curl https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
}

link_stow_packages() {
  local packages=(zsh git quickshell)

  backup_target "$HOME/.zshrc" "$DOTFILES_DIR/zsh/.zshrc"
  backup_target "$HOME/.zprofile" "$DOTFILES_DIR/zsh/.zprofile"
  backup_target "$HOME/.gitconfig" "$DOTFILES_DIR/git/.gitconfig"
  backup_target "$HOME/.config/quickshell" "$DOTFILES_DIR/quickshell/dot-config/quickshell"

  if [[ "$OS_NAME" == "Darwin" && -e "$DOTFILES_DIR/neovide/Library/Application Support/neovide/neovide-settings.json" ]]; then
    backup_target "$HOME/Library/Application Support/neovide/neovide-settings.json" "$DOTFILES_DIR/neovide/Library/Application Support/neovide/neovide-settings.json"
    packages+=(neovide)
  fi

  log "Linking shell, git, Quickshell, and mise config"
  stow --dir "$DOTFILES_DIR" --target "$HOME" --dotfiles --restow "${packages[@]}"
}

link_mise_config() {
  local source="$DOTFILES_DIR/mise/dot-config/mise/config.toml"
  local target="$HOME/.config/mise/config.toml"

  [[ -f "$source" ]] || abort "missing mise config: $source"

  mkdir -p "$(dirname "$target")"
  backup_target "$target" "$source"
  [[ -e "$target" || -L "$target" ]] && return 0

  log "Linking mise config"
  ln -s "$source" "$target"
}

configure_local_git() {
  local target="$HOME/.gitconfig.local"

  [[ -e "$target" ]] && return 0

  log "Writing machine-local Git config"
  if [[ "$OS_NAME" == "Darwin" ]]; then
    printf "[credential]\n\thelper = osxkeychain\n" > "$target"
  elif command -v gh >/dev/null 2>&1; then
    printf "[credential \"https://github.com\"]\n\thelper = !gh auth git-credential\n[credential]\n\thelper = cache\n" > "$target"
  else
    printf "[credential]\n\thelper = cache\n" > "$target"
  fi
}

install_mise_tools() {
  if is_nixos && [[ "${INSTALL_MISE_TOOLS:-0}" != "1" ]]; then
    log "Skipping mise tool installation on NixOS"
    printf "Set INSTALL_MISE_TOOLS=1 to run mise install anyway.\n"
    printf "NixOS may also require system-level build tools and nix-ld for generic Linux binaries.\n"
    return 0
  fi

  log "Installing mise tools"
  mise install
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
  if [[ "$OS_NAME" == "Linux" && "${INSTALL_OBSIDIAN_VAULT:-0}" != "1" ]]; then
    log "Skipping Obsidian vault clone on Linux"
    printf "Set INSTALL_OBSIDIAN_VAULT=1 to clone %s during setup.\n" "$OBSIDIAN_VAULT_REPO"
    return 0
  fi

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
  case "$OS_NAME" in
    Darwin)
      ensure_homebrew
      load_homebrew

      log "Installing Homebrew bundle"
      brew bundle --file "$DOTFILES_DIR/Brewfile"
      ;;
    Linux)
      install_linux_packages
      install_mise
      ;;
    *)
      abort "unsupported OS: $OS_NAME"
      ;;
  esac

  command -v stow >/dev/null 2>&1 || abort "stow was not installed"
  command -v mise >/dev/null 2>&1 || abort "mise was not installed"

  link_stow_packages
  link_mise_config
  configure_local_git
  link_neovim
  clone_obsidian_vault

  install_mise_tools

  log "Done"
  printf "Open a new terminal or run: source ~/.zshrc\n"
}

main "$@"
