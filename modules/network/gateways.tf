resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.prefix}main"
  }
}

resource "aws_eip" "nat_gateway" {
  for_each = {
    for key, subnet in local.subnets :
    "${subnet.availability_zone}" => subnet
    if subnet.purpose == "general" && subnet.kind == "public"
  }

  domain = "vpc"

  tags = {
    Name = "${var.prefix}nat-gateway-${each.key}"
  }
}

resource "aws_nat_gateway" "this" {
  for_each = {
    for key, subnet in local.subnets :
    "${subnet.availability_zone}" => subnet
    if subnet.purpose == "general" && subnet.kind == "public"
  }

  allocation_id = aws_eip.nat_gateway[each.key].id
  subnet_id     = aws_subnet.this[each.value.key].id

  tags = {
    Name = "${var.prefix}${each.key}"
  }
}
