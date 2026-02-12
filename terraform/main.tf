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

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.100.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]
  tags = { Name = "public-subnet-b" }
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

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
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

  depends_on = [aws_instance.client_vm]
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

  depends_on = [aws_instance.ubuntu_vm]
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

# ===========================================================
# NIOS Grid Master (GM) - Traditional NIOS appliance
# ===========================================================

locals {
  gm_ami_id = "ami-008772a29d4c2f558"
}

# --- GM Management Network Interface (10.100.0.10) ---
resource "aws_network_interface" "gm_mgmt" {
  subnet_id       = aws_subnet.public.id
  private_ips     = ["10.100.0.10"]
  security_groups = [aws_security_group.rdp_sg.id]
  tags = { Name = "gm-mgmt-nic" }
}

# --- GM LAN1 Network Interface (10.100.0.11) - must be same AZ as MGMT ---
resource "aws_network_interface" "gm_lan1" {
  subnet_id       = aws_subnet.public.id
  private_ips     = ["10.100.0.11"]
  security_groups = [aws_security_group.rdp_sg.id]
  tags = { Name = "gm-lan1-nic" }
}

# --- GM EC2 Instance ---
resource "aws_instance" "gm" {
  ami           = local.gm_ami_id
  instance_type = "m5.2xlarge"
  key_name      = aws_key_pair.rdp.key_name

  network_interface {
    network_interface_id = aws_network_interface.gm_mgmt.id
    device_index         = 0
  }
  network_interface {
    network_interface_id = aws_network_interface.gm_lan1.id
    device_index         = 1
  }

  user_data = <<-EOF
#infoblox-config
temp_license: nios IB-V825 enterprise dns dhcp cloud
remote_console_enabled: y
default_admin_password: "${var.windows_admin_password}"
lan1:
  v4_addr: 10.100.0.11
  v4_netmask: 255.255.255.0
  v4_gw: 10.100.0.1
mgmt:
  v4_addr: 10.100.0.10
  v4_netmask: 255.255.255.0
  v4_gw: 10.100.0.1
EOF

  tags = { Name = "Infoblox-GM" }

  depends_on = [aws_internet_gateway.gw]
}

# --- EIP for GM (attached to LAN1 for external access) ---
resource "aws_eip" "gm_eip" {
  domain = "vpc"
  tags   = { Name = "gm-eip" }
}

resource "aws_eip_association" "gm_eip_assoc" {
  network_interface_id = aws_network_interface.gm_lan1.id
  allocation_id        = aws_eip.gm_eip.id
  private_ip_address   = "10.100.0.11"

  depends_on = [aws_instance.gm]
}

# ===========================================================
# Windows Client #2 (10.100.0.120)
# ===========================================================

resource "aws_network_interface" "client_2_eni" {
  subnet_id       = aws_subnet.public.id
  private_ips     = ["10.100.0.120"]
  security_groups = [aws_security_group.rdp_sg.id]
  tags = { Name = "client-2-eni" }
}

resource "aws_eip" "client_2_eip" {
  domain = "vpc"
  tags   = { Name = "client-2-eip" }
}

resource "aws_eip_association" "client_2_assoc" {
  network_interface_id = aws_network_interface.client_2_eni.id
  allocation_id        = aws_eip.client_2_eip.id
  private_ip_address   = "10.100.0.120"

  depends_on = [aws_instance.client_2_vm]
}

resource "aws_instance" "client_2_vm" {
  ami           = data.aws_ami.windows.id
  instance_type = "t3.medium"
  key_name      = aws_key_pair.rdp.key_name

  network_interface {
    network_interface_id = aws_network_interface.client_2_eni.id
    device_index         = 0
  }

  user_data = templatefile("./scripts/winrm-init.ps1.tpl", {
    admin_password = var.windows_admin_password
  })

  tags = { Name = "client-vm-2" }

  depends_on = [aws_internet_gateway.gw]
}

# ===========================================================
# Ubuntu Syslog Server (10.100.0.140) - TCP 514 enabled
# ===========================================================

