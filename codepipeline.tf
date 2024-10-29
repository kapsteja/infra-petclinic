
# ---------------------------------------------------------------------------------------------------------------------
# Code Pipeline
# ---------------------------------------------------------------------------------------------------------------------


# Codepipeline role

resource "aws_iam_role" "codepipeline_role" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
  path               = "/"
}

resource "aws_iam_policy" "codepipeline_policy" {
  description = "Policy to allow codepipeline to execute"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetObject", "s3:GetObjectVersion", "s3:PutObject",
        "s3:GetBucketVersioning"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.artifact_bucket.arn}/*"
    },
    {
      "Action" : [
        "codebuild:StartBuild", "codebuild:BatchGetBuilds",
        "cloudformation:*",
        "iam:PassRole"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action" : [
        "ecs:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action" : [
        "codecommit:CancelUploadArchive",
        "codecommit:GetBranch",
        "codecommit:GetCommit",
        "codecommit:GetUploadArchiveStatus",
        "codecommit:UploadArchive"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "codepipeline-attach" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_policy.arn
}

resource "aws_s3_bucket" "artifact_bucket" {
  bucket = "tds-29062024"
}

# Optional: Define a bucket policy to control access explicitly
resource "aws_s3_bucket_policy" "artifact_bucket_policy" {
  bucket = aws_s3_bucket.artifact_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "codepipeline.amazonaws.com"
        },
        Action   = ["s3:GetObject", "s3:PutObject"],
        Resource = "${aws_s3_bucket.artifact_bucket.arn}/*"
      },
      {
        Effect = "Allow",
        Principal = {
          Service = "codebuild.amazonaws.com"
        },
        Action   = ["s3:GetObject", "s3:PutObject"],
        Resource = "${aws_s3_bucket.artifact_bucket.arn}/*"
      }
    ]
  })
}


# CodePipeline 

resource "aws_codepipeline" "pipeline" {
  depends_on = [
    aws_codebuild_project.codebuild,
  ]
  name     = "${var.github_repo}-${var.github_branch}-Pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
  artifact_store {
    location = aws_s3_bucket.artifact_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      version          = "1"
      provider         = "GitHub"
      output_artifacts = ["SourceOutput"]
      run_order        = 1
      configuration = {
        Repo      = var.github_repo
        Branch    = var.github_branch
         Owner      = var.github_owner 
         OAuthToken = data.aws_ssm_parameter.github_token.value
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      version          = "1"
      provider         = "CodeBuild"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["BuildOutput"]
      run_order        = 1
      configuration = {
        ProjectName = aws_codebuild_project.codebuild.id
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      version         = "1"
      provider        = "ECS"
      run_order       = 1
      input_artifacts = ["BuildOutput"]
      configuration = {
        ClusterName       = "${var.stack}-Cluster"
        ServiceName       = "${var.stack}-Service"
        FileName          = "imagedefinitions.json"
        DeploymentTimeout = "15"
      }
    }
  }
}

output "pipeline_url" {
  value = "https://console.aws.amazon.com/codepipeline/home?region=${var.aws_region}#/view/${aws_codepipeline.pipeline.id}"
}
