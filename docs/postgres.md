# Shared Postgres Instance

For convenience, `raya` provides a Postgres instance that can be used by any
workloads needing a database.

## The cnpg-system namespace

This is the namespace where the [CloudNativePG] machinery lives. CloudNativePG
is a Kubernetes operator owning Postgres instances defined as `Cluster`
objects. From that resource, it creates the pods and their external volumes,
and abstracts them away behind `Services` (`$clusterName-rw` and
`$clusterName-ro`).

CloudNativePG is installed via `HelmRepository` and `HelmRelease` objects which
get [reconciled by Flux](flux-system.md) when they are updated in `raya`’s
repository. CloudNativePG supports many advanced features of Postgres, notably
related to high-availability (*e.g.*, running several replicas with a primary
instance to survive a database defect). We use only the most basic features for
now.

Additionally, we have installed the [Barman Cloud] plugin. This plugin enables
us to ensure we can restore our Postgres instance from nightly backups and WAL
archives. Barman Cloud is vendored in `raya`’s repository because it is only
published via a static URL (no Helm releases available).

[Barman Cloud]: https://cloudnative-pg.io/plugin-barman-cloud/
[CloudNativePG]: https://cloudnative-pg.io/

## The postgresql namespace

We have defined one cluster named `postgresql`, which is a single instance with
10Gi of storage. The cluster is configured with `isWALArchiver: true` and
pointing to a r2 object store hosted by Cloudflare, and nightly backups with a
30-day retention policy. This means the databases can be restored in a new
cluster with little to no loss of data, in case something wrong happens to
`postgresql`.

In addition, we have deployed `ext-postgres-operator`. This is a convenient
operator which allows workloads to request the creation of users and databases
using specific custom resources.

```yaml
apiVersion: db.movetokube.com/v1alpha1
kind: Postgres
metadata:
  name: hello
spec:
  database: hello
---
apiVersion: db.movetokube.com/v1alpha1
kind: PostgresUser
metadata:
  name: hello
spec:
  role: hello
  database: hello      # the Postgres resource, not the database
  secretName: db-info  # the Secret is `db-info-hello`, `$secretName-$database`
  privileges: OWNER
```

`Postgres` creates the database, `PostgresUser` creates a role inside it and
writes the credentials to a `Secret` next to the workload.

`ext-postgres-operator` is fetched from its official upstream helm repository.
