# Football Network

Réseau professionnel mondial destiné à tous les acteurs du football : sportifs, staffs, recruteurs, agents, dirigeants, métiers médicaux, administratifs, logistiques, marketing et médias.

## Vision produit

Football Network permet de créer une identité professionnelle, développer son réseau, publier, découvrir des opportunités et prendre contact dans un cadre fiable. Un profil peut être relié à une identité JustRate vérifiée afin d’afficher, via l’API de l’application JustRate hébergée sur Render, des statistiques sportives autorisées. Les deux plateformes et leurs bases restent indépendantes.

La stratégie détaillée est documentée dans `docs/PRODUCT_STRATEGY.md`.

## Stack

- application : Next.js et TypeScript ;
- base de données : Supabase PostgreSQL ;
- authentification : Supabase Auth ;
- médias : Supabase Storage ;
- temps réel : Supabase Realtime ;
- paiement : Stripe lors de l’activation commerciale.

## Internationalisation

Le produit prend en charge dès sa fondation : français, anglais, espagnol, italien, portugais, allemand, néerlandais, arabe et turc. Les routes, libellés, contenus éditoriaux et rôles professionnels sont localisables.

## Structure utile

- `database/schema.sql` : schéma initial ;
- `database/migrations/20260721_multilingual_foundation.sql` : langues, contenus traduits et rôles professionnels ;
- `database/migrations/20260721_network_core.sql` : coordonnées protégées, droits Premium et lien JustRate ;
- `database/migrations/20260721_member_onboarding.sql` : inscription, propriété des profils et relations sécurisées ;
- `database/seed.sql` : premières données France et Maroc ;
- `database/seed-demo.sql` : données de démonstration ;
- `docs/PRODUCT_STRATEGY.md` : stratégie et feuille de route ;
- `docs/technical-decisions.md` : décisions techniques initiales.

## Priorité MVP

Le parcours de référence est : découvrir un profil, comprendre son expérience, demander une relation, échanger par messagerie puis accéder aux coordonnées uniquement lorsque le membre l’autorise et que les droits requis sont présents.
