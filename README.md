# Running Hyperledger Fabric on Kubernetes

## Supported Configuration

| Platform   | Version                                      |
|------------|----------------------------------------------|
| Minikube   | >=1.12.0                                     |
| Kubernetes | >=1.16                                       |
| IKS        | Free Cluster (Paid cluster is not supported) |

## Prerequisities

### HF Binaries

Download binaries for Hyperledger Fabric 2.2.1

```bash
curl -sSL http://bit.ly/2ysbOFE | bash -s -- 2.2.1 -d -s
rm -r config
export PATH=${PWD}/bin:$PATH
```

Generate keys and genesis block

```bash
./generate.sh
```

### Exposing public orderer endpoint in channel configuration (Optional)

In [configtx.yaml](configtx.yaml), search for `# BEGIN EDIT HERE` and uncomment the section. Modify the `Host` and `Port` to match the external endpoint. If using free IKS cluster, do not alter the `Port` and use the worker node's public address as the `Host`

In [cryptogen.yaml](crypto-config.yaml), modify the `SAN` field to include the worker node's public IP address for IKS cluster or LoadBalancer IP for paid IKS cluster

To retrieve worker node's public IP address:  

```bash
kubectl get node -o wide
```

## Basic Deployment

Follow the steps below to deploy 2 orgs (1 peer each), 2 orderers and 2 CAs and join those peers to a channel called `channel1`

Run the auto setup script:

```bash
./start.sh
```

## Utility Pod

Utility Pod is always running to access all other pods directly and perform various tasks

```bash
kubectl exec -it utility-pod bash
```

## Remove Deployment

Remove all the deployments:

```bash
./stop.sh
```

## Running Chaincode

### External chaincode builder/launcher

This repository includes a Kubernetes external chaincode builder/launcher provided by <https://github.com/postfinance/hlfabric-k8scc>. In case there is a need to rebuild the binary, follow the instructions in [External Chaincode](EXTERNAL_CC.md)

### Sample chaincode

First chaincode commit (sequence: 1):

```bash
./run_chaincode.sh
```

For subsequent commits (sequence is automatically calculated):

```bash
/run_chaincode.sh --upgrade <version>
```

## CouchDB Database

### Deploy CouchDB Database

```bash
kubectl apply -f kube/couchdb.yaml
```

### Access CouchDB Database

Access CouchDB Database: <http://external_ip:31985/_utils>

| Username  | Password       |
| --------- | -------------- |
| admin     | pass           |

*(If using minikube, issue `minikube ip` to find the external IP)*

### Remove CouchDB Database

```bash
kubectl delete -f kube/couchdb.yaml
```

## Monitoring

### Deploy Prometheus and Grafana

```bash
kubectl apply -f kube/monitoring.yaml
```

| Component  | Address       |
| --------- | -------------- |
| Prometheus     | <http://external_ip:30882>  |
| Grafana     | <http://external_ip:30883>  |

*(If using minikube, issue `minikube ip` to find the external IP)*

### Remove Monitoring

```bash
kubectl delete -f kube/monitoring.yaml
```

<!-- แก้เรื่อง checksum mismatch ตอน go mod vendor -->
export GOPROXY="proxy.golang.org,direct"