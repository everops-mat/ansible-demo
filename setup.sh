#!/bin/bash
# Create user
if ! id "ansible" &>/dev/null; then
    sudo useradd -m -s /bin/bash ansible
fi

# Sudo rights
echo "ansible ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/ansible

# SSH Setup
sudo mkdir -p /home/ansible/.ssh
# Read from the uploaded file in /tmp
cat /tmp/ansible_key.pub | sudo tee -a /home/ansible/.ssh/authorized_keys

# Permissions
sudo chown -R ansible:ansible /home/ansible/.ssh
sudo chmod 700 /home/ansible/.ssh
sudo chmod 600 /home/ansible/.ssh/authorized_keys

echo "Ansible user setup complete!"
