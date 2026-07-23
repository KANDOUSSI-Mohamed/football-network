# Cahier des charges - Football Network

**Version :** 1.0  
**Date de référence :** 23 juillet 2026  
**Statut :** document directeur produit, design, données et technique  
**Positionnement :** réseau professionnel mondial de tous les acteurs du football

## 1. Résumé exécutif

Football Network doit devenir l'infrastructure mondiale de mise en relation professionnelle du football. La plateforme permet à une personne ou une organisation d'être trouvée, de prouver son identité et son expérience, de développer son réseau, de publier, de recruter, de candidater et de communiquer dans un environnement fiable.

Le produit ne vise pas uniquement les joueurs. Il couvre l'ensemble de l'écosystème : clubs, académies, joueurs, entraîneurs, adjoints, préparateurs physiques, analystes, recruteurs, agents, dirigeants, personnel médical, administratif, logistique, marketing, média, juridique, financier et prestataires spécialisés.

Football Network et JustRate restent deux produits et deux bases distincts. Après contrôle d'identité, un membre Football Network peut relier son profil à son identité JustRate et afficher les données sportives autorisées par une API sécurisée.

## 2. Ambition et objectifs

### 2.1 Ambition

Créer le premier graphe professionnel mondial exclusivement dédié au football, capable de relier une identité, une carrière, une organisation, une opportunité, une conversation et des preuves sportives vérifiées.

### 2.2 Objectifs prioritaires

1. Référencer les personnes, organisations et opportunités du football mondial.
2. Permettre une recherche professionnelle précise, rapide et multilingue.
3. Réduire les intermédiaires inutiles sans contourner le consentement ni la réglementation.
4. Donner de la visibilité à tous les métiers, niveaux, genres et territoires.
5. Rendre la prise de contact directe, traçable et sécurisée.
6. Construire un marché du recrutement avec publication, candidature, pipeline et alertes.
7. Relier les profils éligibles à JustRate sans fusionner les deux bases.
8. Atteindre progressivement 500 000 à 600 000 organisations traçables, sans données fictives.

### 2.3 Principes non négociables

- Le positionnement est mondial dès le premier écran.
- La France et le Maroc sont des zones d'amorçage, pas des limites commerciales.
- Tous les métiers du football utilisent une identité professionnelle commune et des modules spécialisés.
- Les coordonnées personnelles sont privées par défaut.
- Un abonnement peut ouvrir un droit de demande, jamais supprimer le consentement du membre.
- Chaque donnée importée doit conserver sa source, sa licence et son niveau de confiance.
- Les profils de mineurs bénéficient de protections renforcées.
- JustRate reste indépendant et accessible uniquement par API contrôlée.
- L'ergonomie peut reprendre les bons principes d'un réseau professionnel, sans copier son code, sa marque ou ses contenus.

## 3. État de référence au 23 juillet 2026

### 3.1 Fondations disponibles

- dépôt GitHub officiel et historique versionné ;
- application Next.js et TypeScript ;
- Supabase PostgreSQL, Auth, Storage et Realtime comme socle Football Network ;
- site public Football Network déployé ;
- layout réseau à trois colonnes avec centre défilant ;
- fondation multilingue pour neuf langues ;
- schémas de profils, réseau, messagerie, fil social, recrutement et données mondiales ;
- annuaire public de 13 036 clubs traçables dans 14 pays ;
- 52 914 localités et codes postaux déjà chargés pour la France et le Maroc ;
- imports GeoNames et Wikidata avec provenance, déduplication et file de contrôle ;
- liens de source visibles et routes sensibles protégées.

### 3.2 Éléments encore à rendre complets côté utilisateur

- inscription et onboarding final de bout en bout ;
- édition complète de tous les types de profils ;
- dépôt et traitement opérationnel des demandes de vérification ;
- publication réelle de photos, vidéos et documents ;
- demandes de relation, messagerie et notifications entièrement utilisables ;
- moteur de recrutement complet avec candidatures et pipeline ;
- abonnements, facturation et droits Premium ;
- connexion réelle à l'API JustRate ;
- console de modération, support et administration ;
- couverture géographique et catalogue mondial à grande échelle.

