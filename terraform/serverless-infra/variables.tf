##################################
### Common Parameters
##################################
variable "domain_name" {
  description = "The domain name of the application (e.g. mydomain.net)"
  type        = string
}

variable "aws_region" {
  description = "Region to deploy the resources."
  type        = string
  default     = "us-east-1"
}

##################################
### VPC Parameters
##################################
variable "network_ip" {
  description = "CIDR block of the VPC network"
  type        = string
  default     = "10.100.0.0"
}

##################################
### Frontend Parameters
##################################
variable "frontend_subdomain" {
  description = "Name of the subdomain of the frontend application. This means that if you se this value as 'app' and your domain is 'games.com', the FQDN will be 'app.games.com'"
  type        = string
}

variable "frontend_bucket_name" {
  description = "The name of the bucket that is gonna host the frontend website content"
  type        = string
}

variable "website_entry_document" {
  description = "Name of the entrypoint of the website"
  type        = string
  default     = "index.html"
}

variable "website_error_document" {
  description = "Name of the file that contains a user-friendly error message"
  type        = string
  default     = "index.html" // It's common to use "error.html"
}

##################################
### Database Parameters
##################################
variable "database_identifier" {
  description = "The name of the RDS instance that will be created. In other words, defines the name that will appear in the AWS console."
  type        = string
}

variable "database_requested_storage_in_GiB" {
  description = "The allocated storage in gibibytes (GiB)."
  type        = number
}

variable "database_max_storage_in_GiB" {
  description = "Maximium storage size that the storage can scale in gibibytes (GiB). If not set or set to zero, the autoscaling of the storage will be disabled"
  type        = number
  default     = 0
}

variable "database_name" {
  description = "The name of the database to create when the DB instance is created."
  type        = string
}

variable "database_engine" {
  description = "The version of the engine"
  type        = string
  default     = "mysql"
}

variable "database_engine_version" {
  description = "The version of the engine that you are going to use. You can specify only the major and minor versions. Use the AWS CLI in order to get all engine versions available `aws rds aws rds describe-db-engine-versions --engine mysql`"
  type        = string
}

variable "database_password" {
  description = "Password of the database"
  type        = string
}

variable "database_master_username" {
  description = "Name of the master username of the database"
  type        = string
  default     = "root"
}

variable "database_instance_class" {
  description = "Name of the instance class used to run the database. You can check all the available instances and compare all of them using https://instances.vantage.sh/rds/"
  type        = string
}

variable "database_port" {
  description = "The port on which the DB accepts connections."
  type        = number
  default     = 3306
}

##################################
### Backend Parameters
##################################
variable "backend_subdomain" {
  description = "Name of the subdomain of the backend application. This means that if you se this value as 'api' and your domain is 'games.com', the FQDN will be 'api.games.com'"
  type        = string
}

variable "backend_s3_bucket_name_application" {
  description = "Name of the S3 bucket that the backend will store data."
  type        = string
}


variable "backend_s3_bucket_name" {
  description = "Name of the S3 bucket that will store the code of the AWS Lambda. This bucket will be populated by the CI of the backend repository"
  type        = string
}

variable "backend_lambda_name" {
  description = "Name of the AWS Lambda that will run the backend code"
  type        = string
}

variable "backend_lambda_architecture" {
  description = "Architecture used to run the code. It accepts the following values: x86_64 or arm64. Keep in mind that the arm64 is cheaper than x86_64"
  type        = string
  default     = "arm64"
}

variable "backend_lambda_s3_object" {
  description = "Name of the zipped code object in the 'backend_s3_bucket_name' bucket"
  type        = string
}

variable "backend_lambda_handler" {
  description = "Function entrypoint in your code"
  type        = string
  default     = "lambda_function/index.handler"
}

variable "backend_lambda_memory_in_MB" {
  description = "Amount of memory in MB that your Lambda Function will use. Remember that you do not configure CPU in a Lambda, if you need more CPU, please you need to increase the Memory since CPU scale with memory in Lambda."
  type        = number
  default     = 128
}

variable "backend_lambda_runtime" {
  description = "Function's runtime. You can check available values in https://docs.aws.amazon.com/lambda/latest/dg/API_CreateFunction.html#API_CreateFunction_RequestSyntax"
  type        = string
  default     = "nodejs16.x"
}

variable "backend_lambda_timeout_in_seconds" {
  description = "Maximum amount of time that the Lambda has to return a response."
  type        = number
  default     = 3
}

variable "backend_lambda_environments_variables" {
  description = "A key-value pair corresponding to the environment variables that the function needs to run."
  type        = map(string)
  default     = {}
}

variable "backend_api_gateway_name" {
  description = "Name of the API Gateway to create"
  type        = string
}
