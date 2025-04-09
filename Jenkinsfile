pipeline {
    agent any
    stages {
        stage('Loggin'){
            steps {
                sh 'echo INIT'
                sh 'terraform init -backend-config="state.config" --auto-approve'
            }
        }
        stage('Formatting'){
            steps {
                sh 'echo FORMATTING'
                sh 'terraform fmt -diff --auto-approve'
            }
        }
        stage('Validation and Scanning'){
            steps {
                sh 'echo VALIDATION AND SCANNING'
                sh 'terraform validate --auto-approve'
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
