#################
## STORAGE
#################


data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_function"
  output_path = "${path.module}/lambda_function.zip"
}


resource "aws_s3_bucket" "lambda" {
  bucket = var.backend_s3_bucket_name
}

resource "aws_s3_bucket" "backend" {
  bucket = var.backend_s3_bucket_name_application
}

resource "aws_s3_object" "lambda_code" {
  bucket = aws_s3_bucket.lambda.id
  key    = var.backend_lambda_s3_object
  source = data.archive_file.lambda_zip.output_path
  etag = filemd5(data.archive_file.lambda_zip.output_path)
}

#################
## LAMBDA
#################
resource "aws_security_group" "lambda" {
  name   = "allow_labda_traffic"
  vpc_id = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_policy" "lambda" {
  name        = var.backend_lambda_name
  description = "IAM policy that allows a Lambda with the same name to work properly"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:Get*",
          "s3:List*",
          "s3:Put*"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.backend.arn,
          "${aws_s3_bucket.backend.arn}/*"
        ]
      },
    ]
  })
}

resource "aws_iam_role" "lambda" {
  name        = var.backend_lambda_name
  description = "IAM Role used by the AWS Lambda with the same name"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",     # Allow logging in CloudWatch
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole", # Allow Lambda attached to VPC
    aws_iam_policy.lambda.arn
  ]
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "AllowLambdaAssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}


resource "aws_lambda_function" "backend" {
  function_name = var.backend_lambda_name
  role          = aws_iam_role.lambda.arn
  architectures = [var.backend_lambda_architecture]
  handler       = var.backend_lambda_handler
  memory_size   = var.backend_lambda_memory_in_MB
  runtime       = var.backend_lambda_runtime
  timeout       = var.backend_lambda_timeout_in_seconds

  s3_bucket = aws_s3_bucket.lambda.id
  s3_key    = aws_s3_object.lambda_code.key
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  depends_on = [aws_s3_bucket.lambda]

  vpc_config {
    security_group_ids = [aws_security_group.lambda.id]
    subnet_ids = [
      aws_subnet.private[0].id,
      aws_subnet.private[1].id,
      aws_subnet.private[2].id,
    ]
  }

  environment {
    variables = {
      "DB_HOST"     = aws_db_instance.this.address
      "DB_PORT"     = var.database_port
      "DB_USER"     = var.database_master_username
      "DB_PASSWORD" = var.database_password
      "DB_NAME"     = var.database_name
    }
    # variables = merge(
    #   var.backend_lambda_environments_variables,
    #   {
    #     "DB_HOST" : "ABC" #aws_db_instance.this.address
    #   }
    # )
  }
}

resource "aws_lambda_permission" "apig_to_lambda" {
  depends_on = [
    aws_lambda_function.backend,
    aws_api_gateway_rest_api.this
  ]

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.backend_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${local.account_id}:${aws_api_gateway_rest_api.this.id}/*/*/*"
}

##################
### API GATEWAY
##################

resource "aws_api_gateway_rest_api" "this" {
  name        = var.backend_api_gateway_name
  description = "API Gateway that exposes the API deployed in a lambda"
}

resource "aws_api_gateway_resource" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.this.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "cors" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.this.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "root_any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_rest_api.this.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "root_any" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_rest_api.this.root_resource_id
  http_method             = aws_api_gateway_method.root_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.backend.invoke_arn
}

resource "aws_api_gateway_method_response" "cors" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this.id
  http_method = aws_api_gateway_method.cors.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

resource "aws_api_gateway_integration" "any" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.this.id
  http_method             = aws_api_gateway_method.any.http_method
  integration_http_method = "POST"

  type = "AWS_PROXY"
  uri  = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${var.aws_region}:${local.account_id}:function:${var.backend_lambda_name}/invocations"
}

resource "aws_api_gateway_integration" "cors" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.this.id
  http_method             = aws_api_gateway_method.cors.http_method
  integration_http_method = "OPTIONS"

  type = "AWS_PROXY"
  uri  = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${var.aws_region}:${local.account_id}:function:${var.backend_lambda_name}/invocations"
}

resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = "prod"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_deployment" "this" {
depends_on = [
    aws_api_gateway_integration.any,
    aws_api_gateway_integration.cors,
    aws_api_gateway_integration.root_any
  ]
  rest_api_id = aws_api_gateway_rest_api.this.id
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.this.id,
      aws_api_gateway_method.any.id,
      aws_api_gateway_method.cors.id,
      aws_api_gateway_method.root_any.id,
      aws_api_gateway_integration.any.id,
      aws_api_gateway_integration.cors.id,
      aws_api_gateway_integration.root_any.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

##################
### ROUTE 53 AND ACM
##################
resource "aws_acm_certificate" "backend" {
  provider = aws.virginia # This certificate MUST be created in us-east-1. Reference: https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-custom-domains.html

  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_domain_name" "this" {
  certificate_arn = aws_acm_certificate_validation.backend.certificate_arn
  domain_name     = local.backend_fqdn
}

resource "aws_api_gateway_base_path_mapping" "this" {
  api_id      = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  domain_name = aws_api_gateway_domain_name.this.domain_name
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.backend.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.zone_id
}

resource "aws_acm_certificate_validation" "backend" {
  provider                = aws.virginia
  certificate_arn         = aws_acm_certificate.backend.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}