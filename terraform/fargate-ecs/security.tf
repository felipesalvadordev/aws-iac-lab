# security.tf

# ALB security Group: Edit to restrict access to the application
resource "aws_security_group" "lb" {
    name        = "cb-load-balancer-security-group"
    description = "Controls public access to the ALB"
    vpc_id      = aws_vpc.main.id

    ingress {
        protocol    = "tcp"
        from_port   = var.app_port
        to_port     = var.app_port
        cidr_blocks = ["0.0.0.0/0"] # Open to the world, cause is public
    }

    egress {
        protocol    = "-1"
        from_port   = 0
        to_port     = 0
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Traffic to the ECS cluster should only come from the ALB
resource "aws_security_group" "ecs_tasks" {
    name        = "cb-ecs-tasks-security-group"
    description = "Allow inbound access exclusively from the ALB"
    vpc_id      = aws_vpc.main.id

    ingress {
        protocol        = "tcp"
        from_port       = var.app_port
        to_port         = var.app_port
        security_groups = [aws_security_group.lb.id] # Allows only ALB traffic
    }

    egress {
        protocol    = "-1"
        from_port   = 0
        to_port     = 0
        cidr_blocks = ["0.0.0.0/0"] # It allows tasks to download images, use SSM, call APIs, etc.
    }
}
