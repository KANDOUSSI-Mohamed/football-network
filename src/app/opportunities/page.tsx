import { AppShell } from "@/components/app-shell";
import { getOpportunities } from "@/lib/data";

export default async function OpportunitiesPage() {
  const opportunities = await getOpportunities();

  return (
    <AppShell active="opportunities">
      <div className="topbar">
        <input
          className="search"
          placeholder="Rechercher une opportunité, un poste, un pays..."
          aria-label="Recherche opportunités"
        />
        <button className="button">Publier une opportunité</button>
      </div>

      <section className="page-heading">
        <div>
          <div className="eyebrow">Recrutement</div>
          <h1>Opportunités clubs, essais et missions football</h1>
          <p>
            Ce module structure les besoins des clubs, les candidatures et le
            futur pipeline de recrutement.
          </p>
        </div>
      </section>

      <section className="grid">
        {opportunities.map((opportunity) => (
          <article className="card" key={opportunity.id}>
            <div className="card-header">
              <span className="tag">{opportunity.status}</span>
              <span className="tag">{opportunity.deadline}</span>
            </div>
            <div>
              <h3>{opportunity.title}</h3>
              <p className="muted">
                {opportunity.club} - {opportunity.city}, {opportunity.country}
              </p>
            </div>
            <div className="tag-row">
              <span className="tag">{opportunity.level}</span>
              <span className="tag">{opportunity.position}</span>
            </div>
            <button className="button secondary">Voir les candidatures</button>
          </article>
        ))}
      </section>
    </AppShell>
  );
}
