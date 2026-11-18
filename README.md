# 🧠 Mindset Stairs

Jeu Roblox en 2D inspiré des vidéos TikTok « Motivation vs Ego vs Discipline vs Obsession » qui montent des escaliers.
Ici, c'est **toi** qui montes, avec **ton avatar Roblox** : une musique d'aura se lance, des cercles apparaissent à l'écran,
tu cliques dessus **en rythme**. Note réussie = tu montes. Note ratée = tu redescends.

## Les persos

| Perso | Règle |
|---|---|
| **Motivation** | +2 marches par note au début, +1 ensuite. Rater au début = -1, ensuite = -2 |
| **Ego** | +1 par note, +2 sur les PARFAIT dès 10 de combo. Rater = -2 |
| **Discipline** | +1 par note, jamais plus. Ne redescend **jamais** |
| **Obsession** | Au début seuls les PARFAIT comptent, puis +1, puis +2 sur la 2e moitié. Rater = -1 |

## Installation dans Roblox Studio

| Fichier | Où le mettre dans Studio | Type |
|---|---|---|
| `src/ServerScriptService/MindsetServer.server.lua` | ServerScriptService | Script |
| `src/StarterPlayerScripts/MindsetClient.client.lua` | StarterPlayer > StarterPlayerScripts | LocalScript |

Le script serveur construit tout seul la scène (les escaliers, le fond, la lumière).

## Musiques

Dans le `CONFIG` du script serveur, remplis `MUSIQUES` :

```lua
MUSIQUES = {
    { id = "rbxassetid://123456789", bpm = 130, debut = 12.5, decalage = 0 },
},
```

- `id` : l'ID copié dans la Toolbox (onglet Audio) ou le Creator Store
- `bpm` : le tempo de la musique
- `debut` : la seconde où on démarre (pour commencer direct sur le drop)
- `decalage` : à ajuster si les cercles tombent un peu à côté du rythme

## À faire

- [ ] Ajouter les musiques (ID + BPM)
- [ ] Tester, équilibrer les persos
- [ ] Publier

L'ancien jeu de course est gardé dans le repère git `v1-course`.
