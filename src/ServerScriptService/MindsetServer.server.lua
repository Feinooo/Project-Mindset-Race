--[[
    🌍 MINDSET SIMULATOR — Script SERVEUR
    À mettre dans : ServerScriptService  (type : Script, nom : MindsetServer)

    Un open world de FARM sur la trend Motivation vs Ego vs Discipline vs Obsession.
      - Au centre : la VILLE (sans danger) avec le marchand d'aura, les 4 sanctuaires des états d'esprit,
        l'autel de renaissance, les tableaux TOP 10 et une zone AFK.
      - Autour : 4 ZONES (une par état d'esprit), reliées à la ville par des ponts. On débloque la suivante avec l'aura.
          MOTIVATION (nord, gratuite) → DISCIPLINE (est) → EGO (sud) → OBSESSION (ouest)
      - Dans chaque zone : des CRISTAUX à casser à coups de poing → de l'AURA. Plus la zone est loin, plus ça rapporte.
      - De temps en temps une PENSÉE GÉANTE (boss) apparaît dans une zone : tout le monde tape dessus.
      - L'aura achète des améliorations (force, vitesse de frappe, bonus d'aura, vitesse de marche)
        et les états d'esprit (chacun a un bonus de farm).
      - RENAISSANCE : tu perds ton aura et tes améliorations, mais tu gagnes un bonus pour toujours.
      - Les gros moments (zone débloquée, renaissance, boss cassé) passent en EDIT NOIR ET BLANC (script client).
    Ce script construit toute la carte, gère les cristaux, l'aura, les achats, la sauvegarde et les classements.
    (les anciens jeux sont gardés dans les tags git v1-course, v2-rythme, v3-escalier3d, v4-battlegrounds)
]]

