# Ansible Demo Runbook

A comprehensive guide for demonstrating Ansible's capabilities using Datadog agent deployment as a practical example.

---

## Overview

### What is Ansible?

Ansible is an open-source automation tool that enables:

- **Configuration Management** - Define and enforce system state
- **Application Deployment** - Deploy software consistently across environments
- **Infrastructure as Code** - Version control your infrastructure
- **Orchestration** - Coordinate multi-tier deployments

### Key Characteristics

| Feature | Description |
|---------|-------------|
| **Agentless** | No software to install on managed nodes - uses SSH/WinRM |
| **Declarative** | Describe desired state, not procedures |
| **Idempotent** | Safe to run multiple times - only makes necessary changes |
| **Human-Readable** | YAML-based playbooks anyone can understand |

### Why Ansible for Datadog?

- Deploy agents consistently across hundreds of servers
- Enforce configuration standards (tags, integrations, settings)
- Version control your monitoring configuration
- Audit trail of all changes
- Easily onboard new servers with complete monitoring

---

## Demo Environment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Host Machine (macOS)                     │
│                                                              │
│  ┌────────────────┐                                         │
│  │ Ansible Control│                                         │
│  │    Machine     │                                         │
│  └───────┬────────┘                                         │
│          │ SSH (ansible_key)                                │
│          │                                                  │
│  ┌───────┴──────────────────────────────────────────┐      │
│  │              VMware Fusion VMs                    │      │
│  │                                                   │      │
│  │  ┌─────────┐   ┌─────────┐   ┌─────────┐        │      │
│  │  │  node1  │   │  node2  │   │  node3  │        │      │
│  │  │ .56.11  │   │ .56.12  │   │ .56.13  │        │      │
│  │  │         │   │         │   │         │        │      │
│  │  │ DD Full │   │ DD Min  │   │ DD Min  │        │      │
│  │  │ + Ping  │   │         │   │         │        │      │
│  │  └─────────┘   └─────────┘   └─────────┘        │      │
│  │                                                   │      │
│  │  Group: dd_full    Group: dd_min                 │      │
│  └───────────────────────────────────────────────────┘      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Node Configuration

| Node | IP Address | Datadog Config | Purpose |
|------|------------|----------------|---------|
| node1 | 192.168.56.11 | Full (APM, Logs, Integrations) | Primary monitoring node |
| node2 | 192.168.56.12 | Minimal (metrics only) | Lightweight monitoring |
| node3 | 192.168.56.13 | Minimal (metrics only) | Lightweight monitoring |

---

## Part 1: Environment Setup

### Prerequisites

Before starting, ensure you have:

- macOS with Apple Silicon (M1/M2/M3/M4)
- Homebrew installed
- VMware Fusion installed and licensed
- A Datadog account with API key

### Step 1: Install Vagrant and VMware Plugin

```bash
# Install Vagrant
brew install vagrant

# Install VMware utility (required for plugin)
brew install vagrant-vmware-utility

# Install Vagrant VMware plugin
vagrant plugin install vagrant-vmware-desktop
```

**What this does:** Vagrant is a tool for building and managing virtual machine environments. The VMware plugin allows Vagrant to create VMs using VMware Fusion.

### Step 2: Clone the Repository

```bash
git clone <repository-url>
cd ansible-demo
```

### Step 3: Generate SSH Key for Ansible

```bash
ssh-keygen -t ed25519 -f ansible_key -N ''
```

**What this does:** Creates a dedicated SSH key pair for Ansible to authenticate to managed nodes. The `-N ''` creates it without a passphrase for automation purposes.

**Files created:**

- `ansible_key` - Private key (kept secret, used by Ansible)
- `ansible_key.pub` - Public key (deployed to VMs)

