locals {
  sites = ["us-east", "eu-west", "ap-southeast"]

  # The first node of each site keeps its historical key. NEVER rename these:
  # changing a for_each key makes Terraform destroy and recreate the VM.
  first_node_key = { "us-east" = "server", "eu-west" = "agent1", "ap-southeast" = "agent2" }

  # Extra nodes are named "<site>-2", "<site>-3", ... (all k3s agents).
  # The us-east first node is the k3s server (control plane).
  nodes = merge([
    for site in local.sites : {
      for i in range(var.node_counts[site]) :
      (i == 0 ? local.first_node_key[site] : "${site}-${i + 1}") => {
        role = (i == 0 && site == "us-east") ? "server" : "agent"
        site = site
      }
    }
  ]...)
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "k3s" {
  name        = "platform-k3s"
  description = "k3s cluster for the GitOps platform project"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  ingress {
    description = "Kubernetes API from admin"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  ingress {
    description = "NodePort services (ArgoCD, Grafana, portal) from admin"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  ingress {
    description = "All traffic between cluster nodes (flannel, kubelet, API)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "node" {
  for_each               = local.nodes
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids = [aws_security_group.k3s.id]

  root_block_device {
    volume_size = var.disk_gb
    volume_type = "gp3"
  }
  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }
  lifecycle {
    # most_recent AMI moves over time; without this a plan would REPLACE every running node.
    ignore_changes = [ami]
  }
  tags = {
    Name = "platform-${each.key}"
    Role = each.value.role
    Site = each.value.site
  }
}

# Only the server gets an Elastic IP: its address must survive stop/start.
resource "aws_eip" "server" {
  domain   = "vpc"
  instance = aws_instance.node["server"].id
  tags     = { Name = "platform-server" }
}

locals {
  inventory_nodes = {
    for k, v in local.nodes : k => {
      role       = v.role
      site       = v.site
      private_ip = aws_instance.node[k].private_ip
      public_ip  = k == "server" ? aws_eip.server.public_ip : aws_instance.node[k].public_ip
    }
  }
}

# The inventory used to be written by Terraform. With shared state (CI) it is now an output:
# run ansible/refresh-inventory.sh. "destroy = false" forgets the resource but keeps the file.
removed {
  from = local_file.inventory
  lifecycle {
    destroy = false
  }
}
