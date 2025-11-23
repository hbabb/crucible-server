
#!/bin/bash
set -e
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

# Ensure package.conf is loaded
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
if [ ! -f "$SCRIPT_DIR/package.conf" ]; then
    echo "Error: package.conf not found in script directory."
    exit 1
fi
source "$SCRIPT_DIR/package.conf"

# Update system
apt update && apt upgrade -y

# Install all packages from package.conf arrays
apt install -y "${SYSTEM_UTILS[@]}" "${SYSTEM_UTILS_DEBIAN[@]}" \
               "${DEV_TOOLS[@]}" "${DEV_TOOLS_DEBIAN[@]}" \
               "${SECURITY[@]}" "${WEB_DEV[@]}"

# Enable and start services safely
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

# Install Oh-My-Zsh if missing
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Remove old configs before stow
rm -rf "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/nvim" \
       "$HOME/.config/lazygit" "$HOME/.zsh" "$HOME/.config/zellij" \
       "$HOME/.config/starship.toml" 2>/dev/null

# Dotfiles setup
cd ~
REPO_URL="https://github.com/hbabb/dotfiles.git"
REPO_NAME="dotfiles"

if ! command -v stow &> /dev/null; then
    echo "Error: 'stow' is not installed."
    exit 1
fi

if [ ! -d "$REPO_NAME" ]; then
    git clone "$REPO_URL" || { echo "Failed to clone dotfiles."; exit 1; }
fi

cd "$REPO_NAME"
stow bash git lazygit nvim zellij oh-my-zsh zsh starship || true

# Set zsh as default shell
if [ "$(which zsh)" != "$SHELL" ]; then
    chsh -s "$(which zsh)" || echo "Please change your shell manually."
fi

echo '. "$HOME/.asdf/asdf.sh"' >> ~/.zshrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.zshrc

echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc

echo "Setup complete. Restart terminal or log out/in."
cd "$ORIGINAL_DIR"
