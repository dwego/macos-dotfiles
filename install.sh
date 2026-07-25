#!/usr/bin/env bash

set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SUFFIX="backup-$(date +%Y%m%d-%H%M%S)"

bold='\033[1m'
blue='\033[38;2;136;192;208m'
muted='\033[38;2;104;113;132m'
yellow='\033[38;2;199;185;157m'
reset='\033[0m'

info() {
  printf "%b==>%b %s\n" "$blue$bold" "$reset" "$1"
}

warn() {
  printf "%bwarning:%b %s\n" "$yellow$bold" "$reset" "$1" >&2
}

die() {
  printf "%berror:%b %s\n" "$yellow$bold" "$reset" "$1" >&2
  exit 1
}

backup_path() {
  local path="$1"

  if [[ -e "$path" || -L "$path" ]]; then
    local backup="${path}.${BACKUP_SUFFIX}"
    warn "Backing up $path to $backup"
    mv "$path" "$backup"
  fi
}

link_file() {
  local source="$1"
  local target="$2"

  [[ -f "$source" ]] || die "Missing file: $source"
  mkdir -p "$(dirname "$target")"

  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    return
  fi

  backup_path "$target"
  ln -s "$source" "$target"
  printf "  linked %s -> %s\n" "$target" "$source"
}

link_directory() {
  local source="$1"
  local target="$2"

  [[ -d "$source" ]] || die "Missing directory: $source"
  mkdir -p "$(dirname "$target")"

  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    return
  fi

  backup_path "$target"
  ln -s "$source" "$target"
  printf "  linked %s -> %s\n" "$target" "$source"
}

install_formula() {
  local formula="$1"

  if brew list --formula "$formula" >/dev/null 2>&1; then
    printf "  formula already installed: %s\n" "$formula"
  else
    brew install "$formula"
  fi
}

install_cask() {
  local cask="$1"

  if brew list --cask "$cask" >/dev/null 2>&1; then
    printf "  cask already installed: %s\n" "$cask"
  else
    brew install --cask "$cask"
  fi
}

[[ "$(uname -s)" == "Darwin" ]] || die "This setup supports macOS only."
[[ "$EUID" -ne 0 ]] || die "Run this script as your normal user, not with sudo."

macos_major="$(sw_vers -productVersion | cut -d. -f1)"
if [[ "$macos_major" =~ ^[0-9]+$ ]] && (( macos_major < 13 )); then
  die "Ghostty requires macOS 13 or newer."
fi

if ! command -v brew >/dev/null 2>&1; then
  cat >&2 <<'MSG'
Homebrew is required but was not found.
Install it from https://brew.sh, reopen the terminal, and run ./install.sh again.
MSG
  exit 1
fi

eval "$(brew shellenv)"

info "Installing command-line tools"
install_formula starship
install_formula zsh-autosuggestions
install_formula zsh-syntax-highlighting
install_formula blueutil

info "Installing applications and fonts"
install_cask ghostty
install_cask karabiner-elements
install_cask font-jetbrains-mono-nerd-font

info "Installing SketchyBar"
brew tap FelixKratz/formulae >/dev/null
if brew help trust >/dev/null 2>&1; then
  brew trust --formula felixkratz/formulae/sketchybar >/dev/null
fi

if brew list --formula sketchybar >/dev/null 2>&1; then
  printf "  formula already installed: sketchybar\n"
else
  brew install felixkratz/formulae/sketchybar
fi

info "Preparing executable files"
[[ -d "$REPO_DIR/bin" ]] && chmod +x "$REPO_DIR/bin/"* 2>/dev/null || true
[[ -f "$REPO_DIR/sketchybar/sketchybarrc" ]] && chmod +x "$REPO_DIR/sketchybar/sketchybarrc"
[[ -d "$REPO_DIR/sketchybar/plugins" ]] && chmod +x "$REPO_DIR/sketchybar/plugins/"*.sh 2>/dev/null || true

info "Linking Ghostty"
GHOSTTY_MAC_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
mkdir -p "$GHOSTTY_MAC_DIR"

# Avoid an older XDG config being loaded before the macOS-specific config.
for stale_config in \
  "$HOME/.config/ghostty/config" \
  "$HOME/.config/ghostty/config.ghostty"; do
  if [[ -e "$stale_config" || -L "$stale_config" ]]; then
    backup_path "$stale_config"
  fi
done

link_file \
  "$REPO_DIR/ghostty/config.ghostty" \
  "$GHOSTTY_MAC_DIR/config.ghostty"

info "Linking Starship and Zsh"
link_file "$REPO_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
link_file "$REPO_DIR/shell/zshrc" "$HOME/.zshrc"

info "Linking SketchyBar"
link_directory "$REPO_DIR/sketchybar" "$HOME/.config/sketchybar"

info "Installing Karabiner rules"
KARABINER_ASSETS="$HOME/.config/karabiner/assets/complex_modifications"
mkdir -p "$KARABINER_ASSETS"

if [[ -f "$REPO_DIR/karabiner/assets/complex_modifications/super-key.json" ]]; then
  link_file \
    "$REPO_DIR/karabiner/assets/complex_modifications/super-key.json" \
    "$KARABINER_ASSETS/super-key.json"
else
  warn "Karabiner rule not found; skipping Super Key installation."
fi

# A full Karabiner config is optional. When present, it makes enabled rules portable too.
if [[ -f "$REPO_DIR/karabiner/karabiner.json" ]]; then
  link_file "$REPO_DIR/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
fi

info "Starting SketchyBar"
if brew services list | grep -q '^sketchybar '; then
  brew services restart sketchybar
else
  brew services start sketchybar
fi

info "Opening applications for first-run permissions"
open -a Ghostty >/dev/null 2>&1 || true
open -a Karabiner-Elements >/dev/null 2>&1 || true

printf "\n%bInstallation complete.%b\n\n" "$blue$bold" "$reset"
printf "%bFinish these macOS steps:%b\n" "$bold" "$reset"
printf "  1. Grant the permissions requested by Karabiner-Elements.\n"
printf "  2. In Karabiner-Elements, enable the rules from \"macOS Super Key\" if no full karabiner.json was installed.\n"
printf "  3. Set the native menu bar to automatically hide if you want SketchyBar to be the main bar.\n"
printf "  4. Run: exec zsh\n"
printf "\n%bUseful commands:%b shortcuts, keys, sketchybar --reload\n" "$muted" "$reset"

for app in RustRover Claude; do
  if ! open -Ra "$app" >/dev/null 2>&1; then
    warn "$app is not installed, so its Super Key launcher will not work yet."
  fi
done
