output "ip" {
  value = vsphere_virtual_machine.virtual_machine.*.guest_ip_addresses
}
