# Démarche et commandes — TP DevOps : System Metrics Agent

**Groupe 12** — NDONG EYEGHE Georges Frédéric, PEMBE MOUPOMA Vinciane Franelle,
OUSMANE MOANDA Ali El Hadj Mahamat

**Dépôt GitHub** : https://github.com/moondaali20-a11y/metrics_agent_devops
**Images Docker Hub** : https://hub.docker.com/r/ousali/metrics_agent

---

## 1. Présentation du projet

Ce TP met en pratique les fondamentaux du DevOps sur une application Python
fournie, `system_metrics_agent` (FastAPI + psutil), composée de deux
processus distincts :

- **API** (`app.api`) : expose `/health`, `/metrics` (GET/POST) et
  `/metrics/latest`, lancée avec `uvicorn`.
- **Agent** (`app.agent`) : collecte les métriques système (CPU, mémoire,
  charge) toutes les `COLLECTION_INTERVAL` secondes et les envoie en HTTP
  vers `METRICS_ENDPOINT`.

Le code source de l'application (`app/`, `tests/`, `requirements.txt`,
`.env.example`) provient du dépôt fourni par le cours et n'a pas été modifié
dans sa logique métier. Le travail du groupe a porté exclusivement sur
l'infrastructure DevOps autour de cette application.

---

## 2. Architecture mise en place

- **Dockerfile.dev** : image de développement, basée sur `python:3.12-slim`,
  avec toutes les dépendances (y compris `pytest`/`httpx`), hot-reload
  d'uvicorn (`--reload`) et montage du code en volume, utilisateur non-root.
- **Dockerfile** : image de production, build **multi-stage** (un stage
  `builder` qui compile les dépendances en wheels, un stage `final` minimal
  qui les installe sans accès réseau), utilisateur non-root dédié (UID
  10001), `HEALTHCHECK` sur `/health` en Python pur (sans `curl`), image
  finale d'environ **67 MB**.
- **docker-compose.yaml** : orchestre les services `api` et `agent` sur un
  réseau Docker dédié (`metrics-network`), avec `env_file` pour la
  configuration et `depends_on: condition: service_healthy` pour que l'agent
  ne démarre qu'une fois l'API opérationnelle.
- **docker-compose.override.yml** : bascule automatiquement en mode
  développement (build sur `Dockerfile.dev`, volumes montés) quand on lance
  `docker compose up` sans option.
- **Stratégie image unique** : plutôt que deux images séparées, une seule
  image de production est construite ; le service `agent` surcharge
  simplement la commande par défaut avec `command: ["python", "-m", "app.agent"]`.
- **Pipeline CI/CD** (`.github/workflows/ci-cd.yml`) : à chaque push/pull
  request sur `main`, le pipeline fait le checkout, build l'image de test
  (`Dockerfile.dev`), exécute `pytest` dans un conteneur (le pipeline échoue
  si un test échoue), puis build et pousse l'image de production sur Docker
  Hub avec deux tags (`latest` et le SHA du commit), uniquement si les tests
  sont passés. Les identifiants Docker Hub sont stockés comme secrets GitHub
  (`DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`), jamais en clair dans le code.

---

## 3. Démarche suivie, étape par étape

1. **Récupération du projet fourni** et mise en place de la structure du
   dépôt (`app/`, `tests/`, `.env.example`, `.gitignore`).
2. **Écriture et test local du `Dockerfile.dev`** : build, run, vérification
   du rechargement à chaud en modifiant un fichier source.
3. **Écriture et test local du `Dockerfile` de production** : build
   multi-stage, vérification du `HEALTHCHECK` et de l'utilisateur non-root.
4. **Écriture de `docker-compose.yaml`** et vérification que les services
   `api` et `agent` communiquent bien entre eux via le réseau interne.
5. **Création du compte Docker Hub** et d'un access token dédié
   (*Account Settings → Security → New Access Token*).
6. **Ajout des secrets GitHub** (`DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`)
   dans *Settings → Secrets and variables → Actions* du dépôt.
