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

output "dns_servers" {
  value = var.dns_servers
}

output "searchdomain" {
  value = var.searchdomain
}

output "hub_network_name" {
  value = var.hub_network_name
}

output "opnsense_internal_network_order" {
  value = var.opnsense_internal_network_order
}
