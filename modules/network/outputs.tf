output "vpc" {
  value = aws_vpc.this
}

output "subnets" {
  value = {
    for key, spec in local.subnets : key => merge(
      spec,
      {
        resource = aws_subnet.this[key]
      },
    )
  }
}
