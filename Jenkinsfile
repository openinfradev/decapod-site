@Library('jenkins-pipeline-library@main') _

pipeline {
  agent {
    node {
      label 'openstack-slave-pangyo'
      customWorkspace "workspace/${env.JOB_NAME}/${env.BUILD_NUMBER}"
    }
  }

  parameters {
    string(name: 'APPS',
      defaultValue: 'lma,service-mesh',
      description: 'Apps to deploy on k8s cluster(comma-seperated list)'
    )
    string(name: 'SITE_NAME',
      defaultValue: 'hanu-reference',
      description: 'Site name for decapod-manifest'
    )
    string(name: 'BASE_BRANCH',
      defaultValue: 'v1.0',
      description: 'Branch name for decapod-base'
    )
    string(name: 'SITE_BRANCH',
      defaultValue: 'main',
      description: 'Branch name for decapod-site'
    )
    string(name: 'ADMIN_NODE_IP',
      defaultValue: '',
      description: 'Exising k8s cluster\'s admin node IP. The node can be connected with jenkins.key in taco production env.')
    booleanParam(name: 'OFFLINE',
      defaultValue: false,
      description: 'Is is an offline environment?'
    )
    booleanParam(name: 'CLEANUP',
      defaultValue: false,
      description: 'delete VM once job is finished?'
    )
  }

  stages {
    stage ('Prepare manifest') {
      steps {
        script {
          ADMIN_NODE_IP = params.ADMIN_NODE_IP

          sh """
            git clone https://github.com/openinfradev/taco-gate-inventories.git
            git clone -b v1.0  https://github.com/openinfradev/decapod-flow.git
            cp taco-gate-inventories/config/pangyo-clouds.yml ./clouds.yaml
          """

          BRANCH_NAME = "jenkins-deploy-${env.BUILD_NUMBER}"
          sh """
            git clone -b $SITE_BRANCH https://github.com/openinfradev/decapod-site.git
            cd decapod-site && git checkout -b $BRANCH_NAME

            git push origin $BRANCH_NAME
            cd ..
          """
        }
      }
    }
    stage ('Run argo workflow') {
      steps {
        script {
          sh """
            cp /opt/jenkins/.ssh/jenkins-slave-hanukey ./jenkins.key
            scp -o StrictHostKeyChecking=no -i jenkins.key -r decapod-flow/workflows/* taco-gate-inventories/scripts/deployApps.sh taco@$ADMIN_NODE_IP:/home/taco/
            ssh -o StrictHostKeyChecking=no -i jenkins.key taco@$ADMIN_NODE_IP chmod 0755 /home/taco/deployApps.sh
          """

          if (params.OFFLINE) {
            echo "This is offline environment."
            sh """
              ssh -o StrictHostKeyChecking=no -i jenkins.key taco@$ADMIN_NODE_IP /home/taco/deployApps.sh --apps ${params.APPS} --site ${params.SITE_NAME} --site-branch $BRANCH_NAME --base-branch ${params.BASE_BRANCH} --offline
            """
          } else {
            echo "This is online environment."
            sh """
              ssh -o StrictHostKeyChecking=no -i jenkins.key taco@$ADMIN_NODE_IP /home/taco/deployApps.sh --apps ${params.APPS} --site ${params.SITE_NAME} --site-branch $BRANCH_NAME --base-branch ${params.BASE_BRANCH}
            """
          }
        }
      }
    }
    stage ('Validate LMA') {
      when {
        expression { params.APPS.contains("lma") }
      }
      steps {
        script {
            def job = build(
              job: "validate-lma",
              parameters: [
                string(name: 'KUBERNETES_CLUSTER_IP', value: "${ADMIN_NODE_IP}")
              ],
              propagate: true
            )
            res = job.getResult()
            println("Validate-lma Result: ${res}")
        }
      }
    }
  }
  post {
    always {
      script {
        sh """
          echo "Delete temporary branch"
          cd decapod-site && git push origin :$BRANCH_NAME
        """
      }
    }
    success {
      script {
        if ( params.CLEANUP == true ) {
          deleteOpenstackVMs(vmNamePrefixRand, "", 'openstack-pangyo')
        } else {
          echo "Skipping VM cleanup.."
        }
      }
    }
  }
}
