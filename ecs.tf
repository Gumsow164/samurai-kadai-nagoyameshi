#----------------------------------------------------------
# ECS cluster
#----------------------------------------------------------
resource "aws_ecs_cluster" "ecs_cluster_dev" {
  name = "${var.project_name}-${var.environment}-ecs-cluster-dev"
  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-cluster-dev"
    project     = var.project_name
    environment = var.environment
  }
  configuration {
    execute_command_configuration {
      logging = "DEFAULT"
    }
  }
}
#----------------------------------------------------------
# ECS task execution role
#----------------------------------------------------------
resource "aws_iam_role" "ecs_task_execution_role_dev" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-role-dev"

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
    Name        = "${var.project_name}-${var.environment}-ecs-task-execution-role-dev"
    project     = var.project_name
    environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_dev" {
  role       = aws_iam_role.ecs_task_execution_role_dev.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# タスク実行ロールにAmazonSSMManagedInstanceCoreを追加
resource "aws_iam_role_policy_attachment" "ecs_ssm_managed_instance_core_dev" {
  role       = aws_iam_role.ecs_task_execution_role_dev.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CodePipelineからのECSデプロイ権限を追加
resource "aws_iam_role_policy" "ecs_task_execution_codepipeline_policy" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-codepipeline-policy"
  role = aws_iam_role.ecs_task_execution_role_dev.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_task_execution_role_dev.arn,
          aws_iam_role.ecs_task_role_dev.arn
        ]
      }
    ]
  })
}

#----------------------------------------------------------
# ECS task role for execute command
#----------------------------------------------------------
resource "aws_iam_role" "ecs_task_role_dev" {
  name = "${var.project_name}-${var.environment}-ecs-task-role-dev"

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
    Name        = "${var.project_name}-${var.environment}-ecs-task-role-dev"
    project     = var.project_name
    environment = var.environment
  }
}

resource "aws_iam_role_policy" "ecs_task_role_policy_dev" {
  name = "${var.project_name}-${var.environment}-ecs-task-role-policy-dev"
  role = aws_iam_role.ecs_task_role_dev.id

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
resource "aws_ecs_task_definition" "laravel_app_task_dev" {
  family                   = "aa-laravel-app-task-dev-neo"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role_dev.arn
  task_role_arn            = aws_iam_role.ecs_task_role_dev.arn


  container_definitions = jsonencode([
    {
      name      = "laravel-app"
      image     = "${aws_ecr_repository.ecr_repository_dev.repository_url}:latest"
      essential = true
      cpu       = 0
      command   = ["sh", "-c", "php artisan serve --host=0.0.0.0 --port=80"]
      linuxParameters = {
        initProcessEnabled = true
      }
      interactive    = true
      pseudoTerminal = true
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
          value = aws_db_instance.mysql_dev.username
        },
        {
          name  = "DB_PORT"
          value = "3306"
        },
        {
          name  = "DB_HOST"
          value = "nagoyameshi-dev-mysql-dev.cdgeew22q4ur.ap-northeast-1.rds.amazonaws.com"
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
          value = "nagoyameshi_db"
        },
        {
          name  = "DB_PASSWORD"
          value = aws_db_instance.mysql_dev.password
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/laravel-app-${var.environment}"
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

resource "aws_ecs_service" "ecs_service_dev" {
  name                   = "aa-laravel-app-task-dev-neo-service-hx2wa01b"
  cluster                = aws_ecs_cluster.ecs_cluster_dev.id
  task_definition        = aws_ecs_task_definition.laravel_app_task_dev.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = [aws_subnet.private_subnet_dev_1a.id, aws_subnet.private_subnet_dev_1c.id]
    security_groups  = [aws_security_group.ecs_service_security_group_dev.id]
    assign_public_ip = false
  }

  # ALBとの連携を追加
  load_balancer {
    target_group_arn = aws_lb_target_group.alb_tg_dev_v2.arn
    container_name   = "laravel-app"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.alb_listener_dev_v2]
}

#----------------------------------------------------------
# ECR repository
#----------------------------------------------------------
resource "aws_ecr_repository" "ecr_repository_dev" {
  name                 = "${var.project_name}-${var.environment}-ecr-repository-dev"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecr-repository-dev"
    project     = var.project_name
    environment = var.environment
  }
}

#----------------------------------------------------------
# ECR lifecycle policy
#----------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "ecr_lifecycle_policy_dev" {
  repository = aws_ecr_repository.ecr_repository_dev.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep only the last 10 images",
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}

#----------------------------------------------------------
# CodePipeline IAM Role
#----------------------------------------------------------
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project_name}-${var.environment}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-codepipeline-role"
    project     = var.project_name
    environment = var.environment
  }
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.project_name}-${var.environment}-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::codepipeline-*",
          "arn:aws:s3:::codepipeline-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "ecs:RunTask",
          "ecs:StopTask"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_task_execution_role_dev.arn,
          aws_iam_role.ecs_task_role_dev.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}
