# maker_friend

A new Flutter project.

## Following / Followers (Firestore + Cloud Functions)

Cette app utilise maintenant ce modèle:

- Le client écrit uniquement `users/{me}/following/{targetUid}`.
- Une Cloud Function synchronise automatiquement:
  - `users/{targetUid}/followers/{me}`
  - `users/{me}.followingCount`
  - `users/{targetUid}.followersCount`

### Déployer

```bash
firebase deploy --only firestore:rules,functions
```

### Structure attendue

- `functions/src/index.ts`: triggers `onFollowingCreated` et `onFollowingDeleted`
- `firestore.rules`: droits sur `users/*/following/*` et lecture seule sur `users/*/followers/*`

## Getting Started

This project is a starting point for a Flutter application.
