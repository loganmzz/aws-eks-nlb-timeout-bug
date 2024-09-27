locals {
  aws_region = data.aws_availability_zones.available.id

  subnet_purposes = [
    {
      name = "general"
      size = 1
    },
    {
      name = "k8s"
      size = 2
    },
  ]
  subnet_kinds = [
    "public",
    "private",
  ]
  subnet_azs = sort(slice(data.aws_availability_zones.available.names, 0, 3))
  subnet_cidrs = cidrsubnets(
    aws_vpc.this.cidr_block,
    flatten([
      for purpose in local.subnet_purposes : flatten([
        for kind_index, kind_name in local.subnet_kinds : [
          for az_index, az_name in local.subnet_azs :
          8 - purpose.size + 1
        ]
      ])
    ])...
  )
  subnets = merge([
    for purpose_index, purpose in local.subnet_purposes : merge([
      for kind_index, kind_name in local.subnet_kinds : {
        for az_index, az_name in local.subnet_azs :
        "${purpose.name}_${kind_name}_${az_name}" => {
          key               = "${purpose.name}_${kind_name}_${az_name}"
          name              = "${var.prefix}${purpose.name}-${kind_name}-${format("%02d", az_index)}"
          purpose           = purpose.name
          kind              = kind_name
          availability_zone = az_name
          index             = az_index
          global_index      = purpose_index * length(local.subnet_kinds) * length(local.subnet_azs) + kind_index * length(local.subnet_azs) + az_index
          cidr_block        = local.subnet_cidrs[purpose_index * length(local.subnet_kinds) * length(local.subnet_azs) + kind_index * length(local.subnet_azs) + az_index]
        }
      }
    ]...)
  ]...)
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.prefix}main"
  }
}

resource "aws_vpc_dhcp_options" "this" {
  domain_name         = local.aws_region != "us-east-1" ? "${local.aws_region}.compute.internal" : "ec2.internal"
  domain_name_servers = ["AmazonProvidedDNS"]

  tags = {
    Name = "${var.prefix}main"
  }
}

resource "aws_vpc_dhcp_options_association" "this" {
  vpc_id          = aws_vpc.this.id
  dhcp_options_id = aws_vpc_dhcp_options.this.id
}

resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value.availability_zone
  cidr_block        = each.value.cidr_block

  map_public_ip_on_launch         = each.value.kind == "public"
  assign_ipv6_address_on_creation = false

  tags = merge(
    {
      Name             = each.value.name
      Purpose          = each.value.purpose
      Kind             = each.value.kind
      AvailabilityZone = each.value.availability_zone
      Index            = each.value.index
      GlobalIndex      = each.value.global_index
    },
    each.value.purpose == "k8s" && each.value.kind == "public" ? { "kubernetes.io/role/elb" : "1" } : {},
    each.value.purpose == "k8s" && each.value.kind == "private" ? { "kubernetes.io/role/internal-elb" : "1" } : {},
  )
}
