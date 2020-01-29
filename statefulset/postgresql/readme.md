# PostgreSQL Cluster

## Helm

Helm is the first application package manager running atop Kubernetes. It allows describing the application structure through convenient helm-charts and managing it with simple commands.

### Helm in action

To deploy nginx ingress execute command: `helm install --name nginx stable/nginx-ingress`. In a minute nginx ingress will be deployed.

To terminate deployment execute: `helm del --purge nginx`

The main chart repository: [https://github.com/helm/charts](https://github.com/helm/charts)

## PostgreSQL simple deployment

To deploy production ready psql cluster we should download [production-values.yaml file](https://github.com/helm/charts/raw/master/stable/postgresql/values-production.yaml): `wget https://github.com/helm/charts/raw/master/stable/postgresql/values-production.yaml`. And then use helm to deploy psql: `helm install --name pg -f values-production.yaml stable/postgresql --set replication.slaveReplicas=3,metrics.enabled=false` (set the number of slave replicas to 3 and disable prometheus exporter (since we don't have prometheus)).

## Automatic Master Failover

HA PostgreSQL should automatically survive and recover if node with a database master (primary) crashes. With the pure Kubernetes solution from the previous step it works in the following way:

1) PostgreSQL master pod or node crashes.
2) Kubernetes runs a healthcheck every 10 seconds by default. We can tune periodSeconds and run a healthcheck every second (it’s the minimum interval). In one second after the crash Kubernetes detects it.
3) Kubernetes schedules a new pod for the PostgreSQL master server. If a node crashed it may need to run a new node first. If just a pod failed Kubernetes can just restart a pod.
4) PostgreSQL master starts.

This pure Kubernetes HA solution has an advantage of simplicity of setup. But we have a downtime between steps 1 and 4 and the downtime can be minutes if Kubernetes needs to restart a node.

There are a few solutions for the HA PostgreSQL clusters. [Stolon](https://github.com/sorintlab/stolon) and [Patroni](https://github.com/zalando/patroni).

The both projects are similar by supported features. The small comparison:

- Patroni is supported by Postgres Operator
- Both of projects support sync replication: patroni and stolon.
- Both of them support quorum-based sync replication (but not natively by PostgreSQL): patroni and stolon

We will use Stolon because it has more clear architecture.

Let's terminate current deployment: `helm del --purge pg`

## Running Stolon PostgreSQL

1) Create secrets for PostgreSQL superuser and replication: `kubectl create secret generic pg-su --from-literal=username='su_username' --from-literal=password='su_password'`, `kubectl create secret generic pg-repl --from-literal=username='repl_username' --from-literal=password='repl_password'`
2) Deploy: `helm install --name stolon -f stolon-prod-values.yaml stable/stolon`. In a few minutes HA PSQL cluster will be up.
3) Check cluster: `kubectl get all`.
4) To check whois master and check status of the cluster execute: `kubectl exec -it stolon-keeper-0 -- bash -c "stolonctl status --cluster-name stolon --store-backend=kubernetes --kube-resource-kind=configmap"`
5) Add some data and check it: `kubectl exec -it stolon-keeper-0 -- psql --host stolon-proxy --port 5432 --username su_username -W -d template1`, `create database test;`, `\c test`, `create table test (id int primary key not null, value text not null);`, `insert into test values (1, 'value1');`, `select * from test;`
6) Let's kill the master: `kubectl delete pod stolon-keeper-0`. (Step 4).
7) The second replica should be elected as a master. Check it: `kubectl exec -it stolon-keeper-1 -- psql --host stolon-proxy --port 5432 --username su_username -W -d test`, `select pg_is_in_recovery();`, and check data `select * from test;`.
8) To failover (migrate) master run bash session (`kubectl exec -it stolon-keeper-0 -- bash`) and execute: `stolonctl failkeeper MASTER_KEEPER_ID --cluster-name stolon --store-backend=kubernetes --kube-resource-kind=configmap`, be sure you replaced MASTER_KEEPER_ID with id of the keeper (example: `keeper0`), use step 4 to get master id.

## Running ODOO connected to Stolon

[Odoo](https://www.odoo.com/) is a suite of web-based open source business apps. The main Odoo Apps include an Open Source CRM, Website Builder, eCommerce, Project Management, Billing & Accounting, Point of Sale, Human Resources, Marketing, Manufacturing, Purchase Management, ...

1) ODOO reqiures superuser credentials and we will use existing superuser credenetials: `helm install --name odoo stable/odoo --set postgresql.enabled=false,externalDatabase.host=stolon-proxy,externalDatabase.user=su_username,externalDatabase.password=su_password`. In a few minutes Odoo will be up and running. You can get public ip from services: `kubectl get svc`. And then access web interface by using public ip.

## PG backups

Odoo uses `bitnami_odoo` as a defult DB, we are going to create cron job that should get dump of that DB and put it into S3 bucket twice per day.

We will use [lgatica/pgdump-s3](https://hub.docker.com/r/lgatica/pgdump-s3) image for that.

1) Create bucket and IAM.
2) Create secrets: `kubectl create secret generic backuper-cred --from-literal=access-key='123' --from-literal=secret-key='123' --from-literal=bucket='msb-odoo-backups' --from-literal=pg-uri='postgres://su_username:su_password@stolon-proxy:5432/bitnami_odoo'`. Be sure you replaced access-key, secret-key and bucket.
3) Create cronjob: `kubectl apply -f pg-dump-cronjob.yaml`
4) To test it manually execute: `kubectl create job --from=cronjob/pg-to-s3-backuper pg-manual-test`
5) Check logs: `kubectl logs -f job/pg-manual-test`
6) Delete job and pod: `kubectl delete jobs pg-manual-test`

## Clean up

1) Terminate cronjob: `kubectl delete -f pg-dump-cronjob.yaml`
2) Terminate Odoo: `helm del --purge odoo`
3) Terminate PG cluster: `helm del --purge stolon`
