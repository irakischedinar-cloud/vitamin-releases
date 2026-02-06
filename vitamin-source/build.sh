#!/bin/bash
#
# Vitamin Browser - Build Script
#
# This script can:
# 1. Build the omni.ja for quick testing
# 2. Generate patches for LibreWolf source integration
# 3. Build a full .deb package (requires LibreWolf source)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/src/browser-omni"
OUTPUT_DIR="$SCRIPT_DIR/dist"
PATCHES_DIR="$SCRIPT_DIR/patches"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

show_help() {
    echo -e "${CYAN}Vitamin Browser Build Script${NC}"
    echo ""
    echo "Usage: ./build.sh [command]"
    echo ""
    echo "Commands:"
    echo "  omni      Build browser-omni.ja for quick testing"
    echo "  patches   Generate LibreWolf patches from current code"
    echo "  deb       Build full .deb package (requires LibreWolf source)"
    echo "  help      Show this help message"
    echo ""
}

build_omni() {
    echo -e "${GREEN}Building browser-omni.ja...${NC}"

    mkdir -p "$OUTPUT_DIR"

    if [ -f "$OUTPUT_DIR/browser-omni.ja" ]; then
        mv "$OUTPUT_DIR/browser-omni.ja" "$OUTPUT_DIR/browser-omni.ja.bak"
    fi

    cd "$BUILD_DIR"
    zip -r -9 "$OUTPUT_DIR/browser-omni.ja" . \
        -x "*.git*" \
        -x "*.DS_Store" \
        -x "*__pycache__*"

    SIZE=$(du -h "$OUTPUT_DIR/browser-omni.ja" | cut -f1)
    echo -e "${GREEN}Built: $OUTPUT_DIR/browser-omni.ja ($SIZE)${NC}"
    echo ""
    echo "To install:"
    echo "  sudo cp $OUTPUT_DIR/browser-omni.ja /usr/lib/librewolf/browser/omni.ja"
}

