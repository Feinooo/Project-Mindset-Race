# 🧠 Mindset Race

Jeu Roblox : une course de 30 à 60 secondes où tu choisis un état d'esprit (**Motivation**, **Ego**, **Discipline**, **Obsession**) qui court à sa façon. Inspiré de la trend TikTok « Motivation vs Ego vs Obsession vs Discipline ».

## Installation dans Roblox Studio

| Fichier | Où le mettre dans Studio | Type |
|---|---|---|
| `src/ServerScriptService/MindsetServer.server.lua` | ServerScriptService | Script |
| `src/StarterPlayerScripts/MindsetClient.client.lua` | StarterPlayer > StarterPlayerScripts | LocalScript |

Le script serveur construit tout seul la piste, le lobby et l'arche d'arrivée.

## À faire

- [ ] Musique d'aura (`ID_MUSIQUE_AURA`)
- [x] Sauvegarde de la progression (DataStore) : victoires et aura
- [x] Perso Talent (débloqué après 10 victoires)
- [x] Bots réalistes (pseudos, looks, animations, esquives, balayettes)
- [x] Vue à la première personne avec les bras visibles, **C** pour regarder derrière
- [x] Tacle (**E**) et balayette (**F**), avec boutons sur mobile
- [ ] Auras à débloquer
- [ ] Classement du jour
- [ ] Écran de fin adapté au mobile
- [ ] Tests avec des amis, puis publication
