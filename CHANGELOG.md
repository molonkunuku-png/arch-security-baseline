# Changelog

## [1.1.0] - 2026-08-06
- Added IPv6 rules to firewall/iptables.rules
- Added --help, --version, --dry-run, --restore to scripts/apply-hardening.sh
- Added timestamped backups before applying changes
- Added additional sysctl hardening (sysrq, stack guard gap, printk restrictions)
- Added MIT license with copyright holder "6mins"
- Added .gitignore

## [1.0.0] - 2026-08-05
- Initial release
- Baseline configs for auditd, firewall, lynis, ssh, sysctl
- Master apply-hardening script
