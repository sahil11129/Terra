# User Input

variable "compute_nodes_count" {
  description = "Worker Node Count"
  type        = number
  default     = 3
}

variable "compute_nodes_flavor" {
  description = "Worker Node Flavor"
  type        = string
  default     = "b3c.4x16"
}

variable "ocp_version" {
  description = "OpenShift Version"
  type        = string
  default     = "4.10"
}

variable "nfs" {
  description = "NFS Size"
  type        = number
  default     = 0
}