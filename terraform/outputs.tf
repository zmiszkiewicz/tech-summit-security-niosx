# Outputs
output "client_public_ip" {
  description = "Public IP for Windows client VM (RDP access)"
  value       = aws_eip.client_eip.public_ip
}

output "ubuntu_public_ip" {
  description = "Public IP for Ubuntu EC2 workstation"
  value       = aws_eip.ubuntu_eip.public_ip
}

output "ssh_to_ubuntu" {
  description = "SSH command to access the Ubuntu workstation"
  value       = "ssh -i instruqt-dc-key.pem ubuntu@${aws_eip.ubuntu_eip.public_ip}"
}

output "niosx_1_public_ip" {
  description = "Public IP of NIOS-X server #1"
  value       = aws_eip.niosx_1_eip.public_ip
}

output "niosx_2_public_ip" {
  description = "Public IP of NIOS-X server #2"
  value       = aws_eip.niosx_2_eip.public_ip
}

output "gm_public_ip" {
  description = "Public IP of NIOS Grid Master (GM)"
  value       = aws_eip.gm_eip.public_ip
}

output "client_2_public_ip" {
  description = "Public IP for Windows client VM #2 (RDP access)"
  value       = aws_eip.client_2_eip.public_ip
}

output "ubuntu_syslog_public_ip" {
  description = "Public IP for Ubuntu syslog server"
  value       = aws_eip.ubuntu_syslog_eip.public_ip
}

output "ssh_to_ubuntu_syslog" {
  description = "SSH command to access the Ubuntu syslog server"
  value       = "ssh -i instruqt-dc-key.pem ubuntu@${aws_eip.ubuntu_syslog_eip.public_ip}"
}

# --- Azure Outputs ---

output "azure_win11_public_ip" {
  description = "Public IP for Azure Windows 11 desktop client (RDP access)"
  value       = azurerm_public_ip.win11.ip_address
}

output "azure_win11_2_public_ip" {
  description = "Public IP for Azure Windows 11 desktop client #2 (RDP access)"
  value       = azurerm_public_ip.win11_2.ip_address
}
