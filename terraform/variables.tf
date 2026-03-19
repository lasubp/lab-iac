variable "pm_api_url" {
  type        = string
  description = "Proxmox API URL, for example https://pve.example.com:8006/api2/json"
}

variable "pm_api_token_id" {
  type        = string
  description = "Proxmox API token ID"
}

variable "pm_api_token_secret" {
  type        = string
  description = "Proxmox API token secret"
  sensitive   = true
}

variable "pm_tls_insecure" {
  type    = bool
  default = true
}

variable "pm_parallel" {
  type    = number
  default = 2
}

variable "pm_timeout" {
  type    = number
  default = 600
}

variable "target_node" {
  type        = string
  description = "Proxmox node name"
}

variable "ubuntu_template_name" {
  type        = string
  description = "Name of the prepared Ubuntu cloud-init template"
}

variable "opnsense_template_name" {
  type        = string
  description = "Name of the prepared OPNsense template"
}

variable "clone_storage" {
  type        = string
  description = "Target datastore for cloned VM disks"
}

variable "ssh_public_key_file" {
  type        = string
  description = "Path to your SSH public key"
}

variable "vm_username" {
  type    = string
  default = "ubuntu"
}

variable "dns_servers" {
  type    = list(string)
  default = ["1.1.1.1", "8.8.8.8"]
}

variable "searchdomain" {
  type    = string
  default = "lab.local"
}

variable "ubuntu_cores" {
  type    = number
  default = 2
}

variable "ubuntu_memory" {
  type    = number
  default = 2048
}

variable "ubuntu_disk_size" {
  type    = string
  default = "20G"
}

variable "opnsense_cores" {
  type    = number
  default = 2
}

variable "opnsense_memory" {
  type    = number
  default = 4096
}

variable "opnsense_disk_size" {
  type    = string
  default = "32G"
}

variable "wan_bridge" {
  type    = string
  default = "vmbr1"
}

variable "internal_networks" {
  description = "Per-network bridge and addressing"
  type = map(object({
    bridge  = string
    subnet  = string
    gateway = string
    hosts   = list(string)
  }))
  default = {
    net1 = {
      bridge  = "vmbr2"
      subnet  = "10.1.1.0/24"
      gateway = "10.1.1.1"
      hosts   = ["10.1.1.11", "10.1.1.12", "10.1.1.13"]
    }
    net2 = {
      bridge  = "vmbr3"
      subnet  = "10.2.2.0/24"
      gateway = "10.2.2.1"
      hosts   = ["10.2.2.11", "10.2.2.12", "10.2.2.13"]
    }
    net3 = {
      bridge  = "vmbr4"
      subnet  = "10.3.3.0/24"
      gateway = "10.3.3.1"
      hosts   = ["10.3.3.11", "10.3.3.12", "10.3.3.13"]
    }
    net4 = {
      bridge  = "vmbr5"
      subnet  = "10.4.4.0/24"
      gateway = "10.4.4.1"
      hosts   = ["10.4.4.11", "10.4.4.12", "10.4.4.13"]
    }
    net5 = {
      bridge  = "vmbr6"
      subnet  = "10.5.5.0/24"
      gateway = "10.5.5.1"
      hosts   = ["10.5.5.11", "10.5.5.12", "10.5.5.13"]
    }
  }
}
