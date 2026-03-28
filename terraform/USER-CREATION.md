# Guide to create a Terraform user and API token in Proxmox

The privilege sets below follow the Telmate Proxmox provider guidance. This repo intentionally keeps the local user name as `terraform@pve` and the example token name as `lab` so they match `terraform/terraform.tfvars.example`.

## Role creation

### Create role in PVE 8 and older

```bash
pveum role add TerraformProv -privs "Datastore.Allocate \
  Datastore.AllocateSpace Datastore.AllocateTemplate \
  Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify \
  SDN.Use VM.Allocate VM.Audit VM.Clone VM.Config.CDROM \
  VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType \
  VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate \
  VM.Monitor VM.PowerMgmt User.Modify"
```

### Create role in PVE 9 and newer

In Proxmox 9, the `VM.Monitor` privilege was deprecated and is no longer required.

```bash
pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Pool.Audit Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.PowerMgmt SDN.Use"
```

## Create group

```bash
pveum group add terraform-users
```

## Add permissions

```bash
pveum acl modify /storage -group terraform-users -role TerraformProv
```

```bash
pveum acl modify /vms -group terraform-users -role TerraformProv
```

```bash
pveum acl modify /sdn/zones -group terraform-users -role TerraformProv
```

## Create user `terraform`

```bash
pveum useradd terraform@pve -groups terraform-users
```

## Generate a token

This outputs a token value. Save it and use the same token name in `terraform/terraform.tfvars`.

```bash
pveum user token add terraform@pve lab -privsep 0
```

That matches the example token ID:

```hcl
pm_api_token_id = "terraform@pve!lab"
```

In the UI, `Privilege Separation` must be set to `No`.
