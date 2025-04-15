pipeline {
    agent any
    environment {
        AZURE_CRED = credentials('azure-cred')
        AZURE_CLIENT_ID='$AZURE_CRED_USR'
        AZURE_CLIENT_SECRET='$AZURE_CRED_PSW'
        // AZURE_TENANT_ID="84f1e4ea-8554-43e1-8709-f0b8589ea118"
        // AZURE_SUBSCRIPTION_ID="9734ed68-621d-47ed-babd-269110dbacb1"
        // AZURE_STORAGE_ACCOUNT="jenkinsmaster7989"
        // AZURE_RESOURCE_GROUP="1-c27c81ae-playground-sandbox"
    }
    stages {
        stage('Loggin'){
            when {
                expression { params.Action != 'destroy' }
            }
            steps {
                sh 'echo INIT'

                sh 'az login --service-principal --username $AZURE_CLIENT_ID --password $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID'
                sh 'az account set --subscription $AZURE_SUBSCRIPTION_ID'
                sh 'terraform init -input=false -backend-config="storage_account_name=$AZURE_STORAGE_ACCOUNT"'
            }
        }
        stage('Formatting'){
            when {
                expression { params.Action != 'destroy' }
            }
            steps {
                sh 'echo FORMATTING'
                sh 'terraform fmt -diff'
            }
        }
        stage('Validation and Scanning'){
            when {
                expression { params.Action != 'destroy' }
            }
            steps {
                sh 'echo VALIDATION AND SCANNING'
                sh 'terraform validate'
            }
        }
        stage('Plan'){
            when {
                expression { params.Action != 'destroy' }
            }
            environment {
                ARM_CLIENT_ID="$AZURE_CLIENT_ID"
                ARM_CLIENT_SECRET="$AZURE_CLIENT_SECRET"
                ARM_TENANT_ID="$AZURE_TENANT_ID"
                ARM_SUBSCRIPTION_ID="$AZURE_SUBSCRIPTION_ID"
                ARM_RESOURCE_PROVIDER_REGISTRATIONS="none"
            }
            steps {
                sh 'echo PLAN'
                sh 'terraform plan -input=false -out=tfplan -var="resource_group_name=$AZURE_RESOURCE_GROUP"'
            }
        }
        stage('Apply'){
            when {
                expression { params.Action == 'apply' }
            }
            environment {
                ARM_CLIENT_ID="$AZURE_CLIENT_ID"
                ARM_CLIENT_SECRET="$AZURE_CLIENT_SECRET"
                ARM_TENANT_ID="$AZURE_TENANT_ID"
                ARM_SUBSCRIPTION_ID="$AZURE_SUBSCRIPTION_ID"
                ARM_RESOURCE_PROVIDER_REGISTRATIONS="none"
            }
            steps {
                // sh 'echo PUSH'
                // sh 'terraform push'
                sh 'echo APPLY'
                sh 'terraform apply tfplan'
            }
        }
        stage('Destroy'){
            when {
                expression { params.Action == 'destroy' }
            }
            environment {
                ARM_CLIENT_ID="$AZURE_CLIENT_ID"
                ARM_CLIENT_SECRET="$AZURE_CLIENT_SECRET"
                ARM_TENANT_ID="$AZURE_TENANT_ID"
                ARM_SUBSCRIPTION_ID="$AZURE_SUBSCRIPTION_ID"
                ARM_RESOURCE_PROVIDER_REGISTRATIONS="none"
            }
            steps {
                sh 'echo DESTROY'
                sh 'terraform destroy -var="resource_group_name=$AZURE_RESOURCE_GROUP" -auto-approve'
            }
        }
    }
}
