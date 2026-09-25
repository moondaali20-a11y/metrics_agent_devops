# Démarche complète + commandes — TP DevOps (à rendre samedi)

## ⚠️ Point CRITIQUE avant de commencer : oui, il faut cloner le vrai dépôt

Le sujet est noté sur **votre code fourni**, pas sur une réimplémentation. J'ai consulté
la page publique de `https://github.com/Mficius/metrics_agent` (sans pouvoir le cloner
depuis mon environnement, qui n'a pas accès réseau) et voici ce qu'elle contient
réellement, **déjà confirmé** :

```
metrics_agent/                  (contenu RÉEL du dépôt fourni)
├── app/                        (agent.py, api.py, collector.py, config.py, formatter.py, sender.py, __init__.py)
├── tests/                      (test_api.py, test_collector.py, test_formatter.py, test_sender.py)
├── .env.example                (METRICS_ENDPOINT, COLLECTION_INTERVAL=5, REQUEST_TIMEOUT=5)
├── .gitignore
├── requirements.txt             (fastapi, uvicorn, psutil, requests, python-dotenv, pytest — TOUT dans un seul fichier)
└── README.md
```

**Aucun `Dockerfile`, `docker-compose.yaml`, ni `.github/workflows/` n'existe encore dans
ce dépôt** — c'est exactement le travail que le sujet vous demande d'ajouter. Ce zip
fournit donc précisément les fichiers manquants, déjà adaptés à cette structure réelle.

Détails qui ont un impact technique (déjà pris en compte dans les fichiers de ce zip) :
- `requirements.txt` contient **déjà `pytest`** en une seule liste (pas de fichier séparé
  dev/prod chez eux) → mon `Dockerfile` de production **filtre automatiquement** la ligne
  `pytest` avant d'installer les dépendances, pour respecter la consigne "sans pytest en
  prod" sans toucher à leur fichier.
- `REQUEST_TIMEOUT` vaut **5** par défaut chez eux (pas 3 comme écrit dans le sujet PDF,
  probablement une petite incohérence du sujet — gardez la valeur du `.env.example` réel).
- La collecte de la charge système passe par `subprocess` + la commande `uptime`, et le
  payload envoyé à l'API est imbriqué (`{"agent":..., "event_type":..., "data": {...}}`) —
  cela ne change **rien** à vos Dockerfiles/Compose/CI, qui ne dépendent que des points
  d'entrée (`app.api:app`, `python -m app.agent`) et de la route `/health`.

➡️ **Ce que vous devez faire concrètement :**
1. Clonez le **vrai** dépôt : `git clone https://github.com/Mficius/metrics_agent.git`
2. Copiez **uniquement** ces fichiers de ce zip par-dessus, à la racine du clone :
   `Dockerfile`, `Dockerfile.dev`, `docker-compose.yaml`, `docker-compose.override.yml`,
   `.dockerignore`, `.github/workflows/ci-cd.yml`, `requirements-dev.txt`, `README.md`
3. **Ne remplacez pas** leur `app/`, `tests/`, `requirements.txt`, `.env.example` ni
   `.gitignore` d'origine — gardez-les tels quels (ajoutez juste `DOCKERHUB_USERNAME=...`
   à la fin de leur `.env.example` si vous voulez, sinon exportez-le en variable shell).
4. Le dossier `app/`/`tests/` fourni dans ce zip ne sert que de **filet de sécurité** :
   si jamais le clone échoue ou que la structure diverge trop, vous avez une version
   fonctionnelle de repli qui respecte exactement l'architecture attendue par le sujet.

---

## Étape 0 — Récupérer le vrai projet (5 min)

```bash
git clone https://github.com/Mficius/metrics_agent.git
cd metrics_agent
```

Regardez le `requirements.txt` fourni : si les noms de paquets diffèrent de ceux de ce
zip, remplacez mon `requirements.txt`/`requirements-dev.txt` par les leurs (en ajoutant
`pytest` + `httpx` dans le fichier `-dev`).

## Étape 1 — Copier les fichiers d'infrastructure (5 min)

Copiez dans le dossier du projet cloné (racine) :

