data "aws_availability_zones" "available" {}

//create dedicated VPC for kubernetes related stuff
resource "aws_vpc" "vpc" {
  cidr_block = "${var.net_vpc_cidr_block}"
  enable_dns_hostnames = "true"
  tags = "${
    map(
     "Name", "${var.net_vpc_name}",
     "kubernetes.io/cluster/${var.net_eks_cluster_name}", "shared"
    )
  }"
}

resource "aws_subnet" "subnets" {
  count = "${length(var.net_subnet_cidr_block)}"

  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block        = "${var.net_subnet_cidr_block[count.index]}"
  vpc_id            = "${aws_vpc.vpc.id}"

  tags = "${
    map(
     "Name", "${var.net_vpc_name}",
     "kubernetes.io/cluster/${var.net_eks_cluster_name}", "shared"
    )
  }"
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags = {
    Name = "${var.net_vpc_name}"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags = {
    Name = "${var.net_route_table_name}"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internet_gateway.id}"
  }
}

resource "aws_route_table_association" "route_table_association" {
  count = "${length(var.net_subnet_cidr_block)}"
  subnet_id      = "${aws_subnet.subnets.*.id[count.index]}"
  route_table_id = "${aws_route_table.route_table.id}"
}
