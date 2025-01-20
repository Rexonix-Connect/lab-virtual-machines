data "vsphere_datacenter" "dc" {
  name = var.vCenterDatacenterName
}
data "vsphere_compute_cluster" "cluster" {
  count         = 1
  name          = var.clusterName
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_datastore" "datastore" {
  name          = var.datastoreName
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_network" "network" {
  name          = var.portGroup
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_content_library" "library" {
  name = var.libraryName
}
data "vsphere_content_library_item" "item" {
  name       = var.templateName
  library_id = data.vsphere_content_library.library.id
  type       = "ovf"
}