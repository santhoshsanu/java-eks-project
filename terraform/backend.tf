terraform {
  backend "s3" {
    bucket       = "java-eks-project-tfstate-889951088124"
    key          = "java-eks-project/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}
