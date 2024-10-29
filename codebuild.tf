# ---------------------------------------------------------------------------------------------------------------------
# Code Build
# ---------------------------------------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# Codebuild role

resource "aws_iam_role_policy" "ecr_access" {
  role   = aws_iam_role.codebuild_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = [
          "arn:aws:ecr:us-east-1:842675992953:repository/openjdk-slim" # Add this line
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "codebuild_role" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
  path               = "/"
}

resource "aws_iam_policy" "codebuild_policy" {
  description = "Policy to allow codebuild to execute build spec"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents",
        "ecr:GetAuthorizationToken"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.artifact_bucket.arn}/*"
    },
    {
      "Action": [
        "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability", "ecr:PutImage",
        "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Effect": "Allow",
      "Resource": "${aws_ecr_repository.image_repo.arn}"
    },
    {
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ],
      "Effect": "Allow",
      "Resource": "${aws_ecr_repository.image_repo.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "codebuild-attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}


# Codebuild project

resource "aws_codebuild_project" "codebuild" {
  depends_on = [

    aws_ecr_repository.image_repo
  ]
  name         = "codebuild-${var.name}"
  service_role = aws_iam_role.codebuild_role.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
    environment_variable {
      name  = "REPOSITORY_URI"
      value = aws_ecr_repository.image_repo.repository_url
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "CONTAINER_NAME"
      value = var.family
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = <<BUILDSPEC
version: 0.2
phases:
  install:
    runtime-versions:
      java: corretto8
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 842675992953.dkr.ecr.us-east-1.amazonaws.com
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=$${COMMIT_HASH:=latest}         
  build:
    commands:
      - cd petclinic
      - echo Build started on `date`
      - echo Building the jar
      - mvn package
      - echo Building the Docker image...
      - docker build -t $REPOSITORY_URI:latest .
      - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker image...
      - docker push $REPOSITORY_URI:latest
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - printf '[{"name":"%s","imageUri":"%s"}]' $CONTAINER_NAME $REPOSITORY_URI:$IMAGE_TAG > ../imagedefinitions.json
      - if [ -f ../imagedefinitions.json ]; then echo "File exists"; else echo "File does not exist"; fi
      - ls -al ..
artifacts:
  files:
    - 'imagedefinitions.json'
BUILDSPEC
  }
}
