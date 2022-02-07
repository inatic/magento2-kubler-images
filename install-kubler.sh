#!/bin/bash
# Install in the user's home directory
git clone https://github.com/edannenberg/kubler.git ~/kubler

# Add to user's path variable so 'kubler' can be executed in any directory 
echo '' >> ~/.bashrc
echo "# Allow kubler command to be used from any directory" >> ~/.bashrc
echo 'export PATH="${PATH}:~/kubler/bin"' >> ~/.bashrc

# Kubler uses jq as JSON processor
apt-get install jq

# Enable auto-completion for kubler, open a new console for changes to take effect
echo "# Auto-complete kubler commands" >> ~/.bashrc
echo 'source ~/kubler/lib/kubler-completion.bash' >> ~/.bashrc

# Source .bashrc for changes to take effect
source ~/.bashrc
