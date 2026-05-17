# Decisions techniques initiales

## 1. Positionnement technique

La plateforme doit etre concue comme un produit mondial des le depart. Les premiers jeux de donnees seront France et Maroc, mais la structure technique ne doit jamais etre limitee a ces pays.

## 2. Application

Choix recommande : Next.js avec TypeScript.

Raisons :

- rapide pour creer un MVP moderne ;
- compatible web app, SEO et pages publiques ;
- bonne base pour tableaux de bord, profils et recherche ;
- facile a connecter a Supabase.

## 3. Base de donnees

Choix recommande : Supabase PostgreSQL.

Supabase sert de hub technique initial :

- base de donnees ;
- authentification ;
- stockage de fichiers ;
- API ;
- securite par Row Level Security ;
- temps reel possible pour la messagerie.

## 4. Stockage medias

Les photos, videos, CV PDF, licences et documents ne doivent pas etre stockes directement dans les tables. Ils doivent etre stockes dans Supabase Storage, puis references dans la table `media_assets` ou `documents`.

Buckets a prevoir :

- `avatars` ;
- `club-logos` ;
- `player-videos` ;
- `documents` ;
- `covers`.

## 5. Premium

Stripe sera le choix recommande pour gerer :

- abonnements joueurs premium ;
- abonnements clubs ;
- abonnements agents ;
- abonnements recruteurs ;
- factures ;
- paiements internationaux.

Stripe n'est pas necessaire pour le premier prototype local.

## 6. Donnees initiales

Les premieres donnees doivent etre importees progressivement :

- pays ;
- confederations ;
- federations ;
- competitions ;
- clubs ;
- stades ;
- profils publics revendiquables.

La France et le Maroc seront les deux premiers lots operationnels.

## 7. Regle de confiance

Chaque donnee importante doit pouvoir etre classee :

- declaree par l'utilisateur ;
- importee publiquement ;
- verifiee partiellement ;
- revendiquee ;
- officielle.

