provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
}

terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "trueparallels"

    workspaces {
      name = "cfb-guide-prod"
    }
  }
}

resource "aws_vpc" "cfb-guide-vpc" {
  cidr_block = "172.33.0.0/16"

  tags = {
    Name = "cfb-guide-vpc"
  }
}

resource "aws_dynamodb_table" "cfb-guide-prod-teams" {
  name = "cfb-guide-prod-teams"
  billing_mode = "PROVISIONED"

  read_capacity = 5
  write_capacity = 5

  hash_key = "id"

  attribute {
    name = "id"
    type = "N"
  }

  tags = {
      Group = "cfb-guide-prod"
  }
}

resource "aws_dynamodb_table" "cfb-guide-prod-leagues" {
  name = "cfb-guide-prod-leagues"
  billing_mode = "PROVISIONED"

  read_capacity = 5
  write_capacity = 5

  hash_key = "id"

  attribute {
    name = "id"
    type = "N"
  }
}

resource "aws_dynamodb_table" "cfb-guide-prod-games" {
  name = "cfb-guide-prod-games"
  billing_mode = "PROVISIONED"

  read_capacity = 5
  write_capacity = 5

  hash_key = "game_week_year"
  range_key = "game_id"

  attribute {
    name = "game_week_year"
    type = "S"
  }

  attribute {
    name = "game_id"
    type = "S"
  }
}

resource "aws_s3_bucket" "cfb-guide-prod-s3-bucket" {
  bucket = "cfb-guide-prod"
  acl = "public-read"

  website {
    index_document = "index.html"
  }

  tags = {
    Name = "cfb-guide-prod"
  }
}

