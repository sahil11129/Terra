provider "ibm" {
  region           = "us-south"
  ibmcloud_api_key = var.ibmcloud_api_key
}

provider "ibm" {
  alias = "itz"
  region           = "us-south"
  ibmcloud_api_key = var.ibmcloud_api_key
}