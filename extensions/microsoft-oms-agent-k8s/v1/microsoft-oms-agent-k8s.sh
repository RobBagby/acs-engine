#!/bin/bash

set -e
[ "$DEBUG" == 'true' ] && set -x

parameters=$(echo $1 | base64 -d -)

log() {
  echo "`date +'[%Y-%m-%d %H:%M:%S:%N %Z]'` $1"
}

get_param() {
  local param=$1
  echo $(echo "$parameters" | jq ".$param" -r)
}

install_script_dependencies() {
  log ''
  log 'Installing script dependencies'
  log ''

  # Install jq to obtain the input parameters
  log 'Installing jq'
  log ''
  sudo apt-get -y install jq
  log ''

  log 'done'
  log ''
}

cleanup_script_dependencies() {
  log ''
  log 'Removing script dependencies'
  log ''

  log 'Removing jq'
  log ''
  sudo apt-get -y remove jq
  log ''

  log 'done'
  log ''
}

create_secret_yaml() {
  log ''
  log 'Creating oms-agentsecret.yaml file'
  log ''

  local wsid=$(get_param 'wsid')
  local key=$(get_param 'key')

  cat > ./oms-agentsecret.yaml <<EOFSECRET
apiVersion: v1
kind: Secret
metadata:
  name: omsagent-secret
type: Opaque
data:
  WSID: `echo $wsid | base64 -`
  KEY: `echo $key | base64 -` 
EOFSECRET

  log 'done'
  log ''
}

create_daemonset_yaml() {
  log ''
  log 'Creating oms-daemonset.yaml file'
  log ''

  cat > oms-daemonset.yaml <<EOFDAEMONSET
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
 name: omsagent
spec:
 template:
  metadata:
   labels:
    app: omsagent
    agentVersion: 1.3.4-127
    dockerProviderVersion: 10.0.0-22
  spec:
   containers:
     - name: omsagent 
       image: "microsoft/oms"
       imagePullPolicy: Always
       env:
        - name: WSID
          valueFrom:
            secretKeyRef:
              name: omssecrets
              key: wsid
        - name: KEY
          valueFrom:
            secretKeyRef:
              name: omssecrets
              key: key
       securityContext:
         privileged: true
       ports:
       - containerPort: 25225
         protocol: TCP 
       - containerPort: 25224
         protocol: UDP
       volumeMounts:
        - mountPath: /var/run/docker.sock
          name: docker-sock
        - mountPath: /var/opt/microsoft/omsagent/state/containerhostname
          name: container-hostname
        - mountPath: /var/log 
          name: host-log
   volumes:
    - name: docker-sock 
      hostPath:
       path: /var/run/docker.sock
    - name: container-hostname
      hostPath:
       path: /etc/hostname
    - name: host-log
      hostPath:
       path: /var/log 
EOFDAEMONSET

  log 'done'
  log ''
}

deploy_yaml() {
  log ''
  log 'Deploying yaml files'
  log ''

  log 'Deploying oms agent secret - oms-agentsecret.yaml'
  kubectl create -f 'oms-agentsecret.yaml'

  log 'Deploying oms agent daemonset - oms-daemonset.yaml' 
  kubectl create -f 'oms-daemonset.yaml'

  log 'done'
  log ''
}

log 'ACS-Engine - installing Microsoft OMS Agent (k8s)'
log '--------------------------------------------------'

install_script_dependencies
create_secret_yaml
create_daemonset_yaml
deploy_yaml
cleanup_script_dependencies

log ''
log 'done'
log ''