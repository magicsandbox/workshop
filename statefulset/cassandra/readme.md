# Deploying Cassandra with Stateful Sets

## Deploy Cassandra in POD

Let's try deploy cassandra using simple POD: `kubectl apply -f cassandra-pod.yaml`. It is super easy to run cassandra in POD, but it is hard to manage it. Statefulset object is a really nice helper.

## Simple statefulset object

Deployments and ReplicationControllers are meant for stateless usage and are rather lightweight. StatefulSets are used when state has to be persisted. Therefore the latter use volumeClaimTemplates / claims on persistent volumes to ensure they can keep the state across component restarts.

So if your application is stateful or if you want to deploy stateful storage on top of Kubernetes use a StatefulSet.

To deploy simple statefulset example execute: `kubectl apply -f simple-sts.yaml`, 2 nginx replicas should be ready in a minute.

## Deploy Cassandra using Statefulset (simple deployment)

Sometimes you don’t need load-balancing and a single Service IP. In this case, you can create what are termed 'headless' Services, by explicitly specifying `"None"` for the cluster IP (`.spec.clusterIP`)

You can use a headless `Service` to interface with other service discovery mechanisms, without being tied to Kubernetes’ implementation.
For headless `Service`s, a cluster IP is not allocated, kube-proxy does not handle these Services, and there is no load balancing or proxying done by the platform for them.

We will use headless service for the cassandra deployment, headless service returns the IP of the first replica. So new replicas will be able to connect to the ring without any additional configuration.

To create headless service execute: `kubectl apply -f cassandra-headless-svc.yaml`.

To deploy cassandra execute: `kubectl apply -f cassandra-sts-simple.yaml`. 3 replicas will be up in a few minutes.

To check cassandra ring launch temporary pod with `nodetool` app: `kubectl run --generator=run-pod/v1 nodetool --rm -i --tty --image cassandra:3.0 -- /bin/bash` and execute: `nodetool --host cassandra.default status`. Exit from bash session will terminate pod.

Terminate statefulset: `kubectl delete sts cassandra`

## Deploy Cassandra using Statefulset (complex deployment)

For the production usage statefulset config should have `podAntiAffinity` option and PV (`volumeClaimTemplates`) mounted to `/cassandra_data`.

Use `kubectl apply -f cassandra-sts.yaml` to deploy production ready deployment.

To increase number of replicas use `kubectl edit sts cassandra` command, find `replicas: 3` field and increase that number.

Check cassandra ring status by launching temporary pod with `nodetool` app: `kubectl run --generator=run-pod/v1 nodetool --rm -i --tty --image cassandra:3.0 -- /bin/bash` and execute: `nodetool --host cassandra.default status`.

## Clean up

To terminate cassandra deployment execute: `kubectl delete sts cassandra && kubectl delete svc cassandra`.
