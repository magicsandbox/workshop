# CI/CD

## Easy way (requires access to docker registry)

1. Execute `./provision.sh`, PG, Gitea and jenkins will be installed in a 2 minutes
2. Create private repo in Gitea using `msb` org
3. Go to hello-world-app dir, init repo, commit files and push them into the created repo
4. Click `scan msb repos` button using Jenkins main page. Job should be launched for the repo
5. Update `main.go` file, push it to the master and then push master branch to production branch

To build docker image locally use the next command: `./docker-build.sh --image msbcom/hello:latest --context ./hello-world-app`

## Hard way (requires access to DNS hosting provider)

1. Deploy cert-manager and cluster issuer: `kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml && helm repo add jetstack https://charts.jetstack.io && helm install --name cert-manager --namespace cert-manager jetstack/cert-manager --set webhook.enabled=false && kubectl apply -f cluster-issuer.yaml && kubectl apply -f regcred.yaml`
2. Deploy psql for Gitea `helm install --name postgresql --set postgresqlUsername=gitea,postgresqlPassword=gitea1234,postgresqlDatabase=gitea stable/postgresql`
3. Deploy nginx ingress `helm install --name nginx stable/nginx-ingress`
4. Get nginx external ip and add change A record for `git.workshop.msb.com` `jenkins.workshop.msb.com` `registry.workshop.msb.com` `hello-world.workshop.msb.com`
5. Deploy Gitea `helm install --name gitea charts/gitea`
6. Deploy docker-registry `helm install --name docker-registry stable/docker-registry -f charts/helm-docker-registry-values.yaml`
7. Deploy Jenkins `helm install --name jenkins stable/jenkins -f charts/helm-jenkins-values.yaml`
8. Create service account for the jenkins agent: `kubectl create serviceaccount build-robot && kubectl create clusterrolebinding build-robot --clusterrole=cluster-admin --serviceaccount=default:build-robot`
9. Configure Gitea (admin account, org, jenkins account, repo)
10. [Configure jenkins](https://mike42.me/blog/2019-05-how-to-integrate-gitea-and-jenkins)
11. Test CI/CD

## Credentials

Gitea: `msb-admin:123456` `jenkins:Qw123456-*`

Jenkins: `admin:123456`

Registry: `msb:123456`

How to check registry

```bash
curl https://RegistryCreds@registry.workshop.msb.com/v2/_catalog
curl https://RegistryCreds@registry.workshop.msb.com/v2/msb/hello-world/tags/list
```
