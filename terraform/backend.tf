terraform {
  backend "s3" {
    bucket  = "koru-mohan-tf-statefile-bucket"
    key     = "java-eks-project/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
