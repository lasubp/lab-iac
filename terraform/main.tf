locals {
  ssh_public_key = trimspace(file(var.ssh_public_key_file))

  ubuntu_vms = merge([
    for net_name, net in var.internal_networks : {
      for idx, ip in net.hosts : "${net_name}-vm${idx + 1}" => {
        name    = "${net_name}-vm${idx + 1}"
        bridge  = net.bridge
        ip      = ip
        cidr    = split("/", net.subnet)[1]
        gateway = net.gateway
        vmid    = 2100 + (index(keys(var.internal_networks), net_name) * 10) + idx
      }
    }
  ]...)

  sorted_network_names = sort(keys(var.internal_networks))
}

resource "proxmox_vm_qemu" "opnsense" {
  name        = "lab-opnsense"
  target_node = var.target_node
  clone       = var.opnsense_template_name
  full_clone  = true

  vmid        = 2000
  onboot      = true
  os_type     = "other"
  scsihw      = "virtio-scsi-pci"
  boot        = "order=scsi0"
  agent       = 0
  cores       = var.opnsense_cores
  memory      = var.opnsense_memory
  balloon     = 0
  ciupgrade   = false

  disks {
    scsi {
      scsi0 {
        disk {
          storage = var.clone_storage
          size    = var.opnsense_disk_size
        }
      }
    }
  }

  network {
    id       = 0
    model    = "virtio"
    bridge   = var.wan_bridge
    firewall = true
  }

  dynamic "network" {
    for_each = local.sorted_network_names
    content {
      id       = network.key + 1
      model    = "virtio"
      bridge   = var.internal_networks[network.value].bridge
      firewall = true
    }
  }
}

resource "proxmox_vm_qemu" "ubuntu" {
  for_each    = local.ubuntu_vms
  name        = each.value.name
  target_node = var.target_node
  clone       = var.ubuntu_template_name
  full_clone  = true

  vmid        = each.value.vmid
  onboot      = true
  os_type     = "cloud-init"
  agent       = 1
  qemu_os     = "l26"
  scsihw      = "virtio-scsi-pci"
  boot        = "order=scsi0"
  ciupgrade   = true
  ciuser      = var.vm_username
  sshkeys     = local.ssh_public_key
  ipconfig0   = "ip=${each.value.ip}/${each.value.cidr},gw=${each.value.gateway}"
  nameserver  = join(" ", var.dns_servers)
  searchdomain = var.searchdomain

  cores       = var.ubuntu_cores
  memory      = var.ubuntu_memory
  balloon     = 0

  disks {
    scsi {
      scsi0 {
        disk {
          storage = var.clone_storage
          size    = var.ubuntu_disk_size
        }
      }
    }
  }

  network {
    id       = 0
    model    = "virtio"
    bridge   = each.value.bridge
    firewall = true
  }
}
