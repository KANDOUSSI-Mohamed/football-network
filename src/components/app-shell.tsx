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

      <main className="main">
        <div className="app-status">
          <strong>Football Network</strong>
          <span>Supabase : {hasSupabaseConfig ? "connecté" : "à connecter"}</span>
        </div>
        {children}
      </main>
    </div>
  );
}