-- ===================== RÉGLAGES (tu peux les modifier) =====================
local CONFIG = {
    VITESSE_BASE = 18,      -- vitesse de marche de départ (16 = la vitesse normale de Roblox)
    PORTEE = 9,             -- distance (en studs) pour frapper un cristal
    CRISTAUX_PAR_ZONE = 22, -- nombre de cristaux en même temps dans chaque zone
    REAPPARITION_CRISTAL = 1.2, -- un nouveau cristal toutes les ... secondes (par zone, s'il en manque)

    -- 💎 LES CRISTAUX : pv = coups qu'il faut (multiplié par la zone), aura = ce qu'ils rapportent (multiplié par la zone)
    TYPES = {
        { nom = "SMALL", pv = 8, aura = 3, taille = 3, poids = 62 },
        { nom = "MEDIUM", pv = 35, aura = 15, taille = 5, poids = 29 },
        { nom = "BIG", pv = 140, aura = 70, taille = 8, poids = 9 },
    },

    -- 👑 LA PENSÉE GÉANTE (boss) : apparaît toutes les « intervalle » secondes dans une zone où il y a du monde
    BOSS = { intervalle = 150, duree = 120, pv = 5000, aura = 4000, taille = 16 },

    -- 🔁 la série de DISCIPLINE : chaque cristal cassé d'affilée (sans pause de plus de « delai » s) = + « bonus »
    SERIE_DELAI = 8,
    SERIE_BONUS = 0.02,
    SERIE_MAX = 1, -- +100 % au maximum

    -- ♻️ RENAISSANCE : prix = prixBase × croissance ^ (nombre de renaissances)
    RENAISSANCE = { prixBase = 250000, croissance = 4, bonusAura = 0.5, bonusDegats = 0.25 },

    AURA_AFK = 5,          -- dans la zone AFK : 5 × (multiplicateur de ta meilleure zone) toutes les 30 secondes
    AURA_CADEAU_STUDIO = 5000, -- en Studio seulement : de l'aura pour tester les achats

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
}

-- 🗺️ LES ZONES (dans l'ordre où on les débloque)
--   prix = aura pour la débloquer · aura = multiplicateur d'aura des cristaux · pv = multiplicateur de leurs PV
--   direction = de quel côté de la ville elle est
-- ⚠️ Si tu changes un titre ou une phrase, change aussi sa traduction (script client, partie LANGUE).
local ZONES = {
    { nom = "Motivation", titre = "SUNRISE VALLEY", prix = 0, aura = 1, pv = 1, direction = Vector3.new(0, 0, -1),
        phrase = "MOTIVATION gets you started." },
    { nom = "Discipline", titre = "IRON DOJO", prix = 2500, aura = 8, pv = 10, direction = Vector3.new(1, 0, 0),
        phrase = "DISCIPLINE keeps you going." },
    { nom = "Ego", titre = "GOLDEN STAGE", prix = 60000, aura = 70, pv = 90, direction = Vector3.new(0, 0, 1),
        phrase = "EGO wants everyone to watch." },
    { nom = "Obsession", titre = "RED ABYSS", prix = 1500000, aura = 600, pv = 800, direction = Vector3.new(-1, 0, 0),
        phrase = "OBSESSION makes you unstoppable." },
}

-- 🧠 LES ÉTATS D'ESPRIT : chacun a un bonus de farm. On les achète dans les sanctuaires de la ville.
local PERSOS = {
    Motivation = { prix = 0, couleur = Color3.fromRGB(255, 150, 30), devise = "Fast start. Then it fades.",
        passif = { nom = "FAST START", texte = "Your first hit on every crystal deals x3 damage." } },
    Discipline = { prix = 3000, couleur = Color3.fromRGB(60, 140, 255), devise = "Steady. Every day.",
        passif = { nom = "ROUTINE", texte = "Every crystal you break in a row gives +2% aura (up to +100%). Stop for 8 s and it resets." } },
    Ego = { prix = 40000, couleur = Color3.fromRGB(170, 80, 255), devise = "Main character. Glass jaw.",
        passif = { nom = "MAIN CHARACTER", texte = "x2 aura from crystals, but -25% damage. Crown when you're the richest on the server." } },
    Obsession = { prix = 400000, couleur = Color3.fromRGB(230, 40, 60), devise = "Slow start. Unstoppable end.",
        passif = { nom = "FIXATION", texte = "Every hit on the same crystal deals +15% damage (up to x4)." } },
}
local ORDRE_PERSOS = { "Motivation", "Discipline", "Ego", "Obsession" }

-- 🛒 LES AMÉLIORATIONS du marchand : prix du niveau n = prixBase × croissance ^ n
local AMELIORATIONS = {
    { cle = "Force", nom = "POWER", texte = "Damage per hit", max = 80, prixBase = 15, croissance = 1.32 },
    { cle = "Rapidite", nom = "PUNCH SPEED", texte = "Punches per second", max = 12, prixBase = 120, croissance = 2.1 },
    { cle = "Aimant", nom = "AURA BOOST", texte = "Bonus aura", max = 30, prixBase = 60, croissance = 1.55 },
    { cle = "Jambes", nom = "WALK SPEED", texte = "Walk speed", max = 10, prixBase = 100, croissance = 1.9 },
}
-- ce que donne chaque niveau
local function valeurAmelioration(cle, n)
    if cle == "Force" then
        return 1 + n + math.floor(1.17 ^ n)
    elseif cle == "Rapidite" then
        return 0.5 * 0.9 ^ n -- secondes entre 2 coups
    elseif cle == "Aimant" then
        return 10 * n -- % d'aura en plus
    else
        return CONFIG.VITESSE_BASE + 2 * n
    end
end
-- ===========================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local OR = Color3.fromRGB(255, 220, 80)
local BLANC = Color3.new(1, 1, 1)

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

-- 1234567 → « 1.23M »
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc" }
local function court(n)
    n = math.floor(n or 0)
    if n < 1000 then
        return tostring(n)
    end
    local i, x = 1, n
    while x >= 1000 and i < #SUFFIXES do
        x /= 1000
        i += 1
    end
    local s
    if x >= 100 then
        s = tostring(math.floor(x))
    elseif x >= 10 then
        s = string.format("%.1f", math.floor(x * 10) / 10)
    else
        s = string.format("%.2f", math.floor(x * 100) / 100)
    end
    if string.find(s, "%.") then
        s = string.gsub(s, "0+$", "")
        s = string.gsub(s, "%.$", "")
    end
    return s .. SUFFIXES[i]
end

local function prixAmelioration(def, n)
    return math.floor(def.prixBase * def.croissance ^ n)
end
local function prixRenaissance(n)
    return math.floor(CONFIG.RENAISSANCE.prixBase * CONFIG.RENAISSANCE.croissance ^ n)
end

local ZONE_PAR_NOM, AMELIO_PAR_CLE = {}, {}
for i, zone in ipairs(ZONES) do
    zone.index = i
    ZONE_PAR_NOM[zone.nom] = zone
    zone.couleur = PERSOS[zone.nom].couleur
end
for _, def in ipairs(AMELIORATIONS) do
    AMELIO_PAR_CLE[def.cle] = def
end

-- ========================== COMMUNICATION ==========================
for _, nom in ipairs({ "MindsetRemotes", "MindsetCarte" }) do
    local vieux = ReplicatedStorage:FindFirstChild(nom)
    if vieux then
        vieux:Destroy()
    end
end
local dossierRemotes = creer("Folder", { Name = "MindsetRemotes", Parent = ReplicatedStorage })
local function remote(nom, estFonction)
    return creer(if estFonction then "RemoteFunction" else "RemoteEvent", { Name = nom, Parent = dossierRemotes })
end
local FrapperEvent = remote("Frapper")       -- client → serveur : je frappe ce cristal
local ImpactEvent = remote("Impact")         -- serveur → clients : un cristal a pris un coup
local CasseEvent = remote("Casse")           -- serveur → clients : un cristal est cassé (+ ton aura gagnée)
local EvenementEvent = remote("Evenement")   -- serveur → clients : zone débloquée, renaissance, boss...
local MessageEvent = remote("Message")       -- serveur → client : petit message en haut
local ReglagesEvent = remote("Reglages")     -- client → serveur : les paramètres du joueur
local AcheterFonction = remote("Acheter", true) -- client → serveur : acheter (amélioration, zone, état d'esprit, renaissance)

-- tout ce que le client doit savoir (prix, textes...) est publié ici en JSON
do
    local function rgb(c)
        return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
    end
    local zones = {}
    for i, zone in ipairs(ZONES) do
        zones[i] = { nom = zone.nom, titre = zone.titre, prix = zone.prix, aura = zone.aura, phrase = zone.phrase, couleur = rgb(zone.couleur) }
    end
    local persos = {}
    for nom, p in pairs(PERSOS) do
        persos[nom] = { prix = p.prix, couleur = rgb(p.couleur), devise = p.devise, passif = p.passif }
    end
    local amelios = {}
    for i, def in ipairs(AMELIORATIONS) do
        local valeurs, prix = {}, {}
        for n = 0, def.max do
            valeurs[n + 1] = valeurAmelioration(def.cle, n)
            prix[n + 1] = prixAmelioration(def, n)
        end
        amelios[i] = { cle = def.cle, nom = def.nom, texte = def.texte, max = def.max, valeurs = valeurs, prix = prix }
    end
    ReplicatedStorage:SetAttribute("Config", HttpService:JSONEncode({
        zones = zones,
        persos = persos,
        ordrePersos = ORDRE_PERSOS,
        ameliorations = amelios,
        renaissance = CONFIG.RENAISSANCE,
        portee = CONFIG.PORTEE,
        serie = { delai = CONFIG.SERIE_DELAI, bonus = CONFIG.SERIE_BONUS, max = CONFIG.SERIE_MAX },
    }))
    local musiques = {}
    for _, m in ipairs(CONFIG.MUSIQUES) do
        if m.id ~= "" then
            table.insert(musiques, { id = m.id, nom = m.nom })
        end
    end
    ReplicatedStorage:SetAttribute("Musiques", HttpService:JSONEncode(musiques))
end

-- ========================== LUMIÈRE ==========================
-- fin d'après-midi, un peu contrasté (le script client change l'ambiance selon la zone où tu es)
Lighting.ClockTime = 15
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(120, 120, 130)
Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 140)
Lighting.EnvironmentDiffuseScale = 0.5
Lighting.EnvironmentSpecularScale = 0.6
Lighting.GlobalShadows = true
for _, nom in ipairs({ "MindsetBloom", "MindsetStyle", "MindsetAtmo" }) do
    local vieux = Lighting:FindFirstChild(nom)
    if vieux then
        vieux:Destroy()
    end
end
creer("BloomEffect", { Name = "MindsetBloom", Intensity = 0.8, Size = 24, Threshold = 0.95, Parent = Lighting })
creer("ColorCorrectionEffect", { Name = "MindsetStyle", Saturation = -0.1, Contrast = 0.12, Brightness = 0.01, Parent = Lighting })
creer("Atmosphere", { Name = "MindsetAtmo", Density = 0.28, Offset = 0.2, Color = Color3.fromRGB(200, 200, 215), Decay = Color3.fromRGB(110, 110, 130), Glare = 0.3, Haze = 1.2, Parent = Lighting })

-- ========================== SAUVEGARDE (DataStore) ==========================
-- ⚠️ Pour tester dans Studio : publie le jeu, puis
--    Paramètres du jeu > Sécurité > « Activer l'accès Studio aux services API ».
-- (nouvelle sauvegarde pour ce jeu : tout le monde recommence à zéro)
local sauvegarde = nil
do
    local ok, resultat = pcall(function()
        return DataStoreService:GetDataStore("MindsetSim_Joueurs_v1")
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

-- L'état de chaque joueur (le serveur décide de tout)
--   niveaux = { Force = 0, ... } · zones = { Motivation = true, ... } · persos = { Motivation = true, ... }
local etats = {} -- [joueur] = état

local function nouvelEtat()
    local niveaux = {}
    for _, def in ipairs(AMELIORATIONS) do
        niveaux[def.cle] = 0
    end
    return {
        niveaux = niveaux,
        zones = { Motivation = true },
        persos = { Motivation = true },
        perso = "Motivation",
        rebirths = 0,
        serie = 0,
        dernierCasse = 0,
        derniereFrappe = 0,
        reglages = nil,
        charge = false,
        chargeOk = false,
        arrivee = os.clock(),
        tempsAvant = 0,
    }
end

local function stat(joueur, nom)
    for _, dossier in ipairs({ "leaderstats", "StatsCachees" }) do
        local d = joueur:FindFirstChild(dossier)
        local v = d and d:FindFirstChild(nom)
        if v then
            return v
        end
    end
    return nil
end

local function intervalle(e)
    return valeurAmelioration("Rapidite", e.niveaux.Rapidite)
end
local function degats(e)
    local d = valeurAmelioration("Force", e.niveaux.Force) * (1 + CONFIG.RENAISSANCE.bonusDegats * e.rebirths)
    if e.perso == "Ego" then
        d *= 0.75
    end
    return d
end
local function bonusSerie(e)
    if e.perso ~= "Discipline" then
        return 0
    end
    return math.min(CONFIG.SERIE_MAX, e.serie * CONFIG.SERIE_BONUS)
end
local function multAura(e)
    local m = (1 + valeurAmelioration("Aimant", e.niveaux.Aimant) / 100) * (1 + CONFIG.RENAISSANCE.bonusAura * e.rebirths)
    if e.perso == "Ego" then
        m *= 2
    end
    return m * (1 + bonusSerie(e))
end
local function meilleureZone(e)
    local meilleure = ZONES[1]
    for _, zone in ipairs(ZONES) do
        if e.zones[zone.nom] then
            meilleure = zone
        end
    end
    return meilleure
end

local majEtiquette -- (définie plus bas : l'étiquette au-dessus de la tête)

-- les clients lisent tout ça dans les attributs du joueur
local function publier(joueur)
    local e = etats[joueur]
    if not e then
        return
    end
    joueur:SetAttribute("Niveaux", HttpService:JSONEncode(e.niveaux))
    joueur:SetAttribute("Zones", HttpService:JSONEncode(e.zones))
    joueur:SetAttribute("Persos", HttpService:JSONEncode(e.persos))
    joueur:SetAttribute("Perso", e.perso)
    joueur:SetAttribute("Rebirths", e.rebirths)
    joueur:SetAttribute("Degats", math.floor(degats(e)))
    joueur:SetAttribute("Intervalle", intervalle(e))
    joueur:SetAttribute("MultAura", multAura(e))
    joueur:SetAttribute("Serie", e.serie)
    local r = stat(joueur, "Rebirths")
    if r then
        r.Value = e.rebirths
    end
    local humanoid = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = valeurAmelioration("Jambes", e.niveaux.Jambes)
    end
    if majEtiquette then
        majEtiquette(joueur)
    end
end

local function ajouterAura(joueur, n)
    local aura, total = stat(joueur, "Aura"), stat(joueur, "Total")
    if aura and total then
        aura.Value += n
        total.Value += n
    end
end

local function chargerJoueur(joueur)
    local e = etats[joueur]
    local donnees = nil
    if sauvegarde then
        local ok, resultat = essayer(function()
            return sauvegarde:GetAsync("joueur_" .. joueur.UserId)
        end)
        if ok then
            donnees = resultat or {}
            e.chargeOk = true
        else
            warn("💾 Impossible de charger les données de " .. joueur.Name .. " : pas de sauvegarde pour cette partie.")
        end
    end
    if not joueur.Parent then
        return
    end
    if type(donnees) == "table" then
        local function nombre(x)
            return if type(x) == "number" and x == x and x >= 0 then math.floor(x) else 0
        end
        stat(joueur, "Aura").Value = nombre(donnees.aura)
        stat(joueur, "Total").Value = nombre(donnees.total)
        e.rebirths = nombre(donnees.rebirths)
        e.tempsAvant = nombre(donnees.temps)
        if type(donnees.niveaux) == "table" then
            for _, def in ipairs(AMELIORATIONS) do
                e.niveaux[def.cle] = math.clamp(nombre(donnees.niveaux[def.cle]), 0, def.max)
            end
        end
        if type(donnees.zones) == "table" then
            for _, zone in ipairs(ZONES) do
                if donnees.zones[zone.nom] == true then
                    e.zones[zone.nom] = true
                end
            end
        end
        if type(donnees.persos) == "table" then
            for nom in pairs(PERSOS) do
                if donnees.persos[nom] == true then
                    e.persos[nom] = true
                end
            end
        end
        if type(donnees.perso) == "string" and e.persos[donnees.perso] then
            e.perso = donnees.perso
        end
        if type(donnees.reglages) == "table" then
            e.reglages = donnees.reglages
            joueur:SetAttribute("Reglages", HttpService:JSONEncode(donnees.reglages))
        end
    end
    -- 🎁 en Studio : de l'aura pour tester
    local aura = stat(joueur, "Aura")
    if RunService:IsStudio() and aura.Value < CONFIG.AURA_CADEAU_STUDIO then
        aura.Value = CONFIG.AURA_CADEAU_STUDIO
    end
    e.charge = true
    publier(joueur)
end

local publierClassements -- (défini plus bas)

local function sauverJoueur(joueur)
    local e = etats[joueur]
    if not sauvegarde or not e or not e.chargeOk or not stat(joueur, "Aura") then
        return
    end
    local copie = {
        aura = stat(joueur, "Aura").Value,
        total = stat(joueur, "Total").Value,
        rebirths = e.rebirths,
        niveaux = table.clone(e.niveaux),
        zones = table.clone(e.zones),
        persos = table.clone(e.persos),
        perso = e.perso,
        reglages = e.reglages,
        temps = e.tempsAvant + math.floor(os.clock() - e.arrivee),
    }
    essayer(function()
        sauvegarde:UpdateAsync("joueur_" .. joueur.UserId, function(anciennes)
            local donnees = anciennes or {}
            for cle, valeur in pairs(copie) do
                donnees[cle] = valeur
            end
            return donnees
        end)
    end)
    if publierClassements then
        publierClassements(joueur, copie.total, copie.rebirths)
    end
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
    local e = etats[joueur]
    if not e or type(reglages) ~= "table" then
        return
    end
    local function nombre(x)
        return if type(x) == "number" and x == x then math.clamp(x, 0, 1) else 1
    end
    e.reglages = {
        musique = nombre(reglages.musique),
        bruitages = nombre(reglages.bruitages),
        secousses = reglages.secousses ~= false,
        flashs = reglages.flashs ~= false,
        langue = if reglages.langue == "en" or reglages.langue == "fr" then reglages.langue else "auto",
    }
end)

-- ========================== LA CARTE ==========================
-- VILLE : centre C, ronde (rayon RAYON_VILLE), sol à y = 100.
-- ZONES : des îles carrées de 210 × 210, à DISTANCE_ZONE du centre, reliées à la ville par un pont.
-- Le client trouve les endroits par leur nom : Porte_<Zone> (dossier Portes), et les ProximityPrompt
-- qui ont un attribut « Action » (Boutique, Persos, Renaissance, Porte).
local C = Vector3.new(0, 100, 0)
local RAYON_VILLE = 95
local DISTANCE_ZONE = 340
local DEMI_ZONE = 105
local ZONE_CRISTAUX = 72 -- les cristaux apparaissent à moins de 72 studs du centre de la zone
local APPARITION = C + Vector3.new(0, 4, 24)

for _, nom in ipairs({ "MindsetMap", "MindsetCristaux" }) do
    local vieux = workspace:FindFirstChild(nom)
    if vieux then
        vieux:Destroy()
    end
end
local dossierCarte = creer("Folder", { Name = "MindsetMap", Parent = workspace })
local dossierVille = creer("Folder", { Name = "Ville", Parent = dossierCarte })
local dossierPortes = creer("Folder", { Name = "Portes", Parent = dossierCarte })
local dossierCristaux = creer("Folder", { Name = "MindsetCristaux", Parent = workspace })

local function bloc(proprietes)
    proprietes.Anchored = true
    proprietes.TopSurface = Enum.SurfaceType.Smooth
    proprietes.BottomSurface = Enum.SurfaceType.Smooth
    proprietes.Material = proprietes.Material or Enum.Material.SmoothPlastic
    proprietes.Parent = proprietes.Parent or dossierVille
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
    proprietes.CanQuery = false
    return bloc(proprietes)
end
local function cylindre(centre, diametre, hauteur, proprietes)
    proprietes.Shape = Enum.PartType.Cylinder
    proprietes.Size = Vector3.new(hauteur, diametre, diametre)
    proprietes.CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.pi / 2)
    return bloc(proprietes)
end
local function boule(centre, diametre, proprietes)
    proprietes.Shape = Enum.PartType.Ball
    proprietes.Size = Vector3.new(diametre, diametre, diametre)
    proprietes.Position = centre
    return bloc(proprietes)
end
-- un texte sur une face d'une part
local function panneau(part, message, couleur, pixels, face)
    local surface = creer("SurfaceGui", {
        Face = face or Enum.NormalId.Front,
        SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
        PixelsPerStud = pixels or 30,
        LightInfluence = 0,
        Parent = part,
    })
    local label = creer("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBlack,
        TextScaled = true,
        RichText = true,
        Text = message,
        TextColor3 = couleur,
        Parent = surface,
    })
    return surface, label