### Step 4: Create Python Virtual Environment

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install ansible datadog
```

**What this does:** Creates an isolated Python environment for Ansible and the Datadog Python library (required for the `datadog_monitor` module), avoiding conflicts with system packages.

### Step 5: Install Ansible Role Dependencies

```bash
ansible-galaxy install -r requirements.yml
```

**What this does:** Downloads the official Datadog Ansible role from Ansible Galaxy, which provides pre-built tasks for installing and configuring the Datadog agent.

### Step 6: Create Vault Password

```bash
openssl rand -base64 32 > .vault_pass
```

**What this does:** Generates a random password used to encrypt sensitive data (like API keys) in Ansible Vault.

### Step 7: Configure Datadog API Key

```bash
ansible-vault create playbooks/secrets.yml
```

When prompted, enter:

```yaml
datadog_api_key: "YOUR_ACTUAL_API_KEY_HERE"
datadog_app_key: "YOUR_ACTUAL_APP_KEY_HERE"
```

**What this does:** Creates an encrypted file storing your Datadog API and App keys. The keys are never stored in plain text and can be safely committed to version control.

> **Note:** The `datadog_app_key` is required for creating dashboards and monitors via the API. Get it from Datadog > Organization Settings > Application Keys.

### Step 8: Start Virtual Machines

```bash
vagrant up --provider=vmware_desktop
```

**What this does:**

1. Downloads Ubuntu 22.04 base image (first run only)
2. Creates 3 virtual machines
3. Configures networking (static IPs)
4. Runs `setup.sh` provisioner to create ansible user and deploy SSH key

**Expected duration:** 5-10 minutes on first run, ~2 minutes on subsequent runs (linked clones).

### Step 9: Verify Connectivity

```bash
ansible all -m ping
```

**Expected output:**

```
node1 | SUCCESS => {"ping": "pong"}
node2 | SUCCESS => {"ping": "pong"}
node3 | SUCCESS => {"ping": "pong"}
```

---

## Part 2: Understanding the Ansible Structure

### Directory Layout

```
ansible-demo/
├── ansible.cfg          # Ansible configuration
├── hosts.ini            # Inventory (which servers to manage)
├── requirements.yml     # External role dependencies
├── group_vars/          # Variables by group
│   ├── all.yml          # Applied to all hosts
│   ├── dd_full.yml      # Full Datadog config
│   └── dd_min.yml       # Minimal Datadog config
├── playbooks/           # Automation scripts
├── templates/           # Jinja2 templates for config files
└── files/               # Static files to deploy
```

### Key Concepts

#### Inventory (`hosts.ini`)

Defines which servers Ansible manages and how to connect:

```ini
node1 ansible_host=192.168.56.11
node2 ansible_host=192.168.56.12
node3 ansible_host=192.168.56.13

[demo_nodes]       # Group containing all nodes
node1
node2
node3

[dd_full]          # Nodes getting full Datadog
node1

[dd_min]           # Nodes getting minimal Datadog
node2
node3
```

#### Playbooks

YAML files describing automation tasks:

```yaml
---
- name: Install Datadog Agent    # Human-readable description
  hosts: dd_full                 # Target these servers
  become: true                   # Use sudo

  tasks:
    - name: Install package      # Each task has a name
      ansible.builtin.apt:       # Module to use
        name: datadog-agent
        state: present
```

#### Variables and Group Variables

Variables can be defined at multiple levels:

- `group_vars/all.yml` - Applied to every host
- `group_vars/dd_full.yml` - Only for hosts in `dd_full` group
- Playbook `vars:` section - Only for that playbook
- Command line `--extra-vars` - Highest priority

#### Templates (Jinja2)

Dynamic configuration files:

```yaml
# templates/ping.yaml.j2
instances:
{% for target in ping_targets %}
  - host: {{ target.host }}
    name: {{ target.name }}
{% endfor %}
```

---

## Part 3: Running the Demo

### Demo 1: Basic Connectivity Test

**Concept:** Ansible's ad-hoc commands for quick tasks

```bash
# Ping all nodes
ansible all -m ping

# Get system facts from one node
ansible node1 -m setup | head -50

# Run a command on all nodes
ansible all -m command -a "uptime"

# Check disk space on all nodes
ansible all -m command -a "df -h /"
```

**Teaching points:**

- Ansible connects via SSH, no agent needed
- Modules abstract common operations
- Parallel execution by default

### Demo 2: System Maintenance

**Concept:** Playbook execution and idempotency

```bash
# Run maintenance playbook
ansible-playbook playbooks/maintenance.yml
```

**Run it again to demonstrate idempotency:**

```bash
ansible-playbook playbooks/maintenance.yml
```

**Teaching points:**

- Tasks report: `changed` (action taken) vs `ok` (already in desired state)
- Second run shows mostly `ok` - idempotent!
- Safe to run repeatedly without side effects

### Demo 3: Datadog Agent Deployment

**Concept:** Role-based deployment and group targeting

```bash
# Deploy to all Datadog hosts
ansible-playbook playbooks/site.yml --tags "datadog"

