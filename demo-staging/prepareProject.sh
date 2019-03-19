#!/bin/bash
#Enter your project details for detting up the project dependencies
region='{your-region-here}'
zone='{your-zone-here}'

project='{your-project-id}'
projectNumber={your-project-number}

#differentiate this deployment from others
prefix='{desired-domain-name-and-unique-seed-for-bucket-name}'

#user you will be running as
user="{user-you-will-run-as}"

#######################################################################################
### For the purposes of this demo script, you dont need to fill in anything past here
#######################################################################################

#bucket where your terraform state file, passwords and outputs will be stored
bucketName=$prefix'-deployment-staging'

kmsKeyRing=$prefix"-deployment-ring"
kmsKey=$prefix"-deployment-key"

echo $prefix
echo $bucketName
echo $kmsKeyRing
echo $kmsKey

# The files we have to substitute in are:
# backend.tf  clearwaiters.sh  copyBootstrapArtifacts.sh  getDomainPassword.sh  main.tf
sed -i "s/{common-backend-bucket}/$bucketName/g;s/{cloud-project-id}/$project/g;s/{cloud-project-region}/$region/g;s/{cloud-project-zone}/$zone/g;s/{deployment-name}/$prefix/g" backend.tf main.tf clearwaiters.sh copyBootstrapArtifacts.sh getDomainPassword.sh
 
#########################################
#enable the services that we depend upon
##########################################
 for API in compute cloudkms deploymentmanager runtimeconfig cloudresourcemanager iam
 do
         gcloud services enable "$API.googleapis.com" --project $project
 done
 
#create the bucket
 gsutil mb -p $project gs://$bucketName
 gsutil -m cp -r ../powershell/bootstrap/* gs://$bucketName/powershell/bootstrap/
 
DefaultServiceAccount="$projectNumber-compute@developer.gserviceaccount.com"
AdminServiceAccountName="admin-$prefix"
echo AdminServiceAccountName
 
AdminServiceAccount="$AdminServiceAccountName@$project.iam.gserviceaccount.com"
echo $AdminServiceAccount
 
gcloud iam service-accounts create $AdminServiceAccountName --display-name "Admin service account for bootstrapping domain-joined servers with elevated permissions" --project $project
gcloud iam service-accounts add-iam-policy-binding $AdminServiceAccount --member "user:$user" --role "roles/iam.serviceAccountUser" --project $project
gcloud projects add-iam-policy-binding $project --member "serviceAccount:$AdminServiceAccount" --role "roles/editor"
 
ServiceAccount=$AdminServiceAccount
echo  "Service Account: [$ServiceAccount]"
 
 
 gcloud kms keyrings create $kmsKeyRing --project $project --location $region
 gcloud kms keys create $kmsKey --project $project --purpose=encryption --keyring $kmsKeyRing --location $region
 
 sed "s/{Usr}/$user/g;s/{SvcAccount}/$ServiceAccount/g" policy.json | tee policy.out
 echo $policy
 
 
 gcloud kms keys set-iam-policy $kmsKey policy.out --project $project --location=$region --keyring=$kmsKeyRing
 rm policy.out
 
 
 sed "s/{Usr}/$user/g;s/{SvcAccount}/$DefaultServiceAccount/g" policy.json | tee policy.out
 gcloud kms keys set-iam-policy $kmsKey policy.out --project $project --location=$region --keyring=$kmsKeyRing
 rm policy.out

