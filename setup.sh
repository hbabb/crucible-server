#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Starting Crucible Quick Setup...${NC}"

# Install git if missing
if ! command -v git &> /dev/null; then
  echo "Installing git..."
  apt update && apt install -y git
fi

# Detect if we're in LXC
IS_LXC=false
if [ -f /run/.containerenv ] || [ -f /.dockerenv ] || grep -q lxc /proc/1/cgroup 2>/dev/null; then
  IS_LXC=true
  echo -e "${GREEN}LXC environment detected${NC}"
fi

# Core packages - always installed
CORE_PACKAGES=(
  curl wget git zsh neovim stow fzf btop htop zellij bat
)

# Optional packages - ask user
echo ""
echo "What do you need installed?"
echo "1) Just core tools (default)"
echo "2) Core + nginx"
echo "3) Core + nginx + postgresql"
echo "4) Core + full web stack (nginx, postgresql, redis)"
read -r -p "Choose [1-4] (default: 1): " SETUP_CHOICE
SETUP_CHOICE=${SETUP_CHOICE:-1}

PACKAGES=("${CORE_PACKAGES[@]}")

case $SETUP_CHOICE in
  2)
    PACKAGES+=(nginx)
    ;;
  3)
    PACKAGES+=(nginx postgresql)
    ;;
  4)
    PACKAGES+=(nginx postgresql redis-server)
    ;;
esac

# Add security tools only if not in LXC
if [ "$IS_LXC" = false ]; then
  read -r -p "Install security tools (ufw, fail2ban)? [y/N]: " INSTALL_SECURITY
  if [[ $INSTALL_SECURITY =~ ^[Yy]$ ]]; then
    PACKAGES+=(ufw fail2ban)
  fi
fi

# Add Neovim PPA for latest verion (Lazyvim requirement)
echo -e "${BLUE}Adding Neovim unstable repository...${NC}"
echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list
cat > /etc/apt/preferences.d/99pin-unstable << 'EOF'
Package: *
Pin: release a=unstable
Pin-Priority: 10

Package: neovim
Pin: release a=unstable
Pin-Priority: 900
EOF

# Update and install
echo -e "${BLUE}Installing packages...${NC}"
apt update -y
apt upgrade -y
apt install -y "${PACKAGES[@]}"

# Enable services if install and not in LXC
if [ "$IS_LXC" = false ]; then
  for service in nginx postgresql redis-server ufw fail2ban; do
    if command -v $service &> /dev/null || systemctl list-unit-files | grep -q "^${service}.service"; then
      systemctl enable --now $service 2>/dev/null || true
    fi
  done

  # Basic UFW setup if installed
  if command -v ufw &> /dev/null; then
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable
    echo -e "${GREEN}UFW enabled with SSH, HTTP, and HTTPS${NC}"
  fi
fi

# Install ASDF version manager
if [ ! -d "$HOME/.asdf" ]; then
  echo -e "${BLUE}Installing ASDF...${NC}"
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
fi

# Install Oh-My-Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo -e "${BLUE}Installing Oh-My-Zsh...${NC}"
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Setup dotfiles
echo -e "${BLUE}Setting up dotfiles...${NC}"
cd "$HOME"
if [ ! -d "dotfiles" ]; then
  git clone https://github.com/hbabb/dotfiles.git
fi

cd dotfiles

# Remove existing configs to avoid stow confilicts
rm -rf "$HOME/.bashrc" \
       "$HOME/.zshrc" \
       "$HOME/.oh-my-zsh" \
       "$HOME/.config/nvim" \
       "$HOME/.config/zellij" \
       "$HOME/.config/starship.toml" 2>/dev/null || true

# Apply dotfiles using stow
stow bash zsh oh-my-zsh zellij nvim starship 2>/dev/null || {
  echo "NOTE: Some dotfiles may already exist"
}

# Try to set zsh as default (may require password)
if [ "$EUID" -eq 0 ]; then
  chsh -s "$(which zsh)" || echo "NOTE: Run 'chsh -s \$(which zsh)' manually to set zsh as default"
else
  echo "Run 'chsh -s \$(which zsh)' to set zsh as default shell"
fi

echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "Installed packages: ${PACKAGES[*]}"
echo ""
echo "Next steps:"
echo "  1. Exit and log back in (or run 'exec zsh')"
echo "  2. Use ASDF to install language runtimes as needed"
echo "  3. Check service status: systemctl status nginx"
echo ""
