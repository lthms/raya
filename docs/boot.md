# Boot sequence

The boot sequence of `raya`’s VMs consists in two distinct phases. The first
one only happens during the first boot directly following the provisioning of
the VM: the OS reads the supplied Ignition config (from `user_data`) and runs
it. The, the regular boot sequence proceeds.

```mermaid
graph TB
  subgraph ignition["Ignition · initramfs · first boot only"]
    fetch["Read config from<br/>hcloud user_data"]
    growfs["Grow the root partition<br/>to fill the disk"]
    run["Run the config"]
    fetch --> growfs --> run
  end

  subgraph systemd["systemd · every boot"]
    tmpfiles["systemd-tmpfiles-setup<br/>restores the SELinux context<br/>of /var/usrlocal/bin"]
    nm["NetworkManager<br/>enp7s0 static · public NIC by DHCP"]
    online(["network-online.target"])
    init["k3s-init.service<br/>writes config.yaml.d/50-public-ip.yaml"]
    k3s["k3s.service<br/>k3s server"]
    tmpfiles --> nm --> online --> init --> k3s
  end

  run --> tmpfiles

  classDef onceOnly stroke-dasharray: 5 5
  class ignition onceOnly
```
