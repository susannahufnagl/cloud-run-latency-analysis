# Lebach

concurrent: round-based, 4 parallel requests, pause in between => more "spiky" traffic, lots of idle time.

independent: 4 permanent streams --> more throughput, more pressure on Pub/Sub & network --> batch effects more visible --> how many requests arrive at the server at the same time

# Stage 0: Base architecture

# 1. Stop everything listening on 8080

## e.g.

sudo pkill -f producer || true
pgrep  -a producer -> check whether it stopped

docker stop lat-bench 2>/dev/null || true

sudo systemctl start containerd
sudo nerdctl rm -f lat-bench   # Remove container
sudo systemctl stop containerd

sudo ss -lntp | egrep ':(80|8080)\b' || echo "nothing on 80/8080"

# 2. Build and test producer

cd ~/ba/services/Cloud-Run/go-producer
go build -o producer .
set -a; source ~/ba/.env; set +a
export GCP_PROJECT="$PROJECT"
export GOOGLE_CLOUD_PROJECT="$PROJECT"
export TOPIC_ID="$TOPIC"
export GOOGLE_APPLICATION_CREDENTIALS=~/ba/key.json
./producer > /tmp/producer.log 2>&1 &
sleep 2
tail -n 20 /tmp/producer.log
curl -fsS http://127.0.0.1:8080/health && echo ok

# 3. Test run

CE_BASE="http://127.0.0.1:8080" CHANNEL=bare STAGE=0 \
  bash ~/ba/scripts/run_all_concurrent_0.sh
CE_BASE="http://127.0.0.1:8080" CHANNEL=bare STAGE=0 \
  bash ~/ba/scripts/run_all_independent_0.sh

# Stage 1: S0 + LB/HTTP

# 1. Stop everything listening on 8080

## e.g.

sudo pkill -f producer || true
pgrep  -a producer

docker stop lat-bench 2>/dev/null || true

sudo systemctl start containerd
sudo nerdctl rm -f lat-bench   # Remove container
sudo systemctl stop containerd

sudo ss -lntp | egrep ':(80|8080)\b' || echo "nothing on 80/8080"

# 2. Build and test producer

cd ~/ba/services/Cloud-Run/go-producer
go build -o producer .
set -a; source ~/ba/.env; set +a
export GCP_PROJECT="$PROJECT"
export GOOGLE_CLOUD_PROJECT="$PROJECT"
export TOPIC_ID="$TOPIC"
export GOOGLE_APPLICATION_CREDENTIALS=~/ba/key.json
./producer > /tmp/producer.log 2>&1 &
sleep 2
tail -n 20 /tmp/producer.log
curl -fsS http://127.0.0.1:8080/health && echo ok

# 3. Test LB again:
## a. Local:

LB_S1_IP=$(gcloud compute forwarding-rules describe fr-s2-http --global \
        --format='value(IPAddress)')
echo "LB_IP=$LB_IP"

## b. On the VM:

export LB_S1_IP=34.8.201.151
curl -fsS http://$LB_S1_IP/health

# 4. Is the backend healthy:

gcloud compute backend-services get-health be-s2 --global

# 5. Run tests

CE_BASE="http://$LB_S1_IP" CHANNEL=lb STAGE=1 \
  bash scripts/run_all_concurrent_0.sh
CE_BASE="http://$LB_S1_IP" CHANNEL=lb STAGE=1 \
  bash scripts/run_all_independent_0.sh

# Stage 2: (S1 + containerization in containerd)

# 1. Stop everything on 8080

## e.g.

pkill -x producer || true
sudo pkill -f 'socat.*8080' 2>/dev/null || true
sleep 1
sudo ss -lntp | grep ':8080\b' || echo "Port 8080 free"

# 2. If Minikube is still running, shut it down and stop it

minikube delete --all --purge

# 3. Clear cache

sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches

# 4. Reload images or rebuild --> previously built via docker build

sudo nerdctl load < ce-cb-go.tar

# 5. Create key

sudo rm -rf /home/susannahufnagl/.gcp/key.json
sudo install -m 600 ~/ba/key.json /home/susannahufnagl/.gcp/sa-key.json

# 6. Start the service

sudo nerdctl rm -f lat-bench || true
sudo nerdctl run -d --name lat-bench \
  --runtime runc --net host \
  -e PORT=8080 \
  -e PROJECT=project-accountsec \
  -e TOPIC=cloudrun-broker-single \
  -v /home/susannahufnagl/.gcp/key.json:/var/secrets/gcp/key.json:ro \
  ce-cb-go:latest

# 7. Test

curl -fsS 127.0.0.1:8080/health
sudo ss -lntp | grep ':8080\b'
sudo nerdctl logs lat-bench | tail

# 8. Check logs if there are problems

