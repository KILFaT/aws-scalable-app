variable "access_key" {
  
}

variable "secret_key" {
  
}

variable "region" {
  default = "eu-central-1"
}

provider "aws" {
  region="eu-central-1"
  shared_credentials_file = ".aws/credentials"
  profile = "kilfat_profile"
}

# LaunchConfiguration
resource "aws_launch_configuration" "primary" {
  depends_on = ["aws_subnet.primary", "aws_nat_gateway.gw"]
  name          = "web_config_primary"
  image_id      = "ami-030aae8cba933aede"
  instance_type = "${var.ami_type}"
  security_groups = ["${aws_security_group.primary.id}"]
  user_data = 
  <<-EOF
  #!/bin/bash
  # curl https://omnitruck.chef.io/install.sh | sudo bash -s -- -P chefdk -c stable -v 2.5.3
  # mkdir chef-repo
  # cd chef-repo
  curl https://raw.githubusercontent.com/KILFaT/aws-scalable-app/master/serv.py -O
  # sudo chef-client --local-mode webserver.rb
  python serv.py
  # python -m http.server 80
  EOF

  key_name               = "${var.key_name}"
}

# SecurityGroup ELB
resource "aws_security_group" "primary" {
  name        = "${var.primary_sg}"
  description = "${var.primary_sg_desc}"
  vpc_id = "${aws_vpc.vpc.id}"
  depends_on = ["aws_internet_gateway.gw"]
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  tags {
    Name = "${var.primary_sg}"
  }
}

resource "aws_vpc" "vpc" {
    cidr_block = "${var.vpc_ip}"
    enable_dns_hostnames = true
    tags {
        Name = "${var.vpc_name}"
    }
}

resource "aws_autoscaling_group" "asgPrimary" {
  depends_on = ["aws_launch_configuration.primary"]
  availability_zones        = ["${data.aws_availability_zones.available.names[0]}"]
  name                      = "TerraformASGPrimary"
  max_size                  = 2
  min_size                  = 1
  wait_for_capacity_timeout = "0"
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = false
  wait_for_capacity_timeout = "0"
  vpc_zone_identifier = ["${aws_subnet.primary.id}"]
  launch_configuration      = "${aws_launch_configuration.primary.name}"
  load_balancers = ["${aws_elb.elb.name}"]
}

resource "aws_subnet" "private_primary" {
  depends_on = ["aws_subnet.primary"]
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.private_subnet_cidr}"
  map_public_ip_on_launch = "${var.private_ip_bool}"
  tags {
    Name = "Private Main"
  }
}


