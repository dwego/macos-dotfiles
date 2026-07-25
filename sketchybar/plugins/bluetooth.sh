#!/bin/bash

BLUEUTIL="/opt/homebrew/bin/blueutil"

update() {
  POWER="$("$BLUEUTIL" --power 2>/dev/null)"

  if [[ "$POWER" == "1" ]]; then
    sketchybar --set "$NAME" \
      icon="󰂯" \
      icon.color=0xff88c0d0 \
      label="On"
  else
    sketchybar --set "$NAME" \
      icon="󰂲" \
      icon.color=0xff687184 \
      label="Off"
  fi
}

case "$SENDER" in
  mouse.clicked)
    case "$BUTTON" in
      left)
        CURRENT="$("$BLUEUTIL" --power)"

        if [[ "$CURRENT" == "1" ]]; then
          "$BLUEUTIL" --power 0
        else
          "$BLUEUTIL" --power 1
        fi
        ;;

      right)
        open "x-apple.systempreferences:com.apple.BluetoothSettings"
        ;;
    esac
    ;;
esac

update
