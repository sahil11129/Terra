#!/bin/bash

# Exit if any of the intermediate steps fail
set -e

oc create user IAM#${EMAIL}

oc create identity IAM:IBMid-${USER_ID}

oc create useridentitymapping IAM:IBMid-${USER_ID} IAM#${EMAIL}

oc adm policy add-cluster-role-to-user cluster-admin IAM#${EMAIL}