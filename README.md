# learn-terraform-aws-documentDB
```bash
alias tf="terraform"; alias tfa="terraform apply --auto-approve"; alias tfd="terraform destroy --auto-approve"; alias tfm="terraform init; terraform fmt; terraform validate; terraform plan"
```
## https://developer.hashicorp.com/terraform/install
Install if running at cloudshell
```ruby
sudo yum install -y yum-utils shadow-utils; sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo; sudo yum -y install terraform; terraform init
```
## Resource
```bash
https://github.com/cloudposse/terraform-aws-documentdb-cluster/tree/main
```
## Redo
ALB
[] https://github.com/terraform-aws-modules/terraform-aws-alb/tree/master/modules
VPC
[] https://github.com/terraform-aws-modules/terraform-aws-vpc

