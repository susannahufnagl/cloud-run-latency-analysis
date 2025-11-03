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

***

# Editing this README

When you're ready to make this README your own, just edit this file and use the handy template below (or feel free to structure it however you want - this is just a starting point!). Thanks to [makeareadme.com](https://www.makeareadme.com/) for this template.

## Suggestions for a good README

Every project is different, so consider which of these sections apply to yours. The sections used in the template are suggestions for most open source projects. Also keep in mind that while a README can be too long and detailed, too long is better than too short. If you think your README is too long, consider utilizing another form of documentation rather than cutting out information.

## Name
Choose a self-explaining name for your project.

## Description
Let people know what your project can do specifically. Provide context and add a link to any reference visitors might be unfamiliar with. A list of Features or a Background subsection can also be added here. If there are alternatives to your project, this is a good place to list differentiating factors.

## Badges
On some READMEs, you may see small images that convey metadata, such as whether or not all the tests are passing for the project. You can use Shields to add some to your README. Many services also have instructions for adding a badge.

## Visuals
Depending on what you are making, it can be a good idea to include screenshots or even a video (you'll frequently see GIFs rather than actual videos). Tools like ttygif can help, but check out Asciinema for a more sophisticated method.

## Installation
Within a particular ecosystem, there may be a common way of installing things, such as using Yarn, NuGet, or Homebrew. However, consider the possibility that whoever is reading your README is a novice and would like more guidance. Listing specific steps helps remove ambiguity and gets people to using your project as quickly as possible. If it only runs in a specific context like a particular programming language version or operating system or has dependencies that have to be installed manually, also add a Requirements subsection.

## Usage
Use examples liberally, and show the expected output if you can. It's helpful to have inline the smallest example of usage that you can demonstrate, while providing links to more sophisticated examples if they are too long to reasonably include in the README.

## Support
Tell people where they can go to for help. It can be any combination of an issue tracker, a chat room, an email address, etc.

## Roadmap
If you have ideas for releases in the future, it is a good idea to list them in the README.

## Contributing
State if you are open to contributions and what your requirements are for accepting them.

For people who want to make changes to your project, it's helpful to have some documentation on how to get started. Perhaps there is a script that they should run or some environment variables that they need to set. Make these steps explicit. These instructions could also be useful to your future self.

You can also document commands to lint the code or run tests. These steps help to ensure high code quality and reduce the likelihood that the changes inadvertently break something. Having instructions for running tests is especially helpful if it requires external setup, such as starting a Selenium server for testing in a browser.

## Authors and acknowledgment
Show your appreciation to those who have contributed to the project.

## License
For open source projects, say how it is licensed.

## Project status
If you have run out of energy or time for your project, put a note at the top of the README saying that development has slowed down or stopped completely. Someone may choose to fork your project or volunteer to step in as a maintainer or owner, allowing your project to keep going. You can also make an explicit request for maintainers.


# Keep alive Optionen neu verbinden um Broken pipe zu verhindern 
gcloud compute ssh ce-latency-bench --zone europe-west10-b -- \
  -o ServerAliveInterval=30 -o ServerAliveCountMax=3

sudo apt update && sudo apt install -y tmux

# neue beständige session 

tmux new -s bench


# S0 ausführen lassen 
#   VM starten 
1. source .env.local
2. vm up 
3. vm ssh 
4. ins repo lotsen und git pullen 

# producer starten --> auch für S1

cd ~/ba/services/Cloud-Run/go-producer   
go mod tidy
go build -o producer .

./producer > /tmp/producer.log 2>&1 & # starten 
#   läuft der producer wirklich? 
sudo ss -lntp | egrep ':(80|8080)\b' || echo "nichts auf 80/8080"
LISTEN 0      4096               *:8080            *:*    users:(("producer",pid=2980,fd=9))       




#   Producer läuft & CE_BASE lokal:
export CE_BASE="http://127.0.0.1:8080"
set -a; source ~/ba/.env; set +a    # für CR_BASE in den CR-Tests
bash ~/ba/scripts/run_all_concurrent_0.sh
bash ~/ba/scripts/run_all_independent_0.sh


## aktualisierte ersion 

STAGE=0 bash ~/repo/scripts/run_all_concurrent_0.sh
STAGE=0 bash ~/repo/scripts/run_all_independent_0.sh

( # S2
    ## Firewall Rules erfahren --> aus Lokal 
    gcloud compute firewall-rules list --filter="name~8080"

    ## Health Testen des lazfenden Prozesses und des LoadBalancers 

    (# lokal
    curl -i http://localhost:8080/health || tail -n 200 /tmp/producer.log

    export PROJECT="${PROJECT:-${PROJECT_ID:-}}"
    export TOPIC="${TOPIC:-${TOPIC_ID:-}}"

    pkill -f 'producer' 2>/dev/null || true
    cd ~/ba/services/Cloud-Run/go-producer
    nohup ./producer > /tmp/producer.log 2>&1 &)


    # checken ob die Project und Topic übergebne wurden 
    tr '\0' '\n' < /proc/$PID/environ | egrep '^(PROJECT|TOPIC)=' || echo "ENV im Prozess fehlen"

    # müssen nach dem starten des Producers hier übergeben werden oder inline wie hier


    # alternatives

    export PROJECT=project-accountsec
    export TOPIC=cloudrun-broker-single
    pkill -f producer 2>/dev/null || true
    nohup ./producer > /tmp/producer.log 2>&1 &




    # via Load Balancer
    LB_IP=$(gcloud compute forwarding-rules describe fr-s2-http --global --format='value(IPAddress)')
    curl -i "http://$LB_IP/health"


    ## Backend Gesundheit aus Sicht des LB

    gcloud compute backend-services get-health be-s2 --global

    ## Von wo kommen Verbindunegn an 8080 

    sudo journalctl -u your-service | tail
    # oder mit tcpdump
    sudo tcpdump -n host 35.191.0.0/16 or host 130.211.0.0/22

    # prüfen was an benötigten elementen für S2 schone existiert 

    gcloud compute instance-groups unmanaged list --zones=europe-west10-b
    gcloud compute instance-groups unmanaged list-instances mig-s2 --zone=europe-west10-b
    gcloud compute health-checks describe hc-8080
    gcloud compute backend-services list
    gcloud compute url-maps list
    gcloud compute target-http-proxies list
    gcloud compute forwarding-rules list

    # starten der Tests 

    LB_IP=$(gcloud compute forwarding-rules describe fr-s2-http --global --format='value(IPAddress)')
    echo "LB_IP=$LB_IP" 

    curl -i "http://$LB_IP/health"


    export CE_BASE="http://$LB_IP:8080"
    set -a; source ~/repo/.env; set +a    # für CR_BASE in den CR-Tests
    bash ~/repo/scripts/run_all_concurrent_0.sh
    bash ~/repo/scripts/run_all_independent_0.sh
)

# S1 tatsächlicher start verlauf zuvor

# alle lauschenden Prozesse auf irgendeinen Port anzeigen lassen 

sudo ss -lntp



pkill -x producer || true
sleep 1
sudo ss -lntp | grep ':8080\b' || echo "Port 8080 frei"

export PROJECT=project-accountsec
export PROJECT_ID="$PROJECT"
export GOOGLE_CLOUD_PROJECT="$PROJECT"

export TOPIC=cloudrun-broker-single
export TOPIC_ID="$TOPIC"

export PORT=8080


cd ~/ba/services/Cloud-Run/go-producer
go version >/dev/null 2>&1 || sudo apt update && sudo apt install -y golang
go build -o producer .


./producer > /tmp/producer.log 2>&1 &
sleep 1
curl -i http://127.0.0.1:8080/health || tail -n 200 /tmp/producer.log


## pgrep sucht alle laufenden Prozesse, deren Name exakt producer lautet
# head n1 nimmt nur den ersten treffer falls mehrere. producer prozesse laufenden
# ergebnis wird in pid gespeichert 
## environ enthält alle umgebungsariablen mit denne der Prozess gestartet wurde
pid=$(pgrep -x producer | head -n1)
echo "PID=$pid"
sudo tr '\0' '\n' < /proc/$pid/environ | egrep '^(PROJECT|TOPIC|PORT)='


curl -i http://localhost:8080/health || tail -n 200 /tmp/producer.log # Der Load‑Balancer wurde in dieser Phase so konfiguriert, dass er den Frontend‑Port 8080 annahm und eins‑zu‑eins auf Port 8080 der VM weiterleitete. Das ist technisch möglich – Google‑Cloud‑Load‑Balancer unterstützen 80, 8080 und 443 als öffentliche Ports – und vereinfacht die Messung, weil kein zusätzlicher URL‑Map‑Hop oder Port‑Übersetzung stattfindet.


LB_IP=$(gcloud compute forwarding-rules describe fr-s2-http --global --format='value(IPAddress)')  #lokal aufrufen 
echo "LB_IP=$LB_IP"   
<!-- die loadbalcner anfrage geh tnur über den lokalen host -->


curl -i "http://$LB_IP/health" #lokal aufrufen

## Tests ausführen 

STAGE=1 CE_BASE="http://$LB_IP:8080" bash ~/ba/scripts/run_all_concurrent_0.sh
STAGE=1 CE_BASE="http://$LB_IP:8080" bash ~/ba/scripts/run_all_independent_0.sh


# S2 Docker Version 

# 0) Ziel & Prinzip

Konstante halten:  LB, IP, Port (8080), IAM/ADC, Topic, Testskripte, COUNT/SLEEP identisch lassen
Einzige Variable:** Prozess läuft vorher direkt auf der VM, jetzt im Container



# A) Basis (Referenz) – Binary auf der VM

1. Aufräumen & Port prüfen

```bash
pkill -x producer || true --> müssen wir nicht machen außer wir greifen nicht aus docker grade darauf zu 
alternativ nur: docker restart lat-bench
sudo ss -lntp | grep ':8080\b' || echo "Port 8080 frei"

```
Antwort:
LISTEN 0      4096         0.0.0.0:8080      0.0.0.0:*    users:(("docker-proxy",pid=5068,...))
LISTEN 0      4096            [::]:8080         [::]:*    users:(("docker-proxy",pid=5074,...))



Das heißt:
Port 8080 auf deiner VM wird vom docker-proxy „überwacht“.
Der docker-proxy ist der Prozess, der alles, was an der VM auf 8080 ankommt, an deinen Container weiterleitet.
Also:
Client → VM:8080 → docker-proxy → Container (App auf 8080)

3. Was du jetzt machen kannst
Du kannst direkt prüfen, ob dein Container auch wirklich läuft und reagiert:
curl -fsS http://127.0.0.1:8080/health && echo "Container erreichbar ✅"


2. Env & App starten (wie gehabt)

```bash
export PROJECT=project-accountsec
export GOOGLE_CLOUD_PROJECT="$PROJECT"
export TOPIC=cloudrun-broker-single
export TOPIC_ID="$TOPIC"
export PORT=8080

cd ~/ba/services/Cloud-Run/go-producer
go build -o producer .
./producer > /tmp/producer.log 2>&1 &
```

3. Health & LB testen

```bash
curl -fsS http://127.0.0.1:8080/health && echo ok
LB_IP=$(gcloud compute forwarding-rules describe fr-s2-http --global --format='value(IPAddress)')
curl -fsS "http://$LB_IP:8080/health" && echo LB ok
```

4. Messlauf (Referenz)

```bash
CR_BASE="https://<dein-cloud-run>.europe-west10.run.app" \
CE_BASE="http://$LB_IP:8080" \
STAGE=1 \
bash ~/ba/scripts/run_all_concurrent_0.sh

CR_BASE="https://<dein-cloud-run>.europe-west10.run.app" \
CE_BASE="http://$LB_IP:8080" \
STAGE=1 \
bash ~/ba/scripts/run_all_independent_0.sh
```

→ CSVs sichern (Ordnerpfad aus Skript-Ausgabe notieren)

---

# B) Containerisiert – **einziger Unterschied: Prozess läuft im Container**

1. Binary stoppen, Container sauber neu starten

```bash
pkill -x producer || true
docker rm -f lat-bench 2>/dev/null || true
sudo ss -lntp | grep ':8080\b' || echo "Port 8080 frei"
```

2. Env setzen (gleich wie oben)

```bash
export PROJECT=project-accountsec
export GOOGLE_CLOUD_PROJECT="$PROJECT"
export TOPIC=cloudrun-broker-single
export TOPIC_ID="$TOPIC"
export PORT=8080
```

3. Container Cloud-Run-artig starten (**gleicher Host-Port 8080!**)

```bash
docker run -d --name lat-bench --restart=always \
  -p 8080:8080 \
  --cpus=1 --memory=1024m \
  --read-only \
  --tmpfs /tmp:rw,nosuid,nodev,noexec,size=256m \
  --security-opt no-new-privileges \
  --pids-limit=4096 --cap-drop ALL \
  --user 65532:65532 \
  --stop-timeout 30 \
  -e PORT -e PROJECT -e GOOGLE_CLOUD_PROJECT -e TOPIC -e TOPIC_ID \
  ce-cb-go:latest
```

Wichtig: App im Container muss auf `0.0.0.0:$PORT` lauschen


4. Health & LB testen (Pfad identisch)

```bash
curl -fsS http://127.0.0.1:8080/health && echo ok ## anscheinend bei restart hier erst anfangen und docker merkt sich die variablen 
docker logs --tail 100 -f lat-bench
## docker exec -it lat-bench env | egrep 'PROJECT|TOPIC|PORT'
LB_IP=$(gcloud compute forwarding-rules describe fr-s2-http --global --format='value(IPAddress)')
echo "LB_IP=$LB_IP"

curl -fsS "http://$LB_IP:8080/health" && echo LB ok
```

5. Messlauf (Container)

```bash

sh
```


STAGE=2 CE_BASE="http://$LB_IP" bash ~/ba/scripts/run_all_concurrent_0.sh
STAGE=2 CE_BASE="http://$LB_IP" bash ~/ba/scripts/run_all_independent_0.sh


---

# C) Auswertung & Checks

* Vergleich: nutze die zwei CSV-Sets (Basis vs Container) mit identischen COUNT/SLEEP
* Relevante Spalten: `client_total_ms` (End-to-End), `server_latency_ms` (aus deiner App)
* Delta Containerisierung = Mittelwert(Container) − Mittelwert(Basis)

Sanity-Checks

```bash
# zeigt, dass Host:8080 vom docker-proxy gemappt ist
sudo ss -lntp | egrep ':(8080)\b'

# lauscht die App im Container?
docker exec -it lat-bench sh -c 'ss -lntp | grep ":8080 " || netstat -lntp | grep ":8080 "'

# Env im Container
docker exec -it lat-bench env | egrep 'PROJECT|TOPIC|PORT'
-- ```
# von au0en schauen ob docker container lauscht \ 

curl -fsS http://127.0.0.1:8080/health && echo "Container erreichbar ✅"

<!--  geht weil docker-proxy den Host-Port 8080 auf den Container Port weiterleitet  -->

# D) Warum das sauber ist (Port-Story in 1 Minute)


# E) Häufige Stolpersteine (fix in Sekunden)

* 8080 belegt → `docker rm -f lat-bench` oder Mapping prüfen
* App hört nur auf `127.0.0.1` → in Code `0.0.0.0` setzen
* LB spricht anderen Port → immer `:8080` durchgängig (Frontend, Backend, VM, Container)
* Doppelt laufende Binary + Container → vorher immer `pkill -x producer`


## Neustarten:

prüfen ob Docker läuft:

sudo systemctl status docker --no-pager

schauen ob Container existiert: docker ps -a



### 1) Minikube starten (Docker-Treiber)

```bash
minikube start --driver=docker
kubectl get nodes ##  <!-- gibt overview über die present nodes in dem Kubernetes cluser  -->, also ob unser Minikube cluster wirklich läuft

## Falls Kubernetes noch nicht nsatlliert ist machen wir das so: minikube kubectl -- get nodes

<!-- 
## Wir setzen alias für minikube kubect1 : alias kubectl="minikube kubectl --" -->
--> was wir bis hier hin gemacht haben_ Cluster läuft, ce-cb-go:latest ist schon in Minikube geladen

Nächste Schritte, ohne Yaml, 1. Deployment erstellen

```
minikube image load ce-cb-go:latest

### 2) Docker-Build in Minikube (damit K8s das Image findet)

```bash
# Docker-CLI auf den Minikube-Daemon umbiegen
eval $(minikube -p minikube docker-env)

# Im Projektordner mit deinem Dockerfile:
docker build -t lat-bench:local .

--> antwort f05e64a363f4   gcr.io/k8s-minikube/kicbase:v0.0.48   "/usr/local/bin/entr…"   7 minutes ago   Up 7 minutes   127.0.0.1:32768->22/tcp, 127.0.0.1:32769->2376/tcp, 127.0.0.1:32770->5000/tcp, 127.0.0.1:32771->8443/tcp, 127.0.0.1:32772->32443/tcp   minikube
```

### 3) Deployment + Service anlegen

Erstelle `lat-bench-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lat-bench
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lat-bench
  template:
    metadata:
      labels:
        app: lat-bench
    spec:
      containers:
      - name: lat-bench
        image: lat-bench:local
        imagePullPolicy: IfNotPresent
        env:
        - name: PORT
          value: "8080"
        - name: GOOGLE_CLOUD_PROJECT
          value: "DEIN_PROJECT_ID"
        - name: PROJECT
          value: "DEIN_PROJECT_ID"
        - name: PROJECT_ID
          value: "DEIN_PROJECT_ID"
        - name: TOPIC
          value: "DEIN_TOPIC"
        - name: TOPIC_ID
          value: "DEIN_TOPIC"
        ports:
        - containerPort: 8080
```

Erstelle `lat-bench-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: lat-bench-svc
spec:
  type: NodePort
  selector:
    app: lat-bench
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080   # fest, damit du stabile URL hast
```

### 4) Anwenden & prüfen

```bash
kubectl apply -f lat-bench-deployment.yaml
kubectl apply -f lat-bench-service.yaml

kubectl get pods -o wide
kubectl logs -l app=lat-bench --tail=100
```

### 5) URL holen & Healthcheck

```bash
minikube service lat-bench-svc --url

curl -sS http://192.168.49.2:30080/health
```


# Anwenden der beiden yamls 

kubectl apply -f deployment.yaml
kubectl apply -f service.yaml


## Port forward im Vordergrund starten um von lokalen computer oder hier der vm auf den Üod im Kubernetes Cluster zuzugreifen

POD=$(kubectl get pods -l app=lat-bench -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward pod/$POD 8080:8080

auf anderer vm terminal curl -i http://127.0.0.1:8080/health
darüberhinaus 
curl -i http://127.0.0.1:8080/send/nobatch
curl -i http://127.0.0.1:8080/send/batch

1. auf vm ein lokales image in Minikube-node öaden

# auf der VM: dein lokales Image in den Minikube-Node laden
minikube image load ce-cb-go:latest

2. SA secret wenn vm oder key neu sind 
kubectl delete secret gcp-sa 2>/dev/null || true
kubectl create secret generic gcp-sa --from-file=key.json=./key.json


3. Ready? verifzieren 

kubectl get deploy lat-bench
kubectl get pods -l app=lat-bench -o wide
kubectl logs deploy/lat-bench --tail=50


Port forward im vordergrund und dann wie oben oder im hintergrund

URL="$(minikube service lat-bench --url)"
curl -i "$URL/health" 
curl -i "$URL/send/nobatch"
curl -i "$URL/send/batch"         

STAGE=3 CE_BASE="$URL" bash ~/ba/scripts/run_all_independent_0.sh
STAGE=3 CE_BASE="$URL" bash ~/ba/scripts/run_all_concurrent_0.sh