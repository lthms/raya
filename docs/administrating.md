# Administrating the cluster

!!! note

    You need to have access to one of the authorized SSH keys to administrate
    the cluster. As a reminder, they are provisioned at boot time from [a list
    of GitHub handles](cluster-provisioning.md#users).

For now, the control plane API endpoint is only reachable from within one of
the VMs, as its bind address is its private IP (that is,
`local.control_plane_private_ip = 10.0.1.10`, see [Private network](network.md)).

Assuming `$cp_public_ip` is the public IP of the control plane, then the most
straightforward way to reach its API is to establish an SSH tunnel to make port
`:6443` available on our workstation.

```bash
ssh -N -L 6443:10.0.1.10:6443 core@$cp_public_ip
```

!!! warning

    `-N` tells `ssh` not to open a shell on the remote machine. As a
    consequence, the command has no visible effect on the terminal you are
    running it in.

While this command is running, `https://127.0.0.1:6443` is tunneled through the
SSH connection directly to the API.

The missing piece is a kubeconfig file, which you can create by fetching
`/etc/rancher/k3s/k3s.yaml` and changing the `server` directive to point to
your SSH tunnel.

```bash
ssh core@$cp_public_ip sudo cat /etc/rancher/k3s/k3s.yaml \
  | sed -E 's#^( *server:).*#\1 https://127.0.0.1:6443#' > raya.yaml
```

!!! warning

    The resulting `raya.yaml` gives admin credentials over the cluster. Take
    care not to share it with the world by mistake.

Once this is done, you can interact with `raya`’s cluster, for instance with
`kubectl`.

```bash
KUBECONFIG=raya.yaml kubectl get nodes
```
