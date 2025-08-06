#----------------------------------------------------------
# ECS cluster
#----------------------------------------------------------
resource "aws_ecs_cluster" "ecs_cluster_prod" {
  name = "${var.project_name}-${var.environment}-ecs-cluster-prod"
  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-cluster-prod"
    project     = var.project_name
    environment = var.environment
  }
}

#----------------------------------------------------------
# ECS task execution role
#----------------------------------------------------------
resource "aws_iam_role" "ecs_task_execution_role_prod" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-role-prod"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-task-execution-role-prod"
    project     = var.project_name
    environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_prod" {
  role       = aws_iam_role.ecs_task_execution_role_prod.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#----------------------------------------------------------
# ECS task role for execute command
#----------------------------------------------------------
resource "aws_iam_role" "ecs_task_role_prod" {
  name = "${var.project_name}-${var.environment}-ecs-task-role-prod"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-task-role-prod"
    project     = var.project_name
    environment = var.environment
  }
}

resource "aws_iam_role_policy" "ecs_task_role_policy_prod" {
  name = "${var.project_name}-${var.environment}-ecs-task-role-policy-prod"
  role = aws_iam_role.ecs_task_role_prod.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateSSMAgentStatus",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

#----------------------------------------------------------
# ECS task definition for Laravel application
#----------------------------------------------------------
resource "aws_ecs_task_definition" "laravel_app_task_prod" {
  family                   = "laravel-app-task-prod"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role_prod.arn
  task_role_arn            = aws_iam_role.ecs_task_role_prod.arn


  container_definitions = jsonencode([
    {
      name      = "laravel-app"
      image     = "181438959772.dkr.ecr.ap-northeast-1.amazonaws.com/nagoyameshi-${var.environment}-ecr-repository:latest"
      essential = true
      cpu       = 0
      command   = ["sh", "-c", "php artisan serve --host=0.0.0.0 --port=80"]
      portMappings = [
        {
          name          = "laravel-app"
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
      environment = [
        {
          name  = "APP_ENV"
          value = "production"
        },
        {
          name  = "DB_USERNAME"
          value = aws_db_instance.mysql_prod.username
        },
        {
          name  = "DB_PORT"
          value = "3306"
        },
        {
          name  = "DB_HOST"
          value = aws_db_instance.mysql_prod.address
        },
        {
          name  = "DB_CONNECTION"
          value = "mysql"
        },
        {
          name  = "APP_DEBUG"
          value = "false"
        },
        {
          name  = "DB_DATABASE"
          value = aws_db_instance.mysql_prod.db_name
        },
        {
          name  = "DB_PASSWORD"
          value = aws_db_instance.mysql_prod.password
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/laravel-app-prod"
          awslogs-create-group  = "true"
          awslogs-region        = "ap-northeast-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Name        = "${var.project_name}-${var.environment}-laravel-app-task"
  }
}

resource "aws_ecs_service" "ecs_service_prod" {
  name                   = "${var.project_name}-${var.environment}-ecs-service-prod"
  cluster                = aws_ecs_cluster.ecs_cluster_prod.id
  task_definition        = aws_ecs_task_definition.laravel_app_task_prod.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = [aws_subnet.public_subnet_prod_1a.id, aws_subnet.public_subnet_prod_1c.id]
    security_groups  = [aws_security_group.ecs_service_security_group_prod.id]
    assign_public_ip = true
  }

  # ALBとの連携を追加
  load_balancer {
    target_group_arn = aws_lb_target_group.alb_tg_prod_v2.arn
    container_name   = "laravel-app"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.alb_listener_prod_v2]
}

#----------------------------------------------------------
# ECR repository
#----------------------------------------------------------
resource "aws_ecr_repository" "ecr_repository_prod" {
  name                 = "${var.project_name}-${var.environment}-ecr-repository-prod"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecr-repository-prod"
    project     = var.project_name
    environment = var.environment
  }
}

#----------------------------------------------------------
# ECR lifecycle policy
#----------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "ecr_lifecycle_policy_prod" {
  repository = aws_ecr_repository.ecr_repository_prod.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep only the last 10 images",
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan",
          countNumber = 10
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}
