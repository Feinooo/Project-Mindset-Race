--[[
    🥊 MINDSET BATTLEGROUNDS — Script SERVEUR
    À mettre dans : ServerScriptService  (type : Script, nom : MindsetServer)

    Un jeu de combat en arène (genre « battlegrounds »), sur la trend Motivation vs Ego vs Discipline vs Obsession.
      - Un GRAND LOBBY à explorer (zone sans danger) : les 4 sanctuaires des états d'esprit, le marchand d'aura,
        les tableaux TOP 100, une tour de parkour, une zone AFK, des gradins et un écran géant sur l'arène.
      - L'ARÈNE : tout le monde contre tout le monde, sans fin. Tu meurs → tu reviens au lobby.
      - Chaque état d'esprit a son style de combat (comme dans la trend) :
          MOTIVATION : énorme au début, puis son énergie s'éteint (les kills la rallument)
          EGO        : gros dégâts et combos stylés, mais fragile
          DISCIPLINE : bloque, contre, dur à tuer
          OBSESSION  : faible au début, plus fort à chaque coup donné
      - Les gros moments (ultime, kill) passent en EDIT NOIR ET BLANC (script client).
    Ce script construit toute la carte, gère le combat (dégâts, étourdissements, kits), les bots, l'aura,
    la sauvegarde et les classements. Le script client s'occupe de l'affichage, des animations et des commandes.
    (les anciens jeux sont gardés dans les tags git « v1-course », « v2-rythme », et le commit 1c6e90f pour l'escalier 3D)
]]

-- ===================== RÉGLAGES (tu peux les modifier) =====================
local CONFIG = {
    -- ❤️ les points de vie de chaque état d'esprit
    PV = { Motivation = 100, Ego = 85, Discipline = 125, Obsession = 100 },
    -- 🏃 les vitesses (16 = la vitesse normale de Roblox)
    VITESSE_LOBBY = 20,
    REAPPARITION = 4,       -- secondes avant de revenir au lobby après une mort
    PROTECTION = 2,         -- secondes d'invincibilité en entrant dans l'arène
    BOTS = 4,               -- l'arène a au moins ce nombre de combattants : des bots complètent
    BOTS_MIN = 2,           -- et toujours au moins 2 bots (pour qu'il y ait de l'action à regarder)
    SOIN_KILL = 25,         -- PV rendus quand tu fais un kill

    -- 💜 L'AURA (la monnaie du marchand)
    AURA_KILL = 15,         -- par kill
    AURA_DEGATS = 25,       -- 1 aura toutes les 25 points de dégâts infligés
    AURA_AFK = 1,           -- dans la zone AFK : 1 aura toutes les 30 secondes
    AURA_PARKOUR = 50,      -- en haut de la tour de parkour (une fois par serveur)

    -- 🎵 MUSIQUES : jouées en fond (une au hasard, puis la suivante). id = "" : ignorée.
    MUSIQUES = {
        { id = "rbxassetid://74842327948915", nom = "BUFÓN!" },
        { id = "rbxassetid://134372266822247", nom = "MONTAGE SENNTANA" },
        { id = "rbxassetid://117822777228038", nom = "ME VS ME" },
        { id = "rbxassetid://84227603413943", nom = "NO ERA AMOR" },
        { id = "rbxassetid://80140071567818", nom = "EMPIRE" },
        { id = "rbxassetid://135464211325455", nom = "TIKI TIKI" },
        { id = "rbxassetid://127965945833744", nom = "Your Next Opponent Is You" },
    },

    -- 🛒 MARCHAND D'AURA
    COUTS = { 100, 250, 500, 900, 1500 }, -- prix (en aura) du niveau 1, 2, 3, 4, 5 d'une compétence
    AURA_CADEAU_STUDIO = 3000,            -- en Studio seulement : de l'aura pour tester le marchand
}

-- 🥊 LES KITS : ce que chaque état d'esprit sait faire (affiché sur les sanctuaires et en bas de l'écran).
-- Les chiffres (dégâts, durées...) sont dans la partie « LES CAPACITÉS » plus bas.
-- Commandes : clic = coups (combo de 4) · F = bloquer · Q = esquive · 1 2 3 = capacités · G = ultime · T = provoquer
local KITS = {
    Motivation = {
        devise = "Fast start. Then it fades.",
        passif = { nom = "BURNOUT", texte = "Huge damage and speed at full energy. Energy fades over time. Kills light it back up." },
        { nom = "RUSH", texte = "Dash forward with a burning punch", recharge = 6 },
        { nom = "FIRE FISTS", texte = "A flurry of 5 fast punches", recharge = 9 },
        { nom = "SECOND WIND", texte = "Get 40% of your energy back", recharge = 22 },
        ult = { nom = "LAST FLAME", texte = "8 s at full energy: +50% damage, faster" },
    },
    Ego = {
        devise = "Main character. Glass jaw.",
        passif = { nom = "MAIN CHARACTER", texte = "+25% damage but less health. Double jump. Taunt (T) charges your ultimate." },
        { nom = "SHOWTIME", texte = "An uppercut that launches the enemy", recharge = 7 },
        { nom = "SPOTLIGHT SLAM", texte = "Jump and slam the ground (breaks guards)", recharge = 10 },
        { nom = "MIRROR", texte = "Counter stance: the next hit is sent back", recharge = 12 },
        ult = { nom = "MAIN CHARACTER MOMENT", texte = "8 s: every hit is a critical hit" },
    },
    Discipline = {
        devise = "Steady. Hard to kill.",
        passif = { nom = "IRON WILL", texte = "More health. Blocking stops 90% of the damage." },
        { nom = "COUNTER", texte = "Parry stance: punish the next attack", recharge = 8 },
        { nom = "ROUTINE", texte = "3 heavy hits that nothing can interrupt", recharge = 9 },
        { nom = "WALL", texte = "A shockwave that pushes everyone away", recharge = 12 },
        ult = { nom = "UNBREAKABLE", texte = "8 s: 70% less damage, can't be stunned" },
    },
    Obsession = {
        devise = "Slow start. Unstoppable end.",
        passif = { nom = "FIXATION", texte = "Every hit you land makes you stronger and faster (20 stacks max: unstoppable)." },
        { nom = "HUNT", texte = "Teleport behind the closest enemy and hit", recharge = 12 },
        { nom = "RELENTLESS", texte = "Grab the enemy and hit 3 times", recharge = 9 },
        { nom = "FRENZY", texte = "5 s of much faster punches", recharge = 18 },
        ult = { nom = "OBSESSED", texte = "8 s: max stacks and every hit heals you" },
    },
}

-- 🧠 LES COMPÉTENCES du marchand : 3 par état d'esprit, de niveau 0 à 5, achetées avec l'aura.
--   texte = ce que fait la compétence (%s = la valeur du niveau, %% = le signe %)
--   valeurs = la valeur à chaque niveau (1, 2, 3, 4, 5)
-- ⚠️ Si tu changes un texte, change aussi sa traduction (script client, partie LANGUE).
local COMPETENCES = {
    Motivation = {
        { nom = "SLOW BURN", texte = "Energy fades %s%% slower", valeurs = { 10, 20, 30, 40, 50 } },
        { nom = "HOT HANDS", texte = "RUSH and FIRE FISTS deal +%s%% damage", valeurs = { 10, 20, 30, 40, 50 } },
        { nom = "COMEBACK", texte = "Kills give back %s%% more energy", valeurs = { 20, 40, 60, 80, 100 } },
    },
    Ego = {
        { nom = "THICK SKIN", texte = "+%s max health", valeurs = { 5, 10, 15, 20, 25 } },
        { nom = "SHOWOFF", texte = "SHOWTIME and SLAM deal +%s%% damage", valeurs = { 10, 20, 30, 40, 50 } },
        { nom = "SPOTLIGHT", texte = "Your ultimate charges %s%% faster", valeurs = { 10, 20, 30, 40, 50 } },
    },
    Discipline = {
        { nom = "IRON GUARD", texte = "Every blocked hit heals you %s HP", valeurs = { 1, 2, 3, 4, 5 } },
        { nom = "ROUTINE+", texte = "ROUTINE deals +%s%% damage", valeurs = { 10, 20, 30, 40, 50 } },
        { nom = "HARD WORK", texte = "+%s%% aura earned", valeurs = { 10, 20, 35, 50, 75 } },
    },
    Obsession = {
        { nom = "FIXATION+", texte = "+%s max stacks", valeurs = { 2, 4, 6, 8, 10 } },
        { nom = "PREDATOR", texte = "HUNT recharges %s%% faster", valeurs = { 10, 20, 30, 40, 50 } },
        { nom = "BLOODLUST", texte = "Heal %s%% of the damage you deal", valeurs = { 2, 4, 6, 8, 10 } },
    },
}
local NIVEAU_MAX = #CONFIG.COUTS
-- ===========================================================================

local PERSOS = {
    Motivation = { couleur = Color3.fromRGB(255, 150, 30) },
    Ego = { couleur = Color3.fromRGB(170, 80, 255) },
    Discipline = { couleur = Color3.fromRGB(60, 140, 255) },
    Obsession = { couleur = Color3.fromRGB(230, 40, 60) },
}
local ORDRE_PERSOS = { "Motivation", "Ego", "Discipline", "Obsession" }
local OR = Color3.fromRGB(255, 220, 80)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local function creer(classe, proprietes)
    local objet = Instance.new(classe)
    for nom, valeur in pairs(proprietes) do
        if nom ~= "Parent" then
            objet[nom] = valeur
        end
    end
    objet.Parent = proprietes.Parent
    return objet
end

