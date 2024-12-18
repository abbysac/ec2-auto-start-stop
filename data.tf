data "archive_file" "source_ec2_start" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}