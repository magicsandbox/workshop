# workshop

1. Create hello world app
2. Deploy cert-manager and cluster issuer: `kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml && helm repo add jetstack https://charts.jetstack.io && helm install --name cert-manager --namespace cert-manager jetstack/cert-manager --set webhook.enabled=false && kubectl apply -f cluster-issuer.yaml && kubectl apply -f regcred.yaml`
3. Deploy psql for Gitea `helm install --name postgresql --set postgresqlUsername=gitea,postgresqlPassword=gitea1234,postgresqlDatabase=gitea stable/postgresql`
4. Deploy nginx ingress `helm install --name nginx stable/nginx-ingress`
5. Get nginx external ip and add change A record for `git.workshop.msb.com` `jenkins.workshop.msb.com` `registry.workshop.msb.com`
6. Deploy Gitea `helm install --name gitea charts/gitea`
7. Deploy docker-registry `helm install --name docker-registry stable/docker-registry -f charts/helm-docker-registry-values.yaml`
8. Deploy Jenkins `helm install --name jenkins stable/jenkins -f charts/helm-jenkins-values.yaml`
9. Configure Gitea
10. Configure [jenkins](https://mike42.me/blog/2019-05-how-to-integrate-gitea-and-jenkins)
11. Test CI/CD

Gitea:
msb-admin:123456
jenkins:Qw123456-*

Jenkins:
admin:123456

Registry:
msb:123456

curl docker-registry.default:5000/v2/_catalog
curl docker-registry.default:5000/v2/msb/hello-world/tags/list
curl docker-registry.default:5000/v2/msb/hello-world/manifests/v1

## todo -> 9
