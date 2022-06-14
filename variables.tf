variable "name_prefix" {
  type        = string
  description = "Resources name tag prefix."
}

variable "spoke_vpc_cidr" {
  type        = list(string)
  description = "List of CIDR blocks for spoke VPCs (12 max, /16 only)."
}

variable "egress_vpc_cidr" {
  type        = string
  default     = ""
  description = "CIDR block for the egress VPC (/28 only)."
}

variable "remote_gateway_ip" {
  type        = string
  description = "On-premise gateway public IP."
}

variable "vpn_local_ipv4_network_cidr" {
  type        = string
  description = "On-premise side private network."
}

variable "vpn_remote_ipv4_network_cidr" {
  type        = string
  description = "AWS side private network."
}

variable "vpn_tunnel_psk" {
  type        = string
  description = "VPN tunnel preshared key"
  sensitive   = true
}

variable "ssh_public_key" {
  type        = string
  description = "Public key for SSH connection to test instances"
  sensitive   = true
}