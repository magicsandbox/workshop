#!/bin/bash

git config --global user.email "workshop@msb.com"
git config --global user.name "workshop at msb"

helm install --name nginx-ingress stable/nginx-ingress

# pg
kubectl create configmap db-gitea --from-file=./files/gitea.sql
helm install --name postgresql --set postgresqlUsername=gitea,postgresqlPassword=gitea1234,postgresqlDatabase=gitea,initdbScriptsConfigMap=db-gitea stable/postgresql
while [[ $(kubectl get pods postgresql-postgresql-0 -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for pg" && sleep 2; done

helm install --name gitea charts/gitea

# jenkins
kubectl create secret generic j-cred --from-file=./files/credentials.xml
helm install --name jenkins stable/jenkins -f charts/helm-jenkins-values.yaml
while [[ $(kubectl get pods -l app.kubernetes.io/name=jenkins -o 'jsonpath={..status.conditions[?(@.type=="Initialized")].status}') != "True" ]]; do echo "waiting for jenkins" && sleep 2; done
jenkins_pod=$(kubectl get pod -l app.kubernetes.io/name=jenkins -o jsonpath="{.items[0].metadata.name}")
kubectl cp ./files/org.jenkinsci.plugin.gitea.servers.GiteaServers.xml default/$jenkins_pod:/var/jenkins_home/org.jenkinsci.plugin.gitea.servers.GiteaServers.xml
kubectl exec $jenkins_pod -- chown -R root:root /var/jenkins_home/org.jenkinsci.plugin.gitea.servers.GiteaServers.xml
kubectl delete po $jenkins_pod
echo "Jenkins has been initialized, waiting for readiness"
while [[ $(kubectl get pods -l app.kubernetes.io/name=jenkins -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for jenkins" && sleep 2; done
echo "Jenkins is ready to serve"

while [ -z $external_ip ]; do echo "Waiting for end point..."; external_ip=$(kubectl get svc nginx-nginx-ingress-controller --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}"); [ -z "$external_ip" ] && sleep 2; done; echo "End point ready $external_ip"

# service account for the jenkins agent
kubectl create serviceaccount build-robot && kubectl create clusterrolebinding build-robot --clusterrole=cluster-admin --serviceaccount=default:build-robot

# docker-registry credentials
kubectl apply -f regcred.yaml

# kaniko
cp -R ./files/kaniko/* /kaniko/
# cd PROJECT_DIR
# /kaniko/executor -f `pwd`/dockerfile -c `pwd` --no-push --destination=registry.msb.com/theia:abc