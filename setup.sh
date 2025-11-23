#!/bin/bash
set -e

# Detect the directory of the cloned repo
REPO_DIR="$HOME/crucible-server"
ORIGINAL_DIR=$(pwd)

if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning crucible-server repo..."
    git clone https://github.com/hbabb/crucible-server.git "$REPO_DIR"
fi

cd "$REPO_DIR"

# Print the logo
cat << "EOF"
    ______                _ __    __
   / ____/______  _______(_) /_  / /__
  / /   / ___/ / / / ___/ / __ \/ / _ \
 / /___/ /  / /_/ / /__/ / /_/ / /  __/   Linux Server System Crafting Tool
 \____/_/   \__,_/\___/_/_.___/_/\___/   by: techsolvd
                                      courtesy of typecraft
EOF

# Source package.conf from repo root
if [ ! -f "package.conf" ]; then
    echo "Error: package.conf not found in $REPO_DIR"
    exit 1
fi
source "package.conf"

# Detect LXC
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
    echo "Running in LXC..."
    if ! grep -q "lxc.aa_profile=unconfined" /proc/1/cgroup 2>/dev/null; then
        echo "Unprivileged LXC: skipping Docker/K8s"
        SKIP_DOCKER=true
    fi
    if [ "$SKIP_DOCKER" != "true" ]; then
        apt update && apt install -y uidmap dbus-user-session
        dockerd-rootless-setuptool.sh install || true
    fi
fi

# Install packages
apt update && apt upgrade -y
apt install -y git curl zsh stow ufw docker.io docker-compose \
    postgresql redis-server nginx python3-pip fail2ban \
    "${SYSTEM_UTILS[@]}" "${SYSTEM_UTILS_DEBIAN[@]}" \
    "${DEV_TOOLS[@]}" "${DEV_TOOLS_DEBIAN[@]}" \
    "${SECURITY[@]}" "${WEB_DEV[@]}"

# Enable services
for svc in docker postgresql redis-server nginx ufw fail2ban; do
    if systemctl list-unit-files | grep -q "$svc"; then
        systemctl enable --now "$svc" || true
    fi
done

# Configure UFW
if command -v ufw &> /dev/null; then
    ufw default deny incoming
    ufw allow ssh
    ufw --force enable
fi

# Install asdf
if [ ! -d "$HOME/.asdf" ]; then
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
    echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
    echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
fi

# Install kubectl
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
fi

# Install Oh-My-Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Remove old configs
rm -rf "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/nvim" \
       "$HOME/.config/lazygit" "$HOME/.zsh" "$HOME/.config/zellij" \
       "$HOME/.config/starship.toml" 2>/dev/null

# Dotfiles setup
DOTFILES_DIR="$HOME/dotfiles"
if [ ! -d "$DOTFILES_DIR" ]; then
    git clone https://github.com/hbabb/dotfiles.git "$DOTFILES_DIR"
fi
cd "$DOTFILES_DIR"
stow bash git lazygit nvim zellij oh-my-zsh zsh starship || true

# Set zsh as default shell
if [ "$(which zsh)" != "$SHELL" ]; then
    chsh -s "$(which zsh)" || echo "Please change your shell manually."
fi

echo "Setup complete. Restart terminal or log out/in."
cd "$ORIGINAL_DIR"
