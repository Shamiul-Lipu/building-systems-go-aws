#!/bin/bash
# =============================================================
#  monitor.sh — Linux Network Namespace Simulation — Monitor
#  Run:  sudo ./monitor.sh
#  Safe to run at any time — does not change anything.
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

print_info() {
    echo -e "${BLUE}➜ $1${NC}"
}

print_ok() {
    echo -e "${GREEN}✔ $1${NC}"
}

print_fail() {
    echo -e "${RED}✘ $1${NC}"
}

# ---------- Root Check ----------
if [ "$EUID" -ne 0 ]; then
    print_fail "Please run as root: sudo ./monitor.sh"
    exit 1
fi

print_header "Network Namespace Lab — Monitor"
echo -e "  ${CYAN}$(date)${NC}"

# ---------------------------------------------------------
print_section "Namespaces"
ip netns list 2>/dev/null || echo -e "  ${RED}(none found)${NC}"

# ---------------------------------------------------------
print_section "Bridges"
for BR in br0 br1; do
    if ip link show $BR &>/dev/null; then
        STATE=$(ip link show $BR | grep -oP 'state \K\w+')
        STP=$(cat /sys/class/net/$BR/bridge/stp_state 2>/dev/null || echo "?")
        printf "  %-6s state=%-8s stp=%s\n" "$BR" "$STATE" "$STP"
    else
        echo -e "  $BR  ${RED}NOT FOUND${NC}"
    fi
done

# ---------------------------------------------------------
print_section "Bridge ports"
bridge link show 2>/dev/null | sed 's/^/  /' || echo -e "  ${RED}(no ports found)${NC}"

# ---------------------------------------------------------
print_section "IP addresses"

for NS in ns1 ns2 router-ns; do
    echo -e "  ${CYAN}[$NS]${NC}"
    ip netns exec $NS ip addr show 2>/dev/null \
        | grep -E "inet |state" \
        | grep -v "127.0.0.1" \
        | sed 's/^/    /' \
        || echo -e "    ${RED}(namespace not found)${NC}"
done

# ---------------------------------------------------------
print_section "Routing tables"

for NS in ns1 ns2 router-ns; do
    echo -e "  ${CYAN}[$NS]${NC}"
    ip netns exec $NS ip route show 2>/dev/null \
        | sed 's/^/    /' \
        || echo -e "    ${RED}(namespace not found)${NC}"
done

# ---------------------------------------------------------
print_section "IP forwarding (router-ns)"
ip netns exec router-ns sysctl net.ipv4.ip_forward 2>/dev/null \
    | sed 's/^/  /' \
    || echo -e "  ${RED}(namespace not found)${NC}"

# ---------------------------------------------------------
print_section "Connectivity tests"
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

# ---------------------------------------------------------
print_section "Manual test commands"

echo -e "  ${BLUE}➜ ns1 → ns2 ping:${NC}"
echo "    sudo ip netns exec ns1 ping 10.0.2.10"

echo -e "  ${BLUE}➜ ns2 → ns1 ping:${NC}"
echo "    sudo ip netns exec ns2 ping 10.0.1.10"

echo -e "  ${BLUE}➜ traceroute:${NC}"
echo "    sudo ip netns exec ns1 traceroute 10.0.2.10"

echo -e "  ${BLUE}➜ router routes:${NC}"
echo "    sudo ip netns exec router-ns ip route show"

echo ""
echo -e "  ${YELLOW}Cleanup when finished:${NC}"
echo "    sudo ./cleanup.sh"

print_header "Done"
echo ""