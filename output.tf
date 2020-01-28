output "kubeconfig" {
  value = module.eks_cluster.kubeconfig
}

output "kubeconfig_filename" {
  value = module.eks_cluster.kubeconfig_filename
}