terraform {
  required_version = ">= 1.3.0"

  backend "local" {
    path = "$STATEFILE_PATH"
  }

  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.10.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.5"
    }
  }

  encryption {
    key_provider "pbkdf2" "mykey" {
      passphrase = "$TF_ENCRYPTION_KEY"
    }

    method "aes_gcm" "new_method" {
      keys = key_provider.pbkdf2.mykey
    }

    state {
      method = method.aes_gcm.new_method
      enforced = true
    }
  }
}

locals {
  templatevars = {
    name         = var.vmName
    ipv4_address = var.vmIPAddresses[0]
    ipv4_netmask = var.vmIPNetmask
    ipv4_gateway = var.vmIPGateway
    domain       = var.vmDomain
    dns_servers  = jsonencode(var.dnsServerList)
    public_keys  = jsonencode(concat(var.authorizedSshKeys, [tls_private_key.temp_ssh_keypair.public_key_openssh]))
    ssh_username = var.vmUsername
    ssh_password = var.vmPassword
  }
}

resource "tls_private_key" "temp_ssh_keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "vsphere_virtual_machine" "virtual_machine" {
  name             = var.vmName
  datastore_id     = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_compute_cluster.cluster[0].resource_pool_id
  num_cpus         = 2
  memory           = 4096
  # folder           = "/${var.vCenterDatacenterName}/vm/${var.vmFolder}"
  folder           = "${var.vmFolder}"
  connection {
    type        = "ssh"
    host        = self.guest_ip_addresses[0]
    user        = var.vmUsername
    private_key = tls_private_key.temp_ssh_keypair.private_key_openssh
  }
  lifecycle {
    ignore_changes = [guest_id]
  }
  extra_config = {
    "guestinfo.metadata"          = base64encode(templatefile("${path.module}/templates/metadata.yaml", local.templatevars))
    "guestinfo.metadata.encoding" = "base64"
    "guestinfo.userdata"          = base64encode(templatefile("${path.module}/templates/userdata.yaml", local.templatevars))
    "guestinfo.userdata.encoding" = "base64"
  }
  disk {
    label            = "disk0"
    size             = "50"
    thin_provisioned = true
  }
  network_interface {
    network_id = data.vsphere_network.network.id
  }
  clone {
    template_uuid = data.vsphere_content_library_item.item.id
  }
  provisioner "remote-exec" {
    inline = [
      "sudo userdel vagrant",
      "sudo rm -r /home/vagrant",
      "sudo passwd ${var.vmUsername} <<EOF",
      "${var.vmPassword}",
      "${var.vmPassword}",
      "EOF"
    ]
  }
}
