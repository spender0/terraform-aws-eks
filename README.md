### Terraform config for automated AWS EKS cluster deploy

![alt text]()

##### Based on
* https://www.terraform.io/docs/providers/aws/guides/eks-getting-started.html
* https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html

##### Features
* Saves money with dynamic auto-scaling based on Cluster-autoscaler: https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler
* Spot instances also supported
* Able to create as many auto-scaling groups with different properties as needed
* Able to restrict running applications on "spot" or "system" instances 
* Flexible, most AWS settings are represented as terraform variables
* Well organized, with modules, as recommended by Terraform guys: https://www.terraform.io/docs/enterprise/workspaces/repo-structure.html#multiple-workspaces-per-repo-recommended-

##### Requirements
* git: https://git-scm.com/downloads
* AWS account with access and secret keys: https://aws.amazon.com
* aws cli: https://docs.aws.amazon.com/cli/latest/userguide/installing.html
* kubectl and aws-iam-authenticator: https://docs.aws.amazon.com/eks/latest/userguide/configure-kubectl.html
* terraform: https://www.terraform.io/intro/getting-started/install.html

##### Terraform workflow
* Run aws configure to specify access key and secret 

`aws configure`

* init 

`terraform init`

* If you are going to have one EKS per environment - select workspace (assume it is "dev"):

`terraform workspace new dev` or 
`terraform workspace select dev` (if already exists)

* revise variables.tf

* terraform apply:

`terraform apply -var 'eks_cluster_name=terraform-eks-dev'`

* if everything is ok it will show farther instructions that need to be done on EKS side
