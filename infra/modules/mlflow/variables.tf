variable "name_prefix" { type = string }
variable "app_name" { type = string }
variable "artifact_bucket_arn" { type = string }
variable "artifact_store_uri" {
  description = "s3://bucket/prefix used as the MLflow artifact root."
  type        = string
}
