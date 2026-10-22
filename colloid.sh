#!/usr/bin/env bash
set -e

# Colores terminal
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[info]${NC} $1"; }
success() { echo -e "${GREEN}[ok]${NC} $1"; }
error()   { echo -e "${RED}[error]${NC} $1"; exit 1; }

# Nombres y Rutas
THEME_NAME="Noctalia-Colloid"
ICONS_DIR="$HOME/.local/share/icons"
NOCTALIA_DIR="$HOME/.config/noctalia"
TEMPLATES_DIR="$NOCTALIA_DIR/templates"
THEME_DIR="$ICONS_DIR/$THEME_NAME"
TMP_DIR="$HOME/.cache/noctalia-dynamic-icons/colloid"

clear
# Arte ASCII solicitado
echo -e "${BLUE}"
echo "    ____                                ______    ____      _     __"
echo "   / __ \__  ______  ____ _____ ___  (_)____            / ____/___  / / /___  (_)___/ /"
echo "  / / / / / / / __ \/ __ \`/ __ \`__ \/ / ___/  ______   / /   / __ \/ / / __ \/ / __  / "
echo " / /_/ / /_/ / / / / /_/ / / / / / / / /__   /_____/  / /___/ /_/ / / / /_/ / / /_/ /  "
echo "/_____/\__, /_/ /_/\__,_/_/ /_/ /_/_/\___/            \____/\____/_/_/\____/_/\__,_/   "
echo "      /____/                                                                           "
echo -e "${NC}"

echo -e "${BLUE}=== EXCLUSIVE INSTALLER: $THEME_NAME ===${NC}"
echo "1) Install $THEME_NAME"
echo "2) TOTAL CLEANUP"
read -r -p "Select an option [1-2]: " OPT

# --- OPCIÓN 2: DESINSTALACIÓN ---
if [ "$OPT" == "2" ]; then
    info "Removing $THEME_NAME..."
    rm -rf "$THEME_DIR" "$ICONS_DIR/${THEME_NAME}-Light" "$TEMPLATES_DIR/${THEME_NAME}.sh"
    sed -i "/\[theme.templates.user.${THEME_NAME,,}\]/,+4d" "$NOCTALIA_DIR/templates.toml" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "Adwaita"
    success "Cleanup complete."; exit 0
fi

# --- OPCIÓN 1: INSTALACIÓN ---
info "Starting installation of $THEME_NAME..."

# 1. Preparación y Descarga
mkdir -p "$HOME/.cache/noctalia-dynamic-icons"
if [ ! -d "$TMP_DIR/.git" ]; then
    info "Cloning repository (will be cached)..."
    rm -rf "$TMP_DIR"
    git clone --depth 1 "https://github.com/vinceliuice/Colloid-icon-theme.git" "$TMP_DIR" || error "Download failed"
else
    info "Updating local cache..."
    git -C "$TMP_DIR" pull -q --rebase || true
fi
CDIR="$TMP_DIR"

# 2. Instalador Oficial
bash "$CDIR/install.sh" -d "$ICONS_DIR" -n "$THEME_NAME" -t default -s default

# Resolver symlinks (Colloid enlaza internamente a las variantes Light/Dark)
cp -rL "$ICONS_DIR/$THEME_NAME" "$ICONS_DIR/${THEME_NAME}-tmp" 2>/dev/null || true
rm -rf "$ICONS_DIR/$THEME_NAME"
mv "$ICONS_DIR/${THEME_NAME}-tmp" "$ICONS_DIR/$THEME_NAME"

rm -rf "$ICONS_DIR/Noctalia-Colloid-Dark" "$ICONS_DIR/Noctalia-Colloid-Light"
rm -rf "$ICONS_DIR/Noctalia-Colloid-dark" "$ICONS_DIR/Noctalia-Colloid-light"

# 3. Snapshot de Git (Para permitir cambios de color infinitos)
cd "$THEME_DIR"
rm -rf .git
git init -q && git add . && git commit -q -m "original" && git tag -f "original"

# 4. Plantilla de Noctalia (Motor de color dinámico corregido)
info "Creating application template..."
mkdir -p "$TEMPLATES_DIR"
cat > "$TEMPLATES_DIR/${THEME_NAME}.sh" << 'EOF'
#!/usr/bin/env bash
PRI="{{colors.primary.default.hex}}"
C1="${PRI:1}"
T_DIR="$HOME/.local/share/icons/Noctalia-Colloid"

BRANCH="color-${C1}"
if git -C "$T_DIR" show-ref --quiet "refs/heads/$BRANCH"; then
    git -C "$T_DIR" checkout -q "$BRANCH"
else
    git -C "$T_DIR" checkout -q "original"
    git -C "$T_DIR" checkout -q -b "$BRANCH"
    
    # Reemplazo de color maestro multihilo
    find "$T_DIR" -name "*.svg" -type f -print0 | xargs -0 -P $(nproc) sed -i -E \
        -e "s/#60c0f0/#${C1}/gI" \
        -e "s/#5294e2/#${C1}/gI" \
        -e "s/fill:#[0-9a-fA-F]{6}/fill:#${C1}/gI" \
        -e "s/stop-color:#[0-9a-fA-F]{6}/stop-color:#${C1}/gI" \
        -e "s/style=\"fill:#[0-9a-fA-F]{6}/style=\"fill:#${C1}/gI" \
        -e "s/currentColor/#${C1}/gI"
        
    git -C "$T_DIR" commit -q -am "color $BRANCH"
fi

gtk-update-icon-cache -f -t "$T_DIR" 2>/dev/null
CURRENT=\$(gsettings get org.gnome.desktop.interface icon-theme | tr -d "'")
if [[ "\$CURRENT" == "Noctalia-Colloid" ]]; then
    gsettings set org.gnome.desktop.interface icon-theme "hicolor" 2>/dev/null
    sleep 0.2
    gsettings set org.gnome.desktop.interface icon-theme "Noctalia-Colloid" 2>/dev/null
fi
EOF

# 5. Registro en user-templates.toml (Adaptado para que Noctalia lo reconozca)
info "Registering in templates.toml..."
sed -i "/\[theme.templates.user.${THEME_NAME,,}\]/,+4d" "$NOCTALIA_DIR/templates.toml" 2>/dev/null || true
cat >> "$NOCTALIA_DIR/templates.toml" << EOF

[theme.templates.user.${THEME_NAME,,}]
input_path  = "~/.config/noctalia/templates/${THEME_NAME}.sh"
output_path = "~/.cache/noctalia/${THEME_NAME}-apply.sh"
post_hook   = "bash ~/.cache/noctalia/${THEME_NAME}-apply.sh"
EOF

# 6. Finalización y Aplicación inicial
chmod +x "$TEMPLATES_DIR/${THEME_NAME}.sh"
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