local function auHasard(liste)
    return liste[math.random(1, #liste)]
end

-- ========================== COMMUNICATION ==========================
-- (on enlève d'abord les restes des anciennes versions du jeu)
for _, nom in ipairs({ "MindsetRemotes", "Grimpeurs", "ChoixMusiques", "Classements", "TesteurMusiques", "MindsetMarchand" }) do
    local vieux = ReplicatedStorage:FindFirstChild(nom)
    if vieux then
        vieux:Destroy()
    end
end
for _, nom in ipairs({ "MindsetScene", "MindsetEscalier", "MindsetDecor", "MindsetObstacles", "MindsetHubSol", "Bots", "MindsetMap", "MindsetBots" }) do
    local vieux = workspace:FindFirstChild(nom)
    if vieux then
        vieux:Destroy()
    end
end

local dossierRemotes = Instance.new("Folder")
dossierRemotes.Name = "MindsetRemotes"
local function remote(nom)
    return creer("RemoteEvent", { Name = nom, Parent = dossierRemotes })
end
local ActionEvent = remote("Action")       -- client -> serveur : "M1", "Garde", "Esquive", "Capacite" (1-3), "Ultime", "Provoc"
local AnimEvent = remote("Anim")           -- serveur -> clients : tel combattant fait telle animation
local ImpactEvent = remote("Impact")       -- serveur -> clients : un coup a touché (étincelles, dégâts, son)
local CoupEvent = remote("Coup")           -- serveur -> joueur touché : recul (le joueur bouge son propre avatar)
local KillEvent = remote("Kill")           -- serveur -> clients : un kill (fil des kills + edit noir et blanc)
local UltEvent = remote("Ult")             -- serveur -> clients : quelqu'un lance son ultime
local FinEvent = remote("Fin")             -- serveur -> joueur : son écran de mort (stats de sa vie)
local ZoneEvent = remote("Zone")           -- serveur -> joueur : il entre dans l'arène / revient au lobby
local MessageEvent = remote("Message")     -- serveur -> joueur : petit message (« tu es EGO », « parkour réussi »...)
local ReglagesEvent = remote("Reglages")   -- client -> serveur : ses paramètres (volumes, langue...) à sauvegarder
local ClassementFonction = creer("RemoteFunction", { Name = "Classement", Parent = dossierRemotes }) -- un top 100
local AmeliorerFonction = creer("RemoteFunction", { Name = "Ameliorer", Parent = dossierRemotes }) -- acheter une compétence
dossierRemotes.Parent = ReplicatedStorage

-- ce que les clients doivent savoir (affichage des kits, du marchand, musiques)
do
    -- (en JSON, une table ne peut pas mélanger [1], [2], [3] et des noms : les 3 capacités vont dans « capacites »)
    local kitsJson = {}
    for perso, kit in pairs(KITS) do
        kitsJson[perso] = { devise = kit.devise, passif = kit.passif, ult = kit.ult, capacites = { kit[1], kit[2], kit[3] } }
    end
    ReplicatedStorage:SetAttribute("Kits", HttpService:JSONEncode(kitsJson))
end
ReplicatedStorage:SetAttribute("Competences", HttpService:JSONEncode({ couts = CONFIG.COUTS, persos = COMPETENCES }))
do
    local musiques = {}
    for _, m in ipairs(CONFIG.MUSIQUES) do
        if m.id ~= "" then
            table.insert(musiques, m)
        end
    end
    ReplicatedStorage:SetAttribute("Musiques", HttpService:JSONEncode(musiques))
end
Players.RespawnTime = CONFIG.REAPPARITION

-- ========================== LUMIÈRE : le look « edit » ==========================
-- Nuit, très contrasté, couleurs un peu éteintes : le noir et blanc des edits, avec les néons des 4 états d'esprit.
Lighting.ClockTime = 0
Lighting.Brightness = 1
Lighting.Ambient = Color3.fromRGB(150, 150, 160)
Lighting.OutdoorAmbient = Color3.fromRGB(110, 110, 120)
Lighting.EnvironmentDiffuseScale = 0.3
Lighting.EnvironmentSpecularScale = 0.6
for _, nom in ipairs({ "MindsetBloom", "MindsetStyle" }) do
    local vieux = Lighting:FindFirstChild(nom)
    if vieux then
        vieux:Destroy()
    end
end
creer("BloomEffect", { Name = "MindsetBloom", Intensity = 1, Size = 28, Threshold = 0.9, Parent = Lighting })
creer("ColorCorrectionEffect", { Name = "MindsetStyle", Saturation = -0.35, Contrast = 0.18, Brightness = 0.02, Parent = Lighting })


-- ========================== SAUVEGARDE (DataStore) ==========================
-- ⚠️ Pour tester dans Studio : publie le jeu, puis
--    Paramètres du jeu > Sécurité > « Activer l'accès Studio aux services API ».
-- (même sauvegarde que les anciennes versions : l'aura, les niveaux du marchand et les réglages sont gardés)
local donneesChargees = {}
local sauvegarde = nil
do
    local ok, resultat = pcall(function()
        return DataStoreService:GetDataStore("MindsetStairs_Joueurs_v1")
    end)
    if ok then
        sauvegarde = resultat
    else
        warn("💾 Sauvegarde désactivée (publie le jeu et active l'accès Studio aux services API) :", resultat)
    end
end

local function essayer(fonction)
    for essai = 1, 3 do
        local ok, resultat = pcall(fonction)
        if ok then
            return true, resultat
        end
        warn("💾 Sauvegarde : essai " .. essai .. " raté :", resultat)
        if essai < 3 then
            task.wait(2)
        end
    end
    return false, nil
end

local reglagesJoueurs = {} -- [joueur] = { musique, bruitages, secousses, flashs, langue }

-- 📊 Les stats du joueur.
--   En haut à droite (leaderstats) : KILLS (au total) et STREAK (kills d'affilée sans mourir).
--   Cachées (StatsCachees) : l'Aura, la meilleure série de tous les temps, les secondes de jeu.
local arrivees = {} -- [joueur] = os.clock() de son arrivée

local function chercherStat(joueur, nom)
    for _, dossier in ipairs({ "leaderstats", "StatsCachees" }) do
        local stats = joueur and joueur:FindFirstChild(dossier)
        local valeur = stats and stats:FindFirstChild(nom)
        if valeur then
            return valeur
        end
    end
    return nil
end

local function ajouterStat(joueur, nom, nombre)
    local valeur = chercherStat(joueur, nom)
    if valeur then
        valeur.Value += nombre
    end
end

local function tempsTotal(joueur)
    local base = chercherStat(joueur, "Secondes")
    return (if base then base.Value else 0) + math.floor(os.clock() - (arrivees[joueur] or os.clock()))
end

-- 🧠 Les niveaux de compétences : [joueur] = { Motivation = {0, 0, 0}, Ego = {...}, ... }
local niveauxJoueurs = {}
local chargementFini = {} -- [joueur] = true quand ses données sont chargées

local function niveauxVides()
    local niveaux = {}
    for perso, liste in pairs(COMPETENCES) do
        niveaux[perso] = {}
        for i = 1, #liste do
            niveaux[perso][i] = 0
        end
    end
    return niveaux
end

local function lireNiveaux(brut)
    local niveaux = niveauxVides()
    if type(brut) == "table" then
        for perso, liste in pairs(niveaux) do
            local sauves = brut[perso]
            if type(sauves) == "table" then
                for i = 1, #liste do
                    local n = sauves[i]
                    if type(n) == "number" and n == n then
                        liste[i] = math.clamp(math.floor(n), 0, NIVEAU_MAX)
                    end
                end
            end
        end
    end
    return niveaux
end

-- les clients lisent les niveaux dans l'attribut « Niveaux » du joueur (texte JSON)
local function publierNiveaux(joueur)
    joueur:SetAttribute("Niveaux", HttpService:JSONEncode(niveauxJoueurs[joueur] or niveauxVides()))
end

local surChargement -- (défini plus bas : on applique l'état d'esprit sauvegardé à l'avatar)

local function finChargement(joueur, donnees)
    niveauxJoueurs[joueur] = lireNiveaux(donnees and donnees.niveaux)
    publierNiveaux(joueur)
    local perso = donnees and donnees.perso
    if type(perso) == "string" and PERSOS[perso] and not joueur:GetAttribute("Perso") then
        joueur:SetAttribute("Perso", perso)
    end
    -- 🎁 en Studio : de l'aura pour tester le marchand
    local aura = chercherStat(joueur, "Aura")
    if RunService:IsStudio() and aura and aura.Value < CONFIG.AURA_CADEAU_STUDIO then
        aura.Value = CONFIG.AURA_CADEAU_STUDIO
    end
    chargementFini[joueur] = true
    if surChargement then
        surChargement(joueur)
    end
end

local function chargerJoueur(joueur)
    if not sauvegarde then
        finChargement(joueur, nil)
        return
    end
    local ok, donnees = essayer(function()
        return sauvegarde:GetAsync("joueur_" .. joueur.UserId)
    end)
    if not joueur.Parent then
        return
    end
    if ok then
        donnees = donnees or {}
        chercherStat(joueur, "Kills").Value += donnees.kills or 0
        chercherStat(joueur, "MeilleureSerie").Value = math.max(chercherStat(joueur, "MeilleureSerie").Value, donnees.serie or 0)
        chercherStat(joueur, "Aura").Value += donnees.aura or 0
        chercherStat(joueur, "Secondes").Value += donnees.temps or 0
        joueur:SetAttribute("Record", chercherStat(joueur, "MeilleureSerie").Value)
        if type(donnees.reglages) == "table" then
            reglagesJoueurs[joueur] = donnees.reglages
            joueur:SetAttribute("Reglages", HttpService:JSONEncode(donnees.reglages))
        end
        donneesChargees[joueur] = true
        finChargement(joueur, donnees)
    else
        warn("💾 Impossible de charger les données de " .. joueur.Name .. " : pas de sauvegarde pour cette partie.")
        finChargement(joueur, nil)
    end
end

local function sauverJoueur(joueur)
    if not sauvegarde or not donneesChargees[joueur] or not chercherStat(joueur, "Kills") then
        return
    end
    local kills = chercherStat(joueur, "Kills").Value
    local serie = chercherStat(joueur, "MeilleureSerie").Value
    local aura = chercherStat(joueur, "Aura").Value
    local temps = tempsTotal(joueur)
    local reglages = reglagesJoueurs[joueur]
    local niveaux = niveauxJoueurs[joueur]
    local perso = joueur:GetAttribute("Perso")
    essayer(function()
        sauvegarde:UpdateAsync("joueur_" .. joueur.UserId, function(anciennes)
            local donnees = anciennes or {}
            donnees.kills = kills
            donnees.serie = math.max(serie, donnees.serie or 0)
            donnees.aura = aura
            donnees.temps = temps
            donnees.reglages = reglages or donnees.reglages
            donnees.niveaux = niveaux or donnees.niveaux
            donnees.perso = perso or donnees.perso
            return donnees
        end)
    end)
end

game:BindToClose(function()
    local restants = 0
    for _, joueur in ipairs(Players:GetPlayers()) do
        restants += 1
        task.spawn(function()
            sauverJoueur(joueur)
            restants -= 1
        end)
    end
    local limite = os.clock() + 25
    while restants > 0 and os.clock() < limite do
        task.wait(0.1)
    end
end)

task.spawn(function()
    while true do
        task.wait(120)
        for _, joueur in ipairs(Players:GetPlayers()) do
            task.spawn(sauverJoueur, joueur)
        end
    end
end)

-- PARAMÈTRES : on garde les réglages du joueur
ReglagesEvent.OnServerEvent:Connect(function(joueur, reglages)
    if type(reglages) ~= "table" then
        return
    end
    local function nombre(x)
        return if type(x) == "number" and x == x then math.clamp(x, 0, 1) else 1
    end
    reglagesJoueurs[joueur] = {
        musique = nombre(reglages.musique),
        bruitages = nombre(reglages.bruitages),
        secousses = reglages.secousses ~= false,
        flashs = reglages.flashs ~= false,
        langue = if reglages.langue == "en" or reglages.langue == "fr" then reglages.langue else "auto",
    }
end)

-- 🛒 LE MARCHAND : acheter le niveau suivant d'une compétence avec son aura.
-- Renvoie ok (true/false), puis le nouveau niveau ou la raison du refus.
local achatEnCours = {}
AmeliorerFonction.OnServerInvoke = function(joueur, perso, numero)
    if type(perso) ~= "string" or not COMPETENCES[perso] or type(numero) ~= "number" or not COMPETENCES[perso][numero] then
        return false, "Unknown skill"
    end
    if not chargementFini[joueur] or not niveauxJoueurs[joueur] then
        return false, "Still loading your data..."
    end
    if achatEnCours[joueur] then
        return false, "Wait a second..."
    end
    achatEnCours[joueur] = true
    local niveaux = niveauxJoueurs[joueur][perso]
    local niveau = niveaux[numero]
    local aura = chercherStat(joueur, "Aura")
    local resultatOk, resultat
    if niveau >= NIVEAU_MAX then
        resultatOk, resultat = false, "Already at max level"
    elseif not aura or aura.Value < CONFIG.COUTS[niveau + 1] then
        resultatOk, resultat = false, "Not enough aura"
    else
        aura.Value -= CONFIG.COUTS[niveau + 1]
        niveaux[numero] = niveau + 1
        publierNiveaux(joueur)
        resultatOk, resultat = true, niveau + 1
    end
    achatEnCours[joueur] = nil
    return resultatOk, resultat
end


-- ========================== CLASSEMENTS (TOP 100) ==========================
--   K = le plus de KILLS au total · S = la meilleure SÉRIE de kills (sans mourir)
-- Sauvegardés dans des OrderedDataStore (il faut publier le jeu) ; sinon, on garde ceux de la session.
local TABLEAUX = {
    K = { nom = "MSB_Kills_v1" },
    S = { nom = "MSB_Serie_v1" },
}
local alerteClassement = false
for _, t in pairs(TABLEAUX) do
    t.session, t.charges, t.cache, t.cacheA = {}, {}, nil, -math.huge
    local ok, store = pcall(function()
        return DataStoreService:GetOrderedDataStore(t.nom)
    end)
    if ok then
        t.store = store
    end
end

local function alerte(erreur)
    if not alerteClassement then
        alerteClassement = true
        warn("🏆 Classements : sauvegarde indisponible (publie le jeu + accès Studio aux services API). On garde les scores de la session. ", erreur)
    end
end

local nomsCache = {}
local function nomDe(userId)
    if userId <= 0 then
        return "Player"
    end
    local present = Players:GetPlayerByUserId(userId)
    if present then
        nomsCache[userId] = present.DisplayName
    end
    if nomsCache[userId] then
        return nomsCache[userId]
    end
    local ok, nom = pcall(function()
        return Players:GetNameFromUserIdAsync(userId)
    end)
    nomsCache[userId] = if ok and nom then nom else ("Player " .. userId)
    return nomsCache[userId]
end

-- le top 100 (gardé 30 s en mémoire pour ne pas spammer la sauvegarde)
local function lireClassement(cle)
    local t = TABLEAUX[cle]
    if not t then
        return {}
    end
    if t.cache and os.clock() - t.cacheA < 30 then
        return t.cache
    end
    local scores = {}
    if t.store then
        local ok, page = pcall(function()
            return t.store:GetSortedAsync(false, 100):GetCurrentPage()
        end)
        if ok then
            for _, ligne in ipairs(page) do
                local id = tonumber(ligne.key)
                if id then
                    scores[id] = ligne.value
                end
            end
        else
            alerte(page)
        end
    end
    for id, score in pairs(t.session) do
        if score > (scores[id] or 0) then
            scores[id] = score
        end
    end
    local liste = {}
    for id, score in pairs(scores) do
        table.insert(liste, { id = id, score = score })
    end
    table.sort(liste, function(a, b)
        return a.score > b.score
    end)
    -- les pseudos qu'on ne connaît pas encore : on les demande tous en même temps (5 s max)
    local enAttente = 0
    for i = 1, math.min(100, #liste) do
        if not nomsCache[liste[i].id] then
            enAttente += 1
            task.spawn(function()
                nomDe(liste[i].id)
                enAttente -= 1
            end)
        end
    end
    local limite = os.clock() + 5
    while enAttente > 0 and os.clock() < limite do
        task.wait(0.05)
    end
    local resultat = {}
    for i = 1, math.min(100, #liste) do
        resultat[i] = { nom = nomsCache[liste[i].id] or ("Player " .. liste[i].id), score = liste[i].score, userId = liste[i].id }
    end
    t.cache, t.cacheA = resultat, os.clock()
    return resultat
end

local function recordDe(cle, userId)
    local t = TABLEAUX[cle]
    if not t then
        return 0
    end
    if t.store and not t.charges[userId] then
        t.charges[userId] = true
        local ok, valeur = pcall(function()
            return t.store:GetAsync(tostring(userId))
        end)
        if ok and valeur and valeur > (t.session[userId] or 0) then
            t.session[userId] = valeur
        elseif not ok then
            alerte(valeur)
        end
    end
    return t.session[userId] or 0
end

-- enregistre un score s'il est meilleur que l'ancien
local function enregistrerRecord(cle, joueur, score)
    local t = TABLEAUX[cle]
    if not t or score <= 0 or score <= (t.session[joueur.UserId] or 0) then
        return
    end
    t.session[joueur.UserId] = score
    t.cache = nil
    if t.store then
        local ok, erreur = pcall(function()
            t.store:UpdateAsync(tostring(joueur.UserId), function(ancien)
                if (ancien or 0) >= score then
                    return nil
                end
                return score
            end)
        end)
        if not ok then
            alerte(erreur)
        end
    end
end

local dernierAppelClassement = {}
ClassementFonction.OnServerInvoke = function(demandeur, cle)
    if typeof(cle) ~= "string" or not TABLEAUX[cle] then
        return nil
    end
    if os.clock() - (dernierAppelClassement[demandeur] or 0) < 0.25 then
        task.wait(0.25) -- anti-spam
    end
    dernierAppelClassement[demandeur] = os.clock()
    return { liste = lireClassement(cle), moi = recordDe(cle, demandeur.UserId) }
end
Players.PlayerRemoving:Connect(function(parti)
    dernierAppelClassement[parti] = nil
end)


-- ========================== LA CARTE ==========================
-- Tout est construit ici (le même pour tout le monde). Le script client trouve les endroits importants par leur nom :
--   Sanctuaire_<Perso>, PointMarchand, TableauKills, TableauSerie, EcranGeant, ZoneAFK, SommetParkour, Porte, Sortie
-- LOBBY : centre L, sol à y = 200, de -115 à +115 en x et en z. Au sud (z = +115) : la vitre qui donne sur l'arène.
-- ARÈNE : centre A, ronde, rayon 95, juste derrière la vitre.
local L = Vector3.new(0, 200, 0)
local A = Vector3.new(0, 200, 272)
local RAYON_ARENE = 95
local APPARITION = L + Vector3.new(0, 3, -42) -- là où on apparaît au lobby

local dossierCarte = creer("Folder", { Name = "MindsetMap", Parent = workspace })
local dossierLobby = creer("Folder", { Name = "Lobby", Parent = dossierCarte })
local dossierArene = creer("Folder", { Name = "Arene", Parent = dossierCarte })

local function bloc(proprietes)
    proprietes.Anchored = true
    proprietes.TopSurface = Enum.SurfaceType.Smooth
    proprietes.BottomSurface = Enum.SurfaceType.Smooth
    proprietes.Material = proprietes.Material or Enum.Material.SmoothPlastic
    proprietes.Parent = proprietes.Parent or dossierLobby
    return creer("Part", proprietes)
end
local function neon(proprietes)
    proprietes.Material = Enum.Material.Neon
    proprietes.CanCollide = proprietes.CanCollide or false
    proprietes.CastShadow = false
    return bloc(proprietes)
end
local function invisible(proprietes)
    proprietes.Transparency = 1
    proprietes.CastShadow = false
    return bloc(proprietes)
end
local function cylindre(centre, diametre, hauteur, proprietes)
    proprietes.Shape = Enum.PartType.Cylinder
    proprietes.Size = Vector3.new(hauteur, diametre, diametre)
    proprietes.CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.pi / 2)
    return bloc(proprietes)
end
-- un texte sur la face avant d'une part (la face -Z de son CFrame)
local function panneau(part, message, couleur, pixels, police)
    local surface = creer("SurfaceGui", {
        Face = Enum.NormalId.Front,
        SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
        PixelsPerStud = pixels or 30,
        LightInfluence = 0,
        Parent = part,
    })
    creer("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Font = police or Enum.Font.GothamBlack,
        TextScaled = true,
        RichText = true,
        Text = message,
        TextColor3 = couleur,
        Parent = surface,
    })
    return surface
end
-- une part posée en position, tournée pour que sa face avant regarde dans la direction voulue
local function tournee(position, regarde)
    return CFrame.lookAt(position, position + regarde)
end
local function enCouleur(mot, couleur)
    return string.format('<font color="#%02X%02X%02X">%s</font>', math.floor(couleur.R * 255), math.floor(couleur.G * 255), math.floor(couleur.B * 255), mot)
end

-- ---------- LE SOL ET LES MURS DU LOBBY ----------
do
    bloc({ Name = "Sol", Size = Vector3.new(232, 4, 232), CFrame = CFrame.new(L - Vector3.new(0, 2, 0)), Color = Color3.fromRGB(30, 30, 34), Material = Enum.Material.Slate })
    cylindre(L + Vector3.new(0, 0.05, -10), 96, 0.1, { Name = "Place", Color = Color3.fromRGB(52, 52, 58), Material = Enum.Material.Marble, CanCollide = false })
    -- l'anneau de la place, aux 4 couleurs
    for i = 0, 63 do
        local a = i / 64 * math.pi * 2
        local position = L + Vector3.new(math.cos(a) * 48, 0.12, -10 + math.sin(a) * 48)
        neon({ Size = Vector3.new(0.5, 0.1, 2 * math.pi * 48 / 64 * 1.04), CFrame = tournee(position, Vector3.new(-math.sin(a), 0, math.cos(a))), Color = PERSOS[ORDRE_PERSOS[i // 16 + 1]].couleur })
    end
    -- les allées lumineuses (blanches) vers chaque coin
    for _, ligne in ipairs({
        { Vector3.new(-48, 0, -10), Vector3.new(-90, 0, -10) },   -- vers les sanctuaires
        { Vector3.new(48, 0, -10), Vector3.new(90, 0, -10) },     -- vers le marchand et les tableaux
        { Vector3.new(0, 0, 38), Vector3.new(0, 0, 100) },        -- vers l'arène
        { Vector3.new(-34, 0, -44), Vector3.new(-52, 0, -72) },   -- vers le parkour
        { Vector3.new(34, 0, -44), Vector3.new(54, 0, -76) },     -- vers la zone AFK
    }) do
        local a, b = L + ligne[1] + Vector3.new(0, 0.12, 0), L + ligne[2] + Vector3.new(0, 0.12, 0)
        neon({ Size = Vector3.new(0.6, 0.1, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = Color3.fromRGB(235, 235, 245), Transparency = 0.3 })
    end
    -- murs : bas et sombres autour, avec un liseré ; des murs invisibles hauts pour ne pas sortir
    for _, mur in ipairs({
        { Vector3.new(-115, 0, 0), Vector3.new(2, 6, 232) },
        { Vector3.new(115, 0, 0), Vector3.new(2, 6, 232) },
        { Vector3.new(0, 0, -115), Vector3.new(232, 6, 2) },
    }) do
        bloc({ Name = "Muret", Size = mur[2], CFrame = CFrame.new(L + mur[1] + Vector3.new(0, 3, 0)), Color = Color3.fromRGB(20, 20, 24) })
        neon({ Size = mur[2] * Vector3.new(1, 0, 1) + Vector3.new(0.2, 0.25, 0.2), CFrame = CFrame.new(L + mur[1] + Vector3.new(0, 6.1, 0)), Color = Color3.fromRGB(235, 235, 245) })
        invisible({ Name = "MurInvisible", Size = mur[2] + Vector3.new(0, 80, 0), CFrame = CFrame.new(L + mur[1] + Vector3.new(0, 40, 0)) })
    end
    -- au sud : la grande VITRE qui donne sur l'arène
    bloc({ Name = "Vitre", Size = Vector3.new(232, 44, 1), CFrame = CFrame.new(L + Vector3.new(0, 22, 115.5)), Material = Enum.Material.Glass, Color = Color3.fromRGB(200, 210, 230), Transparency = 0.8 })
    invisible({ Name = "MurInvisible", Size = Vector3.new(232, 90, 2), CFrame = CFrame.new(L + Vector3.new(0, 45, 116)) })
    neon({ Size = Vector3.new(232, 0.3, 0.3), CFrame = CFrame.new(L + Vector3.new(0, 44, 115)), Color = Color3.fromRGB(235, 235, 245) })
end

-- ---------- LE TITRE (au nord) + le point d'apparition ----------
do
    local titre = bloc({ Name = "Titre", Size = Vector3.new(96, 26, 1), CFrame = tournee(L + Vector3.new(0, 26, -113), Vector3.new(0, 0, 1)), Color = Color3.fromRGB(10, 10, 12) })
    panneau(titre, "MINDSET\nBATTLEGROUNDS", Color3.fromRGB(245, 245, 250), 10)
    local sousTitre = bloc({ Name = "SousTitre", Size = Vector3.new(96, 5, 1), CFrame = tournee(L + Vector3.new(0, 10, -113), Vector3.new(0, 0, 1)), Color = Color3.fromRGB(10, 10, 12) })
    panneau(sousTitre, enCouleur("MOTIVATION", PERSOS.Motivation.couleur) .. "  vs  " .. enCouleur("EGO", PERSOS.Ego.couleur) .. "  vs  "
        .. enCouleur("DISCIPLINE", PERSOS.Discipline.couleur) .. "  vs  " .. enCouleur("OBSESSION", PERSOS.Obsession.couleur), Color3.fromRGB(200, 200, 210), 20)
    neon({ Size = Vector3.new(98, 0.4, 0.4), CFrame = CFrame.new(L + Vector3.new(0, 39.4, -112.4)), Color = Color3.fromRGB(245, 245, 250) })
    cylindre(APPARITION - Vector3.new(0, 2.95, 0), 14, 0.1, { Name = "Apparition", Color = Color3.fromRGB(235, 235, 245), Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.4 })
end

-- ---------- LES 4 SANCTUAIRES (ouest) : on y choisit son état d'esprit ----------
-- Une statue de marbre dans la pose de l'état d'esprit, sa devise, et le bouton E « Become ... ».
local sanctuaires = {} -- [perso] = la part du socle (avec son ProximityPrompt)
local POSES_STATUES = {
    Motivation = { RightShoulder = Vector3.new(2.9, 0, 0.1), RightElbow = Vector3.new(0.4, 0, 0), LeftShoulder = Vector3.new(0, 0, -0.35), Waist = Vector3.new(0.12, 0, 0), Neck = Vector3.new(0.25, 0, 0) },
    Ego = { LeftShoulder = Vector3.new(1.35, 0, 0.55), RightShoulder = Vector3.new(1.35, 0, -0.55), LeftElbow = Vector3.new(1.75, 0, 0), RightElbow = Vector3.new(1.75, 0, 0), Neck = Vector3.new(0.3, 0, 0), Waist = Vector3.new(0.1, 0.25, 0) },
    Discipline = { LeftShoulder = Vector3.new(1.4, 0, 0.3), RightShoulder = Vector3.new(1.2, 0, -0.3), LeftElbow = Vector3.new(2.1, 0, 0), RightElbow = Vector3.new(2.1, 0, 0), LeftKnee = -0.35, RightKnee = -0.35, LeftHip = Vector3.new(0.3, 0, -0.15), RightHip = Vector3.new(0.1, 0, 0.15) },
    Obsession = { Waist = Vector3.new(-0.45, 0, 0), Neck = Vector3.new(0.4, 0, 0), LeftShoulder = Vector3.new(0.6, 0, -0.4), RightShoulder = Vector3.new(0.6, 0, 0.4), LeftElbow = Vector3.new(0.9, 0, 0), RightElbow = Vector3.new(0.9, 0, 0), LeftKnee = -0.5, RightKnee = -0.5, LeftHip = 0.35, RightHip = 0.35 },
}
local function poserModele(modele, pose)
    for nom, angle in pairs(pose) do
        local moteur = modele:FindFirstChild(nom, true)
        if moteur and moteur:IsA("Motor6D") then
            local v = if typeof(angle) == "Vector3" then angle else Vector3.new(angle, 0, 0)
            moteur.C0 = moteur.C0 * CFrame.Angles(v.X, v.Y, v.Z)
        end
    end
end
for i, perso in ipairs(ORDRE_PERSOS) do
    local couleur = PERSOS[perso].couleur
    local base = L + Vector3.new(-90, 0, -66 + (i - 1) * 44)
    local socle = cylindre(base + Vector3.new(0, 0.75, 0), 15, 1.5, { Name = "Sanctuaire_" .. perso, Color = Color3.fromRGB(24, 24, 28), Material = Enum.Material.Marble })
    cylindre(base + Vector3.new(0, 1.55, 0), 15.6, 0.1, { Color = couleur, Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.2 })
    creer("PointLight", { Color = couleur, Range = 22, Brightness = 2.5, Parent = socle })
    -- le panneau derrière : le nom, la devise, le passif
    local fond = bloc({ Name = "Panneau_" .. perso, Size = Vector3.new(18, 20, 1), CFrame = tournee(base + Vector3.new(-12, 11, 0), Vector3.new(1, 0, 0)), Color = Color3.fromRGB(12, 12, 14) })
    neon({ Size = Vector3.new(0.3, 20.4, 18.4), CFrame = CFrame.new(base + Vector3.new(-12.6, 11, 0)), Color = couleur })
    local kit = KITS[perso]
    local titreSanctuaire = bloc({ Size = Vector3.new(16, 5, 0.2), CFrame = tournee(base + Vector3.new(-11.4, 17, 0), Vector3.new(1, 0, 0)), Transparency = 1, CanCollide = false })
    panneau(titreSanctuaire, string.upper(perso), couleur, 24)
    local texteSanctuaire = bloc({ Size = Vector3.new(16, 11, 0.2), CFrame = tournee(base + Vector3.new(-11.4, 8, 0), Vector3.new(1, 0, 0)), Transparency = 1, CanCollide = false })
    panneau(texteSanctuaire, string.format('%s\n\n<font color="#AAAAB4">%s · %s</font>', kit.devise, kit.passif.nom, kit.passif.texte), Color3.fromRGB(220, 220, 230), 24, Enum.Font.GothamBold)
    fond.Name = "Panneau_" .. perso
    -- le bouton E pour devenir cet état d'esprit
    creer("ProximityPrompt", {
        Name = "Choisir",
        ActionText = "Become " .. string.upper(perso),
        ObjectText = "Mindset",
        KeyboardKeyCode = Enum.KeyCode.E,
        HoldDuration = 0.25,
        MaxActivationDistance = 12,
        RequiresLineOfSight = false,
        Parent = socle,
    })
    sanctuaires[perso] = socle
    -- la statue de marbre (un avatar Roblox, posé et figé)
    task.spawn(function()
        local ok, statue = pcall(function()
            local description = Instance.new("HumanoidDescription")
            for _, partie in ipairs({ "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" }) do
                description[partie] = Color3.fromRGB(225, 225, 230)
            end
            return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
        end)
        if not ok or not statue then
            return
        end
        statue.Name = "Statue_" .. perso
        local humanoid = statue:FindFirstChildOfClass("Humanoid")
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        for _, objet in ipairs(statue:GetDescendants()) do
            if objet:IsA("BasePart") then
                objet.Material = Enum.Material.Marble
                objet.Anchored = objet.Name == "HumanoidRootPart"
            elseif objet:IsA("Script") or objet:IsA("LocalScript") then
                objet:Destroy()
            end
        end
        local racine = statue:FindFirstChild("HumanoidRootPart")
        local hauteur = humanoid.HipHeight + racine.Size.Y / 2
        statue:PivotTo(CFrame.lookAt(base + Vector3.new(0, 1.5 + hauteur, 0), base + Vector3.new(10, 1.5 + hauteur, 0)) * CFrame.new(0, 0, 0))
        statue:ScaleTo(1.6)
        statue:PivotTo(CFrame.lookAt(base + Vector3.new(0, 1.5 + hauteur * 1.6, 0), base + Vector3.new(10, 1.5 + hauteur * 1.6, 0)))
        poserModele(statue, POSES_STATUES[perso])
        creer("Highlight", { FillTransparency = 1, OutlineColor = couleur, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = statue })
        statue.Parent = dossierLobby
    end)
end

-- ---------- LE MARCHAND D'AURA (est) ----------
local POINT_MARCHAND
do
    local base = L + Vector3.new(92, 0, -52)
    local F = tournee(base, Vector3.new(-1, 0, 0)) -- -Z local = vers l'ouest (la place)
    local function ici(x, y, z)
        return F * CFrame.new(x, y, z)
    end
    local BOIS = Color3.fromRGB(60, 42, 34)
    bloc({ Name = "Comptoir", Size = Vector3.new(16, 3.4, 2.6), CFrame = ici(0, 1.7, -4), Color = BOIS, Material = Enum.Material.Wood })
    neon({ Size = Vector3.new(16.2, 0.15, 0.15), CFrame = ici(0, 3.45, -5.3), Color = Color3.fromRGB(170, 90, 255) })
    bloc({ Name = "FondBoutique", Size = Vector3.new(20, 16, 1), CFrame = ici(0, 8, 4), Color = Color3.fromRGB(20, 14, 30) })
    bloc({ Name = "Toit", Size = Vector3.new(22, 1, 12), CFrame = ici(0, 16.5, -1) * CFrame.Angles(math.rad(-8), 0, 0), Color = Color3.fromRGB(50, 26, 80) })
    for _, x in ipairs({ -9.5, 9.5 }) do
        bloc({ Size = Vector3.new(1, 16, 1), CFrame = ici(x, 8, -5.5), Color = BOIS, Material = Enum.Material.Wood })
    end
    local enseigne = bloc({ Name = "Enseigne", Size = Vector3.new(14, 3, 0.4), CFrame = ici(0, 19, -5.6) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, math.pi, 0), Color = Color3.fromRGB(14, 10, 22) })
    panneau(enseigne, "AURA SHOP", OR, 30)
    creer("PointLight", { Color = Color3.fromRGB(190, 120, 255), Range = 24, Brightness = 2, Parent = enseigne })
    -- le point du bouton E (devant le comptoir)
    POINT_MARCHAND = invisible({ Name = "PointMarchand", Size = Vector3.new(1, 1, 1), CFrame = ici(0, 3, -8), CanCollide = false, CanQuery = false })
    creer("ProximityPrompt", {
        Name = "Boutique",
        ActionText = "Upgrade",
        ObjectText = "Aura Merchant",
        KeyboardKeyCode = Enum.KeyCode.E,
        HoldDuration = 0,
        MaxActivationDistance = 12,
        RequiresLineOfSight = false,
        Parent = POINT_MARCHAND,
    })
    -- le marchand lui-même : un avatar tout en noir et violet derrière son comptoir
    task.spawn(function()
        local ok, marchand = pcall(function()
            local description = Instance.new("HumanoidDescription")
            description.HeadColor = Color3.fromRGB(40, 32, 52)
            description.TorsoColor = Color3.fromRGB(28, 18, 44)
            description.LeftArmColor = Color3.fromRGB(28, 18, 44)
            description.RightArmColor = Color3.fromRGB(28, 18, 44)
            description.LeftLegColor = Color3.fromRGB(18, 14, 26)
            description.RightLegColor = Color3.fromRGB(18, 14, 26)
            return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
        end)
        if not ok or not marchand then
            warn("🛒 Impossible de créer le marchand :", marchand)
            return
        end
        marchand.Name = "Marchand"
        local humanoid = marchand:FindFirstChildOfClass("Humanoid")
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        for _, objet in ipairs(marchand:GetDescendants()) do
            if objet:IsA("Script") or objet:IsA("LocalScript") then
                objet:Destroy()
            end
        end
        local racine = marchand:FindFirstChild("HumanoidRootPart")
        racine.Anchored = true
        local hauteur = humanoid.HipHeight + racine.Size.Y / 2
        marchand:PivotTo(ici(0, hauteur, -1) * CFrame.Angles(0, 0, 0))
        poserModele(marchand, { LeftShoulder = Vector3.new(0.5, 0, -0.2), RightShoulder = Vector3.new(0.5, 0, 0.2), LeftElbow = Vector3.new(1.2, 0, 0), RightElbow = Vector3.new(1.2, 0, 0) })
        local tete = marchand:FindFirstChild("Head")
        if tete then
            local nom = creer("BillboardGui", { Size = UDim2.fromOffset(220, 30), StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0), MaxDistance = 80, Parent = tete })
            creer("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = "AURA MERCHANT", TextColor3 = OR, TextStrokeTransparency = 0.4, Parent = nom })
            creer("ParticleEmitter", {
                Rate = 8, Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(40, 40),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }),
                LightEmission = 1, Color = ColorSequence.new(Color3.fromRGB(170, 90, 255)), Parent = tete,
            })
        end
        marchand.Parent = dossierLobby
    end)
end

-- ---------- LES DEUX TABLEAUX TOP 100 (est) ----------
-- Le contenu (la liste) est dessiné par chaque client ; ici : le cadre, le podium et le bouton E.
do
    for _, infos in ipairs({ { "TableauKills", 2, OR }, { "TableauSerie", 50, Color3.fromRGB(255, 90, 90) } }) do
        local base = L + Vector3.new(104, 0, infos[2])
        local F = tournee(base, Vector3.new(-1, 0, 0))
        local planche = bloc({ Name = infos[1], Size = Vector3.new(24, 16, 0.8), CFrame = F * CFrame.new(0, 12, 0), Color = Color3.fromRGB(10, 10, 14) })
        for _, barre in ipairs({ { Vector3.new(24.8, 0.4, 0.4), CFrame.new(0, 20.2, -0.3) }, { Vector3.new(24.8, 0.4, 0.4), CFrame.new(0, 3.8, -0.3) },
            { Vector3.new(0.4, 16.8, 0.4), CFrame.new(-12.2, 12, -0.3) }, { Vector3.new(0.4, 16.8, 0.4), CFrame.new(12.2, 12, -0.3) } }) do
            neon({ Size = barre[1], CFrame = F * barre[2], Color = infos[3] })
        end
        for _, x in ipairs({ -9, 9 }) do
            bloc({ Size = Vector3.new(1, 4, 1), CFrame = F * CFrame.new(x, 2, 0), Color = Color3.fromRGB(28, 28, 34) })
        end
        creer("PointLight", { Color = infos[3], Range = 20, Brightness = 1.2, Parent = planche })
        local point = invisible({ Name = "Point" .. infos[1], Size = Vector3.new(1, 1, 1), CFrame = F * CFrame.new(0, 3, -7), CanCollide = false, CanQuery = false })
        creer("ProximityPrompt", {
            Name = "Voir",
            ActionText = "View",
            ObjectText = if infos[1] == "TableauKills" then "Top 100 · Kills" else "Top 100 · Best streak",
            KeyboardKeyCode = Enum.KeyCode.E,
            HoldDuration = 0,
            MaxActivationDistance = 12,
            RequiresLineOfSight = false,
            Parent = point,
        })
    end
end

-- ---------- LA ZONE AFK (nord-est) : on y gagne de l'aura sans rien faire ----------
local ZONE_AFK = L + Vector3.new(66, 0, -86)
do
    cylindre(ZONE_AFK + Vector3.new(0, 0.1, 0), 28, 0.2, { Name = "ZoneAFK", Color = Color3.fromRGB(40, 44, 60), Material = Enum.Material.Marble, CanCollide = false })
    cylindre(ZONE_AFK + Vector3.new(0, 0.22, 0), 28.6, 0.05, { Color = Color3.fromRGB(140, 200, 255), Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.3 })
    for k = 0, 5 do
        local a = k / 6 * math.pi * 2
        local position = ZONE_AFK + Vector3.new(math.cos(a) * 10, 1, math.sin(a) * 10)
        bloc({ Name = "Banc", Size = Vector3.new(6, 1, 2), CFrame = tournee(position, Vector3.new(-math.cos(a), 0, -math.sin(a))), Color = Color3.fromRGB(70, 60, 55), Material = Enum.Material.Wood })
    end
    local lumiere = invisible({ Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(ZONE_AFK + Vector3.new(0, 14, 0)), CanCollide = false })
    creer("PointLight", { Color = Color3.fromRGB(150, 200, 255), Range = 30, Brightness = 2, Parent = lumiere })
    local enseigne = bloc({ Size = Vector3.new(16, 4, 0.4), CFrame = tournee(ZONE_AFK + Vector3.new(0, 9, -15), Vector3.new(0, 0, 1)), Color = Color3.fromRGB(12, 12, 16) })
    panneau(enseigne, "AFK ZONE · FREE AURA", Color3.fromRGB(150, 200, 255), 30)
end

-- ---------- LA TOUR DE PARKOUR (nord-ouest) ----------
local SOMMET_PARKOUR
do
    local centre = L + Vector3.new(-62, 0, -84)
    bloc({ Name = "Pilier", Size = Vector3.new(6, 64, 6), CFrame = CFrame.new(centre + Vector3.new(0, 32, 0)), Color = Color3.fromRGB(24, 24, 28), Material = Enum.Material.Concrete })
    local NB = 26
    for k = 1, NB do
        local a = k * 0.55
        local taille = if k > 18 then 3.6 elseif k > 10 then 4.2 else 5
        local position = centre + Vector3.new(math.cos(a) * 12, k * 2.6, math.sin(a) * 12)
        bloc({ Name = "Marche" .. k, Size = Vector3.new(taille, 1, taille), CFrame = CFrame.new(position), Color = Color3.fromRGB(36, 36, 42) })
        neon({ Size = Vector3.new(taille + 0.1, 0.12, taille + 0.1), CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)), Color = PERSOS[ORDRE_PERSOS[k % 4 + 1]].couleur, Transparency = 0.35 })
    end
    local hautTour = centre + Vector3.new(0, NB * 2.6 + 3, 0)
    SOMMET_PARKOUR = bloc({ Name = "SommetParkour", Size = Vector3.new(12, 1, 12), CFrame = CFrame.new(hautTour), Color = Color3.fromRGB(30, 26, 14) })
    neon({ Size = Vector3.new(12.2, 0.15, 12.2), CFrame = CFrame.new(hautTour + Vector3.new(0, 0.55, 0)), Color = OR })
    local trophee = neon({ Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), CFrame = CFrame.new(hautTour + Vector3.new(0, 3, 0)), Color = OR })
    creer("PointLight", { Color = OR, Range = 30, Brightness = 3, Parent = trophee })
    local enseigne = bloc({ Size = Vector3.new(12, 3, 0.4), CFrame = tournee(centre + Vector3.new(0, 4, 16), Vector3.new(0, 0, 1)), Color = Color3.fromRGB(12, 12, 16) })
    panneau(enseigne, "PARKOUR · +" .. CONFIG.AURA_PARKOUR .. " AURA", OR, 30)
end

-- ---------- LES GRADINS, L'ÉCRAN GÉANT ET LA PORTE DE L'ARÈNE (sud) ----------
local PORTE = L + Vector3.new(0, 0, 108) -- le centre de la porte
do
    for _, cote in ipairs({ -1, 1 }) do
        for marche = 0, 3 do
            bloc({
                Name = "Gradin",
                Size = Vector3.new(70, 1.5 + marche * 1.5, 4),
                CFrame = CFrame.new(L + Vector3.new(cote * 55, (1.5 + marche * 1.5) / 2, 94 - marche * 4)),
                Color = Color3.fromRGB(34 + marche * 4, 34 + marche * 4, 40 + marche * 4),
            })
        end
    end
    local ecran = bloc({ Name = "EcranGeant", Size = Vector3.new(64, 24, 1), CFrame = tournee(L + Vector3.new(0, 34, 112), Vector3.new(0, 0, -1)), Color = Color3.fromRGB(6, 6, 8) })
    neon({ Size = Vector3.new(65, 25, 0.2), CFrame = CFrame.new(L + Vector3.new(0, 34, 112.7)), Color = Color3.fromRGB(235, 235, 245), Transparency = 0.6 })
    creer("PointLight", { Color = Color3.fromRGB(230, 230, 240), Range = 30, Brightness = 1, Parent = ecran })
    -- la porte : deux piliers, un fronton et une « membrane » qu'on traverse
    for _, x in ipairs({ -12, 12 }) do
        bloc({ Size = Vector3.new(3, 20, 3), CFrame = CFrame.new(PORTE + Vector3.new(x, 10, 0)), Color = Color3.fromRGB(16, 16, 20) })
        neon({ Size = Vector3.new(0.4, 20, 3.2), CFrame = CFrame.new(PORTE + Vector3.new(x - 1.6 * math.sign(x), 10, 0)), Color = Color3.fromRGB(255, 70, 70) })
    end
    local fronton = bloc({ Name = "Fronton", Size = Vector3.new(27, 4, 3), CFrame = tournee(PORTE + Vector3.new(0, 20, 0), Vector3.new(0, 0, -1)), Color = Color3.fromRGB(16, 16, 20) })
    panneau(fronton, "ENTER THE ARENA", Color3.fromRGB(255, 90, 90), 25)
    bloc({ Name = "Porte", Size = Vector3.new(21, 18, 0.5), CFrame = CFrame.new(PORTE + Vector3.new(0, 9, 0)), Material = Enum.Material.ForceField, Color = Color3.fromRGB(255, 60, 60), CanCollide = false, CanQuery = false })
end

-- ---------- L'ARÈNE ----------
local APPARITIONS_ARENE = {}
local SORTIE = A + Vector3.new(0, 0, -(RAYON_ARENE - 10)) -- le pad de sortie (côté lobby)
do
    local function blocArene(proprietes)
        proprietes.Parent = dossierArene
        return bloc(proprietes)
    end
    local function neonArene(proprietes)
        proprietes.Parent = dossierArene
        return neon(proprietes)
    end
    cylindre(A - Vector3.new(0, 2, 0), RAYON_ARENE * 2, 4, { Name = "SolArene", Color = Color3.fromRGB(16, 16, 18), Material = Enum.Material.Concrete, Parent = dossierArene })
    -- la grille blanche au sol (look noir et blanc)
    for d = -80, 80, 20 do
        local longueur = 2 * math.sqrt(RAYON_ARENE ^ 2 - d ^ 2) - 4
        neonArene({ Size = Vector3.new(0.25, 0.06, longueur), CFrame = CFrame.new(A + Vector3.new(d, 0.04, 0)), Color = Color3.fromRGB(200, 200, 210), Transparency = 0.6 })
        neonArene({ Size = Vector3.new(longueur, 0.06, 0.25), CFrame = CFrame.new(A + Vector3.new(0, 0.04, d)), Color = Color3.fromRGB(200, 200, 210), Transparency = 0.6 })
    end
    -- l'anneau du bord, aux 4 couleurs, et les murs invisibles
    for i = 0, 79 do
        local a = i / 80 * math.pi * 2
        local position = A + Vector3.new(math.cos(a) * RAYON_ARENE, 0.5, math.sin(a) * RAYON_ARENE)
        local tangente = Vector3.new(-math.sin(a), 0, math.cos(a))
        neonArene({ Size = Vector3.new(0.8, 1, 2 * math.pi * RAYON_ARENE / 80 * 1.05), CFrame = tournee(position, tangente), Color = PERSOS[ORDRE_PERSOS[i // 20 + 1]].couleur })
        if i % 2 == 0 then
            local mur = blocArene({ Name = "MurInvisible", Size = Vector3.new(2, 100, 2 * math.pi * RAYON_ARENE / 40 * 1.1), CFrame = tournee(position + Vector3.new(0, 50, 0), tangente) })
            mur.Transparency = 1
            mur.CastShadow = false
        end
    end
    -- 8 piliers (pour se cacher)
    for k = 0, 7 do
        local a = k / 8 * math.pi * 2 + math.pi / 8
        local position = A + Vector3.new(math.cos(a) * 58, 14, math.sin(a) * 58)
        blocArene({ Name = "Pilier", Size = Vector3.new(7, 28, 7), CFrame = CFrame.new(position), Color = Color3.fromRGB(44, 44, 50), Material = Enum.Material.Concrete })
        neonArene({ Size = Vector3.new(7.2, 0.4, 7.2), CFrame = CFrame.new(position + Vector3.new(0, 14, 0)), Color = PERSOS[ORDRE_PERSOS[k % 4 + 1]].couleur })
        local lumiere = neonArene({ Size = Vector3.new(0.3, 20, 0.3), CFrame = CFrame.new(position + Vector3.new(0, 0, 0) + (A - position).Unit * 3.6 * Vector3.new(1, 0, 1)), Color = Color3.fromRGB(235, 235, 245) })
        creer("PointLight", { Color = Color3.fromRGB(230, 230, 240), Range = 26, Brightness = 1.4, Parent = lumiere })
    end
    -- la plateforme du centre + 4 rampes
    cylindre(A + Vector3.new(0, 1.5, 0), 34, 3, { Name = "Centre", Color = Color3.fromRGB(28, 28, 32), Material = Enum.Material.Concrete, Parent = dossierArene })
    cylindre(A + Vector3.new(0, 3.05, 0), 34.4, 0.1, { Color = Color3.fromRGB(235, 235, 245), Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.5, Parent = dossierArene })
    for k = 0, 3 do
        local a = k / 4 * math.pi * 2
        local direction = Vector3.new(math.cos(a), 0, math.sin(a))
        local position = A + direction * 21 + Vector3.new(0, 1.5, 0)
        creer("WedgePart", {
            Name = "Rampe",
            Anchored = true,
            Size = Vector3.new(10, 3, 8),
            CFrame = CFrame.lookAt(position, position + direction), -- le bas de la rampe vers l'extérieur
            Color = Color3.fromRGB(28, 28, 32),
            Material = Enum.Material.Concrete,
            Parent = dossierArene,
        })
    end
    -- quelques caisses
    for k, infos in ipairs({ { 34, 0.4 }, { 38, 1.9 }, { 30, 3.3 }, { 40, 4.6 }, { 33, 5.6 } }) do
        local position = A + Vector3.new(math.cos(infos[2]) * infos[1], 3, math.sin(infos[2]) * infos[1])
        blocArene({ Name = "Caisse", Size = Vector3.new(6, 6, 6), CFrame = CFrame.new(position) * CFrame.Angles(0, k, 0), Color = Color3.fromRGB(60, 56, 50), Material = Enum.Material.WoodPlanks })
    end
    -- les points d'apparition (au bord)
    for k = 0, 9 do
        local a = k / 10 * math.pi * 2
        table.insert(APPARITIONS_ARENE, A + Vector3.new(math.cos(a) * 80, 3, math.sin(a) * 80))
    end
    -- le pad de SORTIE (retour au lobby)
    cylindre(SORTIE + Vector3.new(0, 0.1, 0), 10, 0.2, { Name = "Sortie", Color = Color3.fromRGB(110, 230, 160), Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.3, Parent = dossierArene })
    local enseigne = blocArene({ Size = Vector3.new(10, 2.5, 0.4), CFrame = tournee(SORTIE + Vector3.new(0, 6, -6), Vector3.new(0, 0, 1)), Color = Color3.fromRGB(12, 12, 16) })
    panneau(enseigne, "EXIT", Color3.fromRGB(110, 230, 160), 30)
end


-- ========================== LE COMBAT ==========================
-- Chaque combattant (joueur ou bot) a une fiche « c » : son avatar, son état d'esprit, ses recharges, sa garde,
-- son énergie (MOTIVATION), ses crans (OBSESSION), sa jauge d'ultime, sa série de kills...
-- Le serveur décide de tout (qui touche qui, combien de dégâts). Les clients affichent (animations, effets).
-- Ce que les clients doivent voir est recopié en attributs sur l'avatar :
--   Combattant, Perso, Nom, Arene, Energie (0-1), Crans, CransMax, Jauge (0-100), Garde, Etourdi (heure serveur),
--   Ult (heure serveur de fin), Serie, AFK
local combattants = {}      -- [modele] = c
local listeModeles = {}     -- les avatars des combattants (pour les zones de coups)
local joueursCombattants = {} -- [joueur] = c

local function maintenant()
    return os.clock()
end
local function heureServeur()
    return workspace:GetServerTimeNow()
end

local function attribut(modele, nom, valeur)
    if modele:GetAttribute(nom) ~= valeur then
        modele:SetAttribute(nom, valeur)
    end
end

local function majListeModeles()
    listeModeles = {}
    for modele in pairs(combattants) do
        table.insert(listeModeles, modele)
    end
end

-- la valeur de la compétence n° numero (ou nil si pas achetée)
local function competence(c, numero)
    local niveaux = if c.joueur then niveauxJoueurs[c.joueur] else c.niveaux -- (un achat compte tout de suite)
    local niveau = niveaux and niveaux[c.perso] and niveaux[c.perso][numero] or 0
    local def = COMPETENCES[c.perso] and COMPETENCES[c.perso][numero]
    if not def or niveau <= 0 then
        return nil
    end
    return def.valeurs[math.min(niveau, #def.valeurs)]
end

local function pvMax(c)
    return CONFIG.PV[c.perso] + (if c.perso == "Ego" then competence(c, 1) or 0 else 0)
end

local function vivant(c)
    return c and combattants[c.modele] == c and c.humanoid.Health > 0 and c.racine.Parent ~= nil
end

local function crankMax(c)
    return 20 + (if c.perso == "Obsession" then competence(c, 1) or 0 else 0)
end

-- donne de l'aura (DISCIPLINE « HARD WORK » : bonus en %)
local function donnerAura(c, montant)
    local joueur = c.joueur
    if not joueur or montant <= 0 then
        return
    end
    local bonus = if c.perso == "Discipline" then competence(c, 3) else nil
    if bonus then
        local total = montant * (1 + bonus / 100)
        montant = math.floor(total) + (if math.random() < total % 1 then 1 else 0)
    end
    ajouterStat(joueur, "Aura", montant)
end

local function animer(c, nom, extra)
    AnimEvent:FireAllClients(c.modele, nom, extra)
end

local function enUlt(c)
    return heureServeur() < c.ultFin
end

-- ne peut pas être étourdi : DISCIPLINE en ultime, OBSESSION au max de crans ou en ultime, armure de ROUTINE
local function inarretable(c)
    if c.perso == "Discipline" and enUlt(c) then
        return true
    end
    if c.perso == "Obsession" and (enUlt(c) or c.crans >= crankMax(c)) then
        return true
    end
    return maintenant() < c.armureJusqua
end

local function etourdir(c, duree)
    if duree <= 0 or inarretable(c) then
        return
    end
    local fin = maintenant() + duree
    if fin > c.etourdiJusqua then
        c.etourdiJusqua = fin
        c.modele:SetAttribute("Etourdi", heureServeur() + duree)
    end
    c.garde = false
    attribut(c.modele, "Garde", false)
end

-- le recul : un joueur bouge son propre avatar (on lui envoie la poussée), un bot est poussé ici
local function reculer(c, depuis, force, haut)
    if (force or 0) <= 0 and (haut or 0) <= 0 then
        return
    end
    if inarretable(c) then
        force, haut = (force or 0) * 0.25, 0
    end
    local direction = (c.racine.Position - depuis) * Vector3.new(1, 0, 1)
    direction = if direction.Magnitude > 0.01 then direction.Unit else c.racine.CFrame.LookVector * -1
    local vitesse = direction * (force or 0) + Vector3.new(0, haut or 0, 0)
    if c.joueur then
        CoupEvent:FireClient(c.joueur, vitesse)
    else
        c.racine.AssemblyLinearVelocity = vitesse
    end
end

local function multiplicateurDegats(c)
    local m = 1
    if c.perso == "Motivation" then
        m *= 0.8 + 0.6 * c.energie -- x1,4 à pleine énergie, x0,98 quand elle est éteinte
    elseif c.perso == "Ego" then
        m *= 1.25
    elseif c.perso == "Obsession" then
        m *= 1 + 0.03 * c.crans
    end
    if enUlt(c) and (c.perso == "Motivation" or c.perso == "Ego") then
        m *= 1.5
    end
    return m
end

local declencherContre -- (défini plus bas)
local surMort -- (défini plus bas)

-- 💥 UN COUP : att frappe cible. opts = { degats, etourdi, recul, haut, casseGarde, imparable, lourd, couleur }
-- Renvoie true si le coup a touché (même bloqué).
local function blesser(att, cible, opts)
    if not vivant(att) or not vivant(cible) or att == cible then
        return false
    end
    if not att.arene or not cible.arene then
        return false -- pas de dégâts dans le lobby
    end
    local t = maintenant()
    if t < cible.protegeJusqua then
        return false
    end
    -- un contre (MIRROR de l'EGO, COUNTER de la DISCIPLINE) : c'est l'attaquant qui prend
    if t < cible.contreJusqua and not opts.imparable then
        cible.contreJusqua = 0
        declencherContre(cible, att)
        return false
    end
    local degats = opts.degats * multiplicateurDegats(att)
    local critique = att.perso == "Ego" and enUlt(att)
    -- la garde : de face seulement
    local deFace = (att.racine.Position - cible.racine.Position) * Vector3.new(1, 0, 1)
    deFace = deFace.Magnitude < 0.01 or deFace.Unit:Dot(cible.racine.CFrame.LookVector) > -0.1
    local bloque = false
    if cible.garde and deFace then
        if opts.casseGarde then
            -- garde cassée !
            cible.garde = false
            attribut(cible.modele, "Garde", false)
            etourdir(cible, 1.1)
            animer(cible, "GardeCassee")
            degats *= 0.5
        else
            bloque = true
            degats *= if cible.perso == "Discipline" then 0.1 else 0.2
            local soin = if cible.perso == "Discipline" then competence(cible, 1) else nil -- IRON GUARD
            if soin then
                cible.humanoid.Health = math.min(cible.humanoid.MaxHealth, cible.humanoid.Health + soin)
            end
        end
    end
    if cible.perso == "Discipline" and enUlt(cible) then
        degats *= 0.3
    end
    degats = math.max(1, math.floor(degats + 0.5))
    if not bloque then
        etourdir(cible, opts.etourdi or 0.35)
        reculer(cible, att.racine.Position, opts.recul or 4, opts.haut or 0)
    else
        reculer(cible, att.racine.Position, 6, 0)
    end
    cible.humanoid:TakeDamage(degats)
    cible.dernierAttaquant = att
    cible.dernierCoup = t
    att.dernierCoupDonne = t
    cible.degatsRecus += degats
    att.degatsVie += degats
    -- la jauge d'ultime se remplit en frappant (et un peu en se faisant frapper)
    if not enUlt(att) then
        local bonus = if att.perso == "Ego" then 1 + (competence(att, 3) or 0) / 100 else 1
        att.jauge = math.min(100, att.jauge + degats * 0.9 * bonus)
    end
    if not enUlt(cible) then
        cible.jauge = math.min(100, cible.jauge + degats * 0.45)
    end
    -- OBSESSION : chaque coup qui touche = un cran de plus ; BLOODLUST / ultime = vol de vie
    if att.perso == "Obsession" and not bloque then
        att.crans = math.min(crankMax(att), att.crans + 1)
        local vol = (competence(att, 3) or 0) / 100 + (if enUlt(att) then 0.3 else 0)
        if vol > 0 then
            att.humanoid.Health = math.min(att.humanoid.MaxHealth, att.humanoid.Health + degats * vol)
        end
    end
    -- l'aura gagnée en frappant
    att.auraDegats += degats
    while att.auraDegats >= CONFIG.AURA_DEGATS do
        att.auraDegats -= CONFIG.AURA_DEGATS
        donnerAura(att, 1)
    end
    local point = cible.racine.Position + (att.racine.Position - cible.racine.Position) * 0.25 + Vector3.new(0, 1, 0)
    ImpactEvent:FireAllClients(cible.modele, point, degats, bloque, att.modele, opts.lourd or critique, critique)
    return true
end

-- les combattants dans une boîte devant c (taille, à « distance » studs devant lui)
local function ciblesDevant(c, taille, distance)
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = listeModeles
    local cf = c.racine.CFrame * CFrame.new(0, 0, -distance)
    local vus, liste = {}, {}
    for _, part in ipairs(workspace:GetPartBoundsInBox(cf, taille, params)) do
        local modele = part:FindFirstAncestorOfClass("Model")
        while modele and not combattants[modele] do
            modele = modele.Parent and modele.Parent:FindFirstAncestorOfClass("Model")
        end
        local cible = modele and combattants[modele]
        if cible and cible ~= c and not vus[cible] then
            vus[cible] = true
            table.insert(liste, cible)
        end
    end
    return liste
end

local function ciblesAutour(c, rayon)
    local liste = {}
    for _, cible in pairs(combattants) do
        if cible ~= c and vivant(cible) and (cible.racine.Position - c.racine.Position).Magnitude <= rayon then
            table.insert(liste, cible)
        end
    end
    return liste
end

-- l'ennemi le plus proche (dans l'arène, vivant, pas protégé)
local function plusProche(c, distanceMax)
    local meilleur, meilleureDistance = nil, distanceMax or math.huge
    for _, cible in pairs(combattants) do
        if cible ~= c and cible.arene and vivant(cible) and maintenant() >= cible.protegeJusqua then
            local d = (cible.racine.Position - c.racine.Position).Magnitude
            if d < meilleureDistance then
                meilleur, meilleureDistance = cible, d
            end
        end
    end
    return meilleur, meilleureDistance
end

-- un contre réussi : le contreur frappe l'attaquant
declencherContre = function(contreur, att)
    local miroir = contreur.contreType == "miroir"
    animer(contreur, if miroir then "MiroirReussi" else "ContreReussi")
    contreur.armureJusqua = maintenant() + 0.4
    task.delay(0.05, function()
        if vivant(contreur) and vivant(att) then
            contreur.contreJusqua = 0
            blesser(contreur, att, {
                degats = if miroir then 11 else 14,
                etourdi = if miroir then 1.0 else 1.3,
                recul = 40,
                haut = 12,
                imparable = true,
                casseGarde = true,
                lourd = true,
            })
        end
    end)
end

-- petit élan vers l'avant (les bots ; les joueurs le font eux-mêmes, tout de suite)
local function elan(c, vitesse, haut)
    if not c.joueur then
        local v = c.racine.CFrame.LookVector * vitesse
        c.racine.AssemblyLinearVelocity = Vector3.new(v.X, haut or c.racine.AssemblyLinearVelocity.Y, v.Z)
    end
end

-- peut agir ? (vivant, pas étourdi, pas déjà en train d'attaquer)
local function pret(c)
    local t = maintenant()
    return vivant(c) and t >= c.etourdiJusqua and t >= c.attaqueJusqua
end

local function enRecharge(c, nom)
    return (c.recharges[nom] or 0) > maintenant()
end

local function recharger(c, nom, duree)
    c.recharges[nom] = maintenant() + duree
end

-- 👊 LES COUPS DE BASE : un combo de 4 (le 4e envoie valser)
local function coupDeBase(c)
    local t = maintenant()
    local frenesie = t < c.frenesieJusqua
    if not pret(c) or c.garde or t - c.dernierM1 < (if frenesie then 0.2 else 0.3) then
        return
    end
    if t - c.dernierM1 > 1.2 then
        c.combo = 0
    end
    c.combo = c.combo % 4 + 1
    c.dernierM1 = t
    local fin = c.combo == 4
    c.attaqueJusqua = t + (if fin then 0.55 elseif frenesie then 0.12 else 0.2)
    animer(c, "M" .. c.combo)
    elan(c, if fin then 18 else 8)
    task.delay(0.1, function()
        if not vivant(c) then
            return
        end
        for _, cible in ipairs(ciblesDevant(c, Vector3.new(6, 6, 6.5), 3.3)) do
            blesser(c, cible, {
                degats = if fin then 9 else 5,
                etourdi = if fin then 0.75 else 0.45,
                recul = if fin then 55 else 5,
                haut = if fin then 16 else 0,
                lourd = fin,
            })
        end
    end)
end

local function garder(c, actif)
    if actif and (not pret(c)) then
        return
    end
    c.garde = actif == true
    attribut(c.modele, "Garde", c.garde)
end


-- ========================== LES CAPACITÉS (touches 1, 2, 3) ==========================
-- Chaque capacité : une fonction qui reçoit le combattant. Les recharges sont dans KITS (en haut).
local function frapperApres(c, delai, taille, distance, opts)
    task.delay(delai, function()
        if vivant(c) then
            for _, cible in ipairs(ciblesDevant(c, taille, distance)) do
                blesser(c, cible, opts)
            end
        end
    end)
end

local function frapperAutourApres(c, delai, rayon, opts)
    task.delay(delai, function()
        if vivant(c) then
            for _, cible in ipairs(ciblesAutour(c, rayon)) do
                blesser(c, cible, opts)
            end
            ImpactEvent:FireAllClients(nil, c.racine.Position - Vector3.new(0, 2.5, 0), 0, false, c.modele, true, false, rayon)
        end
    end)
end

local CAPACITES = {
    Motivation = {
        -- RUSH : on fonce, poing en feu
        function(c)
            local bonus = 1 + (competence(c, 2) or 0) / 100
            c.attaqueJusqua = maintenant() + 0.4
            animer(c, "Rush")
            elan(c, 75)
            frapperApres(c, 0.18, Vector3.new(7, 6, 9), 4, { degats = 11 * bonus, etourdi = 0.7, recul = 45, haut = 12, lourd = true })
        end,
        -- FIRE FISTS : 5 coups très rapides
        function(c)
            local bonus = 1 + (competence(c, 2) or 0) / 100
            c.attaqueJusqua = maintenant() + 0.8
            animer(c, "Rafale")
            for k = 1, 5 do
                frapperApres(c, 0.06 + k * 0.12, Vector3.new(6, 6, 6.5), 3.3, {
                    degats = 3.2 * bonus,
                    etourdi = 0.35,
                    recul = if k == 5 then 40 else 3,
                    haut = if k == 5 then 10 else 0,
                    lourd = k == 5,
                })
            end
        end,
        -- SECOND WIND : l'énergie revient
        function(c)
            c.energie = math.min(1, c.energie + 0.4)
            animer(c, "Cri")
        end,
    },
    Ego = {
        -- SHOWTIME : l'uppercut qui envoie en l'air
        function(c)
            local bonus = 1 + (competence(c, 2) or 0) / 100
            c.attaqueJusqua = maintenant() + 0.45
            animer(c, "Uppercut")
            frapperApres(c, 0.16, Vector3.new(6, 7, 6.5), 3.3, { degats = 10 * bonus, etourdi = 1.0, recul = 6, haut = 62, lourd = true })
        end,
        -- SPOTLIGHT SLAM : il saute et retombe sur tout le monde (casse les gardes)
        function(c)
            local bonus = 1 + (competence(c, 2) or 0) / 100
            c.attaqueJusqua = maintenant() + 0.75
            animer(c, "Slam")
            elan(c, 10, 55)
            frapperAutourApres(c, 0.6, 12, { degats = 12 * bonus, etourdi = 0.8, recul = 45, haut = 24, casseGarde = true, lourd = true })
        end,
        -- MIRROR : posture de contre (le prochain coup reçu est renvoyé)
        function(c)
            c.contreJusqua = maintenant() + 1.0
            c.contreType = "miroir"
            c.attaqueJusqua = maintenant() + 0.3
            animer(c, "Miroir")
        end,
    },
    Discipline = {
        -- COUNTER : parade (punit la prochaine attaque)
        function(c)
            c.contreJusqua = maintenant() + 0.65
            c.contreType = "contre"
            c.attaqueJusqua = maintenant() + 0.3
            animer(c, "Contre")
        end,
        -- ROUTINE : 3 coups lourds, rien ne l'arrête
        function(c)
            local bonus = 1 + (competence(c, 2) or 0) / 100
            c.armureJusqua = maintenant() + 1.1
            c.attaqueJusqua = maintenant() + 1.0
            animer(c, "Routine")
            for k, delai in ipairs({ 0.2, 0.5, 0.85 }) do
                frapperApres(c, delai, Vector3.new(6.5, 6, 7), 3.5, {
                    degats = 7 * bonus,
                    etourdi = 0.55,
                    recul = if k == 3 then 50 else 6,
                    haut = if k == 3 then 12 else 0,
                    casseGarde = k == 3,
                    lourd = k == 3,
                })
            end
        end,
        -- WALL : une onde de choc qui repousse tout le monde
        function(c)
            c.attaqueJusqua = maintenant() + 0.45
            animer(c, "Onde")
            frapperAutourApres(c, 0.22, 14, { degats = 8, etourdi = 0.5, recul = 75, haut = 14, lourd = true })
        end,
    },
    Obsession = {
        -- HUNT : il apparaît derrière l'ennemi le plus proche et frappe
        function(c)
            local cible = plusProche(c, 45)
            if not cible then
                return false -- personne à chasser : pas de recharge
            end
            local derriere = cible.racine.CFrame * CFrame.new(0, 0, 3.2)
            c.modele:PivotTo(CFrame.lookAt(derriere.Position, cible.racine.Position))
            c.attaqueJusqua = maintenant() + 0.35
            animer(c, "Traque", cible.modele)
            frapperApres(c, 0.14, Vector3.new(6, 6, 6.5), 3, { degats = 8, etourdi = 0.7, recul = 20, haut = 6, imparable = true })
        end,
        -- RELENTLESS : il attrape et frappe 3 fois
        function(c)
            c.attaqueJusqua = maintenant() + 0.95
            animer(c, "Saisie")
            task.delay(0.15, function()
                if not vivant(c) then
                    return
                end
                local cible = ciblesDevant(c, Vector3.new(6, 6, 6.5), 3.3)[1]
                if not cible or not blesser(c, cible, { degats = 4, etourdi = 1.1, recul = 0, casseGarde = true }) then
                    return
                end
                for k, delai in ipairs({ 0.2, 0.4, 0.6 }) do
                    task.delay(delai, function()
                        if vivant(c) and vivant(cible) then
                            blesser(c, cible, { degats = 5, etourdi = 0.5, recul = if k == 3 then 45 else 0, haut = if k == 3 then 12 else 0, imparable = true, lourd = k == 3 })
                        end
                    end)
                end
            end)
        end,
        -- FRENZY : 5 secondes de coups beaucoup plus rapides
        function(c)
            c.frenesieJusqua = maintenant() + 5
            animer(c, "Cri")
        end,
    },
}

local function rechargeDe(c, numero)
    local def = KITS[c.perso] and KITS[c.perso][numero]
    local duree = def and def.recharge or 8
    if c.perso == "Obsession" and numero == 1 then
        duree *= 1 - (competence(c, 2) or 0) / 100 -- PREDATOR
    end
    return duree
end

local function utiliserCapacite(c, numero)
    if type(numero) ~= "number" or not CAPACITES[c.perso] or not CAPACITES[c.perso][numero] then
        return
    end
    local nom = "C" .. numero
    if not pret(c) or c.garde or enRecharge(c, nom) then
        return
    end
    local resultat = CAPACITES[c.perso][numero](c)
    if resultat ~= false then
        recharger(c, nom, rechargeDe(c, numero))
        if c.joueur then
            c.modele:SetAttribute("Recharge" .. numero, heureServeur() + rechargeDe(c, numero))
        end
    end
end

-- ⚡ L'ULTIME (G) : jauge pleine → 8 s de pouvoir + l'edit noir et blanc chez tout le monde autour
local function ultime(c)
    if not vivant(c) or c.jauge < 100 or enUlt(c) or maintenant() < c.etourdiJusqua then
        return
    end
    c.jauge = 0
    c.ultFin = heureServeur() + 8
    c.modele:SetAttribute("Ult", c.ultFin)
    c.protegeJusqua = maintenant() + 1.2 -- le temps de l'edit
    c.attaqueJusqua = maintenant() + 1.0
    if c.perso == "Motivation" then
        c.energie = 1
    elseif c.perso == "Obsession" then
        c.crans = crankMax(c)
    end
    animer(c, "Ultime")
    UltEvent:FireAllClients(c.modele, c.perso)
end

-- 😏 PROVOQUER (T) : l'EGO charge son ultime en frimant
local function provoquer(c)
    if not pret(c) or enRecharge(c, "Provoc") then
        return
    end
    recharger(c, "Provoc", 6)
    c.attaqueJusqua = maintenant() + 1.2
    animer(c, "Provoc")
    if c.arene and not enUlt(c) then
        c.jauge = math.min(100, c.jauge + (if c.perso == "Ego" then 12 else 4))
    end
end

-- ce que les joueurs envoient
ActionEvent.OnServerEvent:Connect(function(joueur, action, valeur)
    local c = joueursCombattants[joueur]
    if not c or not vivant(c) then
        return
    end
    if action == "M1" then
        coupDeBase(c)
    elseif action == "Garde" then
        garder(c, valeur == true)
    elseif action == "Esquive" then
        if not enRecharge(c, "Esquive") and maintenant() >= c.etourdiJusqua then
            recharger(c, "Esquive", 1.6)
            c.protegeJusqua = math.max(c.protegeJusqua, maintenant() + 0.22) -- un petit instant intouchable
            animer(c, "Esquive", valeur)
        end
    elseif action == "Capacite" then
        utiliserCapacite(c, valeur)
    elseif action == "Ultime" then
        ultime(c)
    elseif action == "Provoc" then
        provoquer(c)
    end
end)


-- ========================== LES COMBATTANTS : naissance, mort ==========================
local function nouveauCombattant(modele, joueur, perso)
    local humanoid = modele:WaitForChild("Humanoid", 10)
    local racine = modele:WaitForChild("HumanoidRootPart", 10)
    if not humanoid or not racine then
        return nil
    end
    local t = maintenant()
    local c = {
        modele = modele, humanoid = humanoid, racine = racine, joueur = joueur,
        perso = if PERSOS[perso] then perso else auHasard(ORDRE_PERSOS),
        nom = if joueur then joueur.DisplayName else modele.Name,
        niveaux = nil, recharges = {}, combo = 0, dernierM1 = 0, attaqueJusqua = 0,
        garde = false, etourdiJusqua = 0, contreJusqua = 0, contreType = nil, armureJusqua = 0, frenesieJusqua = 0,
        ultFin = 0, crans = 0, energie = 1, jauge = 0,
        arene = false, protegeJusqua = 0, entreeArene = t, naissance = t,
        serie = 0, killsVie = 0, degatsVie = 0, degatsRecus = 0, auraDegats = 0,
        dernierAttaquant = nil, dernierCoup = 0, dernierCoupDonne = 0,
        afk = false, afkDepuis = t,
    }
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- le client affiche sa propre étiquette
    humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    humanoid.UseJumpPower = false
    humanoid.JumpHeight = 7.2
    -- pas de régénération automatique des PV (comme dans les vrais battlegrounds)
    local regen = modele:FindFirstChild("Health")
    if regen and regen:IsA("Script") then
        regen:Destroy()
    end
    humanoid.MaxHealth = pvMax(c)
    humanoid.Health = humanoid.MaxHealth
    for nom, valeur in pairs({
        Combattant = true, Perso = c.perso, Nom = c.nom, Arene = false, Energie = 1, Crans = 0, CransMax = crankMax(c),
        Jauge = 0, Garde = false, Etourdi = 0, Ult = 0, Serie = 0, AFK = false, Bot = joueur == nil,
    }) do
        modele:SetAttribute(nom, valeur)
    end
    combattants[modele] = c
    majListeModeles()
    humanoid.Died:Connect(function()
        surMort(c)
    end)
    return c
end

-- changer d'état d'esprit (seulement au lobby)
local function changerPerso(c, perso)
    c.perso = perso
    c.crans, c.energie, c.recharges = 0, 1, {}
    c.humanoid.MaxHealth = pvMax(c)
    c.humanoid.Health = c.humanoid.MaxHealth
    attribut(c.modele, "Perso", perso)
    attribut(c.modele, "CransMax", crankMax(c))
    for numero = 1, 3 do
        c.modele:SetAttribute("Recharge" .. numero, nil)
    end
end

-- la place de départ la plus éloignée des autres combattants
local function apparitionArene(c)
    local meilleur, meilleurScore = APPARITIONS_ARENE[1], -1
    for _, point in ipairs(APPARITIONS_ARENE) do
        local plusPres = math.huge
        for _, autre in pairs(combattants) do
            if autre ~= c and autre.arene and vivant(autre) then
                plusPres = math.min(plusPres, (autre.racine.Position - point).Magnitude)
            end
        end
        plusPres += math.random() * 10
        if plusPres > meilleurScore then
            meilleur, meilleurScore = point, plusPres
        end
    end
    return CFrame.lookAt(meilleur, Vector3.new(A.X, meilleur.Y, A.Z))
end

local function entrerArene(c)
    c.modele:PivotTo(apparitionArene(c))
    c.racine.AssemblyLinearVelocity = Vector3.zero
    c.arene = true
    c.protegeJusqua = maintenant() + CONFIG.PROTECTION
    c.entreeArene = maintenant()
    c.humanoid.Health = c.humanoid.MaxHealth
    c.energie, c.crans = 1, 0
    c.afk = false
    attribut(c.modele, "AFK", false)
    attribut(c.modele, "Arene", true)
    if c.joueur then
        ZoneEvent:FireClient(c.joueur, "Arene")
    end
end

local function sortirArene(c)
    local position = PORTE + Vector3.new((math.random() - 0.5) * 10, 3, -14)
    c.modele:PivotTo(CFrame.lookAt(position, position - Vector3.new(0, 0, 1)))
    c.racine.AssemblyLinearVelocity = Vector3.zero
    c.arene = false
    c.garde = false
    c.ultFin = 0
    attribut(c.modele, "Ult", 0)
    attribut(c.modele, "Garde", false)
    c.humanoid.Health = c.humanoid.MaxHealth
    attribut(c.modele, "Arene", false)
    if c.joueur then
        ZoneEvent:FireClient(c.joueur, "Lobby")
    end
end

-- 💀 UNE MORT : le dernier qui l'a frappé (il y a moins de 10 s) a le kill
surMort = function(c)
    if combattants[c.modele] ~= c then
        return
    end
    local t = maintenant()
    combattants[c.modele] = nil
    majListeModeles()
    if c.joueur and joueursCombattants[c.joueur] == c then
        joueursCombattants[c.joueur] = nil
    end
    if not c.arene then
        return -- (un « Réinitialiser » au lobby : rien à annoncer)
    end
    local tueur = c.dernierAttaquant
    if tueur and (t - c.dernierCoup > 10 or not vivant(tueur)) then
        tueur = nil
    end
    if tueur then
        tueur.serie += 1
        tueur.killsVie += 1
        attribut(tueur.modele, "Serie", tueur.serie)
        tueur.humanoid.Health = math.min(tueur.humanoid.MaxHealth, tueur.humanoid.Health + CONFIG.SOIN_KILL)
        if tueur.perso == "Motivation" then
            tueur.energie = math.min(1, tueur.energie + 0.3 * (1 + (competence(tueur, 3) or 0) / 100)) -- COMEBACK
        end
        if not enUlt(tueur) then
            tueur.jauge = math.min(100, tueur.jauge + 15)
        end
        local joueurTueur = tueur.joueur
        if joueurTueur then
            ajouterStat(joueurTueur, "Kills", 1)
            local streak = chercherStat(joueurTueur, "Streak")
            if streak then
                streak.Value = tueur.serie
            end
            donnerAura(tueur, CONFIG.AURA_KILL)
            local meilleure = chercherStat(joueurTueur, "MeilleureSerie")
            if meilleure and tueur.serie > meilleure.Value then
                meilleure.Value = tueur.serie
                joueurTueur:SetAttribute("Record", tueur.serie)
                task.spawn(enregistrerRecord, "S", joueurTueur, tueur.serie)
            end
            local kills = chercherStat(joueurTueur, "Kills")
            if kills then
                task.spawn(enregistrerRecord, "K", joueurTueur, kills.Value)
            end
        end
    end
    KillEvent:FireAllClients({
        tueur = tueur and tueur.nom,
        tueurPerso = tueur and tueur.perso,
        tueurModele = tueur and tueur.modele,
        victime = c.nom,
        victimePerso = c.perso,
        victimeModele = c.modele,
        serie = if tueur then tueur.serie else 0,
    })
    if c.joueur then
        local streak = chercherStat(c.joueur, "Streak")
        if streak then
            streak.Value = 0
        end
        FinEvent:FireClient(c.joueur, {
            tueur = tueur and tueur.nom,
            tueurPerso = tueur and tueur.perso,
            perso = c.perso,
            kills = c.killsVie,
            degats = math.floor(c.degatsVie),
            survie = math.floor(t - c.naissance),
            reapparition = CONFIG.REAPPARITION,
        })
    else
        task.delay(3, function()
            if c.modele then
                c.modele:Destroy()
            end
        end)
    end
end

-- ========================== LES JOUEURS ==========================
local parkourFait = {} -- [joueur] = true (le parkour ne donne son aura qu'une fois par serveur)

local function joueurArrive(joueur)
    arrivees[joueur] = os.clock()
    local stats = Instance.new("Folder")
    stats.Name = "leaderstats"
    creer("IntValue", { Name = "Kills", Parent = stats })
    creer("IntValue", { Name = "Streak", Parent = stats })
    stats.Parent = joueur
    local cachees = creer("Folder", { Name = "StatsCachees", Parent = joueur })
    creer("IntValue", { Name = "Aura", Parent = cachees })
    creer("IntValue", { Name = "Secondes", Parent = cachees })
    creer("IntValue", { Name = "MeilleureSerie", Parent = cachees })
    task.spawn(chargerJoueur, joueur)

    local function surPersonnage(personnage)
        if not joueur:GetAttribute("Perso") then
            joueur:SetAttribute("Perso", auHasard(ORDRE_PERSOS))
        end
        local c = nouveauCombattant(personnage, joueur, joueur:GetAttribute("Perso"))
        if not c then
            return
        end
        joueursCombattants[joueur] = c
        -- on apparaît au lobby (zone sans danger)
        local position = APPARITION + Vector3.new((math.random() - 0.5) * 10, 0, (math.random() - 0.5) * 10)
        personnage:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, 1)))
        c.humanoid.WalkSpeed = CONFIG.VITESSE_LOBBY
        ZoneEvent:FireClient(joueur, "Lobby")
    end
    joueur.CharacterAdded:Connect(surPersonnage)
    if joueur.Character then
        task.spawn(surPersonnage, joueur.Character)
    end
end

-- les données sont chargées : on applique l'état d'esprit sauvegardé (si on est au lobby) et on publie son total de kills
surChargement = function(joueur)
    local c = joueursCombattants[joueur]
    local perso = joueur:GetAttribute("Perso")
    if c and perso and c.perso ~= perso and not c.arene then
        changerPerso(c, perso)
    end
    local kills = chercherStat(joueur, "Kills")
    if kills and kills.Value > 0 then
        task.spawn(enregistrerRecord, "K", joueur, kills.Value)
    end
end

Players.PlayerRemoving:Connect(function(joueur)
    sauverJoueur(joueur)
    local c = joueursCombattants[joueur]
    if c then
        combattants[c.modele] = nil
        majListeModeles()
    end
    joueursCombattants[joueur] = nil
    donneesChargees[joueur] = nil
    reglagesJoueurs[joueur] = nil
    niveauxJoueurs[joueur] = nil
    chargementFini[joueur] = nil
    arrivees[joueur] = nil
    achatEnCours[joueur] = nil
    parkourFait[joueur] = nil
end)

-- les SANCTUAIRES : bouton E → on devient cet état d'esprit
for perso, socle in pairs(sanctuaires) do
    socle:WaitForChild("Choisir").Triggered:Connect(function(joueur)
        local c = joueursCombattants[joueur]
        if not c or c.arene then
            return
        end
        joueur:SetAttribute("Perso", perso)
        changerPerso(c, perso)
        MessageEvent:FireClient(joueur, "Choisi", perso)
    end)
end

-- 🗺️ LES ZONES (4 fois par seconde) : la porte de l'arène, la sortie, la zone AFK, le haut du parkour, les chutes
local function surveillerZones()
    local t = maintenant()
    for joueur, c in pairs(joueursCombattants) do
        if not vivant(c) then
            continue
        end
        local p = c.racine.Position
        if not c.arene then
            local d = p - PORTE
            if math.abs(d.X) < 10.5 and math.abs(d.Z) < 3 and d.Y < 18 then
                entrerArene(c)
                continue
            end
            -- la zone AFK : de l'aura toutes les 30 s
            local dansAfk = ((p - ZONE_AFK) * Vector3.new(1, 0, 1)).Magnitude < 14 and math.abs(p.Y - ZONE_AFK.Y) < 8
            if dansAfk ~= c.afk then
                c.afk = dansAfk
                c.afkDepuis = t
                attribut(c.modele, "AFK", dansAfk)
            elseif dansAfk and t - c.afkDepuis >= 30 then
                c.afkDepuis = t
                donnerAura(c, CONFIG.AURA_AFK)
                MessageEvent:FireClient(joueur, "AFK", CONFIG.AURA_AFK)
            end
            -- le haut de la tour de parkour
            local s = p - SOMMET_PARKOUR.Position
            if not parkourFait[joueur] and math.abs(s.X) < 6.5 and math.abs(s.Z) < 6.5 and s.Y > 0 and s.Y < 7 then
                parkourFait[joueur] = true
                donnerAura(c, CONFIG.AURA_PARKOUR)
                MessageEvent:FireClient(joueur, "Parkour", CONFIG.AURA_PARKOUR)
            end
            if p.Y < L.Y - 40 then
                c.modele:PivotTo(CFrame.new(APPARITION))
            end
        else
            local s = p - SORTIE
            if (s * Vector3.new(1, 0, 1)).Magnitude < 5 and math.abs(s.Y) < 6 and t - c.entreeArene > 2 then
                if t - c.dernierCoup > 4 and t - c.dernierCoupDonne > 4 then
                    sortirArene(c)
                elseif t - (c.messageSortie or 0) > 2 then
                    c.messageSortie = t
                    MessageEvent:FireClient(joueur, "SortieCombat")
                end
            end
            if p.Y < A.Y - 40 then
                c.modele:PivotTo(apparitionArene(c))
            end
        end
    end
end


-- ========================== LES BOTS ==========================
-- Il y a toujours de l'action dans l'arène : des bots complètent jusqu'à CONFIG.BOTS combattants.
-- Ils foncent sur l'ennemi le plus proche, enchaînent les coups, bloquent parfois, utilisent leurs capacités et leur ultime.
local dossierBots = creer("Folder", { Name = "MindsetBots", Parent = workspace })
local PEAUX = {
    Color3.fromRGB(255, 224, 189), Color3.fromRGB(255, 205, 148), Color3.fromRGB(234, 192, 134),
    Color3.fromRGB(198, 134, 66), Color3.fromRGB(141, 85, 36), Color3.fromRGB(90, 56, 37),
}
local PRENOMS = { "Lucas", "Emma", "Noah", "Lina", "Adam", "Jade", "Nathan", "Mia", "Enzo", "Chloe", "Sacha", "Ines", "Leo", "Zoe", "Hugo", "Lea", "Max", "Sara" }
local MOTS = { "Gamer", "Pro", "Speed", "Dark", "Shadow", "King", "Queen", "Ninja", "Flash", "Sigma", "Turbo", "Dragon", "Wolf", "Blox", "Star" }
local ANIMS_BOT = {
    course = "rbxassetid://913376220", -- les animations R15 de base de Roblox
    attente = "rbxassetid://507766388",
    saut = "rbxassetid://507765000",
    chute = "rbxassetid://507767968",
}

local function pseudoDeBot()
    local style = math.random(1, 4)
    if style == 1 then
        return auHasard(PRENOMS) .. "_" .. auHasard(MOTS) .. math.random(1, 99)
    elseif style == 2 then
        return "xX" .. auHasard(MOTS) .. auHasard(PRENOMS) .. "Xx"
    elseif style == 3 then
        return string.lower(auHasard(PRENOMS)) .. math.random(2008, 2016)
    end
    return auHasard(MOTS) .. auHasard(MOTS) .. math.random(100, 999)
end

local function animerBot(modele)
    local humanoid = modele:FindFirstChildOfClass("Humanoid")
    local animator = humanoid:FindFirstChildOfClass("Animator") or creer("Animator", { Parent = humanoid })
    local pistes = {}
    for nom, id in pairs(ANIMS_BOT) do
        local animation = Instance.new("Animation")
        animation.AnimationId = id
        local ok, piste = pcall(function()
            return animator:LoadAnimation(animation)
        end)
        if ok and piste then
            piste.Looped = nom ~= "saut"
            pistes[nom] = piste
        end
    end
    if pistes.attente then
        pistes.attente:Play()
    end
    humanoid.Running:Connect(function(vitesse)
        local course = pistes.course
        if not course then
            return
        end
        if vitesse > 1 then
            if not course.IsPlaying then
                course:Play(0.15)
            end
            course:AdjustSpeed(math.clamp(vitesse / 16, 0.6, 2))
        elseif course.IsPlaying then
            course:Stop(0.2)
        end
    end)
    humanoid.StateChanged:Connect(function(_, nouvel)
        if nouvel == Enum.HumanoidStateType.Jumping and pistes.saut then
            pistes.saut:Play(0.1)
        elseif nouvel == Enum.HumanoidStateType.Freefall and pistes.chute then
            pistes.chute:Play(0.2)
        elseif nouvel == Enum.HumanoidStateType.Landed and pistes.chute then
            pistes.chute:Stop(0.15)
        end
    end)
end

-- l'état d'esprit le moins représenté dans l'arène (pour avoir les 4 en même temps)
local function persoPourBot()
    local comptes = {}
    for _, perso in ipairs(ORDRE_PERSOS) do
        comptes[perso] = math.random() * 0.5
    end
    for _, c in pairs(combattants) do
        if c.arene then
            comptes[c.perso] += 1
        end
    end
    local meilleur, minimum = ORDRE_PERSOS[1], math.huge
    for perso, n in pairs(comptes) do
        if n < minimum then
            meilleur, minimum = perso, n
        end
    end
    return meilleur
end

local function nouveauBot()
    local perso = persoPourBot()
    local ok, modele = pcall(function()
        local description = Instance.new("HumanoidDescription")
        local peau = auHasard(PEAUX)
        local habit = PERSOS[perso].couleur
        description.HeadColor = peau
        description.TorsoColor = habit
        description.LeftArmColor = if math.random() < 0.5 then peau else habit
        description.RightArmColor = description.LeftArmColor
        description.LeftLegColor = Color3.fromRGB(28, 28, 32)
        description.RightLegColor = Color3.fromRGB(28, 28, 32)
        return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
    end)
    if not ok or not modele then
        warn("🤖 Impossible de créer un bot :", modele)
        return
    end
    local pseudo = pseudoDeBot()
    modele.Name = pseudo
    for _, objet in ipairs(modele:GetDescendants()) do
        if objet:IsA("Script") or objet:IsA("LocalScript") then
            objet:Destroy()
        end
    end
    modele:PivotTo(apparitionArene(nil))
    modele.Parent = dossierBots
    local c = nouveauCombattant(modele, nil, perso)
    if not c then
        modele:Destroy()
        return
    end
    c.nom = pseudo
    attribut(modele, "Nom", pseudo)
    c.niveaux = { [perso] = { math.random(0, 3), math.random(0, 3), math.random(0, 3) } }
    c.humanoid.MaxHealth = pvMax(c)
    c.humanoid.Health = c.humanoid.MaxHealth
    c.ia = {
        garde = 0.2 + math.random() * 0.35,      -- chance de bloquer quand on l'attaque
        finGarde = 0,
        prochaineCapacite = maintenant() + 2 + math.random() * 3,
        prochainePromenade = 0,
        reflexe = 0.05 + math.random() * 0.15,   -- temps de réaction
    }
    animerBot(modele)
    pcall(function()
        c.racine:SetNetworkOwner(nil)
    end)
    entrerArene(c)
end

local function piloterBot(c)
    if not vivant(c) then
        return
    end
    local t = maintenant()
    local ia = c.ia
    if t < c.etourdiJusqua then
        return
    end
    local cible, distance = plusProche(c, 400)
    local p = c.racine.Position
    if not cible then
        if c.garde then
            garder(c, false)
        end
        if t > ia.prochainePromenade then
            ia.prochainePromenade = t + 3
            c.humanoid:MoveTo(A + Vector3.new((math.random() - 0.5) * 100, 0, (math.random() - 0.5) * 100))
        end
        return
    end
    local q = cible.racine.Position
    local face = Vector3.new(q.X, p.Y, q.Z)
    -- en garde : on attend un peu
    if c.garde then
        if t > ia.finGarde then
            garder(c, false)
        else
            c.humanoid:MoveTo(p)
            if (face - p).Magnitude > 0.1 then
                c.racine.CFrame = CFrame.lookAt(p, face)
            end
            return
        end
    end
    -- l'ennemi attaque tout près : parfois on bloque
    if distance < 8 and t < cible.attaqueJusqua and math.random() < ia.garde * 0.6 then
        garder(c, true)
        ia.finGarde = t + 0.45 + math.random() * 0.45
        return
    end
    if c.jauge >= 100 and distance < 16 then
        ultime(c)
        return
    end
    if t > ia.prochaineCapacite and distance < 11 then
        ia.prochaineCapacite = t + 2.5 + math.random() * 3.5
        if (face - p).Magnitude > 0.1 then
            c.racine.CFrame = CFrame.lookAt(p, face)
        end
        utiliserCapacite(c, math.random(1, 3))
        return
    end
    if distance > 4.3 then
        c.humanoid:MoveTo(q + (p - q).Unit * 2.5)
        if distance > 14 and distance < 32 and math.random() < 0.03 then
            elan(c, 60) -- un dash vers l'ennemi
        end
    else
        c.humanoid:MoveTo(p)
        if (face - p).Magnitude > 0.1 then
            c.racine.CFrame = CFrame.lookAt(p, face)
        end
        if math.random() > ia.reflexe then
            coupDeBase(c)
        end
    end
end

-- le bon nombre de bots : CONFIG.BOTS combattants dans l'arène (au moins CONFIG.BOTS_MIN bots)
local function equilibrerBots()
    local joueursDansArene, bots = 0, {}
    for _, c in pairs(combattants) do
        if c.arene and vivant(c) then
            if c.joueur then
                joueursDansArene += 1
            else
                table.insert(bots, c)
            end
        end
    end
    local voulu = math.max(CONFIG.BOTS_MIN, CONFIG.BOTS - joueursDansArene)
    if #bots < voulu then
        task.spawn(nouveauBot)
    elseif #bots > voulu then
        -- on enlève un bot qui n'est pas en plein combat
        for _, c in ipairs(bots) do
            if maintenant() - c.dernierCoup > 6 and maintenant() - c.dernierCoupDonne > 6 then
                combattants[c.modele] = nil
                majListeModeles()
                c.modele:Destroy()
                break
            end
        end
    end
end


-- ========================== LES BOUCLES ==========================
-- 10 fois par seconde : vitesse de chacun (selon son état d'esprit), énergie de la MOTIVATION,
-- et les attributs que les clients affichent (énergie, crans, jauge...).
local function majCombattant(c, dt)
    local t = maintenant()
    if c.perso == "Motivation" and c.arene then
        if enUlt(c) then
            c.energie = 1
        else
            local duree = 55 * (1 + (competence(c, 1) or 0) / 100) -- SLOW BURN
            c.energie = math.max(0.3, c.energie - dt / duree)
        end
    end
    local vitesse
    if not c.arene then
        vitesse = CONFIG.VITESSE_LOBBY
    elseif c.perso == "Motivation" then
        vitesse = 15 + 9 * c.energie
        if enUlt(c) then
            vitesse *= 1.25
        end
    elseif c.perso == "Ego" then
        vitesse = 18
    elseif c.perso == "Discipline" then
        vitesse = 17
    else
        vitesse = 14 + 0.35 * c.crans
    end
    if c.garde then
        vitesse = math.min(vitesse, 7)
    end
    if t < c.attaqueJusqua then
        vitesse *= 0.5
    end
    local etourdi = t < c.etourdiJusqua
    if etourdi then
        vitesse = 2
    end
    if math.abs(c.humanoid.WalkSpeed - vitesse) > 0.05 then
        c.humanoid.WalkSpeed = vitesse
    end
    local saut = if etourdi or c.garde then 0 elseif c.perso == "Ego" then 8.5 else 7.2
    if c.humanoid.JumpHeight ~= saut then
        c.humanoid.JumpHeight = saut
    end
    attribut(c.modele, "Energie", math.floor(c.energie * 100 + 0.5) / 100)
    attribut(c.modele, "Crans", c.crans)
    attribut(c.modele, "Jauge", math.floor(c.jauge))
    if not enUlt(c) and (c.modele:GetAttribute("Ult") or 0) > 0 then
        attribut(c.modele, "Ult", 0)
    end
end

task.spawn(function()
    local dernier = os.clock()
    local prochainesZones, prochainsBots, prochainEquilibre = 0, 0, 0
    while true do
        task.wait(0.1)
        local t = os.clock()
        local dt = t - dernier
        dernier = t
        for _, c in pairs(combattants) do
            if vivant(c) then
                majCombattant(c, dt)
            end
        end
        if t >= prochainesZones then
            prochainesZones = t + 0.25
            surveillerZones()
        end
        if t >= prochainsBots then
            prochainsBots = t + 0.15
            for _, c in pairs(combattants) do
                if not c.joueur then
                    piloterBot(c)
                end
            end
        end
        if t >= prochainEquilibre then
            prochainEquilibre = t + 2
            equilibrerBots()
        end
    end
end)

Players.PlayerAdded:Connect(joueurArrive)
for _, joueur in ipairs(Players:GetPlayers()) do
    task.spawn(joueurArrive, joueur)
end

