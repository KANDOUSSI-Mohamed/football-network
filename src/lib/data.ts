import {
  clubs as demoClubs,
  conversations,
  opportunities as demoOpportunities,
  players as demoPlayers,
  type Club,
  type Opportunity,
  type Player
} from "@/lib/demo-data";
import { supabase } from "@/lib/supabase";

export async function getPlayers(): Promise<Player[]> {
  if (!supabase) {
    return demoPlayers;
  }

  const { data, error } = await supabase
    .from("player_profiles")
    .select(
      "id, primary_position, preferred_foot, height_cm, availability_status, profile_completion_score, profiles(display_name, city), clubs(official_name), player_statistics(appearances, goals, assists)"
    )
    .limit(12);

  if (error || !data?.length) {
    return demoPlayers;
  }

  return data.map((player: any) => {
    const stats = player.player_statistics?.[0];

    return {
      id: player.id,
      name: player.profiles?.display_name ?? "Joueur",
      age: 0,
      position: player.primary_position ?? "Poste a renseigner",
      foot: player.preferred_foot ?? "Non renseigne",
      height: player.height_cm ? `${player.height_cm / 100} m` : "Non renseigne",
      country: "A renseigner",
      city: player.profiles?.city ?? "A renseigner",
      club: player.clubs?.official_name ?? "Libre / non renseigne",
      status: formatAvailability(player.availability_status),
      stats: {
        matches: stats?.appearances ?? 0,
        goals: stats?.goals ?? 0,
        assists: stats?.assists ?? 0
      },
      completion: player.profile_completion_score ?? 0,
      visibility: "Profil Supabase"
    };
  });
}

export async function getClubs(): Promise<Club[]> {
  if (!supabase) {
    return demoClubs;
  }

  const { data, error } = await supabase
    .from("clubs")
    .select("id, official_name, city, club_status, claim_status, countries(name)")
    .order("official_name")
    .limit(24);

  if (error || !data?.length) {
    return demoClubs;
  }

  return data.map((club: any) => ({
    id: club.id,
    name: club.official_name,
    country: club.countries?.name ?? "A renseigner",
    city: club.city ?? "A renseigner",
    division: formatClubStatus(club.club_status),
    status:
      club.claim_status === "claimed"
        ? "Fiche revendiquee"
        : "Fiche publique non revendiquee",
    needs: ["Recrutement", "Scouting", "Profil club"]
  }));
}

export async function getOpportunities(): Promise<Opportunity[]> {
  if (!supabase) {
    return demoOpportunities;
  }

  const { data, error } = await supabase
    .from("opportunities")
    .select("id, title, city, level, position, status, deadline, countries(name)")
    .order("created_at", { ascending: false })
    .limit(12);

  if (error || !data?.length) {
    return demoOpportunities;
  }

  return data.map((opportunity: any) => ({
    id: opportunity.id,
    title: opportunity.title,
    club: "Organisation",
    country: opportunity.countries?.name ?? "A renseigner",
    city: opportunity.city ?? "A renseigner",
    level: opportunity.level ?? "A renseigner",
    position: opportunity.position ?? "A renseigner",
    status: opportunity.status ?? "open",
    deadline: opportunity.deadline ?? "Ouvert"
  }));
}

export async function getDashboardData() {
  const [players, clubs, opportunities] = await Promise.all([
    getPlayers(),
    getClubs(),
    getOpportunities()
  ]);

  return {
    players,
    clubs,
    opportunities,
    conversations
  };
}

function formatAvailability(status?: string) {
  const labels: Record<string, string> = {
    available_now: "Disponible maintenant",
    available_end_of_season: "Disponible fin de saison",
    open_to_opportunities: "Ouvert aux opportunites",
    not_available: "Non disponible",
    unknown: "Disponibilite a renseigner"
  };

  return labels[status ?? "unknown"] ?? status ?? "Disponibilite a renseigner";
}

function formatClubStatus(status?: string) {
  const labels: Record<string, string> = {
    professional: "Professionnel",
    semi_professional: "Semi-professionnel",
    amateur: "Amateur",
    academy: "Academie",
    school: "Ecole",
    association: "Association",
    unknown: "Statut a renseigner"
  };

  return labels[status ?? "unknown"] ?? status ?? "Statut a renseigner";
}
