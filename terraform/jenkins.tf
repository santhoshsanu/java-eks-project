# ─── Jenkins Security Group ───────────────────────────────────────────────────

resource "aws_security_group" "jenkins_sg" {
  name        = "${var.project_name}-jenkins-sg"
  description = "Security group for Jenkins EC2 server"
  vpc_id      = aws_vpc.main.id

  # Jenkins Web UI
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
    description = "Jenkins Web UI"
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
    description = "SSH access"
  }

  # Jenkins agent JNLP port
  ingress {
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Jenkins agent JNLP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-jenkins-sg"
  }
}

# ─── Jenkins User Data (bootstrap script) ─────────────────────────────────────

locals {
  jenkins_user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system
    apt-get update -y
    apt-get upgrade -y

    # Install Java 17
    apt-get install -y openjdk-17-jdk

    # Install Jenkins
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | tee /etc/apt/sources.list.d/jenkins.list > /dev/null
    apt-get update -y
    apt-get install -y jenkins

    # Start and enable Jenkins
    systemctl enable jenkins
    systemctl start jenkins

    # Install Docker
    apt-get install -y ca-certificates curl gnupg lsb-release
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io

    # Add jenkins user to docker group
    usermod -aG docker jenkins
    systemctl enable docker
    systemctl start docker

    # Install AWS CLI v2
    apt-get install -y unzip
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf awscliv2.zip aws/

    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/kubectl

    # Install Trivy
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | tee /etc/apt/sources.list.d/trivy.list
    apt-get update -y
    apt-get install -y trivy

    # Install Gradle 8
    apt-get install -y wget unzip
    wget https://services.gradle.org/distributions/gradle-8.5-bin.zip -P /tmp
    unzip -d /opt/gradle /tmp/gradle-8.5-bin.zip
    ln -s /opt/gradle/gradle-8.5/bin/gradle /usr/local/bin/gradle

    # Restart Jenkins to pick up docker group
    systemctl restart jenkins

    echo "Jenkins bootstrap complete!" >> /var/log/jenkins-bootstrap.log
  EOF
}

# ─── Jenkins EC2 Instance ─────────────────────────────────────────────────────

resource "aws_instance" "jenkins" {
  ami                    = var.jenkins_ami_id
  instance_type          = var.jenkins_instance_type
  key_name               = var.jenkins_key_pair_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins_profile.name

  root_block_device {
    volume_size           = 20   # reduced for free tier
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = base64encode(local.jenkins_user_data)

  tags = {
    Name = "${var.project_name}-jenkins-server"
  }
}

# ─── Elastic IP for Jenkins ───────────────────────────────────────────────────

resource "aws_eip" "jenkins" {
  instance = aws_instance.jenkins.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-jenkins-eip"
  }

  depends_on = [aws_internet_gateway.main]
}
