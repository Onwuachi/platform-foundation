terraform {
  backend "s3" {
    bucket  = "devops-lab-tfstate-bucket"
    key     = "platform-foundation/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

