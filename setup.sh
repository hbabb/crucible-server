#!/bin/bash
set -e

# Find the script’s directory (the repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source packages.conf from repo root  
if [ ! -f "$SCRIPT_DIR/packages.conf" ]; then  
  echo "Error: packages.conf not found in $SCRIPT_DIR"  
  exit 1  
fi  
source "$SCRIPT_DIR/packages.conf"

# Print the logo  
cat << "EOF"  
    ______                _ __    __  
   / ____/______  _______(_) /_  / /__  
  / /   / ___/ / / / ___/ / __ \/ / _ \  
 / /___/ /  / /_/ / /__/ / /_/ / /  __/   Linux Server System Crafting Tool  
 \____/_/   \__,_/\___/_/_.___/_/\___/   by: techsolvd  
                                      courtesy of typecraft  
EOF

# LXC detection  
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then  
  echo "Running in LXC container. Adjusting setup..."  
  if ! grep -q "lxc.aa_profile=unconfined" /proc/1/cgroup 2>/dev/null; then  
    echo "Unprivileged LXC detected. Skipping Docker/Kubernetes..."  
    SKIP_DOCKER=true  
  fi  
  if [ "$SKIP_DOCKER" != "true" ]; then  
    apt update && apt install -y uidmap dbus-user-session  
    dockerd-rootless-setuptool.sh install || true  
  fi  
fi

# Update and install packages from the arrays  
apt update && apt upgrade -y  
apt install -y "${SYSTEM_UTILS[@]}" "${SYSTEM_UTILS_DEBIAN[@]}" \
               "${DEV_TOOLS[@]}" "${DEV_TOOLS_DEBIAN[@]}" \
               "${SECURITY[@]}" "${WEB_DEV[@]}"

# Enable services safely  
for svc in docker postgresql redis nginx ufw fail2ban; do  
  if systemctl list-unit-files | grep -q "^$svc"; then  
    systemctl enable --now "$svc" || true  
  fi  
done

# UFW setup  
if command -v ufw &>/dev/null; then  
  ufw default deny incoming  
  ufw allow ssh  
  ufw --force enable  
fi

# asdf install  
if [ ! -d "$HOME/.asdf" ]; then  
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0  
  echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc  
  echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc  
fi

# kubectl  
if ! command -v kubectl &>/dev/null; then  
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"  
  install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl  
fi

# Oh My Zsh  
if [ ! -d "$HOME/.oh-my-zsh" ]; then  
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended  
fi

# Clean old dotfile configs  
rm -rf "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/nvim" \
       "$HOME/.config/lazygit" "$HOME/.zsh" "$HOME/.config/zellij" \
       "$HOME/.config/starship.toml" 2>/dev/null

# Dotfiles with stow  
cd "$HOME"  
if ! command -v stow &>/dev/null; then  
  echo "Error: stow is not installed."  
  exit 1  
fi  
if [ ! -d "$HOME/dotfiles" ]; then  
  git clone https://github.com/hbabb/dotfiles.git "$HOME/dotfiles"  
fi  
cd "$HOME/dotfiles"  
stow bash git lazygit nvim zellij oh-my-zsh zsh starship || true

# Change shell to zsh  
if [ "$(which zsh)" != "$SHELL" ]; then  
  chsh -s "$(which zsh)" || echo "Please change your shell manually."  
fi

echo "Setup complete. Please restart terminal or log out/in."