## 4. Utilisateurs et rôles professionnels

Un compte peut gérer plusieurs rôles, plusieurs expériences et, selon ses droits, plusieurs organisations.

### 4.1 Sportifs

- joueur ou joueuse professionnel(le), semi-professionnel(le), amateur(e) ou en formation ;
- gardien ou gardienne ;
- joueur de futsal, beach soccer ou discipline associée ;
- ancien joueur ou ancienne joueuse ;
- arbitre et officiel de match.

### 4.2 Encadrement sportif

- entraîneur principal ;
- entraîneur adjoint ;
- entraîneur des gardiens ;
- préparateur physique ;
- responsable de la performance ;
- directeur technique ;
- directeur sportif ;
- responsable d'académie ;
- formateur et éducateur ;
- analyste tactique ou vidéo ;
- data analyst, data scientist et spécialiste du recrutement.

### 4.3 Recrutement et représentation

- recruteur ou scout indépendant ;
- cellule de recrutement d'un club ;
- agent de football ;
- agence de représentation ;
- intermédiaire autorisé selon la juridiction ;
- conseiller de carrière ;
- responsable des prêts et partenariats.

### 4.4 Santé et performance

- médecin ;
- kinésithérapeute ;
- ostéopathe ;
- infirmier ;
- nutritionniste ;
- psychologue ;
- podologue ;
- réathlétiseur ;
- responsable médical ;
- spécialiste du sommeil et de la récupération.

### 4.5 Direction et administration

- président, propriétaire ou actionnaire ;
- directeur général ;
- secrétaire général ;
- directeur administratif et financier ;
- juriste et responsable conformité ;
- responsable RH ;
- team manager ;
- responsable licences et compétitions ;
- responsable sûreté, sécurité et intégrité.

### 4.6 Opérations et services

- logistique et déplacements ;
- stadium manager et entretien des installations ;
- billetterie et hospitalité ;
- équipementier et kit manager ;
- responsable matériel ;
- interprète et accompagnateur ;
- transport, hébergement et restauration.

### 4.7 Marketing, média et commercial

- marketing et communication ;
- community manager ;
- attaché de presse ;
- photographe et vidéaste ;
- journaliste et créateur de contenu ;
- sponsoring et partenariats ;
- commercial et business development ;
- merchandising et e-commerce ;
- responsable RSE et relations institutionnelles.

### 4.8 Organisations

- club professionnel, semi-professionnel ou amateur ;
- académie, centre de formation et école de football ;
- agence de joueurs ;
- fédération, ligue, district et association ;
- syndicat, organisme de formation et université ;
- prestataire, média, marque, équipementier et organisateur d'événements.

## 5. Expérience globale et design

### 5.1 Structure permanente

Toutes les pages authentifiées conservent le même cadre :

- barre supérieure fixe avec logo, recherche, navigation, messagerie, notifications, langue et compte ;
- colonne gauche fixe avec identité, raccourcis, favoris et contexte de la page ;
- colonne centrale défilante contenant l'expérience principale ;
- colonne droite fixe avec recommandations, alertes, opportunités, tendances et widgets JustRate ;
- adaptation tablette et mobile : la colonne centrale reste prioritaire, les colonnes latérales deviennent des panneaux accessibles sans recouvrir le contenu.

### 5.2 Ligne visuelle

- univers sombre professionnel cohérent avec JustRate, sans palette monotone ;
- vert lime réservé aux états positifs, appels prioritaires et données JustRate ;
- typographie moderne, fine, très lisible, sans titres surdimensionnés ;
- densité adaptée à un outil professionnel consulté quotidiennement ;
- cartes peu arrondies, bordures discrètes et hiérarchie claire ;
- icônes standards et info-bulles pour les commandes ;
- aucun texte d'aide décoratif qui remplace une vraie fonctionnalité.

### 5.3 Pages principales

