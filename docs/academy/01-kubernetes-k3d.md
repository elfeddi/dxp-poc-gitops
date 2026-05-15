# Chapitre 01 — Kubernetes & k3d · Le socle d'exécution

> **Série :** DxP Academy · Stack 0 — Control Plane  
> **Niveau :** Débutant  
> **Durée de lecture :** ~10 minutes

---

## C'est quoi un conteneur ?

Avant de parler de Kubernetes, il faut comprendre les conteneurs.

Un **conteneur** c'est une boîte autonome qui contient une application et tout ce dont elle a besoin pour tourner — le code, les bibliothèques, les dépendances. Peu importe la machine sur laquelle on la pose, elle fonctionne exactement pareil.

> Un conteneur c'est comme un appartement meublé — tout est dedans, tu poses tes valises et tu habites. Pas besoin de racheter des meubles à chaque déménagement.

**Docker** est l'outil qui crée et fait tourner ces conteneurs.

---

## Le problème sans Kubernetes

Imaginons que ton application devient populaire. Tu as besoin de :
- Faire tourner 10 copies de ton app en même temps (charge)
- Redémarrer automatiquement si une copie plante
- Mettre à jour l'app sans interruption de service
- Répartir le trafic entre les copies

Avec Docker seul, tu gères tout ça à la main. Sur 3 serveurs, c'est faisable. Sur 50 serveurs avec 200 conteneurs... c'est ingérable.

---

## C'est quoi Kubernetes ?

**Kubernetes** (aussi appelé K8s) est un **orchestrateur de conteneurs**. C'est lui qui décide où et comment faire tourner tes conteneurs sur un ensemble de machines.

> Kubernetes c'est le chef d'orchestre. Les conteneurs sont les musiciens. Kubernetes s'assure que chaque musicien joue la bonne partition, au bon moment, sur le bon instrument — et remplace instantanément celui qui tombe malade.

### Les concepts clés

**Le cluster** — l'ensemble des machines gérées par Kubernetes :
```
Cluster Kubernetes
├── Server (Control Plane) ← le cerveau — prend les décisions
├── Agent 1 (Worker)       ← fait tourner les applications
└── Agent 2 (Worker)       ← fait tourner les applications
```

**Le Pod** — la plus petite unité dans Kubernetes. Un pod contient un ou plusieurs conteneurs qui travaillent ensemble.

**Le Deployment** — dit à Kubernetes "je veux 3 copies de cette application, et maintiens-les en vie".

**Le Service** — expose une application sur le réseau, répartit le trafic entre les pods.

**Le Namespace** — un espace isolé dans le cluster. Comme des dossiers pour organiser les applications.

```
Cluster
├── namespace: argocd    ← ArgoCD et ses pods
├── namespace: vault     ← Vault et ses pods
├── namespace: dxp-demo  ← nos applications
└── namespace: default   ← espace par défaut
```

---

## C'est quoi k3d ?

Kubernetes est conçu pour tourner sur des serveurs en datacenter. Pour développer et tester localement, on a besoin d'une version légère.

**k3s** est une distribution Kubernetes ultra-légère — même fonctionnalités, empreinte mémoire réduite de 50%.

**k3d** fait tourner k3s dans des conteneurs Docker. On obtient un cluster Kubernetes complet sur son poste, en quelques secondes.

```
Ton poste Windows
    └── WSL2 Ubuntu
            └── Docker Engine
                    ├── k3d-dxp-poc-server-0   (Control Plane)
                    ├── k3d-dxp-poc-agent-0    (Worker)
                    └── k3d-dxp-poc-agent-1    (Worker)
```

> k3d c'est comme un simulateur de vol — tu t'entraînes sur terre avec les mêmes commandes et les mêmes sensations qu'en vrai, sans risquer l'avion.

---

## Dans DxP, Kubernetes joue quel rôle ?

Kubernetes est le **socle d'exécution universel** de DxP. Absolument tout tourne dessus :

- Vault → pod dans le namespace `vault`
- ArgoCD → pods dans le namespace `argocd`
- Tekton → pods dans le namespace `tekton-pipelines`
- Backstage → pod dans le namespace `backstage`
- Tes applications → pods dans leurs namespaces

**DxP abstrait Kubernetes.** Les développeurs n'ont pas besoin de connaître kubectl ou les YAMLs complexes — ils utilisent l'interface DxP (Backstage, CLI) et DxP gère Kubernetes en dessous.

---

## kubectl — l'outil de commande

`kubectl` est la commande pour interagir avec Kubernetes. Les commandes de base :

```bash
# Voir les nœuds du cluster
kubectl get nodes

# Voir tous les pods d'un namespace
kubectl get pods -n argocd

# Voir les détails d'un pod
kubectl describe pod <nom-du-pod> -n <namespace>

# Voir les logs d'un pod
kubectl logs <nom-du-pod> -n <namespace>

# Exécuter une commande dans un pod
kubectl exec -n <namespace> <pod> -- <commande>

# Surveiller en temps réel
kubectl get pods -n <namespace> -w
```

---

## Helm — le gestionnaire de paquets Kubernetes

Installer une application dans Kubernetes manuellement nécessite des dizaines de fichiers YAML. **Helm** package tout ça en un seul "chart" (paquet) installable en une commande.

```bash
# Ajouter un repo de charts
helm repo add hashicorp https://helm.releases.hashicorp.com

# Installer une application
helm install vault hashicorp/vault --namespace vault

# Lister les installations
helm list -A

# Désinstaller
helm uninstall vault -n vault
```

> Helm c'est comme apt ou npm — mais pour Kubernetes. Un `helm install` remplace 50 `kubectl apply`.

---

## Notre cluster LiteDxP

```
Cluster : dxp-poc
├── server-0  (Control Plane)  ← API Kubernetes, scheduler, etcd
├── agent-0   (Worker)         ← fait tourner les pods
└── agent-1   (Worker)         ← fait tourner les pods

Load Balancer k3d :
├── Port 8080 → HTTP (ingress)
└── Port 8443 → HTTPS (ingress)
```

---

## Commandes de référence

```bash
# Créer le cluster LiteDxP
k3d cluster create dxp-poc \
  --servers 1 --agents 2 \
  -p "8080:80@loadbalancer" \
  -p "8443:443@loadbalancer"

# Vérifier l'état du cluster
kubectl get nodes
k3d cluster list

# Importer une image Docker dans k3d
k3d image import <image>:<tag> -c dxp-poc

# Arrêter le cluster
k3d cluster stop dxp-poc

# Démarrer le cluster
k3d cluster start dxp-poc

# Supprimer le cluster
k3d cluster delete dxp-poc
```

---

## Résumé

> Kubernetes est le système nerveux de DxP — il fait tourner tous les composants de la plateforme sur un ensemble de machines, gère leur cycle de vie, et assure leur disponibilité. k3d nous permet de répliquer ce système en local sur WSL2, avec les mêmes outils et les mêmes commandes qu'en production.

---

*DxP Academy · Chapitre 01 · Mai 2026*
