# Session 03 — Harbor
## 15 Mai 2026

### Objectif
Installer Harbor comme registry d'images privé de LiteDxP. Corriger le CrashLoop ArgoCD ApplicationSet controller.

### Environnement
- Harbor v2.15.0 · Helm chart v1.19.0
- Mode : NodePort, TLS désactivé, persistence désactivée
- Namespace : `harbor`
- Port d'accès : 30002 → port-forward 9091

### Ce qu'on a fait
1. Fix ArgoCD ApplicationSet controller (CRD manquante → restart suffisait)
2. Ajout du repo Helm Harbor
3. Identification des 10 images Harbor nécessaires
4. Pull des images + import par groupes de 3 dans k3d (limite taille tarball)
5. Installation Harbor via Helm
6. Création du projet `dxp` dans l'UI Harbor
7. Push du values.yaml dans le repo GitOps

### Décisions prises
- Import par groupes de 3 images max — au-delà le tarball k3d échoue silencieusement
- TLS désactivé pour le POC — HTTP simple sur nodePort 30002
- Persistence désactivée — données perdues au redémarrage (normal POC)
- Projet `dxp` public dans Harbor — simplifie les pulls sans auth pour le POC
- Port-forward sur 9091 (9090 réservé ArgoCD)

### Problèmes rencontrés
| Problème | Cause | Solution |
|----------|-------|----------|
| `k3d image import` silencieusement vide sur 10 images | Tarball trop lourd pour le volume k3d | Import par groupes de 3 images max |
| `harbor-jobservice` CrashLoop au démarrage | Dépendance harbor-core pas encore prête | Auto-résolu après quelques secondes |
| ArgoCD ApplicationSet CrashLoop depuis session 01 | CRD `ApplicationSet` annotation trop longue | `kubectl rollout restart` suffisait — CRD déjà présente |

### Commandes clés

```bash
# Statut Harbor
kubectl get pods -n harbor

# Accès UI
kubectl port-forward -n harbor svc/harbor 9091:80
# → http://localhost:9091 · admin / Harbor12345

# Pusher une image vers Harbor
docker tag mon-image:tag localhost:30002/dxp/mon-image:tag
docker push localhost:30002/dxp/mon-image:tag
```

### État en fin de session
- ✅ Harbor v2.15.0 Running (8 pods)
- ✅ Trivy scanner intégré (scan CVE automatique)
- ✅ Projet `dxp` créé
- ✅ values.yaml versionnée dans GitOps
- ⚠️ Persistence désactivée — données perdues au redémarrage

### Prochaine session
- Tekton (pipelines CI/CD — build → push Harbor)
