#!/data/data/com.termux/files/usr/bin/bash
# bootstrap.sh — One-click Claude Code Android environment setup
# Safe to re-run (packages/configs are checked before installing)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[--]${NC} $*"; }
fail() { echo -e "${RED}[!!]${NC} $*"; exit 1; }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  Claude Code Android — Setup             ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ---- Step 1: Install base packages ----
echo "[1/7] Installing base packages..."
pkg update -y -q
for pkg in nodejs-lts git tmux openssh python make clang binutils neovim gnupg ripgrep fd; do
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    log "  $pkg already installed"
  else
    pkg install -y "$pkg" && log "  $pkg installed"
  fi
done

# ---- Step 2: Install Node.js global packages ----
echo "[2/7] Installing Node.js global packages..."
if command -v claude >/dev/null 2>&1; then
  log "  claude already installed ($(claude --version 2>/dev/null || echo 'unknown'))"
else
  npm install -g @anthropic-ai/claude-code && log "  @anthropic-ai/claude-code installed"
fi

if command -v code-server >/dev/null 2>&1; then
  log "  code-server already installed"
else
  npm install -g code-server && log "  code-server installed"
fi

# ---- Step 3: Install Python packages ----
echo "[3/7] Installing Python packages..."
if pip show litellm >/dev/null 2>&1; then
  log "  litellm already installed ($(pip show litellm 2>/dev/null | grep Version | cut -d' ' -f2))"
else
  pip install litellm && log "  litellm installed"
fi

# ---- Step 4: Create directories ----
echo "[4/7] Setting up directories..."
mkdir -p ~/projects ~/bin ~/.secrets ~/.termux/boot ~/.config/code-server
chmod 700 ~/.secrets
log "  Directory structure ready"

# ---- Step 5: Deploy configuration files ----
echo "[5/7] Deploying configuration files..."

# Locate asset source (APK assets or local script directory)
ASSET_DIR=""
if [ -d "/data/data/com.termux/files/conf-backup" ]; then
  ASSET_DIR="/data/data/com.termux/files/conf-backup"
elif [ -d "$(dirname "$0")" ]; then
  ASSET_DIR="$(dirname "$0")"
fi

if [ -n "$ASSET_DIR" ] && [ -f "$ASSET_DIR/tmux.conf" ]; then
  cp "$ASSET_DIR/tmux.conf" ~/.tmux.conf
  cp "$ASSET_DIR/termux.properties" ~/.termux/termux.properties
  cp "$ASSET_DIR/cstart" ~/bin/cstart
  cp "$ASSET_DIR/claude-with" ~/bin/claude-with
  cp "$ASSET_DIR/restore-env" ~/bin/restore-env
  cp "$ASSET_DIR/code-server.yaml" ~/.config/code-server/config.yaml
  cp "$ASSET_DIR/litellm_config.yaml" ~/litellm_config.yaml
  chmod +x ~/bin/cstart ~/bin/claude-with ~/bin/restore-env
  log "  Config files deployed from $ASSET_DIR"
else
  warn "  No pre-packaged configs found — writing defaults inline"
  cat > ~/.tmux.conf << 'TMUXEOF'
set -g prefix C-a
unbind C-b
set -g mouse on
set -g base-index 1
set -g history-limit 50000
TMUXEOF
fi

# ---- Step 6: System permissions ----
echo "[6/7] Configuring system permissions..."
termux-setup-storage 2>/dev/null || warn "  termux-setup-storage needs manual run"
termux-wake-lock acquire 2>/dev/null && log "  Wake lock acquired" || warn "  termux-api not installed"

# ---- Step 7: Write boot auto-start ----
echo "[7/7] Writing boot auto-start..."
cat > ~/.termux/boot/auto.sh << 'BOOTSH'
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock acquire 2>/dev/null
tmux new-session -d -s main -n claude 2>/dev/null
BOOTSH
chmod +x ~/.termux/boot/auto.sh
log "  Boot script written"

# ---- Done ----
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  Setup complete!                         ║"
echo "╠══════════════════════════════════════════╣"
echo "║  Next steps:                             ║"
echo "║  1. claude login                         ║"
echo "║  2. cstart                               ║"
echo "║                                          ║"
echo "║  Optional:                               ║"
echo "║  3. Chrome → localhost:8080               ║"
echo "║     (code-server, password: claude)      ║"
echo "║  4. ~/bin/claude-with deepseek           ║"
echo "║  5. See ~/litellm_config.yaml            ║"
echo "╚══════════════════════════════════════════╝"
echo ""
