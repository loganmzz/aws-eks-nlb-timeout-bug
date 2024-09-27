resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.prefix}public"
  }
}

resource "aws_route" "internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_main_route_table_association" "this" {
  vpc_id         = aws_vpc.this.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public" {
  for_each = {
    for key, subnet in local.subnets :
    key => subnet
    if subnet.kind == "public"
  }

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = {
    for az_name in local.subnet_azs :
    az_name => az_name
  }

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.prefix}private-${each.key}"
  }
}

resource "aws_route" "nat_gateway" {
  for_each = {
    for az_name in local.subnet_azs :
    az_name => az_name
  }

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.key].id
}

resource "aws_route_table_association" "private" {
  for_each = {
    for key, subnet in local.subnets :
    key => subnet
    if subnet.kind == "private"
  }

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.private[each.value.availability_zone].id
}
