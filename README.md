# Docker scaling lab

Two Spring Boot services run under Docker Compose on one EC2 instance. A resident script watches container CPU. When a service passes the peak measured on a single replica, the script adds replicas with `docker compose up --scale`.

Grafana, Prometheus, and Tempo are the same boards used in the local compose stack. Terraform creates the instance and starts that stack.

## What is running

`productservice` takes `POST /productapi/products`, looks up a coupon, and stores the discounted price. `couponservice` keeps the coupons and is only reachable on the Compose network. An nginx gateway publishes port 9090 and sends each request to a product replica.

| Piece | Role |
| --- | --- |
| `productservice`, `couponservice` | One replica at start. Memory reservation 512MiB, limit 768MiB. |
| `gateway` | Host port 9090. Resolves new replicas through the Compose DNS. |
| `mysql` | Database `servicedb`. Not published off the instance. |
| Grafana, Prometheus, Tempo | The local observability stack, on port 3000. |
| `bin/scale-watch.sh` | systemd unit `scale-watch`. Idle until a baseline file exists. |

The project tree is `docker-assignment/`.

## Create the instance

From `docker-assignment/`:

```bash
terraform -chdir=tf init
terraform -chdir=tf apply
```

Apply builds a small VPC, a `t3.large` in `eu-west-1`, and a security group that allows SSH, Grafana, and port 9090 only from the machine that runs Terraform. User data installs Docker and the Compose plugin. A provisioner then copies this tree to `/opt/docker-assignment`, builds the images, starts Compose, and writes the coupons `SAVE10` and `SAVE20`.

The SSH private key is written to `docker-assignment/tf/lab-key.pem`. It is not committed.

```bash
terraform -chdir=tf output
```

Grafana is `http://<public-ip>:3000`. The boards are in the folder **CSR lab**. The product list is `http://<public-ip>:9090/productapi/products`. An empty list `[]` means the service is up and no product has been stored yet.

## Measure, then scale

The scaler does not use a fixed guess. The first k6 run records the peak CPU of the single replica. Later runs scale when CPU goes above that peak.

On the instance, start the sampler. It pauses scaling for 110 seconds:

```bash
ssh -i docker-assignment/tf/lab-key.pem ec2-user@<public-ip> \
  '/opt/docker-assignment/bin/measure-baseline.sh'
```

While that window is open, from this machine:

```bash
docker-assignment/bin/k6-load.sh http://<public-ip>:9090
```

k6 needs to be installed locally. The script posts products for about 100 seconds and ramps to 20 virtual users, alternating `SAVE10` and `SAVE20`.

The sampler writes `scale/thresholds.env` on the instance:

```
PRODUCT_CPU_PERCENT=<peak>
COUPON_CPU_PERCENT=<peak>
```

`scale-watch` reads that file every 15 seconds.

- Above the peak, it adds at most 2 replicas and stops at 4.
- Below the peak for 120 seconds, it removes one replica and stops at 1.
- If free memory cannot hold another 512MiB reservation, the extra replica is not started. That is the Compose counterpart of a Pod left `Pending`.

Run the same k6 command again to cross the recorded peak. `docker compose ps` on the instance shows the new containers. Grafana shows the application metrics and traces.

## Stop the instance

```bash
terraform -chdir=tf destroy
```

Destroy removes the VPC, the instance, and the key pair in AWS. The local key file remains on disk.
