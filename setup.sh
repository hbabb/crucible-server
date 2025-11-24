#!/bin/bash
set -e

# Detect script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verifiy package.conf exists
if [ ! -f "$SCRIPT_DIR/package.conf" ]; then
  echo "Error: package.conf not found in $SCRIPT_DIR"
  exit 1
fi

# Load package.conf variables for script
source "$SCRIPT_DIR/package.conf"

# Print ASCII logo
cat << "EOF"
    ______                _ __    __
   / ____/______  _______(_) /_  / /__
  / /   / ___/ / / / ___/ / __ \/ / _ \
 / /___/ /  / /_/ / /__/ / /_/ / /  __/   Linux Server System Crafting Tool
 \____/_/   \__,_/\___/_/_.___/_/\___/   by: techsolvd
                                      courtesy of typecraft
EOF

# Check for LXC or VM
IS_LXC=false

if [ -f /run/.containerenv ] || [ -f /.dockerenv ]; then
  IS_LXC=true
fi

# Handle LXC docker/kubernetes behavior
if [ "$IS_LXC" = true ]; then
  echo "LXC environment detected."
  SKIP_DOCKER=true
  SKIP_K8S=true
fi

# Update and upgrade apt packages
apt update -y && apt upgrade -y

# Aggrecate packages from package.conf
ALL_PACKAGES=(
  "${SYSTEM_UTILS[0]}"
  "${SYSTEM_UTILS_DEBIAN[0]}"
  "${DEV_TOOLS[0]}"
  "${SECURITY[0]}"
  "${WEB_DEV[0]}"
  )

apt install -y "${ALL_PACKAGES}"

if [ "$IS_LXC" = false ]; then
  systemctl enable --now ufw || true
  systemctl enable --now fail2ban || true
  systemctl enable --now nginx || true
  systemctl enable --now redis || true
  systemctl enable --now postgresql || true

  # Docker if not skipped
  if [ "$SKIP_DOCKER" != true ]; then
    systemctl enable --now docker || true
  fi
fi

# Configure UFW if not LXC
if [ "$IS_LXC" = false ]; then
  ufw default deny incoming
  ufw allow ssh
  ufw --force enable
fi

# Install ASDF version manager
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0

echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc

# Install KUBECTL if not LXC
if [ "$IS_LXC" = false ]; then
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
fi

# Install Oh-My-Zsh
echo "Installing Oh-My-Zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Remove existing config files for Stow
rm -rf "$HOME/.bashrc" \
       "$HOME/.zshrc" \
       "$HOME/.config/nvim" \
       "$HOME/.config/lazygit" \
       "$HOME/.config/zellij" \
       "$HOME/.config/starship.toml" \
       "$HOME/.oh-my-zsh" 2>/dev/null

# Clone and apply dotfiles with stow
echo "Setting up dotfiles..."

cd "$HOME"

if [ ! -d "dotfiles" ]; then
  git clone https://github.com/hbabb/dotfiles.git
fi

cd dotfiles

stow bash git lazygit nvim zellij oh-my-zsh zsh starship

# Set zsh as default shell
chsh -s "$(which zsh)"

# source ~/.zshrc to load config immediately
zsh -c "source ~/.zshrc"

# Completed message
echo "Setup complete, please restart your terminal or log out and back in."
