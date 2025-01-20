data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}
data "vsphere_compute_cluster" "cluster" {
  count         = 1
  name          = var.compute_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_datastore" "datastore" {
  name          = var.vm_datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_network" "network" {
  name          = var.vm_network
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_content_library" "library" {
  name = var.content_library
}
data "vsphere_content_library_item" "item" {
  name       = var.vm_template
  library_id = data.vsphere_content_library.library.id
  type       = "ovf"
}