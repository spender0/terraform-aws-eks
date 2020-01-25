variable "aws_key_pair_public_key_path" {default = "~/.ssh/id_rsa.pub"}


#Open kube-apiserver for particular public networks or IPs.
#Usually it is an ip dedicated by your internet providers
#You can figure the ip out here https://www.whatismyip.com/what-is-my-public-ip-address/
#0.0.0.0/0 means that it is accessible from everywhere
variable "security_group_eks_external_cidr_blocks" {
  type = "list"
  default = ["0.0.0.0/0"]
}


#########################################
########### vpc options #################
#########################################
variable "net_vpc_cidr_block" {default = "10.0.0.0/16"}
variable "net_public_subnet_cidr_blocks" {
  type = "list"
  default = ["10.0.0.0/24","10.0.1.0/24"]
}
variable "net_private_subnet_cidr_blocks" {
  type = "list"
  default = ["10.0.2.0/24","10.0.3.0/24"]
}

#########################################
####### eks cluster options #############
#########################################
variable "eks_cluster_name" { default = "terraform-eks-demo" }
variable "k8s_version" { default = "1.14"}

#########################################
###### worker nodes options #############
#########################################
variable "system_node_create" { default = "1"}
variable "system_node_launch_configuration_instance_type" {default = "t2.small"}
variable "system_node_launch_configuration_volume_type" {default = "standard"}
variable "system_node_launch_configuration_volume_size" {default = "30"}
variable "system_node_autoscaling_group_desired_capacity" {default = "1"}
variable "system_node_autoscaling_group_min_number" {default = "1"}
variable "system_node_autoscaling_group_max_number" {default = "3"}

variable "on_demand_node_create" { default = "1"}
variable "on_demand_node_launch_configuration_instance_type" {default = "t2.medium"}
variable "on_demand_node_launch_configuration_volume_type" {default = "standard"}
variable "on_demand_node_launch_configuration_volume_size" {default = "30"}
variable "on_demand_node_autoscaling_group_desired_capacity" {default = "1"}
variable "on_demand_node_autoscaling_group_min_number" {default = "1"}
variable "on_demand_node_autoscaling_group_max_number" {default = "3"}

variable "spot_node_create" { default = "0"}
#see ec2 -> Spot requests -> spot advisor to find out offers
variable "spot_node_launch_configuration_spot_price" {default = "0.036"}
variable "spot_node_launch_configuration_instance_type" {default = "m4.large"}
variable "spot_node_launch_configuration_volume_type" {default = "standard"}
variable "spot_node_launch_configuration_volume_size" {default = "30"}
variable "spot_node_autoscaling_group_desired_capacity" {default = "1"}
variable "spot_node_autoscaling_group_min_number" {default = "1"}
variable "spot_node_autoscaling_group_max_number" {default = "3"}

