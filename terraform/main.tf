data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.100.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "Infoblox-Lab" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.100.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = { Name = "public-subnet" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "igw" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# --- Security Groups ---

resource "aws_security_group" "rdp_sg" {
  name        = "allow_rdp"
  description = "Allow RDP, HTTPS, DNS, SSH to client VM"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rdp-sg"
  }
}

resource "aws_security_group" "ubuntu_sg" {
  name        = "allow_ubuntu"
  description = "Allow SSH and ICMP to Ubuntu workstation"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ubuntu-sg"
  }
}

# --- TLS Key Pair ---

resource "tls_private_key" "rdp" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "rdp" {
  key_name   = "instruqt-dc-key"
  public_key = tls_private_key.rdp.public_key_openssh
}

resource "local_sensitive_file" "private_key_pem" {
  filename        = "./instruqt-dc-key.pem"
  content         = tls_private_key.rdp.private_key_pem
  file_permission = "0400"
}

# --- Windows Client VM (10.100.0.110) ---

resource "aws_network_interface" "client_eni" {
  subnet_id       = aws_subnet.public.id
  private_ips     = ["10.100.0.110"]
  security_groups = [aws_security_group.rdp_sg.id]
  tags = { Name = "client-eni" }
}

resource "aws_eip" "client_eip" {
  domain = "vpc"
  tags   = { Name = "client-eip" }
}

resource "aws_eip_association" "client_assoc" {
  network_interface_id = aws_network_interface.client_eni.id
  allocation_id        = aws_eip.client_eip.id
  private_ip_address   = "10.100.0.110"
}

resource "aws_instance" "client_vm" {
  ami           = data.aws_ami.windows.id
  instance_type = "t3.medium"
  key_name      = aws_key_pair.rdp.key_name

  network_interface {
    network_interface_id = aws_network_interface.client_eni.id
    device_index         = 0
  }

  user_data = templatefile("./scripts/winrm-init.ps1.tpl", {
    admin_password = var.windows_admin_password
  })

  tags = { Name = "client-vm" }

  depends_on = [aws_internet_gateway.gw]
}

# --- Ubuntu EC2 Workstation (10.100.0.130) ---

resource "aws_network_interface" "ubuntu_eni" {
  subnet_id       = aws_subnet.public.id
  private_ips     = ["10.100.0.130"]
  security_groups = [aws_security_group.ubuntu_sg.id]
  tags = { Name = "ubuntu-eni" }
}

resource "aws_eip" "ubuntu_eip" {
  domain = "vpc"
  tags   = { Name = "ubuntu-eip" }
}

resource "aws_eip_association" "ubuntu_assoc" {
  network_interface_id = aws_network_interface.ubuntu_eni.id
  allocation_id        = aws_eip.ubuntu_eip.id
  private_ip_address   = "10.100.0.130"
}

resource "aws_instance" "ubuntu_vm" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  key_name      = aws_key_pair.rdp.key_name

  network_interface {
    network_interface_id = aws_network_interface.ubuntu_eni.id
    device_index         = 0
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y net-tools curl dnsutils traceroute iputils-ping

              sudo hostnamectl set-hostname ubuntu-workstation
            EOF

  tags = { Name = "ubuntu-workstation" }

  depends_on = [aws_internet_gateway.gw]
}
