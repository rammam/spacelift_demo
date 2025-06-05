variable "location" {

  description = "Azure Region"

  type        = string

  default     = "East US"

}


variable "resource_group_name" {

  description = "Resource Group Name"

  type        = string

  default     = "rg-vpc-example"

}


variable "vm_ssh_public_key" {

  description = "SSH public key for VM"

  type        = string

}