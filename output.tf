output "envName" {
  value = "IBMCloud"
}

output "region" {
  description = "Region"
  value = var.region
}

output "projectName" {
  description = "Project name"
  value = local.instance
}

output "projectUrl" {
  description = "Project URL"
  value = "https://console-openshift-console.${data.ibm_container_vpc_cluster.my-cluster.ingress_hostname}"
}

output "dashAppUrl" {
  description = "Sample Dash App URL"
  value = "http://grpc-dash-app-${local.instance}.${data.ibm_container_vpc_cluster.my-cluster.ingress_hostname}"
}

output "cloudAccount" {
  description = "Cloud Account"
  value = var.cloudAccount 
}

output "userEmail" {
  description = "User Email" 
  value = var.user_email
}


