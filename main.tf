# Random project suffix
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "random_string" "etcd-user-password" {
  length  = 16
  special = false
  upper   = false
}

locals {
    instance = lower("IBMid-${var.user_id}-${random_string.suffix.result}")
}

#
# access group
#
resource "ibm_iam_access_group" "accgrp" {
  name        = local.instance
}

#
# resource group
#
data "ibm_resource_group" "rsrcgrp" {
  name = var.resource_group
}

# the Kubernetes cluster
data "ibm_container_vpc_cluster" "my-cluster" {
  name = var.roks_cluster
}

#
# COS instance
#
data "ibm_resource_instance" "cos-instance" {
  name     = var.cos_instance_name
  location = "global"
  service  = "cloud-object-storage"
}

#
# access group policies
#
resource "ibm_iam_access_group_policy" "policy" {
  access_group_id = ibm_iam_access_group.accgrp.id
  roles        = ["Writer", "Viewer"]

  resource_attributes {
    name  = "resourceGroupId"
    value = data.ibm_resource_group.rsrcgrp.id
  }
  
  resource_attributes {
    name  = "region"
    value = var.region
    operator = "stringEquals"
  }

  resource_attributes {
    name  = "serviceName"
    value = "containers-kubernetes"
  }

  resource_attributes {
    name  = "serviceInstance"
    value = data.ibm_container_vpc_cluster.my-cluster.id
    operator = "stringEquals"
  }

  resource_attributes {
    name  = "namespace"
    value = local.instance
  }
}

resource "ibm_iam_access_group_policy" "policy2" {
  access_group_id = ibm_iam_access_group.accgrp.id
  roles           = ["Viewer"]
  resources {
    resource_type = "resource-group"
    resource      = data.ibm_resource_group.rsrcgrp.id
  }
}

#
# service credential for sample COS bucket
#
data "ibm_resource_key" "sample_cos_bucket_key" {
  name                  = var.sample_cos_bucket_key
  resource_instance_id  = data.ibm_resource_instance.cos-instance.id
}

#
# COS bucket for user-provided models
#
resource "ibm_cos_bucket" "my-bucket" {
  bucket_name          = local.instance
  resource_instance_id = data.ibm_resource_instance.cos-instance.id
  region_location      = var.region
  storage_class        = "standard"
}

#
# service id
#
resource "ibm_iam_service_id" "my-bucket-sid" {
  name = local.instance
}

