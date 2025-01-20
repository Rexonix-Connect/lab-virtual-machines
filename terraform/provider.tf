provider "vsphere" {
  user                 = var.vCenterUsername
  password             = var.vCenterPassword
  vsphere_server       = var.vCenterServer
  allow_unverified_ssl = var.vCenterInsecureConnection
}
