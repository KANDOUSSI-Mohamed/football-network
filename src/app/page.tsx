import { AppShell } from "@/components/app-shell";
import { getDashboardData } from "@/lib/data";

export default async function Home() {
  const { clubs, players, opportunities } = await getDashboardData();
  const featuredPlayer = players[0];

  return (
    <AppShell active="overview">
      <div className="social-layout jr-layout">
        <aside className="left-rail">
          <section className="jr-panel profile-widget">
            <div className="profile-cover" />
            <div className="profile-body">
              <div className="profile-photo">FN</div>
              <h2>Football Network</h2>
              <p>Réseau professionnel mondial du football</p>
              <div className="profile-stats">
                <span>
                  <strong>{players.length}</strong>
                  profils joueurs
                </span>
                <span>
                  <strong>{clubs.length}</strong>
                  clubs suivis
                </span>
              </div>
            </div>
          </section>

          <section className="jr-panel match-list-widget">
            <div className="widget-tabs">
              <button className="active">Favoris</button>
              <button>Compétitions</button>
            </div>
            <h3>Opportunités suivies</h3>
            <div className="mini-match active">
              <span>LIVE</span>
              <strong>CODM Meknès</strong>
              <em>Recherche attaquant U23</em>
            </div>
            <div className="mini-match">
              <span>15:00</span>
              <strong>FC Nantes</strong>
              <em>Essai gardien senior</em>
            </div>
            <div className="mini-match">
              <span>20:00</span>
              <strong>Académie internationale</strong>
              <em>Analyste vidéo</em>
            </div>
          </section>

          <section className="jr-panel side-widget compact">
            <h3>Accès rapide</h3>
            <a href="/players">Créer un profil joueur</a>
            <a href="/clubs">Revendiquer un club</a>
            <a href="/opportunities">Publier un besoin</a>
          </section>
        </aside>

        <section className="center-feed">
          <article className="jr-score-card">
            <div className="score-meta">
              <span>FOOTBALL NETWORK</span>
              <strong>Profil joueur connecté</strong>
              <span>JustRate sync</span>
            </div>
            <div className="score-board">
              <div className="team-side">
                <div className="club-badge">JR</div>
                <strong>{featuredPlayer?.name ?? "Joueur à suivre"}</strong>
                <span>{featuredPlayer?.position ?? "Profil joueur"}</span>
              </div>
              <div className="main-score">
                <span>JRI</span>
                <strong>8.3</strong>
                <em>{featuredPlayer?.status ?? "Disponible"}</em>
              </div>
              <div className="team-side">
                <div className="club-badge alt">FN</div>
                <strong>{featuredPlayer?.club ?? "Club à renseigner"}</strong>
                <span>{featuredPlayer?.city ?? "Marché mondial"}</span>
              </div>
            </div>
            <div className="score-details">
              <span>{featuredPlayer?.stats.matches ?? 0} matchs</span>
              <span>{featuredPlayer?.stats.goals ?? 0} buts</span>
              <span>{featuredPlayer?.stats.assists ?? 0} passes</span>
              <span>Profil vérifié à {featuredPlayer?.completion ?? 0}%</span>
            </div>
          </article>

          <article className="composer-card jr-panel">
            <div className="composer-line">
              <div className="avatar">FN</div>
              <button>Partager une actualité football</button>
            </div>
            <div className="composer-actions">
              <button>Vidéo</button>
              <button>Photo</button>
              <button>Stats</button>
              <button>Recrutement</button>
            </div>
          </article>

          <article className="feed-card jr-panel">
            <div className="post-author">
              <div className="avatar">{featuredPlayer?.name.charAt(0) ?? "J"}</div>
              <div>
                <strong>{featuredPlayer?.name ?? "Joueur à suivre"}</strong>
                <span>
                  {featuredPlayer?.position ?? "Profil joueur"} -{" "}
                  {featuredPlayer?.status ?? "Disponible"}
                </span>
              </div>
            </div>
            <p>
              Nouvelle vidéo ajoutée : appels en profondeur, vitesse d'exécution,
              finition et séquences de match. Profil visible par les clubs,
              recruteurs et agents vérifiés.
            </p>
            <div className="football-media">
              <div>
                <span>Highlight vidéo</span>
                <strong>Actions clés + stats JustRate</strong>
              </div>
            </div>
            <div className="post-actions">
              <button>Recommander</button>
              <button>Commenter</button>
              <button>Partager</button>
              <button>Short-list</button>
            </div>
          </article>

          <article className="feed-card jr-panel">
            <div className="post-author">
              <div className="avatar">C</div>
              <div>
                <strong>CODM Meknès</strong>
                <span>Club - Besoin de recrutement</span>
              </div>
            </div>
            <p>
              Recherche attaquant U23 disponible rapidement. Priorité aux profils
              avec vidéo, statistiques et références vérifiables.
            </p>
            <div className="job-strip">
              <span>Avant-centre</span>
              <span>Botola Pro</span>
              <span>Disponible maintenant</span>
            </div>
          </article>
        </section>

        <aside className="right-rail">
          <section className="jr-panel ranking-widget">
            <div className="talent-card">
              <div className="avatar">J</div>
              <div>
                <strong>Pépite de la semaine</strong>
                <span>{featuredPlayer?.name ?? "Profil joueur"}</span>
              </div>
              <b>8.3</b>
            </div>
            <h3>Top profils joueurs</h3>
            {players.slice(0, 3).map((player, index) => (
              <div className="rank-row" key={player.id}>
                <span>{index + 1}</span>
                <div>
                  <strong>{player.name}</strong>
                  <em>{player.position}</em>
                </div>
                <b>{(8.5 - index * 0.18).toFixed(1)}</b>
              </div>
            ))}
          </section>

          <section className="jr-panel side-widget">
            <h3>Opportunités récentes</h3>
            {opportunities.slice(0, 3).map((opportunity) => (
              <a href="/opportunities" key={opportunity.id}>
                <strong>{opportunity.title}</strong>
                <span>
                  {opportunity.city}, {opportunity.country}
                </span>
              </a>
            ))}
          </section>

          <section className="jr-panel justrate-sync">
            <h3>Connexion JustRate</h3>
            <p>
              Lier un profil joueur Football Network à son profil JustRate pour
              afficher les notes, matchs, statistiques et tendances en temps réel.
            </p>
            <button>Lier un profil JustRate</button>
          </section>
        </aside>
      </div>
    </AppShell>
  );
}
