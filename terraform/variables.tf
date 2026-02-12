variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.100.0.0/16"
}

variable "windows_admin_password" {
  description = "Password for the Windows Administrator account"
  type        = string
  sensitive   = true
}

variable "infoblox_join_token" {
  description = "Join token for NIOS-X servers"
  type        = string
  sensitive   = true
}

# --- Azure Variables ---

variable "azure_location" {
  description = "Azure region for the Windows 11 VM"
  type        = string
  default     = "northeurope"
}

variable "azure_vm_size" {
  description = "Azure VM size for the Windows 11 desktop client"
  type        = string
  default     = "Standard_D2s_v3"
}
