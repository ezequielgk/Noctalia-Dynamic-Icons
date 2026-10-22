#!/usr/bin/env bash
set -e

# Colores para la terminal
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[info]${NC} $1"; }
success() { echo -e "${GREEN}[ok]${NC} $1"; }
error()   { echo -e "${RED}[error]${NC} $1"; exit 1; }

# Rutas
ICONS_DIR="$HOME/.local/share/icons"
NOCTALIA_DIR="$HOME/.config/noctalia"
TEMPLATES_DIR="$NOCTALIA_DIR/templates"
CACHE_DIR="$HOME/.cache/noctalia"
THEME_NAME="Noctalia-Flat"
THEME_DIR="$ICONS_DIR/$THEME_NAME"
TMP_DIR="$HOME/.cache/noctalia-dynamic-icons/flat-remix"

clear
# Arte ASCII solicitado
echo -e "${BLUE}"
echo "    _  __            __        ___              ________      __ "
echo "   / | / /___  _____/ /_____ _/ (_)___ _       / ____/ /___ _/ /_"
echo "  /  |/ / __ \/ ___/ __/ __ \`/ / / __ \`/_____/ /_  / / __ \`/ __/"
echo " / /|  / /_/ / /__/ /_/ /_/ / / / /_/ /_____/ __/ / / /_/ / /_  "
echo "/_/ |_/\____/\___/\__/\__,_/_/_/\__,_/     /_/   /_/\__,_/\__/  "
echo "                                                                "
echo -e "${NC}"

echo -e "${BLUE}=== EXCLUSIVE INSTALLER: $THEME_NAME ===${NC}"
echo "1) Install $THEME_NAME"
echo "2) TOTAL CLEANUP"
read -r -p "Select an option [1-2]: " OPT

if [ "$OPT" == "2" ]; then
    info "Cleaning installation of configuraciones previas..."
    rm -rf "$THEME_DIR" "$TEMPLATES_DIR/${THEME_NAME}.sh" "$CACHE_DIR/${THEME_NAME}-apply.sh"
    sed -i "/\[theme.templates.user.${THEME_NAME,,}\]/,+4d" "$NOCTALIA_DIR/templates.toml" 2>/dev/null || true
    success "Cleanup complete."; exit 0
fi

# --- CONFIGURACIÓN ESPECÍFICA ---
B_NAME="Flat Remix"
URL="https://github.com/daniruiz/flat-remix.git"
MATCH="Flat-Remix-Blue-Dark"

# --- PREPARACIÓN Y DESCARGA ---
mkdir -p "$HOME/.cache/noctalia-dynamic-icons"
if [ ! -d "$TMP_DIR/.git" ]; then
    info "Cloning repository (will be cached)..."
    rm -rf "$TMP_DIR"
    git clone --depth 1 "$URL" "$TMP_DIR" || error "Download failed"
else
    info "Updating local cache..."
    git -C "$TMP_DIR" pull -q --rebase || true
fi
SRC="$TMP_DIR/$MATCH"

# --- COPIA INTELIGENTE (Creando tema separado) ---
info "Creating structure for $THEME_NAME..."
rm -rf "$THEME_DIR"
cp -rL "$SRC" "$THEME_DIR" 2>/dev/null || true

# Copiar index.theme y renombrarlo internamente
cp "$SRC/index.theme" "$THEME_DIR/"
sed -i "s/^Name=.*/Name=$THEME_NAME/" "$THEME_DIR/index.theme"
sed -i "s/^Inherits=.*/Inherits=$MATCH,hicolor/" "$THEME_DIR/index.theme"

# --- SNAPSHOT GIT (Para reset de color) ---
info "Creating original snapshot for Noctalia..."
cd "$THEME_DIR"
git init -q
git add .
git commit -q -m "original"
git tag -f "original"

# --- SCRIPT APLICADOR DE COLOR (Template) ---
info "Creating template for Noctalia..."
mkdir -p "$TEMPLATES_DIR"
cat > "$TEMPLATES_DIR/${THEME_NAME}.sh" << 'EOF'
#!/usr/bin/env bash
PRI="{{colors.primary.default.hex}}"
C1="${PRI:1}"
T_DIR="$HOME/.local/share/icons/Noctalia-Flat"
BRANCH="color-${C1}"

if git -C "$T_DIR" show-ref --quiet "refs/heads/$BRANCH"; then
    git -C "$T_DIR" checkout -q "$BRANCH"
else
    git -C "$T_DIR" checkout -q "original"
    git -C "$T_DIR" checkout -q -b "$BRANCH"
    
CONTAINER="{{colors.primary_container.default.hex}}"
C_DARK="${CONTAINER:1}"
    
    # MOTOR DE COLOR PRECISO
    find "$T_DIR" -name "*.svg" -type f -print0 | xargs -0 -P $(nproc) sed -i -E \
        -e "s/367bf0/${C1}/gI" \
        -e "s/2b62c0/${C_DARK}/gI" \
        -e "s/357af0/${C1}/gI" \
        -e "s/8c42ab/${C_DARK}/gI"
        
    git -C "$T_DIR" commit -q -am "color $BRANCH"
fi

gtk-update-icon-cache -f -t "$T_DIR" 2>/dev/null
CURRENT=$(gsettings get org.gnome.desktop.interface icon-theme | tr -d "'")
if [[ "$CURRENT" == "$THEME_NAME" ]]; then
    gsettings set org.gnome.desktop.interface icon-theme "hicolor" 2>/dev/null
    sleep 0.3
    gsettings set org.gnome.desktop.interface icon-theme "$THEME_NAME" 2>/dev/null
fi
EOF

# --- VINCULACIÓN CON NOCTALIA ---
info "Actualizando templates.toml..."
sed -i "/\[theme.templates.user.${THEME_NAME,,}\]/,+4d" "$NOCTALIA_DIR/templates.toml" 2>/dev/null || true
cat >> "$NOCTALIA_DIR/templates.toml" << EOF

[theme.templates.user.${THEME_NAME,,}]
input_path  = "~/.config/noctalia/templates/${THEME_NAME}.sh"
output_path = "~/.cache/noctalia/${THEME_NAME}-apply.sh"
post_hook   = "bash ~/.cache/noctalia/${THEME_NAME}-apply.sh"
EOF

# Aplicar el tema inmediatamente
gsettings set org.gnome.desktop.interface icon-theme "$THEME_NAME"


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
