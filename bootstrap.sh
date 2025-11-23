
#!/bin/bash
# Install git if missing
if ! command -v git &> /dev/null; then
  apt update && apt install -y git
fi
# Clone your main repo
git clone https://github.com/yourusername/your-server-scripts-repo
cd your-server-scripts-repo
# Run the full setup
./setup.sh
