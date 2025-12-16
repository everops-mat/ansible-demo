"""
Custom Datadog Check: Demo Check
Collects system metrics to demonstrate custom check deployment via Ansible.
"""

from datadog_checks.base import AgentCheck


class DemoCheck(AgentCheck):
    """A demo custom check that collects system information."""

    def check(self, instance):
        # Get configuration from instance
        metric_prefix = instance.get('metric_prefix', 'demo')
        tags = instance.get('tags', [])

        # Collect uptime
        try:
            with open('/proc/uptime', 'r') as f:
                uptime_seconds = float(f.read().split()[0])
            self.gauge(f'{metric_prefix}.uptime_seconds', uptime_seconds, tags=tags)
        except Exception as e:
            self.log.warning(f"Could not collect uptime: {e}")

        # Collect load average
        try:
            with open('/proc/loadavg', 'r') as f:
                load_parts = f.read().split()
                self.gauge(f'{metric_prefix}.load_1min', float(load_parts[0]), tags=tags)
                self.gauge(f'{metric_prefix}.load_5min', float(load_parts[1]), tags=tags)
                self.gauge(f'{metric_prefix}.load_15min', float(load_parts[2]), tags=tags)
        except Exception as e:
            self.log.warning(f"Could not collect load average: {e}")

        # Collect logged in users count
        try:
            import subprocess
            result = subprocess.run(['who'], capture_output=True, text=True)
            user_count = len(result.stdout.strip().split('\n')) if result.stdout.strip() else 0
            self.gauge(f'{metric_prefix}.logged_in_users', user_count, tags=tags)
        except Exception as e:
            self.log.warning(f"Could not collect user count: {e}")

        # Send a service check
        self.service_check(
            f'{metric_prefix}.health',
            AgentCheck.OK,
            tags=tags,
            message="Demo check is running successfully"
        )
