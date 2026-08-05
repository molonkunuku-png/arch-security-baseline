#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[*] DRY RUN — no changes will be made\n"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

command_exists() {
    command -v "$1" &>/dev/null
}

warn() { echo "[!] $*"; }
ok()   { echo "[+] $*"; }
skip() { echo "[-] $*"; }

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

echo "\n[*] Done. Reboot recommended for sysctl changes."
if $DRY_RUN; then
    echo "    Run without --dry-run to actually apply."
fi
