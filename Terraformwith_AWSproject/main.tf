#Create VPC
resource "aws_vpc" "myvpc" {
    cidr_block = var.cidr
  
  }

#Create Subnet1
resource "aws_subnet" "sub1" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
}

#Create Subnet2
resource "aws_subnet" "sub2" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true
}

#Create Internet gateway to get access to internet 
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.myvpc.id
}

#Create Route table
resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
 }
}

#Create Route table association 
resource "aws_route_table_association" "rta1" {
    subnet_id = aws_subnet.sub1.id
    route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "rta2" {
    subnet_id = aws_subnet.sub2.id
    route_table_id = aws_route_table.RT.id
}

#Create security group
resource "aws_security_group" "websg" {
  name        = "websg"
  vpc_id      = aws_vpc.myvpc.id

 ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  
 ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

#Create S3 bucket
resource "aws_s3_bucket" "example" {
  bucket = "rina-terraform-bucket-2023-project"
}

#Create ec2 instance
resource "aws_instance" "webserver1" {
  ami = "ami-053b0d53c279acc90"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.websg.id]
  subnet_id = aws_subnet.sub1.id
  user_data = base64encode(file("userdata.sh"))
  }

resource "aws_instance" "webserver2" {
  ami = "ami-053b0d53c279acc90"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.websg.id]
  subnet_id = aws_subnet.sub2.id
  user_data = base64encode(file("userdata1.sh"))
  }

#Create application load balancer
resource "aws_lb" "myalb" {
  name = "my-alb"
  internal = false
  load_balancer_type = "application"
  enable_deletion_protection = false

  security_groups = [aws_security_group.websg.id]
  subnets = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  tags = {
    Name = "web"
  }
}

resource "aws_lb_target_group" "tg" {
  name     = "myTg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }

}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver1.id
  port             = 80

}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver2.id
  port             = 80

}

resource "aws_lb_listener" "listner" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }
}

output "Loadbalancer" {
  value = aws_lb.myalb.dns_name
}


