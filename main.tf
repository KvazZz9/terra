terraform {
  required_providers {
    vsphere = {
      source = "hashicorp/vsphere"
      version = "2.11.1"  # 
    }
  }
}

provider "vault" {
 skip_child_token = true
 address = "https://192.168.3.243:8200"
 token = "${var.VAULT_TOKEN}"
}

data "vault_generic_secret" "my_secret" {
  path = "kv_ans/vsphere"
}


provider "vsphere" {
  user           = "${data.vault_generic_secret.my_secret.data.vsphere_user}"
  password       = "${data.vault_generic_secret.my_secret.data.vsphere_password}"
  vsphere_server = "vcenter.hayas.ru"
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "Datacenter"
}

data "vsphere_compute_cluster" "cluster" {
  name          = "Hayas"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_datastore" "datastore" {
  name          = "LNV_array_1_ssd_01"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = "3_ESXi"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "Ubuntu22.04_Template_12.12.2024_noVLM_v21"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_virtual_machine" "testnginx01" {
  name             = "testnginx01"
  firmware = "efi"
  resource_pool_id = "${data.vsphere_compute_cluster.cluster.resource_pool_id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"
  folder = "TEST"

  num_cpus = 2
  memory   = 4096
  guest_id = data.vsphere_virtual_machine.template.guest_id

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

   disk {
    label            = "disk0"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }


  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

    customize {
      linux_options {
        host_name = "testnginx01"
        domain    = "dc"
      }
        dns_server_list     = ["192.168.3.4", "192.168.3.3"]
        network_interface {
        ipv4_address = "192.168.33.166"
        ipv4_netmask = 24
      }


      ipv4_gateway = "192.168.33.1"
    }
  }
}

output "vsphere_user" {
  value     = "${data.vault_generic_secret.my_secret.data["vsphere_user"]}"
  }

output "datacenter_id" {
  value = "${data.vsphere_datacenter.dc.id}"
}

output "datastore_id" {
  value = "${data.vsphere_datastore.datastore.id}"
}

output "cluster_id" {
  value = "${data.vsphere_compute_cluster.cluster.id}"
}

output "vm_ip" {
  value = "${vsphere_virtual_machine.testnginx01.clone[0].customize[0].network_interface[0].ipv4_address}"
}  
