# OPNsense setup for this lab

This document finishes the firewall configuration after Terraform deploys the OPNsense VM.

The interface names, bridges, and IP plan below match the default `terraform.tfvars.example`. If you customize `wan_bridge`, `internal_networks`, VM naming, or the number of LANs in Terraform, make the equivalent changes here during OPNsense setup.

## Interfaces used by the clone

| OPNsense NIC | Proxmox bridge | Role |
|---|---|---|
| vtnet0 | vmbr1 | WAN |
| vtnet1 | vmbr2 | NET1 |
| vtnet2 | vmbr3 | NET2 |
| vtnet3 | vmbr4 | NET3 |
| vtnet4 | vmbr5 | NET4 |
| vtnet5 | vmbr6 | NET5 |

If the detected names are `em0`, `em1`, etc., use those instead. The bridge mapping above is what matters.

## Part A - One-time template prep

1. Boot the installer VM created by `scripts/create-opnsense-installer-vm.sh`.
2. Install OPNsense to the disk.
3. Reboot into the installed system.
4. At the console menu, assign interfaces like this:
   - WAN = vtnet0
   - LAN = vtnet1
   - OPT1 = vtnet2
   - OPT2 = vtnet3
   - OPT3 = vtnet4
   - OPT4 = vtnet5
5. Shutdown the VM.
6. Convert it to a template:

```bash
qm template <VMID>
```

That becomes the template used by Terraform.

## Part B - Configure the cloned lab firewall

After `terraform apply`, open the OPNsense clone console and configure the interfaces.

### 1. Assign IP addresses

With the default Terraform variables, use these addresses:

| Interface | Name in UI | IPv4 |
|---|---|---|
| WAN | WAN | DHCP |
| LAN | NET1 | 10.1.1.1/24 |
| OPT1 | NET2 | 10.2.2.1/24 |
| OPT2 | NET3 | 10.3.3.1/24 |
| OPT3 | NET4 | 10.4.4.1/24 |
| OPT4 | NET5 | 10.5.5.1/24 |

Rename interfaces in the GUI so rules are readable.

### 2. Enable DHCP on each internal network

If you use the current OPNsense Kea UI, DHCP is configured in two places:

1. Go to `Services -> Kea DHCPv4 -> Settings`.
2. Enable `Kea DHCPv4`.
3. In `Interfaces`, select `NET1`, `NET2`, `NET3`, `NET4`, and `NET5`.
4. Do not select `WAN`.
5. Save and apply.
6. Go to `Services -> Kea DHCPv4 -> Subnets`.
7. Create one subnet entry for each internal network.

Suggested subnet and pool values:

| Network | Subnet | Range |
|---|---|---|
| NET1 | 10.1.1.0/24 | 10.1.1.100 - 10.1.1.199 |
| NET2 | 10.2.2.0/24 | 10.2.2.100 - 10.2.2.199 |
| NET3 | 10.3.3.0/24 | 10.3.3.100 - 10.3.3.199 |
| NET4 | 10.4.4.0/24 | 10.4.4.100 - 10.4.4.199 |
| NET5 | 10.5.5.0/24 | 10.5.5.100 - 10.5.5.199 |

For each subnet entry:

1. Set the subnet to the matching `/24` network.
2. Add a pool with the matching `.100` to `.199` range.
3. Save the subnet.
4. Apply changes after all subnet entries are added.

If your Kea form does not expose an explicit router or gateway field, OPNsense will still serve the subnet correctly as long as the interface itself already has the matching static IP, such as `10.2.2.1/24` on `NET2`.

Static IPs from Terraform are already set on the Ubuntu VMs, so DHCP is optional for those guests but helpful for future lab devices and for one-off test VMs.

### 3. NAT

Set outbound NAT to **Automatic**.

### 4. Firewall rules

These rules implement the default topology where `NET1` is the shared hub and `NET2`..`NET5` are isolated from each other. If you change the number of networks or their intended reachability, adjust the rule set to match.