end
-- une part dont la face avant regarde dans la direction voulue
local function tournee(position, regarde)
    return CFrame.lookAt(position, position + regarde)
end
local function enCouleur(mot, couleur)
    return string.format('<font color="#%02X%02X%02X">%s</font>', math.floor(couleur.R * 255), math.floor(couleur.G * 255), math.floor(couleur.B * 255), mot)
end
-- un bouton « E » ; Action = ce que le client ouvre quand on appuie
local function bouton(parent, actionTexte, objetTexte, action, distance)
    local prompt = creer("ProximityPrompt", {
        ActionText = actionTexte,
        ObjectText = objetTexte,
        KeyboardKeyCode = Enum.KeyCode.E,
        HoldDuration = 0,
        MaxActivationDistance = distance or 12,
        RequiresLineOfSight = false,
        Parent = parent,
    })
    prompt:SetAttribute("Action", action)
    return prompt
end

-- un mur invisible entre deux points (au sol), haut de « hauteur »
local function murEntre(a, b, hauteur, parent)
    local milieu = (a + b) / 2
    local longueur = (b - a).Magnitude
    invisible({
        Name = "Mur",
        Size = Vector3.new(longueur, hauteur, 2),
        CFrame = CFrame.lookAt(milieu + Vector3.new(0, hauteur / 2, 0), milieu + Vector3.new(0, hauteur / 2, 0) + (b - a).Unit)
            * CFrame.Angles(0, math.pi / 2, 0),
        Parent = parent,
    })
end

