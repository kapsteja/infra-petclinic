
data "aws_ssm_parameter" "dbpassword" {
  name = "/database/password"
  #   with_decryption = true
}

data "aws_ssm_parameter" "github_token" {
  name            = "/github/token"
  with_decryption = true
}

data "aws_iam_policy" "AmazonSSMReadOnlyAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

data "aws_iam_policy" "AmazonECSTaskExecutionRolePolicy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}