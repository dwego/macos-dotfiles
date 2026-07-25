#!/bin/sh

APP="$INFO"

if [[ -z "$APP" ]]; then
  APP="$(osascript -e \
    'tell application "System Events" to get name of first application process whose frontmost is true')"
fi

sketchybar --set "$NAME" label="$APP"
