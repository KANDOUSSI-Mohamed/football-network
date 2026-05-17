import { AppShell } from "@/components/app-shell";
import { conversations } from "@/lib/demo-data";

export default function MessagesPage() {
  return (
    <AppShell active="messages">
      <div className="topbar">
        <input
          className="search"
          placeholder="Rechercher une conversation..."
          aria-label="Recherche messages"
        />
        <button className="button">Nouveau message</button>
      </div>

      <section className="page-heading">
        <div>
          <div className="eyebrow">Messagerie interne</div>
          <h1>Contacts professionnels et demandes contrôlées</h1>
          <p>
            La messagerie doit protéger les joueurs contre le spam tout en
            donnant aux clubs, agents et recruteurs des échanges sérieux.
          </p>
        </div>
      </section>

      <section className="message-layout">
        <div className="message-list">
          {conversations.map((conversation) => (
            <article className="message-item" key={conversation.id}>
              <div className="card-header">
                <strong>{conversation.contact}</strong>
                <span className="tag">{conversation.status}</span>
              </div>
              <span className="muted">{conversation.role}</span>
              <h3>{conversation.subject}</h3>
              <p>{conversation.lastMessage}</p>
            </article>
          ))}
        </div>
        <div className="panel">
          <h2>Règles de contact</h2>
          <div className="check-list">
            <span>Coordonnées masquées par défaut</span>
            <span>Demandes directes limitées</span>
            <span>Signalement et blocage disponibles</span>
            <span>Priorité aux comptes vérifiés</span>
          </div>
        </div>
      </section>
    </AppShell>
  );
}