sudo nerdctl logs lat-bench | tail -n 80'

# 9. If container runs --> check

sudo nerdctl ps
--> lat-bench status should be UP

# 10. Reconnect LB:

Local:
LB_IP=$(gcloud compute forwarding-rules describe fr-s2-http --global --format='value(IPAddress)')
echo $LB_IP
-->  34.8.201.151
Check backend health:

gcloud compute backend-services get-health be-s2 --global

On VM:

LB_S2_IP=34.8.201.151

curl -fsS http://127.0.0.1:8080/health

curl -fsS http://$LB_S2_IP/health

# 11. Is the backend healthy?

gcloud compute backend-services get-health be-s2 --global

# 12. General test run:

CE_BASE="http://$LB_S2_IP" CHANNEL=lb STAGE=2 \
  bash scripts/run_all_concurrent_0.sh
CE_BASE="http://$LB_S2_IP" CHANNEL=lb STAGE=2 \
  bash scripts/run_all_independent_0.sh

Stage 3 and 4:

# 1. Delete Minikube if not done yet:

sudo -E minikube delete --all --purge

# 2. Clear cache

sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches

sudo rm -f /tmp/juju-mk*

# 3.

sudo sysctl fs.protected_regular=0

# 4. Restart minikube

export MINIKUBE_HOME=/home/susannahufnagl/.minikube
export KUBECONFIG=/home/susannahufnagl/.kube/config
export CHANGE_MINIKUBE_NONE_USER=true

sudo apt update
sudo apt install -y iptables

sudo -E minikube start \
  --driver=none \
  --container-runtime=containerd \

## If needed

sudo chown -R susannahufnagl:susannahufnagl /home/susannahufnagl/.minikube /home/susannahufnagl/.kube
sudo chmod -R u+wrx /home/susannahufnagl/.minikube

sudo -E minikube addons enable gvisor
minikube image load ce-cb-go:latest
minikube status

# 5. Restart containerd (maybe earlier)

sudo systemctl restart containerd

# 6. Check containerd status

sudo systemctl status containerd --no-pager
sudo crictl info | grep RuntimeName

## a. If config is broken, remove and recreate

sudo systemctl stop containerd
sudo pkill -f 'containerd-shim' || true
sudo mv /etc/containerd/config.toml /etc/containerd/config.toml.broken-$(date +%s)
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

## b. Start containerd again and let it come up

sudo systemctl daemon-reload
sudo systemctl restart containerd
sudo systemctl status containerd --no-pager
sudo crictl info | grep RuntimeName

# 7. Reset and redeploy everything

# Clean deployments/services (ignore errors if not present)

kubectl delete deploy lat-bench lat-bench-gvisor 2>/dev/null || true
kubectl delete svc   lat-bench lat-bench-gvisor 2>/dev/null || true
kubectl delete secret gcp-sa 2>/dev/null || true

kubectl create secret generic gcp-sa --from-file=key.json=./key.json
kubectl apply -f deployments/deployments.yaml
kubectl apply -f deployments/deployment-gvisor.yaml
kubectl apply -f deployments/service.yaml
kubectl apply -f deployments/service-gvisor.yaml

kubectl get pods -A -o wide
kubectl get svc -A
kubectl get
kubectl get runtimeclass
kubectl get node -o wide
kubectl get node -o wide        # CONTAINER-RUNTIME should show containerd
sudo crictl info | grep RuntimeName
sudo crictl ps | head

8. Quick check

a. Test LB:
LB_IP=$(gcloud compute forwarding-rules describe fr-s7-http --global --format='value(IPAddress)') -> 34.36.203.245

b. export LB_S4_IP=34.36.203.245,
c. echo $LB_S4_IP
d. curl -i http://$LB_S4_IP/health
e. On VM, check that kube-proxy listens on 8080 and the forwarding to gVisor works: curl 127.0.0.1:8080/health

9. Set listener on 8080 via socat, which forwards LB requests to NodePort:

Kill everything listening on port 8080 first:

pkill -x producer || true, sudo pkill -f 'socat.*8080' || true

S3:

MINI_IP=$(minikube ip)

sudo apt-get install -y socat
sudo pkill -f 'socat.*8080' 2>/dev/null || true

sudo nohup socat \
  TCP4-LISTEN:8080,reuseaddr,fork \
  TCP4:${MINI_IP}:30082 \
  >/tmp/socat-8080.log 2>&1 &

S4:

MINI_IP=$(minikube ip)

sudo apt-get install -y socat
sudo pkill -f 'socat.*8080' 2>/dev/null || true

sudo nohup socat \
  TCP4-LISTEN:8080,reuseaddr,fork \
  TCP4:${MINI_IP}:30083 \
  >/tmp/socat-8080.log 2>&1 &
