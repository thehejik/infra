data "template_file" "combustion_xslt" {
  template = file("combustion-qemu-commandline.xslt.tpl")
  count    = var.vms

  vars = {
    combustion_filename = "${var.vm_name}-combustion-${count.index}"
  }
}

resource "libvirt_volume" "vm" {
  name           = "${var.vm_name}-volume-${count.index}"
  pool           = var.pool
  size           = var.vm_disk_size
  base_volume_id = libvirt_volume.img.id
  count          = var.vms
}

resource "libvirt_volume" "combustion" {
  name           = "${var.vm_name}-combustion-${count.index}"
  pool           = var.pool
  count          = var.vms
  format          = "raw"
  # TODO generate combustion-script with repos, packages, users, ssh keys etc. taken from variables
  source =  "${path.module}/combustion-script"
}

resource "libvirt_domain" "vm" {
  count      = var.vms
  name       = "${var.vm_name}-${count.index}"
  memory     = var.vm_memory
  vcpu       = var.vm_vcpu

#  cpu = {
#    mode = "host-passthrough"
#  }

  disk {
    volume_id = element(libvirt_volume.vm.*.id, count.index)
  }

  xml {
    xslt = data.template_file.combustion_xslt[count.index].rendered
  }

  qemu_agent = true

  network_interface {
    bridge = var.bridge
    wait_for_lease = true
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
  }
}

resource "null_resource" "vm_wait_combustion" {
  depends_on = [libvirt_domain.vm]
  count      = var.vms

  connection {
    host = element(
      libvirt_domain.vm.*.network_interface.0.addresses.0,
      count.index,
    )
    user     = var.username
    private_key = file("${path.module}/id_ecdsa_shared")
    type     = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "wall 'SSH connection established - Combustion finished'",
    ]
  }
}

resource "null_resource" "vm_reboot" {
  depends_on = [null_resource.vm_wait_combustion]
  count      = var.vms

  provisioner "local-exec" {
    environment = {
      user = var.username
      host = element(
        libvirt_domain.vm.*.network_interface.0.addresses.0,
        count.index,
      )
    }

    command = <<EOT
export sshopts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -oConnectionAttempts=60"
if ! ssh $sshopts $user@$host 'sudo needs-restarting -r'; then
    ssh $sshopts $user@$host sudo reboot || :
    export delay=5
    # wait for node reboot completed
    while ! ssh $sshopts $user@$host 'sudo needs-restarting -r'; do
        sleep $delay
        delay=$((delay+1))
        [ $delay -gt 30 ] && exit 1
    done
fi
EOT

  }
}
