# POD, volume, init container

## POD, multiple containers

Kubernetes doesn’t run containers directly; instead it wraps one or more containers into a higher-level structure called a pod. Any containers in the same pod will share the same resources and local network. Containers can easily communicate with other containers in the same pod as though they were on the same machine while maintaining a degree of isolation from others.

Pods can hold multiple containers, but you should limit yourself when possible. Because pods are scaled up and down as a unit, all containers in a pod must scale together, regardless of their individual needs. This leads to wasted resources and an expensive bill. To resolve this, pods should remain as small as possible, typically holding only a main process and its tightly-coupled helper containers (these helper containers are typically referred to as “side-cars”).

Simple example:

1) create pod with multiple containers and service: `kubectl apply -f multiple-containers.yaml`.
2) get responce from the nginx: `curl nginx.default`.
3) add second line to the `index.html` file with using debian-container: `kubectl exec -ti two-containers -c debian-container -- bash -c "echo second line >> /pod-data/index.html"`.
4) get responce from the nginx: `curl nginx.default`.
5) terminate example: `kubectl delete -f multiple-containers.yaml`

## Init container

A Pod can have multiple containers running apps within it, but it can also have one or more init containers, which are run before the app containers are started.

Init containers are exactly like regular containers, except:

- Init containers always run to completion.
- Each init container must complete successfully before the next one starts.
- If a Pod’s init container fails, Kubernetes repeatedly restarts the Pod until the init container succeeds. However, if the Pod has a restartPolicy of Never, Kubernetes does not restart the Pod.

Simple example:

1) create pod with init-containers: `kubectl apply -f init-containers.yaml`, init containers should wait for services.
2) execute `kubectl describe po init-in-action` to take a look at init-containers, containers, events section.
3) create services: `kubectl apply -f init-containers-svc.yaml`, after a few seconds init containers should be completed and container with app should be launched.
4) execute `kubectl describe po init-in-action` to take a look at init-containers, containers, events section.
5) terminate example: `kubectl delete -f init-containers.yaml && kubectl delete -f init-containers-svc.yaml`

## Lifecycle Hooks

There are two hooks that are exposed to Containers:

```bash
PostStart
```

This hook executes immediately after a container is created. However, there is no guarantee that the hook will execute before the container ENTRYPOINT. No parameters are passed to the handler.

```bash
PreStop
```

This hook is called immediately before a container is terminated due to an API request or management event such as liveness probe failure, preemption, resource contention and others. A call to the preStop hook fails if the container is already in terminated or completed state. It is blocking, meaning it is synchronous, so it must complete before the call to delete the container can be sent. No parameters are passed to the handler.
A more detailed description of the termination behavior can be found in Termination of Pods.

Simple example:

1) create pod with lifecycle section: `kubectl apply -f lifecycle.yaml`.
2) get responce from the nginx: `curl nginx.default`.
3) terminate pod: `kubectl delete -f lifecycle.yaml`.

## Volume

On-disk files in a Container are ephemeral, which presents some problems for non-trivial applications when running in Containers. First, when a Container crashes, kubelet will restart it, but the files will be lost - the Container starts with a clean state. Second, when running Containers together in a Pod it is often necessary to share files between those Containers. The Kubernetes Volume abstraction solves both of these problems.

### emptyDir volume

An `emptyDir` volume is first created when a Pod is assigned to a Node, and exists as long as that Pod is running on that node. As the name says, it is initially empty. Containers in the Pod can all read and write the same files in the emptyDir volume, though that volume can be mounted at the same or different paths in each Container. When a Pod is removed from a node for any reason, the data in the emptyDir is deleted forever.

Simple example:

1) create pod with empty dir volume: `kubectl apply -f volume-empty-dir.yaml`. Volume should be attached into nginx html dir.
2) get responce from the nginx: `curl nginx.default`.
3) create index.html: `kubectl exec -ti empty-dir -- bash -c "echo hello world >> /usr/share/nginx/html/index.html"`.
4) get responce from the nginx: `curl nginx.default`.
5) terminate example: `kubectl delete -f volume-empty-dir.yaml`

### downward api volume

A `downwardAPI` volume is used to make downward API data available to applications. It mounts a directory and writes the requested data in plain text files.

Simple example:

1) create pod with downward api volume: `kubectl apply -f volume-downward-api.yaml`. Volume should be attached into nginx html dir.
2) get responce from the nginx: `curl nginx.default/labels` and `curl nginx.default/annotations`.
3) use bash: `kubectl exec -ti downward-api -- bash -c "ls -lah /usr/share/nginx/html"`, `kubectl exec -ti downward-api -- bash -c "cat /usr/share/nginx/html/labels"`, `kubectl exec -ti downward-api -- bash -c "cat /usr/share/nginx/html/annotations"`
4) you can change labels or annotaions with using `kubectl edit` command, or edit yaml file and apply it, in that case pod will not be restarted but changes will applied onto the files inside pod - on the fly.
5) terminate example: `kubectl delete -f volume-downward-api.yaml`

