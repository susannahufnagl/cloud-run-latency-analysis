# Lebach



## Getting started

To make it easy for you to get started with GitLab, here's a list of recommended next steps.

Already a pro? Just edit this README.md and make it your own. Want to make it easy? [Use the template at the bottom](#editing-this-readme)!

## Add your files

- [ ] [Create](https://docs.gitlab.com/ee/user/project/repository/web_editor.html#create-a-file) or [upload](https://docs.gitlab.com/ee/user/project/repository/web_editor.html#upload-a-file) files
- [ ] [Add files using the command line](https://docs.gitlab.com/topics/git/add_files/#add-files-to-a-git-repository) or push an existing Git repository with the following command:

```
cd existing_repo
git remote add origin https://git.tu-berlin.de/susannahufnagl/lebach.git
git branch -M main
git push -uf origin main
```

## Integrate with your tools

- [ ] [Set up project integrations](https://git.tu-berlin.de/susannahufnagl/lebach/-/settings/integrations)

## Collaborate with your team

- [ ] [Invite team members and collaborators](https://docs.gitlab.com/ee/user/project/members/)
- [ ] [Create a new merge request](https://docs.gitlab.com/ee/user/project/merge_requests/creating_merge_requests.html)
- [ ] [Automatically close issues from merge requests](https://docs.gitlab.com/ee/user/project/issues/managing_issues.html#closing-issues-automatically)
- [ ] [Enable merge request approvals](https://docs.gitlab.com/ee/user/project/merge_requests/approvals/)
- [ ] [Set auto-merge](https://docs.gitlab.com/user/project/merge_requests/auto_merge/)

## Test and Deploy

Use the built-in continuous integration in GitLab.

- [ ] [Get started with GitLab CI/CD](https://docs.gitlab.com/ee/ci/quick_start/)
- [ ] [Analyze your code for known vulnerabilities with Static Application Security Testing (SAST)](https://docs.gitlab.com/ee/user/application_security/sast/)
- [ ] [Deploy to Kubernetes, Amazon EC2, or Amazon ECS using Auto Deploy](https://docs.gitlab.com/ee/topics/autodevops/requirements.html)
- [ ] [Use pull-based deployments for improved Kubernetes management](https://docs.gitlab.com/ee/user/clusters/agent/)
- [ ] [Set up protected environments](https://docs.gitlab.com/ee/ci/environments/protected_environments.html)


# Stage 0: Basisarchitektur

# 1. alles wieder stoppen, was auf 8080 lauscht 

## z.B.

sudo pkill -f producer || true
pgrep  -a producer  schauen ob er gestoptt ist 
docker stop lat-bench 2>/dev/null || true

sudo systemctl start containerd
sudo nerdctl rm -f lat-bench   # Container weg
sudo systemctl stop containerd 

sudo ss -lntp | egrep ':(80|8080)\b' || echo "nichts auf 80/8080"


# 2. Producer bauen und testen 

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



# Stage 1: S0+ LB/ HTTP


# 1. alles wieder stoppen, was auf 8080 lauscht 

## z.B.

sudo pkill -f producer || true
pgrep  -a producer  schauen ob er gestoptt ist 
docker stop lat-bench 2>/dev/null || true

sudo systemctl start containerd
sudo nerdctl rm -f lat-bench   # Container weg
sudo systemctl stop containerd 

sudo ss -lntp | egrep ':(80|8080)\b' || echo "nichts auf 80/8080"


# 2. Producer bauen und testen 

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





# 3.	LB wieder testen:
## a.	Lokal: 

LB_S1_IP=$(gcloud compute forwarding-rules describe fr-s2-http --global \
        --format='value(IPAddress)')
echo "LB_IP=$LB_IP"

## b.	Auf der VM: 

export LB_S1_IP=34.8.201.151
curl -fsS http://$LB_S1_IP/health

# 4.	Ist das Backend healthy:

gcloud compute backend-services get-health be-s2 --global

# 5.	Testrun durchführen 

CE_BASE="http://$LB_S1_IP" CHANNEL=lb STAGE=1 \
  bash scripts/run_all_concurrent_0.sh
CE_BASE="http://$LB_S1_IP" CHANNEL=lb STAGE=1 \
  bash scripts/run_all_independent_0.sh



# Stage 2: (S1+ Containerisierung in containered)

# 1. alles stoppen was auf 8080

## z.B 
pkill -x producer || true
sudo pkill -f 'socat.*8080' 2>/dev/null || true
sleep 1
sudo ss -lntp | grep ':8080\b' || echo "Port 8080 frei"


# 2.	Falls Minikube noch läuft, das einmal herunterfahren  und stoppen

minikube delete --all --purge

# 3.	Cache leeren

sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches


# 4.	Images neu laden oder builds nachziehen --> habe ich zuvor in docker build gebaut 

sudo nerdctl load < ce-cb-go.tar

# 5.	Key anlegen 
sudo rm -rf /home/susannahufnagl/.gcp/key.json
sudo install -m 600 ~/ba/key.json /home/susannahufnagl/.gcp/sa-key.json




# 6.	Starten des Diensts
sudo nerdctl rm -f lat-bench || true
sudo nerdctl run -d --name lat-bench \
  --runtime runc --net host \
  -e PORT=8080 \
  -e PROJECT=project-accountsec \
  -e TOPIC=cloudrun-broker-single \
  -v /home/susannahufnagl/.gcp/key.json:/var/secrets/gcp/key.json:ro \
  ce-cb-go:latest

# 7.	Testen 

curl -fsS 127.0.0.1:8080/health
sudo ss -lntp | grep ':8080\b'
sudo nerdctl logs lat-bench | tail

# 8.	Logs anschauen bei problemen 

sudo nerdctl logs lat-bench | tail -n 80'

# 9.	Wenn contianer läuft --> Kontrolle 

sudo nerdctl ps 
--> status der lat-bench soll UP sein

# 10.	LB wieder anbinden:

Lokal: 
LB_IP=$(gcloud compute forwarding-rules describe fr-s2-http --global --format='value(IPAddress)')
echo $LB_IP
-->  34.8.201.151
Health von Backend checken:

gcloud compute backend-services get-health be-s2 --global

Auf VM: 

LB_S2_IP=34.8.201.151


curl -fsS http://127.0.0.1:8080/health 

curl -fsS http://$LB_S2_IP/health

# 11.	Ist das Backend healthy?

gcloud compute backend-services get-health be-s2 --global

# 12.	allgemeiner Testrun:

CE_BASE="http://$LB_S2_IP" CHANNEL=lb STAGE=2 \
  bash scripts/run_all_concurrent_0.sh
CE_BASE="http://$LB_S2_IP" CHANNEL=lb STAGE=2 \
  bash scripts/run_all_independent_0.sh











Stage 3 und 4: 

# 1.	Minikube deleten falls noch nicht getan:
sudo -E minikube delete --all --purge
# 2.	Cache leeren 
sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches

sudo rm -f /tmp/juju-mk*

# 3.	
sudo sysctl fs.protected_regular=0


# 4.	minikube neu starten 


export MINIKUBE_HOME=/home/susannahufnagl/.minikube
export KUBECONFIG=/home/susannahufnagl/.kube/config
export CHANGE_MINIKUBE_NONE_USER=true

sudo apt update
sudo apt install -y iptables


sudo -E minikube start \
  --driver=none \
  --container-runtime=containerd \

## Evtl
sudo chown -R susannahufnagl:susannahufnagl /home/susannahufnagl/.minikube /home/susannahufnagl/.kube
sudo chmod -R u+wrx /home/susannahufnagl/.minikube


sudo -E minikube addons enable gvisor
minikube image load ce-cb-go:latest
minikube status

# 5.	Containered restarten (eventuell noch früher machen) 

sudo systemctl restart containerd


# 6.	Containered status abrufen 
sudo systemctl status containerd --no-pager
sudo crictl info | grep RuntimeName

## a.	Eventuell defektte config entfernen und neu anlegen 
sudo systemctl stop containerd
sudo pkill -f 'containerd-shim' || true
sudo mv /etc/containerd/config.toml /etc/containerd/config.toml.broken-$(date +%s)
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

## b.	Containernd wieder starten und hochkommen lassen

sudo systemctl daemon-reload
sudo systemctl restart containerd
sudo systemctl status containerd --no-pager
sudo crictl info | grep RuntimeName



# 7.	alle Resetzen und Neuaufsetzen 

# Deployments/Services säubern (ignoriere Fehler, falls nicht vorhanden)

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
kubectl get node -o wide        # CONTAINER-RUNTIME sollte containerd zeigen
sudo crictl info | grep RuntimeName
sudo crictl ps | head



8.	Kleiner Check 

´

a.	LB testen: 
LB_IP=$(gcloud compute forwarding-rules describe fr-s7-http --global --format='value(IPAddress)')  34.36.203.245

b.	export LB_S4_IP=34.36.203.245, 
c.	echo $LB_S4_IP
d.	curl -i http://$LB_S4_IP/health
e.	auf vm schauen dass kube proxy auf 8080 lauscht und die Weiterleitung zu gVisor steht curl 127.0.0.1:8080/health

9.	Listener auf 8080 einstellen mitels Socat, der dann die Anfragen von LB an Nodeport leitet: 

Zuvor alles killen was auf den Port 8080 lauscht: 

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
