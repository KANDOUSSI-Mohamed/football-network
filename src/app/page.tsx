import { clubs, players } from "@/lib/demo-data";
import { hasSupabaseConfig } from "@/lib/supabase";

export default function Home() {
  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <strong>Football Network</strong>
          <span>Professional football platform</span>
        </div>

        <nav className="nav" aria-label="Navigation principale">
          <a className="active" href="/">
            Vue generale
          </a>
          <a href="/players">Joueurs</a>
          <a href="/clubs">Clubs</a>
          <a href="/opportunities">Recrutement</a>
          <a href="/messages">Messages</a>
        </nav>

        <div className="muted">
          Supabase : {hasSupabaseConfig ? "connecte" : "a connecter"}
        </div>
      </aside>

      <main className="main">
        <div className="topbar">
          <input
            className="search"
            placeholder="Rechercher joueur, club, agent, recruteur..."
            aria-label="Recherche"
          />
          <button className="button">Creer un profil</button>
        </div>

        <section className="hero">
          <div className="hero-panel">
            <div>
              <div className="eyebrow">Reseau professionnel mondial du football</div>
              <h1>Connecter joueurs, clubs, agents, recruteurs et staffs.</h1>
              <p>
                Une base mondiale structuree pour rendre les profils visibles,
                faciliter le recrutement, verifier les acteurs et creer des
                opportunites dans tout l'ecosysteme football.
              </p>
            </div>

            <div className="metrics">
              <div className="metric">
                <strong>{players.length}</strong>
                <span>profils joueurs demo</span>
              </div>
              <div className="metric">
                <strong>{clubs.length}</strong>
                <span>clubs initiaux</span>
              </div>
              <div className="metric">
                <strong>2</strong>
                <span>pays pilotes data</span>
              </div>
            </div>
          </div>

          <div className="panel">
            <h2>Priorites MVP</h2>
            <div className="tag-row">
              <span className="tag">Profil joueur</span>
              <span className="tag">Recherche</span>
              <span className="tag">Pages clubs</span>
              <span className="tag">Opportunites</span>
              <span className="tag">Messagerie</span>
              <span className="tag">Premium</span>
              <span className="tag">Verification</span>
            </div>
          </div>
        </section>

        <div className="sections">
          <section className="section">
            <h2>Joueurs a mettre en avant</h2>
            <div className="grid">
              {players.map((player) => (
                <article className="card" key={player.id}>
                  <div className="card-header">
                    <div>
                      <div className="avatar">{player.name.charAt(0)}</div>
                    </div>
                    <span className="tag">{player.status}</span>
                  </div>
                  <div>
                    <h3>{player.name}</h3>
                    <p className="muted">
                      {player.age} ans - {player.position} - {player.club}
                    </p>
                  </div>
                  <div className="tag-row">
                    <span className="tag">{player.country}</span>
                    <span className="tag">{player.city}</span>
                    <span className="tag">Pied {player.foot}</span>
                    <span className="tag">{player.height}</span>
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
            </div>
          </section>

          <section className="section">
            <h2>Clubs et besoins</h2>
            <div className="grid">
              {clubs.map((club) => (
                <article className="card" key={club.id}>
                  <div>
                    <h3>{club.name}</h3>
                    <p className="muted">
                      {club.city}, {club.country} - {club.division}
                    </p>
                  </div>
                  <span className="tag">{club.status}</span>
                  <div className="tag-row">
                    {club.needs.map((need) => (
                      <span className="tag" key={need}>
                        {need}
                      </span>
                    ))}
                  </div>
                </article>
              ))}
            </div>
          </section>
        </div>
      </main>
    </div>
  );
}