# Or deploy to specific groups
ansible-playbook playbooks/datadog.yml        # Full install (node1)
ansible-playbook playbooks/datadog-minimal.yml # Minimal (node2, node3)
```

**Verify installation:**

```bash
ansible dd_full -m command -a "datadog-agent status" --become
```

**Teaching points:**

- Same role, different configurations via group_vars
- Tags allow selective execution
- Roles encapsulate complex logic (official Datadog role)

### Demo 4: Check Mode (Dry Run)

**Concept:** Preview changes before applying

```bash
ansible-playbook playbooks/demo_check_mode.yml --check --diff
```

**Teaching points:**

- `--check` shows what WOULD change
- `--diff` shows exact file differences
- Essential for change management and code review
- Some tasks can override with `check_mode: false`

### Demo 5: Facts-Based Configuration

**Concept:** Dynamic configuration based on system properties

```bash
ansible-playbook playbooks/facts_demo.yml
```

**Teaching points:**

- Ansible automatically gathers system facts
- Facts enable conditional logic (OS, memory, CPU)
- Dynamic tagging based on infrastructure
- Reports generated per-host

### Demo 6: Rolling Updates

**Concept:** Safe updates with health checks

```bash
ansible-playbook playbooks/rolling_update.yml
```

**Teaching points:**

- `serial: 1` updates one host at a time
- Pre/post tasks for validation
- Health checks with retries
- Automatic rollback on failure

### Demo 7: Custom Datadog Check

**Concept:** Deploying custom monitoring

```bash
ansible-playbook playbooks/custom_check.yml
```

**Verify the check:**

```bash
ansible dd_full -m command -a "sudo -u dd-agent datadog-agent check demo_check" --become
```

**Teaching points:**

- Deploy Python scripts with `copy` module
- Template configuration files
- Validate deployment inline
- Handler triggers restart only when needed

### Demo 8: Using Tags for Selective Runs

**Concept:** Granular control over execution

```bash
# List all available tags
ansible-playbook playbooks/site.yml --list-tags

# Run only Datadog tasks
ansible-playbook playbooks/site.yml --tags "datadog"

# Skip maintenance
ansible-playbook playbooks/site.yml --skip-tags "maintenance"

# Multiple tags
ansible-playbook playbooks/site.yml --tags "datadog,ping"
```

**Teaching points:**

- Tags enable partial playbook execution
- Useful for large playbooks
- Speed up development/testing cycles

### Demo 9: External Configuration (CSV)

**Concept:** Data-driven configuration

```bash
# Show the CSV file
cat files/ping_targets.csv

# Deploy ping configuration
ansible-playbook playbooks/ping_collector.yml --tags configure
```

**Teaching points:**

- Configuration can come from external sources
- CSV, JSON, databases, APIs all possible
- Separation of data from logic

### Demo 10: Datadog Dashboard and Monitors via API

**Concept:** Managing cloud resources with Ansible

```bash
# Create dashboard and monitors
ansible-playbook playbooks/ping_dashboard.yml

# Run again to demonstrate idempotency
ansible-playbook playbooks/ping_dashboard.yml
```

**What gets created:**

| Resource | Name | Description |
|----------|------|-------------|
| Dashboard | Ping Collector - Network Reachability | Visualizes ping metrics |
| Monitor | [Ping Collector] Host Unreachable | Alerts when host stops responding |
| Monitor | [Ping Collector] High Response Time | Warns > 200ms, critical > 500ms |

**Run with tags:**

```bash
# Only create/update dashboard
ansible-playbook playbooks/ping_dashboard.yml --tags dashboard

# Only create/update monitors
ansible-playbook playbooks/ping_dashboard.yml --tags monitor
```

**Teaching points:**

- Ansible can manage cloud resources via APIs, not just servers
- `community.general.datadog_monitor` module provides idempotent monitor management
- Dashboard uses search-then-update pattern for idempotency
- Infrastructure-as-code extends to monitoring configuration
- Monitors and dashboards can be version controlled alongside infrastructure

---

## Part 4: Key Ansible Concepts Demonstrated

### 1. Idempotency

**Definition:** Running the same playbook multiple times produces the same result.

**Why it matters:**

- Safe to re-run after failures
- No fear of "double-applying" changes
- Enables continuous enforcement of desired state

**Demo:** Run any playbook twice, observe `changed=0` on second run.

### 2. Declarative vs Imperative

**Imperative (scripts):** "Install package, then edit file, then restart service"

**Declarative (Ansible):** "Package should be installed, file should contain X, service should be running"

Ansible figures out how to achieve the desired state.

### 3. Inventory and Groups

Organize hosts logically:

- By environment: `[production]`, `[staging]`
- By role: `[webservers]`, `[databases]`
- By location: `[us-east]`, `[eu-west]`

Target specific groups or combinations:

```bash
ansible 'webservers:&production' -m ping  # Webservers AND production
ansible 'webservers:!staging' -m ping     # Webservers NOT in staging
```

### 4. Variables and Precedence

Variables can be defined at 22 different levels! Key ones (lowest to highest priority):

1. Role defaults
2. Inventory group_vars
3. Playbook vars
4. Task vars
5. Extra vars (`-e`)

### 5. Handlers

Tasks that run only when notified:

```yaml
tasks:
  - name: Update config
    template: ...
    notify: Restart service    # Only triggers if task changes

