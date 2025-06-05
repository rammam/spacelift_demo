# Output the public IP of the VM for SSH/HTTP

output "vm_public_ip" {

  description = "Public IP address of the Debian VM"

  value       = azurerm_public_ip.vm.ip_address

}