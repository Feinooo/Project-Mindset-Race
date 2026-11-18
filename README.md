# 🧠 Mindset Race

Jeu Roblox : une course de 30 à 60 secondes où tu choisis un état d'esprit (**Motivation**, **Ego**, **Discipline**, **Obsession**) qui court à sa façon. Inspiré de la trend TikTok « Motivation vs Ego vs Obsession vs Discipline ».

## Installation dans Roblox Studio

| Fichier | Où le mettre dans Studio | Type |
|---|---|---|
| `src/ServerScriptService/MindsetServer.server.lua` | ServerScriptService | Script |
| `src/StarterPlayerScripts/MindsetClient.client.lua` | StarterPlayer > StarterPlayerScripts | LocalScript |

Le script serveur construit tout seul la piste, le lobby et l'arche d'arrivée.

## À faire

- [ ] Coller les ID des musiques (`MUSIQUE_LOBBY`, `MUSIQUE_COURSE`, `MUSIQUES_AURA`, `MUSIQUE_VICTOIRE` dans le CONFIG du script serveur)
- [x] Courses immersives : nuit néon, public qui saute, intro cinématique, décompte, lignes de vitesse, plaques turbo, niveaux d'aura (étincelles → flammes → AURA MAX), dernière ligne droite, cinématique du gagnant, confettis
- [x] Sauvegarde de la progression (DataStore) : victoires et aura
- [x] Perso Talent (débloqué après 10 victoires)
- [x] Bots réalistes (pseudos, looks, animations, esquives, balayettes)
- [x] Tacle (**E**) et balayette (**F**), avec boutons sur mobile
- [ ] Auras à débloquer
- [ ] Classement du jour
- [ ] Écran de fin adapté au mobile
- [ ] Tests avec des amis, puis publication
