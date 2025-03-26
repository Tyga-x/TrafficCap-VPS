#!/bin/bash

echo "Uninstalling Bandwidth Limiter..."

# Remove the global command
sudo rm -f /usr/local/bin/cap-vps

# Remove the main script directory
sudo rm -rf /usr/local/bin/cap-vps/

# Reset UFW rules
sudo ufw reset

# Remove vnstat data (optional)
sudo apt remove -y vnstat jq

echo "Uninstallation complete!"
