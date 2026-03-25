#!/bin/bash
# =============================================================
#  cleanup.sh — Linux Network Namespace Simulation — Cleanup
#  Run:  sudo ./cleanup.sh
#  Safe to run multiple times — skips anything already gone.
# =============================================================

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

# ---------- Helpers ----------
print_header() {
    echo -e "\n${CYAN}=================================================${NC}"
    echo -e "  ${BLUE}$1${NC}"
    echo -e "${CYAN}=================================================${NC}"
}

print_section() {
    echo -e "\n${YELLOW}--- $1 ---${NC}"
}

print_ok() {
    echo -e "${GREEN}✔ $1${NC}"
}

print_skip() {
    echo -e "${YELLOW}➜ $1${NC}"
}

print_fail() {
    echo -e "${RED}✘ $1${NC}"
}

# ---------- Root Check ----------
if [ "$EUID" -ne 0 ]; then
    print_fail "Please run as root: sudo ./cleanup.sh"
    exit 1
fi

print_header "Network Namespace Lab — Cleanup"

# ---------------------------------------------------------
print_section "Removing namespaces"

ip netns del ns1       2>/dev/null && print_ok "ns1 removed"       || print_skip "ns1 not found, skipping"
ip netns del ns2       2>/dev/null && print_ok "ns2 removed"       || print_skip "ns2 not found, skipping"
ip netns del router-ns 2>/dev/null && print_ok "router-ns removed" || print_skip "router-ns not found, skipping"

# ---------------------------------------------------------
print_section "Removing leftover interfaces"

ip link del veth-ns1-br  2>/dev/null && print_ok "veth-ns1-br removed"  || print_skip "veth-ns1-br not found, skipping"
ip link del veth-ns2-br  2>/dev/null && print_ok "veth-ns2-br removed"  || print_skip "veth-ns2-br not found, skipping"
ip link del veth-rtr0-br 2>/dev/null && print_ok "veth-rtr0-br removed" || print_skip "veth-rtr0-br not found, skipping"
ip link del veth-rtr1-br 2>/dev/null && print_ok "veth-rtr1-br removed" || print_skip "veth-rtr1-br not found, skipping"

# ---------------------------------------------------------
print_section "Removing bridges"

ip link set br0 down 2>/dev/null
ip link del br0 2>/dev/null && print_ok "br0 removed" || print_skip "br0 not found, skipping"

ip link set br1 down 2>/dev/null
ip link del br1 2>/dev/null && print_ok "br1 removed" || print_skip "br1 not found, skipping"

# ---------------------------------------------------------
print_section "Restoring firewall"

iptables -D FORWARD -s 10.0.1.0/24 -j ACCEPT 2>/dev/null
iptables -D FORWARD -d 10.0.1.0/24 -j ACCEPT 2>/dev/null
iptables -D FORWARD -s 10.0.2.0/24 -j ACCEPT 2>/dev/null
iptables -D FORWARD -d 10.0.2.0/24 -j ACCEPT 2>/dev/null
print_ok "iptables rules removed"

sysctl -qw net.bridge.bridge-nf-call-iptables=1 2>/dev/null && print_ok "bridge-nf-call-iptables restored to 1"
sysctl -qw net.bridge.bridge-nf-call-ip6tables=1 2>/dev/null

# ---------------------------------------------------------
print_section "Verifying cleanup"

PROBLEMS=0

check_gone() {
    if eval "$2" &>/dev/null 2>&1; then
        echo -e "  ${RED}[STILL THERE]${NC} $1"
        PROBLEMS=$((PROBLEMS + 1))
    else
        echo -e "  ${GREEN}[GONE]       ${NC} $1"
    fi
}

check_gone "ns1"       "ip netns list | grep -qw ns1"
check_gone "ns2"       "ip netns list | grep -qw ns2"
check_gone "router-ns" "ip netns list | grep -qw router-ns"
check_gone "br0"       "ip link show br0"
check_gone "br1"       "ip link show br1"

echo ""
if [ "$PROBLEMS" -eq 0 ]; then
    echo -e "${GREEN}✔ All components removed successfully.${NC}"
else
    echo -e "${RED}✘ $PROBLEMS component(s) could not be removed.${NC}"
    echo -e "${YELLOW}➜ Try:${NC} sudo ip netns del <name>  or  sudo ip link del <interface>"
fi

print_header "Cleanup done"
echo -e "${BLUE}To rebuild:${NC} sudo ./setup.sh"
echo ""