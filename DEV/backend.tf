terraform {
  backend "s3" {
    bucket         = "tfstate-awsbucket-s3"
    key            = "tfstate-bucket"
    region         = "us-east-1"
    dynamodb_table = "tf-state-table"
  }
}