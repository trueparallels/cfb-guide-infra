locals {
  task_path = "${path.module}/tasks/backend.json"
  policy_path = "${path.module}/policies/task_execution_role_policy.json"
  allowed_actions_path = "${path.module}/policies/allowed_actions_policy.json"
}

resource "aws_ecs_cluster" "cfb-guide-graphql-cluster" {
  name = "cfb-guide-graphql-cluster"
}

resource "aws_ecs_service" "cfb-guide-graphql-service" {
  name = "cfb-guide-graphql-service"
  desired_count = 1
  launch_type = "FARGATE"
  cluster = aws_ecs_cluster.cfb-guide-graphql-cluster.arn
  task_definition = aws_ecs_task_definition.cfb-guide-graphql-task.arn

  network_configuration {
    assign_public_ip = true
    subnets = ["${var.cfb-guide_subnet_id}"]
    security_groups = ["${var.cfb-guide-security_group_id}"]
  }

  lifecycle {
    # create_before_destroy = true
    ignore_changes = [task_definition]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.cfb-guide-graphql-lb-target-group.arn
    container_name = "cfb-guide-graphql"
    container_port = 80
  }
}

resource aws_ecr_repository "cfb-guide-ecr-repo" {
  name = "cfb-guide-image-repo"
}

resource "aws_iam_policy" "cfb-guide-ecs_task_execution_role_policy" {
  name = "cfb-guide-ecs_task_execution_role_policy"
  policy = file(local.allowed_actions_path)
}

resource "aws_iam_role" "cfb-guide-ecs_task_execution_role" {
  name = "cfb-guide-ecs_task_execution_role"
  assume_role_policy = file(local.policy_path)
}

resource "aws_iam_policy_attachment" "ecs_policy_attachment" {
  name = "ecs_policy_attachment"
  policy_arn = aws_iam_policy.cfb-guide-ecs_task_execution_role_policy.arn
  roles = ["${aws_iam_role.cfb-guide-ecs_task_execution_role.name}"]
}

resource "aws_ecs_task_definition" "cfb-guide-graphql-task" {
  family = "cfb-guide-graphql-family"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = 256
  memory = 512

  container_definitions = templatefile(local.task_path, {
    image = "${aws_ecr_repository.cfb-guide-ecr-repo.repository_url}"
    log_group = "${var.cloudwatch_log_group}"
    log_region = "${var.cloudwatch_log_region}"
  })
  
  execution_role_arn = aws_iam_role.cfb-guide-ecs_task_execution_role.arn
  task_role_arn = aws_iam_role.cfb-guide-ecs_task_execution_role.arn
}

resource aws_alb "cfb-guide-graphql-alb" {
  name = "cfb-guide-graphql-alb"
  security_groups = [var.cfb-guide-security_group_id]

  subnets = [var.cfb-guide_subnet_id, var.cfb-guide_subnet_two_id]
}

resource aws_lb_target_group "cfb-guide-graphql-lb-target-group" {
  name = "cfb-guide-graphql-lb-target"
  port = 80
  protocol = "HTTP"
  vpc_id = var.cfb-guide-vpc_id
  target_type = "ip"

  health_check {
    path = "/ok"
    interval = 60
    timeout = 30
  }
}

resource aws_lb_listener "cfb-guide-graphql-alb-listener" {
  load_balancer_arn = aws_alb.cfb-guide-graphql-alb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.cfb-guide-graphql-lb-target-group.arn
  }
}