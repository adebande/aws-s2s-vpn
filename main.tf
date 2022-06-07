locals {

  name_prefix = "s2s"

  target_vpc = {
    a = "10.4.13.0/24"
    b = "10.4.14.0/24"
  }

  remote_gateway_ip = "82.66.115.76"

  # On-premises side
  vpn_local_ipv4_network_cidr = "172.16.0.0/16"

  # AWS side
  vpn_remote_ipv4_network_cidr = "10.4.0.0/16"
}




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
  description = "S2S Transit Gateway"
  tags = {
    Name = "${local.name_prefix}-tgw"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc" {
  for_each                                        = local.target_vpc
  subnet_ids                                      = [aws_subnet.private[each.key].id]
  transit_gateway_id                              = aws_ec2_transit_gateway.tgw.id
  vpc_id                                          = aws_vpc.target[each.key].id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = {
    Name = "${local.name_prefix}-tgw-attachment-${each.key}"
  }
}


# VPN to VPC Routes
resource "aws_ec2_transit_gateway_route" "vpn" {
  for_each                       = local.target_vpc
  destination_cidr_block         = each.value
  transit_gateway_route_table_id = aws_ec2_transit_gateway.tgw.association_default_route_table_id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc[each.key].id
}


# VPC to VPN Routes
resource "aws_ec2_transit_gateway_route_table" "vpc" {
  for_each           = local.target_vpc
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags = {
    Name = "${local.name_prefix}-tgw-route-table-${each.key}"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "vpc" {
  for_each                       = local.target_vpc
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpc[each.key].id
}

resource "aws_ec2_transit_gateway_route" "vpc" {
  for_each                       = local.target_vpc
  destination_cidr_block         = local.vpn_local_ipv4_network_cidr
  transit_gateway_attachment_id  = aws_vpn_connection.main.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.vpc[each.key].id
}



/* 
____    ____ .______     ______ 
\   \  /   / |   _  \   /      |
 \   \/   /  |  |_)  | |  ,----'
  \      /   |   ___/  |  |     
   \    /    |  |      |  `----.
    \__/     | _|       \______|

*/

resource "aws_vpc" "target" {
  for_each   = local.target_vpc
  cidr_block = each.value
  tags = {
    Name = "${local.name_prefix}-vpc-${each.key}"
  }
}

resource "aws_subnet" "private" {
  for_each   = local.target_vpc
  vpc_id     = aws_vpc.target[each.key].id
  cidr_block = each.value
  tags = {
    Name = "${local.name_prefix}-subnet-${each.key}"
  }
}

resource "aws_route_table" "tgw" {
  for_each = local.target_vpc
  vpc_id   = aws_vpc.target[each.key].id
  route {
    cidr_block         = local.vpn_local_ipv4_network_cidr
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }
  tags = {
    Name = "${local.name_prefix}-route-table-${each.key}"
  }
}

resource "aws_route_table_association" "tgw" {
  for_each       = local.target_vpc
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.tgw[each.key].id
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
  ip_address = local.remote_gateway_ip
  type       = "ipsec.1"
  tags = {
    Name = "${local.name_prefix}-customer-gateway"
  }
}

resource "aws_vpn_connection" "main" {
  transit_gateway_id       = aws_ec2_transit_gateway.tgw.id
  customer_gateway_id      = aws_customer_gateway.customer_gateway.id
  type                     = "ipsec.1"
  static_routes_only       = true
  tunnel1_preshared_key    = var.vpn_tunnel_psk
  tunnel2_preshared_key    = var.vpn_tunnel_psk
  local_ipv4_network_cidr  = local.vpn_local_ipv4_network_cidr
  remote_ipv4_network_cidr = local.vpn_remote_ipv4_network_cidr
  tags = {
    Name = "${local.name_prefix}-vpn-connection"
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
  for_each               = local.target_vpc
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private[each.key].id
  private_ip             = "${trimsuffix(each.value, "0/24")}10"
  vpc_security_group_ids = [aws_security_group.allow_ping[each.key].id]
  tags = {
    Name = "${local.name_prefix}-test-instance-${each.key}"
  }
}

resource "aws_security_group" "allow_ping" {
  for_each    = local.target_vpc
  name        = "allow_ping"
  description = "Allow ICMP inbound traffic"
  vpc_id      = aws_vpc.target[each.key].id

  ingress {
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
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
    Name = "${local.name_prefix}-allow-ping-${each.key}"
  }
}


# http://www.network-science.de/ascii/ -- Star Wars