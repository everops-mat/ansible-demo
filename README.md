# A Simple Ansible Demo

1. `brew install vagrant`

2. Install VMware Fusion.

3. Install the Vagrant VMware Plugin.
  a. `vagrant plugin install vagrant-qemu`
  b. `brew install vagrant-vmware-utility`

5. Create a working directory.
  a. `mkdir ~/ansible-demo`

6. Create ansible ssh key.
  a. `ssh-keygen -t ed25519 -C "ansible demo" -f ansible_key -N ""`

7. Make sure the `seutp.sh` and `Vagrantfile` are created.

8. Start the VMs.
  a. `vagrant up --provider=vmware_desktop`

9. Install the Datadog Ansible Playbook
  a. `ansible-galaxy install Datadog.datadog`

10. Create a vault password file.
  a. `openssl rand -base64 32 > .vault_pass`

11.
