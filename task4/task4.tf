provider "aws" {
    region = "ap-south-1"
    profile = "bobby"
}
resource "tls_private_key" "task4_key" {
    algorithm = "RSA"
}

resource "aws_key_pair" "key2" {
    depends_on = [
        tls_private_key.task4_key
    ]
    key_name = "task4_key"
    public_key = "${tls_private_key.task4_key.public_key_openssh}"
}

resource "local_file" "key-file" {
    content = "${tls_private_key.task4_key.private_key_pem}"
    filename = "task4_key.pem"
    file_permission = 0400
    depends_on = [
        tls_private_key.task4_key
    ]
}
resource "aws_vpc" "bobbyvpc" {
    cidr_block = "192.168.0.0/16"
    instance_tenancy = "default"
    enable_dns_hostnames = true

    tags = {
        Name = "bobbyvpc"
    }
}

resource "aws_subnet" "public_subnet" {
    depends_on = [aws_vpc.bobbyvpc]
    vpc_id = aws_vpc.bobbyvpc.id
    cidr_block = "192.168.0.0/24"
    availability_zone = "ap-south-1a"
    map_public_ip_on_launch = true
    tags = {
        Name =  "Public_Subnet"
    }
}
resource "aws_internet_gateway" "My_IG" {
    depends_on = [aws_vpc.bobbyvpc]
    vpc_id = aws_vpc.bobbyvpc.id
    tags = {
        Name = "My_Internet_Gateway"
    }
}
resource "aws_route_table" "my_routing_table" {
    depends_on = [aws_internet_gateway.My_IG,aws_vpc.bobbyvpc]
    vpc_id = "${aws_vpc.bobbyvpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.My_IG.id}"
    }
    tags = {
        Name = "Route_table"
    }
}
resource "aws_route_table_association" "routing_table_asson" {
    depends_on = [aws_route_table.my_routing_table,aws_subnet.public_subnet]
    subnet_id = "${aws_subnet.public_subnet.id}"
    route_table_id = "${aws_route_table.my_routing_table.id}"
}
resource "aws_subnet" "private_subnet" {
    depends_on = [aws_vpc.bobbyvpc]
    vpc_id = aws_vpc.bobbyvpc.id
    cidr_block = "192.168.2.0/24"
    availability_zone = "ap-south-1b"
    tags = {
        Name =  "Private_Subnet"
    }

}
resource "aws_eip" "elasti_ip" {
    vpc = true
}
resource "aws_nat_gateway" "nat_gateway" {
    allocation_id = "${aws_eip.elasti_ip.id}"
    subnet_id = "${aws_subnet.public_subnet.id}"
    tags = {
      Name = "my_nat_gateway"  
    }
}
resource "aws_route_table" "nat_gateway_route" {
    vpc_id = "${aws_vpc.bobbyvpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_nat_gateway.nat_gateway.id}"
    }
    tags = {
        Name = "nat_gateway_route"
    }

}
resource "aws_route_table_association" "nat_asso" {
  subnet_id      = "${aws_subnet.private_subnet.id}"
  route_table_id = "${aws_route_table.nat_gateway_route.id}"
}
resource "aws_security_group" "Security_Group_Word_Press" {
    depends_on = [aws_vpc.bobbyvpc]
    name = "Security_Group_Word_Press"
    description = "Allow HTTP inbound traffic"
    vpc_id = "${aws_vpc.bobbyvpc.id}"

    ingress {
        description = "http"
        from_port   = 80
        to_port     = 80
        protocol    = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "ssh"
        from_port   = 22
        to_port     = 22
        protocol    = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "HTTPS"
        from_port   = 443
        to_port     = 443
        protocol    = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress{
           from_port   = 0
           to_port     = 0
           protocol    = "-1"
           cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
      Name ="Security_Group_Word_Press"
  }
}
resource "aws_security_group" "Security_Group_BastionHost" {
    depends_on = [aws_vpc.bobbyvpc]
    name = "Security_Group_BastionHost"
    description = "ssh_bh"
    vpc_id = "${aws_vpc.bobbyvpc.id}"

    ingress {
        description = "ssh"
        from_port   = 22
        to_port     = 22
        protocol    = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress{
           from_port   = 0
           to_port     = 0
           protocol    = "-1"
           cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
      Name ="Security_Group_BastionHost"
  }
}
resource "aws_security_group" "Security_Group_MySQL" {
    depends_on = [aws_vpc.bobbyvpc]
    name = "Security_Group_MySQL"
    description = "Allow HTTP inbound traffic"
    vpc_id = "${aws_vpc.bobbyvpc.id}"

    ingress {
        description = "mysql"
        from_port   = 3306
        to_port     = 3306
        protocol    = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "ssh"
        from_port   = 22
        to_port     = 22
        protocol    = "TCP"
        security_groups = ["${aws_security_group.Security_Group_BastionHost.id}"]
    }
    egress{
           from_port   = 0
           to_port     = 0
           protocol    = "-1"
           cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
      Name ="Security_Group_MYSQL"
  }
}
resource "aws_instance" "Wordpress" {
    ami = "ami-0fab75b03b2c2152d"
    instance_type = "t2.micro"
    key_name = "${aws_key_pair.key2.key_name}"
    subnet_id = "${aws_subnet.public_subnet.id}"
    vpc_security_group_ids = ["${aws_security_group.Security_Group_Word_Press.id}"]
    tags = {
        Name = "WordPress_OS"
    }
}
resource "aws_instance" "BastionHost" {
    ami = "ami-0ebc1ac48dfd14136"
    instance_type = "t2.micro"
    key_name = "${aws_key_pair.key2.key_name}"
    subnet_id = "${aws_subnet.public_subnet.id}"
    vpc_security_group_ids = ["${aws_security_group.Security_Group_BastionHost.id}"]
    tags = {
        Name = "BastionHost_OS"
    }
}
resource "aws_instance" "MYSQL" {
    ami = "ami-0ebc1ac48dfd14136"
    instance_type = "t2.micro"
    key_name = "${aws_key_pair.key2.key_name}"
    subnet_id = "${aws_subnet.private_subnet.id}"
    vpc_security_group_ids = ["${aws_security_group.Security_Group_MySQL.id}"]
    tags = {
        Name = "MySql_Os"
    }
}
// https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/hosting-wordpress.html