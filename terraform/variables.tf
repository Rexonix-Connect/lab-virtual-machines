variable "authorizedSshKeys" {
  description = "This is the list of ssh public keys that will be inserted into authorized_keys for admin user."
  type        = list(string)
  sensitive   = false
}
variable "vCenterDatacenter" {
  description = "The vSphere Datacenter that the VM(s) will be deployed"
  type        = string
}
variable "libraryName" {
  description = "The name of the Content Library that has the VM(s) Image"
  type        = string
}
variable "datastoreName" {
  description = "The vSphere Datastore that will back the VM(s)"
  type        = string
}
variable "vmName" {
  description = "Name base of the VM(s) that will be created"
  type        = string
}
variable "vmUsername" {
  description = "Username of the VM(s) that will be created"
  type        = string
}
variable "vmPassword" {
  description = "Password of the VM(s) that will be created"
  type        = string
  sensitive   = true
}
variable "vmFolder" {
  description = "The folder that the VM(s) will be placed in. This will be the full path and name of the folder that will be created"
  type        = string
}
variable "templateName" {
  description = "The name of the VM(s) Image that is hosted in a Content Library"
  type        = string
}
variable "portGroup" {
  description = "The name of the VM(s) network"
  type        = string
}
variable "vCenterUsername" {
  description = "The user account that will be used to create the VM(s)"
  type        = string
}
variable "vCenterPassword" {
  description = "The password for the user account that will be used for creating vSphere resources"
  type        = string
  sensitive   = true
}
variable "vCenterServer" {
  description = "The IP Address or FQDN of the VMware vCenter server"
  type        = string
}
variable "vCenterInsecureConnection" {
  description = "Use unverified SSL when connecting to vCenter server"
  type        = bool
  default     = false
}
variable "clusterName" {
  description = "The name of the vSphere cluster that the VM(s) will be deployed to"
  type        = string
  default     = null
}
variable "vmIPAddresses" {
  description = "A list of IP Addresses that will be assigned to the VM(s)."
  type        = list(string)
}
variable "vmIPNetmask" {
  description = "The subnet mask of the VM(s) mgmt network"
  type        = string
}
variable "vmIPGateway" {
  description = "The IP Address of the gateway for the VM(s) mgmt network"
  type        = string
}
variable "dnsServerList" {
  description = "A list of DNS IP Addresses that will be assigned to the VM(s)."
  type        = list(string)
}
variable "vmDomain" {
  description = "The Domain for the VM(s)"
  type        = string
}
