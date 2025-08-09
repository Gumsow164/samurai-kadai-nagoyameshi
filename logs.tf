#----------------------------------------------------------
# CloudWatch Logs - ECS application logs
#----------------------------------------------------------
resource "aws_cloudwatch_log_group" "laravel_app_logs" {
  name              = "/ecs/laravel-app-${var.environment}"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-${var.environment}-laravel-app-logs"
    project     = var.project_name
    environment = var.environment
  }
}
