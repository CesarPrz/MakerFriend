# MakerFlow

MakerFlow est une application mobile sociale pour makers, centree sur le partage de projets, les timelines d'avancement et les interactions de communaute.

## Concept

L'objectif est de rendre les projets personnels plus visibles et plus vivants:

- publier des projets avec couverture, tags et description
- poster des updates (posts et etapes) dans une timeline projet
- suivre d'autres makers et voir leurs activites dans un fil dedie
- liker, commenter et recevoir des notifications en temps reel

## Fonctionnalites principales

- Decouverte de projets avec tri (`Nouveau` / `Populaire`) et filtrage par tags
- Feed "Mon fil" combinant updates de projets et activite des profils suivis
- Profils utilisateurs avec compteurs (projets, suivis, followers, likes)
- Like projet + commentaires sur posts
- Notifications pour follows, likes et commentaires
- Creation, edition et suppression de contenu (projets et posts)

## Stack technique

- Frontend: Flutter (Dart)
- State management: BLoC / Cubit
- Backend: Firebase
- Base de donnees: Cloud Firestore
- Auth: Firebase Auth
- Fonctions serveur: Cloud Functions for Firebase (TypeScript)
- Notifications push: Firebase Cloud Messaging
- Storage: Firebase Storage

## Architecture (haut niveau)

- `lib/screens`: UI pages (discover, feed, profile, timeline, etc.)
- `lib/repositories`: acces aux donnees Firestore/Firebase
- `lib/features/*/cubit`: logique d'etat par feature
- `lib/widgets`: composants UI reutilisables
- `functions/src`: logique backend declenchee par evenements Firestore
- `firestore.rules`: regles de securite de la base

## Etat du projet

Le projet est en developpement actif avec une base fonctionnelle complete (social + timeline + notifications), et une structure orientee evolution.

## Seeder dev (screenshots)

Un script de seed Firestore est disponible pour peupler des donnees maker realistes (users, projets, timeline, commentaires, likes, follows, notifications).

Depuis `functions/`:

```bash
npm run seed:dev -- --viewerUid <TON_UID_FIREBASE_AUTH>
```

Si tu n'as pas ADC configure, passe directement une cle service account:

```bash
npm run seed:dev -- --viewerUid <TON_UID_FIREBASE_AUTH> --serviceAccount "C:\\Users\\Cesar\\.secrets\\makerfriend-dev-seed.json"
```

Version reset (supprime puis recree les docs seedes):

```bash
npm run seed:dev:reset -- --viewerUid <TON_UID_FIREBASE_AUTH>
```

Notes:
- par defaut, le script cible le projet `dev` de `.firebaserc`
- il bloque `stage/prod` sauf si `--allow-non-dev` est fourni explicitement
- il faut des credentials ADC valides (`GOOGLE_APPLICATION_CREDENTIALS` ou `gcloud auth application-default login`)

## Licence

MIT - voir `LICENSE`.
