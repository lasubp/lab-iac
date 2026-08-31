resource "proxmox_vm_qemu" "ubuntu" {
  count = var.vm_count

  name        = "${var.vm_name_prefix}-${count.index + 1}"
  target_node = var.target_node
  clone       = var.template_name
  full_clone  = true

  vmid               = var.vm_id_start + count.index  # VM IDs: 100, 101, 102, etc.
  start_at_node_boot = false
  vm_state           = "running"
  os_type            = "cloud-init"
  agent              = 1
  scsihw             = "virtio-scsi-pci"
  boot               = "order=scsi0"

  description = var.vm_description

  # Cloudinit
  ciuser             = var.vm_username
  cipassword         = var.vm_password
  sshkeys            = trimspace(file(pathexpand(var.ssh_public_key_file)))
  ipconfig0          = "ip=${var.network_subnet}.${var.vm_ip_start + count.index}/24,gw=${var.gateway_ip}"

  memory  = var.vm_memory
  balloon = var.vm_ram_baloon

  cpu {
    cores = var.vm_cores
  }

  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = var.clone_storage
    size    = var.vm_disk_size
  }

  network {
    id       = 0
    model    = "virtio"
    bridge   = var.vm_net_bridge
    firewall = var.enable_proxmox_firewall
  }

    serial {
    id = 0
  }
}