handlers:
  - name: Restart service
    service:
      name: myservice
      state: restarted
```

**Benefit:** Service restarts once at end, not after every config change.

### 6. Jinja2 Templating

Dynamic configuration files:

- Variable substitution: `{{ variable }}`
- Conditionals: `{% if condition %}...{% endif %}`
- Loops: `{% for item in list %}...{% endfor %}`
- Filters: `{{ variable | upper }}`

### 7. Ansible Vault

Encrypt sensitive data:

```bash
ansible-vault create secrets.yml   # Create encrypted file
ansible-vault edit secrets.yml     # Edit encrypted file
ansible-vault view secrets.yml     # View contents
```

Playbooks automatically decrypt when run (using vault password).

---

## Part 5: Real-World Applications

### Use Case 1: New Server Onboarding

When a new server is provisioned:

1. Add to inventory
2. Run site.yml
3. Server is fully configured with monitoring

**Time savings:** Hours → Minutes

### Use Case 2: Configuration Drift Detection

```bash
ansible-playbook site.yml --check --diff
```

Shows any manual changes that deviate from defined state.

### Use Case 3: Emergency Patching

```bash
ansible all -m apt -a "name=openssl state=latest" --become
```

Patch all servers in seconds, not hours.

### Use Case 4: Audit and Compliance

- All configurations in version control
- Git history shows who changed what, when
- Playbooks serve as documentation
- `--check` mode for compliance verification

### Use Case 5: Multi-Environment Consistency

Same playbooks, different inventories:

```bash
ansible-playbook -i inventories/staging site.yml
ansible-playbook -i inventories/production site.yml
```

Guarantee staging matches production.

---

## Troubleshooting Guide

### Connection Issues

```bash
# Verbose output
ansible all -m ping -vvv

# Test specific host
ssh -i ansible_key ansible@192.168.56.11

# Check SSH key permissions
ls -la ansible_key  # Should be 600 or 400
```

### Playbook Debugging

```bash
# Step through tasks one at a time
ansible-playbook playbooks/site.yml --step

# Start at specific task
ansible-playbook playbooks/site.yml --start-at-task="Install Datadog"

# Limit to specific host
ansible-playbook playbooks/site.yml --limit node1
```

### Variable Debugging

```bash
# Show all variables for a host
ansible node1 -m debug -a "var=hostvars[inventory_hostname]"

# Show specific variable
ansible node1 -m debug -a "var=datadog_config"
```

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Permission denied (publickey)" | SSH key not deployed | Re-run `vagrant provision` |
| "No hosts matched" | Wrong group name | Check inventory |
| "Vault password required" | Missing vault password | Ensure `.vault_pass` exists |
| "Module not found" | Missing collection | Run `ansible-galaxy install -r requirements.yml` |

---

## Cleanup

### Stop VMs (preserve state)

```bash
vagrant halt
```

### Destroy VMs (delete everything)

```bash
vagrant destroy -f
```

### Full Reset

```bash
vagrant destroy -f
vagrant up --provider=vmware_desktop
ansible-playbook playbooks/site.yml
```

---

## Summary

### What We Demonstrated

1. **Infrastructure as Code** - VM and Ansible configuration in version control
2. **Agentless Automation** - SSH-based, nothing to install on targets
3. **Idempotent Operations** - Safe to run repeatedly
4. **Role-Based Configuration** - Reusable, community-supported roles
5. **Secrets Management** - Ansible Vault for sensitive data
6. **Selective Execution** - Tags for granular control
7. **Dry Run Capability** - Preview changes before applying
8. **Facts-Based Logic** - Dynamic configuration based on system properties
9. **Rolling Updates** - Safe, controlled deployments
10. **External Data Sources** - CSV-driven configuration
11. **Cloud Resource Management** - Dashboards and monitors via API

### Key Takeaways

- Ansible reduces manual work and human error
- Configuration becomes documentation
- Changes are auditable and reversible
- Same playbooks work across environments
- Start simple, grow complexity as needed

### Next Steps

- Explore `docs/FUTURE_IMPROVEMENTS.md` for advanced patterns
- Try adding a new integration to the Datadog setup
- Experiment with the CSV ping targets
- Build your own custom check
- Modify the dashboard widgets or add new monitors

---

## Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Datadog Ansible Role](https://github.com/DataDog/ansible-datadog)
- [Ansible Galaxy](https://galaxy.ansible.com/) - Community roles
- [Ansible Lint](https://ansible-lint.readthedocs.io/) - Best practices checker
