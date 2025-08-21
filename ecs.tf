#----------------------------------------------------------
# ECS cluster
#----------------------------------------------------------
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.project_name}-${var.environment}-ecs-cluster"
  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-cluster"
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
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-role"

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
    Name        = "${var.project_name}-${var.environment}-ecs-task-execution-role"
    project     = var.project_name
    environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# タスク実行ロールにAmazonSSMManagedInstanceCoreを追加
resource "aws_iam_role_policy_attachment" "ecs_ssm_managed_instance_core" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CodePipelineからのECSデプロイ権限を追加
resource "aws_iam_role_policy" "ecs_task_execution_codepipeline_policy" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-codepipeline-policy"
  role = aws_iam_role.ecs_task_execution_role.id

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
          aws_iam_role.ecs_task_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      }
    ]
  })
}

#----------------------------------------------------------
# ECS task role for execute command
#----------------------------------------------------------
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-${var.environment}-ecs-task-role"

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
    Name        = "${var.project_name}-${var.environment}-ecs-task-role"
    project     = var.project_name
    environment = var.environment
  }
}

resource "aws_iam_role_policy" "ecs_task_role_policy" {
  name = "${var.project_name}-${var.environment}-ecs-task-role-policy"
  role = aws_iam_role.ecs_task_role.id

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
resource "aws_ecs_task_definition" "laravel_app_task" {
  family                   = "aa-laravel-app-task-prod-neo"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn


  container_definitions = jsonencode([
    {
      name      = "laravel-app"
      image     = "181438959772.dkr.ecr.ap-northeast-1.amazonaws.com/nagoyameshi-dev-01-ecr-repository-dev:latest"
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
          value = aws_db_instance.mysql.username
        },
        {
          name  = "DB_PORT"
          value = "3306"
        },
        {
          name  = "DB_HOST"
          value = aws_db_instance.mysql.endpoint
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
          value = aws_db_instance.mysql.password
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
    Name        = "${var.project_name}-${var.environment}-laravel-app-task-prod"
  }
}

resource "aws_ecs_service" "ecs_service" {
  name                   = "aa-laravel-app-task-prod-neo-service-hx2wa01b"
  cluster                = aws_ecs_cluster.ecs_cluster.id
  task_definition        = aws_ecs_task_definition.laravel_app_task.arn
  desired_count          = 2
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = [aws_subnet.private_subnet_1a.id, aws_subnet.private_subnet_1c.id]
    security_groups  = [aws_security_group.ecs_service_security_group.id]
    assign_public_ip = false
  }

  # ALBとの連携を追加
  load_balancer {
    target_group_arn = aws_lb_target_group.alb_tg_v2.arn
    container_name   = "laravel-app"
    container_port   =80
  }

  depends_on = [aws_lb_listener.alb_listener_v2]

  # Auto Scaling設定
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
}

#----------------------------------------------------------
# ECS Auto Scaling
#----------------------------------------------------------
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy" {
  name               = "${var.project_name}-${var.environment}-ecs-autoscaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
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
          aws_iam_role.ecs_task_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
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