-- ---------- LA VILLE ----------
do
    local sol = cylindre(C - Vector3.new(0, 2, 0), RAYON_VILLE * 2, 4, { Name = "Sol", Material = Enum.Material.Concrete, Color = Color3.fromRGB(58, 58, 66) })
    sol.CFrame = CFrame.new(C - Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
    cylindre(C + Vector3.new(0, 0.05, 0), 70, 0.2, { Name = "Place", Material = Enum.Material.Slate, Color = Color3.fromRGB(80, 80, 92), CanCollide = false })
    -- les 4 allées vers les ponts, dans la couleur de leur zone
    for _, zone in ipairs(ZONES) do
        local d = zone.direction
        local milieu = C + d * (35 + (RAYON_VILLE - 35) / 2) + Vector3.new(0, 0.1, 0)
        bloc({ Name = "Allee", Size = Vector3.new(20, 0.2, RAYON_VILLE - 35), CFrame = tournee(milieu, d), Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 70, 82), CanCollide = false })
        for _, cote in ipairs({ -1, 1 }) do
            local lateral = Vector3.new(-d.Z, 0, d.X) * 10.5 * cote
            neon({ Name = "Bord", Size = Vector3.new(0.6, 0.25, RAYON_VILLE - 35), CFrame = tournee(milieu + lateral, d), Color = zone.couleur })
        end
    end
    -- le bord de la ville : un anneau de néon + des murs invisibles (sauf devant les ponts)
    local SEGMENTS = 24
    for k = 0, SEGMENTS - 1 do
        local angle = k * 2 * math.pi / SEGMENTS
        local a = C + Vector3.new(math.cos(angle - math.pi / SEGMENTS), 0, math.sin(angle - math.pi / SEGMENTS)) * (RAYON_VILLE - 1)
        local b = C + Vector3.new(math.cos(angle + math.pi / SEGMENTS), 0, math.sin(angle + math.pi / SEGMENTS)) * (RAYON_VILLE - 1)
        local milieu = (a + b) / 2
        local versCentre = (C - milieu).Unit
        neon({ Name = "Anneau", Size = Vector3.new((b - a).Magnitude + 0.5, 0.6, 1), CFrame = CFrame.lookAt(milieu + Vector3.new(0, 0.3, 0), milieu + Vector3.new(0, 0.3, 0) + versCentre), Color = Color3.fromRGB(220, 220, 235) })
        if k % 6 ~= 0 then -- k = 0, 6, 12, 18 : les 4 ponts
            murEntre(a, b, 14, dossierVille)
        end
    end

    -- le monument du centre : un obélisque avec les 4 noms, chacun face à son pont
    local socle = cylindre(C + Vector3.new(0, 1, 0), 16, 2, { Name = "Socle", Material = Enum.Material.Marble, Color = Color3.fromRGB(230, 230, 236) })
    socle.CFrame = CFrame.new(C + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2)
    local obelisque = bloc({ Name = "Obelisque", Size = Vector3.new(7, 34, 7), CFrame = CFrame.new(C + Vector3.new(0, 19, 0)), Material = Enum.Material.Marble, Color = Color3.fromRGB(28, 28, 34) })
    for _, zone in ipairs(ZONES) do
        local face = bloc({ Name = "Face", Size = Vector3.new(6, 26, 0.2), CFrame = tournee(C + Vector3.new(0, 20, 0) + zone.direction * 3.6, zone.direction), Material = Enum.Material.Neon, Color = Color3.fromRGB(18, 18, 22), CanCollide = false })
        local s, label = panneau(face, string.upper(zone.nom), zone.couleur, 20)
        label.Rotation = 0
        s.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
        s.CanvasSize = Vector2.new(60, 260)
        label.Size = UDim2.fromOffset(260, 60)
        label.AnchorPoint = Vector2.new(0.5, 0.5)
        label.Position = UDim2.fromScale(0.5, 0.5)
        label.Rotation = 90
    end
    neon({ Name = "Pointe", Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(C + Vector3.new(0, 37.5, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = OR })
    local anneau = neon({ Name = "Halo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 22, 22), CFrame = CFrame.new(C + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = BLANC, Transparency = 0.6 })
    anneau:SetAttribute("Tourne", true)
    creer("PointLight", { Range = 40, Brightness = 2, Color = OR, Parent = obelisque })

    -- le point d'apparition
    local spawn = creer("SpawnLocation", {
        Name = "MindsetApparition",
        Anchored = true,
        Neutral = true,
        Duration = 0,
        Size = Vector3.new(10, 0.4, 10),
        CFrame = CFrame.new(APPARITION - Vector3.new(0, 3.8, 0)),
        Transparency = 1,
        CanCollide = false,
        CanQuery = false,
        Parent = dossierVille,
    })
    spawn:ClearAllChildren()

    -- 🛒 LE MARCHAND D'AURA (ouest)
    do
        local p = C + Vector3.new(-62, 0, -24)
        local versCentre = (C - p).Unit
        local base = tournee(p, versCentre)
        bloc({ Name = "Comptoir", Size = Vector3.new(16, 4, 4), CFrame = base * CFrame.new(0, 2, -2), Material = Enum.Material.Wood, Color = Color3.fromRGB(90, 60, 40) })
        bloc({ Name = "Toit", Size = Vector3.new(20, 1, 12), CFrame = base * CFrame.new(0, 12, 2), Material = Enum.Material.Fabric, Color = Color3.fromRGB(160, 40, 200) })
        for _, x in ipairs({ -9, 9 }) do
            bloc({ Name = "Poteau", Size = Vector3.new(1, 12, 1), CFrame = base * CFrame.new(x, 6, -3), Material = Enum.Material.Wood, Color = Color3.fromRGB(70, 45, 30) })
        end
        local enseigne = bloc({ Name = "Enseigne", Size = Vector3.new(18, 3, 0.4), CFrame = base * CFrame.new(0, 10, -4.2), Color = Color3.fromRGB(20, 18, 26) })
        panneau(enseigne, "AURA MERCHANT", OR, 30)
        -- le marchand lui-même (une silhouette encapuchonnée)
        bloc({ Name = "Corps", Size = Vector3.new(3, 5, 2), CFrame = base * CFrame.new(0, 6.5, 1), Material = Enum.Material.Fabric, Color = Color3.fromRGB(30, 26, 40) })
        boule(base * CFrame.new(0, 10, 1).Position, 2.4, { Name = "Tete", Material = Enum.Material.Fabric, Color = Color3.fromRGB(30, 26, 40) })
        for _, x in ipairs({ -0.45, 0.45 }) do
            neon({ Name = "Oeil", Size = Vector3.new(0.35, 0.2, 0.1), CFrame = base * CFrame.new(x, 10.1, -0.2), Color = Color3.fromRGB(200, 120, 255) })
        end
        local point = invisible({ Name = "PointMarchand", Size = Vector3.new(2, 2, 2), CFrame = base * CFrame.new(0, 3, -5), CanCollide = false })
        bouton(point, "Shop", "Aura Merchant", "Boutique")
    end

    -- ♻️ L'AUTEL DE RENAISSANCE (est)
    do
        local p = C + Vector3.new(62, 0, -24)
        local versCentre = (C - p).Unit
        local base = tournee(p, versCentre)
        local autel = cylindre(p + Vector3.new(0, 1, 0), 14, 2, { Name = "Autel", Material = Enum.Material.Marble, Color = Color3.fromRGB(235, 235, 240) })
        autel.CFrame = CFrame.new(p + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2)
        neon({ Name = "Cercle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 15, 15), CFrame = CFrame.new(p + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = BLANC })
        local orbe = neon({ Name = "Orbe", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 5, 5), Position = p + Vector3.new(0, 9, 0), Color = BLANC })
        orbe:SetAttribute("Flotte", true)
        creer("PointLight", { Range = 24, Brightness = 3, Color = BLANC, Parent = orbe })
        local enseigne = bloc({ Name = "Enseigne", Size = Vector3.new(14, 2.6, 0.4), CFrame = base * CFrame.new(0, 15, 0), Color = Color3.fromRGB(20, 18, 26), CanCollide = false })
        panneau(enseigne, "REBIRTH", BLANC, 30)
        local point = invisible({ Name = "PointRenaissance", Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(p + Vector3.new(0, 3, 0)), CanCollide = false })
        bouton(point, "Rebirth", "Rebirth Altar", "Renaissance", 14)
    end

    -- 🧠 LES 4 SANCTUAIRES (en diagonale autour du monument)
    for i, nom in ipairs(ORDRE_PERSOS) do
        local perso = PERSOS[nom]
        local angle = math.rad(-135 + (i - 1) * 90)
        local p = C + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 50
        local versCentre = (C - p).Unit
        local base = tournee(p, versCentre)
        local socle2 = cylindre(p + Vector3.new(0, 1.5, 0), 9, 3, { Name = "Socle", Material = Enum.Material.Marble, Color = Color3.fromRGB(225, 225, 232) })
        socle2.CFrame = CFrame.new(p + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2)
        neon({ Name = "Bague", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 9.6, 9.6), CFrame = CFrame.new(p + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = perso.couleur })
        local embleme = neon({ Name = "Embleme", Size = Vector3.new(3.2, 3.2, 3.2), CFrame = CFrame.new(p + Vector3.new(0, 8, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(35)), Color = perso.couleur })
        embleme:SetAttribute("Tourne", true)
        creer("PointLight", { Range = 18, Brightness = 2, Color = perso.couleur, Parent = embleme })
        local plaque = bloc({ Name = "Plaque", Size = Vector3.new(10, 2.2, 0.3), CFrame = base * CFrame.new(0, 12.5, 0), Color = Color3.fromRGB(16, 16, 20), CanCollide = false })
        panneau(plaque, string.upper(nom), perso.couleur, 30)
        local point = invisible({ Name = "Sanctuaire_" .. nom, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(p + Vector3.new(0, 4, 0)), CanCollide = false })
        local prompt = bouton(point, "Mindsets", string.upper(nom), "Persos", 11)
        prompt:SetAttribute("Perso", nom)
    end

    -- 🏆 LES DEUX TABLEAUX TOP 10 (sud)
    for i, info in ipairs({ { nom = "TableauTotal", x = 46 }, { nom = "TableauRebirths", x = -46 } }) do
        local p = C + Vector3.new(info.x, 0, 52)
        local versCentre = Vector3.new(-info.x, 0, -52).Unit
        local base = tournee(p, versCentre)
        bloc({ Name = "Pied", Size = Vector3.new(1.2, 6, 1.2), CFrame = base * CFrame.new(0, 3, 0), Color = Color3.fromRGB(30, 30, 36) })
        local tableau = bloc({ Name = info.nom, Size = Vector3.new(20, 22, 0.6), CFrame = base * CFrame.new(0, 16, 0), Color = Color3.fromRGB(14, 14, 18) })
        neon({ Name = "Cadre", Size = Vector3.new(20.6, 22.6, 0.4), CFrame = base * CFrame.new(0, 16, 0.2), Color = if i == 1 then OR else BLANC })
        local surface = creer("SurfaceGui", { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Vector2.new(500, 550), LightInfluence = 0, Parent = tableau })
        creer("TextLabel", { Name = "Titre", Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 12), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true,
            Text = if i == 1 then "TOP 10 · TOTAL AURA" else "TOP 10 · REBIRTHS", TextColor3 = if i == 1 then OR else BLANC, Parent = surface })
        for rang = 1, 10 do
            creer("TextLabel", {
                Name = "Ligne" .. rang,
                Size = UDim2.new(1, -40, 0, 40),
                Position = UDim2.fromOffset(20, 80 + (rang - 1) * 46),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold,
                TextScaled = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                RichText = true,
                Text = if rang == 1 then "Loading..." else "",
                TextColor3 = Color3.fromRGB(230, 230, 240),
                Parent = surface,
            })
        end
    end

    -- 😴 LA ZONE AFK (sud, sur l'allée de l'Ego)
    do
        local p = C + Vector3.new(0, 0, 62)
        local cercle = neon({ Name = "ZoneAFK", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 18, 18), CFrame = CFrame.new(p + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(110, 230, 160), Transparency = 0.55 })
        cercle:SetAttribute("Pulse", true)
        local plaque = bloc({ Name = "Plaque", Size = Vector3.new(12, 2.4, 0.3), CFrame = tournee(p + Vector3.new(0, 9, 0), Vector3.new(0, 0, -1)), Color = Color3.fromRGB(16, 16, 20), CanCollide = false })
        panneau(plaque, "AFK ZONE", Color3.fromRGB(110, 230, 160), 30)
        panneau(plaque, "AFK ZONE", Color3.fromRGB(110, 230, 160), 30, Enum.NormalId.Back)
    end

    -- des lampadaires autour de la place
    for k = 0, 11 do
        local angle = k * math.pi / 6 + math.pi / 12
        local p = C + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 82
        bloc({ Name = "Lampadaire", Size = Vector3.new(0.8, 12, 0.8), CFrame = CFrame.new(p + Vector3.new(0, 6, 0)), Color = Color3.fromRGB(30, 30, 36), Material = Enum.Material.Metal })
        local lampe = neon({ Name = "Lampe", Size = Vector3.new(2, 1.2, 2), CFrame = CFrame.new(p + Vector3.new(0, 12.4, 0)), Color = Color3.fromRGB(255, 235, 200) })
        creer("PointLight", { Range = 22, Brightness = 1.4, Color = Color3.fromRGB(255, 225, 180), Parent = lampe })
    end
end

-- ---------- LES ZONES ----------
-- le centre de chaque zone (au sol)
for _, zone in ipairs(ZONES) do
    zone.centre = C + zone.direction * DISTANCE_ZONE
end

local THEMES = {
    Motivation = { sol = Enum.Material.Grass, couleurSol = Color3.fromRGB(96, 140, 58), pont = Enum.Material.WoodPlanks, couleurPont = Color3.fromRGB(120, 82, 50) },
    Discipline = { sol = Enum.Material.Slate, couleurSol = Color3.fromRGB(70, 82, 100), pont = Enum.Material.Cobblestone, couleurPont = Color3.fromRGB(95, 100, 110) },
    Ego = { sol = Enum.Material.Marble, couleurSol = Color3.fromRGB(235, 232, 225), pont = Enum.Material.Marble, couleurPont = Color3.fromRGB(215, 200, 160) },
    Obsession = { sol = Enum.Material.Basalt, couleurSol = Color3.fromRGB(30, 24, 26), pont = Enum.Material.Basalt, couleurPont = Color3.fromRGB(45, 30, 32) },
}

-- les décors de chaque zone (posés tout autour, entre 80 et 100 studs du centre, pour laisser la place aux cristaux)
local function decorer(zone, dossier)
    local graine = Random.new(zone.index * 7919)
    local centre = zone.centre
    local function pointAuBord()
        for _ = 1, 20 do
            local x, z = graine:NextNumber(-98, 98), graine:NextNumber(-98, 98)
            local distance = math.max(math.abs(x), math.abs(z))
            -- pas devant l'entrée (côté ville)
            local local3 = Vector3.new(x, 0, z)
            local versVille = -zone.direction
            local devant = local3:Dot(versVille) > 60 and math.abs(local3:Dot(Vector3.new(-versVille.Z, 0, versVille.X))) < 22
            if distance > 80 and not devant then
                return centre + local3
            end
        end
        return centre + Vector3.new(90, 0, 90)
    end
    local function parent(p)
        p.Parent = dossier
        return p
    end
    if zone.nom == "Motivation" then
        -- des arbres d'automne et des torches
        for _ = 1, 26 do
            local p = pointAuBord()
            local h = graine:NextNumber(10, 18)
            parent(bloc({ Name = "Tronc", Size = Vector3.new(1.6, h, 1.6), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)), Material = Enum.Material.Wood, Color = Color3.fromRGB(90, 60, 38) }))
            local teinte = Color3.fromRGB(graine:NextInteger(200, 255), graine:NextInteger(90, 160), 40)
            parent(boule(p + Vector3.new(0, h + 2, 0), graine:NextNumber(8, 12), { Name = "Feuillage", Material = Enum.Material.Grass, Color = teinte }))
            parent(boule(p + Vector3.new(2, h - 1, 1), graine:NextNumber(5, 7), { Name = "Feuillage", Material = Enum.Material.Grass, Color = teinte }))
        end
        for _ = 1, 10 do
            local p = pointAuBord()
            parent(bloc({ Name = "Torche", Size = Vector3.new(0.8, 6, 0.8), CFrame = CFrame.new(p + Vector3.new(0, 3, 0)), Material = Enum.Material.Wood, Color = Color3.fromRGB(70, 45, 30) }))
            local feu = parent(neon({ Name = "Flamme", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(p + Vector3.new(0, 6.5, 0)), Color = Color3.fromRGB(255, 150, 30) }))
            creer("Fire", { Size = 4, Heat = 6, Color = Color3.fromRGB(255, 140, 30), SecondaryColor = Color3.fromRGB(255, 60, 20), Parent = feu })
            creer("PointLight", { Range = 16, Brightness = 2, Color = Color3.fromRGB(255, 160, 60), Parent = feu })
        end
        -- un soleil levant au loin
        local soleil = parent(neon({ Name = "Soleil", Shape = Enum.PartType.Ball, Size = Vector3.new(60, 60, 60), Position = centre + zone.direction * 260 + Vector3.new(0, 20, 0), Color = Color3.fromRGB(255, 170, 60), Transparency = 0.1 }))
        soleil.CanQuery = false
    elseif zone.nom == "Discipline" then
        -- des piliers de pierre, des lanternes bleues, des mannequins d'entraînement, des portiques de dojo
        for _ = 1, 16 do
            local p = pointAuBord()
            local h = graine:NextNumber(12, 24)
            parent(bloc({ Name = "Pilier", Size = Vector3.new(4, h, 4), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, graine:NextNumber(0, math.pi), 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(110, 118, 130) }))
        end
        for _ = 1, 12 do
            local p = pointAuBord()
            parent(bloc({ Name = "Poteau", Size = Vector3.new(0.6, 7, 0.6), CFrame = CFrame.new(p + Vector3.new(0, 3.5, 0)), Color = Color3.fromRGB(40, 40, 46) }))
            local lanterne = parent(neon({ Name = "Lanterne", Size = Vector3.new(1.6, 2.2, 1.6), CFrame = CFrame.new(p + Vector3.new(0, 8, 0)), Color = Color3.fromRGB(90, 160, 255) }))
            creer("PointLight", { Range = 18, Brightness = 1.6, Color = Color3.fromRGB(90, 160, 255), Parent = lanterne })
        end
        for _ = 1, 10 do
            local p = pointAuBord()
            parent(bloc({ Name = "Mannequin", Size = Vector3.new(2, 5, 2), CFrame = CFrame.new(p + Vector3.new(0, 2.5, 0)), Material = Enum.Material.Wood, Color = Color3.fromRGB(150, 110, 70) }))
            parent(bloc({ Name = "Bras", Size = Vector3.new(5, 0.6, 0.6), CFrame = CFrame.new(p + Vector3.new(0, 4, 0)) * CFrame.Angles(0, graine:NextNumber(0, math.pi), 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(130, 95, 60) }))
            parent(boule(p + Vector3.new(0, 5.8, 0), 1.8, { Name = "Tete", Material = Enum.Material.Fabric, Color = Color3.fromRGB(200, 180, 140) }))
        end
        -- un grand portique à l'entrée
        local entree = centre - zone.direction * 88
        local cote = Vector3.new(-zone.direction.Z, 0, zone.direction.X)
        for _, s in ipairs({ -1, 1 }) do
            parent(bloc({ Name = "Torii", Size = Vector3.new(2, 20, 2), CFrame = CFrame.new(entree + cote * 13 * s + Vector3.new(0, 10, 0)), Color = Color3.fromRGB(40, 60, 110) }))
        end
        -- (la poutre du haut est en travers : son axe X est sur le côté)
        parent(bloc({ Name = "Torii", Size = Vector3.new(32, 2, 2.4), CFrame = tournee(entree + Vector3.new(0, 20, 0), zone.direction), Color = Color3.fromRGB(40, 60, 110) }))
    elseif zone.nom == "Ego" then
        -- des colonnes dorées, des miroirs, des projecteurs, un tapis rouge jusqu'au centre
        for _ = 1, 18 do
            local p = pointAuBord()
            local h = graine:NextNumber(14, 22)
            local col = parent(cylindre(p + Vector3.new(0, h / 2, 0), 3, h, { Name = "Colonne", Material = Enum.Material.Foil, Color = Color3.fromRGB(230, 190, 70) }))
            col.CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
            parent(neon({ Name = "Chapiteau", Size = Vector3.new(4, 0.6, 4), CFrame = CFrame.new(p + Vector3.new(0, h + 0.3, 0)), Color = Color3.fromRGB(255, 220, 120) }))
        end
        for _ = 1, 10 do
            local p = pointAuBord()
            local regard = (centre - p) * Vector3.new(1, 0, 1)
            parent(bloc({ Name = "Miroir", Size = Vector3.new(7, 12, 0.4), CFrame = tournee(p + Vector3.new(0, 6, 0), regard.Unit), Material = Enum.Material.Glass, Color = Color3.fromRGB(200, 210, 230), Reflectance = 0.7, Transparency = 0.1 }))
            parent(neon({ Name = "CadreMiroir", Size = Vector3.new(7.6, 12.6, 0.2), CFrame = tournee(p + Vector3.new(0, 6, 0), regard.Unit) * CFrame.new(0, 0, 0.3), Color = Color3.fromRGB(230, 190, 70) }))
        end
        for _ = 1, 6 do
            local p = pointAuBord()
            local projecteur = parent(bloc({ Name = "Projecteur", Size = Vector3.new(2, 2, 3), CFrame = CFrame.lookAt(p + Vector3.new(0, 3, 0), centre + Vector3.new(0, 30, 0)), Color = Color3.fromRGB(30, 30, 30), Material = Enum.Material.Metal }))
            creer("SpotLight", { Range = 60, Angle = 35, Brightness = 4, Color = Color3.fromRGB(255, 240, 200), Face = Enum.NormalId.Front, Parent = projecteur })
        end
        local entree = centre - zone.direction * 100
        local milieu = (entree + centre) / 2
        parent(bloc({ Name = "TapisRouge", Size = Vector3.new(10, 0.2, 88), CFrame = tournee(milieu + Vector3.new(0, 0.1, 0), zone.direction), Material = Enum.Material.Fabric, Color = Color3.fromRGB(170, 20, 30), CanCollide = false }))
    else
        -- des pics noirs, des fissures de lave rouge, des rochers qui flottent
        for _ = 1, 22 do
            local p = pointAuBord()
            local h = graine:NextNumber(8, 22)
            parent(bloc({ Name = "Pic", Size = Vector3.new(3, h, 3), CFrame = CFrame.new(p + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(graine:NextNumber(-0.25, 0.25), graine:NextNumber(0, math.pi), graine:NextNumber(-0.25, 0.25)), Material = Enum.Material.Basalt, Color = Color3.fromRGB(22, 18, 20) }))
        end
        for _ = 1, 24 do
            local x, z = graine:NextNumber(-95, 95), graine:NextNumber(-95, 95)
            parent(neon({ Name = "Fissure", Size = Vector3.new(graine:NextNumber(0.4, 1), 0.15, graine:NextNumber(8, 22)), CFrame = CFrame.new(centre + Vector3.new(x, 0.08, z)) * CFrame.Angles(0, graine:NextNumber(0, math.pi), 0), Color = Color3.fromRGB(255, 40, 40) }))
        end
        for _ = 1, 12 do
            local p = pointAuBord() + Vector3.new(0, graine:NextNumber(18, 40), 0)
            local rocher = parent(bloc({ Name = "RocherFlottant", Size = Vector3.new(graine:NextNumber(4, 9), graine:NextNumber(3, 6), graine:NextNumber(4, 9)), CFrame = CFrame.new(p) * CFrame.Angles(graine:NextNumber(0, 3), graine:NextNumber(0, 3), 0), Material = Enum.Material.Basalt, Color = Color3.fromRGB(35, 25, 28), CanCollide = false }))
            rocher:SetAttribute("Flotte", true)
        end
        local lune = parent(neon({ Name = "Lune", Shape = Enum.PartType.Ball, Size = Vector3.new(50, 50, 50), Position = centre + zone.direction * 260 + Vector3.new(0, 60, 0), Color = Color3.fromRGB(200, 30, 40) }))
        lune.CanQuery = false
    end
end

for _, zone in ipairs(ZONES) do
    local dossier = creer("Folder", { Name = "Zone_" .. zone.nom, Parent = dossierCarte })
    local theme = THEMES[zone.nom]
    local d = zone.direction
    local lateral = Vector3.new(-d.Z, 0, d.X)
    local centre = zone.centre

    -- l'île
    bloc({ Name = "Sol", Size = Vector3.new(DEMI_ZONE * 2, 6, DEMI_ZONE * 2), CFrame = CFrame.new(centre - Vector3.new(0, 3, 0)), Material = theme.sol, Color = theme.couleurSol, Parent = dossier })
    bloc({ Name = "Dessous", Size = Vector3.new(DEMI_ZONE * 2 - 20, 30, DEMI_ZONE * 2 - 20), CFrame = CFrame.new(centre - Vector3.new(0, 21, 0)), Material = Enum.Material.Rock, Color = Color3.fromRGB(60, 52, 48), Parent = dossier })
    -- les bords : néon + murs invisibles (avec une ouverture côté ville)
    local coins = {
        centre + Vector3.new(-DEMI_ZONE, 0, -DEMI_ZONE),
        centre + Vector3.new(DEMI_ZONE, 0, -DEMI_ZONE),
        centre + Vector3.new(DEMI_ZONE, 0, DEMI_ZONE),
        centre + Vector3.new(-DEMI_ZONE, 0, DEMI_ZONE),
    }
    for k = 1, 4 do
        local a, b = coins[k], coins[k % 4 + 1]
        local milieu = (a + b) / 2
        local cote = (milieu - centre).Unit
        local faceVille = cote:Dot(-d) > 0.9
        neon({ Name = "BordNeon", Size = Vector3.new((b - a).Magnitude, 0.5, 0.8), CFrame = CFrame.lookAt(milieu + Vector3.new(0, 0.25, 0), milieu + Vector3.new(0, 0.25, 0) + (b - a).Unit) * CFrame.Angles(0, math.pi / 2, 0), Color = zone.couleur, Parent = dossier })
        if faceVille then
            local ouverture = 14
            local porteA = milieu + (a - milieu).Unit * ouverture
            local porteB = milieu + (b - milieu).Unit * ouverture
            murEntre(a, porteA, 16, dossier)
            murEntre(porteB, b, 16, dossier)
        else
            murEntre(a, b, 16, dossier)
        end
    end

    -- le pont
    local debut, fin = RAYON_VILLE - 2, DISTANCE_ZONE - DEMI_ZONE + 2
    local longueur = fin - debut
    local milieuPont = C + d * (debut + longueur / 2)
    bloc({ Name = "Pont", Size = Vector3.new(24, 3, longueur), CFrame = tournee(milieuPont - Vector3.new(0, 1.5, 0), d), Material = theme.pont, Color = theme.couleurPont, Parent = dossier })
    for _, s in ipairs({ -1, 1 }) do
        neon({ Name = "Rambarde", Size = Vector3.new(0.6, 0.6, longueur), CFrame = tournee(milieuPont + lateral * 11.7 * s + Vector3.new(0, 3, 0), d), Color = zone.couleur, Parent = dossier })
        invisible({ Name = "MurPont", Size = Vector3.new(1, 14, longueur), CFrame = tournee(milieuPont + lateral * 12.5 * s + Vector3.new(0, 7, 0), d), Parent = dossier })
        for k = 0, 6 do
            local p = C + d * (debut + 8 + k * (longueur - 16) / 6) + lateral * 11.7 * s
            bloc({ Name = "Poteau", Size = Vector3.new(0.8, 3, 0.8), CFrame = CFrame.new(p + Vector3.new(0, 1.5, 0)), Color = Color3.fromRGB(30, 30, 36), Parent = dossier })
        end
    end
    -- l'arche à l'entrée du pont (côté ville), avec le nom de la zone
    local arche = C + d * (RAYON_VILLE + 4)
    for _, s in ipairs({ -1, 1 }) do
        bloc({ Name = "Arche", Size = Vector3.new(2, 18, 2), CFrame = CFrame.new(arche + lateral * 13 * s + Vector3.new(0, 9, 0)), Color = Color3.fromRGB(26, 26, 32), Parent = dossier })
    end
    local fronton = bloc({ Name = "Fronton", Size = Vector3.new(28, 4.5, 1), CFrame = tournee(arche + Vector3.new(0, 19, 0), -d), Color = Color3.fromRGB(16, 16, 20), Parent = dossier })
    do
        local surface = creer("SurfaceGui", { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Vector2.new(560, 90), LightInfluence = 0, Parent = fronton })
        creer("TextLabel", { Size = UDim2.new(1, 0, 0.62, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = zone.titre, TextColor3 = zone.couleur, Parent = surface })
        creer("TextLabel", { Position = UDim2.fromScale(0, 0.64), Size = UDim2.new(1, 0, 0.32, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true,
            Text = (if zone.prix > 0 then court(zone.prix) .. " AURA" else "FREE") .. "  ·  x" .. court(zone.aura) .. " AURA", TextColor3 = BLANC, Parent = surface })
    end
    neon({ Name = "LigneFronton", Size = Vector3.new(28, 0.4, 1.1), CFrame = tournee(arche + Vector3.new(0, 16.6, 0), -d), Color = zone.couleur, Parent = dossier })

    -- 🔒 la porte (au bout du pont), sauf pour la première zone
    if zone.prix > 0 then
        local p = C + d * (fin - 4)
        local porte = neon({
            Name = "Porte_" .. zone.nom,
            Size = Vector3.new(24, 16, 1.2),
            CFrame = tournee(p + Vector3.new(0, 8, 0), -d),
            Color = zone.couleur,
            Transparency = 0.45,
            CanCollide = true,
            Parent = dossierPortes,
        })
        porte:SetAttribute("Zone", zone.nom)
        local texteVerrou = zone.titre .. "\nLOCKED · " .. court(zone.prix) .. " AURA"
        panneau(porte, texteVerrou, BLANC, 18)
        panneau(porte, texteVerrou, BLANC, 18, Enum.NormalId.Back)
        local prompt = bouton(porte, "Unlock", zone.titre .. " · " .. court(zone.prix) .. " AURA", "Porte", 16)
        prompt:SetAttribute("Zone", zone.nom)
    end

    -- le socle de la pensée géante (au centre)
    local socle = cylindre(centre + Vector3.new(0, 0.6, 0), 30, 1.2, { Name = "SocleBoss", Material = Enum.Material.Marble, Color = Color3.fromRGB(40, 40, 46), Parent = dossier })
    socle.CFrame = CFrame.new(centre + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2)
    neon({ Name = "CercleBoss", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 31, 31), CFrame = CFrame.new(centre + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = zone.couleur, Transparency = 0.3, Parent = dossier })

    decorer(zone, dossier)
end

-- ========================== LES CRISTAUX ==========================
local cristaux = {} -- [modele] = info
local nombreParZone = {}
for _, zone in ipairs(ZONES) do
    nombreParZone[zone.nom] = 0
end
local bossActuel = nil

local function majBarre(info)
    local part = math.clamp(info.pv / info.pvMax, 0, 1)
    info.rempli.Size = UDim2.fromScale(part, 1)
    if info.textePv then
        info.textePv.Text = court(math.max(0, info.pv)) .. " / " .. court(info.pvMax)
    end
end

local function creerCristal(zone, typeCristal, position, estBoss)
    local taille = if estBoss then CONFIG.BOSS.taille else typeCristal.taille
    local modele = creer("Model", { Name = if estBoss then "Boss" else "Cristal" })
    local base = CFrame.new(position)
    local penche = CFrame.Angles(math.rad(45), 0, math.rad(35))
    local coque = creer("Part", {
        Name = "Coque",
        Anchored = true,
        CanCollide = false,
        CanTouch = false,
        Size = Vector3.new(taille, taille, taille),
        CFrame = base * penche,
        Material = Enum.Material.Glass,
        Transparency = 0.25,
        Reflectance = 0.15,
        Color = zone.couleur:Lerp(BLANC, 0.25),
        CastShadow = false,
        Parent = modele,
    })
    local coeur = creer("Part", {
        Name = "Coeur",
        Anchored = true,
        CanCollide = false,
        CanTouch = false,
        CanQuery = false,
        Size = Vector3.new(taille, taille, taille) * 0.55,
        CFrame = base * penche,
        Material = Enum.Material.Neon,
        Color = zone.couleur,
        CastShadow = false,
        Parent = modele,
    })
    if estBoss or typeCristal.nom == "BIG" then
        creer("PointLight", { Range = taille * 2.2, Brightness = if estBoss then 4 else 1.5, Color = zone.couleur, Parent = coeur })
    end
    modele.PrimaryPart = coque
    -- la barre de vie
    local billboard = creer("BillboardGui", {
        Name = "Barre",
        Size = if estBoss then UDim2.fromOffset(320, 54) else UDim2.fromOffset(96, 14),
        StudsOffsetWorldSpace = Vector3.new(0, taille * 0.85 + 1.5, 0),
        MaxDistance = if estBoss then 300 else 40,
        AlwaysOnTop = estBoss,
        LightInfluence = 0,
        Parent = coque,
    })
    local fond = creer("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = if estBoss then UDim2.new(1, 0, 0, 20) else UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(15, 15, 20),
        BorderSizePixel = 0,
        Parent = billboard,
    })
    creer("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fond })
    creer("UIStroke", { Color = BLANC, Thickness = 1.2, Transparency = 0.3, Parent = fond })
    local rempli = creer("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = zone.couleur:Lerp(BLANC, 0.2), BorderSizePixel = 0, Parent = fond })
    creer("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rempli })
    local textePv = creer("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = BLANC, TextStrokeTransparency = 0.3, Parent = fond })
    if estBoss then
        creer("TextLabel", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = "GIANT THOUGHT", TextColor3 = zone.couleur:Lerp(BLANC, 0.3), TextStrokeTransparency = 0, Parent = billboard })
    end

    local pv = math.floor((if estBoss then CONFIG.BOSS.pv else typeCristal.pv) * zone.pv)
    local aura = math.floor((if estBoss then CONFIG.BOSS.aura else typeCristal.aura) * zone.aura)
    modele:SetAttribute("Zone", zone.nom)
    modele:SetAttribute("Type", if estBoss then "BOSS" else typeCristal.nom)
    modele:SetAttribute("Taille", taille)
    modele:SetAttribute("Base", base)
    modele:SetAttribute("Aura", aura)
    modele.Parent = dossierCristaux

    local info = {
        modele = modele,
        zone = zone,
        type = if estBoss then "BOSS" else typeCristal.nom,
        pv = pv,
        pvMax = pv,
        aura = aura,
        position = position,
        taille = taille,
        coups = {},
        contributions = {},
        boss = estBoss,
        rempli = rempli,
        textePv = textePv,
        ne = os.clock(),
    }
    cristaux[modele] = info
    majBarre(info)
    if not estBoss then
        nombreParZone[zone.nom] += 1
    end
    return info
end

local function choisirType()
    local total = 0
    for _, t in ipairs(CONFIG.TYPES) do
        total += t.poids
    end
    local tirage = math.random() * total
    for _, t in ipairs(CONFIG.TYPES) do
        tirage -= t.poids
        if tirage <= 0 then
            return t
        end
    end
    return CONFIG.TYPES[1]
end

local function apparaitreCristal(zone)
    local typeCristal = choisirType()
    local position
    for _ = 1, 10 do
        local x = (math.random() * 2 - 1) * ZONE_CRISTAUX
        local z = (math.random() * 2 - 1) * ZONE_CRISTAUX
        if math.abs(x) > 18 or math.abs(z) > 18 then -- pas sur le socle du boss
            local essai = zone.centre + Vector3.new(x, typeCristal.taille * 0.9 + 1, z)
            local libre = true
            for _, info in pairs(cristaux) do
                if info.zone == zone and (info.position - essai).Magnitude < (info.taille + typeCristal.taille) * 0.75 + 3 then
                    libre = false
                    break
                end
            end
            if libre then
                position = essai
                break
            end
        end
    end
    if position then
        creerCristal(zone, typeCristal, position, false)
    end
end

-- 💥 un cristal est cassé : chacun gagne sa part d'aura (selon les dégâts qu'il a faits)
local function casser(modele, info)
    if info.mort then
        return
    end
    info.mort = true
    modele:SetAttribute("Mort", true)
    local gains = {}
    local meilleur, meilleurDegats = nil, 0
    for j, contribution in pairs(info.contributions) do
        local e = etats[j]
        if e and j.Parent then
            local part = math.clamp(contribution / info.pvMax, 0, 1)
            if info.boss then
                part = math.max(part, 0.1) -- tous ceux qui ont aidé ont au moins 10 %
            else
                -- la série de DISCIPLINE
                if os.clock() - e.dernierCasse <= CONFIG.SERIE_DELAI then
                    e.serie += 1
                else
                    e.serie = 1
                end
                e.dernierCasse = os.clock()
                j:SetAttribute("Serie", e.serie)
                j:SetAttribute("MultAura", multAura(e))
            end
            local gain = math.max(1, math.floor(info.aura * part * multAura(e) + 0.5))
            ajouterAura(j, gain)
            gains[j] = gain
            if contribution > meilleurDegats then
                meilleur, meilleurDegats = j, contribution
            end
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        CasseEvent:FireClient(p, info.position, gains[p] or 0, info.type, info.zone.nom, info.taille)
    end
    if info.boss then
        bossActuel = nil
        EvenementEvent:FireAllClients("BossMort", info.zone.nom, if meilleur then meilleur.DisplayName else "")
    else
        nombreParZone[info.zone.nom] -= 1
    end
    cristaux[modele] = nil
    task.delay(0.05, function()
        modele:Destroy()
    end)
end

-- 👊 un joueur frappe un cristal
FrapperEvent.OnServerEvent:Connect(function(joueur, modele)
    local e = etats[joueur]
    if not e or not e.charge or typeof(modele) ~= "Instance" then
        return
    end
    local info = cristaux[modele]
    if not info or info.mort then
        return
    end
    local maintenant = os.clock()
    if maintenant - e.derniereFrappe < intervalle(e) * 0.8 then
        return -- trop vite
    end
    if not e.zones[info.zone.nom] then
        return
    end
    local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
    if not racine or (racine.Position - info.position).Magnitude > CONFIG.PORTEE + info.taille * 0.6 + 5 then
        return
    end
    e.derniereFrappe = maintenant
    local coups = (info.coups[joueur] or 0) + 1
    info.coups[joueur] = coups
    local d = degats(e)
    local critique = false
    if e.perso == "Motivation" and coups == 1 then
        d *= 3
        critique = true
    elseif e.perso == "Obsession" then
        local m = math.min(4, 1 + 0.15 * (coups - 1))
        d *= m
        critique = m >= 4
    end
    d = math.max(1, math.floor(d))
    info.contributions[joueur] = (info.contributions[joueur] or 0) + math.min(d, math.max(0, info.pv))
    info.pv -= d
    majBarre(info)
    ImpactEvent:FireAllClients(modele, d, joueur, critique)
    if info.pv <= 0 then
        casser(modele, info)
    end
end)

-- on remplit les zones, puis on remplace les cristaux cassés petit à petit
for _, zone in ipairs(ZONES) do
    for _ = 1, CONFIG.CRISTAUX_PAR_ZONE do
        apparaitreCristal(zone)
    end
end
task.spawn(function()
    while true do
        task.wait(CONFIG.REAPPARITION_CRISTAL)
        for _, zone in ipairs(ZONES) do
            if nombreParZone[zone.nom] < CONFIG.CRISTAUX_PAR_ZONE then
                apparaitreCristal(zone)
            end
        end
    end
end)

-- 👑 LA PENSÉE GÉANTE : dans une zone où il y a quelqu'un
task.spawn(function()
    while true do
        task.wait(CONFIG.BOSS.intervalle)
        if not bossActuel then
            local candidates = {}
            for _, p in ipairs(Players:GetPlayers()) do
                local zone = ZONE_PAR_NOM[p:GetAttribute("Zone") or ""]
                if zone and not table.find(candidates, zone) then
                    table.insert(candidates, zone)
                end
            end
            if #candidates > 0 then
                local zone = candidates[math.random(1, #candidates)]
                local info = creerCristal(zone, nil, zone.centre + Vector3.new(0, CONFIG.BOSS.taille * 0.9 + 2.5, 0), true)
                bossActuel = info
                EvenementEvent:FireAllClients("Boss", zone.nom)
                task.delay(CONFIG.BOSS.duree, function()
                    if bossActuel == info and not info.mort then
                        info.mort = true
                        bossActuel = nil
                        cristaux[info.modele] = nil
                        info.modele:Destroy()
                        EvenementEvent:FireAllClients("BossFuite", zone.nom)
                    end
                end)
            end
        end
    end
end)

-- ========================== LES ACHATS ==========================
local function acheter(joueur, e, quoi, nom)
    local aura = stat(joueur, "Aura")
    if quoi == "Amelioration" then
        local def = AMELIO_PAR_CLE[nom]
        if not def then
            return false, "Unknown upgrade"
        end
        local n = e.niveaux[def.cle]
        if n >= def.max then
            return false, "Already at max level"
        end
        local prix = prixAmelioration(def, n)
        if aura.Value < prix then
            return false, "Not enough aura"
        end
        aura.Value -= prix
        e.niveaux[def.cle] = n + 1
        publier(joueur)
        return true, n + 1
    elseif quoi == "Zone" then
        local zone = ZONE_PAR_NOM[nom]
        if not zone then
            return false, "Unknown zone"
        end
        if e.zones[zone.nom] then
            return false, "Already unlocked"
        end
        local precedente = ZONES[zone.index - 1]
        if precedente and not e.zones[precedente.nom] then
            return false, "Unlock the previous zone first"
        end
        if aura.Value < zone.prix then
            return false, "Not enough aura"
        end
        aura.Value -= zone.prix
        e.zones[zone.nom] = true
        publier(joueur)
        EvenementEvent:FireClient(joueur, "Debloque", zone.nom)
        return true, zone.nom
    elseif quoi == "Perso" then
        local perso = PERSOS[nom]
        if not perso then
            return false, "Unknown mindset"
        end
        if e.persos[nom] then
            if e.perso == nom then
                return false, "Already equipped"
            end
            e.perso = nom
            e.serie = 0
            publier(joueur)
            return true, "equipe"
        end
        if aura.Value < perso.prix then
            return false, "Not enough aura"
        end
        aura.Value -= perso.prix
        e.persos[nom] = true
        e.perso = nom
        e.serie = 0
        publier(joueur)
        EvenementEvent:FireClient(joueur, "NouveauPerso", nom)
        return true, "achete"
    elseif quoi == "Renaissance" then
        local prix = prixRenaissance(e.rebirths)
        if aura.Value < prix then
            return false, "Not enough aura"
        end
        aura.Value = 0
        for cle in pairs(e.niveaux) do
            e.niveaux[cle] = 0
        end
        e.rebirths += 1
        e.serie = 0
        publier(joueur)
        EvenementEvent:FireClient(joueur, "Renaissance", e.rebirths)
        task.spawn(sauverJoueur, joueur)
        return true, e.rebirths
    end
    return false, "?"
end

AcheterFonction.OnServerInvoke = function(joueur, quoi, nom)
    local e = etats[joueur]
    if not e or not e.charge then
        return false, "Still loading your data..."
    end
    if type(quoi) ~= "string" or (nom ~= nil and type(nom) ~= "string") then
        return false, "?"
    end
    if e.achatEnCours then
        return false, "Wait a second..."
    end
    e.achatEnCours = true
    local ok, resultat, detail = pcall(acheter, joueur, e, quoi, nom)
    e.achatEnCours = false
    if not ok then
        warn("🛒 Achat raté :", resultat)
        return false, "Try again in a second..."
    end
    return resultat, detail
end

-- ========================== CLASSEMENTS (TOP 10) ==========================
-- T = le plus d'aura gagnée en tout · R = le plus de renaissances
-- Sauvegardés dans des OrderedDataStore (il faut publier le jeu) ; sinon, on montre les joueurs du serveur.
local CLASSEMENTS = {
    T = { store = "MSS_TotalAura_v1", tableau = "TableauTotal", stat = "Total" },
    R = { store = "MSS_Rebirths_v1", tableau = "TableauRebirths", stat = "Rebirths" },
}
local alerteClassement = false
for _, c in pairs(CLASSEMENTS) do
    local ok, store = pcall(function()
        return DataStoreService:GetOrderedDataStore(c.store)
    end)
    if ok then
        c.ordre = store
    end
end
local function alerte(erreur)
    if not alerteClassement then
        alerteClassement = true
        warn("🏆 Classements : sauvegarde indisponible (publie le jeu + accès Studio aux services API). On montre les joueurs du serveur. ", erreur)
    end
end

publierClassements = function(joueur, total, rebirths)
    for cle, valeur in pairs({ T = total, R = rebirths }) do
        local c = CLASSEMENTS[cle]
        if c.ordre and valeur > 0 then
            local ok, erreur = pcall(function()
                c.ordre:SetAsync(tostring(joueur.UserId), math.floor(valeur))
            end)
            if not ok then
                alerte(erreur)
            end
        end
    end
end

local nomsCache = {}
local function nomDe(userId)
    local present = Players:GetPlayerByUserId(userId)
    if present then
        nomsCache[userId] = present.DisplayName
    end
    if not nomsCache[userId] then
        local ok, nom = pcall(function()
            return Players:GetNameFromUserIdAsync(userId)
        end)
        nomsCache[userId] = if ok and nom then nom else ("Player " .. userId)
    end
    return nomsCache[userId]
end

local function majTableau(cle)
    local c = CLASSEMENTS[cle]
    local scores = {}
    if c.ordre then
        local ok, page = pcall(function()
            return c.ordre:GetSortedAsync(false, 10):GetCurrentPage()
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
    -- les joueurs présents (leur score actuel, même pas encore sauvegardé)
    for _, p in ipairs(Players:GetPlayers()) do
        local v = stat(p, c.stat)
        if v and v.Value > (scores[p.UserId] or 0) then
            scores[p.UserId] = v.Value
        end
    end
    local liste = {}
    for id, score in pairs(scores) do
        if score > 0 then
            table.insert(liste, { id = id, score = score })
        end
    end
    table.sort(liste, function(a, b)
        return a.score > b.score
    end)
    local tableau = dossierVille:FindFirstChild(c.tableau)
    local surface = tableau and tableau:FindFirstChildOfClass("SurfaceGui")
    if not surface then
        return
    end
    local COULEURS_RANG = { OR, Color3.fromRGB(210, 210, 225), Color3.fromRGB(215, 140, 80) }
    for rang = 1, 10 do
        local ligne = surface:FindFirstChild("Ligne" .. rang)
        local l = liste[rang]
        if ligne then
            if l then
                local couleur = COULEURS_RANG[rang] or Color3.fromRGB(200, 200, 215)
                ligne.Text = enCouleur("#" .. rang, couleur) .. "  " .. nomDe(l.id) .. "   " .. enCouleur(court(l.score), couleur)
            else
                ligne.Text = if rang == 1 then "No record yet: be the first!" else ""
            end
        end
    end
end

task.spawn(function()
    task.wait(5)
    while true do
        for cle in pairs(CLASSEMENTS) do
            pcall(majTableau, cle)
        end
        task.wait(60)
    end
end)

-- ========================== LES JOUEURS ==========================
-- l'étiquette au-dessus de la tête : l'état d'esprit (en couleur) + les renaissances
majEtiquette = function(joueur)
    local e = etats[joueur]
    local tete = joueur.Character and joueur.Character:FindFirstChild("Head")
    if not e or not tete then
        return
    end
    local etiquette = tete:FindFirstChild("MindsetEtiquette")
    if not etiquette then
        etiquette = creer("BillboardGui", { Name = "MindsetEtiquette", Size = UDim2.fromOffset(160, 26), StudsOffset = Vector3.new(0, 2.6, 0), MaxDistance = 70, LightInfluence = 0, Parent = tete })
        creer("TextLabel", { Name = "Texte", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, RichText = true, TextStrokeTransparency = 0.2, TextColor3 = BLANC, Parent = etiquette })
    end
    local texte = enCouleur(string.upper(e.perso), PERSOS[e.perso].couleur)
    if e.rebirths > 0 then
        texte ..= "  " .. enCouleur("R" .. e.rebirths, BLANC)
    end
    etiquette.Texte.Text = texte
end

-- 👑 la couronne de l'EGO (le plus riche du serveur, s'il est Ego)
local function majCouronnes()
    local riche, plus = nil, -1
    for _, p in ipairs(Players:GetPlayers()) do
        local aura = stat(p, "Aura")
        if aura and aura.Value > plus then
            riche, plus = p, aura.Value
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        local e = etats[p]
        local tete = p.Character and p.Character:FindFirstChild("Head")
        if tete then
            local couronne = tete:FindFirstChild("CouronneEgo")
            local doitAvoir = e and e.perso == "Ego" and p == riche
            if doitAvoir and not couronne then
                couronne = creer("Part", {
                    Name = "CouronneEgo",
                    Size = Vector3.new(1.4, 0.7, 1.4),
                    Material = Enum.Material.Neon,
                    Color = OR,
                    CanCollide = false,
                    CanQuery = false,
                    CanTouch = false,
                    Massless = true,
                    CFrame = tete.CFrame * CFrame.new(0, tete.Size.Y / 2 + 0.6, 0),
                    Parent = tete,
                })
                creer("WeldConstraint", { Part0 = couronne, Part1 = tete, Parent = couronne })
                creer("PointLight", { Range = 8, Brightness = 2, Color = OR, Parent = couronne })
            elseif not doitAvoir and couronne then
                couronne:Destroy()
            end
        end
    end
end

local function joueurArrive(joueur)
    etats[joueur] = nouvelEtat()
    local stats = creer("Folder", { Name = "leaderstats" })
    creer("IntValue", { Name = "Aura", Parent = stats })
    creer("IntValue", { Name = "Rebirths", Parent = stats })
    stats.Parent = joueur
    local cachees = creer("Folder", { Name = "StatsCachees", Parent = joueur })
    creer("IntValue", { Name = "Total", Parent = cachees })
    joueur:SetAttribute("Zone", "Ville")
    task.spawn(chargerJoueur, joueur)

    local function surPersonnage(personnage)
        local humanoid = personnage:WaitForChild("Humanoid", 10)
        if not humanoid then
            return
        end
        task.wait() -- (le temps que Roblox ait posé l'avatar)
        local position = APPARITION + Vector3.new((math.random() - 0.5) * 8, 0, (math.random() - 0.5) * 6)
        personnage:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, -1)))
        local e = etats[joueur]
        if e then
            humanoid.WalkSpeed = valeurAmelioration("Jambes", e.niveaux.Jambes)
        end
        personnage:WaitForChild("Head", 5)
        majEtiquette(joueur)
    end
    joueur.CharacterAdded:Connect(surPersonnage)
    if joueur.Character then
        task.spawn(surPersonnage, joueur.Character)
    end
end
Players.PlayerAdded:Connect(joueurArrive)
for _, joueur in ipairs(Players:GetPlayers()) do
    task.spawn(joueurArrive, joueur)
end
Players.PlayerRemoving:Connect(function(joueur)
    sauverJoueur(joueur)
    etats[joueur] = nil
    for _, info in pairs(cristaux) do
        info.contributions[joueur] = nil
        info.coups[joueur] = nil
    end
end)

-- où est chaque joueur ? (ville, pont, ou une zone) — et pas dans une zone fermée !
local function zoneA(position)
    local plat = (position - C) * Vector3.new(1, 0, 1)
    if plat.Magnitude <= RAYON_VILLE + 2 then
        return "Ville"
    end
    for _, zone in ipairs(ZONES) do
        local ecart = position - zone.centre
        if math.abs(ecart.X) <= DEMI_ZONE + 1 and math.abs(ecart.Z) <= DEMI_ZONE + 1 then
            return zone.nom
        end
    end
    return "Pont"
end

task.spawn(function()
    local tic = 0
    while true do
        task.wait(0.5)
        tic += 1
        for _, joueur in ipairs(Players:GetPlayers()) do
            local e = etats[joueur]
            local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
            if e and racine then
                local position = racine.Position
                local zone = zoneA(position)
                if position.Y < C.Y - 60 then
                    -- tombé dans le vide : retour en ville
                    joueur.Character:PivotTo(CFrame.new(APPARITION))
                    zone = "Ville"
                elseif ZONE_PAR_NOM[zone] and e.charge and not e.zones[zone] then
                    joueur.Character:PivotTo(CFrame.new(APPARITION))
                    MessageEvent:FireClient(joueur, "This zone is locked!")
                    zone = "Ville"
                end
                if joueur:GetAttribute("Zone") ~= zone then
                    joueur:SetAttribute("Zone", zone)
                end
                -- la série de Discipline retombe à 0 après une pause
                if e.serie > 0 and os.clock() - e.dernierCasse > CONFIG.SERIE_DELAI then
                    e.serie = 0
                    joueur:SetAttribute("Serie", 0)
                    joueur:SetAttribute("MultAura", multAura(e))
                end
                -- 😴 la zone AFK
                if tic % 60 == 0 and e.charge then
                    local afk = C + Vector3.new(0, 0, 62)
                    if ((position - afk) * Vector3.new(1, 0, 1)).Magnitude < 9 then
                        local gain = math.floor(CONFIG.AURA_AFK * meilleureZone(e).aura * multAura(e))
                        ajouterAura(joueur, gain)
                        MessageEvent:FireClient(joueur, "+" .. court(gain) .. " AURA (AFK)")
                    end
                end
            end
        end
        if tic % 10 == 0 then
            majCouronnes()
        end
    end
end)

print("🌍 Mindset Simulator : carte construite, " .. #ZONES .. " zones, prêt !")
