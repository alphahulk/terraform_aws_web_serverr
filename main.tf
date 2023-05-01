provider "aws" {
    region = "ap-south-1"
    access_key = ""
    secret_key = ""
  
}

#1create a vpc
resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.0.0.0/16"

  tags={
    Name = "production"
  }
}



#2create internet gateway

///An Internet Gateway (IGW) is a horizontally scalable, redundant, and highly available VPC component that allows communication between resources in your VPC and the Internet.

/*In AWS, an Internet Gateway (IGW) is a critical component for enabling public Internet access to resources in a Virtual Private Cloud (VPC). When an EC2 instance or other resources in a VPC has a public IP address, it can communicate with the Internet directly through the IGW.

An Internet Gateway in AWS allows you to:
Establish a public-facing internet routable IP address for your VPC.
Connect your VPC to the internet for outbound and inbound traffic.
Enable communication between instances in your VPC and the internet.
Use public IP addresses to communicate with the internet.*/
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod_vpc.id

  tags = {
    Name = "gw"
  }
}



#3create custom route table
/*Route Table is a virtual networking component that contains a set of rules, known as routes, 
that determine where network traffic is directed. Each VPC has a default route table, 
but you can also create additional custom route tables to control the flow of traffic in more specific ways*/
resource "aws_route_table" "prod_route_table" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod_route_table"
  }
}



#4create a subnet
/*In AWS, a subnet is a range of IP addresses in your Virtual Private Cloud (VPC) that you can use to isolate your resources and control access to them. 
Each subnet is associated with a specific Availability Zone (AZ) in the AWS Region in which it is created.*/
resource "aws_subnet" "subnet" {
    vpc_id = aws_vpc.prod_vpc.id
    cidr_block = "10.0.0.0/16"
    availability_zone = "ap-south-1a"
      tags = {
    Name = "prod_Subnet"
  }
}



#5create a subnet with route table
/*In AWS, a Route Table is a virtual networking component that contains a set of rules, known as routes, that determine where network traffic is directed. Each subnet in your Virtual Private Cloud (VPC) is associated with a specific Route Table, which controls how traffic is routed within the subnet.

Here are some common use cases for subnets with Route Tables in AWS:

Traffic routing: By associating different subnets with different Route Tables, you can control how traffic is routed within your VPC. For example, you can route public traffic through one Route Table and private traffic through another, or route traffic to a specific service, such as a NAT Gateway or VPN connection.

Network segmentation: By creating multiple subnets with different Route Tables, you can segment your network into different tiers, such as web, application, and database tiers, and control access to resources based on their location within the VPC.

High availability: By creating resources in multiple subnets across different Availability Zones, and associating them with different Route Tables, you can ensure that your applications remain available even if one AZ becomes unavailable.

Security: By associating each subnet with a specific Route Table, you can control the flow of traffic to and from the subnet, and apply security rules based on the location of the resources within the VPC.*/
resource "aws_route_table_association" "a" {
  subnet_id      =  aws_subnet.subnet.id
  route_table_id = aws_route_table.prod_route_table.id
}



#6create security group to allow route 22,80,443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod_vpc.id

  ingress {
    description      = "https"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
    ingress {
    description      = "http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
    ingress {
    description      = "ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

#7create a network interface wth ip in the subnet that was created in step4
/*In AWS, a network interface (ENI) is a virtual network interface that you can attach to an instance in your Virtual Private Cloud (VPC) to enable network connectivity. An ENI can have one or more private IPv4 addresses, one or more elastic IP addresses, and one or more security groups.

Here are some common use cases for network interfaces with IP addresses in AWS:

Multi-homed instances: You can attach multiple ENIs to a single instance, each with its own private IP address, and use them to create a multi-homed instance that can communicate with different subnets or networks.

Elastic IP addresses: You can assign an elastic IP address to an ENI to provide a static, public IP address that can be used to access your instances from the internet.

Network traffic control: You can use ENIs with different IP addresses to control the flow of traffic between instances in your VPC, or between your VPC and other networks.

High availability: You can attach ENIs with IP addresses to instances in multiple Availability Zones to create highly available and fault-tolerant architectures.*/
resource "aws_network_interface" "web_server_nic" {
  subnet_id       = aws_subnet.subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]


}



#8assign an elastic ip to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web_server_nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}



#9create ubuntu server and install enable apache2

/*Apache2 is a popular open-source web server that can be installed on AWS EC2 instances using Terraform. Here are some use cases for Apache2 on an AWS web server:

Hosting web content: Apache2 can be used to serve web pages, images, videos, and other web-based applications on an AWS web server. It can handle multiple requests simultaneously and is suitable for high-traffic websites and applications.

Load balancing: Apache2 can be used as a load balancer on an AWS web server to distribute incoming traffic across multiple EC2 instances. This helps to improve the performance and availability of the web application.

Security features: Apache2 includes several security features, such as SSL/TLS encryption, authentication and authorization mechanisms, and access control features. These features can help to secure the web application running on the AWS web server.

Proxy server: Apache2 can be used as a reverse proxy server on an AWS web server to route incoming traffic to the appropriate backend server. This can be useful for load balancing or to provide additional security to the web application.

Overall, Apache2 is a versatile and powerful web server that can be used to host a variety of web applications and services on an AWS web server. By using Terraform to automate the installation and configuration of Apache2, you can quickly and easily set up a web server that meets your specific requirements.






*/
resource "aws_instance" "web_server_instance" {
  ami="ami-02eb7a4783e7e9317"
  instance_type = "t2.micro"
  availability_zone = "ap-south-1a"
  key_name = "access-key1"

  network_interface {
    device_index = 0
    network_interface_id =  aws_network_interface.web_server_nic.id 

  }
    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemct1 start apache2
                sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                EOF
    tags = {
        Name = "web-server"
    }
}
