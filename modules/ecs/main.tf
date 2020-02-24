resource "aws_ecs_cluster" "cfb-guide-graphql-cluster" {
    name = "cfb-guide-graphql-cluster"
}

resource "aws_ecs_service" "cfb-guide-graphql-service" {
    name = "cfb-guide-graphql-service"
    desired_count = 1
    launch_type = "FARGATE"
    cluster = "aws_ecs_cluster.cfb-guide-graphql-cluster.arn"
    task_definition = "aws_ecs_task_definition.cfb-guide-graphql-task.arn"

}

resource aws_ecr_repository "cfb-guide-ecr-repo" {
  name = "cfb-guide-image-repo"
}

resource "aws_ecs_task_definition" "cfb-guide-graphql-task" {
    family = "cfb-guide-graphql-family"
    requires_compatibilities = ["FARGATE"]

    container_definitions = templatefile("${path.module}/tasks/backend.json", {
      image = "${aws_ecr_repository.cfb-guide-ecr-repo.repository_url}"
      log_group = "${var.cloudwatch_log_group}"
      log_region = "${var.cloudwatch_log_region}"
    })
    
}