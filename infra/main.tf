module "artifact_store" {
  source = "./modules/artifact_store"

  bucket_name = "${local.name_prefix}-mlflow-artifacts"
}

module "mlflow" {
  source = "./modules/mlflow"

  name_prefix         = local.name_prefix
  app_name            = var.mlflow_app_name
  artifact_bucket_arn = module.artifact_store.bucket_arn
  artifact_store_uri  = "s3://${module.artifact_store.bucket_name}/mlflow"
}

module "github_oidc" {
  source = "./modules/github_oidc"

  name_prefix     = local.name_prefix
  github_repo     = var.github_repo
  github_owner_id = var.github_owner_id
  github_repo_id  = var.github_repo_id
}
