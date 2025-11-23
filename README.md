# Crucible-Server

**Linux Server System Crafting Tool**
Automate the setup of Debian/Ubuntu servers for DevOps, web development, and security.

---

## **Features**

- Installs essential utilities, dev tools, and security packages.
- Sets up Docker, Kubernetes, Nginx, PostgreSQL, Redis, and Fail2Ban.
- Configures Oh-My-Zsh, Neovim, Zellij, and Starship.
- Uses GNU Stow for dotfile managment.

---

## **Prerequisites**

- A fresh Debian/Ubuntu Linux installation.
- `curl` (preinstalled on most systems).

---

## **Quick Start**

Run the following command to bootstrap your server:

```bash
curl -fsSL https://raw.githubusercontent.com/hbabb/crucible-server/master/bootstrap.sh
```

## **Manual Setup (Alternative)**

1. Install git
   `apt update && apt install -y git`
2. Clone the repo
   `git clone https://github.com/hbabb/crucible-server ~/crucible-server`
   `cd crucible-server`
3. Run the setup script
   `./setup.sh`

---

## Customization

- Edit `package.conf` to add/remove packages.
- Update the `PACKAGES` array in `setup.sh` to stow additional dotfiles.

## **License**

MIT

```

```