7. **Écriture du workflow CI/CD** et vérification de son exécution dans
   l'onglet Actions après chaque push.
8. **Vérification de la publication sur Docker Hub**, puis démonstration
   complète d'un déploiement à partir des images publiées uniquement
   (`docker compose pull` + `docker compose up`, sans code source local),
   testée dans un dossier vide séparé du projet.
9. **Rédaction du README.md** avec toutes les sections demandées et les
   captures d'écran de preuve de fonctionnement.
10. **Nettoyage final du dépôt** et vérification qu'aucun secret n'est
    exposé dans l'historique Git.

---

## 4. Difficultés rencontrées et solutions apportées

| Problème rencontré | Cause | Solution |
|---|---|---|
| L'agent plantait en boucle avec `uptime: No such file or directory` | La commande système `uptime`, utilisée par `collector.py` pour la charge système, n'est pas installée par défaut dans l'image `python:3.12-slim` | Installation explicite du paquet `procps` dans les deux Dockerfiles (dev et production) |
| Le build de production échouait en CI avec `Could not find a version that satisfies the requirement starlette` | L'option `--no-deps` utilisée lors du `pip wheel` du stage `builder` empêchait la récupération des dépendances transitives de `fastapi` (comme `starlette`, `pydantic`) | Retrait de `--no-deps` pour que toutes les dépendances nécessaires soient bien compilées en wheels |
| `requirements.txt` contenait `pytest` mélangé aux dépendances de production | Le fichier fourni avec le projet n'était pas séparé en prod/dev | Le `Dockerfile` de production filtre automatiquement la ligne `pytest` (`grep -v`) avant de builder les wheels, sans modifier le fichier source |
| Erreur `port is already allocated` lors des tests de déploiement | Un conteneur d'un test précédent tournait encore sur le port 8000 | `docker compose down` systématique avant de relancer un nouveau test |
| `git push` rejeté (`fetch first`) lors du travail à plusieurs sur le même dépôt | Un membre du groupe avait poussé un commit entre-temps | `git pull` (puis résolution du message de merge) avant de repousser |
| Pipeline en échec avec `Username required` | Les secrets Docker Hub n'étaient pas encore configurés dans les paramètres du dépôt GitHub | Ajout des secrets `DOCKERHUB_USERNAME` et `DOCKERHUB_TOKEN` dans *Settings → Secrets and variables → Actions* |

---

## 5. Vérifications de sécurité effectuées avant le rendu

- `git log --all --full-history -- .env` → vide, confirmant qu'aucun fichier
  `.env` réel n'a jamais été commité.
- Recherche dans l'historique complet (`git log -p --all`) de toute valeur de
  token en clair → aucune trouvée, seules des références au nom des secrets
  GitHub apparaissent dans le workflow et la documentation.
- Vérification de la structure du dépôt (`git ls-files`) conforme aux
  livrables attendus, sans fichier superflu.
- Test de déploiement depuis un **clone entièrement neuf** du dépôt
  (simulant la correction), confirmant que le projet fonctionne de bout en
  bout sans configuration manuelle préalable autre que `cp .env.example .env`.

---

## 6. Ce que nous retenons de ce TP

Ce travail nous a permis de comprendre concrètement :
- L'intérêt de séparer les environnements de développement (hot-reload,
  dépendances de test) et de production (image minimale, sécurisée,
  non-root).
- L'importance de la gestion des secrets dans un pipeline CI/CD, et pourquoi
  ils ne doivent jamais apparaître en clair dans le code ou son historique.
- La différence entre un build local (`docker compose up --build`) et un
  déploiement réel à partir d'images publiées sur un registre (`docker
  compose pull` + `up`), qui est la situation réelle d'un déploiement en
  production.
- L'importance d'une communication réseau correcte entre conteneurs
  (utilisation du nom de service Compose plutôt que `127.0.0.1`).
- La gestion d'un dépôt Git en travail de groupe (synchronisation,
  résolution de merges, coordination des pushs).
