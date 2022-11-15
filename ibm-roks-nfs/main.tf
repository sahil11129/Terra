resource "local_file" "home" {
  content  = "home folder"
  filename = "${path.module}/home/home.txt"
}

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
