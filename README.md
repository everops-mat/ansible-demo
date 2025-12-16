# Ansible Demo

A demo environment for learning Ansible with Datadog agent deployment on Vagrant VMs.

## Prerequisites

- macOS with Apple Silicon (M1/M2/M3/M4)
- [Homebrew](https://brew.sh/)
- VMware Fusion
- Datadog account (for API key)

## Quick Start

### 1. Install Dependencies

```bash
brew install vagrant
brew install vagrant-vmware-utility
vagrant plugin install vagrant-vmware-desktop
```

### 2. Generate SSH Key

```bash
ssh-keygen -t ed25519 -f ansible_key -N ''
```

### 3. Create Vault Password

```bash
openssl rand -base64 32 > .vault_pass
```

### 4. Add Your Datadog API Key

```bash
ansible-vault create playbooks/secrets.yml
```

Add the following content:
```yaml
datadog_api_key: "YOUR_API_KEY_HERE"
datadog_app_key: "YOUR_APP_KEY_HERE"  # Required for dashboard/monitor creation
```

> **Note:** The `datadog_app_key` is required for the `ping_dashboard.yml` playbook which creates dashboards and monitors via the Datadog API. Get it from Datadog > Organization Settings > Application Keys.

### 5. Install Ansible Role

```bash
pip install ansible datadog   # or use a venv
ansible-galaxy install -r requirements.yml
```

### 6. Start VMs

```bash
vagrant up --provider=vmware_desktop
```

### 7. Run Playbooks

```bash
# Test connectivity
ansible all -m ping

# Run everything
ansible-playbook playbooks/site.yml

# Or run individual playbooks
ansible-playbook playbooks/maintenance.yml
ansible-playbook playbooks/datadog.yml
ansible-playbook playbooks/datadog-infra-basic.yml
```

## Project Structure

```
ansible-demo/
├── ansible.cfg           # Ansible configuration
├── hosts.ini             # Inventory file
├── requirements.yml      # Role dependencies
├── Vagrantfile           # VM definitions
├── setup-ubuntu.sh       # VM provisioning (Ubuntu)
├── setup-fedora.sh       # VM provisioning (Fedora)
├── group_vars/
│   ├── all.yml           # Shared variables
│   ├── dd_full.yml       # Full Datadog config
│   ├── dd_min.yml        # Minimal Datadog config
│   └── dd_infra_basic.yml # Infra basic Datadog config
├── playbooks/
│   ├── site.yml          # Master playbook
│   ├── maintenance.yml   # System updates
│   ├── datadog.yml       # Datadog full install
│   ├── datadog-minimal.yml # Datadog minimal install
│   ├── datadog-infra-basic.yml # Datadog infra basic (metrics + APM)
│   ├── ping_collector.yml  # Ping integration
│   ├── ping_dashboard.yml  # Dashboard and monitors for ping
│   ├── custom_check.yml  # Custom Datadog check deployment
│   ├── facts_demo.yml    # Facts-based configuration demo
│   ├── demo_check_mode.yml # Check mode demonstration
│   ├── rolling_update.yml  # Rolling update demonstration
│   └── secrets.yml       # Vault-encrypted secrets
├── files/
│   ├── ping_targets.csv  # Ping check targets (CSV)
│   └── checks.d/
│       └── demo_check.py # Custom Datadog check script
├── templates/
│   ├── ping.yaml.j2      # Datadog ping config
│   └── demo_check.yaml.j2 # Custom check config
├── docs/
│   └── FUTURE_IMPROVEMENTS.md
└── RUNBOOK.md            # Comprehensive demo guide
```

## Inventory Groups

| Group | Hosts | Description |
|-------|-------|-------------|
| `demo_nodes` | node1, node2, node3, node4 | All demo VMs |
| `dd_full` | node1 | Full Datadog agent |
| `dd_min` | node2 | Minimal Datadog (no APM/logs) |
| `dd_infra_basic` | node3, node4 | Infra basic Datadog (metrics + APM only) |

## VM Network

| Host | IP Address | OS |
|------|------------|-----|
| node1 | 192.168.56.11 | Ubuntu 22.04 |
| node2 | 192.168.56.12 | Ubuntu 22.04 |
| node3 | 192.168.56.13 | Ubuntu 22.04 |
| node4 | 192.168.56.14 | Fedora (latest) |

## Ping Targets Configuration

The Datadog ping integration reads targets from `files/ping_targets.csv`. This allows monitoring hosts outside the Ansible inventory.

### CSV Format

```csv
host,name,collect_response_time,timeout,tags
192.168.56.12,node2,true,4,target:node2,env:vagrant_demo
8.8.8.8,google-dns,true,10,external:true,service:dns
```

| Column | Required | Description |
|--------|----------|-------------|
| `host` | Yes | IP address or hostname to ping |
| `name` | Yes | Friendly name for the check |
| `collect_response_time` | No | Collect latency metrics (default: true) |
| `timeout` | No | Ping timeout in seconds |
| `tags` | Yes | Comma-separated tags in `key:value` format |

### Adding New Targets

Edit `files/ping_targets.csv` and run:
```bash
ansible-playbook playbooks/ping_collector.yml --tags configure
```

## Using Tags

Run specific parts of playbooks using tags:

```bash
# Run only Datadog-related tasks
ansible-playbook playbooks/site.yml --tags "datadog"

# Run only system maintenance
ansible-playbook playbooks/site.yml --tags "maintenance"

# Skip maintenance, run everything else
ansible-playbook playbooks/site.yml --skip-tags "maintenance"

# List all available tags
ansible-playbook playbooks/site.yml --list-tags
```

### Available Tags

| Tag | Description |
|-----|-------------|
| `datadog` | All Datadog-related tasks |
| `datadog-full` | Full Datadog agent install |
| `datadog-minimal` | Minimal Datadog install |
| `datadog-infra-basic` | Infra basic Datadog install (metrics + APM) |
| `integration` | Datadog integrations |
| `ping` | Ping integration |
| `dashboard` | Datadog dashboard creation |
| `monitor` | Datadog monitor creation |
| `custom-check` | Custom check deployment |
| `maintenance` | System maintenance |
| `update` | Package updates |
| `cleanup` | Package cleanup |
| `reboot` | Reboot handling |

## Demo Playbooks

### Check Mode (Dry Run)
Preview changes without applying them:
```bash
ansible-playbook playbooks/demo_check_mode.yml --check --diff
```

### Rolling Updates
Update hosts one at a time with health checks:
```bash
ansible-playbook playbooks/rolling_update.yml
```

### Facts Demo
See how Ansible gathers and uses system facts:
```bash
ansible-playbook playbooks/facts_demo.yml
```

### Custom Datadog Check
Deploy a custom Python check:
```bash
ansible-playbook playbooks/custom_check.yml
```

### Ping Dashboard and Monitors
Create a Datadog dashboard and monitors for the ping integration:
```bash
# Create both dashboard and monitors
ansible-playbook playbooks/ping_dashboard.yml

# Create only the dashboard
ansible-playbook playbooks/ping_dashboard.yml --tags dashboard

# Create only the monitors
ansible-playbook playbooks/ping_dashboard.yml --tags monitor
```

This playbook is **idempotent** - it will update existing resources instead of creating duplicates:
- Monitors use `community.general.datadog_monitor` (matches by name)
- Dashboard uses search-then-update logic (matches by title)

**Monitors created:**
| Monitor | Alert Condition |
|---------|-----------------|
| Host Unreachable | Ping fails for 5 minutes |
| High Response Time | Response time > 500ms (warn > 200ms) |

## Datadog Installation Modes

The demo supports three Datadog agent configurations:

| Mode | Playbook | Features | Use Case |
|------|----------|----------|----------|
| **Full** | `datadog.yml` | All features enabled | Production monitoring |
| **Minimal** | `datadog-minimal.yml` | No APM, no logs | Low-overhead monitoring |
| **Infra Basic** | `datadog-infra-basic.yml` | Metrics + APM, no logs | Cost-effective APM |

### Infra Basic Mode
The `dd_infra_basic` group uses a lightweight configuration ideal for infrastructure monitoring with APM tracing but without log collection:

```bash
ansible-playbook playbooks/datadog-infra-basic.yml
```

Configuration (`group_vars/dd_infra_basic.yml`):
- Logs: disabled
- APM: enabled
- Process collection: disabled
- Tags: `env:vagrant_demo`, `role:web_node`, `mode:infra_basic`

## Common Commands

```bash
# VM management
vagrant up                    # Start all VMs
vagrant halt                  # Stop all VMs
vagrant destroy -f            # Delete all VMs
vagrant ssh node1             # SSH into node1

# Ansible
ansible all -m ping           # Test connectivity
ansible-playbook playbooks/site.yml  # Run all playbooks
ansible-vault edit playbooks/secrets.yml  # Edit secrets

# Check syntax
ansible-playbook --syntax-check playbooks/site.yml

# Dry run with diff
ansible-playbook playbooks/site.yml --check --diff
```

## Troubleshooting

**SSH connection issues:**
```bash
ansible all -m ping -vvv
```

**Re-provision a VM:**
```bash
vagrant provision node1
```

**Reset everything:**
```bash
vagrant destroy -f && vagrant up --provider=vmware_desktop
```
