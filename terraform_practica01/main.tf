provider "aws" {
  region = var.aws_region
}

// create a ssh key pair  with terrafom
resource "tls_private_key" "key_pair_ubuntu" {
  algorithm = "RSA"
  rsa_bits = 4096
}

// upload the public key to aws
resource "aws_key_pair" "key_pair_ubuntu" {
    key_name = "pin_key"
    public_key = tls_private_key.key_pair_ubuntu.public_key_openssh
}

// save the private key to a file
resource "local_file" "private_key" {
  content  = tls_private_key.key_pair_ubuntu.private_key_pem
  filename = "pin_key.pem"
  file_permission = "0600"
}

// create a vpc to deploy the ec2 instance
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

//  create an internet gateway and attach it to the vpc
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

// create a route table and add a route to the internet gateway
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
    }
}

resource "aws_main_route_table_association" "a" {
    vpc_id = aws_vpc.main.id
    route_table_id = aws_route_table.main.id
}

// create a subnet and associate it with the route table
resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/24"
}

// create a security group to allow ssh connection
resource "aws_security_group" "allow_ssh" {
  vpc_id = aws_vpc.main.id
  name = "allow_ssh"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    }   
}

// create a ec2 instance with. SO: ubuntu sercer 22.04, t2.micro 
resource "aws_instance" "ubuntu_Server" {
    ami = "ami-005fc0f236362e99f"
    instance_type = "t2.micro"
    subnet_id = aws_subnet.main.id
    vpc_security_group_ids = [aws_security_group.allow_ssh.id]
    associate_public_ip_address = true
    tags = {
        Name = "ubuntu_Server"
    }
    // add user data to install awscli, docker, kubectl and helm
    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                
                # Install awscli
                sudo apt install -y unzip curl docker.io

                # Descargar e instalar AWS CLI v2
                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                unzip awscliv2.zip
                sudo ./aws/install

                # Install kubectl
                curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
                chmod +x kubectl
                sudo mv ./kubectl /usr/local/bin/kubectl

                # Install helm
                curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
  
                # Install eksctl
                curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
                sudo mv /tmp/eksctl /usr/local/bin

                # Verify installations
                aws --version
                kubectl version --client
                helm version
                eksctl version || echo "Instalación de eksctl falló"
                
                echo "Instalación completada."
                EOF
    
    // add the key pair to the instance
    key_name = aws_key_pair.key_pair_ubuntu.key_name
    depends_on = [local_file.private_key]
}

