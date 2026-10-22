#!/usr/bin/env bash
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[info]${NC} $1"; }
success() { echo -e "${GREEN}[ok]${NC} $1"; }
error()   { echo -e "${RED}[error]${NC} $1"; exit 1; }

THEME_NAME="Noctalia-Tela"
ICONS_DIR="$HOME/.local/share/icons"
NOCTALIA_DIR="$HOME/.config/noctalia"
TEMPLATES_DIR="$NOCTALIA_DIR/templates"
CACHE_DIR="$HOME/.cache/noctalia"
THEME_DIR="$ICONS_DIR/$THEME_NAME"
TMP_DIR="$HOME/.cache/noctalia-dynamic-icons/tela"

clear
echo -e "${BLUE}"
echo "    _   __           __      ___          ______     __"
echo "   / | / /___  _____/ /___  / (_)___ _   /_  __/__  / /___ _"
echo "  /  |/ / __ \/ ___/ __/ / / / / __ \`/    / / / _ \/ / __ \`/"
echo " / /|  / /_/ / /__/ /_/ /_/ / / /_/ /    / / /  __/ / /_/ / "
echo "/_/ |_/\____/\___/\__/\__,_/_/\__,_/    /_/  \___/_/\__,_/  "
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

# --- PREPARACIÓN Y DESCARGA ---
mkdir -p "$HOME/.cache/noctalia-dynamic-icons"
if [ ! -d "$TMP_DIR/.git" ]; then
    info "Cloning repository (will be cached)..."
    rm -rf "$TMP_DIR"
    git clone --depth 1 "https://github.com/vinceliuice/Tela-icon-theme.git" "$TMP_DIR" || error "Download failed"
else
    info "Updating local cache..."
    git -C "$TMP_DIR" pull -q --rebase || true
fi
TDIR="$TMP_DIR"

# --- INSTALACIÓN OFICIAL ---
info "Running official installer for Tela..."
rm -rf "$THEME_DIR"
bash "$TDIR/install.sh" -d "$ICONS_DIR" -n "Noctalia-Tela"
rm -rf "$ICONS_DIR/Noctalia-Tela-dark" "$ICONS_DIR/Noctalia-Tela-light"

[ -d "$THEME_DIR" ] || error "The installer did not create $THEME_NAME"

# --- PREPARACIÓN PARA NOCTALIA ---
info "Configuring internal Git for icons..."
cd "$THEME_DIR"
git init -q
git add .
git commit -q -m "original"
git tag "original"

# --- CREACIÓN DEL SCRIPT DE APLICACIÓN ---
info "Creating template for Noctalia..."
mkdir -p "$TEMPLATES_DIR"
cat > "$TEMPLATES_DIR/${THEME_NAME}.sh" << 'EOF'
#!/usr/bin/env bash
PRI="{{colors.primary.default.hex}}"
C1="${PRI:1}"
THEME_NAME="Noctalia-Tela"
T_DIR="$HOME/.local/share/icons/$THEME_NAME"
BRANCH="color-${C1}"

if [[ ! -d "$T_DIR/.git" ]]; then
    git -C "$T_DIR" init -q
    git -C "$T_DIR" add -A
    git -C "$T_DIR" commit -q -m "original"
    git -C "$T_DIR" tag "original"
    git -C "$T_DIR" checkout -q -b "original"
fi

if git -C "$T_DIR" show-ref --quiet "refs/heads/$BRANCH"; then
    git -C "$T_DIR" checkout -q "$BRANCH"
else
    git -C "$T_DIR" checkout -q "original"
    git -C "$T_DIR" checkout -q -b "$BRANCH"

    find "$T_DIR" -name "*.svg" -path "*/places/*" -type f -print0 | xargs -0 -P $(nproc) sed -i \
        -e "s/\.ColorScheme-Highlight { color:#[0-9a-fA-F]\{6\}/\.ColorScheme-Highlight { color:#${C1}/gI" \
        -e "s/\.ColorScheme-Text { color:#[0-9a-fA-F]\{6\}/\.ColorScheme-Text { color:#${C1}/gI" \
        -e "s/fill=\"currentColor\"/fill=\"#${C1}\"/gI"

    git -C "$T_DIR" add -A
    git -C "$T_DIR" commit -q -m "$PRI"
fi

gtk-update-icon-cache -f -t "$T_DIR" 2>/dev/null
CURRENT=$(gsettings get org.gnome.desktop.interface icon-theme | tr -d "'")
if [[ "$CURRENT" == "$THEME_NAME" ]]; then
    gsettings set org.gnome.desktop.interface icon-theme "hicolor" 2>/dev/null
    sleep 0.3
    gsettings set org.gnome.desktop.interface icon-theme "$THEME_NAME" 2>/dev/null
fi

gio set ~/Escritorio metadata::custom-icon-name "user-desktop" 2>/dev/null || true
gio set ~/Desktop metadata::custom-icon-name "user-desktop" 2>/dev/null || true
EOF

# --- VINCULACIÓN CON EL ARCHIVO TOML ---
info "Registering in templates.toml..."
sed -i "/\[theme.templates.user.${THEME_NAME,,}\]/,+4d" "$NOCTALIA_DIR/templates.toml" 2>/dev/null || true
cat >> "$NOCTALIA_DIR/templates.toml" << EOF

[theme.templates.user.${THEME_NAME,,}]
input_path  = "~/.config/noctalia/templates/${THEME_NAME}.sh"
output_path = "~/.cache/noctalia/${THEME_NAME}-apply.sh"
post_hook   = "bash ~/.cache/noctalia/${THEME_NAME}-apply.sh"
EOF

gsettings set org.gnome.desktop.interface icon-theme "$THEME_NAME"
gio set ~/Escritorio metadata::custom-icon-name "user-desktop" 2>/dev/null || true
gio set ~/Desktop metadata::custom-icon-name "user-desktop" 2>/dev/null || true


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
