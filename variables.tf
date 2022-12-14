variable "resource_group_name" {
  description = "Resource Group for Cluster"
  type        = string
  default     = "Sahil-Desai-RG"
}

variable "shared_access_group_name" {
  description = "Shared Access Group for Users"
  type        = string
  default     = "aaron5-ag"
}

# Definded by reservation-ms
variable "datacenter" {
  description = "Datacenter"
  type        = string
  #default     = "tok02"
  default = "dal13"
}

variable "ibm_regions_map" {
  type        = map(any)
  description = "IBM Cloud Region Config"
  default = {
    "dal13" = { region = "us-south" },
    "tok02" = { region = "jp-tok" }

  }
}

variable "user_email" {
  type = string
}

variable "user_id" {
  type = string
}

variable "requestId" {
  type    = string
  default = "NoRequestID"
}

variable "templateId" {
  type    = string
  default = "NoTemplateID"
}

variable "cloudAccount" {
  type    = string
  default = ""
}

variable "cloudTarget" {
  type    = string
  default = ""
}

# variable "ibmcloud_api_key" {
#   description = "IBM Cloud API Key"
#   type = string
# }

 variable "cluster_name" {
   description = "Cluster Name/ID"
   type = string
   default="itzroks-sahil1112-2vscmtnz"
 }

variable "storage_size" {
  description = "NFS Size"
  type        = number
  default     = 0
}
