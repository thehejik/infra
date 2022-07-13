output "ip_vms" {
  value = zipmap(
    libvirt_domain.vm.*.name,
    libvirt_domain.vm.*.network_interface.0.addresses.0,
  )
}