| Page | Contenu central attendu |
| --- | --- |
| Accueil | compositeur de publication, fil, suggestions et actualités réseau |
| Mon réseau | invitations, relations, recommandations et abonnements |
| Profils | recherche et annuaire de tous les métiers |
| Joueurs | recherche sportive, disponibilité et preuves de performance |
| Clubs | annuaire mondial, équipes, besoins et demandes de revendication |
| Recrutement | opportunités, candidatures, alertes et pipeline |
| Messagerie | conversations, pièces jointes, demandes et sécurité |
| Notifications | relations, messages, candidatures, mentions et alertes |
| Mon profil | identité, expériences, compétences, médias et visibilité |
| Organisation | page club/agence, membres, publications, besoins et statistiques |
| JustRate | liaison, statut de vérification et données sportives autorisées |
| Premium | offre, droits, paiement, factures et gestion de l'abonnement |
| Administration | vérifications, signalements, imports, droits et audit |

## 6. Spécifications fonctionnelles

### 6.1 Compte, authentification et onboarding

**FN-ACC-001** - Inscription par email avec validation et récupération de mot de passe.  
**FN-ACC-002** - Connexion sociale à étudier après le MVP, sans rendre un fournisseur obligatoire.  
**FN-ACC-003** - Choix initial d'un ou plusieurs rôles professionnels.  
**FN-ACC-004** - Choix de la langue, du pays, du fuseau horaire et des préférences de confidentialité.  
**FN-ACC-005** - Assistant de création de profil avec progression et reprise ultérieure.  
**FN-ACC-006** - Acceptation versionnée des conditions et politiques nécessaires.  
**FN-ACC-007** - Parcours spécifique mineur, représentant légal et organisation encadrante.  
**FN-ACC-008** - Double authentification requise pour administrateurs et proposée aux membres.

### 6.2 Profil professionnel universel

Chaque profil comprend :

- nom d'usage, nom complet privé, photo, couverture et URL publique ;
- titre professionnel, rôles, disponibilité et zone de mobilité ;
- date et lieu de naissance avec visibilité contrôlée ;
- nationalités, langues et autorisations de travail déclarées ;
- biographie, compétences, diplômes, licences et certifications ;
- expériences chronologiques avec organisation, rôle, dates et réalisations ;
- formation, distinctions, références et recommandations ;
- photos, vidéos, documents, liens et portfolio ;
- coordonnées protégées avec permissions séparées pour email et téléphone ;
- niveau de complétude, statut de vérification et origine des données ;
- paramètres de visibilité par champ : public, réseau, recruteurs autorisés ou privé.

### 6.3 Module joueur

**FN-PLY-001** - Poste principal, postes secondaires et rôle tactique.  
**FN-PLY-002** - Pied préféré, taille, poids optionnel et données athlétiques consenties.  
**FN-PLY-003** - Club actuel, équipe, championnat, numéro et statut contractuel.  
**FN-PLY-004** - Historique de carrière par saison et par club.  
**FN-PLY-005** - Matchs, titularisations, minutes, buts, passes, cartons et statistiques propres au poste.  
**FN-PLY-006** - Statistiques de gardien : arrêts, buts encaissés, clean sheets et penalties.  
**FN-PLY-007** - Sélections nationales et catégories d'âge.  
**FN-PLY-008** - Disponibilité : libre, sous contrat, prêt, essai recherché ou non communiqué.  
**FN-PLY-009** - Galerie de séquences vidéo avec contexte, date, match et droits de diffusion.  
**FN-PLY-010** - Données JustRate clairement distinguées des données déclarées ou importées.  
**FN-PLY-011** - CV sportif exportable en PDF dans la langue choisie.  
**FN-PLY-012** - Toute donnée médicale reste hors du profil public et suit un régime d'accès spécifique.

### 6.4 Modules entraîneur, staff et métiers spécialisés

- spécialité, niveau, catégories entraînées et philosophie de travail ;
- licences et organismes émetteurs avec dates d'expiration ;
- historique des équipes et responsabilités ;
- systèmes de jeu, compétences et langues ;
- portfolio de séances, analyses ou projets lorsque pertinent ;
- résultats et statistiques présentés avec leur contexte ;
- disponibilité, mobilité et type de mission recherché ;
- champs spécialisés configurables par famille de métier.

### 6.5 Agents, recruteurs et agences

