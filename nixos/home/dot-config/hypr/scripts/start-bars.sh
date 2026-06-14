#!/usr/bin/env bash
set -eu

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

pkill -u "$(id -u)" waybar 2>/dev/null || true
pkill -u "$(id -u)" -f "$config_home/hypr/scripts/dock-hover.sh" 2>/dev/null || true

setsid -f waybar \
  --config "$config_home/waybar/top.jsonc" \
  --style "$config_home/waybar/style.css" \
  >/tmp/waybar-top-projectcbl.log 2>&1
