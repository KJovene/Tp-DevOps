# DevOps Demo App

Application fil rouge de la formation.

## Endpoints

- `/` : réponse JSON simple
- `/health` : healthcheck HTTP pour Docker/Kubernetes
- `/metrics` : métriques Prometheus en texte brut

## Commandes

```bash
npm test
npm start
docker build -t devops-app:1.0.0 .
```