**FN-AGT-001** - Numéro de licence, organisme, pays, statut et expiration.  
**FN-AGT-002** - Vérification possible avec les registres FIFA et fédérations lorsque juridiquement applicable.  
**FN-AGT-003** - Portefeuille visible uniquement avec le consentement des représentés.  
**FN-AGT-004** - Territoires, catégories, langues et spécialités.  
**FN-AGT-005** - Mandats et documents sensibles non publics, chiffrés et journalisés.  
**FN-REC-001** - Listes de suivi privées et partagées.  
**FN-REC-002** - Notes internes invisibles des candidats.  
**FN-REC-003** - Recherche sauvegardée et alertes ciblées.  
**FN-REC-004** - Historique des consultations sensibles et des actions d'équipe.

### 6.6 Organisations et clubs

Chaque organisation possède une fiche publique non revendiquée ou revendiquée comprenant :

- nom officiel, noms alternatifs, logo, pays, ville et adresse ;
- type d'organisation, année de création et identifiants externes ;
- fédération, ligue, compétitions et niveaux ;
- équipes : première, réserve, féminine, jeunes, futsal et autres sections ;
- stade, centre d'entraînement, académie et installations ;
- site officiel, réseaux, contacts publics et langues ;
- membres du personnel reliés à des profils vérifiés ;
- publications, opportunités et besoins de recrutement ;
- sources, niveau de confiance et date de dernière mise à jour.

La revendication d'une organisation exige une preuve, un contrôle opérateur et un journal d'audit. Aucun demandeur ne reçoit automatiquement la propriété d'un club.

### 6.7 Recherche mondiale

**FN-SRC-001** - Une recherche globale couvre personnes, clubs, agences, opportunités et publications.  
**FN-SRC-002** - Tolérance aux accents, variantes orthographiques, alias et translittérations.  
**FN-SRC-003** - Filtres : rôle, pays, ville, rayon, langue, disponibilité, expérience et vérification.  
**FN-SRC-004** - Filtres joueurs : âge, poste, pied, niveau, championnat, statistiques et contrat.  
**FN-SRC-005** - Filtres staff : spécialité, licence, niveau, catégorie et mobilité.  
**FN-SRC-006** - Filtres opportunités : métier, contrat, niveau, pays, date et statut.  
**FN-SRC-007** - Recherches enregistrées, alertes et favoris selon l'abonnement.  
**FN-SRC-008** - Les résultats doivent expliquer les principaux critères de correspondance sans exposer d'informations privées.

### 6.8 Réseau et fil social

- publier du texte, une photo, une vidéo, un document, une statistique ou une opportunité ;
- associer une publication à un profil, un club, un match ou une compétition ;
- mentionner des profils et utiliser des sujets contrôlés ;
- réagir, commenter, partager et enregistrer ;
- suivre une personne ou une organisation sans imposer une relation réciproque ;
- demander une relation avec message optionnel et limite anti-spam ;
- choisir qui peut commenter, partager ou contacter ;
- signaler, masquer, bloquer et retirer un contenu ;
- distinguer clairement contenu organique, recommandé et sponsorisé ;
- classer le fil par pertinence et fraîcheur avec contrôle utilisateur.

### 6.9 Messagerie et notifications

**FN-MSG-001** - Conversations individuelles et, pour les offres adaptées, conversations d'équipe.  
**FN-MSG-002** - Demandes de message séparées pour les non-relations.  
**FN-MSG-003** - Texte, photos, vidéos courtes et documents avec analyse de sécurité.  
**FN-MSG-004** - Accusés d'envoi et de lecture configurables.  
**FN-MSG-005** - Blocage, signalement, limitation de fréquence et détection d'abus.  
**FN-MSG-006** - Les coordonnées directes ne sont révélées qu'après autorisation explicite.  
**FN-NOT-001** - Notifications pour relations, messages, réactions, mentions, candidatures, alertes et vérifications.  
**FN-NOT-002** - Préférences séparées pour application, email et futures notifications mobiles.  
**FN-NOT-003** - Regroupement et limitation pour éviter la surcharge.

### 6.10 Place de marché du recrutement

