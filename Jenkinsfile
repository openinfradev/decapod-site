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
      defaultValue: 'lma',
      description: 'Apps to deploy on k8s cluster(comma-seperated list)'
    )
    string(name: 'SITE_NAME',
      defaultValue: 'hanu-reference',
      description: 'Site name for decapod-manifest'
    )
    string(name: 'DECAPOD_MANIFEST_BRANCH',
      defaultValue: 'main',
      description: 'Branch name for decapod-site'
    )
    string(name: 'K8S_VM_NAME',
      defaultValue: '',
      description: 'Name of the Kubernetes VM on which the apps are deployed'
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
          sh """
            git clone -b decapod_v2 https://github.com/openinfradev/taco-gate-inventories.git
            cp taco-gate-inventories/config/pangyo-clouds.yml ./clouds.yaml
          """

          vmNamePrefix = params.K8S_VM_NAME
          if (!params.K8S_VM_NAME) {
            vmNamePrefix = getK8sVmName("k8s_endpoint")
          }

          vmIPs = getOpenstackVMinfo(vmNamePrefix, 'private-mgmt-online', 'openstack-pangyo')
          ceph_mon_host=""

          nodeCount = 0
          def nodeIps = []

          // get API endpoints
          if (vmIPs) {
            vmIPs.eachWithIndex { name, ip, index ->
              nodeCount += 1
              if (index==0) {
                ADMIN_NODE_IP = ip
                print("Found admin node IP: ${ADMIN_NODE_IP}")
              }
              nodeIps[index] = ip
            }
          }

          if (nodeCount == 0) {
            error "No VMs to deploy apps"
          }

          else if (nodeCount == 1) {
            // aio 
            ceph_mon_host=ADMIN_NODE_IP
          } else {
            // multi nodes
            def cephNodes = [nodeIps[0], nodeIps[1], nodeIps[2]]
            ceph_mon_host=cephNodes.join(',')
          }
        }
      }
    }
    stage ('Run argo workflow') {
      steps {
        script {

          sh """
            cp /opt/jenkins/.ssh/jenkins-slave-hanukey ./jenkins.key
            ssh -o StrictHostKeyChecking=no -i jenkins.key taco@$ADMIN_NODE_IP chmod 0755 /home/taco/deployApps.sh
            ssh -o StrictHostKeyChecking=no -i jenkins.key taco@$ADMIN_NODE_IP /home/taco/deployApps.sh --apps ${params.APPS} --site ${params.SITE_NAME} --manifest-branch ${params.DECAPOD_MANIFEST_BRANCH}
          """
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
