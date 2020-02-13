#!/bin/bash

helm del --purge gitea
helm del --purge jenkins
helm del --purge nginx-ingress
helm del --purge postgresql

kubectl delete -f regcred.yaml
kubectl delete serviceaccount build-robot
kubectl delete clusterrolebinding build-robot
kubectl delete -f ./files/jenkins-secrets.yaml
kubectl delete secret j-cred

kubectl delete configmap db-gitea

kubectl delete -f ./hello-world-app/deployment.yaml
