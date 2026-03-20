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

Suggested pools:

| Network | Range |
|---|---|
| NET1 | 10.1.1.100 - 10.1.1.199 |
| NET2 | 10.2.2.100 - 10.2.2.199 |
| NET3 | 10.3.3.100 - 10.3.3.199 |
| NET4 | 10.4.4.100 - 10.4.4.199 |
| NET5 | 10.5.5.100 - 10.5.5.199 |

Static IPs from Terraform are already set on the Ubuntu VMs, so DHCP is optional for those guests but helpful for future lab devices.

### 3. NAT

Set outbound NAT to **Automatic**.

### 4. Firewall rules

Because OPNsense processes rules top-down on each interface, add rules in this order.

These rules implement the default topology where NET1 is the shared hub and NET2..NET5 are isolated from each other. If you change the number of networks or their intended reachability, adjust the rule set to match.

#### NET1 rules

1. Pass source `NET1 net` -> destination `any`

#### NET2 rules

1. Pass source `NET2 net` -> destination `NET1 net`
2. Block source `NET2 net` -> destination `NET3 net`
3. Block source `NET2 net` -> destination `NET4 net`
4. Block source `NET2 net` -> destination `NET5 net`
5. Pass source `NET2 net` -> destination `any`

#### NET3 rules

1. Pass source `NET3 net` -> destination `NET1 net`
2. Block source `NET3 net` -> destination `NET2 net`
3. Block source `NET3 net` -> destination `NET4 net`
4. Block source `NET3 net` -> destination `NET5 net`
5. Pass source `NET3 net` -> destination `any`

#### NET4 rules

1. Pass source `NET4 net` -> destination `NET1 net`
2. Block source `NET4 net` -> destination `NET2 net`
3. Block source `NET4 net` -> destination `NET3 net`
4. Block source `NET4 net` -> destination `NET5 net`
5. Pass source `NET4 net` -> destination `any`

#### NET5 rules

1. Pass source `NET5 net` -> destination `NET1 net`
2. Block source `NET5 net` -> destination `NET2 net`
3. Block source `NET5 net` -> destination `NET3 net`
4. Block source `NET5 net` -> destination `NET4 net`
5. Pass source `NET5 net` -> destination `any`

## Validation tests

From `net2-vm1`:

- ping `10.1.1.11` should work
- ping `10.3.3.11` should fail
- ping `1.1.1.1` should work

From `net1-vm1`:

- ping any VM in Net2..Net5 should work

If you need DNS names inside the lab, add the OPNsense Unbound service later. This project keeps DNS simple and uses the external resolvers defined in Terraform.