#### Publication d'une opportunité

- organisation et auteur vérifiés selon le niveau de sensibilité ;
- métier recherché, intitulé, description et responsabilités ;
- équipe, niveau, compétition et localisation ;
- type de contrat ou mission, dates et durée ;
- compétences, licences, langues et expérience ;
- fourchette de rémunération lorsque légalement et commercialement applicable ;
- visibilité publique, réseau limité ou invitation privée ;
- date d'expiration, nombre de postes et contact responsable.

#### Candidature

- candidature avec profil courant ou version ciblée ;
- message, pièces jointes et questions de présélection ;
- consentement explicite pour les données transmises ;
- retrait possible tant que le processus le permet ;
- statuts : brouillon, envoyée, consultée, présélectionnée, entretien, essai, offre, retenue ou refusée ;
- historique visible du candidat et journal interne côté recruteur.

#### Pipeline recruteur

- colonnes configurables ;
- affectation à un collaborateur ;
- notes, tags, rappels et évaluations ;
- comparaison de profils ;
- modèles de messages ;
- exports encadrés et traçables ;
- statistiques de délai, conversion et origine des candidatures ;
- interdiction d'utiliser des critères discriminatoires ou des données non nécessaires.

### 6.11 Connexion JustRate

**FN-JR-001** - Le membre saisit son URL ou identifiant JustRate.  
**FN-JR-002** - La demande est créée en statut `pending`.  
**FN-JR-003** - Le contrôle compare identité, date de naissance, club, historique et preuves disponibles.  
**FN-JR-004** - La liaison passe à `verified`, `rejected`, `revoked` ou `needs_review`.  
**FN-JR-005** - Football Network appelle une API JustRate authentifiée et versionnée, jamais sa base directement.  
**FN-JR-006** - Les réponses autorisées peuvent être mises en cache pour une courte durée avec date de fraîcheur.  
**FN-JR-007** - Les notes, matchs et statistiques affichent la mention JustRate et leur dernière synchronisation.  
**FN-JR-008** - Le membre peut demander la déconnexion ; les journaux techniques suivent la politique de conservation.  
**FN-JR-009** - Une correspondance incertaine n'est jamais validée automatiquement.  
**FN-JR-010** - Une indisponibilité de JustRate ne doit pas empêcher l'accès au profil Football Network.

### 6.12 Médias et documents

- avatars et logos avec recadrage ;
- photos, couvertures, vidéos et miniatures ;
- CV, licences, diplômes, contrats et justificatifs ;
- métadonnées : propriétaire, visibilité, droits, langue, date et source ;
- analyse antivirus, validation du type réel et limites de taille ;
- suppression logique, quarantaine et politique de rétention ;
- URLs signées pour tout document non public ;
- traitement des demandes de retrait et des droits d'auteur.

### 6.13 Abonnements et droits

| Offre | Cible | Droits principaux |
| --- | --- | --- |
| Network | tous | profil, réseau, publications, recherche standard et messagerie de base |
| Premium Individual | joueurs et professionnels | visibilité, recherche avancée, alertes, statistiques et demandes de contact prioritaires |
| Recruiter / Agent | recruteurs et agences | listes, notes, recherches sauvegardées, alertes, pipeline et collaboration limitée |
| Club / Organization | clubs et structures | page revendiquée, équipes, collaborateurs, opportunités, pipeline partagé et gouvernance |
| Enterprise | grands groupes | SSO futur, rôles avancés, audit, intégrations et accompagnement |

Règles commerciales :

- aucun abonnement ne permet de contourner un blocage ou un refus ;
- aucun achat de liste d'emails ou de téléphones ;
- droits calculés côté serveur ;
- essai, coupon, facture, taxes, remboursement et résiliation gérés de façon traçable ;
- prix localisés et testés après validation des usages ;
- Stripe est prévu pour la facturation commerciale ;
- Odoo peut devenir un outil interne de CRM, support ou comptabilité, mais ne remplace pas l'application Football Network.

### 6.14 Administration, vérification et modération

