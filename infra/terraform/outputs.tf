output "server_public_ip" {
  value = aws_eip.server.public_ip
}

output "nodes" {
  value = { for k, v in local.inventory_nodes : k => "${v.site} ${v.public_ip}" }
}

output "ansible_inventory" {
  description = "Rendered by ansible/refresh-inventory.sh"
  value = templatefile("${path.module}/inventory.tpl", {
    nodes   = local.inventory_nodes
    ssh_key = var.ssh_key_path
  })
}
