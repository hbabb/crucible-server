#!/bin/bash
# Install git if missing
if ! command -v git &> /dev/null; then
  apt update && apt install -y git
fi
# Clone your main repo
git clone https://github.com/hbabb/dotfiles.git
cd dotfiles
# Run the full setup
./setup.sh