generate_patches() {
    echo -e "${GREEN}Generating LibreWolf patches...${NC}"

    mkdir -p "$PATCHES_DIR"

    # List of Vitamin-specific files to add
    VITAMIN_FILES=(
        "actors/VitaminPoisonChild.sys.mjs"
        "actors/VitaminPoisonParent.sys.mjs"
        "actors/VitaminStartPageChild.sys.mjs"
        "actors/VitaminStartPageParent.sys.mjs"
        "modules/VitaminPoison.sys.mjs"
        "chrome/browser/content/browser/vitamin-newtab.html"
        "chrome/browser/content/browser/vitamin-welcome.html"
        "chrome/browser/content/browser/vitamin-poison-settings.html"
        "chrome/browser/content/browser/vitamin-poison-content.js"
        "chrome/browser/content/browser/vitaminpoison.css"
        "chrome/browser/skin/classic/browser/vitamin-poison.svg"
        "chrome/browser/skin/classic/browser/vitamin-poison-active.svg"
    )

    echo "Creating new-files patch..."

    # Create a patch that adds all Vitamin files
    PATCH_FILE="$PATCHES_DIR/vitamin-browser.patch"
    echo "# Vitamin Browser Patch" > "$PATCH_FILE"
    echo "# Apply to LibreWolf browser-omni source" >> "$PATCH_FILE"
    echo "" >> "$PATCH_FILE"

    for file in "${VITAMIN_FILES[@]}"; do
        if [ -f "$BUILD_DIR/$file" ]; then
            echo "--- /dev/null" >> "$PATCH_FILE"
            echo "+++ b/$file" >> "$PATCH_FILE"
            echo "@@ -0,0 +1,$(wc -l < "$BUILD_DIR/$file") @@" >> "$PATCH_FILE"
            sed 's/^/+/' "$BUILD_DIR/$file" >> "$PATCH_FILE"
            echo "" >> "$PATCH_FILE"
        fi
    done

    echo -e "${GREEN}Generated: $PATCH_FILE${NC}"

    # Also create a copy-files script for easier integration
    COPY_SCRIPT="$PATCHES_DIR/apply-vitamin.sh"
    cat > "$COPY_SCRIPT" << 'SCRIPT'
#!/bin/bash
# Apply Vitamin files to LibreWolf source
# Usage: ./apply-vitamin.sh /path/to/librewolf-source

if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/librewolf-source"
    exit 1
fi

TARGET="$1"
SOURCE="$(dirname "$0")/../src/browser-omni"

if [ ! -d "$TARGET" ]; then
    echo "Error: Target directory not found: $TARGET"
    exit 1
fi

echo "Copying Vitamin files to $TARGET..."

# Copy new files
cp "$SOURCE/actors/VitaminPoisonChild.sys.mjs" "$TARGET/actors/"
cp "$SOURCE/actors/VitaminPoisonParent.sys.mjs" "$TARGET/actors/"
cp "$SOURCE/actors/VitaminStartPageChild.sys.mjs" "$TARGET/actors/"
cp "$SOURCE/actors/VitaminStartPageParent.sys.mjs" "$TARGET/actors/"
cp "$SOURCE/modules/VitaminPoison.sys.mjs" "$TARGET/modules/"
cp "$SOURCE/chrome/browser/content/browser/vitamin-newtab.html" "$TARGET/chrome/browser/content/browser/"
cp "$SOURCE/chrome/browser/content/browser/vitamin-welcome.html" "$TARGET/chrome/browser/content/browser/"
cp "$SOURCE/chrome/browser/content/browser/vitamin-poison-settings.html" "$TARGET/chrome/browser/content/browser/"
cp "$SOURCE/chrome/browser/content/browser/vitamin-poison-content.js" "$TARGET/chrome/browser/content/browser/"
cp "$SOURCE/chrome/browser/content/browser/vitaminpoison.css" "$TARGET/chrome/browser/content/browser/"
cp "$SOURCE/chrome/browser/skin/classic/browser/vitamin-poison.svg" "$TARGET/chrome/browser/skin/classic/browser/"

# Copy modified files
cp "$SOURCE/modules/BrowserGlue.sys.mjs" "$TARGET/modules/"
cp "$SOURCE/modules/AboutNewTabRedirector.sys.mjs" "$TARGET/modules/"
cp "$SOURCE/defaults/preferences/firefox-branding.js" "$TARGET/defaults/preferences/"

echo "Done! Vitamin files applied."
SCRIPT
    chmod +x "$COPY_SCRIPT"

    echo -e "${GREEN}Generated: $COPY_SCRIPT${NC}"
}

