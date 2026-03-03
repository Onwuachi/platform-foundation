###############################################
# GitHub OIDC Provider (only created once)
###############################################
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  # GitHub's OIDC thumbprint (stable)
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}

###############################################
# IAM Role for GitHub Actions (Packer AMI builds)
###############################################
resource "aws_iam_role" "github_oidc_role" {
  name = "github-oidc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            # Required audience
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"

            # Restrict to your repo (replace these as needed!)
            "token.actions.githubusercontent.com:sub" = "repo:Onwuachi/platform-foundation:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

###############################################
# IAM Policy for Packer AMI Builds
###############################################
resource "aws_iam_policy" "packer_policy" {
  name        = "packer-build-policy"
  description = "Permissions for GitHub Actions to build AMIs with Packer"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EC2 permissions required for Packer AMI builds
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:CreateTags",
          "ec2:CreateImage",
          "ec2:RegisterImage",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:StopInstances",
          "ec2:StartInstances",
          "ec2:DeleteSnapshot",
          "ec2:CreateSnapshot",
          "ec2:ModifyImageAttribute",
          "ec2:DescribeImages",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },

      # SSM Parameter Store (write AMI ID)
      {
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter"
        ]
        Resource = "*"
      },

      # Allow Packer to pass instance profiles if needed
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
      }
    ]
  })
}

###############################################
# Attach Policy to GitHub OIDC Role
###############################################
resource "aws_iam_role_policy_attachment" "github_oidc_attach" {
  role       = aws_iam_role.github_oidc_role.name
  policy_arn = aws_iam_policy.packer_policy.arn
}
