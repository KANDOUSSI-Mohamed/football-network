# Football Network

Plateforme professionnelle mondiale dediee au football.

## Stack proposee

- Frontend / application : Next.js + TypeScript
- Base de donnees : Supabase PostgreSQL
- Authentification : Supabase Auth
- Stockage medias : Supabase Storage
- Messagerie : tables PostgreSQL + temps reel Supabase plus tard
- Paiement premium : Stripe plus tard

## Pourquoi Supabase pour commencer

Supabase permet de demarrer vite avec :

- une vraie base PostgreSQL ;
- des comptes utilisateurs ;
- des droits d'acces ;
- du stockage pour photos, videos et documents ;
- une API automatique ;
- une evolution possible vers une architecture plus grande.

## Dossiers

- `database/schema.sql` : premier schema de base de donnees.
- `database/seed.sql` : premieres donnees de test France / Maroc.
- `database/seed-demo.sql` : donnees demo pour alimenter les ecrans MVP.
- `docs/technical-decisions.md` : choix techniques initiaux.

## Lancement vise

Le MVP doit d'abord permettre :

- creation d'un profil joueur ;
- consultation de profils joueurs ;
- recherche simple ;
- pages clubs ;
- demandes de relation ;
- messagerie basique ;
- opportunites de recrutement.
