module "all-infra" {
  source           = "git::https://github.com/Digidense/TF-module_repo_test.git//infra"
  api_gateway_name = "my-api-gateway"
  vpc_id           = module.all-vpc.vpc-id
}

module "all-vpc" {
  source = "git::https://github.com/Digidense/TF-module_repo_test.git//vpc"

}