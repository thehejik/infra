data "template_file" "vm_repositories" {
  template = file("cloud-init/repository.tpl")
  count    = length(var.repositories)

  vars = {
    repository_url  = element(values(var.repositories), count.index)
    repository_name = element(keys(var.repositories), count.index)
  }
}

data "template_file" "vm_register_scc" {
  template = file("cloud-init/register-scc.tpl")
  count    = var.sle_registry_code == "" ? 0 : 1

  vars = {
    sle_registry_code = var.sle_registry_code
  }
}

data "template_file" "vm_commands" {
  template = file("cloud-init/commands.tpl")
  count    = join("", var.packages) == "" ? 0 : 1

  vars = {
    packages = join(", ", var.packages)
  }
}

data "template_file" "vm-cloud-init" {
  template = file("cloud-init/common.tpl")
  count = var.vms

  vars = {
    authorized_keys = join("\n", formatlist("  - %s", var.authorized_keys))
    repositories    = join("\n", data.template_file.vm_repositories.*.rendered)
    register_scc    = join("\n", data.template_file.vm_register_scc.*.rendered)
    commands        = join("\n", data.template_file.vm_commands.*.rendered)
    username        = var.username
    password        = var.password
    ntp_servers     = join("\n", formatlist("    - %s", var.ntp_servers))
    hostname        = "${var.vm_name}-${count.index}"
  }
}

resource "libvirt_volume" "vm" {
  name           = "${var.vm_name}-volume-${count.index}"
  pool           = var.pool
  size           = var.vm_disk_size
  base_volume_id = libvirt_volume.img.id
  count          = var.vms
}

resource "libvirt_cloudinit_disk" "vm" {
  # needed when 0 master nodes are defined
  count     = var.vms
  name      = "${var.vm_name}-cloudinit-disk-${count.index}"
  pool      = var.pool
  user_data = data.template_file.vm-cloud-init[count.index].rendered
}

resource "libvirt_domain" "vm" {
  count      = var.vms
  name       = "${var.vm_name}-${count.index}"
  machine    = "virt"
  memory     = var.vm_memory
  vcpu       = var.vm_vcpu
# cloudinit  = element(libvirt_cloudinit_disk.vm.*.id, count.index)
#  firmware   = "/usr/share/qemu/aavmf-aarch64-code.bin"
  firmware   = "/usr/share/AAVMF/AAVMF_CODE.fd" #ubuntu


  cpu = {
    mode = "host-passthrough"
  }

  disk {
    volume_id = element(libvirt_volume.vm.*.id, count.index)
    scsi = true
  }

  disk {
    volume_id = split(";", element(libvirt_cloudinit_disk.vm.*.id, count.index))[0]
    scsi = true
  }

  xml {
    xslt = file("add_disk_cache_unsafe.xslt")
  }

  qemu_agent = true

  network_interface {
    bridge = var.bridge
    hostname = "${var.vm_name}-${count.index}"
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "virtio"
  }
}

resource "null_resource" "vm_wait_cloudinit" {
  depends_on = [libvirt_domain.vm]
  count      = var.vms

  connection {
    host = element(
      libvirt_domain.vm.*.network_interface.0.addresses.0,
      count.index,
    )
    user     = var.username
    password = var.password
    type     = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait > /dev/null",
    ]
  }
}
