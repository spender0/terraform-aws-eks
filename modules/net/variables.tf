variable "net_vpc_name" {}
variable "net_eks_cluster_name" {}
variable "net_route_table_name" {}
variable "net_vpc_cidr_block" {default = "10.0.0.0/16"}
variable "net_subnet_cidr_block" {
  type = "list"
  default = ["10.0.0.0/24","10.0.1.0/24"]
}