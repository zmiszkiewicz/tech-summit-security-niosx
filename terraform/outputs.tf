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
