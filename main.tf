# Random cluster name suffix
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  cluster_name = "itzroks-${lower(var.user_id)}-${random_string.suffix.result}"
}

resource "local_file" "home" {
  content  = "home folder"
  filename = "${path.module}/home/home.txt"
}

data "ibm_resource_group" "resource_group" {
  name = var.resource_group_name
}

// get VLAN ids
data "external" "vlan" {
  program = ["bash", "${path.module}/scripts/get-vlan.sh"]
  query = {
    ibmcloud_api_key = var.ibmcloud_api_key
    datacenter       = var.datacenter
  }
}

####### ROKS ##################################
resource "ibm_container_cluster" "cluster" {
  name                    = local.cluster_name
  datacenter              = var.datacenter
  default_pool_size       = var.compute_nodes_count
  machine_type            = var.compute_nodes_flavor
  hardware                = "shared"
  resource_group_id       = data.ibm_resource_group.resource_group.id
  kube_version            = "${var.ocp_version}_openshift"
  public_vlan_id          = data.external.vlan.result.publicVLAN
  private_vlan_id         = data.external.vlan.result.privateVLAN
  force_delete_storage    = true
  tags                    = [var.user_id, var.requestId]
  public_service_endpoint = true

  timeouts {
    create = "3h"
    delete = "3h"
  }
}

### Watson SaaS ################################
resource "ibm_resource_instance" "watson_discovery" {
 name              = "discovery-${lower(var.user_id)}-${random_string.suffix.result}"
 service           = "discovery"
 plan              = "plus"
 location          = lookup(var.ibm_regions_map, var.datacenter).region
 resource_group_id = data.ibm_resource_group.resource_group.id
 tags              = [var.requestId]
 parameters = {
   service-endpoints : "public-and-private"
 }
}

resource "ibm_resource_instance" "watson_assistant" {
  name              = "assistant-${lower(var.user_id)}-${random_string.suffix.result}"
  service           = "conversation"
  plan              = "plus"
  location          = lookup(var.ibm_regions_map, var.datacenter).region
  resource_group_id = data.ibm_resource_group.resource_group.id
  tags              = [var.requestId]
  parameters = {
    service-endpoints : "public-and-private"
  }
}


###### Access Group #############################
resource "ibm_iam_access_group" "cluster_accgrp" {
  name        = "cluster-${local.cluster_name}"
  description = "Cluster Access Group for ${local.cluster_name}"
  depends_on = [
    ibm_container_cluster.cluster
  ]
}

resource "ibm_iam_access_group_policy" "policy1" {
  access_group_id = ibm_iam_access_group.cluster_accgrp.id
  roles           = ["Manager", "Operator", "Viewer"]

  resources {
    service              = "containers-kubernetes"
    resource_instance_id = ibm_container_cluster.cluster.id
  }
}

resource "ibm_iam_access_group_policy" "policy2" {
  access_group_id = ibm_iam_access_group.cluster_accgrp.id
  roles           = ["Operator", "Manager"]

  resources {
    service              = "discovery"
    resource_instance_id = element(split(":", ibm_resource_instance.watson_discovery.id), 7)
  }
}

resource "ibm_iam_access_group_policy" "policy3" {
  access_group_id = ibm_iam_access_group.cluster_accgrp.id
  roles           = ["Operator", "Manager"]

  resources {
    service              = "conversation"
    resource_instance_id = element(split(":", ibm_resource_instance.watson_assistant.id), 7)
  }
}

data "ibm_iam_access_group" "shared_accgroup" {
  access_group_name = var.shared_access_group_name
}

#### Invite user and add to the groups
resource "null_resource" "invite_user" {
  provisioner "local-exec" {
    command = "${path.module}/scripts/invite-user.sh || true"
    environment = {
      HOME               = "${abspath(path.module)}/home"
      API_KEY            = var.ibmcloud_api_key
      SHARED_GROUP_NAME  = var.shared_access_group_name
      CLUSTER_GROUP_NAME = ibm_iam_access_group.cluster_accgrp.name
      EMAIL              = var.user_email
    }
  }
  depends_on = [
    ibm_iam_access_group.cluster_accgrp
  ]
}

# Download kubeconfig for the cluster
resource "null_resource" "kubeconfig" {

  provisioner "local-exec" {
    command = "${path.module}/scripts/get-kubeconfig.sh || true"
    environment = {
      HOME        = "${abspath(path.module)}/home"
      API_KEY     = var.ibmcloud_api_key
      CLUSTERNAME = ibm_container_cluster.cluster.id
    }
  }

  depends_on = [
    ibm_container_cluster.cluster
  ]
}

resource "null_resource" "add_user_rbac" {
  provisioner "local-exec" {
    command = "${path.module}/scripts/add-user-rbac.sh || true"
    environment = {
      HOME    = "${abspath(path.module)}/home"
      EMAIL   = var.user_email
      USER_ID = var.user_id
    }
  }
  depends_on = [
    ibm_container_cluster.cluster,
    null_resource.kubeconfig
  ]
}

# # NFS storage
# module "nfs" {
#   count  = var.nfs > 0 ? 1 : 0
#   #source = "git::ssh://git@github.ibm.com/dte2-0/terraform-modules.git//ibm-roks-nfs"
  
#   source = "git@github.com:sahil11129/Terra.git//ibm-roks-nfs"
#   ibmcloud_api_key = var.ibmcloud_api_key
#   cluster_name     = ibm_container_cluster.cluster.id
#   storage_size     = var.nfs

#   depends_on = [
#     ibm_container_cluster.cluster
#   ]
# }


# resource "local_file" "home" {
#   content  = "home folder"
#   filename = "${path.module}/home/home.txt"
# }

resource "null_resource" "nfs_storage" {
  provisioner "local-exec" {
    command = "./setupStorage.sh || true"
    environment = {
      HOME             = "${abspath(path.module)}/home"
      IBMCLOUD_API_KEY = var.ibmcloud_api_key
      CLUSTERNAME      = var.cluster_name
      STORAGESIZE      = "${var.storage_size}Gi"
    }
    working_dir = "${abspath(path.module)}/scripts"
    on_failure  = continue
  }
}

