# TODO : IPSEC CONFIG + VAR CONSTRAINTS


/* 

.___________..______          ___      .__   __.      _______. __  .___________.
|           ||   _  \        /   \     |  \ |  |     /       ||  | |           |
`---|  |----`|  |_)  |      /  ^  \    |   \|  |    |   (----`|  | `---|  |----`
    |  |     |      /      /  /_\  \   |  . `  |     \   \    |  |     |  |     
    |  |     |  |\  \----./  _____  \  |  |\   | .----)   |   |  |     |  |     
    |__|     | _| `._____/__/     \__\ |__| \__| |_______/    |__|     |__|     
                                                                                
  _______      ___   .___________. ___________    __    ____  ___   ____    ____ 
 /  _____|    /   \  |           ||   ____\   \  /  \  /   / /   \  \   \  /   / 
|  |  __     /  ^  \ `---|  |----`|  |__   \   \/    \/   / /  ^  \  \   \/   /  
|  | |_ |   /  /_\  \    |  |     |   __|   \            / /  /_\  \  \_    _/   
|  |__| |  /  _____  \   |  |     |  |____   \    /\    / /  _____  \   |  |     
 \______| /__/     \__\  |__|     |_______|   \__/  \__/ /__/     \__\  |__|  

*/

resource "aws_ec2_transit_gateway" "tgw" {
  description = "Learning account network hub"
  tags = {
    Name = "${var.name_prefix}-tgw"
  }
}


#################################
# Transit Gateway VPC Attachments
#################################

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke" {
  for_each                                        = local.spoke_vpc
  subnet_ids                                      = [aws_subnet.spoke_attachment_a[each.key].id, aws_subnet.spoke_attachment_b[each.key].id]
  transit_gateway_id                              = aws_ec2_transit_gateway.tgw.id
  vpc_id                                          = aws_vpc.spoke[each.key].id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = {
    Name = "${var.name_prefix}-spoke-vpc-${each.key}-tgw-attachment"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "egress" {
  subnet_ids                                      = [aws_subnet.egress_attachment[0].id, aws_subnet.egress_attachment[1].id]
  transit_gateway_id                              = aws_ec2_transit_gateway.tgw.id
  vpc_id                                          = aws_vpc.egress.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = {
    Name = "${var.name_prefix}-egress-tgw-attachment"
  }
}


###########################################
# VPN (default) Transit Gateway Route Table
###########################################

resource "aws_ec2_transit_gateway_route" "vpn_to_spoke" {
  for_each                       = local.spoke_vpc
  destination_cidr_block         = each.value["cidr"]
  transit_gateway_route_table_id = aws_ec2_transit_gateway.tgw.association_default_route_table_id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[each.key].id
}

########################################
# Egress VPC Transit Gateway Route Table
########################################

resource "aws_ec2_transit_gateway_route_table" "egress" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags = {
    Name = "${var.name_prefix}-egress-vpc-route-table"
  }
}

resource "aws_ec2_transit_gateway_route" "egress_to_spoke" {
  for_each                       = local.spoke_vpc
  destination_cidr_block         = each.value["cidr"]
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[each.key].id
}

resource "aws_ec2_transit_gateway_route_table_association" "egress" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.egress.id
}


########################################
# Spoke VPC Transit Gateway Route Tables
########################################

resource "aws_ec2_transit_gateway_route_table" "spoke" {
  for_each           = local.spoke_vpc
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags = {
    Name = "${var.name_prefix}-spoke-vpc-${each.key}-tgw-route-table"
  }
}

resource "aws_ec2_transit_gateway_route" "spoke_to_vpn" {
  for_each                       = local.spoke_vpc
  destination_cidr_block         = var.vpn_local_ipv4_network_cidr
  transit_gateway_attachment_id  = aws_vpn_connection.main.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke[each.key].id
}

resource "aws_ec2_transit_gateway_route" "spoke_to_egress" {
  for_each                       = local.spoke_vpc
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke[each.key].id
}

resource "aws_ec2_transit_gateway_route" "blackhole" {
  for_each                       = { for r in local.blackhole_routes : r.route => r }
  destination_cidr_block         = each.value.destination
  blackhole                      = true
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke[each.value.attachment].id
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke" {
  for_each                       = local.spoke_vpc
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke[each.key].id
}




/* 
____    ____ .______     ______ 
\   \  /   / |   _  \   /      |
 \   \/   /  |  |_)  | |  ,----'
  \      /   |   ___/  |  |     
   \    /    |  |      |  `----.
    \__/     | _|       \______|

*/