The newer OPNsense rules UI allows you to create one rule for multiple interfaces. When you do that, the rule behaves like a floating rule. For this lab, use interface-specific or multi-interface rules with these guardrails:

- set `Direction` to `in`
- do not use `Direction = both`
- put block rules above the final `pass -> any` rules
- do not create inbound allow rules on `WAN`

#### Step 1 - Allow NET1 everywhere

Go to `Firewall -> Rules`.

Create a rule with:

- Action: `Pass`
- Interface: `NET1`
- Direction: `in`
- TCP/IP Version: `IPv4`
- Protocol: `any`
- Source: `NET1 net`
- Destination: `any`
- Description: `NET1 access all networks`

Save and apply.

#### Step 2 - Allow NET2..NET5 to reach NET1

Create one shared rule with:

- Action: `Pass`
- Interface: `NET2`, `NET3`, `NET4`, `NET5`
- Direction: `in`
- TCP/IP Version: `IPv4`
- Protocol: `any`
- Source: `NET2 net`, `NET3 net`, `NET4 net`, `NET5 net`
- Destination: `NET1 net`
- Description: `NET2, NET3, NET4, NET5 pass NET1`

If your UI does not let you select multiple source networks cleanly in one rule, create four separate rules instead:

1. `NET2 net` -> `NET1 net`
2. `NET3 net` -> `NET1 net`
3. `NET4 net` -> `NET1 net`
4. `NET5 net` -> `NET1 net`

Save and apply.

#### Step 3 - Block traffic between spoke networks

Create these rules in this order:

1. On `NET2`: block source `NET2 net` -> destination `NET3 net`, `NET4 net`, `NET5 net`
2. On `NET3`: block source `NET3 net` -> destination `NET2 net`, `NET4 net`, `NET5 net`
3. On `NET4`: block source `NET4 net` -> destination `NET2 net`, `NET3 net`, `NET5 net`
4. On `NET5`: block source `NET5 net` -> destination `NET2 net`, `NET3 net`, `NET4 net`

Use these common values on each rule:

- Action: `Block`
- Direction: `in`
- TCP/IP Version: `IPv4`
- Protocol: `any`

Save and apply.

#### Step 4 - Allow NET2..NET5 to reach anything else

Create one final pass rule on each spoke interface:

1. On `NET2`: pass source `NET2 net` -> destination `any`
2. On `NET3`: pass source `NET3 net` -> destination `any`
3. On `NET4`: pass source `NET4 net` -> destination `any`
4. On `NET5`: pass source `NET5 net` -> destination `any`

Use these common values:

- Action: `Pass`
- Direction: `in`
- TCP/IP Version: `IPv4`
- Protocol: `any`

These rules must be below the spoke-to-spoke block rules.

#### Step 5 - Review the final rule layout

The finished policy should read like this:

1. `NET1` pass `NET1 net` -> `any`
2. `NET2` pass `NET2 net` -> `NET1 net`
3. `NET2` block `NET2 net` -> `NET3 net`, `NET4 net`, `NET5 net`
4. `NET2` pass `NET2 net` -> `any`
5. `NET3` pass `NET3 net` -> `NET1 net`
6. `NET3` block `NET3 net` -> `NET2 net`, `NET4 net`, `NET5 net`
7. `NET3` pass `NET3 net` -> `any`
8. `NET4` pass `NET4 net` -> `NET1 net`
9. `NET4` block `NET4 net` -> `NET2 net`, `NET3 net`, `NET5 net`
10. `NET4` pass `NET4 net` -> `any`
11. `NET5` pass `NET5 net` -> `NET1 net`
12. `NET5` block `NET5 net` -> `NET2 net`, `NET3 net`, `NET4 net`
13. `NET5` pass `NET5 net` -> `any`

## Validation tests

From `net2-vm1`:

- ping `10.1.1.11` should work
- ping `10.3.3.11` should fail
- ping `1.1.1.1` should work

From `net1-vm1`:

- ping any VM in Net2..Net5 should work

If you need DNS names inside the lab, add the OPNsense Unbound service later. This project keeps DNS simple and uses the external resolvers defined in Terraform.
