locals {
  niosx_ami_id = "ami-08659b5070b66249d"
}

# --- NIOS-X Server #1 (10.100.0.200) ---

resource "aws_network_interface" "niosx_1_eni" {
  subnet_id       = aws_subnet.public.id
  private_ips     = ["10.100.0.200"]
  security_groups = [aws_security_group.rdp_sg.id]

  tags = {
    Name = "niosx-1-eni"
  }
}

resource "aws_eip" "niosx_1_eip" {
  domain = "vpc"
  tags = {
    Name = "niosx-1-eip"
  }
}

resource "aws_eip_association" "niosx_1_assoc" {
  network_interface_id = aws_network_interface.niosx_1_eni.id
  allocation_id        = aws_eip.niosx_1_eip.id
  private_ip_address   = "10.100.0.200"
}

resource "aws_instance" "niosx_1" {
  ami           = local.niosx_ami_id
  instance_type = "m5.2xlarge"
  key_name      = aws_key_pair.rdp.key_name

  network_interface {
    network_interface_id = aws_network_interface.niosx_1_eni.id
    device_index         = 0
  }

  user_data = templatefile("./scripts/cloud-init.yaml", {
    join_token = var.infoblox_join_token_1
  })

  tags = {
    Name = "niosx-server-1"
  }

  depends_on = [aws_internet_gateway.gw]
}

# --- NIOS-X Server #2 (10.100.0.201) ---

resource "aws_network_interface" "niosx_2_eni" {
  subnet_id       = aws_subnet.public.id
  private_ips     = ["10.100.0.201"]
  security_groups = [aws_security_group.rdp_sg.id]

  tags = {
    Name = "niosx-2-eni"
  }
}

resource "aws_eip" "niosx_2_eip" {
  domain = "vpc"
  tags = {
    Name = "niosx-2-eip"
  }
}

resource "aws_eip_association" "niosx_2_assoc" {
  network_interface_id = aws_network_interface.niosx_2_eni.id
  allocation_id        = aws_eip.niosx_2_eip.id
  private_ip_address   = "10.100.0.201"
}

resource "aws_instance" "niosx_2" {
  ami           = local.niosx_ami_id
  instance_type = "m5.2xlarge"
  key_name      = aws_key_pair.rdp.key_name

  network_interface {
    network_interface_id = aws_network_interface.niosx_2_eni.id
    device_index         = 0
  }

  user_data = templatefile("./scripts/cloud-init.yaml", {
    join_token = var.infoblox_join_token_2
  })

  tags = {
    Name = "niosx-server-2"
  }

  depends_on = [aws_internet_gateway.gw]
}
