


### Yet another Terraform config for automated AWS EKS cluster deploy

![alt text](https://github.com/spender0/terraform-aws-eks/raw/master/diagram.jpg)

##### Features
* Dynamic auto-scaling based on Cluster Autoscaler: https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler
* AWS IAM based authentication. Control which AWS user should be authenticated by K8s 
* Multigroup, able to create as many auto-scaling groups with different properties as needed. Spot instances also supported
* Flexible, most AWS settings are represented as terraform variables
* Well organized, with modules, as recommended by Terraform: https://www.terraform.io/docs/enterprise/workspaces/repo-structure.html#multiple-workspaces-per-repo-recommended-

##### Requirements
* git: https://git-scm.com/downloads
* AWS account with access and secret keys: https://aws.amazon.com
* aws cli: https://docs.aws.amazon.com/cli/latest/userguide/installing.html
* kubectl and aws-iam-authenticator: https://docs.aws.amazon.com/eks/latest/userguide/configure-kubectl.html
* terraform: https://www.terraform.io/intro/getting-started/install.html
* helm and tiller(local): https://helm.sh/docs/install/

##### Terraform workflow

* Run aws configure to specify access key and secret 

`aws configure --profile YOUR_AWS_PROFILE_NAME`

* Clone this repository

`git clone https://github.com/spender0/terraform-aws-eks.git`

`cd terraform-aws-eks`

* Create S3 bucket for terraform state

`aws s3 mb s3://YOUR_BUCKET_NAME`

* Terraform init 

`terraform init -backend-config "bucket=YOUR_BUCKET_NAME" -backend-config "key=file.state"`

* If you are going to have one EKS per environment - select workspace (assume it is "dev"):

`terraform workspace new dev` or 
`terraform workspace select dev` (if already exists)

* Revise variables.tf

* Terraform apply:

`terraform apply -var 'eks_cluster_name=terraform-eks-dev'`

* If everything is ok it will print farther instructions that need to be done on K8s side

* Upload kubeconfig on s3
`aws s3 cp terraform.tfstate.d/dev/kubeconfig.conf s3://YOUR_BUCKET_NAME/env:/dev/`

##### Access to Kubernetes Dashboard

* Get a token to login dashboard with
 
`kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep eks-admin | awk '{print $1}')`

* Proxy dashboard port on your localhost

`kubectl proxy &`

* Open dashboard and login with the token http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:https/proxy/#!/login

##### Add additional AWS IAM users that are supposed to be EKS admins

* Add IAM users that are supposed to be EKS admins to the group named YOUR_CLUSTER_NAME-eks-admin.

* The users then should assume the role in order to get AWS EKS credentials:

* OPTION 1

`aws sts assume-role --role-arn arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/terraform-eks-dev-eks-admin --role-session-name eks-admin`

`export AWS_ACCESS_KEY_ID="get it from 'aws sts assume-role' output`

`export AWS_SECRET_ACCESS_KEY="get it from 'aws sts assume-role' output`

`export AWS_SESSION_TOKEN="get it from 'aws sts assume-role' output`


* OPTION 2: add new profile to ~/.aws/config:
[terraform-eks-dev]
role_arn = arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/terraform-eks-dev-eks-admin
source_profile = EXISTING_AWS_PROFILE

then activate the profile `export AWS_PROFILE=terraform-eks-dev`

##### Based on
* https://www.terraform.io/docs/providers/aws/guides/eks-getting-started.html
* https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html