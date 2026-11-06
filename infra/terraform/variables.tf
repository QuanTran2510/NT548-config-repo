variable "aws_region" {
  description = "Learner Lab only allows us-east-1 and us-west-2"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "key_name" {
  description = "EC2 key pair. Learner Lab provides one called vockey (download labsuser.pem from the lab page)"
  type        = string
  default     = "vockey"
}

variable "ssh_key_path" {
  description = "Path of the private key on the machine that runs Ansible (only written into the inventory text)"
  type        = string
  default     = "~/.ssh/labsuser.pem"
}

variable "admin_cidr" {
  description = "Who may reach SSH (22), the Kubernetes API (6443) and NodePorts. YOUR_IP/32. No default on purpose: a forgotten value must fail, not open the cluster to the world."
  type        = string
}

variable "disk_gb" {
  type    = number
  default = 20
}

# Written by the placement optimiser (nodes.auto.tfvars.json), reviewed in a pull request.
variable "node_counts" {
  description = "Number of t3.small nodes per simulated site"
  type        = map(number)
  default     = { "us-east" = 1, "eu-west" = 1, "ap-southeast" = 1 }

  validation {
    condition = alltrue([
      for s in ["us-east", "eu-west", "ap-southeast"] :
      contains(keys(var.node_counts), s) && var.node_counts[s] >= 1 && var.node_counts[s] <= 4
    ])
    error_message = "node_counts needs us-east, eu-west and ap-southeast, each between 1 and 4."
  }
  validation {
    condition     = sum(values(var.node_counts)) <= 9
    error_message = "Learner Lab allows at most 9 running instances in total."
  }
}
