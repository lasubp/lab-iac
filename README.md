# Proxmox Lab IaC - 5 isolated networks with OPNsense hub

This project deploys a lab on Proxmox with these design goals:

- `vmbr0` is left alone for existing Proxmox management
- `eno2` is used only for the lab WAN uplink via `vmbr1`
- 5 internal isolated bridges have no physical uplink:
  - `vmbr2` = Net1
  - `vmbr3` = Net2
  - `vmbr4` = Net3
  - `vmbr5` = Net4
  - `vmbr6` = Net5
- one OPNsense VM routes between all networks and to the internet
- Net1 is the hub network and can talk to all other networks
- Net2..Net5 can reach Net1 and the internet, but not each other
- each internal network gets 3 Ubuntu Server cloud-init VMs

## Final topology

```text
Home router / Internet
        |
      eno2
        |
      vmbr1  (WAN only)
        |
    OPNsense VM
   /    |    |    |    \
vmbr2 vmbr3 vmbr4 vmbr5 vmbr6
 Net1  Net2  Net3  Net4  Net5
```

## IP plan

| Network | Bridge | Gateway | VM IPs |
|---|---|---|---|
| Net1 | vmbr2 | 10.1.1.1/24 | 10.1.1.11-13 |
| Net2 | vmbr3 | 10.2.2.1/24 | 10.2.2.11-13 |
| Net3 | vmbr4 | 10.3.3.1/24 | 10.3.3.11-13 |
| Net4 | vmbr5 | 10.4.4.1/24 | 10.4.4.11-13 |
| Net5 | vmbr6 | 10.5.5.1/24 | 10.5.5.11-13 |

## What Terraform does

Terraform in this repo:

- clones one Ubuntu cloud-init template 15 times
- clones one OPNsense template once
- attaches each VM to the correct bridge
- sets static IPs, gateway, SSH key, DNS, and metadata for Ubuntu VMs
- wires OPNsense to one WAN bridge and five isolated LAN bridges

## What Terraform does not do

To keep this reliable on real Proxmox installs, the project expects two templates to exist before `terraform apply`:

- one Ubuntu cloud-init template
- one OPNsense template

Those prep steps are scripted and documented here because this is the most repeatable Proxmox workflow when deploying many identical guests from a base image.

---

## Directory layout

```text
lab-iac-new/
  README.md
  host/
    proxmox-network-interfaces.example
  scripts/
    create-ubuntu-template.sh
    create-opnsense-installer-vm.sh
  opnsense/
    README.md
  terraform/
    main.tf
    variables.tf
    providers.tf
    versions.tf
    outputs.tf
    terraform.tfvars.example
```

---

## 1) Configure Proxmox host networking

Review `host/proxmox-network-interfaces.example` and mirror the relevant part in Proxmox.

Important rules:

- leave `vmbr0` untouched
- put `eno2` only on `vmbr1`
- `vmbr2`..`vmbr6` must have **no** physical ports
- none of `vmbr1`..`vmbr6` should have an IP address on the Proxmox host

After updating networking, reload networking or reboot in a maintenance window.

---

## 2) Create the Ubuntu cloud-init template

Run `scripts/create-ubuntu-template.sh` on the Proxmox host.

Example:

```bash
bash scripts/create-ubuntu-template.sh \
  --vmid 9000 \
  --name ubuntu-2404-cloudinit-template \
  --node pve \
  --storage local-lvm \
  --snippet-store local
```

This script downloads the official Ubuntu cloud image, imports it into Proxmox, adds a cloud-init drive, enables serial console, installs qemu-guest-agent on first boot if you extend the template later, and converts the VM into a template.

---

## 3) Create the OPNsense template

Run `scripts/create-opnsense-installer-vm.sh` on the Proxmox host.

Example:

```bash
bash scripts/create-opnsense-installer-vm.sh \
  --vmid 9001 \
  --name opnsense-template \
  --node pve \
  --storage local-lvm \
  --iso-store local
```

Then follow `opnsense/README.md` once to:

- boot the installer VM
- install OPNsense to disk
- reboot and do the first console setup
- shutdown and convert it to a template

---

## 4) Fill in Terraform variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit:

- Proxmox API endpoint
- node name
- datastore names
- template names/IDs if you changed them
- WAN bridge if you use a different one
- SSH public key path
- VM sizing if needed

---

## 5) Apply

```bash
terraform init
terraform plan
terraform apply
```

Terraform will create:

- `lab-opnsense`
- `net1-vm1..vm3`
- `net2-vm1..vm3`
- `net3-vm1..vm3`
- `net4-vm1..vm3`
- `net5-vm1..vm3`

---

## 6) Finish OPNsense configuration

After the OPNsense clone first boots, follow `opnsense/README.md` to configure:

- interface assignment
- LAN IPs
- DHCP scopes
- automatic outbound NAT
- firewall rules

This is the one manual step that remains, because the firewall itself needs its own internal configuration after deployment.

---

## 7) Resulting traffic policy

- Net1 <-> Net2/3/4/5: allowed
- Net2 -> Net1: allowed
- Net3 -> Net1: allowed
- Net4 -> Net1: allowed
- Net5 -> Net1: allowed
- Net2 <-> Net3/4/5: blocked
- Net3 <-> Net4/5: blocked
- Net4 <-> Net5: blocked
- all networks -> internet: allowed

---

## Safety notes

- Never attach lab Ubuntu VMs to `vmbr1` directly. `vmbr1` is WAN only.
- Do not assign any host IP to `vmbr1`..`vmbr6`.
- Use subnets that do not overlap your home LAN.
- Test OPNsense with one VM in Net1 and one in Net2 before scaling or changing rules.

---

## Customization points

You can change, in `terraform.tfvars`:

- number of networks
- number of VMs per network
- bridge names
- subnets and gateways
- VM sizes
- DNS servers
- OPNsense VM resources
- Ubuntu template or OPNsense template names

---

## Recommended workflow

1. Configure Proxmox bridges once
2. Create the two templates once
3. Keep all future lab changes inside Terraform variables
4. Keep firewall policy changes documented in `opnsense/README.md`

