#----------------------------------------------------------
# Application Load Balancer
#----------------------------------------------------------
resource "aws_lb" "alb_dev" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg_dev.id]
  subnets            = [aws_subnet.public_subnet_dev_1a.id, aws_subnet.public_subnet_dev_1c.id]

  enable_deletion_protection = false

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb"
    project     = var.project_name
    environment = var.environment
  }
}

#----------------------------------------------------------
# ALB Target Group
#----------------------------------------------------------
resource "aws_lb_target_group" "alb_tg_dev_v2" {
  name        = "${var.project_name}-${var.environment}-tg-v2"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc_dev.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-399"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-tg-v2"
    project     = var.project_name
    environment = var.environment
  }
}

#----------------------------------------------------------
# ALB Listener (HTTP)
#----------------------------------------------------------
resource "aws_lb_listener" "alb_listener_dev_v2" {
  load_balancer_arn = aws_lb.alb_dev.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-listener"
    project     = var.project_name
    environment = var.environment
  }
}

#----------------------------------------------------------
# ALB Listener (HTTPS)
#----------------------------------------------------------
resource "aws_lb_listener" "alb_listener_https" {
  load_balancer_arn = aws_lb.alb_dev.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = "arn:aws:acm:ap-northeast-1:181438959772:certificate/5670403c-d1e2-4f88-845e-051baa7fc811"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg_dev_v2.arn
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-listener-https"
    project     = var.project_name
    environment = var.environment
  }
} 