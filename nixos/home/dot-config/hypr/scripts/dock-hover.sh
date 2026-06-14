#!/usr/bin/env bash
set -eu

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
pid_file="$runtime_dir/waybar-dock.pid"
show_distance=72
hide_distance=140
state="hidden"

monitor_height() {
  hyprctl monitors | awk '
    /^[[:space:]]*[0-9]+x[0-9]+@/ {
      split($1, dims, "x")
      split(dims[2], h, "@")
      height = h[1]
    }
    /focused: yes/ {
      print height
      found = 1
      exit
    }
    END {
      if (!found && height != "") print height
    }
  '
}

cursor_y() {
  hyprctl cursorpos | awk -F'[, ]+' '{ print $2 }'
}

signal_dock() {
  signal="$1"
  [ -s "$pid_file" ] || return 0
  pid="$(cat "$pid_file")"
  kill -0 "$pid" 2>/dev/null || return 0
  kill "-$signal" "$pid" 2>/dev/null || true
}

while true; do
  height="$(monitor_height)"
  y="$(cursor_y)"

  if [ -n "$height" ] && [ -n "$y" ]; then
    distance=$((height - y))
    if [ "$distance" -le "$show_distance" ] && [ "$state" = "hidden" ]; then
      signal_dock USR1
      state="visible"
    elif [ "$distance" -gt "$hide_distance" ] && [ "$state" = "visible" ]; then
      signal_dock USR2
      state="hidden"
    fi
  fi

  sleep 0.08
done
