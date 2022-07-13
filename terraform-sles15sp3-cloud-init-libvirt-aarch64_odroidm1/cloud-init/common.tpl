#cloud-config

# set locale
locale: en_US.UTF-8

# set timezone
timezone: Etc/UTC

# set root password
chpasswd:
  list: |
    root:linux
    ${username}:${password}
  expire: False

ssh_authorized_keys:
${authorized_keys}

ntp:
  enabled: true
  ntp_client: chrony
  config:
    confpath: /etc/chrony.conf
  servers:
${ntp_servers}

# need to disable gpg checks because the cloud image has an untrusted repo
zypper:
  repos:
${repositories}
  config:
    gpgcheck: "off"
    solver.onlyRequires: "true"
    download.use_deltarpm: "true"

# need to remove the standard docker packages that are pre-installed on the
# cloud image because they conflict with the kubic- ones that are pulled by
# the kubernetes packages
# WARNING!!! Do not use cloud-init packages module when SUSE CaaSP Registraion
# Code is provided. In this case repositories will be added in runcmd module 
# with SUSEConnect command after packages module is ran
#packages:

hostname: ${hostname}

bootcmd:
  - ip link set dev eth0 mtu 1400
  # Hostnames from DHCP - otherwise localhost will be used
  - /usr/bin/sed -ie "s#DHCLIENT_SET_HOSTNAME=\"no\"#DHCLIENT_SET_HOSTNAME=\"yes\"#" /etc/sysconfig/network/dhcp
  # This is needed for as a workaround for nodes in qa.suse.cz where default k8s dns `options ndots:5` resolves domain.io to git.suse.de
  # - /usr/bin/sed -ie "s#NETCONFIG_DNS_STATIC_SERVERS.*#NETCONFIG_DNS_STATIC_SERVERS=\"8.8.8.8\"#" /etc/sysconfig/network/config
  - netconfig update -f
  - systemctl disable --now firewalld
  - echo -e "[main]\nvendors = suse,obs://build.suse.de" | tee /etc/zypp/vendors.d/vendors.conf

runcmd:
${register_scc}
${commands}
#  # enable rke2 inbound ports
#  - firewall-cmd --permanent --zone=public --add-port=22/tcp
#  - firewall-cmd --permanent --zone=public --add-port=9345/tcp
#  - firewall-cmd --permanent --zone=public --add-port=6443/tcp
#  - firewall-cmd --permanent --zone=public --add-port=8472/udp
#  - firewall-cmd --permanent --zone=public --add-port=10250/tcp
#  - firewall-cmd --permanent --zone=public --add-port=2379-2380/tcp
#  - firewall-cmd --permanent --zone=public --add-port=30000-32767/tcp
#  # masquerade needs to be enabled for k8s 1.19 https://github.com/rancher/rancher/issues/28840#issuecomment-756714369
#  - firewall-cmd --add-masquerade --permanent
#  - firewall-cmd --reload
#   - systemctl enable --now docker
#   - usermod -aG docker sles
  # Hack to write /root/.bashrc with exports and aliases - this is for k3s
  - echo 'IyEvYmluL3NoCmV4cG9ydCBLVUJFQ09ORklHPS9ldGMvcmFuY2hlci9rM3MvazNzLnlhbWwKYWxpYXMgaz1rdWJlY3RsCmlmIFsgLXggIiQoY29tbWFuZCAtdiBrdWJlY3RsKSIgXTsgdGhlbgogIHNvdXJjZSA8KGt1YmVjdGwgY29tcGxldGlvbiBiYXNoKQogIHNvdXJjZSA8KGt1YmVjdGwgY29tcGxldGlvbiBiYXNoIHwgc2VkIHMva3ViZWN0bC9rL2cpCmZpCgo=' | base64 -d - | tee /root/.bashrc | tee -a /home/sles/.bashrc
#  - /usr/bin/sed -i '/^GRUB_TERMINAL\b/ s/=.*/="serial"' /etc/default/grub
#  - /usr/bin/sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT\b/ s/=.*/="rw systemd.show_status=1 console=hvc0,115200"' /etc/default/grub
  - update-bootloader


final_message: "The system is finally up, after $UPTIME seconds"