- tableau de bord des profils, organisations, contenus, imports et abonnements ;
- files de vérification avec preuves, double contrôle et motif de décision ;
- revue des licences d'agents et certifications professionnelles ;
- résolution des doublons et fusions réversibles ;
- signalements par type, urgence et risque ;
- sanctions progressives : avertissement, restriction, suspension et fermeture ;
- appels et historique des décisions ;
- gestion des rôles opérateur selon le moindre privilège ;
- journal d'audit non modifiable depuis l'interface ;
- outils de support sans affichage inutile des données privées ;
- mesures anti-spam, anti-harcèlement, anti-usurpation et anti-fraude.

## 7. Données mondiales et objectif 600 000 organisations

### 7.1 Sources autorisées

1. Données ouvertes avec licence compatible et attribution respectée.
2. Sites et publications de fédérations après vérification des conditions d'utilisation.
3. Données officielles fournies par les clubs, ligues ou partenaires.
4. Données déclarées par les membres et soumises à contrôle.
5. Wikidata pour les identités et relations sous CC0.
6. GeoNames pour les localités et codes postaux sous CC BY.

Le scraping non autorisé, l'achat de données opaques et la génération de faux clubs sont interdits.

### 7.2 Pipeline de données

`Source -> zone de staging -> normalisation -> déduplication -> contrôle -> publication -> mise à jour -> archivage`

Chaque enregistrement conserve : source, identifiant externe, URL, licence, date d'import, empreinte, niveau de confiance, dernière vérification et historique des rapprochements.

### 7.3 Niveaux de confiance

- `declared` : déclaré par un membre ;
- `public_import` : importé depuis une source publique ;
- `partially_verified` : plusieurs éléments concordent ;
- `claimed` : revendiqué par un représentant contrôlé ;
- `official` : fourni ou confirmé par une autorité reconnue.

### 7.4 Stratégie de montée en charge

1. Consolider les 14 pays déjà ouverts et enrichir villes, codes postaux et compétitions.
2. Étendre l'Europe, l'Afrique, les Amériques, l'Asie et l'Océanie par vagues mesurées.
3. Ajouter les fédérations et ligues disposant de sources juridiquement exploitables.
4. Ouvrir la revendication de club et l'enrichissement communautaire contrôlé.
5. Mesurer couverture, fraîcheur, doublons et qualité, pas seulement le volume brut.

## 8. Internationalisation

### 8.1 Langues de fondation

- français ;
- anglais ;
- espagnol ;
- italien ;
- portugais ;
- allemand ;
- néerlandais ;
- arabe avec interface droite-gauche ;
- turc.

### 8.2 Langues d'extension

Après validation de la chaîne de traduction : polonais, roumain, grec, russe, chinois simplifié, japonais, coréen, indonésien, hindi et swahili.

### 8.3 Exigences

- aucune chaîne d'interface importante codée en dur ;
- URLs localisées et langue mémorisée ;
- formats locaux pour date, heure, nombre, devise et téléphone ;
- noms propres conservés avec alias et translittérations ;
- contenus utilisateurs non traduits automatiquement sans signalement clair ;
- tests visuels pour textes longs et interface arabe ;
- modération possible dans les langues proposées.

## 9. Vie privée, mineurs et conformité

### 9.1 Principes

- minimisation des données ;
- finalité claire et base légale documentée ;
- consentement distinct lorsqu'il est nécessaire ;
- accès, rectification, portabilité et suppression ;
- durées de conservation définies par catégorie ;
- registre des traitements et journal des consentements ;
- analyse d'impact avant les traitements présentant un risque élevé ;
- contrats et transferts internationaux examinés avant ouverture commerciale ;
- revue juridique par pays, notamment pour agents, mineurs, recrutement et données sportives.

### 9.2 Coordonnées et données sensibles

- email, téléphone, adresse exacte et documents sont privés par défaut ;
- date de naissance complète masquée publiquement si non indispensable ;
- les données de santé ne doivent jamais devenir un filtre public de recrutement ;
- toute consultation ou transmission sensible doit être autorisée et journalisée ;
- les exports sont limités, marqués et contrôlés.

### 9.3 Mineurs

