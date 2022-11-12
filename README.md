# Watson Assistant terraform module

Provisions an instance of Watson Assistant in the account and optionally binds the 
service to a namespace in a cluster via a secret.

## Example usage

```terraform-hcl
module "dev_infrastructure_watsonassistant" {
  source = "github.com/ibm-garage-cloud/terraform-service-watsonassistant?ref=v1.0.0"

  resource_group_name = module.dev_cluster.resource_group_name
  resource_location   = module.dev_cluster.region
  cluster_id          = module.dev_cluster.id
  namespaces          = module.dev_cluster_namespaces.release_namespaces
  namespace_count     = var.release_namespace_count
  name_prefix         = var.name_prefix
  tags                = []
  plan                = "standard"
}
```
