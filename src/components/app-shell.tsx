import { hasSupabaseConfig } from "@/lib/supabase";

type AppShellProps = {
  active: "overview" | "players" | "clubs" | "opportunities" | "messages";
  children: React.ReactNode;
};

const navItems = [
  { key: "overview", href: "/", label: "Vue générale" },
  { key: "players", href: "/players", label: "Joueurs" },
  { key: "clubs", href: "/clubs", label: "Clubs" },
  { key: "opportunities", href: "/opportunities", label: "Recrutement" },
  { key: "messages", href: "/messages", label: "Messages" }
] as const;

export function AppShell({ active, children }: AppShellProps) {
  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <strong>Football Network</strong>
          <span>Plateforme professionnelle du football</span>
        </div>

        <nav className="nav" aria-label="Navigation principale">
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

        <div className="muted">
          Supabase : {hasSupabaseConfig ? "connecté" : "à connecter"}
        </div>
      </aside>

      <main className="main">{children}</main>
    </div>
  );
}