#
# Invite user and assign IAM policy via API call
#
resource "null_resource" "invite_user" {
  triggers = {
    ibmcloud_api_key  = var.ibmcloud_api_key
    iam_id            = "IBMid-${var.user_id}"
    user_email        = var.user_email
    project_name      = local.instance
    region            = var.region
    roks_cluster      = var.roks_cluster
    access_group_id   = local.instance
    ibm_entitlement_key = var.ibm_entitlement_key
    cdb_deployment_id = var.cdb_deployment_id
    etcdctl_api       = var.etcdctl_api
    etcdctl_endpoints = var.etcdctl_endpoints
    etcdctl_user      = var.etcdctl_user
    user              = local.instance
    password          = random_string.etcd-user-password.result
    cos_instance_id   = data.ibm_resource_instance.cos-instance.id
    sample_cos_bucket_name          = var.sample_cos_bucket_name
    sample_bucket_access_key_id     = nonsensitive(data.ibm_resource_key.sample_cos_bucket_key.credentials["cos_hmac_keys.access_key_id"])
    sample_bucket_secret_access_key = nonsensitive(data.ibm_resource_key.sample_cos_bucket_key.credentials["cos_hmac_keys.secret_access_key"])
  }

  provisioner "local-exec" {
    command = <<EOT
      ibmcloud login -r "${self.triggers.region}" --apikey ${self.triggers.ibmcloud_api_key}
      ibmcloud config --check-version=false
      ibmcloud account user-invite ${self.triggers.user_email}
      ibmcloud iam access-group-user-add "${self.triggers.access_group_id}" "${self.triggers.user_email}"  
      ibmcloud oc cluster config -c ${self.triggers.roks_cluster} --admin

      # Create a new project
      oc new-project ${self.triggers.project_name}

      # Configure image pull secret
      oc create secret docker-registry ibm-entitlement-key -n ${self.triggers.project_name} \
        --docker-server=cp.icr.io \
        --docker-username="cp" \
        --docker-password="${self.triggers.ibm_entitlement_key}"
      
      # Prepare etcdctl
      ./scripts/etcdctl-install
      export PATH="/tmp/etcd-download-test:$PATH"

      ibmcloud plugin install cloud-databases -f
      ibmcloud cdb cacert ${self.triggers.cdb_deployment_id} -s

      export ETCDCTL_API="${self.triggers.etcdctl_api}"
      export ETCDCTL_CACERT="$(ibmcloud cdb cacert ${self.triggers.cdb_deployment_id} -j | jq -r '."connection"."cli"."certificate"."name"')"
      export ETCDCTL_ENDPOINTS="${self.triggers.etcdctl_endpoints}"
      export ETCDCTL_USER="${self.triggers.etcdctl_user}"

      env | grep ^ETCDCTL
      cat $ETCDCTL_CACERT

      # Create etcd user
      etcdctl user add ${self.triggers.user}:${self.triggers.password}
      etcdctl role add ${self.triggers.user}
      etcdctl role grant-permission ${self.triggers.user} readwrite /${self.triggers.user}/ --prefix=true
      etcdctl user grant-role ${self.triggers.user} ${self.triggers.user}    

      # Create a secret for accessing etcd
      echo "\
{\
  \"endpoints\": \"${self.triggers.etcdctl_endpoints}\",\
  \"root_prefix\": \"/${self.triggers.user}/\",\
  \"certificate_file\": \"ca.crt\",\
  \"userid\": \"${self.triggers.user}\",\
  \"password\": \"${self.triggers.password}\"\
}" > /tmp/etcd-config-${self.triggers.user}.json

      oc create secret generic model-serving-etcd \
        --from-file=etcd_connection=/tmp/etcd-config-${self.triggers.user}.json \
        --from-file=ca.crt=$ETCDCTL_CACERT

      # Install the WML Serving Operator
      cat ./scripts/wml-serving-operator-group.yaml | sed "s/__NAMESPACE__/${self.triggers.project_name}/" | oc create -f -
      cat ./scripts/wml-serving-operator-catalog-subscription.yaml | sed "s/__NAMESPACE__/${self.triggers.project_name}/" | oc create -f -

      # Create a WmlServing Instance with Watson NLP Runtime support
      oc tag openshift/watson-nlp-runtime:latest ${self.triggers.project_name}/watson-nlp-runtime:latest
      #oc tag openshift/model-mesh:latest ${self.triggers.project_name}/model-mesh:latest
      #cat ./scripts/model-serving-config.yaml | sed "s/__NAMESPACE__/${self.triggers.project_name}/" | oc create -f -
      cat ./scripts/wml-serving.yaml | sed "s/__NAMESPACE__/${self.triggers.project_name}/" | oc create -f -
      cat ./scripts/watson-nlp-runtime.yaml | sed "s/__NAMESPACE__/${self.triggers.project_name}/" | oc create -f -
      sleep 60

      # Create a service key for accessing the COS bucket
      ibmcloud resource service-key-create "${self.triggers.project_name}" Reader \
        --instance-id "${self.triggers.cos_instance_id}" \
        --service-id "${self.triggers.project_name}" \
        --parameters '{"HMAC":true}'

      # Delete the existing policy
      ibmcloud iam service-policy-delete -f \
        ${self.triggers.project_name} \
        $(ibmcloud iam service-policies ${self.triggers.project_name} --output JSON| jq -r '.[0]."id"')

      # Create policy for write access to the project dedicated COS bucket
      ibmcloud iam service-policy-create ${self.triggers.project_name} \
        --roles Writer \
        --service-name cloud-object-storage \
        --service-instance ${data.ibm_resource_instance.cos-instance.guid} \
        --resource-type bucket \
        --resource ${self.triggers.project_name}

      # Update secret/storage-config
      my_bucket_access_key_id="$(ibmcloud resource service-key ${self.triggers.project_name} --output JSON | \
        jq -r '.[0]."credentials"."cos_hmac_keys"."access_key_id"')"
      my_bucket_secret_access_key="$(ibmcloud resource service-key ${self.triggers.project_name} --output JSON | \
        jq -r '.[0]."credentials"."cos_hmac_keys"."secret_access_key"')"

      X=$(cat ./scripts/sample-cos-bucket.json | \
        sed "s/__ACCESS_KEY_ID__/${self.triggers.sample_bucket_access_key_id}/" | \
        sed "s/__SECRET_ACCESS_KEY__/${self.triggers.sample_bucket_secret_access_key}/" | \
        sed "s/__BUCKET_NAME__/${self.triggers.sample_cos_bucket_name}/" | \
        base64 -w0)
      oc patch secret/storage-config -p '{"data": {"'"${self.triggers.sample_cos_bucket_name}"'": "'"$X"'"}}'

      Y=$(cat ./scripts/sample-cos-bucket.json | \
        sed "s/__ACCESS_KEY_ID__/$my_bucket_access_key_id/" | \
        sed "s/__SECRET_ACCESS_KEY__/$my_bucket_secret_access_key/" | \
        sed "s/__BUCKET_NAME__/${self.triggers.project_name}/" | \
        base64 -w0)
      oc patch secret/storage-config -p '{"data": {"'"${self.triggers.project_name}"'": "'"$Y"'"}}'

      # Create sample predictors
      oc create -f ./scripts/sample-predictors.yaml

      # Deploy sample Dash App
      oc apply -f sample-apps/grpc-dash-app/
      oc expose service dash-app --name=grpc-dash-app --port=8050

      # Create User and RBAC
      oc create user IAM#${self.triggers.user_email}
      oc create identity IAM:${self.triggers.iam_id}
      oc create useridentitymapping IAM:${self.triggers.iam_id} IAM#${self.triggers.user_email}
      oc adm policy add-role-to-user cluster-admin IAM#${self.triggers.user_email} -n ${self.triggers.project_name}
      EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      ibmcloud login -r "${self.triggers.region}" --apikey "${self.triggers.ibmcloud_api_key}"
      ibmcloud config --check-version=false
      ibmcloud oc cluster config -c ${self.triggers.roks_cluster} --admin

      # Delete Openshift project and user
      if [ $(oc get project | grep -i ^${self.triggers.iam_id}- | wc -l) == 1 ]; then
        echo "Only one project left"
        oc delete user IAM#${self.triggers.user_email}
        oc delete identity IAM:${self.triggers.iam_id}
      fi
      oc delete project ${self.triggers.project_name}

      # Delete the service key for accessing the COS bucket
      ibmcloud resource service-key-delete "${self.triggers.project_name}" -f

      # Prepare etcdctl
      ./scripts/etcdctl-install
      export PATH="/tmp/etcd-download-test:$PATH"

      ibmcloud plugin install cloud-databases -f
      ibmcloud cdb cacert ${self.triggers.cdb_deployment_id} -s

      export ETCDCTL_API="${self.triggers.etcdctl_api}"
      export ETCDCTL_CACERT="$(ibmcloud cdb cacert ${self.triggers.cdb_deployment_id} -j | jq -r '."connection"."cli"."certificate"."name"')"
      export ETCDCTL_ENDPOINTS="${self.triggers.etcdctl_endpoints}"
      export ETCDCTL_USER="${self.triggers.etcdctl_user}"

      env | grep ^ETCDCTL
      cat $ETCDCTL_CACERT

      # Delete etcd user, role and keys
      etcdctl user del ${self.triggers.user}
      etcdctl role del ${self.triggers.user}
      etcdctl del /${self.triggers.user}/*
      etcdctl del /${self.triggers.user}
    EOT
  }

  depends_on = [
    ibm_iam_access_group.accgrp,
    ibm_cos_bucket.my-bucket
  ]
}

