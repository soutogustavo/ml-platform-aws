
data "aws_iam_policy_document" "mlflow_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["sagemaker.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "mlflow_execution" {
  name               = "${var.name_prefix}-mlflow-execution"
  assume_role_policy = data.aws_iam_policy_document.mlflow_trust.json
}

data "aws_iam_policy_document" "artifact_rw" {
  statement {
    sid       = "ListArtifactBucket"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [var.artifact_bucket_arn]
  }

  statement {
    sid       = "ReadWriteArtifacts"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.artifact_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "mlflow_execution_s3" {
  name   = "artifact-store-access"
  role   = aws_iam_role.mlflow_execution.id
  policy = data.aws_iam_policy_document.artifact_rw.json
}

resource "aws_sagemaker_mlflow_app" "this" {
  name                    = var.app_name
  artifact_store_uri      = var.artifact_store_uri
  role_arn                = aws_iam_role.mlflow_execution.arn
  model_registration_mode = "AutoModelRegistrationDisabled"
}

data "aws_iam_policy_document" "consumer" {
  statement {
    sid       = "UseMlflowApp"
    actions   = ["sagemaker-mlflow:*", "sagemaker:CallMlflowAppApi"]
    resources = [aws_sagemaker_mlflow_app.this.arn]
  }

  source_policy_documents = [data.aws_iam_policy_document.artifact_rw.json]
}

resource "aws_iam_policy" "consumer" {
  name        = "${var.name_prefix}-mlflow-consumer"
  description = "Log runs, artifacts and models to the shared MLflow App."
  policy      = data.aws_iam_policy_document.consumer.json
}
