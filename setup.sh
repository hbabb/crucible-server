#!/bin/bash
ORIGINAL_DIR=$(pwd)

# Print the logo
print_logo() {
    cat << "EOF"
    ______                _ __    __
   / ____/______  _______(_) /_  / /__
  / /   / ___/ / / / ___/ / __ \/ / _ \
 / /___/ /  / /_/ / /__/ / /_/ / /  __/   Linux Server System Crafting Tool
 \____/_/   \__,_/\___/_/_.___/_/\___/   by: techsolvd
                                      courtesy of typecraft

EOF
}

print_logo

# Detect if running in LXC
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
  echo "Running in LXC container. Adjusting setup..."
  # Skip Docker/Kubernetes if unprivileged
  if ! grep -q "lxc.aa_profile=unconfined" /proc/1/cgroup 2>/dev/null; then
    echo "Unprivileged LXC detected. Skipping Docker/Kubernetes..."
    export SKIP_DOCKER=true
  fi
  # Use rootless Docker if needed
  if [ "$SKIP_DOCKER" != "true" ]; then
    apt install -y uidmap dbus-user-session
    dockerd-rootless-setuptool.sh install
  fi
fi

source package.conf

# Install system utilities
apt update && apt upgrade -y
apt install -y "${SYSTEM_UTILS[@]}" "${SYSTEM_UTILS_DEBIAN[@]}" "${DEV_TOOLS[@]}" "${SECURITY[@]}" "${WEB_DEV[@]}"

# Enable services
systemctl enable --now docker postgresql redis nginx ufw fail2ban
ufw default deny incoming && ufw allow ssh && ufw --force enable

# Install asdf
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Oh-My-Zsh
echo "Installing Oh-My-Zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
rm -rf "$HOME/.oh-my-zsh" 2>/dev/null
stow oh-my-zsh

# Remove existing configs (no backup, no prompts)
echo "Removing existing configs for stow..."
rm -rf "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/nvim" "$HOME/.config/lazygit" "$HOME/.zsh" "$HOME/.config/zellij" "$HOME/.config/starship.toml" "$HOME/.oh-my-zsh" 2>/dev/null

# Dotfiles setup
echo "Setting up dotfiles..."
cd ~
REPO_URL="https://github.com/yourusername/your-dotfiles-repo"
REPO_NAME="dotfiles"

if ! command -v stow &> /dev/null; then
  echo "Error: 'stow' is not installed. Install it first."
  exit 1
fi

if [ ! -d "$REPO_NAME" ]; then
  git clone "$REPO_URL" || { echo "Failed to clone dotfiles."; exit 1; }
fi

cd "$REPO_NAME"
stow bash git lazygit nvim zellij zsh starship

# Set zsh as the default shell
echo "Setting zsh as the default shell..."
chsh -s $(which zsh)

# Source .zshrc to apply changes
echo "Sourcing .zshrc..."
zsh -c "source ~/.zshrc"

cd "$ORIGINAL_DIR"
echo "Setup complete. Please restart your terminal or log out and back in."
