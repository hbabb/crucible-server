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
  curl wget git zsh stow fzf btop bat eza
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

# Update and install
echo -e "${BLUE}Installing packages...${NC}"
apt update -y
apt install -y "${PACKAGES[@]}"

# Install latest Neovim for LazyVim
echo -e "${BLUE}Installing latest Neovim via official tarball...${NC}"
cd /tmp
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
tar xzf nvim-linux-x86_64.tar.gz
# Move binaries to /usr/local
cp -r nvim-linux-x86_64/bin/* /usr/local/bin/
cp -r nvim-linux-x86_64/share/* /usr/local/share/
cp -r nvim-linux-x86_64/lib/* /usr/local/lib/
rm -rf nvim-linux-x86_64 nvim-linux-x86_64.tar.gz
chmod +x /usr/local/bin/nvim
echo -e "${GREEN}Neovim installed (latest)${NC}"

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
rm -rf "$HOME/.zshrc" \
       "$HOME/.oh-my-zsh" \
       "$HOME/.config/nvim" 2>/dev/null || true

# Apply dotfiles using stow
stow zsh oh-my-zsh nvim 2>/dev/null || {
  echo "NOTE: Some dotfiles may already exist"
}

# Setup oh-my-zsh plugins after stow
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Try to set zsh as default (may require password)
if [ "$EUID" -eq 0 ]; then
  chsh -s "$(which zsh)" || echo "NOTE: Run 'chsh -s \$(which zsh)' manually to set zsh as default"
else
  echo "Run 'chsh -s \$(which zsh)' to set zsh as default shell"
fi

# Setup SSH server for remote access
echo -e "${BLUE}Configuring SSH server access...${NC}"
apt install -y openssh-server
systemctl enable --now ssh

# Setup root access for SSH Login
cat > /etc/ssh/sshd_config.d/99-root-login.conf << 'EOF'
PermitRootLogin yes
PasswordAuthentication yes
KbdInteractiveAuthentication yes
PubkeyAuthentication yes
EOF

systemctl restart sshd

# Get IP Address
IP_ADDRESS=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)

echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "Installed packages: ${PACKAGES[*]}"
echo ""
echo -e "${BLUE}SSH Access Setup:${NC}"
echo "Server IP: ${IP_ADDRESS}"
echo ""
echo "From your PC, run these commands to setup SSH access:"
echo ""
echo " # Copy your SSH key to this server"
echo " ssh-copy-id -i ~/.ssh/id_ed25519.pub root@${IP_ADDRESS} OR user@${IP_ADDRESS}"
echo ""
echo " # Add to your ~/.ssh/config (optional but recommended):"
echo " Host debian"
echo "     HostName ${IP_ADDRESS}"
echo "     User root"
echo "     IdentityFile ~/.ssh/id_ed25519"
echo ""
echo " # Then connect with:"
echo " ssh debian"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo " 1. Set up SSH access using commands above"
echo " 2. SSH into the server (don't use pct enter for LXC)"
echo " 3. Run 'exec zsh' to start using your new shell"
echo " 4. Use ASDF to install language runtimes as needed"
if [ "$IS_LXC" = false ]; then
  echo " 5. Check service status: systemctl status nginx"
fi
echo ""
