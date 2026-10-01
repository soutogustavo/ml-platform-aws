
output "mlflow_tracking_uri" {
  description = "Value for MLFLOW_TRACKING_URI (the MLflow App ARN, used by the sagemaker-mlflow plugin)."
  value       = module.mlflow.app_arn
}

output "artifact_bucket_name" {
  description = "S3 bucket that stores MLflow artifacts."
  value       = module.artifact_store.bucket_name
}

output "mlflow_consumer_policy_arn" {
  description = "IAM policy to attach to any role (ECS task role, CI role, your CLI role) that logs to MLflow."
  value       = module.mlflow.consumer_policy_arn
}

output "region" {
  value = var.region
}
