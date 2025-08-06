#----------------------------------------------------------
# Application Load Balancer
#----------------------------------------------------------
resource "aws_lb" "alb_prod_v2" {
  name               = "nagoyameshi-prod-alb-v2"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg_prod.id]
  subnets            = [aws_subnet.public_subnet_prod_1a.id, aws_subnet.public_subnet_prod_1c.id]

  enable_deletion_protection = true

  tags = {
    Name        = "nagoyameshi-prod-alb-v2"
    project     = var.project_name
    environment = var.environment
  }
}

#----------------------------------------------------------
# Target Group
#----------------------------------------------------------
resource "aws_lb_target_group" "alb_tg_prod_v2" {
  name        = "nagoyameshi-prod-tg-v2-new"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc_prod.id
  target_type = "ip" # Fargate用にIPターゲットタイプを指定

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "nagoyameshi-prod-tg-v2"
    project     = var.project_name
    environment = var.environment
  }
}

#----------------------------------------------------------
# ALB Listener (HTTP)
#----------------------------------------------------------
resource "aws_lb_listener" "alb_listener_prod_v2" {
  load_balancer_arn = aws_lb.alb_prod_v2.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg_prod_v2.arn
  }
}

#----------------------------------------------------------
# ECS Auto Scaling Target
#----------------------------------------------------------
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster_prod.name}/${aws_ecs_service.ecs_service_prod.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

#----------------------------------------------------------
# ECS Auto Scaling Policy (CPU)
#----------------------------------------------------------
resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  name               = "nagoyameshi-prod-ecs-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

#----------------------------------------------------------
# ECS Auto Scaling Policy (Memory)
#----------------------------------------------------------
resource "aws_appautoscaling_policy" "ecs_memory_policy" {
  name               = "nagoyameshi-prod-ecs-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
} 