resource "aws_subnet" "primary" {
  depends_on = ["aws_route_table.rt"]
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.public_subnet_cidr}"
  map_public_ip_on_launch = "${var.public_ip_bool}"
  tags {
    Name = "Main"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = "${aws_vpc.vpc.id}"
  depends_on = ["aws_internet_gateway.gw"]
  route {
    cidr_block = "${var.route_table_cidr}"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags {
    Name = "${var.route_table_name}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.vpc.id}"
  depends_on = ["aws_vpc.vpc"]
  tags {
    Name = "${var.gateway_name}"
  }
}

resource "aws_nat_gateway" "gw" {
  depends_on = ["aws_eip.nat", "aws_subnet.primary", "aws_internet_gateway.gw"]
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${aws_subnet.primary.id}"
}

resource "aws_eip" "nat" {
  vpc = true
  lifecycle {
    create_before_destroy = true
  }
  depends_on = ["aws_subnet.primary", "aws_internet_gateway.gw"]
}

resource "aws_elb" "elb" {
  depends_on = ["aws_subnet.primary", "aws_subnet.secondary", "aws_nat_gateway.gw"]
  name               = "ELB"
  security_groups = ["${aws_security_group.sg-elb.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 30
    target              = "HTTP:80/"
    interval            = 60
  }

  subnets = ["${aws_subnet.primary.id}", "${aws_subnet.secondary.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "TestELB"
  }
}

resource "aws_security_group" "sg-elb" {
  name        = "${var.sg-elb}"
  vpc_id = "${aws_vpc.vpc.id}"
  depends_on = ["aws_internet_gateway.gw"]
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_route_table_association" "a" {
  depends_on = ["aws_route_table.rt", "aws_subnet.primary"]
  subnet_id      = "${aws_subnet.primary.id}"
  route_table_id = "${aws_route_table.rt.id}"
}

# S3 bucket
resource "aws_s3_bucket" "static_files_bucket" {
  bucket = "aws-scalable-app-static-files-bucket"
  acl    = "private"
  tags {
    Name        = "Static website bucket"
  }
}

resource "aws_s3_bucket_policy" "static_files_bucket_policy" {
  # depends_on = ["${aws_s3_bucket.static_files_bucket}"]
  bucket = "${aws_s3_bucket.static_files_bucket.id}"
  policy =
  <<-POLICY
  {
    "Version": "2012-10-17",
    "Id": "Policy1321321231",
    "Statement": [
        {
            "Sid": "Access-to-specific-VPC-only",
       "Principal": "*",
       "Action": "s3:*",
       "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::aws-scalable-app-static-files-bucket",
                "arn:aws:s3:::aws-scalable-app-static-files-bucket/*"
            ]
        } 
    ]
  }
  POLICY
}
 # ,
        #     "Condition": {
        #  "StringNotEquals": {
        #    "aws:sourceVpc": "${aws_vpc.vpc.id}"
        #  }
      #  }
      #  }
# resource "aws_vpc_endpoint" "s3" {
#   depends_on = ["${aws_route_table.rt}","${aws_vpc.vpc}"]
#   vpc_id       = "${aws_vpc.vpc.id}"
#   service_name = "com.amazonaws.us-west-2.s3"
#   route_table_ids = ["${aws_route_table.rt.id}"]
# }

resource "aws_autoscaling_group" "asgSecondary" {
  depends_on = ["aws_launch_configuration.secondary"]
  availability_zones        = ["${data.aws_availability_zones.available.names[1]}"]
  name                      = "TerraformASGSecondary"
  max_size                  = 2
  min_size                  = 1
  wait_for_capacity_timeout = "0"
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 1
  wait_for_capacity_timeout = "0"
  force_delete              = false
  vpc_zone_identifier = ["${aws_subnet.secondary.id}"]
  launch_configuration      = "${aws_launch_configuration.secondary.name}"
  load_balancers = ["${aws_elb.elb.name}"]
}

resource "aws_subnet" "private_secondary" {
  depends_on = ["aws_subnet.secondary"]
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.secondary_private_subnet_cidr}"
  map_public_ip_on_launch = "${var.private_ip_bool}"
  tags {
    Name = "Private Secondary"
  }
}

resource "aws_subnet" "secondary" {
  depends_on = ["aws_route_table.rt"]
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.secondary_public_subnet_cidr}"
  map_public_ip_on_launch = "${var.public_ip_bool}"
  tags {
    Name = "Secondary"
  }
}

resource "aws_route_table_association" "b" {
  depends_on = ["aws_route_table.rt", "aws_subnet.secondary"]
  subnet_id      = "${aws_subnet.secondary.id}"
  route_table_id = "${aws_route_table.rt.id}"
}

resource "aws_security_group" "secondary" {
  name        = "${var.secondary_sg}"
  description = "${var.secondary_sg_desc}"
  depends_on = ["aws_internet_gateway.gw"]
  vpc_id = "${aws_vpc.vpc.id}"
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  tags {
    Name = "${var.secondary_sg}"
  }
}

resource "aws_launch_configuration" "secondary" {
  image_id      = "ami-030aae8cba933aede"
  instance_type = "${var.ami_type}"
  security_groups = ["${aws_security_group.primary.id}"]
  user_data = 
  <<-EOF
  #!/bin/bash
  # curl https://omnitruck.chef.io/install.sh | sudo bash -s -- -P chefdk -c stable -v 2.5.3
  # mkdir chef-repo
  # cd chef-repo
  curl https://raw.githubusercontent.com/KILFaT/aws-scalable-app/master/serv.py -O
  # sudo chef-client --local-mode webserver.rb
  python serv.py
  # python -m http.server 80
  EOF

  key_name               = "${var.key_name}"
  depends_on = ["aws_subnet.secondary"]
  name          = "web_config_secondary"
}