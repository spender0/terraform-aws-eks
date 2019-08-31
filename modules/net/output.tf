output "net_vpc_id" {
  value = "${aws_vpc.vpc.id}"
}

output "net_vpc_subnet_ids" {
  value = aws_subnet.subnets.*.id
}
