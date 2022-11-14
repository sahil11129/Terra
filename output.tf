output "cluster_id" {
  description = "Cluster ID"
  value       = ibm_container_cluster.cluster.id
}

output "cluster_name" {
  description = "Cluster Name"
  value       = ibm_container_cluster.cluster.name
}

output "cluster_url" {
  description = "Cluster URL"
  value       = "https://cloud.ibm.com/kubernetes/clusters/${ibm_container_cluster.cluster.id}/overview?bss_account=${data.ibm_iam_access_group.shared_accgroup.id}"
}

output "server_url" {
  description = "Cluster Name"
  value       = ibm_container_cluster.cluster.server_url
}

output "ocp_version" {
  description = "OCP Version"
  value       = ibm_container_cluster.cluster.kube_version
}

# Special vars
output "desktop" {
  description = "ROKS Cluster"
  value       = "https://cloud.ibm.com/kubernetes/clusters/${ibm_container_cluster.cluster.id}/overview?bss_account=${data.ibm_iam_access_group.shared_accgroup.id}"
}

output "environmentid" {
  value = ibm_container_cluster.cluster.id
}

output "envName" {
  value = ibm_container_cluster.cluster.name
}

output "compute_nodes_flavor" {
  description = "Worker Node Flavor"
  value       = var.compute_nodes_flavor
}


output "assitant_url" {
  description = "Watson Assistant"
  value       = "https://cloud.ibm.com/services/conversation/${urlencode(ibm_resource_instance.watson_assistant.id)}?paneId=manage&bss_account=${data.ibm_iam_access_group.shared_accgroup.id}"
}

output "discovery_url" {
  description = "Watson Discovery"
  value       = "https://cloud.ibm.com/services/conversation/${urlencode(ibm_resource_instance.watson_discovery.id)}?paneId=manage&bss_account=${data.ibm_iam_access_group.shared_accgroup.id}"
}
