if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Language runtimes are managed by mise in ~/.config/mise/config.toml.
# mise itself is activated from ~/.zshrc for interactive shells.
