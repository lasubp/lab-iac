output "opnsense_vm_name" {
  value = proxmox_vm_qemu.opnsense.name
}

output "ubuntu_vm_names" {
  value = sort([for vm in proxmox_vm_qemu.ubuntu : vm.name])
}

output "ubuntu_vm_ips" {
  value = {
    for name, spec in local.ubuntu_vms : name => spec.ip
  }
}

output "network_summary" {
  value = var.internal_networks
}
