variable "region" {
  type = string
  default = "us-south"
}

variable "user_id" {
  type = string
}

variable "user_email" {
  type = string
}

variable "resource_group" {
  type = string
}

variable "roks_cluster" {
  type = string
}

variable "cloudAccount" {
  type = string
}

variable "ibm_entitlement_key" {
  type = string
}

variable "etcdctl_api" {
  type = string
}

variable "etcdctl_endpoints" {
  type = string
}

variable "etcdctl_user" {
  type = string
}

variable "cdb_deployment_id" {
  type = string
}

variable "cos_instance_name" {
  type = string
}

variable "sample_cos_bucket_name" {
  type = string
}

variable "sample_cos_bucket_key" {
  type = string
}
