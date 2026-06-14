# NixOS Dotfiles

This directory tracks the NixOS host configuration and Linux desktop user
configuration for `projectcbl`.

## Layout

```text
nixos/
  system/
    configuration.nix
    hardware-configuration.nix
  home/
    dot-config/
      ghostty/
      hypr/
      qtile/
      tmux/
      waybar/
      wofi/
```

The live system files in `/etc/nixos` and selected directories in
`~/.config` are symlinks back to these files.

After changing `nixos/system/configuration.nix`, apply it with:

```bash
sudo nixos-rebuild switch
```

After changing Hyprland config, reload it with:

```bash
hyprctl reload
```
