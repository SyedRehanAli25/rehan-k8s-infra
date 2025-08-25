terraform {
  backend "s3" {
    bucket = "k8s-tool-terraform-state-bucket"
    key    = "k8s-infra/terraform.tfstate"
    region = "us-west-1"
  }
}

