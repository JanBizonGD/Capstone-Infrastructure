pipeline {
    agent any
    environment {
        AZURE_CRED = credentials('azure-cred')
        AZURE_CLIENT_ID="$AZURE_CRED_USR"
        AZURE_CLIENT_SECRET="$AZURE_CRED_PSW"
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
                sh 'echo APPLY'
                sh 'terraform apply tfplan'
            }
        }
        stage('Add ACR Credential') {
            when {
                expression { params.Action == 'apply' }
            }
            steps {
                script {
                    import com.cloudbees.plugins.credentials.*
                    import com.cloudbees.plugins.credentials.domains.*
                    import com.cloudbees.plugins.credentials.impl.*
                    import jenkins.model.*

                    def credentialId = "acr-cred"

                    def existing = com.cloudbees.plugins.credentials.CredentialsProvider.lookupCredentials(
                        com.cloudbees.plugins.credentials.common.StandardCredentials.class,
                        Jenkins.instance,
                        null,
                        null
                    ).find { it.id == credential_id }

                    if (!existing) {
                        username = "$(terraform output -raw acr_username)"
                        password = "$(terraform output -raw acr_password)"
                        description = "Service principal credentials for connection to container registry deployed on azure"
                        credentials = new UsernamePasswordCredentialsImpl(
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
                    import com.cloudbees.plugins.credentials.*
                    import com.cloudbees.plugins.credentials.domains.*
                    import com.cloudbees.plugins.credentials.impl.*
                    import jenkins.model.*

                    def credentialId = "deploy-group-cred"

                    def existing = com.cloudbees.plugins.credentials.CredentialsProvider.lookupCredentials(
                        com.cloudbees.plugins.credentials.common.StandardCredentials.class,
                        Jenkins.instance,
                        null,
                        null
                    ).find { it.id == credential_id }

                    if (!existing) {
                        username = "$(terraform output -raw instance_username)"
                        password = "$(terraform output -raw instance_password)"
                        description = "Service principal credentials for connection to container registry deployed on azure"
                        credentials = new UsernamePasswordCredentialsImpl(
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
