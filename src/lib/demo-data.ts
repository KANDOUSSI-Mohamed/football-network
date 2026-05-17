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
    }
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
    club: "Academie privee",
    status: "Ouvert aux opportunites",
    stats: {
      matches: 29,
      goals: 6,
      assists: 11
    }
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
    }
  }
];

export const clubs: Club[] = [
  {
    id: "c1",
    name: "Olympique Lyonnais",
    country: "France",
    city: "Lyon",
    division: "Ligue 1",
    status: "Fiche publique non revendiquee",
    needs: ["U19", "Scouting", "Milieu defensif"]
  },
  {
    id: "c2",
    name: "CODM Meknes",
    country: "Maroc",
    city: "Meknes",
    division: "Botola Pro",
    status: "Fiche publique non revendiquee",
    needs: ["Attaquant", "Analyse video", "U23"]
  },
  {
    id: "c3",
    name: "FC Nantes",
    country: "France",
    city: "Nantes",
    division: "Ligue 1",
    status: "Fiche publique non revendiquee",
    needs: ["Academie", "Recrutement jeunes", "Gardien"]
  }
];

