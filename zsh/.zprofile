if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Language runtimes are managed by mise in ~/.config/mise/config.toml.

export EDITOR="nvim"
export VISUAL="nvim"
# mise itself is activated from ~/.zshrc for interactive shells.
