pipeline {
    agent any
    environment {
        AZURE_CRED = credentials('azure-cred')
        AZURE_CLIENT_ID="$AZURE_CRED_USR"
        AZURE_CLIENT_SECRET="$AZURE_CRED_PSW"
        AZURE_TENANT_ID="84f1e4ea-8554-43e1-8709-f0b8589ea118"
        AZURE_SUBSCRIPTION_ID="28e1e42a-4438-4c30-9a5f-7d7b488fd883"
        AZURE_STORAGE_ACCOUNT="jenkinsmaster1101"
    }
    stages {
        stage('Loggin'){
            steps {
                sh 'echo INIT'

                sh 'az login --service-principal --username $AZURE_CLIENT_ID --password $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID'
                sh 'az account set --subscription $AZURE_SUBSCRIPTION_ID'
                sh 'terraform init -upgrade -backend-config="storage_account_name=$AZURE_STORAGE_ACCOUNT"'
            }
        }
        stage('Formatting'){
            steps {
                sh 'echo FORMATTING'
                sh 'terraform fmt -diff'
            }
        }
        stage('Validation and Scanning'){
            steps {
                sh 'echo VALIDATION AND SCANNING'
                sh 'terraform validate'
            }
        }
        stage('Plan'){
            environment {
                ARM_CLIENT_ID="$AZURE_CLIENT_ID"
                ARM_CLIENT_SECRET="$AZURE_CLIENT_SECRET"
                ARM_TENANT_ID="$AZURE_TENANT_ID"
                ARM_SUBSCRIPTION_ID="$AZURE_SUBSCRIPTION_ID"
                ARM_RESOURCE_PROVIDER_REGISTRATIONS="none"
            }
            steps {
                sh 'echo PLAN'
                sh 'terraform plan'
            }
        }
        // stage('Push and Apply'){
        //     steps {
        //         sh 'echo PUSH'
        //         sh 'terraform push'
        //         sh 'echo APPLY'
        //         sh 'echo (provisioning resource - manual job)'
        //         sh 'terraform apply -auto-approve'
        //     }
        // }
        // stage('Destroy and Push'){
        //     steps {
        //         sh 'echo DESTROY'
        //         sh 'echo (manual job)'
        //         sh 'terraform destroy'
        //     }
        // }
    }
}
