locals {
  infoblox_ami_id = "ami-08659b5070b66249d"
  join_token      = var.infoblox_join_token
}

# --- NIOS-X Server #1 (10.100.0.200) ---

resource "aws_instance" "niosx_1" {
  ami                         = local.infoblox_ami_id
  instance_type               = "m5.large"
  key_name                    = aws_key_pair.rdp.key_name
  subnet_id                   = aws_subnet.public.id
  private_ip                  = "10.100.0.200"
  vpc_security_group_ids      = [aws_security_group.rdp_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #cloud-config
    host_setup:
      jointoken: "${local.join_token}"
  EOF

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = "niosx-server-1"
  }

  depends_on = [aws_internet_gateway.gw]
}

# --- NIOS-X Server #2 (10.100.1.200) ---

resource "aws_instance" "niosx_2" {
  ami                         = local.infoblox_ami_id
  instance_type               = "m5.large"
  key_name                    = aws_key_pair.rdp.key_name
  subnet_id                   = aws_subnet.public_b.id
  private_ip                  = "10.100.1.200"
  vpc_security_group_ids      = [aws_security_group.rdp_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #cloud-config
    host_setup:
      jointoken: "${local.join_token}"
  EOF

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = "niosx-server-2"
  }

  depends_on = [aws_internet_gateway.gw]
}
