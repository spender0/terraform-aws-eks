data "template_file" "cluster_autoscaler_yaml" {
  template = "${file("cluster-autoscaler.t.yaml")}"
  vars {
    system_node_autoscaling_group_name = "${module.system_nodes.node_autoscaling_group_name}"
    eks_cluster_name                   = "${var.eks_cluster_name}"
    aws_region                         = "${var.aws_region}"
  }
}

data "template_file" "config_map_aws_auth" {
  template = "${file("config-map-aws-auth.t.yaml")}"
  vars {
    system_node_iam_role.node_iam_role_arn  = "${module.system_node_iam_role.node_iam_role_arn}"
    regular_node_iam_role.node_iam_role_arn = "${module.regular_node_iam_role.node_iam_role_arn}"

  }
}

resource "local_file" "cluster_autoscaller_yaml" {
  filename  = "./terraform.tfstate.d/${terraform.workspace}/cluster-autoscaler.yaml"
  content   = "${data.template_file.cluster_autoscaler_yaml.rendered}"
}

resource "local_file" "config_map_aws_auth" {
  content  = "${data.template_file.config_map_aws_auth.rendered}"
  filename = "./terraform.tfstate.d/${terraform.workspace}/config-map-aws-auth.yaml"
}


output execute {
  value = <<RUN
#Genereted kubeconfig.conf, cluster-autoscaler.yaml and map-aws-auth.yaml
#Tun this to finish nodes bootstraping.
#1 kubeconfig is located in workspace folder
export KUBECONFIG=./terraform.tfstate.d/${terraform.workspace}/kubeconfig.conf
#2 apply map-aws-auth.yaml to finish nodes bootstraping
kubectl apply -f ./terraform.tfstate.d/${terraform.workspace}/config-map-aws-auth.yaml
#3 wait for at least 1 node
kubectl get nodes --watch
#4 deploy cluster autoscaler
kubectl apply -f ./terraform.tfstate.d/dev/cluster-autoscaler.yaml
#4 deploy dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/heapster.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/influxdb.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/rbac/heapster-rbac.yaml
#5 create service accout and role for admin
kubectl apply -f eks-admin-service-account.yaml
kubectl apply -f eks-admin-cluster-role-binding.yaml
#6 get a token to login dashboard with
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep eks-admin | awk '{print $1}')
#7 proxy dashboard port on your localhost
kubectl proxy
#8 open dashboard
http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/
#9 login with that token from the spep #6
RUN
}