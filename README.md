# 🔥 Crucible Server

**Fast, flexible Linux server setup for developers**

Get from fresh install to fully configured development environment in minutes. Choose what you need, skip what you
don't.

---

## ✨ What You Get

- **Core Tools**: Zsh with Oh-My-Zsh, Neovim (latest), Zellij, FZF, and modern CLI tools
- **Your Dotfiles**: Automatically applied via GNU Stow from your [dotfiles repo](https://github.com/hbabb/dotfiles)
- **ASDF Version Manager**: Install any language runtime on demand
- **Optional Services**: Nginx, PostgreSQL, Redis - only if you need them
- **LXC Smart**: Automatically detects containers and skips incompatible services

---

## 🚀 Quick Start

**One-liner install:**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hbabb/crucible-server/main/bootstrap.sh)
```

The script will ask what you want installed:

1. Just core tools (default)
2. Core + Nginx
3. Core + Nginx + PostgreSQL
4. Core + full web stack (Nginx, PostgreSQL, Redis)

**Manual install:**

```bash
apt update && apt install -y git
git clone https://github.com/hbabb/crucible-server.git
cd crucible-server
chmod +x bootstrap.sh
./bootstrap.sh
```

---

## 🎯 Use Cases

**Quick dev environment:**

```bash
# Option 1: Just give me my tools
# Perfect for LXC containers or minimal setups
```

**Web development server:**

```bash
# Option 2 or 4: Install nginx and databases
# Full stack ready in one go
```

**Testing environments:**

```bash
# Spin up clean LXC containers with your exact config
# No Docker needed, no systemd conflicts
```

---

## 📦 What Gets Installed

**Always installed:**

- `zsh` + Oh-My-Zsh
- `neovim` (latest via PPA for LazyVim compatibility)
- `git`, `curl`, `wget`
- `stow` (dotfile management)
- `fzf`, `bat`, `htop`, `btop`
- `zellij` (terminal multiplexer)
- ASDF version manager

**Optional (you choose):**

- `nginx`
- `postgresql`
- `redis-server`
- `ufw`, `fail2ban` (not in LXC)

---

## 🔧 After Install

```bash
# Log out and back in (or run this)
exec zsh

# Install language runtimes with ASDF
asdf plugin add nodejs
asdf install nodejs latest
asdf global nodejs latest

# Check services (if installed)
systemctl status nginx
```

---

## 💡 Inspiration

This project was inspired by [Typecraft's Crucible](https://github.com/typecraft-dev/crucible), a NixOS-based system
configuration tool. While Crucible uses Nix for declarative system management, this project takes a simpler bash-based
approach optimized for Debian/Ubuntu servers and LXC containers.

---

## 🤝 Contributing

Have ideas for improvements? Found a bug? PRs and issues welcome!

---

## 📄 License

MIT

---

**Made with ☕ by [techsolvd](https://github.com/hbabb)**
