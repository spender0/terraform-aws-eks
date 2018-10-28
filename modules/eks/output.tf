#Configuring kubectl for EKS

resource "local_file" "kubeconfig" {
  content = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.eks_cluster.endpoint}
    certificate-authority-data: ${aws_eks_cluster.eks_cluster.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${var.eks_cluster_name}"
KUBECONFIG
  filename = "./terraform.tfstate.d/${terraform.workspace}/kubeconfig.conf"
}

output "eks_cluster_id" {
  value = "${aws_eks_cluster.eks_cluster.id}"
}

output "eks_cluster_endpoint" {
  value = "${aws_eks_cluster.eks_cluster.endpoint}"
}

output "eks_cluster_ca_data" {
  value = "${aws_eks_cluster.eks_cluster.certificate_authority.0.data}"
}