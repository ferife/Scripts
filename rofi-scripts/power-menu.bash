#!/usr/bin/env bash

# This script is to be used in combination with rofi-wayland to open a power menu from my waybar

chosen=$(printf "Shut down\nReboot\nCancel" | rofi -dmenu -i)

case "$chosen" in
  "Shut Down")
    shutdown now
    ;;
  "Reboot")
    reboot
    ;;
  "Cancel")
    exit 0
    ;;
  *)
    exit 1
    ;;
esac
