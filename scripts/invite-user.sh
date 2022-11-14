#!/bin/bash

# Exit if any of the intermediate steps fail
set -e

echo $(ibmcloud login --apikey ${API_KEY}) > /dev/null

ibmcloud account user-invite ${EMAIL} --access-groups ${SHARED_GROUP_NAME},${CLUSTER_GROUP_NAME}