build_deb() {
    echo -e "${CYAN}Building .deb package...${NC}"

    # --- Configuration ---
    VERSION="147.0.1"
    RELEASE="3"
    PKG_NAME="vitamin-browser"
    PKG_VERSION="${VERSION}-${RELEASE}"
    ARCH="amd64"
    DEB_BUILD_DIR="${DEB_BUILD_DIR:-$HOME/vitamin-deb-build}"
    LIBREWOLF_DIR="$DEB_BUILD_DIR/librewolf"
    PKG_DIR="$DEB_BUILD_DIR/${PKG_NAME}_${PKG_VERSION}_${ARCH}"
    OMNI_WORK="$DEB_BUILD_DIR/omni-work"
    ICONS_DIR="$SCRIPT_DIR/icons"

    # --- Generate icons if needed ---
    if [ ! -f "$ICONS_DIR/vitamin-browser-128.png" ]; then
        echo "  Generating icons..."
        python3 "$SCRIPT_DIR/gen-icon.py"
    fi

    # --- Validate inputs ---
    if [ ! -d "$LIBREWOLF_DIR" ]; then
        echo -e "${RED}Error: LibreWolf installation not found at $LIBREWOLF_DIR${NC}"
        echo ""
        echo "Place a LibreWolf installation directory at:"
        echo "  $LIBREWOLF_DIR"
        echo ""
        echo "You can extract one from an official LibreWolf .tar.bz2 or .deb package."
        exit 1
    fi

    if [ ! -f "$LIBREWOLF_DIR/librewolf-bin" ]; then
        echo -e "${RED}Error: librewolf-bin not found in $LIBREWOLF_DIR${NC}"
        exit 1
    fi

    if [ ! -f "$LIBREWOLF_DIR/browser/omni.ja" ]; then
        echo -e "${RED}Error: browser/omni.ja not found in $LIBREWOLF_DIR${NC}"
        exit 1
    fi

    echo -e "${GREEN}Found LibreWolf at: $LIBREWOLF_DIR${NC}"

    # --- Step 1: Build patched browser omni.ja ---
    echo -e "${YELLOW}[1/4] Building patched browser omni.ja...${NC}"

    rm -rf "$OMNI_WORK"
    mkdir -p "$OMNI_WORK"

    # Extract original browser omni.ja
    cd "$OMNI_WORK"
    unzip -q -o "$LIBREWOLF_DIR/browser/omni.ja" 2>/dev/null || true

    # Copy Vitamin files on top
    echo "  Injecting Vitamin files..."

    # New files
    cp "$BUILD_DIR/actors/VitaminPoisonChild.sys.mjs"    "$OMNI_WORK/actors/"
    cp "$BUILD_DIR/actors/VitaminPoisonParent.sys.mjs"   "$OMNI_WORK/actors/"
    cp "$BUILD_DIR/actors/VitaminStartPageChild.sys.mjs" "$OMNI_WORK/actors/"
    cp "$BUILD_DIR/actors/VitaminStartPageParent.sys.mjs" "$OMNI_WORK/actors/"
    cp "$BUILD_DIR/modules/VitaminPoison.sys.mjs"        "$OMNI_WORK/modules/"

    mkdir -p "$OMNI_WORK/chrome/browser/content/browser"
    cp "$BUILD_DIR/chrome/browser/content/browser/vitamin-newtab.html"          "$OMNI_WORK/chrome/browser/content/browser/"
    cp "$BUILD_DIR/chrome/browser/content/browser/vitamin-welcome.html"         "$OMNI_WORK/chrome/browser/content/browser/"
    cp "$BUILD_DIR/chrome/browser/content/browser/vitamin-poison-settings.html" "$OMNI_WORK/chrome/browser/content/browser/"
    cp "$BUILD_DIR/chrome/browser/content/browser/vitamin-poison-content.js"    "$OMNI_WORK/chrome/browser/content/browser/"
    cp "$BUILD_DIR/chrome/browser/content/browser/vitaminpoison.css"            "$OMNI_WORK/chrome/browser/content/browser/"

    mkdir -p "$OMNI_WORK/chrome/browser/skin/classic/browser"
    cp "$BUILD_DIR/chrome/browser/skin/classic/browser/vitamin-poison.svg"      "$OMNI_WORK/chrome/browser/skin/classic/browser/"
    if [ -f "$BUILD_DIR/chrome/browser/skin/classic/browser/vitamin-poison-active.svg" ]; then
        cp "$BUILD_DIR/chrome/browser/skin/classic/browser/vitamin-poison-active.svg" "$OMNI_WORK/chrome/browser/skin/classic/browser/"
    fi

    # Modified files (overwrite originals)
    cp "$BUILD_DIR/modules/BrowserGlue.sys.mjs"               "$OMNI_WORK/modules/"
    cp "$BUILD_DIR/modules/AboutNewTabRedirector.sys.mjs"      "$OMNI_WORK/modules/"
    cp "$BUILD_DIR/defaults/preferences/firefox-branding.js"   "$OMNI_WORK/defaults/preferences/"

    # Replace branding icons with Vitamin icons
    echo "  Replacing branding icons..."
    BRANDING_DIR="$OMNI_WORK/chrome/browser/content/branding"
    if [ -d "$BRANDING_DIR" ]; then
        for size in 16 32 48 64 128; do
            if [ -f "$ICONS_DIR/vitamin-browser-${size}.png" ]; then
                cp "$ICONS_DIR/vitamin-browser-${size}.png" "$BRANDING_DIR/icon${size}.png"
            fi
        done
        # about-logo used in about:dialog and about pages
        if [ -f "$ICONS_DIR/vitamin-browser-128.png" ]; then
            cp "$ICONS_DIR/vitamin-browser-128.png" "$BRANDING_DIR/about-logo.png"
        fi
        if [ -f "$ICONS_DIR/vitamin-browser-256.png" ]; then
            cp "$ICONS_DIR/vitamin-browser-256.png" "$BRANDING_DIR/about-logo@2x.png"
        fi
        if [ -f "$ICONS_DIR/vitamin-browser-256.png" ]; then
            cp "$ICONS_DIR/vitamin-browser-256.png" "$BRANDING_DIR/about.png"
        fi
    fi

    # Rebrand "LibreWolf" → "Vitamin Browser" in all locale brand.ftl files
    echo "  Rebranding locale strings..."
    find "$OMNI_WORK/localization" -name "brand.ftl" -exec sed -i \
        -e 's/-brand-shorter-name = LibreWolf/-brand-shorter-name = Vitamin/' \
        -e 's/-brand-short-name = LibreWolf/-brand-short-name = Vitamin Browser/' \
        -e 's/-brand-full-name = LibreWolf/-brand-full-name = Vitamin Browser/' \
        -e 's/-brand-shortcut-name = LibreWolf/-brand-shortcut-name = Vitamin Browser/' \
        -e 's/-brand-product-name = LibreWolf/-brand-product-name = Vitamin Browser/' \
        -e 's/-vendor-short-name = LibreWolf/-vendor-short-name = VitaliCorp/' \
        {} +

    # Rebrand hardcoded "LibreWolf" in other .ftl files (browser.ftl, preferences.ftl, aboutDialog.ftl)
    echo "  Rebranding hardcoded LibreWolf references in .ftl files..."
    find "$OMNI_WORK/localization" -name "browser.ftl" -exec sed -i \
        's/LibreWolf/Vitamin Browser/g' {} +
    find "$OMNI_WORK/localization" -name "preferences.ftl" -exec sed -i \
        -e 's/pane-librewolf-title = LibreWolf/pane-librewolf-title = Vitamin Browser/' \
        -e 's/librewolf-header = LibreWolf Preferences/librewolf-header = Vitamin Browser Preferences/' \
        -e 's/LibreWolf supports/Vitamin Browser supports/g' \
        -e 's/LibreWolf is/Vitamin Browser is/g' \
        {} +
    find "$OMNI_WORK/localization" -name "aboutDialog.ftl" -exec sed -i \
        's/LibreWolf/Vitamin Browser/g' {} +

    # Remove debug console.log from aboutDialog.js
    if [ -f "$OMNI_WORK/chrome/browser/content/browser/aboutDialog.js" ]; then
        sed -i '/^[[:space:]]*console\.log(oldVersionString, newVersionString)/d' \
            "$OMNI_WORK/chrome/browser/content/browser/aboutDialog.js"
    fi

    # Repack omni.ja
    echo "  Repacking omni.ja..."
    PATCHED_OMNI="$DEB_BUILD_DIR/browser-omni-patched.ja"
    cd "$OMNI_WORK"
    rm -f "$PATCHED_OMNI"
    zip -r -0 "$PATCHED_OMNI" . \
        -x "*.git*" \
        -x "*.DS_Store" \
        -x "*__pycache__*" > /dev/null

    OMNI_SIZE=$(du -h "$PATCHED_OMNI" | cut -f1)
    echo -e "  ${GREEN}Patched omni.ja: $OMNI_SIZE${NC}"

    # --- Step 2: Assemble package directory ---
    echo -e "${YELLOW}[2/4] Assembling package directory...${NC}"

    rm -rf "$PKG_DIR"
    INSTALL_DIR="$PKG_DIR/usr/lib/$PKG_NAME"
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$PKG_DIR/usr/bin"
    mkdir -p "$PKG_DIR/usr/share/applications"
    mkdir -p "$PKG_DIR/usr/share/pixmaps"
    mkdir -p "$PKG_DIR/DEBIAN"

    # Copy LibreWolf binaries
    echo "  Copying LibreWolf binaries..."
    cp -a "$LIBREWOLF_DIR"/* "$INSTALL_DIR/"

    # Replace browser omni.ja with patched version
    cp "$PATCHED_OMNI" "$INSTALL_DIR/browser/omni.ja"

    # Patch top-level omni.ja (Gecko platform) to rebrand appstrings.properties
    echo "  Patching top-level omni.ja..."
    TOP_OMNI_WORK="$DEB_BUILD_DIR/top-omni-work"
    rm -rf "$TOP_OMNI_WORK"
    mkdir -p "$TOP_OMNI_WORK"
    cd "$TOP_OMNI_WORK"
    unzip -q -o "$INSTALL_DIR/omni.ja" 2>/dev/null || true
    find "$TOP_OMNI_WORK/chrome" -name "appstrings.properties" -exec sed -i \
        's/LibreWolf/Vitamin Browser/g' {} +
    TOP_PATCHED="$DEB_BUILD_DIR/top-omni-patched.ja"
    rm -f "$TOP_PATCHED"
    zip -r -0 "$TOP_PATCHED" . \
        -x "*.git*" \
        -x "*.DS_Store" \
        -x "*__pycache__*" > /dev/null
    cp "$TOP_PATCHED" "$INSTALL_DIR/omni.ja"
    rm -rf "$TOP_OMNI_WORK" "$TOP_PATCHED"

    # --- Rebrand LibreWolf → Vitamin Browser ---
    echo "  Rebranding LibreWolf → Vitamin Browser..."

    # application.ini
    if [ -f "$INSTALL_DIR/application.ini" ]; then
        sed -i 's/^Name=LibreWolf$/Name=Vitamin Browser/' "$INSTALL_DIR/application.ini"
        sed -i 's/^RemotingName=librewolf$/RemotingName=vitamin-browser/' "$INSTALL_DIR/application.ini"
        sed -i 's/^Profile=librewolf$/Profile=vitamin-browser/' "$INSTALL_DIR/application.ini"
    fi

    # librewolf.cfg - rebrand user-visible content (keep librewolf.* pref names for engine compat)
    CFG="$INSTALL_DIR/librewolf.cfg"
    if [ -f "$CFG" ]; then
        # Section headers and comments
        sed -i 's|LIBREWOLF SETTINGS|VITAMIN BROWSER SETTINGS|g' "$CFG"
        sed -i 's|\[CATEGORY\] LIBREWOLF|[CATEGORY] VITAMIN|g' "$CFG"
        sed -i 's|prefs introduced by librewolf-specific patches|prefs introduced by librewolf-specific patches (inherited by Vitamin Browser)|' "$CFG"

        # Support/feedback URLs → Vitamin Browser
        sed -i 's|https://support.librewolf.net/|https://github.com/realvitali/vitamin-browser/wiki|g' "$CFG"
        sed -i 's|https://librewolf.net/docs/faq/#how-do-i-add-a-search-engine|https://github.com/realvitali/vitamin-browser#faq|g' "$CFG"
        sed -i 's|https://librewolf.net/docs/faq/#how-do-i-enable-location-aware-browsing|https://github.com/realvitali/vitamin-browser#faq|g' "$CFG"
        sed -i 's|https://librewolf.net/#questions|https://github.com/realvitali/vitamin-browser/issues|g' "$CFG"
        sed -i 's|https://codeberg.org/librewolf/source|https://github.com/realvitali/vitamin-browser|g' "$CFG"

        # Override config paths: .librewolf → .vitamin-browser
        sed -i 's|\.librewolf/librewolf\.overrides\.cfg|.vitamin-browser/vitamin-browser.overrides.cfg|g' "$CFG"
        sed -i 's|/librewolf/librewolf/librewolf\.overrides\.cfg|/vitamin-browser/vitamin-browser.overrides.cfg|g' "$CFG"
        sed -i 's|path\.includes("\.librewolf")|path.includes(".vitamin-browser")|g' "$CFG"

        # Comment references to librewolf.net docs
        sed -i 's|https://librewolf.net/docs/settings/#where-do-i-find-my-librewolfoverridescfg|https://github.com/realvitali/vitamin-browser#overrides|g' "$CFG"
        sed -i 's|https://librewolf.net/docs/faq/|https://github.com/realvitali/vitamin-browser#faq|g' "$CFG"

        # Comment-only branding (safe to change)
        sed -i 's|set librewolf support and releases urls|set Vitamin Browser support and releases urls|g' "$CFG"
        sed -i 's|librewolf does use DoH|Vitamin Browser uses DoH|g' "$CFG"
        sed -i 's|librewolf should stick to RFP|Vitamin Browser sticks to RFP|g' "$CFG"
    fi

    # distribution/policies.json - update issue tracker
    POLICIES="$INSTALL_DIR/distribution/policies.json"
    if [ -f "$POLICIES" ]; then
        sed -i 's|"Title": "LibreWolf Issue Tracker"|"Title": "Vitamin Browser Issue Tracker"|' "$POLICIES"
        sed -i 's|https://codeberg.org/librewolf/issues|https://github.com/realvitali/vitamin-browser/issues|' "$POLICIES"
    fi

    # Create vitamin-browser launcher wrapper
    cat > "$INSTALL_DIR/$PKG_NAME" << 'LAUNCHER'
#!/bin/sh
# Vitamin Browser launcher wrapper
# Uses a separate profile directory from LibreWolf to avoid conflicts

VITAMIN_DIR="/usr/lib/vitamin-browser"
VITAMIN_PROFILE_DIR="$HOME/.vitamin-browser"

# Create profile directory with restrictive permissions
mkdir -p "$VITAMIN_PROFILE_DIR"
chmod 700 "$VITAMIN_PROFILE_DIR"

export MOZ_APP_LAUNCHER="$0"
export MOZ_LEGACY_PROFILES=1
export MOZ_APP_REMOTINGNAME="vitamin-browser"

exec "$VITAMIN_DIR/librewolf-bin" --class vitamin-browser --name vitamin-browser --profile "$VITAMIN_PROFILE_DIR" "$@"
LAUNCHER
    chmod 755 "$INSTALL_DIR/$PKG_NAME"

    # Create /usr/bin symlink
    ln -sf "/usr/lib/$PKG_NAME/$PKG_NAME" "$PKG_DIR/usr/bin/$PKG_NAME"

    # Desktop entry
    cat > "$PKG_DIR/usr/share/applications/$PKG_NAME.desktop" << DESKTOP
[Desktop Entry]
Version=1.0
Name=Vitamin Browser
GenericName=Web Browser
Comment=Privacy-focused web browser with data poisoning
Exec=$PKG_NAME %u
Icon=$PKG_NAME
Terminal=false
Type=Application
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/vnd.mozilla.xul+xml;x-scheme-handler/http;x-scheme-handler/https;
Categories=Network;WebBrowser;
StartupNotify=true
StartupWMClass=vitamin-browser
DESKTOP

    # Desktop pixmap (128px)
    cp "$ICONS_DIR/vitamin-browser-128.png" "$PKG_DIR/usr/share/pixmaps/$PKG_NAME.png"

    # Replace browser chrome icons (window titlebar, taskbar)
    CHROME_ICONS="$INSTALL_DIR/browser/chrome/icons/default"
    if [ -d "$CHROME_ICONS" ]; then
        for size in 16 32 48 64 128; do
            if [ -f "$ICONS_DIR/vitamin-browser-${size}.png" ]; then
                cp "$ICONS_DIR/vitamin-browser-${size}.png" "$CHROME_ICONS/default${size}.png"
            fi
        done
    fi

    # XDG icon directories for proper desktop integration
    for size in 16 32 48 64 128 256 512; do
        if [ -f "$ICONS_DIR/vitamin-browser-${size}.png" ]; then
            ICON_DEST="$PKG_DIR/usr/share/icons/hicolor/${size}x${size}/apps"
            mkdir -p "$ICON_DEST"
            cp "$ICONS_DIR/vitamin-browser-${size}.png" "$ICON_DEST/$PKG_NAME.png"
        fi
    done

    # --- Step 3: DEBIAN control files ---
    echo -e "${YELLOW}[3/4] Writing DEBIAN metadata...${NC}"

    # Calculate installed size (in KB)
    INSTALLED_SIZE=$(du -sk "$PKG_DIR/usr" | cut -f1)

    cat > "$PKG_DIR/DEBIAN/control" << CONTROL
Package: $PKG_NAME
Version: $PKG_VERSION
Architecture: $ARCH
Maintainer: VitaliCorp <mrvitali@pm.me>
Installed-Size: $INSTALLED_SIZE
Depends: libc6, libgtk-3-0, libx11-6, libdbus-glib-1-2, libxt6, libstdc++6
Conflicts: librewolf
Section: web
Priority: optional
Homepage: https://github.com/realvitali/vitamin-browser
Description: Vitamin Browser - Privacy-focused web browser
 A privacy-focused web browser based on LibreWolf with
 built-in data poisoning capabilities to protect your
 browsing privacy from trackers.
CONTROL

    cat > "$PKG_DIR/DEBIAN/postinst" << 'POSTINST'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q /usr/share/icons/hicolor || true
fi
POSTINST
    chmod 755 "$PKG_DIR/DEBIAN/postinst"

    cat > "$PKG_DIR/DEBIAN/prerm" << 'PRERM'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications || true
fi
PRERM
    chmod 755 "$PKG_DIR/DEBIAN/prerm"

    # --- Fix file permissions ---
    echo "  Setting file permissions..."
    find "$PKG_DIR/usr/share" -type f -exec chmod 644 {} +
    find "$PKG_DIR/usr/share" -type d -exec chmod 755 {} +
    chmod 755 "$INSTALL_DIR/$PKG_NAME"
    find "$INSTALL_DIR" -name "*.so" -exec chmod 755 {} +
    find "$INSTALL_DIR" -name "*.so.*" -exec chmod 755 {} +

    # --- Step 4: Build .deb ---
    echo -e "${YELLOW}[4/4] Building .deb package...${NC}"

    DEB_FILE="$DEB_BUILD_DIR/${PKG_NAME}_${PKG_VERSION}_${ARCH}.deb"
    dpkg-deb --build --root-owner-group "$PKG_DIR" "$DEB_FILE"

    DEB_SIZE=$(du -h "$DEB_FILE" | cut -f1)
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN} .deb built successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "  Package: ${CYAN}$DEB_FILE${NC}"
    echo -e "  Size:    ${CYAN}$DEB_SIZE${NC}"
    echo ""
    echo "  Install with:"
    echo "    sudo dpkg -i $DEB_FILE"
    echo ""
}

# Main
case "${1:-help}" in
    omni)
        build_omni
        ;;
    patches)
        generate_patches
        ;;
    deb)
        build_deb
        ;;
    help|*)
        show_help
        ;;
esac
