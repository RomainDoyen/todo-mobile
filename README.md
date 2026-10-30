# Mes Tâches

Application Flutter (Android et iOS) du même compte que l’extension `todo-extension`. Les données restent dans SQLite sur l’appareil et se synchronisent avec le Worker Cloudflare déjà en place.

## Lancer

Flutter est installé dans `~/flutter` (pas forcément dans le `PATH`).

```bash
export PATH="$HOME/flutter/bin:$PATH"
cd todo-mobile
flutter pub get
flutter run
```

Le serveur par défaut est `https://mes-taches-api.todo-extension.workers.dev`. On peut le changer sur l’écran de connexion, ou au build :

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8787
```

`10.0.2.2` est la machine hôte vue depuis l’émulateur Android. Le simulateur iOS utilise `http://127.0.0.1:8787`.

## Compte

- E-mail / mot de passe : mêmes routes que l’extension (`/auth/login`, `/auth/register`).
- Google : l’app ouvre `/auth/google?client=mobile`, puis récupère `mestaches://auth?code=…`. Ce retour n’existe qu’après déploiement du Worker (`todo-extension/api`).

## Périmètre

Profils, tâches, priorités, échéances, tags, catégories, sous-tâches, thème clair/sombre, sync offline (file d’attente puis pull). L’export JSON de l’extension n’est pas repris ici.
