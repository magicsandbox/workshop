# workshop

1. Create hello world app
2. Deploy psql with db for Gitea `helm install --name postgresql --set postgresqlUsername=gitea,postgresqlPassword=gitea1234,postgresqlDatabase=gitea stable/postgresql`
3. Deploy nginx ingress `helm install --name nginx stable/nginx-ingress`
4. Deploy Gitea `helm install --name gitea charts/gitea`
5. Deploy docker-registry `helm install --name docker-registry stable/docker-registry --set persistence.enabled=true`
6. Deploy Jenkins `helm install --name jenkins stable/jenkins --set master.ingress.enabled=true,master.ingress.hostName=jenkins.workshop.msb.com`
7. Get nginx external ip and add change A record for `git.workshop.msb.com` `jenkins.workshop.msb.com`
8. Configure [jenkins](https://mike42.me/blog/2019-05-how-to-integrate-gitea-and-jenkins)
9. Test CI/CD


Jenkins password:
`printf $(kubectl get secret --namespace default jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 -d);echo`

## todo -> 9