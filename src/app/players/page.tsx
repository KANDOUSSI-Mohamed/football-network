import { AppShell } from "@/components/app-shell";
import { getPlayers } from "@/lib/data";

export default async function PlayersPage() {
  const players = await getPlayers();

  return (
    <AppShell active="players">
      <div className="topbar">
        <input
          className="search"
          placeholder="Filtrer par nom, poste, pays, club..."
          aria-label="Recherche joueurs"
        />
        <button className="button">Nouveau profil joueur</button>
      </div>

      <section className="page-heading">
        <div>
          <div className="eyebrow">Base joueurs</div>
          <h1>Recherche et valorisation des profils joueurs</h1>
          <p>
            Le recruteur doit pouvoir identifier rapidement les joueurs par
            poste, disponibilite, pays, statut contractuel et niveau de profil.
          </p>
        </div>
      </section>

      <section className="filter-bar" aria-label="Filtres joueurs">
        <select>
          <option>Poste</option>
          <option>Avant-centre</option>
          <option>Milieu relayeur</option>
          <option>Gardien</option>
        </select>
        <select>
          <option>Pays</option>
          <option>France</option>
          <option>Maroc</option>
        </select>
        <select>
          <option>Disponibilite</option>
          <option>Disponible maintenant</option>
          <option>Disponible fin de saison</option>
        </select>
        <button className="button secondary">Sauvegarder recherche</button>
      </section>

      <section className="grid">
        {players.map((player) => (
          <article className="card" key={player.id}>
            <div className="card-header">
              <div className="avatar">{player.name.charAt(0)}</div>
              <span className="tag">{player.visibility}</span>
            </div>
            <div>
              <h3>{player.name}</h3>
              <p className="muted">
                {player.age} ans - {player.position} - {player.city}
              </p>
            </div>
            <div className="tag-row">
              <span className="tag">{player.country}</span>
              <span className="tag">{player.club}</span>
              <span className="tag">Pied {player.foot}</span>
              <span className="tag">{player.status}</span>
            </div>
            <div className="completion">
              <span>Profil complete a {player.completion}%</span>
              <div>
                <i style={{ width: `${player.completion}%` }} />
              </div>
            </div>
            <div className="stat-line">
              <div className="stat">
                <strong>{player.stats.matches}</strong>
                <span className="muted">matchs</span>
              </div>
              <div className="stat">
                <strong>{player.stats.goals}</strong>
                <span className="muted">buts</span>
              </div>
              <div className="stat">
                <strong>{player.stats.assists}</strong>
                <span className="muted">passes</span>
              </div>
            </div>
          </article>
        ))}
      </section>
    </AppShell>
  );
}
