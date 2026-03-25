# Linux Network Namespace Simulation

## Overview

This project creates a network simulation using Linux network namespaces. Two separate networks are connected through a router - all running inside a single Linux machine.

The three scripts handle the full lifecycle:

| Script       | Purpose                                    |
| ------------ | ------------------------------------------ |
| `setup.sh`   | Builds the entire topology and tests it    |
| `monitor.sh` | Shows the live state of the lab            |
| `cleanup.sh` | Removes everything and restores the system |

## File Structure

```
.
├── setup.sh      # Builds the full topology (run first)
├── monitor.sh    # Shows live status of the lab
├── cleanup.sh    # Removes all components
└── README.md     # This file
```

---

## How to Run

```bash
# Clone the repository
git clone https://github.com/Shamiul-Lipu/building-systems-go-aws

# Navigate into the project directory
cd linux-Network-Namespace-Simulation

# Make scripts executable
chmod +x setup.sh monitor.sh cleanup.sh

# Build the lab
sudo ./setup.sh

# Monitor the lab (run anytime)
sudo ./monitor.sh

# Remove everything when done
sudo ./cleanup.sh
```

---

## Network Topology

```
                    HOST MACHINE
  ┌──────────────────────────────────────────────────────┐
  │                                                      │
  │   ┌──────────────┐              ┌──────────────┐     │
  │   │     ns1      │              │     ns2      │     │
  │   │ 10.0.1.10/24 │              │ 10.0.2.10/24 │     │
  │   └──────┬───────┘              └──────┬───────┘     │
  │          │ veth-ns1                    │ veth-ns2    │
  │          │ veth-ns1-br                 │ veth-ns2-br │
  │   ┌──────┴───────┐              ┌──────┴───────┐     │
  │   │     br0      │              │     br1      │     │
  │   │  (Network A) │              │  (Network B) │     │
  │   └──────┬───────┘              └──────┬───────┘     │
  │          │ veth-rtr0-br                │ veth-rtr1-br│
  │          │ veth-rtr0                   │ veth-rtr1   │
  │          └──────────┐  ┌──────────────┘              │
  │                 ┌───┴──┴───┐                         │
  │                 │ router-ns│                         │
  │                 │10.0.1.1  │                         │
  │                 │10.0.2.1  │                         │
  │                 │ip_fwd=1  │                         │
  │                 └──────────┘                         │
  └──────────────────────────────────────────────────────┘
```

**Packet path (ns1 → ns2):**

```
ns1 → veth-ns1 → br0 → veth-rtr0 → router-ns → veth-rtr1 → br1 → veth-ns2 → ns2
```

---

## Components

### Network Bridges

| Bridge | Network     | Role                         |
| ------ | ----------- | ---------------------------- |
| `br0`  | 10.0.1.0/24 | Virtual switch for Network A |
| `br1`  | 10.0.2.0/24 | Virtual switch for Network B |

A Linux bridge works like a physical network switch - it connects multiple interfaces and forwards traffic between them at Layer 2.

### Network Namespaces

| Namespace   | Role                        | Connected To |
| ----------- | --------------------------- | ------------ |
| `ns1`       | Simulated host on Network A | br0          |
| `ns2`       | Simulated host on Network B | br1          |
| `router-ns` | Router between networks     | br0 and br1  |

Each namespace is a fully isolated copy of the Linux network stack - its own interfaces, routing table, and firewall rules.

### Virtual Ethernet Pairs (veth)

A veth pair is a virtual cable with two ends. Packets go in one end and come out the other.

| Namespace end | Bridge end     | Connects        |
| ------------- | -------------- | --------------- |
| `veth-ns1`    | `veth-ns1-br`  | ns1 ↔ br0       |
| `veth-ns2`    | `veth-ns2-br`  | ns2 ↔ br1       |
| `veth-rtr0`   | `veth-rtr0-br` | router-ns ↔ br0 |
| `veth-rtr1`   | `veth-rtr1-br` | router-ns ↔ br1 |

---

## IP Addressing Scheme

| Device    | Interface | IP Address | Subnet      | Role                    |
| --------- | --------- | ---------- | ----------- | ----------------------- |
| ns1       | veth-ns1  | 10.0.1.10  | 10.0.1.0/24 | Host on Network A       |
| ns2       | veth-ns2  | 10.0.2.10  | 10.0.2.0/24 | Host on Network B       |
| router-ns | veth-rtr0 | 10.0.1.1   | 10.0.1.0/24 | Gateway for Network A   |
| router-ns | veth-rtr1 | 10.0.2.1   | 10.0.2.0/24 | Gateway for Network B   |
| br0       | —         | none       | 10.0.1.0/24 | L2 switch, no IP needed |
| br1       | —         | none       | 10.0.2.0/24 | L2 switch, no IP needed |

**Subnets:**

