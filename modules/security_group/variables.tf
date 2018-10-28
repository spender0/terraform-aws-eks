variable "security_group_name_eks" {}
variable "security_group_name_node" {}
variable "security_group_vpc_id" {}
variable "security_group_eks_cluster_name" {}
#Open kube-apiserver for particular public networks or IPs.
#Usually it is an ip dedicated by your internet providers
#You can figure the ip out here https://www.whatismyip.com/what-is-my-public-ip-address/
#0.0.0.0/32 means that it is inaccessible from anywhere
variable "security_group_eks_external_cidr_blocks" {
  type = "list"
  default = ["0.0.0.0/32"]
}