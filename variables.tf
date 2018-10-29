#IP Addresses
variable "vpc_ip" {default = "172.30.0.0/16"}

variable "public_subnet_cidr" {default = "172.30.0.0/28"}
variable "secondary_public_subnet_cidr" {default = "172.30.0.16/28"}
variable "private_subnet_cidr" {default = "172.30.112.0/28"}
variable "secondary_private_subnet_cidr" {default = "172.30.224.16/28"}
variable "nat_ip" {default = "172.30.0.10"}

variable "route_table_cidr" {default = "0.0.0.0/0"}


# Provider
# variable "access_key" {}
# variable "secret_key" {}
# variable "region" {default = "us-east-2"}

#IP settings Variables
variable "public_ip_bool" {default = "true"}
variable "private_ip_bool" {default = "false"}


# Name and description Variables
variable "sg-elb" {default = "elbSg"}

variable "vpc_name" {default = "TerraformTestVPC"}

variable "gateway_name" {default = "Gateway"}
variable "route_table_name" {default = "MainRouteTable"}
variable "primary_sg_desc" {default = "Allow all inbound traffic"}
variable "primary_sg" {default = "Primary"}
variable "secondary_sg_desc" {default = "Allow all inbound traffic"}
variable "secondary_sg" {default = "Secondary"}
variable "private_subnet_group_name" {default = "main_subnet_group"}
variable "private_subnet_group_desc" {default = "Main_subnet_group"}


#AMI Settings
variable "ami_type" {default = "t2.micro"}


# RDS Settings
# variable "db_username" {}
# variable "db_password" {}
# variable "db_instance_class" {}
variable "db_multi_az" {default = "true"}
variable "db_allocated_storage" {default = 5}
variable "db_storage_type" {default = "gp2"}


#Data retrieval (from AWS)
# #Getting available availability zones
# variable "aws_availability_zones" {
# 	default = ["eu-central-1","eu-west-1"]

# #   most_recent = true

#   }

data "aws_availability_zones" "available" {}

variable "amis" {
  description = "Base AMI to launch the instances"
  default = {
  eu-central-1 = "ami-030aae8cba933aede"
  }
}
#Getting latest OS (Windows Server 2012 R2 in this case)
data "aws_ami" "amazon_freetier" {
	most_recent = true
	owners      = ["amazon"]
	filter {
	name   = "name"
	values = ["Windows_Server-2012-R2_RTM-English-64Bit-Base-*"]
	}
}
variable "key_name" {
  description = "Key name for SSHing into EC2"
  default = "test-key-pair-1"
}

data "template_file" "asg_user_data" {
  template = "asg_user_data.tpl"

  vars {
    name        = "example"
    environment = "default"
    run_list    = "nginx"
  }
}