- âge et règles de consentement configurables selon le pays ;
- en France, parcours de consentement conjoint requis lorsque le traitement repose sur le consentement d'un mineur de moins de 15 ans ;
- politique produit renforcée possible jusqu'à 18 ans indépendamment du seuil légal ;
- coordonnées, localisation précise et messagerie directe limitées par défaut ;
- représentant légal ou organisation encadrante vérifiée lorsque requis ;
- signalement prioritaire et modération spécialisée ;
- aucune publicité comportementale basée sur les données d'un mineur.

## 10. Architecture technique cible

### 10.1 Football Network

- interface : Next.js et TypeScript ;
- base : Supabase PostgreSQL ;
- identité : Supabase Auth ;
- fichiers : Supabase Storage ;
- temps réel : Supabase Realtime ;
- facturation : Stripe lors de l'activation commerciale ;
- hébergement public actuel : OpenAI Sites ;
- dépôt de référence : GitHub `KANDOUSSI-Mohamed/football-network`.

### 10.2 JustRate

- application et base indépendantes hébergées dans son environnement Render ;
- API versionnée, authentifiée, limitée et observable ;
- identifiant externe JustRate conservé dans Football Network ;
- aucune clé privilégiée exposée au navigateur ;
- aucune réplication complète de la base JustRate.

### 10.3 Sécurité

- politiques Row Level Security sur les données membres ;
- comptes de service réservés aux opérations serveur ;
- secrets uniquement dans les environnements sécurisés ;
- rotation des clés et révocation documentées ;
- validation côté serveur de chaque droit Premium ou organisation ;
- chiffrement en transit et au repos fourni par les services choisis ;
- journalisation des actions sensibles ;
- sauvegardes et restauration testées ;
- analyse de dépendances et correctifs réguliers ;
- tests d'autorisation contre l'accès horizontal et vertical.

## 11. Exigences non fonctionnelles

### 11.1 Performance

- LCP inférieur à 2,5 secondes au 75e percentile mobile sur les parcours prioritaires ;
- INP inférieur à 200 ms et CLS inférieur à 0,1 ;
- recherche standard sous une seconde au 95e percentile, hors dépendance externe ;
- pagination ou chargement progressif obligatoire pour les grands annuaires ;
- images et vidéos responsives, compressées et chargées selon le besoin.

### 11.2 Disponibilité et résilience

- objectif MVP : 99,5 % mensuel ;
- objectif commercial : 99,9 % sur les parcours critiques ;
- dégradation contrôlée si JustRate, paiement ou recommandation est indisponible ;
- reprise sur erreur et idempotence des imports et paiements ;
- supervision, alertes et pages de santé.

### 11.3 Accessibilité

- cible WCAG 2.2 niveau AA ;
- navigation clavier complète ;
- focus visible et non masqué ;
- contrastes vérifiés ;
- libellés accessibles et alternatives aux médias ;
- sous-titres ou transcription pour les vidéos importantes ;
- tests bureau, mobile, zoom et lecteurs d'écran.

### 11.4 Compatibilité

- versions récentes de Chrome, Edge, Firefox et Safari ;
- responsive de 320 px aux grands écrans ;
- fonctionnement tactile sans dépendance au survol ;
- application installable et applications natives étudiées après validation du web.

### 11.5 Capacité cible

L'architecture doit pouvoir évoluer vers :

- 600 000 organisations ;
- plusieurs millions de profils ;
- plusieurs langues et alphabets ;
- des dizaines de millions de relations, messages et contenus ;
- index de recherche séparé lorsque PostgreSQL seul ne suffit plus.

## 12. Mesure et pilotage

### 12.1 Indicateurs produit

- inscriptions validées ;
- profils complétés à 60 %, 80 % et 100 % ;
- profils et organisations vérifiés ;
- recherches produisant une consultation puis une action ;
- demandes de relation envoyées, acceptées et signalées ;
- conversations professionnelles démarrées ;
- opportunités publiées et candidatures qualifiées ;
- temps moyen jusqu'au premier retour recruteur ;
- liens JustRate demandés, vérifiés, refusés et révoqués ;
- rétention à 7, 30 et 90 jours ;
- conversion et résiliation Premium ;
- délai de traitement des signalements.

