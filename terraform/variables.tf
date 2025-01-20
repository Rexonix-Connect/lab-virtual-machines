variable "authorized_ssh_keys" {
  description = "This is the list of ssh public keys that will be inserted into authorized_keys for admin user."
  type        = list(string)
  sensitive   = false
}
variable "vsphere_datacenter" {
  description = "The vSphere Datacenter that the VM(s) will be deployed"
  type        = string
}
variable "content_library" {
  description = "The name of the Content Library that has the VM(s) Image"
  type        = string
}
variable "vm_datastore" {
  description = "The vSphere Datastore that will back the VM(s)"
  type        = string
}
variable "vm_name" {
  description = "Name base of the VM(s) that will be created"
  type        = string
}
variable "vm_username" {
  description = "Username of the VM(s) that will be created"
  type        = string
}
variable "vm_password" {
  description = "Password of the VM(s) that will be created"
  type        = string
  sensitive   = true
}
variable "vm_folder" {
  description = "The folder that the VM(s) will be placed in. This will be the full path and name of the folder that will be created"
  type        = string
}
variable "vm_template" {
  description = "The name of the VM(s) Image that is hosted in a Content Library"
  type        = string
}
variable "vm_network" {
  description = "The name of the VM(s) network"
  type        = string
}
variable "vsphere_user" {
  description = "The user account that will be used to create the VM(s)"
  type        = string
}
variable "vsphere_password" {
  description = "The password for the user account that will be used for creating vSphere resources"
  type        = string
  sensitive   = true
}
variable "vsphere_server" {
  description = "The IP Address or FQDN of the VMware vCenter server"
  type        = string
}
variable "vsphere_unverified_ssl" {
  description = "Use unverified SSL when connecting to vCenter server"
  type        = bool
  default     = false
}
variable "compute_cluster" {
  description = "The name of the vSphere cluster that the VM(s) will be deployed to"
  type        = string
  default     = null
}
variable "vm_ip" {
  description = "A list of IP Addresses that will be assigned to the VM(s)."
  type        = list(string)
}
variable "vm_netmask" {
  description = "The subnet mask of the VM(s) mgmt network"
  type        = string
}
variable "vm_gateway" {
  description = "The IP Address of the gateway for the VM(s) mgmt network"
  type        = string
}
variable "dns_server_list" {
  description = "A list of DNS IP Addresses that will be assigned to the VM(s)."
  type        = list(string)
}
variable "vm_domain" {
  description = "The Domain for the VM(s)"
  type        = string
}
