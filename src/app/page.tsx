import { AppShell } from "@/components/app-shell";
import { getDashboardData } from "@/lib/data";

export default async function Home() {
  const { clubs, players, opportunities } = await getDashboardData();
  const featuredPlayer = players[0];

  return (
    <AppShell active="overview">
      <div className="social-layout">
        <aside className="left-rail">
          <section className="profile-widget">
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

          <section className="side-widget">
            <h3>Mon réseau</h3>
            <a href="/players">Joueurs recommandés</a>
            <a href="/clubs">Clubs à revendiquer</a>
            <a href="/messages">Messages reçus</a>
            <a href="/opportunities">Opportunités sauvegardées</a>
          </section>

          <section className="side-widget compact">
            <h3>Accès rapide</h3>
            <a href="/players">Créer un profil joueur</a>
            <a href="/clubs">Ajouter un club</a>
            <a href="/opportunities">Publier un besoin</a>
          </section>
        </aside>

        <section className="center-feed">
          <article className="composer-card">
            <div className="composer-line">
              <div className="avatar">FN</div>
              <button>Commencer une publication</button>
            </div>
            <div className="composer-actions">
              <button>Vidéo</button>
              <button>Photo</button>
              <button>Annonce recrutement</button>
              <button>Article</button>
            </div>
          </article>

          <article className="feed-card">
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
                <strong>3 actions clés</strong>
              </div>
            </div>
            <div className="post-actions">
              <button>Recommander</button>
              <button>Commenter</button>
              <button>Partager</button>
              <button>Short-list</button>
            </div>
          </article>

          <article className="feed-card">
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
          <section className="side-widget news-widget">
            <h3>Actualités football</h3>
            <a href="/">Profils vérifiés : priorité aux données fiables</a>
            <a href="/">Les clubs peuvent revendiquer leur page</a>
            <a href="/">Les vidéos deviennent centrales dans le recrutement</a>
            <a href="/">Agents et recruteurs : accès premium à venir</a>
          </section>

          <section className="side-widget">
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

          <section className="side-widget">
            <h3>Notifications</h3>
            <span>2 demandes de relation en attente</span>
            <span>1 club a consulté un profil</span>
            <span>3 recherches sauvegardées à compléter</span>
          </section>
        </aside>
      </div>
    </AppShell>
  );
}
