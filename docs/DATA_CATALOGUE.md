# Football Network data catalogue

Football Network stores only traceable organization and geographic records. Imported clubs remain public, unclaimed records until an authorized representative completes the verification flow.

## Current sources

- GeoNames postal exports: cities, postal codes and administrative areas under CC BY 4.0.
- Wikidata: football club identities, aliases, locations, founding dates, coordinates and official websites under CC0 1.0.
- National federations: future verified enrichment, handled source by source according to each federation's publication terms.

Every external club identity is stored in `club_external_ids`. Every run is recorded in `data_import_jobs`, while ambiguous matches are placed in `club_merge_candidates` for review.

## Commands

```powershell
$env:SUPABASE_ACCESS_TOKEN="..."
npm run db:migrate -- database/migrations/20260722_wikidata_club_catalogue.sql
npm run data:clubs -- FR MA
npm run data:clubs:expansion
npm run data:verify
node scripts/verify-club-catalogue.mjs
```

Use `--dry-run`, `--limit N` and `--page-size N` to test extraction without writing to Supabase. The importer is idempotent: a second run matches the external IDs and enriches empty fields instead of creating duplicates.

The expansion command covers Spain, Germany, Italy, the United Kingdom, Portugal, the Netherlands, Belgium, Senegal, Algeria, Tunisia, Cote d'Ivoire and Cameroon. United Kingdom extraction includes England, Scotland, Wales and Northern Ireland entities, while all resulting records retain the ISO country code `GB` in Football Network.

## Scale strategy

The 500,000 to 600,000 organization objective cannot be reached responsibly from one public endpoint. Expansion combines licensed open sources, federation publications and member-claimed records, with source priority, deduplication and manual review for uncertain matches. No placeholder club is generated to inflate the catalogue.
