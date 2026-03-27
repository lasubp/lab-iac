# Proxmox Lab IaC - customizable isolated networks with an OPNsense hub

This project deploys a Proxmox lab with Terraform-managed VM topology and Ansible-managed OPNsense policy.

Prerequisites on the machine driving the workflow:

- `terraform` 1.9 or newer
- `ansible-playbook`
- network access to the Proxmox API and the OPNsense API endpoint

Default design goals:

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

Most lab settings are exposed in `terraform/variables.tf` and `terraform.tfvars`, so you can change VM names, VMIDs, bridges, network definitions, NIC models, firewall flags, sizing, and addressing without editing the module source.

This repo currently supports up to 5 internal networks because the default OPNsense template wiring maps them to `LAN` plus `OPT1..OPT4`.

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

- clones one Ubuntu cloud-init template for every host listed in `internal_networks`
- clones one OPNsense template once
- attaches each VM to the correct bridge
- sets static IPs, gateway, SSH key, DNS, and metadata for Ubuntu VMs
- wires OPNsense to one WAN bridge and every LAN bridge defined in `internal_networks`

## What Ansible does

Ansible in this repo:

- reads the exported Terraform outputs
- configures Kea DHCPv4 on OPNsense
- creates one DHCP subnet and pool per internal network
- creates the default lab firewall policy through the OPNsense API
- applies firewall changes using OPNsense savepoints for rollback safety

## What Terraform does not do

To keep this reliable on real Proxmox installs, the project expects two templates to exist before `terraform apply`:

- one Ubuntu cloud-init template
- one OPNsense template

Those prep steps are scripted and documented here because this is the most repeatable Proxmox workflow when deploying many identical guests from a base image.

Terraform still does not log into OPNsense and configure it internally. That is handled by the Ansible step after `terraform apply`.

---

## Directory layout

```text
lab-iac/
  README.md
  host/
    proxmox-network-interfaces.example
  scripts/
    create-ubuntu-template.sh
    create-opnsense-installer-vm.sh
  opnsense/
    README.md
  ansible/
    README.md
    playbooks/
      configure_opnsense.yml
    tasks/
      delete_firewall_rule.yml
      delete_kea_subnet.yml
      manage_firewall_rule.yml
      manage_kea_subnet.yml
    templates/
      opnsense_desired_state.yml.j2
    vars/
      opnsense.yml.example
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
  --bridge vmbr0 \
  --ssh-public-key-file /root/.ssh/id_ed25519.pub
```

This script downloads the Ubuntu cloud image, imports it into Proxmox, adds a cloud-init drive, enables serial console, optionally injects an SSH public key, and converts the VM into a template.

If the VMID already exists, the script exits safely unless you pass `--force-recreate`.

Useful overrides:

- `--image-url` and `--image-file` to control the source image and cache path
- `--memory`, `--cores`, and `--bridge` to shape the template hardware
- `--ssh-public-key-file` to inject a specific key into the template metadata
- `--cloud-init-user-snippet` plus `--snippet-store` if you want to attach a custom cloud-init user-data snippet
- `--force-recreate` if you intentionally want to replace an existing VM with the same VMID

---

## 3) Create the OPNsense template

Run `scripts/create-opnsense-installer-vm.sh` on the Proxmox host.

Before running it, upload the OPNsense installer ISO to your Proxmox ISO storage.

Example:

```bash
bash scripts/create-opnsense-installer-vm.sh \
  --vmid 9001 \
  --name opnsense-template \
  --node pve \
  --storage local-lvm \
  --iso-store local \
  --iso-file OPNsense-installer.iso \
  --wan-bridge vmbr1 \
  --lan-bridges vmbr2,vmbr3,vmbr4,vmbr5,vmbr6
```

Useful overrides:

- `--memory`, `--cores`, `--disk-size`, `--bios`, and `--network-model`
- `--wan-bridge` and `--lan-bridges` to match your bridge layout, up to 5 internal networks
- `--iso-store` and `--iso-file` to point at the uploaded installer image
- `--force-recreate` if you intentionally want to replace an existing VM with the same VMID

Then follow `opnsense/README.md` once to:

- boot the installer VM
- install OPNsense to disk
- reboot and do the first console setup
- switch boot order to disk-only or remove the installer ISO
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
- deployed VM name and VMID ranges
- WAN bridge if you use a different one
- SSH public key path
- NIC models and firewall flags
- full `internal_networks` map if you want a different number of networks or guests
- `hub_network_name` to pick the shared hub network explicitly
- `opnsense_internal_network_order` to control which network maps to `LAN`, `OPT1`, `OPT2`, `OPT3`, and `OPT4`
- VM sizing if needed

---

## 5) Apply

```bash
terraform init
terraform plan
terraform apply
```

With the default variables, Terraform will create:

- `lab-opnsense`
- `net1-vm1..vm3`
- `net2-vm1..vm3`
- `net3-vm1..vm3`
- `net4-vm1..vm3`
- `net5-vm1..vm3`

---

## 6) Bootstrap OPNsense once

Before automation can take over, follow `opnsense/README.md` once to verify:

- interface assignment
- LAN IPs
- automatic outbound NAT

The Ansible step below assumes the OPNsense template already has the correct interface layout and static LAN IPs.

---

## 7) Export Terraform outputs for Ansible

```bash
bash scripts/export-terraform-outputs.sh
```

This writes `ansible/generated/terraform-output.json`.

---

## 8) Configure OPNsense with Ansible

Create the Ansible vars file:

```bash
cp ansible/vars/opnsense.yml.example ansible/vars/opnsense.yml
```

Edit:

- OPNsense API URL
- OPNsense API key and secret
- optional pruning behavior toggle
- optional interface mapping override if you changed the default LAN/OPT assignment

Then run:

```bash
ansible-playbook -i localhost, ansible/playbooks/configure_opnsense.yml
```

For the detailed flow and prerequisites, see `ansible/README.md`.

---

## 9) Resulting traffic policy

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

- OPNsense VM name and VMID
- Ubuntu VMID base/stride
- number of networks
- current OPNsense layout support: up to 5
- hub network name
- OPNsense internal network order
- number of VMs per network
- bridge names
- subnets and gateways
- network interface models
- Proxmox firewall NIC flag
- VM sizes
- DNS servers
- OPNsense VM resources
- Ubuntu template or OPNsense template names

---

## Recommended workflow

1. Configure Proxmox bridges once
2. Create the two templates once
3. Keep topology changes in Terraform variables
4. Keep OPNsense automation settings in `ansible/vars/opnsense.yml`
5. Keep the intended firewall and DHCP layout documented in `opnsense/README.md`
