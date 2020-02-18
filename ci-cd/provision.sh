#!/bin/bash

jenkins=false
while getopts :ht opt; do
    case $opt in 
        jenkins) jenkins=true ;;
        :) echo "Missing argument for option -$OPTARG"; exit 1;;
       \?) echo "Unknown option -$OPTARG"; exit 1;;
    esac
done

shift $(( OPTIND - 1 ))

git config --global user.email "workshop@msb.com"
git config --global user.name "workshop at msb"

helm install --name nginx-ingress stable/nginx-ingress
while [ -z $external_ip ]; do echo "Waiting for the external IP"; external_ip=$(kubectl get svc nginx-ingress-controller --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}"); [ -z "$external_ip" ] && sleep 2; done; echo "End point ready $external_ip"

# pg
# redirect uri for drone-ci
sed -i "s@EXTERNAL_IP@$external_ip@" ./files/gitea.sql
kubectl create configmap db-gitea --from-file=./files/gitea.sql
helm install --name postgresql --set postgresqlUsername=gitea,postgresqlPassword=gitea1234,postgresqlDatabase=gitea,initdbScriptsConfigMap=db-gitea stable/postgresql
while [[ $(kubectl get pods postgresql-postgresql-0 -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for the pg" && sleep 2; done

# docker-registry credentials
kubectl apply -f regcred.yaml

# gitea
sed -i "s@# externalHost: git.workshop.msb.com@externalHost: $external_ip@" ./charts/gitea/values.yaml
helm install --name gitea charts/gitea

while [[ $(kubectl get pods -l app=gitea-gitea -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for the gitea" && sleep 2; done

# jenkins
if $jenkins; then
  sed -i'' -e "s@<serverUrl>.*@<serverUrl>http://$external_ip/git</serverUrl>@" ./charts/helm-jenkins-values.yaml
  sed -i'' -e "s@<serverUrl>.*@<serverUrl>http://$external_ip/git</serverUrl>@" ./files/org.jenkinsci.plugin.gitea.servers.GiteaServers.xml

  kubectl apply -f ./files/jenkins-secrets.yaml

  kubectl create secret generic j-cred --from-file=./files/credentials.xml
  helm install --name jenkins stable/jenkins -f charts/helm-jenkins-values.yaml
  while [[ $(kubectl get pods -l app.kubernetes.io/name=jenkins -o 'jsonpath={..status.conditions[?(@.type=="Initialized")].status}') != "True" ]]; do echo "waiting for the jenkins" && sleep 2; done
  jenkins_pod=$(kubectl get pod -l app.kubernetes.io/name=jenkins -o jsonpath="{.items[0].metadata.name}")
  sleep 5
  kubectl cp ./files/org.jenkinsci.plugin.gitea.servers.GiteaServers.xml default/$jenkins_pod:/var/jenkins_home/org.jenkinsci.plugin.gitea.servers.GiteaServers.xml
  kubectl exec $jenkins_pod -- chown -R root:root /var/jenkins_home/org.jenkinsci.plugin.gitea.servers.GiteaServers.xml
  echo "Jenkins has been initialized, waiting for readiness"
  while [[ $(kubectl get pods -l app.kubernetes.io/name=jenkins -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for the jenkins" && sleep 2; done
  echo "Jenkins is ready to serve"
  sed -i'' -e "s@git.workshop.msb.com@$external_ip/git@" ./hello-world-app/Jenkinsfile
  
  # service account for the jenkins agent
  kubectl create serviceaccount build-robot && kubectl create clusterrolebinding build-robot --clusterrole=cluster-admin --serviceaccount=default:build-robot

  echo "Use http://$external_ip/git to access gitea and http://$external_ip/jenkins to access jenkins"
else
  helm install --name drone stable/drone \
    --set sourceControl.provider=gitea \
    --set sourceControl.gitea.server=http://$external_ip/git \
    --set server.host=$external_ip \
    --set server.kubernetes.enabled=true \
    --set sourceControl.gitea.clientID=e04bb11b-8e4a-415f-9527-995209eb45e2 \
    --set sourceControl.gitea.clientSecretValue="95IN8jgOOc1KHRvRqjyrlP93XS-Hw47_8yIXN9sn9qo=" \
    --set server.adminUser=msb-admin \
    --set server.kubernetes.pipelineServiceAccount=build-robot
  kubectl apply -f ./charts/drone-ingress.yaml
  while [[ $(kubectl get pods -l app=drone -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for the drone" && sleep 2; done

  # service account for the drone worker
  kubectl create clusterrolebinding build-robot --clusterrole=cluster-admin --serviceaccount=default:build-robot

  echo "Use http://$external_ip/git to access gitea and http://$external_ip to access drone ci"
fi
