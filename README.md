# Football Network

RÃ©seau professionnel mondial destinÃ© Ã  tous les acteurs du football : sportifs, staffs, recruteurs, agents, dirigeants, mÃ©tiers mÃ©dicaux, administratifs, logistiques, marketing et mÃ©dias.

## Vision produit

Football Network permet de crÃ©er une identitÃ© professionnelle, dÃ©velopper son rÃ©seau, publier, dÃ©couvrir des opportunitÃ©s et prendre contact dans un cadre fiable. Un profil peut Ãªtre reliÃ© Ã  une identitÃ© JustRate vÃ©rifiÃ©e afin dâ€™afficher des statistiques sportives autorisÃ©es.

La stratÃ©gie dÃ©taillÃ©e est documentÃ©e dans `docs/PRODUCT_STRATEGY.md`.

## Stack

- application : Next.js et TypeScript ;
- base de donnÃ©es : Supabase PostgreSQL ;
- authentification : Supabase Auth ;
- mÃ©dias : Supabase Storage ;
- temps rÃ©el : Supabase Realtime ;
- paiement : Stripe lors de lâ€™activation commerciale.

## Internationalisation

Le produit prend en charge dÃ¨s sa fondation : franÃ§ais, anglais, espagnol, italien, portugais, allemand, nÃ©erlandais, arabe et turc. Les routes, libellÃ©s, contenus Ã©ditoriaux et rÃ´les professionnels sont localisables.

## Structure utile

- `database/schema.sql` : schÃ©ma initial ;
- `database/migrations/20260721_multilingual_foundation.sql` : langues, contenus traduits et rÃ´les professionnels ;
- `database/migrations/20260721_network_core.sql` : coordonnÃ©es protÃ©gÃ©es, droits Premium et lien JustRate ;
- `database/seed.sql` : premiÃ¨res donnÃ©es France et Maroc ;
- `database/seed-demo.sql` : donnÃ©es de dÃ©monstration ;
- `docs/PRODUCT_STRATEGY.md` : stratÃ©gie et feuille de route ;
- `docs/technical-decisions.md` : dÃ©cisions techniques initiales.

## PrioritÃ© MVP

Le parcours de rÃ©fÃ©rence est : dÃ©couvrir un profil, comprendre son expÃ©rience, demander une relation, Ã©changer par messagerie puis accÃ©der aux coordonnÃ©es uniquement lorsque le membre lâ€™autorise et que les droits requis sont prÃ©sents.
