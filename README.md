AWS - EKS - Issue with NLB
===

This Terraform project demonstrates issue when a Pod is calling another Pod through a NLB.

## Usage

* Deploy Terraform stack (See [`variables.tf`](./variables.tf))

```shell
terraform apply
```

* Retrieve NLB endpoint

```shell
kubectl -n http-echo svc http-echo -o json | jq -r '.status.loadBalancer.ingress[0].hostname'
```

* Connect to "Shell"

```shell
kubectl -n http-echo exec -ti deployment/tester -- bash
```

* Run test

```shell
. /files/check_http_call.shrc &&
check_http_call "http://${NLB_ENDPOINT}"
```
