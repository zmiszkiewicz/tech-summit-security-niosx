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

variable "infoblox_join_token_1" {
  description = "Join token for NIOS-X server #1"
  type        = string
  sensitive   = true
}

variable "infoblox_join_token_2" {
  description = "Join token for NIOS-X server #2"
  type        = string
  sensitive   = true
}