# --- Security Group for Syslog server ---
resource "aws_security_group" "syslog_sg" {
  name        = "allow_syslog"
  description = "Security group for syslog server with TCP 514"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 514
    to_port     = 514
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Syslog TCP"
  }

  ingress {
    from_port   = 514
    to_port     = 514
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Syslog UDP"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ICMP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "syslog-sg" }
}

resource "aws_network_interface" "ubuntu_syslog_eni" {
  subnet_id       = aws_subnet.public.id
  private_ips     = ["10.100.0.140"]
  security_groups = [aws_security_group.syslog_sg.id]
  tags = { Name = "ubuntu-syslog-eni" }
}

resource "aws_eip" "ubuntu_syslog_eip" {
  domain = "vpc"
  tags   = { Name = "ubuntu-syslog-eip" }
}

resource "aws_eip_association" "ubuntu_syslog_assoc" {
  network_interface_id = aws_network_interface.ubuntu_syslog_eni.id
  allocation_id        = aws_eip.ubuntu_syslog_eip.id
  private_ip_address   = "10.100.0.140"

  depends_on = [aws_instance.ubuntu_syslog_vm]
}

resource "aws_instance" "ubuntu_syslog_vm" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  key_name      = aws_key_pair.rdp.key_name

  network_interface {
    network_interface_id = aws_network_interface.ubuntu_syslog_eni.id
    device_index         = 0
  }

  user_data = <<-EOF
#!/bin/bash
sudo apt update -y
sudo apt install -y net-tools curl dnsutils traceroute iputils-ping rsyslog

sudo hostnamectl set-hostname ubuntu-syslog

# Enable rsyslog TCP and UDP reception on port 514
cat >> /etc/rsyslog.conf << 'RSYSLOG_EOF'

# Enable UDP syslog reception
module(load="imudp")
input(type="imudp" port="514")

# Enable TCP syslog reception
module(load="imtcp")
input(type="imtcp" port="514")
RSYSLOG_EOF

# Restart rsyslog to apply changes
sudo systemctl restart rsyslog
sudo systemctl enable rsyslog
EOF

  tags = { Name = "ubuntu-syslog" }

  depends_on = [aws_internet_gateway.gw]
}

# ===========================================================
# Azure Windows 11 Desktop Client
# ===========================================================

resource "azurerm_resource_group" "lab" {
  name     = "infoblox-lab-rg"
  location = var.azure_location
}

resource "azurerm_virtual_network" "lab" {
  name                = "infoblox-lab-vnet"
  address_space       = ["10.200.0.0/16"]
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
}

resource "azurerm_subnet" "public" {
  name                 = "public-subnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.200.0.0/24"]
}

resource "azurerm_network_security_group" "rdp" {
  name                = "win11-rdp-nsg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  security_rule {
    name                       = "Allow-RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-DNS-TCP"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-DNS-UDP"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.rdp.id
}

resource "azurerm_public_ip" "win11" {
  name                = "win11-public-ip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "win11" {
  name                = "win11-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.win11.id
  }
}

resource "azurerm_windows_virtual_machine" "win11" {
  name                  = "win11-client"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  size                  = var.azure_vm_size
  admin_username        = "LabAdmin"
  admin_password        = var.windows_admin_password
  network_interface_ids = [azurerm_network_interface.win11.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-24h2-pro"
    version   = "latest"
  }
}

# ===========================================================
# Azure Windows 11 Desktop Client #2
# ===========================================================

resource "azurerm_public_ip" "win11_2" {
  name                = "win11-2-public-ip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "win11_2" {
  name                = "win11-2-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.win11_2.id
  }
}

resource "azurerm_windows_virtual_machine" "win11_2" {
  name                  = "win11-client-2"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  size                  = var.azure_vm_size
  admin_username        = "LabAdmin"
  admin_password        = var.windows_admin_password
  network_interface_ids = [azurerm_network_interface.win11_2.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-24h2-pro"
    version   = "latest"
  }
}
