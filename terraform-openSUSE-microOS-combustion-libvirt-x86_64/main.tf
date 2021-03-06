provider "libvirt" {
  uri = var.libvirt_uri
}

resource "libvirt_volume" "img" {
  name   = "${var.vm_name}-${basename(var.image_uri)}"
  source = var.image_uri
  pool   = var.pool
}

