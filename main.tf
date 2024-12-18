resource "aws_iam_policy" "policy" {
  name        = "ec2_stop_start_policy"
  path        = "/"
  description = "ec2_stop_start_policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:*:*:*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:StartInstances",
          "ec2:StopInstances"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "ec2_auto_attach" {
  name       = "ec2_stop_start_policy_attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "scheduler.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

# Attach the policy to the IAM role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  policy_arn = aws_iam_policy.policy.arn
  role       = aws_iam_role.lambda_role.name
}

# data "archive_file" "souece_ec2_stop" {
#   type        = "zip"
#   source_file = "/workspaces/my-terraform-journey/modules_practice/ec2_create/ec2_stop.py"
#   output_path = "ec2_stop.zip"
# }

# resource "aws_lambda_function" "ec2_stop" {

#   filename      = "ec2_start-stop.zip"
#   function_name = "ec2_stop_auto"
#   role          = aws_iam_role.lambda_role.arn
#   handler       = "ec2_stop.lambda_handler"
#   timeout       = 60

#   source_code_hash = data.archive_file.souece_ec2_stop.output_base64sha256

#   runtime = "python3.9"

#   environment {
#     variables = {
#       REGION      = var.region
#       INSTANCE_ID = var.instance_id
#     }
#   }
# }




resource "aws_lambda_function" "ec2_start" {

  filename      = "lambda_function.zip"
  function_name = "ec2_start_auto"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  timeout       = 60



  source_code_hash = data.archive_file.source_ec2_start.output_base64sha256

  runtime = "python3.11"


  environment {
    variables = {
      DEFAULT_TAGS = "tag:Name=AutoStop"
    }
  }
}

# resource "aws_lambda_event_source_mapping" "tf_source" {
#   event_source_arn  = aws_cloudwatch_event_rule.stop_instances.arn
#   function_name     = aws_lambda_function.ec2_start.arn
#   starting_position = "LATEST"
# }




# resource "aws_scheduler_schedule" "tf_example" {
#   name       = "my-schedule"
#   group_name = "default"

#   flexible_time_window {
#     mode = "OFF"
#   }

#   schedule_expression = "cron(35 09 ? * MON-SUN *)"

#   target {
#     arn      = aws_lambda_function.ec2_start.arn
#     role_arn = aws_iam_role.lambda_role.arn
#   }
# }


resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEventBridgeFullAccess"
}

resource "aws_cloudwatch_event_rule" "stop_instances" {
  name                = "TF-StopInstance"
  description         = "Stop instances nightly"
  schedule_expression = "cron(55 18 ? * MON-SUN *)"
}

resource "aws_cloudwatch_event_target" "stop_instances" {
  target_id = "TF-StopInstance"
  arn       = aws_lambda_function.ec2_start.arn
  rule      = aws_cloudwatch_event_rule.stop_instances.name
  input = jsonencode({
    action = "stop"
  })

}

resource "aws_cloudwatch_event_rule" "start_instances" {
  name                = "TF-StartInstance"
  description         = "Start instances nightly"
  schedule_expression = "cron(50 18 ? * MON-SUN *)"
}

resource "aws_cloudwatch_event_target" "start_instances" {
  target_id = "TF-StartInstance"
  arn       = aws_lambda_function.ec2_start.arn
  rule      = aws_cloudwatch_event_rule.start_instances.name
  input = jsonencode({
    action = "start"
  })

}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "ec2_start_auto" #aws_lambda_function.ec2_start.function_name
  principal     = "events.amazonaws.com"
  source_arn    = "arn:aws:events:us-east-1:224761220970:rule/TF-StopInstance"
  #   qualifier     = aws_lambda_alias.test_alias.name

}

resource "aws_lambda_permission" "cloudwatch_allow" {
  statement_id  = "AllowExecutionFromCloudWatchEvents"
  action        = "lambda:InvokeFunction"
  function_name = "ec2_start_auto" #aws_lambda_function.ec2_start.function_name
  principal     = "events.amazonaws.com"
  source_arn    = "arn:aws:events:us-east-1:224761220970:rule/TF-StartInstance"
  #   qualifier     = aws_lambda_alias.test_alias.name

}
