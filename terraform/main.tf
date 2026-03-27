locals {
  ssh_public_key       = trimspace(file(pathexpand(var.ssh_public_key_file)))
  sorted_network_names = sort(keys(var.internal_networks))
  opnsense_network_order = var.opnsense_internal_network_order
  network_index_by_name = {
    for idx, net_name in local.sorted_network_names : net_name => idx
  }

  ubuntu_vms = merge([
    for net_name, net in var.internal_networks : {
      for idx, ip in net.hosts : "${net_name}-vm${idx + 1}" => {
        name    = "${net_name}-vm${idx + 1}"
        bridge  = net.bridge
        ip      = ip
        cidr    = split("/", net.subnet)[1]
        gateway = net.gateway
        vmid    = var.ubuntu_vmid_base + (local.network_index_by_name[net_name] * var.ubuntu_vmid_stride) + idx
      }
    }
  ]...)
}

resource "proxmox_vm_qemu" "opnsense" {
  name        = var.opnsense_vm_name
  target_node = var.target_node
  clone       = var.opnsense_template_name
  full_clone  = true

  vmid    = var.opnsense_vmid
  onboot  = true
  os_type = "other"
  scsihw  = "virtio-scsi-pci"
  boot    = "order=scsi0"
  agent   = 0
  cores   = var.opnsense_cores
  memory  = var.opnsense_memory
  balloon = 0

  disk {
    slot    = 0
    type    = "scsi"
    storage = var.clone_storage
    size    = var.opnsense_disk_size
  }

  network {
    model    = var.opnsense_network_model
    bridge   = var.wan_bridge
    firewall = var.enable_proxmox_firewall
  }

  dynamic "network" {
    for_each = local.opnsense_network_order
    content {
      model    = var.opnsense_network_model
      bridge   = var.internal_networks[network.value].bridge
      firewall = var.enable_proxmox_firewall
    }
  }
}

resource "proxmox_vm_qemu" "ubuntu" {
  for_each    = local.ubuntu_vms
  name        = each.value.name
  target_node = var.target_node
  clone       = var.ubuntu_template_name
  full_clone  = true

  vmid         = each.value.vmid
  onboot       = true
  os_type      = "cloud-init"
  agent        = 1
  qemu_os      = "l26"
  scsihw       = "virtio-scsi-pci"
  boot         = "order=scsi0"
  ciuser       = var.vm_username
  sshkeys      = local.ssh_public_key
  ipconfig0    = "ip=${each.value.ip}/${each.value.cidr},gw=${each.value.gateway}"
  nameserver   = join(" ", var.dns_servers)
  searchdomain = var.searchdomain

  cores   = var.ubuntu_cores
  memory  = var.ubuntu_memory
  balloon = 0

  disk {
    slot    = 0
    type    = "scsi"
    storage = var.clone_storage
    size    = var.ubuntu_disk_size
  }

  network {
    model    = var.ubuntu_network_model
    bridge   = each.value.bridge
    firewall = var.enable_proxmox_firewall
  }
}
