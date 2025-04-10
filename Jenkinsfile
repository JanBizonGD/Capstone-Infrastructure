pipeline {
    agent any
    environment {
        AZURE_CRED = credentials('azure-cred')
    }
    stages {
        stage('Loggin'){
            steps {
                sh 'echo INIT'
                sh 'export AZURE_CLIENT_ID=$AZURE_CRED_USR'
                sh 'export AZURE_CLIENT_SECRET=$AZURE_CRED_PSW'
                sh 'export AZURE_TENANT_ID=84f1e4ea-8554-43e1-8709-f0b8589ea118'
                sh 'export AZURE_SUBSCRIPTION_ID=28e1e42a-4438-4c30-9a5f-7d7b488fd883'
                sh 'az login -service-principal --username $AZURE_CLIENT_ID --password $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID'
                sh 'az account set --subscription $AZURE_SUBSCRIPTION_ID'
                sh 'terraform init -backend-config="storage_account_name=jenkinsmaster1101"'
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
            steps {
                sh 'echo PLAN'
                sh 'terraform plan --auto-approve'
            }
        }
        stage('Push and Apply'){
            steps {
                sh 'echo PUSH'
                sh 'terraform push'
                sh 'echo APPLY'
                sh 'echo (provisioning resource - manual job)'
                sh 'terraform apply --auto-approve'
            }
        }
        stage('Destroy and Push'){
            steps {
                sh 'echo DESTROY'
                sh 'echo (manual job)'
                sh 'terraform destroy'
            }
        }
    }
}
