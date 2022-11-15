#!/bin/bash

# LOGGING Variables
RED='\033[0;31m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GREEN='\033[0;32m'
NRM='\033[0m'

log() {
    # inputs:
    # $1 Log Level [DEBUG,INFO,ERROR,WARN,FATAL]
    # $2 Message string
    case $1 in 
      DEBUG )
        printf "${WHITE}[DEBUG] $2 ${NRM}\n"
        ;;
      INFO )
        printf "${GREEN}[INFO] $2 ${NRM}\n"
        ;;
      ERROR )
        printf "${RED}[ERROR] $2 ${NRM}\n"
        ;;
      WARN )
        printf "${CYAN}[WARN] $2 ${NRM}\n"
        ;;
      FATAL)
        printf "${RED}[FATAL] $2 ${NRM}\n"
        ;;
      * )
        printf "${GREEN}[INFO] $2 ${NRM}\n"
        ;;
    esac
}

log "INFO" "app: setupStorage"

# export HOME="/root"
log "DEBUG" "HOME: $HOME"

# login ibmcloud and cluster
log "INFO" "Cloud Account Login"
log "DEBUG" "ibmcloud login -r us-south -q"
ibmcloud login -r us-south -q || exit 1

log "DEBUG" "Installing the Kubernetes Service plug-in..."
ibmcloud plugin install container-service -f

log "DEBUG" "IBMCLOUD CLI Plugins..."
ibmcloud plugin list 

log "INFO" "Cluster Login"
log "DEBUG" "ibmcloud ks cluster config --admin -c ${CLUSTERNAME} -q"
ibmcloud ks cluster config --admin -c ${CLUSTERNAME} -q || exit 1

NFSNAMESPACE="dtenfs"
PVCNAME="dte-nfs-storage"
STORAGESIZE=${STORAGESIZE} # this needs to be set at runtime by the operator

log "DEBUG" "NFSNAMESPACE: $NFSNAMESPACE"
log "DEBUG" "PVCNAME: $PVCNAME"
log "DEBUG" "STORAGESIZE: $STORAGESIZE"

# create namespace
log "INFO" "Create namespace"
oc create namespace ${NFSNAMESPACE}
oc project ${NFSNAMESPACE}

# create storage
log "INFO" "Request storage volume"
cat <<EOF | oc create -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
 name: dte-nfs-storage
 labels:
   billingType: hourly
spec:
 accessModes:
   - ReadWriteMany
 resources:
   requests:
     storage: ${STORAGESIZE}
 storageClassName: ibmc-file-gold
EOF

#log "DEBUG" "$(cat assets/mnfspvc.yaml)"
#oc create -f assets/mnfspvc.yaml

log "INFO" "Verify PVC Active"
# check for PVC
max_retry=30
retry=0
pvcsuccess="no"
while [ ${retry} -lt ${max_retry} ]; do 
    pvcready=$(oc get pvc ${PVCNAME} -ojson | jq -r '.status.phase')
    if [[ "$pvcready" != "Bound" ]]; then
        (( retry = retry + 1 ))
        log "INFO" "PVC Status: $pvcready"
        sleep 60
    else
        log "INFO" "PVC Status: $pvcready"
        pvcsuccess="yes"
        break
    fi
done

if [[ "$pvcsuccess" == "no" ]]; then 
    log "FATAL" "error=dte-nfs-provisioning failed - pvc not ready in time"
    exit 1
fi 

# get NSF Server Data
log "INFO" "NFS Server Info"
volumename=$(oc get pvc ${PVCNAME} -ojson | jq -r '.spec.volumeName')
log "INFO" "Volume: $volumename"
nfspath=$(oc get pv $volumename -ojson | jq -r '.spec.nfs.path')
log "INFO" "NFS Path: $nfspath"
nfsserver=$(oc get pv $volumename -ojson | jq -r '.spec.nfs.server')
log "INFO" "NFS Server: $nfsserver"

#log "DEBUG" "$(cat assets/deplopyment.yaml)"

# Install
log "INFO" "Deploy nfs-provisioner"
oc create -f assets/rbac.yaml 
oc adm policy add-scc-to-user hostmount-anyuid system:serviceaccount:dtenfs:nfs-client-provisioner # needed for oc

cat <<EOF | oc create -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dte-nfs-provisioner #DTE specific name
  labels:
    app: dte-nfs-provisioner
  namespace: dtenfs
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: dte-nfs-provisioner
  template:
    metadata:
      labels:
        app: dte-nfs-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: dtenfs/dte-nfs-provisioner
            - name: NFS_SERVER
              value: ${nfsserver}
            - name: NFS_PATH
              value: ${nfspath}
      volumes:
        - name: nfs-client-root
          nfs:
            server: ${nfsserver}
            path: ${nfspath}
EOF

oc create -f assets/class.yaml 
sleep 60
log "INFO" "Pod info"
oc get pod -l app=dte-nfs-provisioner

# Set default storage
log "INFO" "Set default storage"
oc annotate storageclass ibmc-block-gold storageclass.kubernetes.io/is-default-class-
oc annotate storageclass managed-nfs-storage storageclass.kubernetes.io/is-default-class="true"


log "INFO" "Storage Classes..."
oc get storageclass

log "INFO" "Complete"
exit 0
