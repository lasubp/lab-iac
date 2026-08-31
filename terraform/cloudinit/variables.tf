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

variable "vm_id_start" {
  description = "Starting VM ID"
  type        = number
  default     = 100
}

variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 1

  validation {
    condition     = var.vm_count > 0 && var.vm_count <= 10
    error_message = "VM count must be between 1 and 10"
  }
}

variable "vm_name_prefix" {
  description = "Prefix for VM names"
  type        = string
  default     = "ubuntu-server"
}

variable "template_name" {
  type        = string
  description = "Name of the prepared VM cloud-init template"
}


variable "clone_storage" {
  type        = string
  description = "Target datastore for cloned VM disks"
}

variable "vm_username" {
  type    = string
  default = "ubuntu"
}

variable "vm_password" {
  type = string
  description = "Password for vm user"
}

variable "ssh_public_key_file" {
  type        = string
  description = "Path to your SSH public key"
}

variable "vm_description" {
  type = string
  description = "Provide decription for the vm"
}

variable "vmid_start" {
  type        = number
  description = "Starting VMID for VM guests"
  default     = 2100
}

variable "vm_cores" {
  type    = number
  default = 2
}

variable "vm_memory" {
  type    = number
  default = 2048
}

variable "vm_ram_baloon" {
  type = number
  description = "Set set balooning devise type for the vm memory"
  default = 0
}

variable "vm_disk_size" {
  type    = string
  default = "20G"
}

variable "enable_proxmox_firewall" {
  type        = bool
  description = "Whether to enable the Proxmox firewall flag on VM NICs"
  default     = false
}

variable "vm_net_bridge" {
  type = string
  description = "VM netvork bridge connect to"
  default = "vmbr0"
}

variable "network_subnet" {
  description = "Network subnet for VMs (e.g., 192.168.1)"
  type        = string
  default     = "192.168.1"
}

variable "vm_ip_start" {
  description = "Starting IP address (last octet)"
  type        = number
  default     = 100
}

variable "gateway_ip" {
  description = "Gateway IP address"
  type        = string
}