output "app_arn" {
  value = aws_sagemaker_mlflow_app.this.arn
}

output "execution_role_arn" {
  value = aws_iam_role.mlflow_execution.arn
}

output "consumer_policy_arn" {
  value = aws_iam_policy.consumer.arn
}