- Network A: `10.0.1.0/24` — hosts use `10.0.1.1` to `10.0.1.254`
- Network B: `10.0.2.0/24` — hosts use `10.0.2.1` to `10.0.2.254`

---

## Routing Configuration

### How routing works in this topology

`ns1` and `ns2` are on different networks and cannot talk directly. All traffic between them must go through `router-ns`, which has one interface on each network.

### Routing table — ns1

```
default via 10.0.1.1 dev veth-ns1
10.0.1.0/24 dev veth-ns1 proto kernel src 10.0.1.10
```

ns1 sends all traffic it does not know how to deliver to its gateway `10.0.1.1` (the router).

### Routing table — ns2

```
default via 10.0.2.1 dev veth-ns2
10.0.2.0/24 dev veth-ns2 proto kernel src 10.0.2.10
```

ns2 sends all unknown traffic to its gateway `10.0.2.1` (the router).

### Routing table — router-ns

```
10.0.1.0/24 dev veth-rtr0 proto kernel src 10.0.1.1
10.0.2.0/24 dev veth-rtr1 proto kernel src 10.0.2.1
```

The router knows both networks directly - no static routes needed. When IP forwarding is enabled (`net.ipv4.ip_forward=1`), the kernel forwards packets between the two interfaces automatically.

### IP forwarding

By default Linux does not forward packets between interfaces. We enable it inside `router-ns`:

```bash
ip netns exec router-ns sysctl -w net.ipv4.ip_forward=1
```

This only affects `router-ns` - namespaces have independent sysctl values.

---

## Testing Procedures and Results

### Automated tests (run by setup.sh)

The setup script runs 6 ping tests at the end of setup:

```
Test                                   Result
-----------------------------------------------
ns1 -> 10.0.1.1 (gateway)             PASS
ns2 -> 10.0.2.1 (gateway)             PASS
ns1 -> 10.0.2.10 (cross-network)      PASS
ns2 -> 10.0.1.10 (cross-network)      PASS
router-ns -> 10.0.1.10                PASS
router-ns -> 10.0.2.10                PASS
```

### Manual tests

**Cross-network ping (main objective):**

```bash
# From ns1 to ns2
sudo ip netns exec ns1 ping 10.0.2.10

# Expected output:
# PING 10.0.2.10: 56 data bytes
# 64 bytes from 10.0.2.10: ttl=63 time=0.1 ms
# 64 bytes from 10.0.2.10: ttl=63 time=0.1 ms
```

**Note on TTL=63:** The TTL starts at 64. Each router that forwards the packet decrements it by 1. A TTL of 63 proves the packet crossed `router-ns` - confirming real Layer 3 routing is working.

**Traceroute — shows the path:**

```bash
sudo ip netns exec ns1 traceroute 10.0.2.10

# Expected output:
# 1  10.0.1.1  (router-ns)
# 2  10.0.2.10 (ns2)
```

**Verify routing tables:**

```bash
sudo ip netns exec ns1       ip route show
sudo ip netns exec ns2       ip route show
sudo ip netns exec router-ns ip route show
```

**Verify IP forwarding:**

```bash
sudo ip netns exec router-ns sysctl net.ipv4.ip_forward
# net.ipv4.ip_forward = 1
```

**Inspect bridge ports:**

```bash
sudo bridge link show
```

**Check ARP tables (shows Layer 2 resolution working):**

```bash
sudo ip netns exec ns1 ip neigh show
```

---

## Known Issue — Docker / Netbird VPN Environments

On machines running Docker or Netbird VPN, all tests will fail even when the configuration is correct.

**Why:** Both tools set `net.bridge.bridge-nf-call-iptables=1`, which routes all bridge traffic through the host firewall. Their firewall chains end with a DROP rule that blocks our packets.

**How you can tell:** ARP resolves (Layer 2 works) but ping fails (Layer 3 is blocked).

**The fix** (included in `setup.sh` Step 5):

```bash
# Disconnect bridge from host firewall
sysctl -w net.bridge.bridge-nf-call-iptables=0

# Add explicit ALLOW rules for our subnets
iptables -I FORWARD 1 -s 10.0.1.0/24 -j ACCEPT
iptables -I FORWARD 1 -d 10.0.1.0/24 -j ACCEPT
iptables -I FORWARD 1 -s 10.0.2.0/24 -j ACCEPT
iptables -I FORWARD 1 -d 10.0.2.0/24 -j ACCEPT
```

`cleanup.sh` reverses all of this and restores the original settings.

---

## Requirements

- Linux system with root access
- `iproute2` package (`ip`, `bridge` commands)
- `iptables`
- `ping` / `traceroute` (for testing)

```bash
# Ubuntu / Debian
sudo apt install iproute2 iputils-ping traceroute

# RHEL / Fedora
sudo dnf install iproute iputils traceroute
```
