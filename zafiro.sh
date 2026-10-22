#!/usr/bin/env bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[info]${NC} $1"; }
success() { echo -e "${GREEN}[ok]${NC} $1"; }
error()   { echo -e "${RED}[error]${NC} $1"; exit 1; }

THEME_NAME="Noctalia-Zafiro"
ICONS_DIR="$HOME/.local/share/icons"
NOCTALIA_DIR="$HOME/.config/noctalia"
TEMPLATES_DIR="$NOCTALIA_DIR/templates"
CACHE_DIR="$HOME/.cache/noctalia"
THEME_DIR="$ICONS_DIR/$THEME_NAME"
GIT_URL="https://github.com/zayronxio/Zafiro-icons.git"
TMP_DIR="$HOME/.cache/noctalia-dynamic-icons/zafiro"

clear
echo -e "${BLUE}"
echo " ______         __ _           "
echo "|__  / |       / _(_)          "
echo "   / /| |__   | |_ _ _ __ ___  "
echo "  / / | '_ \  |  _| | '__/ _ \ "
echo " / /__| | | | | | | | | | (_) |"
echo "/_____|_| |_| |_| |_|_|  \___/ "
echo -e "${NC}"

echo -e "${BLUE}=== EXCLUSIVE INSTALLER: $THEME_NAME ===${NC}"
echo "1) Install $THEME_NAME"
echo "2) TOTAL CLEANUP"
read -r -p "Select an option [1-2]: " OPT

if [ "$OPT" == "2" ]; then
    info "Cleaning installation of $THEME_NAME..."
    rm -rf "$THEME_DIR"
    rm -rf "$TEMPLATES_DIR/${THEME_NAME}.sh" "$CACHE_DIR/${THEME_NAME}-apply.sh"
    sed -i "/\[theme.templates.user.${THEME_NAME,,}\]/,+4d" "$NOCTALIA_DIR/templates.toml" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "Adwaita"
    success "Cleanup complete."; exit 0
fi

info "Checking dependencies..."
for cmd in git curl gsettings gtk-update-icon-cache; do
    command -v "$cmd" &>/dev/null || error "Missing dependency: $cmd"
done

mkdir -p "$ICONS_DIR" "$TEMPLATES_DIR" "$CACHE_DIR" "$HOME/.cache/noctalia-dynamic-icons"

if [ ! -d "$TMP_DIR/.git" ]; then
    info "Cloning repository (will be cached)..."
    rm -rf "$TMP_DIR"
    git clone --depth 1 "$GIT_URL" "$TMP_DIR" || error "Download failed"
else
    info "Updating local cache..."
    git -C "$TMP_DIR" pull -q --rebase || true
fi

info "Installing base Zafiro..."
rm -rf "$THEME_DIR"
cp -r "$TMP_DIR/Dark" "$THEME_DIR"
# Renombrar internamente
sed -i "s/^Name=.*/Name=$THEME_NAME/" "$THEME_DIR/index.theme" 2>/dev/null || true

info "Initializing dynamic engine (Git)..."
git -C "$THEME_DIR" init -q
git -C "$THEME_DIR" add -A
git -C "$THEME_DIR" commit -q -m "original"
git -C "$THEME_DIR" tag "original"

info "Installing color template for Noctalia..."
cat > "$TEMPLATES_DIR/${THEME_NAME}.sh" << 'TEMPLATE'
#!/usr/bin/env bash
PRIMARY="{{colors.primary.default.hex}}"
CONTAINER="{{colors.primary_container.default.hex}}"
COLOR="${PRIMARY:1}"
COLOR_DARK="${CONTAINER:1}"
THEME_NAME="Noctalia-Zafiro"
THEME_DIR="$HOME/.local/share/icons/$THEME_NAME"
BRANCH="color-${COLOR}-${COLOR_DARK}"

if git -C "$THEME_DIR" show-ref --quiet "refs/heads/$BRANCH"; then
    git -C "$THEME_DIR" checkout -q "$BRANCH"
else
    git -C "$THEME_DIR" checkout -q "original"
    git -C "$THEME_DIR" checkout -q -b "$BRANCH"
    
    # Zafiro usa #6f8a91 y #d8d8d8
    find "$THEME_DIR" -name "*.svg" -path "*/places/*" -type f -print0 | xargs -0 -P $(nproc) sed -i \
        -e "s/#6f8a91/#${COLOR_DARK}/gI" \
        -e "s/#d8d8d8/#${COLOR}/gI"
        
    git -C "$THEME_DIR" commit -q -am "color $BRANCH"
fi

gtk-update-icon-cache -f -t "$THEME_DIR" 2>/dev/null
CURRENT=$(gsettings get org.gnome.desktop.interface icon-theme | tr -d "'")
if [[ "$CURRENT" == "$THEME_NAME" ]]; then
    gsettings set org.gnome.desktop.interface icon-theme "hicolor" 2>/dev/null
    sleep 0.3
    gsettings set org.gnome.desktop.interface icon-theme "$THEME_NAME" 2>/dev/null
fi
TEMPLATE

info "Updating Noctalia configuration..."
sed -i "/\[theme.templates.user.${THEME_NAME,,}\]/,+4d" "$NOCTALIA_DIR/templates.toml" 2>/dev/null || true
cat >> "$NOCTALIA_DIR/templates.toml" << EOF

[theme.templates.user.${THEME_NAME,,}]
input_path  = "~/.config/noctalia/templates/$THEME_NAME.sh"
output_path = "~/.cache/noctalia/$THEME_NAME-apply.sh"
post_hook   = "bash ~/.cache/noctalia/$THEME_NAME-apply.sh"
EOF

gsettings set org.gnome.desktop.interface icon-theme "$THEME_NAME"

echo ""

# --- SYSTEM SYNCHRONIZATION ---
info "Synchronizing GTK3 and Fuzzel configurations..."
if [ -f "$HOME/.config/fuzzel/fuzzel.ini" ]; then
    sed -i "/^icon-theme=/d" "$HOME/.config/fuzzel/fuzzel.ini" 2>/dev/null || true
    sed -i "/^\[main\]/a icon-theme=$THEME_NAME" "$HOME/.config/fuzzel/fuzzel.ini" 2>/dev/null || true
fi

if [ -f "$HOME/.config/gtk-3.0/settings.ini" ]; then
    sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$THEME_NAME/" "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || true
fi

success "Installation of $THEME_NAME completed!"
info "Refresh your Noctalia color palette to apply changes."
