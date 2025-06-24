resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "MainVPC"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "MainIGW"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Subnet1"
  }
}
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Subnet2"
  }
}
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route_table_association" "subnet1_assoc" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "subnet2_assoc" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "allow_api" {
  name        = "allow_api"
  description = "Allow API ports"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "myAPIserver1" {
  ami                    = "ami-0e58b56aa4d64231b"
  instance_type          = "t2.micro"
  key_name               = "windowsKP1"
  subnet_id              = aws_subnet.subnet1.id
  vpc_security_group_ids = [aws_security_group.allow_api.id]

  user_data = <<-EOF
            #!/bin/bash
            sudo yum update -y
            sudo yum install -y python3
            sudo pip3 install flask pyjwt
            sudo yum install -y docker
            sudo amazon-linux-extras install docker -y
            sudo service docker start
            sudo usermod -a -G docker ec2-user
            sudo docker login -u asobina -p YOUR_DOCKER_HUB_PASSWORD
            sudo docker pull asobina/first-python-app:v1.0.3
            sudo docker run -d -p 5000:5000 asobina/first-python-app:v1.0.3
            EOF

  tags = {
    Name = "myAPIserver1"
  }
}

resource "aws_instance" "myAPIserver2" {
  ami                    = "ami-0e58b56aa4d64231b"
  instance_type          = "t2.micro"
  key_name               = "windowsKP1"
  subnet_id              = aws_subnet.subnet2.id
  vpc_security_group_ids = [aws_security_group.allow_api.id]

  user_data = <<-EOF
            #!/bin/bash
            sudo yum update -y
            sudo yum install -y python3
            sudo pip3 install flask pyjwt
            sudo yum install -y docker
            sudo amazon-linux-extras install docker -y
            sudo service docker start
            sudo usermod -a -G docker ec2-user
            sudo docker login -u asobina -p YOUR_DOCKER_HUB_PASSWORD
            sudo docker pull asobina/first123-python-app:v1.0.3
            sudo docker run -d -p 5000:5000 asobina/first123-python-app:v1.0.3
            EOF
  tags = {
    Name = "myAPIserver2"
  }
}

resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_api.id]
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
}

resource "aws_lb_target_group" "api_tg" {
  name     = "api-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "server1_attach" {
  target_group_arn = aws_lb_target_group.api_tg.arn
  target_id        = aws_instance.myAPIserver1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "server2_attach" {
  target_group_arn = aws_lb_target_group.api_tg.arn
  target_id        = aws_instance.myAPIserver2.id
  port             = 80
}



resource "aws_api_gateway_rest_api" "rest_api" {
  name        = var.api_gateway_name
  description = "REST API with Lambda backend and JWT auth"
}

resource "aws_api_gateway_resource" "secure_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "secure"
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda-authorizer-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda-logging-policy"
  description = "Allow Lambda to write logs to CloudWatch"
  policy = jsonencode({ Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logging_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_lambda_function" "jwt_auth" {
  filename         = "../lambda/auth.zip"
  function_name    = "mylambda12"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.13"
  source_code_hash = filebase64sha256("../lambda/auth.zip")
  environment {
    variables = {
      JWT_SECRET = "mysecretkey"
    }
  }
}

resource "aws_lambda_function" "backend" {
  filename         = "../lambda/backend.zip"
  function_name    = "backendApp"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.13"
  source_code_hash = filebase64sha256("../lambda/backend.zip")
}

resource "aws_api_gateway_authorizer" "jwt_auth" {
  name                   = "JWTAuthorizer"
  rest_api_id            = aws_api_gateway_rest_api.rest_api.id
  authorizer_uri         = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.jwt_auth.arn}/invocations"
  authorizer_credentials = aws_iam_role.lambda_exec.arn
  identity_source        = "method.request.header.Authorization"
  type                   = "TOKEN"
}
#get
resource "aws_api_gateway_method" "secure_get_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.secure_resource.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt_auth.id
}

resource "aws_api_gateway_integration" "secure_get_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.secure_resource.id
  http_method             = aws_api_gateway_method.secure_get_method.http_method
  integration_http_method = "POST" # Still POST because Lambda Proxy integration uses POST
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.backend.invoke_arn
}



# post
resource "aws_api_gateway_method" "secure_post_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.secure_resource.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt_auth.id
}

resource "aws_api_gateway_integration" "secure_post_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.secure_resource.id
  http_method             = aws_api_gateway_method.secure_post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.backend.invoke_arn
}



resource "aws_api_gateway_deployment" "api_deploy" {
  depends_on = [
    aws_api_gateway_integration.secure_post_lambda,
    aws_api_gateway_integration.secure_get_lambda
  ]
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod_stage" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  deployment_id = aws_api_gateway_deployment.api_deploy.id
  stage_name    = "prod"
}

resource "aws_lambda_permission" "auth_api_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jwt_auth.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "backend_api_permission" {
  statement_id  = "AllowExecutionFromAPIGatewayBackend"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/*"
}

# Route 53 DNS Setup (no ACM, HTTP only)
resource "aws_route53_zone" "dns_zone" {
  name = "devopsasodomain.xyz"
}

resource "aws_route53_record" "alb_dns" {
  zone_id = aws_route53_zone.dns_zone.zone_id
  name    = "devopsasodomain.xyz"
  type    = "A"

  alias {
    name                   = aws_lb.web_alb.dns_name
    zone_id                = aws_lb.web_alb.zone_id
    evaluate_target_health = true
  }
}