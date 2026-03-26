# Guide to create terraform user an API tocken in terraform

## Role creation

### Create role in PVE 8 and Older

``` bash
pveum role add TerraformUser -privs "Datastore.Allocate \
  Datastore.AllocateSpace Datastore.AllocateTemplate \
  Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify \
  SDN.Use VM.Allocate VM.Audit VM.Clone VM.Config.CDROM \
  VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType \
  VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate \
  VM.Monitor VM.PowerMgmt User.Modify"
```

### Create role in PVE 9 and Neawer

In Proxmox 9, the ```VM.Monitor``` privilege was deprecated and is no longer required.

``` bash
pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Pool.Audit Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.PowerMgmt SDN.Use"
```

## create group

``` bash
pveum group add terraform-users
```

## add permissions

``` bash
pveum acl modify /storage -group terraform-users -role TerraformUser
```

``` bash
pveum acl modify /vms -group terraform-users -role TerraformUser
```

``` bash
pveum acl modify /sdn/zones -group terraform-users -role TerraformUser
```

## create user 'terraform'

``` bash
pveum useradd terraform@pve -groups terraform-users
```

## generate a token

will output a token value similar to the following, save this information as we’ll pass it via environment variables to Terraform at the end.

``` bash
pveum user token add terraform@pve token -privsep 0
```

In UI check ```Privilege Separation```, must be set to ```No```