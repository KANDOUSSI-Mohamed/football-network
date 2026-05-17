import { hasSupabaseConfig } from "@/lib/supabase";

type AppShellProps = {
  active: "overview" | "players" | "clubs" | "opportunities" | "messages";
  children: React.ReactNode;
};

const navItems = [
  { key: "overview", href: "/", label: "Accueil" },
  { key: "players", href: "/players", label: "Joueurs" },
  { key: "clubs", href: "/clubs", label: "Clubs" },
  { key: "opportunities", href: "/opportunities", label: "Recrutement" },
  { key: "messages", href: "/messages", label: "Messagerie" }
] as const;

export function AppShell({ active, children }: AppShellProps) {
  return (
    <div className="shell">
      <header className="network-topbar">
        <a className="brand-mark" href="/" aria-label="Football Network">
          FN
        </a>

        <div className="global-search">
          <input
            placeholder="Rechercher un joueur, un club, un agent..."
            aria-label="Recherche globale"
          />
        </div>

        <nav className="top-nav" aria-label="Navigation principale">
          {navItems.map((item) => (
            <a
              className={item.key === active ? "active" : undefined}
              href={item.href}
              key={item.key}
            >
              {item.label}
            </a>
          ))}
        </nav>

        <div className="top-actions" aria-label="Actions rapides">
          <button title="Notifications">Notifications</button>
          <button title="Profil">Vous</button>
        </div>
      </header>

      <div className="layout-frame">
        <aside className="left-rail fixed-rail">
          <section className="jr-panel profile-widget">
            <div className="profile-cover" />
            <div className="profile-body">
              <div className="profile-photo">FN</div>
              <h2>Football Network</h2>
              <p>Réseau professionnel mondial du football</p>
              <div className="profile-stats">
                <span>
                  <strong>3</strong>
                  profils joueurs
                </span>
                <span>
                  <strong>3</strong>
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

        <main className="center-scroll">
          <div className="app-status">
            <strong>Football Network</strong>
            <span>Supabase : {hasSupabaseConfig ? "connecté" : "à connecter"}</span>
          </div>
          {children}
        </main>

        <aside className="right-rail fixed-rail">
          <section className="jr-panel ranking-widget">
            <div className="talent-card">
              <div className="avatar">J</div>
              <div>
                <strong>Pépite de la semaine</strong>
                <span>Profil connecté JustRate</span>
              </div>
              <b>8.3</b>
            </div>
            <h3>Top profils joueurs</h3>
            <div className="rank-row">
              <span>1</span>
              <div>
                <strong>Yanis Benali</strong>
                <em>Avant-centre</em>
              </div>
              <b>8.5</b>
            </div>
            <div className="rank-row">
              <span>2</span>
              <div>
                <strong>Adam El Mansouri</strong>
                <em>Milieu relayeur</em>
              </div>
              <b>8.3</b>
            </div>
            <div className="rank-row">
              <span>3</span>
              <div>
                <strong>Noah Morel</strong>
                <em>Gardien</em>
              </div>
              <b>8.1</b>
            </div>
          </section>

          <section className="jr-panel side-widget">
            <h3>Opportunités récentes</h3>
            <a href="/opportunities">
              <strong>Recherche attaquant U23</strong>
              <span>Meknès, Maroc</span>
            </a>
            <a href="/opportunities">
              <strong>Essai gardien senior</strong>
              <span>Nantes, France</span>
            </a>
            <a href="/opportunities">
              <strong>Analyste vidéo</strong>
              <span>Paris, France</span>
            </a>
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
    </div>
  );
}
