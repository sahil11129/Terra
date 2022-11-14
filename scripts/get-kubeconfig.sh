#!/bin/bash

# Exit if any of the intermediate steps fail
set -e

ibmcloud login --apikey ${API_KEY} -r us-south -q || exit 1

ibmcloud plugin install container-service -f

ibmcloud ks cluster config --admin -c ${CLUSTERNAME} -q || exit 1