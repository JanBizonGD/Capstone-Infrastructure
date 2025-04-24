import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import jenkins.model.*
pipeline {
    agent any
    environment {
        AZURE_CRED = credentials('azure-cred')
        AZURE_CLIENT_ID='$AZURE_CRED_USR'
        AZURE_CLIENT_SECRET='$AZURE_CRED_PSW'
        TF_VAR_vm_username='adminuser'
        TF_VAR_vm_password='Password123!'
        TF_VAR_db_username='azureuser'
        TF_VAR_db_password='Password123!'
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
                ARM_CLIENT_ID='$AZURE_CLIENT_ID'
                ARM_CLIENT_SECRET='$AZURE_CLIENT_SECRET'
                ARM_TENANT_ID='$AZURE_TENANT_ID'
                ARM_SUBSCRIPTION_ID='$AZURE_SUBSCRIPTION_ID'
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
                ARM_CLIENT_ID='$AZURE_CLIENT_ID'
                ARM_CLIENT_SECRET='$AZURE_CLIENT_SECRET'
                ARM_TENANT_ID='$AZURE_TENANT_ID'
                ARM_SUBSCRIPTION_ID='$AZURE_SUBSCRIPTION_ID'
                ARM_RESOURCE_PROVIDER_REGISTRATIONS="none"
            }
            steps {
                sh 'echo APPLY'
                sh 'terraform apply tfplan'
            }
        }
        stage('Write to file') {
            when {
                expression { params.Action == 'apply' }
            }
            steps {
                script {
                    def ips = sh(script: 'terraform output -json private_ips', returnStdout: true).trim()
                    def uris = sh(script: 'terraform output -raw sql_uri', returnStdout: true).trim()
                    def lb_ip = sh(script: 'terraform output -raw lb_ip', returnStdout: true).trim()
                    writeFile file: 'deploy-info.txt', text: "IPs=${ips}\nURIs=${uris}\nLB_IP=${lb_ip}"
                }
                archiveArtifacts artifacts: 'deploy-info.txt', fingerprint: true
            }
        }
        stage('Add ACR Credential') {
            when {
                expression { params.Action == 'apply' }
            }
            steps {
                script {
                    def credentialId = "acr-cred"

                    def existing = com.cloudbees.plugins.credentials.CredentialsProvider.lookupCredentials(
                        com.cloudbees.plugins.credentials.common.StandardCredentials.class,
                        Jenkins.instance,
                        null,
                        null
                    ).find { it.id == credentialId }

                    if (!existing) {
                        def username =  sh (
                            script: 'terraform output -raw acr_username',
                            returnStdout: true
                        ).trim()
                        def password = sh (
                            script: 'terraform output -raw acr_password',
                            returnStdout: true
                        ).trim()
                        def description = "Service principal credentials for connection to container registry deployed on azure"
                        def credentials = new UsernamePasswordCredentialsImpl(
                            CredentialsScope.GLOBAL,
                            credentialId,
                            description,
                            username,
                            password
                        )

                        SystemCredentialsProvider.getInstance().getStore().addCredentials(Domain.global(), credentials)
                        SystemCredentialsProvider.getInstance().save()
                        echo "Credential '${credentialId}' added."
                    } else {
                        echo "Credential '${credentialId}' already exists."
                    }
                }
            }
        }
        stage('Add Instance Credential') {
            when {
                expression { params.Action == 'apply' }
            }
            steps {
                script {
                    def credentialId = "deploy-group-cred"

                    def existing = com.cloudbees.plugins.credentials.CredentialsProvider.lookupCredentials(
                        com.cloudbees.plugins.credentials.common.StandardCredentials.class,
                        Jenkins.instance,
                        null,
                        null
                    ).find { it.id == credentialId }

                    if (!existing) {
                        def username = sh (
                            script: 'terraform output -raw instance_username',
                            returnStdout: true
                        ).trim()
                        def password = sh (
                            script: 'terraform output -raw instance_password',
                            returnStdout: true
                        ).trim()
                        def description = "Service principal credentials for connection to container registry deployed on azure"
                        def credentials = new UsernamePasswordCredentialsImpl(
                            CredentialsScope.GLOBAL,
                            credentialId,
                            description,
                            username,
                            password
                        )

                        SystemCredentialsProvider.getInstance().getStore().addCredentials(Domain.global(), credentials)
                        SystemCredentialsProvider.getInstance().save()
                        echo "Credential '${credentialId}' added."
                    } else {
                        echo "Credential '${credentialId}' already exists."
                    }
                }
            }
        }
        stage('Destroy'){
            when {
                expression { params.Action == 'destroy' }
            }
            environment {
                ARM_CLIENT_ID='$AZURE_CLIENT_ID'
                ARM_CLIENT_SECRET='$AZURE_CLIENT_SECRET'
                ARM_TENANT_ID='$AZURE_TENANT_ID'
                ARM_SUBSCRIPTION_ID='$AZURE_SUBSCRIPTION_ID'
                ARM_RESOURCE_PROVIDER_REGISTRATIONS="none"
            }
            steps {
                sh 'echo DESTROY'
                sh 'terraform destroy -var=\'resource_group_name=$AZURE_RESOURCE_GROUP\' -auto-approve'
            }
        }
    }
}
