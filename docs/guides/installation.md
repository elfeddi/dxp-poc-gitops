# DxP POC — Installation k3d + ArgoCD
## Guide de référence · Mai 2026

> **Environnement :** WSL2 Ubuntu 22.04 · Docker Engine natif · k3d v5.7.4 · k3s v1.30.4 · ArgoCD v3.4.2  
> **Contexte :** Poste Windows avec proxy Zscaler (TLS inspection)

---

## Sommaire

1. [Prérequis](#1-prérequis)
2. [Création du cluster k3d](#2-création-du-cluster-k3d)
3. [Installation ArgoCD — Sans Zscaler](#3-installation-argocd--sans-zscaler)
4. [Installation ArgoCD — Avec Zscaler](#4-installation-argocd--avec-zscaler)
5. [Exposition de l'UI ArgoCD](#5-exposition-de-lui-argocd)
6. [Vérification finale](#6-vérification-finale)
7. [Référence — images ArgoCD v3.4.2](#7-référence--images-argocd-v342)

---

## 1. Prérequis

- WSL2 Ubuntu 22.04 installé et fonctionnel
- Docker Engine natif dans WSL2 (`docker info` répond sans erreur)
- k3d installé (`k3d version`)
- kubectl installé (`kubectl version --client`)

**Vérifier que Docker tourne en mode natif WSL2 (pas Docker Desktop) :**

```bash
docker context ls
# Doit afficher : unix:///var/run/docker.sock
```

---

## 2. Création du cluster k3d

```bash
k3d cluster create dxp-poc \
  --servers 1 \
  --agents 2 \
  -p "8080:80@loadbalancer" \
  -p "8443:443@loadbalancer"
```

**Vérification :**

```bash
kubectl get nodes
# Attendu : 3 nœuds Ready (server-0, agent-0, agent-1)
```

```
NAME                   STATUS   ROLES                  AGE   VERSION
k3d-dxp-poc-agent-0    Ready    <none>                 ...   v1.30.4+k3s1
k3d-dxp-poc-agent-1    Ready    <none>                 ...   v1.30.4+k3s1
k3d-dxp-poc-server-0   Ready    control-plane,master   ...   v1.30.4+k3s1
```

> **Note :** k3d expose automatiquement les ports 8080 et 8443 via son load balancer (`k3d-dxp-poc-serverlb`). Ces ports sont réservés — ne pas utiliser pour les port-forwards.

---

## 3. Installation ArgoCD — Sans Zscaler

> Utiliser cette section sur un réseau sans proxy TLS inspection (réseau personnel, VPN split, etc.)

### 3.1 Créer le namespace et installer

```bash
kubectl create namespace argocd

kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 3.2 Attendre que tous les pods soient Running

```bash
kubectl get pods -n argocd -w
```

Tous les pods suivants doivent atteindre `1/1 Running` :

| Pod | Rôle |
|-----|------|
| `argocd-server` | API + UI |
| `argocd-repo-server` | Gestion des repos Git |
| `argocd-application-controller` | Réconciliation GitOps |
| `argocd-dex-server` | Authentification SSO |
| `argocd-redis` | Cache |
| `argocd-notifications-controller` | Notifications |
| `argocd-applicationset-controller` | ApplicationSets |

### 3.3 Passer à l'exposition de l'UI → [Section 5](#5-exposition-de-lui-argocd)

---

## 4. Installation ArgoCD — Avec Zscaler

> Utiliser cette section sur un réseau d'entreprise avec Zscaler (TLS inspection active).  
> **Symptôme :** `ErrImagePull` avec le message `x509: certificate signed by unknown authority`

Zscaler intercepte le TLS et génère des certificats à la volée. Les nœuds k3d ne font pas confiance à son CA. La solution : extraire les CAs Zscaler et les injecter dans WSL2, Docker et k3d.

### 4.1 Extraire le CA Root Zscaler (PowerShell admin Windows)

```powershell
# Lister les CAs Zscaler présents dans le store Windows
Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*Zscaler*" }

# Exporter le Root CA (utiliser le thumbprint du "Zscaler Root CA")
$cert = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Thumbprint -eq "<THUMBPRINT_ROOT>" }
Export-Certificate -Cert $cert -FilePath "$env:USERPROFILE\Desktop\zscaler-root.crt" -Type CERT
certutil -encode "$env:USERPROFILE\Desktop\zscaler-root.crt" "$env:USERPROFILE\Desktop\zscaler-root.pem"
```

> Remplacer `<THUMBPRINT_ROOT>` par le thumbprint du certificat `CN=Zscaler Root CA`.

### 4.2 Extraire le CA Intermediate Zscaler (WSL2)

Le Root CA ne suffit pas — Zscaler utilise une chaîne à 3 niveaux :  
`Zscaler Root CA → Zscaler Intermediate CA → *.domaine.com`

```bash
# Extraire l'Intermediate CA depuis une connexion live
openssl s_client -connect quay.io:443 -showcerts 2>/dev/null \
  | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/{ print }' \
  | awk 'BEGIN{n=0} /BEGIN CERTIFICATE/{n++} n==2{print}' \
  > /tmp/zscaler-intermediate.pem

# Vérifier
head -3 /tmp/zscaler-intermediate.pem
# Doit afficher : -----BEGIN CERTIFICATE-----
```

### 4.3 Injecter les CAs dans WSL2

```bash
# Copier le Root CA depuis Windows
cp /mnt/c/Users/<USERNAME>/Desktop/zscaler-root.pem /tmp/zscaler-root.pem

# Injecter Root CA
sudo cp /tmp/zscaler-root.pem /usr/local/share/ca-certificates/zscaler-root.crt

# Injecter Intermediate CA
sudo cp /tmp/zscaler-intermediate.pem /usr/local/share/ca-certificates/zscaler-intermediate.crt

# Mettre à jour le bundle système
sudo update-ca-certificates
```

### 4.4 Injecter dans Docker (certs.d)

```bash
# quay.io — registry principal ArgoCD
sudo mkdir -p /etc/docker/certs.d/quay.io
sudo cp /tmp/zscaler-intermediate.pem /etc/docker/certs.d/quay.io/ca.crt

# ghcr.io — GitHub Container Registry (dex)
sudo mkdir -p /etc/docker/certs.d/ghcr.io
sudo cp /tmp/zscaler-intermediate.pem /etc/docker/certs.d/ghcr.io/ca.crt

# public.ecr.aws — Amazon ECR Public (redis)
sudo mkdir -p /etc/docker/certs.d/public.ecr.aws
sudo cp /tmp/zscaler-intermediate.pem /etc/docker/certs.d/public.ecr.aws/ca.crt

# Redémarrer Docker
sudo systemctl restart docker
```

### 4.5 Puller les images ArgoCD depuis WSL2

```bash
docker pull quay.io/argoproj/argocd:v3.4.2
docker pull ghcr.io/dexidp/dex:v2.45.0
docker pull public.ecr.aws/docker/library/redis:8.2.3-alpine
```

> **Note :** Pour ghcr.io, utiliser `dexidp` (sans tiret) et non `dex-idp`. La version exacte de dex pour ArgoCD v3.4.2 est `v2.45.0` et redis `8.2.3-alpine` — vérifiable via :
> ```bash
> curl -sk https://raw.githubusercontent.com/argoproj/argo-cd/v3.4.2/manifests/install.yaml | grep "image:"
> ```

### 4.6 Importer les images dans tous les nœuds k3d

```bash
k3d image import \
  quay.io/argoproj/argocd:v3.4.2 \
  ghcr.io/dexidp/dex:v2.45.0 \
  public.ecr.aws/docker/library/redis:8.2.3-alpine \
  -c dxp-poc

# Vérifier la présence sur chaque nœud
docker exec k3d-dxp-poc-server-0 crictl images | grep -E "argocd|dex|redis"
docker exec k3d-dxp-poc-agent-0 crictl images | grep -E "argocd|dex|redis"
docker exec k3d-dxp-poc-agent-1 crictl images | grep -E "argocd|dex|redis"
```

### 4.7 Installer ArgoCD

```bash
kubectl create namespace argocd

kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 4.8 Patcher imagePullPolicy sur tous les workloads

Sans ce patch, k3s tente de re-puller les images depuis internet même si elles sont déjà présentes localement.

```bash
# Deployments
for deploy in argocd-server argocd-repo-server argocd-applicationset-controller argocd-notifications-controller; do
  kubectl patch deployment $deploy -n argocd --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]'
done

# StatefulSet
kubectl patch statefulset argocd-application-controller -n argocd --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]'

# Redis et Dex ont des initContainers — patch les deux niveaux
kubectl patch deployment argocd-redis -n argocd --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/initContainers/0/imagePullPolicy","value":"IfNotPresent"},
       {"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]'

kubectl patch deployment argocd-dex-server -n argocd --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/initContainers/0/imagePullPolicy","value":"IfNotPresent"},
       {"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]'
```

### 4.9 Vérifier que tous les pods essentiels sont Running

```bash
kubectl get pods -n argocd
```

État cible :

```
argocd-application-controller-0      1/1     Running
argocd-dex-server-xxx                1/1     Running
argocd-notifications-controller-xxx  1/1     Running
argocd-redis-xxx                     1/1     Running
argocd-repo-server-xxx               1/1     Running
argocd-server-xxx                    1/1     Running
```

> `argocd-applicationset-controller` peut être en CrashLoopBackOff — non bloquant pour le POC de base.

---

## 5. Exposition de l'UI ArgoCD

Les ports 8080 et 8443 sont déjà occupés par le load balancer k3d. Utiliser un port libre.

```bash
# Dans un terminal dédié (laisser tourner)
kubectl port-forward svc/argocd-server -n argocd 9090:443
```

Accès : **`https://localhost:9090`** dans le navigateur Windows.  
Accepter le certificat auto-signé.

---

## 6. Vérification finale

### 6.1 Récupérer le mot de passe admin

> Ouvrir un **nouveau terminal WSL2** (sans export KUBECONFIG modifié) :

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### 6.2 Se connecter

- URL : `https://localhost:9090`
- Login : `admin`
- Mot de passe : résultat de la commande ci-dessus

### 6.3 État attendu

ArgoCD v3.4.2 — UI accessible, aucune application enregistrée, cluster `in-cluster` disponible dans Settings → Clusters.

---

## 7. Référence — images ArgoCD v3.4.2

| Image | Version | Registry |
|-------|---------|----------|
| ArgoCD | `v3.4.2` | `quay.io/argoproj/argocd` |
| Dex | `v2.45.0` | `ghcr.io/dexidp/dex` |
| Redis | `8.2.3-alpine` | `public.ecr.aws/docker/library/redis` |

> Les versions exactes sont toujours vérifiables via :
> ```bash
> curl -sk https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml | grep "image:"
> ```

---

## Notes et pièges à éviter

| Piège | Symptôme | Solution |
|-------|----------|----------|
| Zscaler chaîne 3 niveaux | `unable to get local issuer certificate` | Injecter **aussi** l'Intermediate CA, pas seulement le Root |
| Images manquantes sur certains nœuds | Pods en `ErrImagePull` après import | `k3d image import` importe sur tous les nœuds simultanément |
| Version Redis incorrecte | Redis en `ErrImagePull` malgré l'import | ArgoCD v3.4.2 utilise `redis:8.2.3-alpine`, pas `7.0.15` |
| KUBECONFIG modifié en session | `permission denied` sur `/root/.kube/config` | Ouvrir un nouveau terminal WSL2 |
| Ports 8080/8443 occupés | `address already in use` sur port-forward | Utiliser le port 9090 (ou tout autre port libre) |
| `dex-idp` vs `dexidp` | `denied` sur ghcr.io | Le namespace correct est `dexidp` (sans tiret) |

---

*DxP POC · Documentation technique · Mai 2026*
