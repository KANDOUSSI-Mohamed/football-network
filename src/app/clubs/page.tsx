import { AppShell } from "@/components/app-shell";
import { getClubs } from "@/lib/data";

export default async function ClubsPage() {
  const clubs = await getClubs();

  return (
    <AppShell active="clubs">
      <div className="topbar">
        <input
          className="search"
          placeholder="Rechercher un club, une ville, une division..."
          aria-label="Recherche clubs"
        />
        <button className="button">Revendiquer une fiche</button>
      </div>

      <section className="page-heading">
        <div>
          <div className="eyebrow">Annuaire clubs</div>
          <h1>Pages clubs, academies et structures revendiquables</h1>
          <p>
            Les clubs existent dans la base avant même la création d'un compte.
            Ils peuvent ensuite revendiquer leur fiche et publier leurs besoins.
          </p>
        </div>
      </section>

      <section className="table-panel">
        <div className="table-row table-head">
          <span>Club</span>
          <span>Pays</span>
          <span>Division</span>
          <span>Besoins</span>
          <span>Statut</span>
        </div>
        {clubs.map((club) => (
          <div className="table-row" key={club.id}>
            <strong>{club.name}</strong>
            <span>{club.country}</span>
            <span>{club.division}</span>
            <span>{club.needs.join(", ")}</span>
            <span className="tag">{club.status}</span>
          </div>
        ))}
      </section>
    </AppShell>
  );
}