```
.dockerignore
.gitignore
.env.example
Dockerfile
Dockerfile.dev
docker-compose.yaml
docker-compose.override.yml
.github/workflows/ci-cd.yml
README.md
```

**Ne remplacez PAS** leur dossier `app/` ni `tests/` si le contenu fourni diffère du mien.

## Étape 2 — Test en développement (hot-reload) — 10 min

```bash
cp .env.example .env
docker compose up --build
```

Dans un **second terminal** :
```bash
curl http://localhost:8000/health
curl http://localhost:8000/metrics/latest
```

Modifiez une ligne dans `app/api.py` (ex. un message) → le serveur doit redémarrer
automatiquement (regardez les logs). C'est la preuve du hot-reload.

Arrêter :
```bash
docker compose down
```

## Étape 3 — Test en production locale — 10 min

```bash
docker compose -f docker-compose.yaml up --build -d
docker ps                     # les 2 conteneurs doivent passer "healthy"
docker compose -f docker-compose.yaml logs -f
```

Vérifiez santé + fonctionnement :
```bash
curl http://localhost:8000/health
curl http://localhost:8000/metrics/latest
```

📸 **Faites une capture d'écran de `docker ps` (colonne STATUS = healthy) et des deux
`curl` ci-dessus** — ce sont des livrables demandés dans le README (section 8).

```bash
docker compose -f docker-compose.yaml down
```

## Étape 4 — Lancer les tests localement (avant de pousser) — 5 min

```bash
docker build -t metrics-agent-test -f Dockerfile.dev .
docker run --rm metrics-agent-test pytest tests/ -v
```

Si un test échoue ici, il échouera aussi sur GitHub Actions — corrigez avant de pousser.

## Étape 5 — Compte Docker Hub + token — 5 min

1. Créer un compte sur https://hub.docker.com (si pas déjà fait)
2. Aller dans **Account Settings → Security → New Access Token**
3. Copier le token généré (il ne sera plus affiché après) — nommez-le par ex. `github-ci`

## Étape 6 — Créer le dépôt GitHub et configurer les secrets — 10 min

```bash
# Si vous partez d'un clone existant, changez le remote vers VOTRE dépôt :
git remote set-url origin https://github.com/VOTRE_USERNAME/system-metrics-devops.git
# (ou git remote add origin ... si vous avez initialisé un repo vide)
```

Sur GitHub.com :
1. Créez un nouveau dépôt (vide, sans README) : `system-metrics-devops`
2. Allez dans **Settings → Secrets and variables → Actions → New repository secret**
3. Ajoutez :
   - `DOCKERHUB_USERNAME` = votre pseudo Docker Hub
   - `DOCKERHUB_TOKEN` = le token créé à l'étape 5

## Étape 7 — Premier commit propre et push — 5 min

⚠️ Faites **plusieurs commits progressifs**, pas un seul "projet final" (c'est noté dans
le barème — "Qualité générale / historique de commits").

```bash
git add Dockerfile.dev
git commit -m "feat: ajout du Dockerfile de developpement (hot-reload)"

git add Dockerfile
git commit -m "feat: ajout du Dockerfile de production multi-stage"

git add docker-compose.yaml docker-compose.override.yml .env.example
git commit -m "feat: orchestration Docker Compose (prod + dev)"

git add .github/workflows/ci-cd.yml
git commit -m "ci: pipeline GitHub Actions (build, test, push)"

git add .gitignore .dockerignore README.md
git commit -m "docs: README complet + nettoyage du depot"

git push -u origin main
```

## Étape 8 — Vérifier le pipeline — 5 min

- Onglet **Actions** de votre dépôt GitHub → le workflow doit se déclencher automatiquement
- S'il est rouge, cliquez dessus pour lire les logs et voir l'étape en échec (voir section
  "Erreurs fréquentes" plus bas)
- Une fois vert : allez sur `https://hub.docker.com/r/VOTRE_USERNAME/metrics_agent` et
  vérifiez que l'image existe bien, avec les tags `latest` et un tag SHA

📸 **Capture d'écran du pipeline vert** (section 8 du README).

## Étape 9 — Démonstration du déploiement depuis Docker Hub — 10 min

Dans un dossier **vide**, séparé du code source (pour prouver que ça marche sans le repo) :