### config map volume

The `configMap` resource provides a way to inject configuration data into Pods. The data stored in a `ConfigMap` object can be referenced in a volume of type `configMap` and then consumed by containerized applications running in a Pod.

Simple example:

1) create configMap and deployment with configMap volume: `kubectl apply -f volume-config-map.yaml`. Volume should be attached into nginx html dir.
2) get responce from the nginx: `curl nginx.default/game.properties` and `curl nginx.default/ui.properties`.
3) use bash: `kubectl exec -ti deploy/nginx-config-map -- bash -c "ls -lah /usr/share/nginx/html"`, `kubectl exec -ti deploy/nginx-config-map -- bash -c "cat /usr/share/nginx/html/game.properties"`
4) terminate example: `kubectl delete -f volume-config-map.yaml`

### Persistent Volume

A PersistentVolume (PV) is a piece of storage in the cluster that has been provisioned by an administrator or dynamically provisioned using Storage Classes. It is a resource in the cluster just like a node is a cluster resource. PVs are volume plugins like Volumes, but have a lifecycle independent of any individual Pod that uses the PV. This API object captures the details of the implementation of the storage, be that NFS, iSCSI, or a cloud-provider-specific storage system.

Simple example:

1) create PV (`hostPath`) and PVC which will consume created PV and POD with pvc: `kubectl apply -f pv-and-pod.yaml`. After you create the PersistentVolumeClaim, the Kubernetes control plane looks for a PersistentVolume that satisfies the claim’s requirements. If the control plane finds a suitable PersistentVolume with the same StorageClass, it binds the claim to the volume.
2) check files in html dir: `kubectl exec -ti host-path-pv-pod -- bash -c "ls -lah /usr/share/nginx/html/"`.
3) add index.html file: `kubectl exec -ti host-path-pv-pod -- bash -c "echo hello world >> /usr/share/nginx/html/index.html"`.
4) check files: `kubectl exec -ti host-path-pv-pod -- bash -c "ls -lah /usr/share/nginx/html/"`
5) terminate container `kubectl exec -ti host-path-pv-pod -- bash -c "kill 1"`, container should be restarted in a seconds (to check this case you can open new terminal session and execute `kubectl get pod -w` to watch over pods).
6) check files: `kubectl exec -ti host-path-pv-pod -- bash -c "ls -lah /usr/share/nginx/html"`. index.html shoule be there since we use PV!
7) terminate example: `kubectl delete -f pv-and-pod.yaml`

### Dynamic Volume Provisioning

Cloud has own provisioneers. And we have NFS provisioneer deployed in cluster, you can use for the dynamic volume provisioning.

Simple example:

1) create statufulset with volumeClaimTemplates section `kubectl apply -f volume-claim-template.yaml`
2) check pv and pvc: `kubectl get pv,pvc`. There should be PVCs and PVs for each replica with `Bound` status.
3) add index.html file to the first replica: `kubectl exec -ti nginx-pvc-0 -- bash -c "echo hello world >> /usr/share/nginx/html/index.html"`.
4) check files: `kubectl exec -ti nginx-pvc-0 -- bash -c "ls -lah /usr/share/nginx/html/"`
5) terminate pod `kubectl delete pod nginx-pvc-0`, pod should be recreated in a seconds.
6) check files: `kubectl exec -ti nginx-pvc-0 -- bash -c "ls -lah /usr/share/nginx/html"`. index.html shoule be there since we use PVC!
7) check files on second replica: `kubectl exec -ti nginx-pvc-1 -- bash -c "ls -lah /usr/share/nginx/html"`. No files, right?
8) terminate sts: `kubectl delete -f volume-claim-template.yaml`
9) and create it again: `kubectl apply -f volume-claim-template.yaml`
10) check files: `kubectl exec -ti nginx-pvc-0 -- bash -c "ls -lah /usr/share/nginx/html/"`. index.html still there :)
11) terminate example and PVCs: `kubectl delete -f volume-claim-template.yaml && kubectl delete pvc www-nginx-pvc-0 www-nginx-pvc-1`. after that operation pv with index.html will be terminated.

#### AccessModes

If a pod mounts a volume with `ReadWriteOnce` access mode, no other pod can mount it. In GKE and EKS the only allowed modes are `ReadWriteOnce` and `ReadOnlyMany`. So either one pod mounts the volume `ReadWrite`, or one or more pods mount the volume `ReadOnlyMany`. NFS provisioneed can handle `ReadWriteMany`, so many PODs are able to mount the same persistend volume with write access.
