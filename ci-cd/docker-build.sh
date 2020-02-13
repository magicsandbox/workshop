#!/bin/bash

# args:
# --context --> path with files (dockerfile should be there)
# --image   --> docker repo/image:tag

if [ $# -ne 4 ]; then
  echo "Usage : $0 --image msbcom/hello:latest --context full-path-to-project-with-dockefile"
  exit 1
fi

ctx=""
image=""
pod_template="apiVersion: v1
kind: Pod
metadata:
  name: kaniko
spec:
  containers:
  - image: msbcom/kaniko:latest
    name: kaniko
    tty: true
    command:
    - cat
    volumeMounts:
    - name: cred
      mountPath: /kaniko/.docker
      readOnly: true
  volumes:
  - name: cred
    secret:
      secretName: regcred
      items:
      - key: .dockerconfigjson
        path: config.json
"


while test $# -gt 0; do
  case "$1" in
    "--context")
      shift
      ctx=$1
      shift
      ;;
    "--image")
      shift
      image=$1
      shift
      ;;
    *)
      echo "You have failed to specify what to do correctly."
      exit 1
      ;;
  esac
done

echo "Using context: $ctx, and image: $image"

echo "$pod_template" | kubectl apply -f -
while [[ $(kubectl get pods kaniko -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for pod" && sleep 2; done

kubectl cp $ctx default/kaniko:/kaniko/project
kubectl exec -ti kaniko -- /kaniko/executor -f=/kaniko/project/dockerfile -c=/kaniko/project --destination=registry.msb.com/$image

kubectl delete po kaniko
