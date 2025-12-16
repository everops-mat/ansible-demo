#!/bin/bash
# Install open-vm-tools for proper VMware integration (IP reporting)
sudo zypper install -y open-vm-tools
sudo systemctl enable --now vmtoolsd

# Ensure all network interfaces are up
sudo systemctl restart wicked || sudo systemctl restart NetworkManager

# Ensure Python is installed (required by Ansible)
sudo zypper install -y python3

# Create user
if ! id "ansible" &>/dev/null; then
    sudo useradd -m -s /bin/bash ansible
fi

# Sudo rights
echo "ansible ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/ansible

# SSH Setup
sudo mkdir -p /home/ansible/.ssh

# Idempotent key setup - only add if not present
if ! sudo grep -qF "$(cat /tmp/ansible_key.pub)" /home/ansible/.ssh/authorized_keys 2>/dev/null; then
    cat /tmp/ansible_key.pub | sudo tee -a /home/ansible/.ssh/authorized_keys
fi

# Cleanup temp file
rm -f /tmp/ansible_key.pub

# Permissions
sudo chown -R ansible:ansible /home/ansible/.ssh
sudo chmod 700 /home/ansible/.ssh
sudo chmod 600 /home/ansible/.ssh/authorized_keys

echo "Ansible user setup complete!"
