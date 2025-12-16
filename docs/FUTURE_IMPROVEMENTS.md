# Future Improvements

Ideas for expanding this Ansible demo that haven't been implemented yet.

## 1. Additional Datadog Integrations

### System Integrations
```yaml
# group_vars/dd_full.yml - Example additions
datadog_checks:
  # Process monitoring
  process:
    init_config:
    instances:
      - name: ssh
        search_string: ['sshd']
        exact_match: false
      - name: nginx
        search_string: ['nginx']

  # Disk check with custom thresholds
  disk:
    init_config:
    instances:
      - use_mount: false
        excluded_filesystems:
          - tmpfs
          - devtmpfs

  # Network check
  network:
    init_config:
    instances:
      - collect_connection_state: true
        excluded_interfaces:
          - lo
```

### Log Collection
```yaml
# Enable log collection in datadog_config
datadog_config:
  logs_enabled: true

# Configure log sources
datadog_logs:
  - type: file
    path: /var/log/syslog
    service: system
    source: syslog
  - type: file
    path: /var/log/auth.log
    service: security
    source: auth
```

### Docker Monitoring
```yaml
datadog_checks:
  docker:
    init_config:
    instances:
      - url: "unix://var/run/docker.sock"
        collect_container_size: true
        collect_images_stats: true
```

---

## 2. Role-Based Structure

Convert playbooks to proper Ansible roles for better reusability:

```
roles/
├── datadog-base/
│   ├── tasks/
│   │   └── main.yml
│   ├── handlers/
│   │   └── main.yml
│   ├── templates/
│   ├── defaults/
│   │   └── main.yml
│   └── meta/
│       └── main.yml
├── datadog-logs/
│   ├── tasks/
│   │   └── main.yml
│   └── defaults/
│       └── main.yml
├── datadog-apm/
│   └── ...
└── datadog-custom-checks/
    └── ...
```

### Example Role Structure
```yaml
# roles/datadog-base/tasks/main.yml
---
- name: Include OS-specific variables
  include_vars: "{{ ansible_os_family | lower }}.yml"

- name: Install Datadog agent
  include_role:
    name: datadog.datadog
  vars:
    datadog_api_key: "{{ dd_api_key }}"

- name: Configure base settings
  template:
    src: datadog.yaml.j2
    dest: /etc/datadog-agent/datadog.yaml
  notify: Restart datadog-agent
```

---

## 3. Multi-Environment Pattern

### Directory Structure
```
inventories/
├── development/
│   ├── hosts.ini
│   └── group_vars/
│       ├── all.yml
│       └── datadog.yml
├── staging/
│   ├── hosts.ini
│   └── group_vars/
│       └── ...
└── production/
    ├── hosts.ini
    └── group_vars/
        └── ...
```

### Environment-Specific Variables
```yaml
# inventories/development/group_vars/all.yml
---
environment: development
datadog_site: "datadoghq.com"
datadog_config:
  tags:
    - "env:development"
  log_level: debug

# inventories/production/group_vars/all.yml
---
environment: production
datadog_site: "datadoghq.com"
datadog_config:
  tags:
    - "env:production"
  log_level: warn
```

### Usage
```bash
# Deploy to development
ansible-playbook -i inventories/development/hosts.ini playbooks/site.yml

# Deploy to production
ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml
```

---

## 4. Datadog Monitors via API

Create alerts programmatically using Ansible and the Datadog API:

```yaml
# playbooks/datadog_monitors.yml
---
- name: Create Datadog Monitors
  hosts: localhost
  connection: local
  gather_facts: false

  vars_files:
    - secrets.yml

  tasks:
    - name: Create CPU monitor
      uri:
        url: "https://api.datadoghq.com/api/v1/monitor"
        method: POST
        headers:
          DD-API-KEY: "{{ datadog_api_key }}"
          DD-APPLICATION-KEY: "{{ datadog_app_key }}"
          Content-Type: "application/json"
        body_format: json
        body:
          name: "High CPU Usage Alert"
          type: "metric alert"
          query: "avg(last_5m):avg:system.cpu.user{env:vagrant_demo} > 80"
          message: |
            CPU usage is above 80% on {{host.name}}.
            @slack-alerts
          tags:
            - "env:vagrant_demo"
            - "managed_by:ansible"
          options:
            thresholds:
              critical: 80
              warning: 60
        status_code: [200, 201]

    - name: Create Disk Space monitor
      uri:
        url: "https://api.datadoghq.com/api/v1/monitor"
        method: POST
        headers:
          DD-API-KEY: "{{ datadog_api_key }}"
          DD-APPLICATION-KEY: "{{ datadog_app_key }}"
          Content-Type: "application/json"
        body_format: json
        body:
          name: "Low Disk Space Alert"
          type: "metric alert"
          query: "avg(last_5m):avg:system.disk.in_use{env:vagrant_demo} * 100 > 85"
          message: "Disk usage above 85% on {{host.name}}"
          tags:
            - "env:vagrant_demo"
```

---

## 5. Dynamic Inventory

Use Vagrant dynamic inventory instead of static hosts.ini:

```python
#!/usr/bin/env python3
# inventory/vagrant.py
"""Dynamic inventory script for Vagrant VMs"""

import subprocess
import json

def get_vagrant_ssh_config():
    result = subprocess.run(
        ['vagrant', 'ssh-config'],
        capture_output=True, text=True
    )
    # Parse and return inventory
    ...

if __name__ == '__main__':
    print(json.dumps(get_vagrant_ssh_config()))
```

Or use the community vagrant plugin:
```bash
ansible-galaxy collection install community.general
```

---

## 6. Ansible Vault for All Secrets

Encrypt all sensitive data:

```bash
# Create encrypted variable file
ansible-vault create group_vars/all/vault.yml

# Contents
datadog_api_key: "your-api-key"
datadog_app_key: "your-app-key"
slack_webhook: "https://hooks.slack.com/..."
```

Reference in playbooks:
```yaml
# group_vars/all/main.yml
api_key: "{{ vault_datadog_api_key }}"
```

---

## 7. CI/CD Integration

### GitHub Actions Example
```yaml
# .github/workflows/ansible-lint.yml
name: Ansible Lint

on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run ansible-lint
        uses: ansible/ansible-lint-action@v6
```

### Pre-commit Hooks
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/ansible/ansible-lint
    rev: v6.22.0
    hooks:
      - id: ansible-lint
```

---

## Implementation Priority

| Feature | Complexity | Value | Priority |
|---------|------------|-------|----------|
| Log Collection | Low | High | 1 |
| Process Monitoring | Low | High | 2 |
| Multi-Environment | Medium | High | 3 |
| Datadog Monitors API | Medium | Medium | 4 |
| Role-Based Structure | High | Medium | 5 |
| Dynamic Inventory | Medium | Low | 6 |
| CI/CD Integration | Low | Medium | 7 |
