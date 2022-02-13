terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

######################################################################################
# Create an code commit repo.
######################################################################################
resource "aws_codecommit_repository" "demo-pipeline0213-repo" {
  repository_name = "demo-pipeline0213"
  description     = "This is the Sample App Repository"
  tags = {
    Name = "demo-pipeline0213"
  }
}

######################################################################################
# Create an EC2 instance with a security group and keypair.
######################################################################################
/* resource "aws_instance" "test_server" {
  ami = "ami-04505e74c0741db8d"
  #   ami = data.aws_ami.ubuntu.id 
  instance_type = "t2.micro"
  key_name      = "Key1"
  # security_groups = sg-00f71129
  tags = {
    Name = "TestServerInstance"
  }
} */
######################################################################################
# Create a role , policy and attach the policy to the role
######################################################################################
resource "aws_iam_role" "demo-pipeline0213-role" {
  name = "demo-pipeline0213-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "demo-pipeline0213-policy" {
  name        = "demo-pipeline0213-policy"
  description = "A demo-pipeline0213 policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:ListBucket"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "demo-pipeline0213-attach" {
  role       = aws_iam_role.demo-pipeline0213-role.name
  policy_arn = aws_iam_policy.demo-pipeline0213-policy.arn
}

######################################################################################
# Create a Security group to attach to EC2
#####################################################################################

resource "aws_security_group" "demo-pipeline0213-sg" {
  name = "demo-pipeline0213-sg"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["69.215.228.134/32"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["69.215.228.134/32"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["69.215.228.134/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

######################################################################################
#  Create an instance profile to assign the role to ec2
######################################################################################
resource "aws_iam_instance_profile" "demo-pipeline0213_profile" {
  name = "demo-pipeline0213_profile"
  role = aws_iam_role.demo-pipeline0213-role.name
}

######################################################################################
# Create an EC2 instacne with Amazon Linux 2 AMI (HVM) - Kernel 5.10, SSD Volume Type 
# ami-033b95fb8079dc481
######################################################################################
resource "aws_instance" "demo-pipeline0213_server" {
  ami           = "ami-033b95fb8079dc481"
  instance_type = "t2.micro"
  key_name      = "Key1"
  # vpc_security_group_ids = []
  security_groups      = [aws_security_group.demo-pipeline0213-sg.name]
  iam_instance_profile = aws_iam_instance_profile.demo-pipeline0213_profile.name
  user_data            = <<-EOF
    #!/bin/bash
    yum -y update
    yum install -y ruby
    yum install -y aws-cli
    cd /home/ec2-user
    wget https://aws-codedeploy-us-east-2.s3.us-east-2.amazonaws.com/latest/install
    chmod +x ./install
    ./install auto
  EOF
  tags = {
    Name = "demo-pipeline0213"
  }
}


######################################################################################
# Code deploy :Create a role , policy and attach the policy to the role
######################################################################################
# variable "AWSCodedeploy_arn" {}

resource "aws_iam_role" "codedeploy-demo-pipeline0213-role" {
  name                = "codedeploy-demo-pipeline0213-role1"
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWScodedeployRole"]

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags = {
    Name = "demo-pipeline0213"
  }

}

# resource "aws_iam_role_policy_attachment" "codedeploy-demo-pipeline0213-attach" {
#   role       = aws_iam_role.demo-pipeline0213-role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWScodedeployRole"
# }


######################################################################################
# Create AWS code deploy app 
######################################################################################

resource "aws_codedeploy_app" "codedeploy-demo-pipeline0213" {
  compute_platform = "Server"
  name             = "codedeploy-demo-pipeline0213"
  tags = {
    Name = "demo-pipeline0213"
  }
}

resource "aws_sns_topic" "demo_sns_topic" {
  name = "demo_sns_topic"
}

resource "aws_codedeploy_deployment_config" "demo_config" {
  deployment_config_name = "codedeployDefault2.OneAtATime"

  #traffic_routing_config {
  #  type = "AllAtOnce"
  #}
  # Terraform: Should be "null" for EC2/Server

  minimum_healthy_hosts {
    type  = "HOST_COUNT"
    value = 0
  }
}

resource "aws_codedeploy_deployment_group" "cd_dg1" {
  app_name              = aws_codedeploy_app.codedeploy-demo-pipeline0213.name
  deployment_group_name = "cd_dg1"
  service_role_arn      = aws_iam_role.codedeploy-demo-pipeline0213-role.arn
  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "demo-pipeline0213"
    }
  }
  trigger_configuration {
    trigger_events = ["DeploymentFailure", "DeploymentSuccess", "DeploymentFailure", "DeploymentStop",
    "InstanceStart", "InstanceSuccess", "InstanceFailure"]
    trigger_name       = "event-trigger"
    trigger_target_arn = aws_sns_topic.demo_sns_topic.arn
  }

  auto_rollback_configuration {
    enabled = false
    events  = ["DEPLOYMENT_FAILURE"]
  }

  # alarm_configuration {
  #   alarms  = ["my-alarm-name"]
  #   enabled = true
  # }

  # load_balancer_info {
  #   target_group_info {
  #     name = aws_lb_target_group.external_alb_tg_app1.name
  #   }
  # }

  deployment_style {
    # deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type = "IN_PLACE"
  }

  # autoscaling_groups = [aws_autoscaling_group.devops_web_asg.id]
  tags = {
    Name = "demo-pipeline0213"
  }
}

######################################################################################
# Create AWS code pipeline  roles
######################################################################################

resource "aws_iam_role" "demo0213-codepipeline_role" {
  name = "demo0213-codepipeline_role"
  # managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/"]
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  tags = {
    Name = "demo-pipeline0213"
  }
}

resource "aws_iam_role_policy" "demo0213-codepipeline_policy" {
  name = "demo0213-codepipeline_policy"
  role = aws_iam_role.demo0213-codepipeline_role.id

  # policy = templatefile("${path.module}/templates/codepipeline-role-policy.json.tpl", {
  #   codepipeline_bucket_arn = aws_s3_bucket.codepipeline_bucket.arn
  # })
  policy = <<EOF
{
    "Statement": [
        {
            "Action": [
                "iam:PassRole"
            ],
            "Resource": "*",
            "Effect": "Allow",
            "Condition": {
                "StringEqualsIfExists": {
                    "iam:PassedToService": [
                        "cloudformation.amazonaws.com",
                        "elasticbeanstalk.amazonaws.com",
                        "ec2.amazonaws.com",
                        "ecs-tasks.amazonaws.com"
                    ]
                }
            }
        },
        {
            "Action": [
                "codecommit:CancelUploadArchive",
                "codecommit:GetBranch",
                "codecommit:GetCommit",
                "codecommit:GetRepository",
                "codecommit:GetUploadArchiveStatus",
                "codecommit:UploadArchive"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "codedeploy:CreateDeployment",
                "codedeploy:GetApplication",
                "codedeploy:GetApplicationRevision",
                "codedeploy:GetDeployment",
                "codedeploy:GetDeploymentConfig",
                "codedeploy:RegisterApplicationRevision"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "codestar-connections:UseConnection"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "elasticbeanstalk:*",
                "ec2:*",
                "elasticloadbalancing:*",
                "autoscaling:*",
                "cloudwatch:*",
                "s3:*",
                "sns:*",
                "cloudformation:*",
                "rds:*",
                "sqs:*",
                "ecs:*"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "lambda:InvokeFunction",
                "lambda:ListFunctions"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "opsworks:CreateDeployment",
                "opsworks:DescribeApps",
                "opsworks:DescribeCommands",
                "opsworks:DescribeDeployments",
                "opsworks:DescribeInstances",
                "opsworks:DescribeStacks",
                "opsworks:UpdateApp",
                "opsworks:UpdateStack"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "cloudformation:CreateStack",
                "cloudformation:DeleteStack",
                "cloudformation:DescribeStacks",
                "cloudformation:UpdateStack",
                "cloudformation:CreateChangeSet",
                "cloudformation:DeleteChangeSet",
                "cloudformation:DescribeChangeSet",
                "cloudformation:ExecuteChangeSet",
                "cloudformation:SetStackPolicy",
                "cloudformation:ValidateTemplate"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "codebuild:BatchGetBuilds",
                "codebuild:StartBuild",
                "codebuild:BatchGetBuildBatches",
                "codebuild:StartBuildBatch"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Effect": "Allow",
            "Action": [
                "devicefarm:ListProjects",
                "devicefarm:ListDevicePools",
                "devicefarm:GetRun",
                "devicefarm:GetUpload",
                "devicefarm:CreateUpload",
                "devicefarm:ScheduleRun"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "servicecatalog:ListProvisioningArtifacts",
                "servicecatalog:CreateProvisioningArtifact",
                "servicecatalog:DescribeProvisioningArtifact",
                "servicecatalog:DeleteProvisioningArtifact",
                "servicecatalog:UpdateProduct"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudformation:ValidateTemplate"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:DescribeImages"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "states:DescribeExecution",
                "states:DescribeStateMachine",
                "states:StartExecution"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "appconfig:StartDeployment",
                "appconfig:StopDeployment",
                "appconfig:GetDeployment"
            ],
            "Resource": "*"
        }
    ],
    "Version": "2012-10-17"
}
EOF
}

resource "aws_iam_role_policy_attachment" "demo0213-codepipeline_codecommit" {
  role       = aws_iam_role.demo0213-codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeCommitFullAccess"
}

######################################################################################
# Create AWS S3 bucket
######################################################################################
resource "aws_s3_bucket" "demo0213-codepipeline_bucket" {
  bucket = "demo0213-bucket"
  acl    = "private"
  force_destroy = true
  lifecycle {
    prevent_destroy = false
  }
  versioning {
    enabled = true
  }
  tags = {
    Name = "demo-pipeline0213"
  }
}
# resource "aws_s3_bucket_acl" "demo0213-codepipeline_bucket_acl" {
#   bucket = aws_s3_bucket.demo0213-codepipeline_bucket.id
#   acl    = "private"
# }

######################################################################################
# Create AWS code pipeline
######################################################################################


resource "aws_codepipeline" "demo0213-codepipeline" {
  name     = "demo0213-pipeline"
  role_arn = aws_iam_role.demo0213-codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.demo0213-codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source"]
      configuration = {
        RepositoryName = "demo-pipeline0212"
        BranchName     = "master"
      }
    }
  }

  /* stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = "demo-pipeline0213"
      }
    }
  } */

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["source"]
      version         = "1"

      configuration = {
        ApplicationName     = aws_codedeploy_app.codedeploy-demo-pipeline0213.name
        DeploymentGroupName = aws_codedeploy_deployment_group.cd_dg1.deployment_group_name
      }
    }
  }
}