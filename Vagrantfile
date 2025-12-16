Vagrant.configure("2") do |config|
  # Ensure ansible key exists before proceeding
  unless File.exist?("./ansible_key.pub")
    abort("ERROR: ansible_key.pub not found. Run: ssh-keygen -t ed25519 -f ansible_key -N ''")
  end

  config.vm.box_check_update = false

  # Ubuntu nodes (1-3)
  (1..3).each do |i|
    config.vm.define "node#{i}" do |node|
      node.vm.box = "bento/ubuntu-22.04"
      node.vm.hostname = "node#{i}"

      # Static IPs! (Much easier for Ansible than ports)
      node.vm.network "private_network", ip: "192.168.56.1#{i}"

      node.vm.provider "vmware_desktop" do |v|
        v.gui = false
        v.memory = 1024
        v.cpus = 1
        v.linked_clone = true
        v.vmx["displayName"] = "ansible-demo-node#{i}"
        # Essential network fix for M3/M4 chips
        v.vmx["ethernet0.virtualDev"] = "vmxnet3"
        v.allowlist_verified = true
      end

      # Upload the public key so we don't rely on shared folders
      node.vm.provision "file", source: "./ansible_key.pub", destination: "/tmp/ansible_key.pub"

      # Run setup
      node.vm.provision "shell", path: "setup.sh"
    end
  end

  # Fedora node (node4)
  # Note: requires manual static IP due to vmtools issue on ARM
  config.vm.define "node4" do |node|
    node.vm.box = "bento/fedora-latest"
    node.vm.hostname = "node4"

    node.vm.network "private_network", ip: "192.168.56.14", netmask: "255.255.255.0"

    node.vm.provider "vmware_desktop" do |v|
      v.gui = false
      v.memory = 1024
      v.cpus = 1
      v.linked_clone = true
      v.vmx["displayName"] = "ansible-demo-node4"
      v.vmx["ethernet0.virtualDev"] = "vmxnet3"
      v.allowlist_verified = true
    end

    node.vm.provision "file", source: "./ansible_key.pub", destination: "/tmp/ansible_key.pub"
    node.vm.provision "shell", path: "setup-fedora.sh"
  end
end
