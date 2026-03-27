terraform {
  required_version = ">= 1.9.0"

  required_providers {
    proxmox = {
      source  = "Terraform-for-Proxmox/proxmox"
      version = "= 0.0.1"
    }
  }
}
