#!/bin/sh

BATTERY_INFO="$(pmset -g batt)"

PERCENTAGE="$(
  printf '%s\n' "$BATTERY_INFO" |
    grep -Eo '[0-9]+%' |
    head -1 |
    tr -d '%'
)"

[[ -z "$PERCENTAGE" ]] && PERCENTAGE="?"

if printf '%s\n' "$BATTERY_INFO" | grep -q "AC Power"; then
  ICON="󰂄"
elif [[ "$PERCENTAGE" != "?" ]] && (( PERCENTAGE >= 80 )); then
  ICON="󰁹"
elif [[ "$PERCENTAGE" != "?" ]] && (( PERCENTAGE >= 50 )); then
  ICON="󰁾"
elif [[ "$PERCENTAGE" != "?" ]] && (( PERCENTAGE >= 20 )); then
  ICON="󰁻"
else
  ICON="󰂎"
fi

sketchybar --set "$NAME" \
  icon="$ICON" \
  label="${PERCENTAGE}%"
