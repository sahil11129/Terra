# dte-managed-nfs

> install managed nfs for DTE based roks clusters. this allows us to use one big nfs volume in ibmcloud vs a lot of little ones which affect our quota.

## Install on a cluster

1. Log in to the ibm cloud ROKS cluster (need cluster-admin rights)
2. Clone this report (container coming soon)
3. Set the following environment var "STORAGESIZE" to a size for the storage to create (i.e. 100Gi = 100 Gigabytes).
4. From the root of this repo run `./setupStorage`. It should take 5 minutes to run and will setup a nfs client provisioning in the dtenfs namespace. The Default storage class will be reset to "managed-nfs-storage". At the end of the script, you should see a Running pod starting with the name "dte-nfs-provisioner-". If not running, report this as an issue.
