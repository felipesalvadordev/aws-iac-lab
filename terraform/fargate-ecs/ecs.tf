resource "aws_ecs_cluster" "main" {
    name = "cb-cluster"
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_ecs_task_definition" "app" {
    family                   = "cb-app-task"
    execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
    network_mode             = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    cpu                      = var.fargate_cpu
    memory                   = var.fargate_memory
    container_definitions = jsonencode([
    {
      name      = "cb-app"
      image     = var.app_image,
      essential = true
      cpu       = var.fargate_cpu,
      memory    = var.fargate_memory
      portMappings = [
        {
          containerPort = var.app_port,
          hostPort      = var.app_port,
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "ecs_service" {
    name            = "cb-service"
    cluster         = aws_ecs_cluster.main.id
    task_definition = aws_ecs_task_definition.app.arn
    desired_count   = var.app_count

    network_configuration {
        security_groups  = [aws_security_group.ecs_tasks.id]
        subnets          = aws_subnet.private.*.id
        assign_public_ip = true
    }

    load_balancer {
        target_group_arn = aws_alb_target_group.app.id
        container_name   = "cb-app"
        container_port   = var.app_port
    }

    capacity_provider_strategy {
        capacity_provider = "FARGATE"
        weight            = 0
        base              = 1 # Ensure at least 1 task runs on FARGATE
    }

    capacity_provider_strategy {
        capacity_provider = "FARGATE_SPOT"
        weight            = 1 # Use FARGATE_SPOT for additional tasks when scaling up
    }

    depends_on = [aws_alb_listener.front_end, aws_iam_role_policy_attachment.ecs-task-execution-role-policy-attachment]
}