export type Player = {
  id: string;
  name: string;
  age: number;
  position: string;
  foot: string;
  height: string;
  country: string;
  city: string;
  club: string;
  status: string;
  stats: {
    matches: number;
    goals: number;
    assists: number;
  };
  completion: number;
  visibility: string;
};

export type Club = {
  id: string;
  name: string;
  country: string;
  city: string;
  division: string;
  status: string;
  needs: string[];
};

export type Opportunity = {
  id: string;
  title: string;
  club: string;
  country: string;
  city: string;
  level: string;
  position: string;
  status: string;
  deadline: string;
};

export type Conversation = {
  id: string;
  contact: string;
  role: string;
  subject: string;
  lastMessage: string;
  status: string;
};

export const players: Player[] = [
  {
    id: "p1",
    name: "Yanis Benali",
    age: 21,
    position: "Avant-centre",
    foot: "Droit",
    height: "1.84 m",
    country: "France",
    city: "Lyon",
    club: "Libre",
    status: "Disponible maintenant",
    stats: {
      matches: 24,
      goals: 14,
      assists: 5
    },
    completion: 78,
    visibility: "Profil public"
  },
  {
    id: "p2",
    name: "Adam El Mansouri",
    age: 19,
    position: "Milieu relayeur",
    foot: "Droit",
    height: "1.78 m",
    country: "Maroc",
    city: "Casablanca",
    club: "Académie privée",
    status: "Ouvert aux opportunités",
    stats: {
      matches: 29,
      goals: 6,
      assists: 11
    },
    completion: 84,
    visibility: "Visible recruteurs"
  },
  {
    id: "p3",
    name: "Noah Morel",
    age: 23,
    position: "Gardien",
    foot: "Gauche",
    height: "1.91 m",
    country: "France",
    city: "Nantes",
    club: "National 3",
    status: "Disponible fin de saison",
    stats: {
      matches: 21,
      goals: 0,
      assists: 1
    },
    completion: 71,
    visibility: "Relations et clubs"
  }
];

export const clubs: Club[] = [
  {
    id: "c1",
    name: "Olympique Lyonnais",
    country: "France",
    city: "Lyon",
    division: "Ligue 1",
    status: "Fiche publique non revendiquée",
    needs: ["U19", "Scouting", "Milieu défensif"]
  },
  {
    id: "c2",
    name: "CODM Meknès",
    country: "Maroc",
    city: "Meknès",
    division: "Botola Pro",
    status: "Fiche publique non revendiquée",
    needs: ["Attaquant", "Analyse vidéo", "U23"]
  },
  {
    id: "c3",
    name: "FC Nantes",
    country: "France",
    city: "Nantes",
    division: "Ligue 1",
    status: "Fiche publique non revendiquée",
    needs: ["Académie", "Recrutement jeunes", "Gardien"]
  }
];

export const opportunities: Opportunity[] = [
  {
    id: "o1",
    title: "Recherche attaquant U23 disponible",
    club: "CODM Meknès",
    country: "Maroc",
    city: "Meknès",
    level: "Botola Pro",
    position: "Avant-centre",
    status: "Ouvert",
    deadline: "30 juin 2026"
  },
  {
    id: "o2",
    title: "Essai gardien senior",
    club: "Club National 3",
    country: "France",
    city: "Nantes",
    level: "National 3",
    position: "Gardien",
    status: "Candidatures",
    deadline: "15 juillet 2026"
  },
  {
    id: "o3",
    title: "Analyste vidéo pour équipe première",
    club: "Académie internationale",
    country: "France",
    city: "Paris",
    level: "Académie",
    position: "Staff",
    status: "Premium club",
    deadline: "Ouvert"
  }
];

export const conversations: Conversation[] = [
  {
    id: "m1",
    contact: "Responsable recrutement",
    role: "Club",
    subject: "Demande de vidéo complète",
    lastMessage: "Le club souhaite consulter le match complet du 12 mai.",
    status: "À traiter"
  },
  {
    id: "m2",
    contact: "Agent vérifié",
    role: "Agent",
    subject: "Représentation joueur",
    lastMessage: "Proposition de rendez-vous pour discuter du projet sportif.",
    status: "Nouveau"
  },
  {
    id: "m3",
    contact: "Scout indépendant",
    role: "Recruteur",
    subject: "Short-list été 2026",
    lastMessage: "Profil ajouté à une liste de suivi.",
    status: "Lu"
  }
];
