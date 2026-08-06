#!/usr/bin/env bash
set -euo pipefail

VERSION="1.1.0"
DRY_RUN=false
RESTORE=false
BACKUP_DIR=""

usage() {
    cat <<USAGE
Usage: $(basename "$0") [OPTIONS]

Options:
  --dry-run    Preview changes without applying
  --restore    Restore from backup
  --backup DIR Backup directory to restore from (default: .backup)
  --help       Show this help
  --version    Show version

Examples:
  $(basename "$0") --dry-run
  $(basename "$0")
  $(basename "$0") --restore
  $(basename "$0") --restore --backup /var/backups/arch-baseline
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --restore)
            RESTORE=true
            shift
            ;;
        --backup)
            BACKUP_DIR="${2:-}"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        --version)
            echo "$VERSION"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if $RESTORE; then
    BACKUP_DIR="${BACKUP_DIR:-$(dirname "$0")/../.backup}"
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "Backup directory not found: $BACKUP_DIR" >&2
        exit 1
    fi
    echo "[*] Restoring from backup: $BACKUP_DIR"
    if [[ -f "$BACKUP_DIR/sysctl.conf" ]]; then
        sudo cp "$BACKUP_DIR/sysctl.conf" /etc/sysctl.d/99-hardening.conf
        sudo sysctl --system
    fi
    if [[ -f "$BACKUP_DIR/sshd_config" ]]; then
        sudo cp "$BACKUP_DIR/sshd_config" /etc/ssh/sshd_config.d/99-hardening.conf
        sudo sshd -t && sudo systemctl reload sshd
    fi
    if [[ -f "$BACKUP_DIR/iptables.rules" ]]; then
        sudo cp "$BACKUP_DIR/iptables.rules" /etc/iptables/iptables.rules
        sudo iptables-restore < "$BACKUP_DIR/iptables.rules"
    fi
    if [[ -f "$BACKUP_DIR/audit.rules" ]]; then
        sudo cp "$BACKUP_DIR/audit.rules" /etc/audit/rules.d/99-hardening.rules
        sudo augenrules --load
    fi
    if [[ -f "$BACKUP_DIR/lynis.prf" ]]; then
        sudo cp "$BACKUP_DIR/lynis.prf" /etc/lynis/custom.prf
    fi
    echo "[+] Restore complete"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

command_exists() { command -v "$1" &>/dev/null; }
warn() { echo "[!] $*"; }
ok()   { echo "[+] $*"; }
skip() { echo "[-] $*"; }
fail() { echo "[x] $*" >&2; exit 1; }

echo "[*] Arch Security Baseline v${VERSION}"
$DRY_RUN && echo "[*] DRY RUN — no changes will be made"
echo ""

# Preflight checks
for cmd in sudo sysctl iptables-restore sshd auditctl augenrules; do
    if ! command_exists "$cmd"; then
        warn "$cmd not found — some checks will be skipped"
    fi
done

# Create backup directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BASE_DIR}/.backup/${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

echo "[*] Backup directory: $BACKUP_DIR"

# Backup existing configs
[[ -f /etc/sysctl.d/99-hardening.conf ]] && sudo cp /etc/sysctl.d/99-hardening.conf "$BACKUP_DIR/sysctl.conf"
[[ -f /etc/ssh/sshd_config.d/99-hardening.conf ]] && sudo cp /etc/ssh/sshd_config.d/99-hardening.conf "$BACKUP_DIR/sshd_config"
[[ -f /etc/iptables/iptables.rules ]] && sudo cp /etc/iptables/iptables.rules "$BACKUP_DIR/iptables.rules"
[[ -f /etc/audit/rules.d/99-hardening.rules ]] && sudo cp /etc/audit/rules.d/99-hardening.rules "$BACKUP_DIR/audit.rules"
[[ -f /etc/lynis/custom.prf ]] && sudo cp /etc/lynis/custom.prf "$BACKUP_DIR/lynis.prf"

# --- sysctl ---
if [[ -f "$BASE_DIR/sysctl/hardening.conf" ]]; then
    if command_exists sysctl; then
        if $DRY_RUN; then
            echo "[DRY] Would apply sysctl rules from $BASE_DIR/sysctl/hardening.conf"
        else
            echo "[*] Applying sysctl hardening..."
            sudo cp "$BASE_DIR/sysctl/hardening.conf" /etc/sysctl.d/99-hardening.conf
            sudo sysctl --system
            ok "sysctl applied"
        fi
    else
        skip "sysctl not found — skip"
    fi
else
    warn "sysctl/hardening.conf not found"
fi

# --- iptables ---
if [[ -f "$BASE_DIR/firewall/iptables.rules" ]]; then
    if command_exists iptables-restore; then
        if $DRY_RUN; then
            echo "[DRY] Would load iptables rules from $BASE_DIR/firewall/iptables.rules"
        else
            echo "[*] Loading iptables rules..."
            sudo iptables-restore < "$BASE_DIR/firewall/iptables.rules"
            ok "iptables rules loaded (reboot to make persistent — or install iptables-save)"
        fi
    else
        skip "iptables-restore not found — skip"
    fi
else
    warn "firewall/iptables.rules not found"
fi

# --- sshd ---
if [[ -f "$BASE_DIR/ssh/sshd_config" ]]; then
    if command_exists sshd; then
        if $DRY_RUN; then
            echo "[DRY] Would copy sshd_config to /etc/ssh/sshd_config.d/99-hardening.conf"
        else
            echo "[*] Deploying SSH hardening..."
            sudo mkdir -p /etc/ssh/sshd_config.d
            sudo cp "$BASE_DIR/ssh/sshd_config" /etc/ssh/sshd_config.d/99-hardening.conf
            if sudo sshd -t; then
                sudo systemctl reload sshd
                ok "sshd config valid and reloaded"
            else
                warn "sshd config test failed — NOT reloading. Fix syntax first."
                exit 1
            fi
        fi
    else
        skip "sshd not found — skip"
    fi
else
    warn "ssh/sshd_config not found"
fi

# --- auditd ---
if [[ -f "$BASE_DIR/auditd/audit.rules" ]]; then
    if command_exists auditctl; then
        if $DRY_RUN; then
            echo "[DRY] Would copy audit rules to /etc/audit/rules.d/99-hardening.rules"
        else
            echo "[*] Deploying auditd rules..."
            sudo mkdir -p /etc/audit/rules.d
            sudo cp "$BASE_DIR/auditd/audit.rules" /etc/audit/rules.d/99-hardening.rules
            sudo augenrules --load
            ok "auditd rules loaded"
        fi
    else
        skip "auditctl not found — install audit package first"
    fi
else
    warn "auditd/audit.rules not found"
fi

# --- lynis ---
if [[ -f "$BASE_DIR/lynis/lynis.conf" ]]; then
    if $DRY_RUN; then
        echo "[DRY] Would copy lynis profile to /etc/lynis/custom.prf"
    else
        echo "[*] Installing Lynis profile..."
        sudo mkdir -p /etc/lynis
        sudo cp "$BASE_DIR/lynis/lynis.conf" /etc/lynis/custom.prf
        ok "Lynis profile installed (run: sudo lynis audit profile=custom)"
    fi
else
    warn "lynis/lynis.conf not found"
fi

echo ""
if ! $DRY_RUN; then
    echo "[*] Done. Reboot recommended for sysctl changes."
    echo "[*] Backup saved to: $BACKUP_DIR"
    echo "[*] To restore: $(basename "$0") --restore --backup $BACKUP_DIR"
fi