data "aws_availability_zones" "available" {
  state = "available"
}


############
# Egress VPC
############

resource "aws_vpc" "egress" {
  cidr_block = var.egress_vpc_cidr
  tags = {
    Name = "${var.name_prefix}-egress-vpc"
  }
}

resource "aws_internet_gateway" "egress" {
  vpc_id = aws_vpc.egress.id

  tags = {
    Name = "${var.name_prefix}-egress-internet-gateway"
  }
}


# Egress Subnets

resource "aws_subnet" "egress" {
  count             = 2
  vpc_id            = aws_vpc.egress.id
  cidr_block        = count.index == 0 ? "${trimsuffix(var.egress_vpc_cidr, "0/26")}0/28" : "${trimsuffix(var.egress_vpc_cidr, "0/26")}16/28"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.name_prefix}-egress-subnet-${count.index}"
  }
}

resource "aws_nat_gateway" "egress" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.egress[count.index].id

  tags = {
    Name = "${var.name_prefix}-nat-gateway-${count.index}"
  }

  depends_on = [aws_internet_gateway.egress]
}

resource "aws_eip" "nat" {
  count = 2
  vpc   = true
  tags = {
    Name = "${var.name_prefix}-nat-eip-${count.index}"
  }
}

resource "aws_route_table" "egress" {
  vpc_id = aws_vpc.egress.id

  tags = {
    Name = "${var.name_prefix}-egress-route-table"
  }
}

resource "aws_route" "to_internet" {
  route_table_id         = aws_route_table.egress.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.egress.id
}

resource "aws_route" "egress_to_spoke" {
  for_each               = local.spoke_vpc
  route_table_id         = aws_route_table.egress.id
  destination_cidr_block = each.value["cidr"]
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

resource "aws_route_table_association" "egress" {
  count          = 2
  subnet_id      = aws_subnet.egress[count.index].id
  route_table_id = aws_route_table.egress.id
}


# Egress TGW Attachment subnets

resource "aws_subnet" "egress_attachment" {
  count             = 2
  vpc_id            = aws_vpc.egress.id
  cidr_block        = count.index == 0 ? "${trimsuffix(var.egress_vpc_cidr, "0/26")}32/28" : "${trimsuffix(var.egress_vpc_cidr, "0/26")}48/28"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.name_prefix}-egress-attachment-subnet-${count.index}"
  }
}

resource "aws_route_table" "nat" {
  count  = 2
  vpc_id = aws_vpc.egress.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.egress[count.index].id
  }

  tags = {
    Name = "${var.name_prefix}-nat-route-table-${count.index}"
  }
}

resource "aws_route_table_association" "nat" {
  count          = 2
  subnet_id      = aws_subnet.egress_attachment[count.index].id
  route_table_id = aws_route_table.nat[count.index].id
}


############
# Spoke VPC
############

resource "aws_vpc" "spoke" {
  for_each   = local.spoke_vpc
  cidr_block = each.value["cidr"]
  tags = {
    Name = "${var.name_prefix}-spoke-vpc-${each.key}"
  }
}


# Workload Subnets

resource "aws_subnet" "private_1" {
  for_each          = local.spoke_vpc
  vpc_id            = aws_vpc.spoke[each.key].id
  cidr_block        = "${trimsuffix(each.value["cidr"], "0.0/16")}1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "${var.name_prefix}-private-subnet-1-${each.key}"
  }
}

resource "aws_subnet" "private_2" {
  for_each          = local.spoke_vpc
  vpc_id            = aws_vpc.spoke[each.key].id
  cidr_block        = "${trimsuffix(each.value["cidr"], "0.0/16")}2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "${var.name_prefix}-private-subnet-2-${each.key}"
  }
}

resource "aws_route_table" "private" {
  for_each = local.spoke_vpc
  vpc_id   = aws_vpc.spoke[each.key].id
  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }
  tags = {
    Name = "${var.name_prefix}-private-route-table-${each.key}"
  }
}

