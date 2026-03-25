#!/bin/bash
# =============================================================
#  setup.sh — Linux Network Namespace Simulation
#  Run:  sudo ./setup.sh
# =============================================================

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color

# ---------- Helpers ----------
print_header() {
    echo -e "\n${CYAN}=================================================${NC}"
    echo -e "  ${BLUE}$1${NC}"
    echo -e "${CYAN}=================================================${NC}"
}

print_step() {
    echo -e "\n${YELLOW}--- $1 ---${NC}"
}

print_ok() {
    echo -e "${GREEN}✔ $1${NC}"
}

print_info() {
    echo -e "${BLUE}➜ $1${NC}"
}

print_fail() {
    echo -e "${RED}✘ $1${NC}"
}

# ---------- Root Check ----------
if [ "$EUID" -ne 0 ]; then
    print_fail "Please run as root: sudo ./setup.sh"
    exit 1
fi

print_header "Linux Network Namespace Simulation — Setup"

# ---------------------------------------------------------
# STEP 1: Create network bridges (virtual switches)
# ---------------------------------------------------------
print_step "Step 1: Creating bridges"

ip link add name br0 type bridge
ip link set br0 type bridge stp_state 0
ip link set br0 type bridge forward_delay 0
ip link set br0 up
print_ok "br0 created (switch for Network A)"

ip link add name br1 type bridge
ip link set br1 type bridge stp_state 0
ip link set br1 type bridge forward_delay 0
ip link set br1 up
print_ok "br1 created (switch for Network B)"

# ---------------------------------------------------------
# STEP 2: Create network namespaces
# ---------------------------------------------------------
print_step "Step 2: Creating namespaces"

ip netns add ns1
print_ok "ns1 created"

ip netns add ns2
print_ok "ns2 created"

ip netns add router-ns
print_ok "router-ns created"

echo ""
print_info "Namespaces on this machine:"
ip netns list

# ---------------------------------------------------------
# STEP 3: Create veth pairs and connect to bridges
# ---------------------------------------------------------
print_step "Step 3: Creating veth pairs"

# ns1 <--> br0
ip link add veth-ns1 type veth peer name veth-ns1-br
ip link set veth-ns1 netns ns1
ip link set veth-ns1-br master br0
ip link set veth-ns1-br up
print_ok "ns1 connected to br0"

# ns2 <--> br1
ip link add veth-ns2 type veth peer name veth-ns2-br
ip link set veth-ns2 netns ns2
ip link set veth-ns2-br master br1
ip link set veth-ns2-br up
print_ok "ns2 connected to br1"

# router-ns <--> br0
ip link add veth-rtr0 type veth peer name veth-rtr0-br
ip link set veth-rtr0 netns router-ns
ip link set veth-rtr0-br master br0
ip link set veth-rtr0-br up
print_ok "router-ns connected to br0"

# router-ns <--> br1
ip link add veth-rtr1 type veth peer name veth-rtr1-br
ip link set veth-rtr1 netns router-ns
ip link set veth-rtr1-br master br1
ip link set veth-rtr1-br up
print_ok "router-ns connected to br1"

# ---------------------------------------------------------
# STEP 4: Assign IP addresses
# ---------------------------------------------------------
print_step "Step 4: Assigning IP addresses"

ip netns exec ns1       ip link set lo up
ip netns exec ns2       ip link set lo up
ip netns exec router-ns ip link set lo up

ip netns exec ns1       ip link set veth-ns1  up
ip netns exec ns2       ip link set veth-ns2  up
ip netns exec router-ns ip link set veth-rtr0 up
ip netns exec router-ns ip link set veth-rtr1 up

ip netns exec ns1       ip addr add 10.0.1.10/24 dev veth-ns1
ip netns exec ns2       ip addr add 10.0.2.10/24 dev veth-ns2
ip netns exec router-ns ip addr add 10.0.1.1/24  dev veth-rtr0
ip netns exec router-ns ip addr add 10.0.2.1/24  dev veth-rtr1

echo ""
print_info "IP Assignments:"
printf "  %-12s → %s\n" "ns1"       "10.0.1.10/24"
printf "  %-12s → %s\n" "ns2"       "10.0.2.10/24"
printf "  %-12s → %s\n" "router-ns" "10.0.1.1/24 (Network A)"
printf "  %-12s → %s\n" "router-ns" "10.0.2.1/24 (Network B)"

# ---------------------------------------------------------
# STEP 5: Configure routing
# ---------------------------------------------------------
print_step "Step 5: Configuring routing"

ip netns exec router-ns sysctl -qw net.ipv4.ip_forward=1
print_ok "IP forwarding enabled in router-ns"

ip netns exec ns1 ip route add default via 10.0.1.1
print_ok "ns1 default route -> 10.0.1.1"

ip netns exec ns2 ip route add default via 10.0.2.1
print_ok "ns2 default route -> 10.0.2.1"

# ---------------------------------------------------------
# FIREWALL FIX
# ---------------------------------------------------------
print_step "Applying firewall fix"

sysctl -qw net.bridge.bridge-nf-call-iptables=0
sysctl -qw net.bridge.bridge-nf-call-ip6tables=0

iptables -C FORWARD -s 10.0.1.0/24 -j ACCEPT 2>/dev/null || iptables -I FORWARD 1 -s 10.0.1.0/24 -j ACCEPT
iptables -C FORWARD -d 10.0.1.0/24 -j ACCEPT 2>/dev/null || iptables -I FORWARD 1 -d 10.0.1.0/24 -j ACCEPT
iptables -C FORWARD -s 10.0.2.0/24 -j ACCEPT 2>/dev/null || iptables -I FORWARD 1 -s 10.0.2.0/24 -j ACCEPT
iptables -C FORWARD -d 10.0.2.0/24 -j ACCEPT 2>/dev/null || iptables -I FORWARD 1 -d 10.0.2.0/24 -j ACCEPT

print_ok "Firewall configured"

# ---------------------------------------------------------
# STEP 6: Test connectivity
# ---------------------------------------------------------
print_step "Step 6: Testing connectivity"

echo ""
printf "  %-38s %s\n" "Test" "Result"
echo "  -----------------------------------------------"

do_ping() {
    printf "  %-38s" "$1 -> $2"
    if ip netns exec $1 ping -c 2 -W 2 -q $2 > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
    fi
}

do_ping ns1       10.0.1.1
do_ping ns2       10.0.2.1
do_ping ns1       10.0.2.10
do_ping ns2       10.0.1.10
do_ping router-ns 10.0.1.10
do_ping router-ns 10.0.2.10

print_header "Setup complete!"
echo -e "${BLUE}Monitor :${NC} sudo ./monitor.sh"
echo -e "${BLUE}Cleanup :${NC} sudo ./cleanup.sh"
echo ""