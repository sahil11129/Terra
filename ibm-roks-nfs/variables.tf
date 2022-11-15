variable "ibmcloud_api_key" {
  description = "IBM Cloud API Key"
  type = string
}

variable "cluster_name" {
  description = "Cluster Name/ID"
  type = string
}

variable "storage_size" {
  description = "NFS Size"
  type        = number
  default     = 0
}