### 12.2 Qualité des données

- couverture par pays, niveau et type de club ;
- pourcentage avec ville, site, logo, compétition et contacts ;
- fraîcheur médiane ;
- doublons confirmés ;
- imports rejetés ou en revue ;
- revendications acceptées et contestées ;
- corrections réalisées par une source officielle.

## 13. Feuille de route d'exécution

### Lot 0 - Fondations techniques

**Statut : largement engagé.** Architecture, données, layout, multilingue, premiers schémas fonctionnels et annuaire initial.

### Lot 1 - Identité et confiance

- onboarding complet ;
- édition du profil universel et modules métier ;
- paramètres de visibilité ;
- revendication de club ;
- vérification et console opérateur ;
- parcours mineurs.

### Lot 2 - Réseau actif

- demandes de relation ;
- fil social réel ;
- médias ;
- commentaires et réactions ;
- messagerie et notifications ;
- signalement et blocage.

### Lot 3 - Recrutement

- publication d'opportunités ;
- candidatures ;
- alertes ;
- listes et pipeline ;
- collaboration club/agence ;
- mesure des conversions.

### Lot 4 - JustRate

- contrat d'API ;
- demande de liaison ;
- contrôle opérateur ;
- widgets de statistiques ;
- fraîcheur, erreurs et révocation.

### Lot 5 - Commercial

- droits par offre ;
- Stripe ;
- factures et taxes ;
- essais et coupons ;
- CRM et support ;
- offres club, agence et entreprise.

### Lot 6 - Expansion mondiale

- localités et codes postaux des nouveaux pays ;
- compétitions, équipes et stades ;
- nouvelles vagues de clubs ;
- partenariats fédérations et ligues ;
- enrichissement et revendication à grande échelle.

## 14. Critères de sortie du MVP

Le MVP est considéré exploitable lorsque :

1. Un nouveau membre valide son email et termine son profil sans intervention technique.
2. Il peut choisir plusieurs rôles et contrôler la visibilité de ses coordonnées.
3. La recherche retrouve personnes, clubs et opportunités avec filtres essentiels.
4. Une demande de relation peut être envoyée, acceptée, refusée ou bloquée.
5. Deux membres autorisés peuvent échanger dans une messagerie sécurisée.
6. Un club vérifié peut publier une opportunité et traiter une candidature.
7. Un candidat peut suivre le statut de sa candidature.
8. Photos et documents respectent les droits d'accès définis.
9. Les signalements arrivent dans une console de modération exploitable.
10. Les neuf langues de fondation couvrent tous les parcours critiques.
11. Les tests d'autorisation empêchent l'accès aux données privées d'un autre membre.
12. Les sauvegardes, journaux, alertes et procédures de reprise sont validés.
13. Le produit respecte la cible WCAG 2.2 AA sur les parcours prioritaires.
14. Les conditions, politiques et parcours mineurs ont été validés juridiquement avant ouverture publique large.

## 15. Ordre de priorité immédiat

1. Onboarding et profil universel réellement éditable.
2. Revendication et vérification des clubs et professionnels.
3. Demandes de relation, messagerie et notifications de bout en bout.
4. Place de marché de recrutement complète.
5. Liaison JustRate vérifiée.
6. Abonnements et commercialisation.
7. Expansion mondiale continue des référentiels.

## 16. Références externes de conformité et de données

- Règlement général sur la protection des données : https://eur-lex.europa.eu/eli/reg/2016/679/oj
- CNIL, consentement et mineurs : https://www.cnil.fr/fr/recommandation-4-rechercher-le-consentement-dun-parent-pour-les-mineurs-de-moins-de-15-ans
- FIFA, réglementation et registre des agents : https://legal.fifa.com/transfer-system/agents
- W3C, WCAG 2.2 : https://www.w3.org/TR/WCAG22/
- Wikidata, licence des données structurées : https://www.wikidata.org/wiki/Wikidata:Licensing
- GeoNames, données, licence et attribution : https://www.geonames.org/export/

Ces références cadrent le produit mais ne remplacent pas une validation juridique par pays avant commercialisation.
