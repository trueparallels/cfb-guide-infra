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

resource aws_subnet "cfb-guide-subnet-one" {
  vpc_id = aws_vpc.cfb-guide-vpc.id
  cidr_block = "172.33.0.0/20"

  tags = {
    Name = "cfb-guide-subnet-one"
  }
}

resource aws_subnet "cfb-guide-subnet-two" {
  vpc_id = aws_vpc.cfb-guide-vpc.id
  cidr_block = "172.33.96.0/20"
  availability_zone = "us-east-1d"

  tags = {
    Name = "cfb-guide-subnet-two"
  }
}

resource "aws_security_group" "cfb-guide_allow-http-traffic" {
  name = "cfb-guide_allow-http-traffic"
  vpc_id = aws_vpc.cfb-guide-vpc.id
  description = "Allow HTTP Traffic for CFBTV Guide"

  ingress {
    from_port = 80
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
  }

  ingress {
    from_port = 443
    to_port = 443
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
  }

  ingress {
    from_port = 3003
    to_port = 3003
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "-1"
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

resource "aws_s3_bucket" "cfb-guide-staging-s3-bucket" {
  bucket = "cfb-guide-staging"
  acl = "public-read"

  website {
    index_document = "index.html"
  }

  tags = {
    Name = "cfb-guide-staging"
  }
}

resource "aws_route53_zone" "cfb-guide-zone" {
  name = "cfbtv.guide"
}

resource "aws_cloudfront_distribution" "distro" {
  enabled = true
  default_root_object = "index.html"

  origin {

    domain_name = "cfb-guide-prod.s3-website-us-east-1.amazonaws.com"
    origin_id   = "cfb-guide-prod-s3-origin"

    # s3_origin_config {
    #   origin_access_identity = "origin-access-identity/cloudfront/E2WUGTWGEWYPC0"
    # }

    custom_origin_config {
      http_port = 80
      https_port = 443

      origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]

      origin_protocol_policy = "http-only"
    }
  }

  aliases = ["cfbtv.guide"]

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cfb-guide-cert.arn
    ssl_support_method = "sni-only"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "cfb-guide-prod-s3-origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    default_ttl = 3600

    viewer_protocol_policy = "redirect-to-https"
  }

  tags = {
    Environment = "prod"
  }
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "shrug"
}

resource "aws_route53_record" "cfb-guide-domain-record" {
  zone_id = aws_route53_zone.cfb-guide-zone.zone_id
  name = "cfbtv.guide"
  type = "A"

  alias {
    name = aws_cloudfront_distribution.distro.domain_name
    zone_id = aws_cloudfront_distribution.distro.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate" "cfb-guide-cert" {
  domain_name = "cfbtv.guide"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "cfb-guide-graphql-logs" {
  name = "CFBGuideGraphQL"
}

resource aws_internet_gateway "cfb-guide_igw" {
  vpc_id = aws_vpc.cfb-guide-vpc.id

  tags = {
    Name = "cfb-guide_igw"
  }
}

resource aws_route_table "cfb-guide-route-table" {
  vpc_id = aws_vpc.cfb-guide-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cfb-guide_igw.id
  }
}

resource aws_route_table_association "cfb-guide-route-table-assoc" {
  subnet_id = aws_subnet.cfb-guide-subnet-one.id
  route_table_id = aws_route_table.cfb-guide-route-table.id
}

module "ecs" {
  source = "./modules/ecs"

  cloudwatch_log_group = aws_cloudwatch_log_group.cfb-guide-graphql-logs.name
  cloudwatch_log_region = var.region
  cfb-guide_subnet_id = aws_subnet.cfb-guide-subnet-one.id
  cfb-guide_subnet_two_id = aws_subnet.cfb-guide-subnet-two.id
  cfb-guide-security_group_id = aws_security_group.cfb-guide_allow-http-traffic.id
  cfb-guide-vpc_id = aws_vpc.cfb-guide-vpc.id
}