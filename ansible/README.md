# Terraform + Ansible OPNsense flow

This repo now supports a practical two-step workflow:

1. Terraform creates the Proxmox topology and all VMs.
2. Ansible configures OPNsense through the official OPNsense API.

Prerequisites on the machine running the playbook:

- `ansible-playbook`
- Terraform outputs exported from Terraform 1.9 or newer
- HTTPS connectivity to the OPNsense API endpoint

The Terraform side of this workflow now uses the pinned `Telmate/proxmox` provider, but the exported output shape consumed by Ansible stays the same.

The Ansible playbook configures:

- Kea DHCPv4 general settings
- one Kea subnet and pool per Terraform network
- the default lab firewall policy where `NET1` is the hub and `NET2`..`NET5` are isolated from each other
- optional pruning of old `lab-iac`-managed Kea subnets and firewall rules that no longer match the Terraform-driven desired state

It assumes:

- the OPNsense VM already exists from Terraform
- the OPNsense template has already been installed and bootstrapped once
- interface assignment already matches the template prep documented in `opnsense/README.md`
- outbound NAT is still left on the OPNsense default automatic mode

## 1. Create an OPNsense API key

In the OPNsense web UI:

1. Go to `System -> Access -> Users`.
2. Edit the user you want to automate with.
3. Create an API key and secret for that user.
4. Save the key and secret somewhere safe.

## 2. Export Terraform outputs for Ansible

After `terraform apply`:

```bash
bash scripts/export-terraform-outputs.sh
```

This writes `ansible/generated/terraform-output.json`.

## 3. Create the Ansible vars file

```bash
cp ansible/vars/opnsense.yml.example ansible/vars/opnsense.yml
```

Edit:

- `opnsense_api_url`
- `opnsense_api_key`
- `opnsense_api_secret`
- optional `opnsense_prune_managed_resources` toggle if you want to disable cleanup behavior
- optional `opnsense_interface_map` override if your template interface order is not the default Terraform order

If your interface assignment differs from the default template prep, also set `opnsense_interface_map`.

Default mapping:

- first entry in `opnsense_internal_network_order` -> `lan`
- second -> `opt1`
- third -> `opt2`
- fourth -> `opt3`
- fifth -> `opt4`

## 4. Run the playbook

```bash
ansible-playbook -i localhost, ansible/playbooks/configure_opnsense.yml
```

The playbook runs locally and talks to OPNsense over HTTPS with the API key.

## Notes

- The firewall apply uses OPNsense savepoints so failed rule changes can roll back automatically.
- Managed descriptions are prefixed with `lab-iac` by default and use `subnet` or `rule` markers to scope pruning more tightly.
- Pruning happens after current Kea subnets have been upserted successfully, so DHCP updates are no longer destructive-first.
- Pruning only touches Kea subnets matching `"<prefix> subnet ..."` and firewall rules matching `"<prefix> rule ..."`.
- The playbook does not currently manage WAN settings or interface IP assignment. Those still come from your initial OPNsense install/template prep.
