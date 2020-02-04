# Deploying Elasticsearch using an Operator

## Deploy ECK in your Kubernetes cluster

Install custom resource definitions and the operator with its RBAC rules:

```bash
kubectl apply -f https://download.elastic.co/downloads/eck/1.0.0/all-in-one.yaml
```

Monitor the operator logs:

```bash
kubectl -n elastic-system logs -f statefulset.apps/elastic-operator
```

## Deploy an Elasticsearch cluster

Apply a simple Elasticsearch cluster specification, with one Elasticsearch node: `kubectl apply -f elasticsearch.yaml`

The operator automatically creates and manages Kubernetes resources to achieve the desired state of the Elasticsearch cluster. It may take up to a few minutes until all the resources are created and the cluster is ready for use.

## Monitor cluster health and creation progress

Get an overview of the current Elasticsearch clusters in the Kubernetes cluster, including health, version and number of nodes: `kubectl get elasticsearch -w`

When you create the cluster, there is no HEALTH status and the PHASE is empty. After a while, the PHASE turns into Ready, and HEALTH becomes green.

You can see that one Pod is in the process of being started: `kubectl get pods --selector='elasticsearch.k8s.elastic.co/cluster-name=elastic'`

### Request Elasticsearch access

A ClusterIP Service is automatically created for your cluster: `kubectl get service elastic-es-http`

1) Get the credentials

A default user named elastic is automatically created with the password stored in a Kubernetes secret:

```bash
PASSWORD=$(kubectl get secret elastic-es-elastic-user -o=jsonpath='{.data.elastic}' | base64 -d)
```

Request the Elasticsearch endpoint.

2) From inside the Kubernetes cluster

```bash
curl -u "elastic:$PASSWORD" -k "https://elastic-es-http:9200"
```

## Deploy a Kibana instance

To deploy your Kibana instance go through the following steps.

1) Specify a Kibana instance and associate it with your Elasticsearch cluster: `kubectl apply -f kibana.yaml`

2) Monitor Kibana health and creation progress.

Similar to Elasticsearch, you can retrieve details about Kibana instances: `kubectl get kibana -w`

And the associated Pods: `kubectl get pod --selector='kibana.k8s.elastic.co/name=kb'`

3) Access Kibana

A ClusterIP Service is automatically created for Kibana: `kubectl get service kb-kb-http`

Expose kibana to the internet by creating service with `LoadBalancer` type: `kubectl apply -f kibana-lb-svc.yaml`

Wait until public ip will be assigned to the service: `kubectl apply get svc -w`

Open `https://KIBANA_IP` in your browser. Your browser will show a warning because the self-signed certificate configured by default is not verified by a third party certificate authority and not trusted by your browser. You can temporarily acknowledge the warning for the purposes of this quick start but it is highly recommended that you configure valid certificates for any production deployments.

Login as the `elastic` user. The password can be obtained with the following command: `kubectl get secret elastic-es-elastic-user -o=jsonpath='{.data.elastic}' | base64 -d; echo`

## Upgrade your deployment

You can add and modify most elements of the original cluster specification provided that they translate to valid transformations of the underlying Kubernetes resources (e.g., existing volume claims cannot be resized). The operator will attempt to apply your changes with minimal disruption to the existing cluster. You should ensure that the Kubernetes cluster has sufficient resources to accommodate the changes (extra storage space, sufficient memory and CPU resources to temporarily spin up new pods etc.).

Change the number of replicas in `elasticsearch.yaml` file from 1 to 3 and apply that file: `kubectl apply -f elasticsearch.yaml`

Number of replicas should be increased from 1 to 3 (1 master and 2 workers).

## Uninstalling ECK

Before uninstalling the operator, remove all Elastic resources in all namespaces:

```bash
kubectl get namespaces --no-headers -o custom-columns=:metadata.name | xargs -n1 kubectl delete elastic --all -n
```

This deletes all underlying Elasticsearch, Kibana, and APM Server resources (pods, secrets, services, etc.).

Then, you can uninstall the operator: `kubectl delete -f https://download.elastic.co/downloads/eck/1.0.0/all-in-one.yaml`

## Own operator

To build your own operator you can use [Kubebuilder](https://book.kubebuilder.io)
