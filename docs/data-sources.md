# Référentiel mondial des clubs et des lieux

Football Network sépare les données importées, les données revendiquées par les clubs et les données créées par les membres. Chaque enregistrement importé doit garder une source, un identifiant externe et une date de synchronisation.

## Sources autorisées

| Donnée | Source privilégiée | Licence / règle |
| --- | --- | --- |
| Villes et codes postaux | GeoNames country postal files | CC BY 4.0, attribution obligatoire |
| Noms alternatifs et identifiants | Wikidata dumps / SPARQL contrôlé | CC0 |
| Localisation complémentaire | Extraits OpenStreetMap | ODbL, attribution obligatoire |
| Clubs et affiliations | Fédérations, ligues et clubs officiels | Conditions propres à chaque source |

Le service public Nominatim n'est pas utilisé pour l'autocomplétion ou les imports massifs. Les données OpenStreetMap doivent venir d'extraits téléchargeables et respecter l'ODbL.

## Pipeline

1. Importer les lieux avec `node scripts/import-geonames-postal.mjs FR MA`.
2. Charger les clubs externes dans `club_import_staging`.
3. Normaliser le nom, la ville et les identifiants.
4. Calculer les candidats de fusion dans `club_merge_candidates`.
5. Valider automatiquement les correspondances très fiables et envoyer les cas ambigus en revue.
6. Enregistrer la provenance dans `club_external_ids` et conserver les aliases dans `club_aliases`.

Les archives téléchargées restent dans `.data/` et ne sont jamais envoyées sur GitHub.

## Montée en charge

Le pipeline accepte tous les pays, mais un référentiel de 500 000 à 600 000 clubs, leurs aliases, leurs adresses et leur historique dépassera rapidement les 500 Mo du plan Supabase gratuit. Le chargement mondial complet doit donc être activé après passage à une capacité de production adaptée.