resource "aws_route_table_association" "private_1" {
  for_each       = local.spoke_vpc
  subnet_id      = aws_subnet.private_1[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_route_table_association" "private_2" {
  for_each       = local.spoke_vpc
  subnet_id      = aws_subnet.private_2[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}


# TGW attachment Subnets

resource "aws_subnet" "spoke_attachment_a" {
  for_each          = local.spoke_vpc
  vpc_id            = aws_vpc.spoke[each.key].id
  cidr_block        = "${trimsuffix(each.value["cidr"], "0.0/16")}0.0/28"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "${var.name_prefix}-tgw-attachment-subnet-1-${each.key}"
  }
}

resource "aws_subnet" "spoke_attachment_b" {
  for_each          = local.spoke_vpc
  vpc_id            = aws_vpc.spoke[each.key].id
  cidr_block        = "${trimsuffix(each.value["cidr"], "0.0/16")}0.16/28"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "${var.name_prefix}-tgw-attachment-subnet-2-${each.key}"
  }
}




/*
____    ____ .______   .__   __. 
\   \  /   / |   _  \  |  \ |  | 
 \   \/   /  |  |_)  | |   \|  | 
  \      /   |   ___/  |  . `  | 
   \    /    |  |      |  |\   | 
    \__/     | _|      |__| \__| 
                                 
  ______   ______   .__   __. .__   __.  _______   ______ .___________. __    ______   .__   __. 
 /      | /  __  \  |  \ |  | |  \ |  | |   ____| /      ||           ||  |  /  __  \  |  \ |  | 
|  ,----'|  |  |  | |   \|  | |   \|  | |  |__   |  ,----'`---|  |----`|  | |  |  |  | |   \|  | 
|  |     |  |  |  | |  . `  | |  . `  | |   __|  |  |         |  |     |  | |  |  |  | |  . `  | 
|  `----.|  `--'  | |  |\   | |  |\   | |  |____ |  `----.    |  |     |  | |  `--'  | |  |\   | 
 \______| \______/  |__| \__| |__| \__| |_______| \______|    |__|     |__|  \______/  |__| \__| 
                                                                                                 
*/

resource "aws_customer_gateway" "customer_gateway" {
  bgp_asn    = 65000
  ip_address = var.remote_gateway_ip
  type       = "ipsec.1"
  tags = {
    Name = "${var.name_prefix}-customer-gateway"
  }
}

resource "aws_vpn_connection" "main" {
  transit_gateway_id       = aws_ec2_transit_gateway.tgw.id
  customer_gateway_id      = aws_customer_gateway.customer_gateway.id
  type                     = "ipsec.1"
  static_routes_only       = true
  tunnel1_preshared_key    = var.vpn_tunnel_psk
  tunnel2_preshared_key    = var.vpn_tunnel_psk
  local_ipv4_network_cidr  = var.vpn_local_ipv4_network_cidr
  remote_ipv4_network_cidr = var.vpn_remote_ipv4_network_cidr
  tags = {
    Name = "${var.name_prefix}-vpn-connection"
  }
}




/*

.___________. _______     _______.___________.
|           ||   ____|   /       |           |
`---|  |----`|  |__     |   (----`---|  |----`
    |  |     |   __|     \   \       |  |     
    |  |     |  |____.----)   |      |  |     
    |__|     |_______|_______/       |__|     
                                              
 __  .__   __.      _______.___________.    ___      .__   __.   ______  _______     _______.
|  | |  \ |  |     /       |           |   /   \     |  \ |  |  /      ||   ____|   /       |
|  | |   \|  |    |   (----`---|  |----`  /  ^  \    |   \|  | |  ,----'|  |__     |   (----`
|  | |  . `  |     \   \       |  |      /  /_\  \   |  . `  | |  |     |   __|     \   \    
|  | |  |\   | .----)   |      |  |     /  _____  \  |  |\   | |  `----.|  |____.----)   |   
|__| |__| \__| |_______/       |__|    /__/     \__\ |__| \__|  \______||_______|_______/    
                                                                                             
*/

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "test" {
  for_each               = local.spoke_vpc
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_1[each.key].id
  private_ip             = "${trimsuffix(each.value["cidr"], "0.0/16")}1.10"
  vpc_security_group_ids = [aws_security_group.allow_all[each.key].id]
  key_name               = aws_key_pair.test.key_name
  tags = {
    Name = "${var.name_prefix}-test-instance-${each.key}"
  }
}

resource "aws_key_pair" "test" {
  key_name   = "deployer-key"
  public_key = var.ssh_public_key
}

resource "aws_security_group" "allow_all" {
  for_each    = local.spoke_vpc
  name        = "allow_all"
  description = "Allow all traffic"
  vpc_id      = aws_vpc.spoke[each.key].id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.name_prefix}-allow-all-sg-${each.key}"
  }
}


# http://www.network-science.de/ascii/ -- Star Wars