```bash
mkdir ../test_deploy && cd ../test_deploy
curl -O https://raw.githubusercontent.com/VOTRE_USERNAME/system-metrics-devops/main/docker-compose.yaml

cat > .env << 'EOF'
METRICS_ENDPOINT=http://api:8000/metrics
COLLECTION_INTERVAL=5
REQUEST_TIMEOUT=3
EOF

export DOCKERHUB_USERNAME=votre_pseudo_dockerhub

docker compose pull
docker compose up -d

curl http://localhost:8000/health
curl http://localhost:8000/metrics/latest
```

## Étape 10 — Finaliser le README et les captures — 10 min

- Remplacez `<VOTRE_USERNAME>` par votre vrai pseudo Docker Hub dans le README
- Insérez les 4 captures d'écran demandées (section 8)
- Vérifiez le `.gitignore` (aucun `.env` réel ne doit être tracké : `git status` doit
  rester silencieux sur ce fichier)

```bash
git add README.md
git commit -m "docs: captures d ecran et liens Docker Hub finaux"
git push
```

## Étape 11 — Rendu

Déposez uniquement le **lien du dépôt GitHub** (et éventuellement le lien Docker Hub)
sur la plateforme indiquée, avant la date limite.

---

## Erreurs fréquentes et comment les corriger

| Symptôme | Cause probable | Solution |
|---|---|---|
| `agent` ne se connecte pas à l'API (`Connection refused`) | `METRICS_ENDPOINT` pointe sur `127.0.0.1` au lieu de `api` | Vérifier `.env` : doit être `http://api:8000/metrics` entre conteneurs |
| `docker compose up` échoue sur `depends_on: condition: service_healthy` | Version de Docker Compose trop ancienne | Mettre à jour Docker Desktop / Compose v2 |
| Le pipeline échoue à l'étape `pytest` | Un test réel échoue, ou dépendance manquante dans `requirements-dev.txt` | Lancer `pytest` en local dans le conteneur dev pour reproduire l'erreur avant de pousser |
| Le pipeline échoue à `docker/login-action` | Secrets `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN` absents ou mal nommés | Vérifier l'orthographe exacte dans *Settings → Secrets and variables → Actions* |
| `docker compose pull` télécharge une image mais `unauthorized` | Dépôt Docker Hub privé, ou mauvais nom d'image | Vérifier que le dépôt `metrics_agent` sur Docker Hub est public, et que `DOCKERHUB_USERNAME` exporté correspond au repo |
| L'image de prod est énorme (>1 Go) | Mauvais usage du multi-stage (COPY de tout `/build` au lieu des wheels seulement) | Vérifier que seul `/build/wheels` est copié depuis le stage `builder` |
| `HEALTHCHECK` reste `unhealthy` indéfiniment | L'API met plus de temps à démarrer que `start_period` | Augmenter `start_period` dans le `HEALTHCHECK` / le `healthcheck:` Compose |
| Fichier `.env` poussé par erreur sur GitHub | `.gitignore` ajouté après le premier `git add .` | `git rm --cached .env` puis commit ; **changer immédiatement** les identifiants exposés |
| `ImportError: No module named 'app'` dans les tests | Tests lancés depuis le mauvais dossier / mauvais `WORKDIR` | Toujours lancer `pytest` depuis la racine du projet (ou dans le conteneur, `WORKDIR /app` doit contenir le dossier `app/`) |

---

## Rappel du barème (/20) — pour prioriser votre temps

| Critère | Points |
|---|---|
| Dockerfile.dev fonctionnel (build + hot-reload) | 3 |
| Dockerfile de production (multi-stage, non-root, healthcheck, image optimisée) | 4 |
| docker-compose.yaml (services, réseau, dépendances, configuration) | 3 |
| Pipeline GitHub Actions (build, test, push conditionnel, secrets) | 5 |
| Publication Docker Hub + déploiement démontré | 2 |
| README.md complet et clair | 2 |
| Qualité générale (structure, .gitignore, historique de commits) | 1 |

⚠️ **Pénalité automatique** si un secret/identifiant est publié en clair (code, historique
Git, ou dans l'image Docker elle-même) — vérifiez avec `git log -p | grep -i "DOCKERHUB"`
avant de rendre.
