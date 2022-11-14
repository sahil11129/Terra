### Cloud Provider Credentials ####

variable "ibmcloud_api_key" {
  description = "IBM Cloud API Key"
  type        = string
}

# Cloud Provider ID
variable "cloud_provider" {
  description = "Cloud Provider"
  type        = string
  default     = "ibmcloud"
}