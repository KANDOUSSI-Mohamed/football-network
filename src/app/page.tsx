import { AppShell } from "@/components/app-shell";
import { getDashboardData } from "@/lib/data";

export default async function Home() {
  const { players } = await getDashboardData();
  const featuredPlayer = players[0];

  return (
    <AppShell active="overview">
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
    </AppShell>
  );
}
