# Arch Security Baseline

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat&logo=archlinux&logoColor=white)
![MIT License](https://img.shields.io/badge/License-MIT-green.svg)

A curated set of security hardening configs for Arch Linux systems. Drop-in files with explanations, not just raw rules.

## Contents

| Path | Purpose |
|------|---------|
| `ssh/sshd_config` | SSH server hardening |
| `sysctl/hardening.conf` | Kernel network + memory hardening |
| `firewall/iptables.rules` | Basic iptables + ip6tables firewall |
| `auditd/audit.rules` | auditd monitoring rules |
| `lynis/lynis.conf` | Lynis security scanner profile |
| `scripts/apply-hardening.sh` | One-shot apply script with backups |

## Usage

Each directory has its own config file with inline comments. Apply individually or use the master script:

```bash
# Dry run first
sudo ./scripts/apply-hardening.sh --dry-run

# Apply everything
sudo ./scripts/apply-hardening.sh

# Restore from backup
sudo ./scripts/apply-hardening.sh --restore
```

## What this is NOT

- Not a complete hardening guide — it's a starting point
- Not guaranteed to work on every Arch setup
- Not a substitute for understanding each setting

## Warnings

- Test on a VM first. Some settings can break services.
- `sysctl` changes need a reboot or `sysctl --system` to take effect.
- Firewall rules assume a single NIC; adjust for your setup.
- These are baselines, not complete hardening. Tune to your environment.

## License

MIT — use it, fork it, break it, fix it.
