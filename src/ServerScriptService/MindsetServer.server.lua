--[[
    🧠 MINDSET STAIRS — Script SERVEUR
    À mettre dans : ServerScriptService  (type : Script)

    L'ESCALIER INFINI en 3D : tout le monde court sur un immense escalier (vue à la 3e personne),
    avec des rochers qui dévalent, des marches qui cassent et des trous. Le plus haut à la fin du chrono gagne.
    Chaque état d'esprit se joue différemment, comme dans la trend :
      MOTIVATION : très rapide au début, puis de plus en plus lent
      EGO        : double saut et saute plus haut... mais quand il tombe, il tombe loin
      DISCIPLINE : vitesse moyenne, mais un checkpoint toutes les 50 marches
      OBSESSION  : lent au début, puis de plus en plus rapide, inarrêtable à la fin
    Ce script construit l'escalier, gère les manches, les pièges, les rochers, les bots et la sauvegarde.
    (l'ancien jeu de rythme est gardé dans le tag git « v2-rythme »)
]]

-- ===================== RÉGLAGES (tu peux les modifier) =====================
local CONFIG = {
    ATTENTE_LOBBY = 25,   -- secondes pour choisir son état d'esprit et voter la musique
    PREPARATION = 4,      -- secondes de décompte avant le départ (3, 2, 1, GO)
    DUREE_MANCHE = 75,    -- durée de la course (secondes)
    DUREE_DANSE = 8,      -- secondes où le gagnant danse pour farm l'aura à la fin
    AURA_PAR_PAS = 1,     -- aura gagnée à chaque pas de danse du gagnant
    COUREURS_MIN = 4,     -- des bots complètent jusqu'à ce nombre
    NB_PROPOSITIONS = 3,  -- musiques proposées au vote dans le lobby

    -- 🪜 L'ESCALIER
    LARGEUR = 30,         -- largeur de l'escalier (studs)
    PROFONDEUR = 2.5,     -- profondeur d'une marche
    HAUTEUR = 1,          -- hauteur d'une marche (1 = on monte en marchant, sans sauter)
    ZONE_TRANQUILLE = 15, -- les premières marches n'ont pas de piège
    -- les pièges : chance qu'une marche en soit un, { en bas, à partir de la marche 400 }
    PIEGES = {
        trou = { 0.03, 0.06 },     -- une marche manque : il faut sauter
        demi = { 0.05, 0.10 },     -- la moitié de la marche manque : passe de l'autre côté
        cassante = { 0.06, 0.15 }, -- marche de lave craquelée : elle casse quand on marche dessus
    },

    -- 💀 LES CHUTES : combien de marches on perd quand on tombe
    CHUTE = 15,
    CHUTE_EGO = 30,          -- l'EGO tombe de plus haut
    CHUTE_DISCIPLINE = 8,    -- la DISCIPLINE perd peu... et jamais sous son dernier checkpoint
    CHECKPOINT = 50,         -- un checkpoint DISCIPLINE toutes les 50 marches

    -- 🏃 LES VITESSES (studs par seconde ; 16 = la vitesse normale de Roblox), du début à la fin de la course
    VITESSE = {
        Motivation = { debut = 25, fin = 13 },
        Ego = { debut = 17, fin = 17 },
        Discipline = { debut = 17.5, fin = 17.5 },
        Obsession = { debut = 12, fin = 28 },
    },
    SAUT = 7.2,           -- hauteur de saut normale (l'EGO saute plus haut avec SHOWTIME, et il a un double saut)

    -- 🪨 LES ROCHERS qui dévalent l'escalier
    ROCHERS_DEBUT = 3.2,  -- un rocher toutes les 3,2 s au début de la course...
    ROCHERS_FIN = 1.0,    -- ... et toutes les 1 s à la fin
    TEMPETE = 8,          -- au DROP de la musique : TEMPÊTE de rochers pendant 8 secondes

    AURA_PAR_MARCHES = 10, -- fin de course : 1 aura toutes les 10 marches
    AURA_VICTOIRE = 25,    -- bonus d'aura du gagnant

    -- 🎵 MUSIQUES : à chaque lobby, 3 sont tirées au hasard et les joueurs votent.
    --   id    = l'ID Roblox du son, ex. "rbxassetid://1234567890" (id = "" : ignorée)
    --   nom   = le nom affiché sur la carte de vote
    --   bpm   = le tempo (le gagnant danse dessus)
    --   debut = à quelle seconde du son la course commence
    --   drop  = à quelle seconde du son arrive le DROP → TEMPÊTE DE ROCHERS (pas de drop = enlève « drop = ... »)
    --           (marque-le avec l'outil : Play dans Studio, touche B)
    MUSIQUES = {
        { id = "rbxassetid://74842327948915", nom = "BUFÓN!", bpm = 82, debut = 0, drop = 9.57, decalage = 0 },
        { id = "rbxassetid://134372266822247", nom = "MONTAGE SENNTANA", bpm = 95, debut = 0, drop = 20.22, decalage = 0 },
        { id = "rbxassetid://117822777228038", nom = "ME VS ME", bpm = 120, debut = 0, drop = 19.14, decalage = 0 },
        { id = "rbxassetid://84227603413943", nom = "NO ERA AMOR", bpm = 103, debut = 0, drop = 10.21, decalage = 0 },
        { id = "rbxassetid://80140071567818", nom = "EMPIRE", bpm = 93, debut = 0, drop = 23.38, decalage = 0 },
        { id = "rbxassetid://135464211325455", nom = "TIKI TIKI", bpm = 84, debut = 0, drop = 8.68, decalage = 0 },
        { id = "rbxassetid://127965945833744", nom = "Your Next Opponent Is You", bpm = 143, debut = 0, drop = 20.11, decalage = 0 },
    },

    -- 🛒 MARCHAND D'AURA : l'aura gagnée en jouant sert à améliorer les compétences de ton état d'esprit
    COUTS = { 100, 250, 500, 900, 1500 }, -- prix (en aura) du niveau 1, 2, 3, 4, 5 d'une compétence
    -- En Studio seulement : on te met au moins cette aura pour pouvoir tester le marchand (0 = rien)
    AURA_CADEAU_STUDIO = 3000,
}

-- 🧠 LES COMPÉTENCES : chaque état d'esprit a 3 compétences, de niveau 0 à 5, achetées chez le marchand.
--   nom     = le nom affiché
--   texte   = ce que fait la compétence (%s = la valeur du niveau, %% = le signe %)
--   valeurs = la valeur à chaque niveau (niveau 1, 2, 3, 4, 5) → c'est ici qu'on équilibre le jeu
-- ⚠️ Si tu changes un texte, change aussi sa traduction (script client, partie LANGUE).
local COMPETENCES = {
    Motivation = {
        { nom = "HEAD START", texte = "Start every round %s steps up", valeurs = { 3, 6, 10, 15, 20 } },
        { nom = "FIRE START", texte = "+%s%% speed in the first 30%% of the round", valeurs = { 5, 10, 15, 20, 25 } },
        { nom = "SECOND WIND", texte = "A %s-second speed boost at mid-round", valeurs = { 2, 3, 4, 5, 6 } },
    },
    Ego = {
        { nom = "SHOWTIME", texte = "+%s%% jump height", valeurs = { 10, 20, 30, 40, 50 } },
        { nom = "SPOTLIGHT", texte = "+%s%% speed while you're 1st", valeurs = { 4, 8, 12, 16, 20 } },
        { nom = "THICK SKIN", texte = "Your first %s falls cost half", valeurs = { 1, 2, 3, 4, 5 } },
    },
    Discipline = {
        { nom = "IRON WILL", texte = "A checkpoint every %s steps", valeurs = { 42, 35, 28, 22, 16 } },
        { nom = "ROUTINE", texte = "+%s%% speed, all round long", valeurs = { 2, 4, 6, 8, 10 } },
        { nom = "HARD WORK", texte = "+%s%% aura earned", valeurs = { 10, 20, 35, 50, 75 } },
    },
    Obsession = {
        { nom = "LATE MONSTER", texte = "+%s top speed at the end", valeurs = { 1, 2, 3, 4, 6 } },
        { nom = "UNSTOPPABLE", texte = "%s%% chance boulders don't knock you", valeurs = { 15, 30, 45, 60, 75 } },
        { nom = "FINAL RUSH", texte = "+30%% speed in the last %s seconds", valeurs = { 5, 8, 11, 14, 18 } },
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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local DataStoreService = game:GetService("DataStoreService")

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

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

-- ========================== COMMUNICATION ==========================
local dossierRemotes = Instance.new("Folder")
dossierRemotes.Name = "MindsetRemotes"
local function remote(nom)
    return creer("RemoteEvent", { Name = nom, Parent = dossierRemotes })
end
local DebutEvent = remote("Debut")         -- serveur -> clients : la course commence (heure du départ, musique...)
local ChoisirEvent = remote("Choisir")     -- client -> serveur : choix du perso
local EvenementEvent = remote("Evenement") -- serveur -> clients : chute, rocher, tempête, vainqueur, danse...
local FinEvent = remote("Fin")             -- serveur -> joueur : son écran de fin
local VoterMusiqueEvent = remote("VoterMusique") -- client -> serveur : vote pour une des 3 musiques
local DanserEvent = remote("Danser")       -- client -> serveur : le gagnant fait un pas de danse (farm d'aura)
local JouerEvent = remote("Jouer")         -- client -> serveur : PLAY (true), AFK (false), retour au hub ("Hub")
local ReglagesEvent = remote("Reglages")   -- client -> serveur : ses paramètres (volumes, langue...) à sauvegarder
local ClassementFonction = creer("RemoteFunction", { Name = "Classement", Parent = dossierRemotes }) -- top d'un classement
local AmeliorerFonction = creer("RemoteFunction", { Name = "Ameliorer", Parent = dossierRemotes }) -- acheter un niveau de compétence

-- les compétences et leurs prix, pour que les clients puissent les afficher (menu, marchand)
ReplicatedStorage:SetAttribute("Competences", game:GetService("HttpService"):JSONEncode({
    couts = CONFIG.COUTS,
    persos = COMPETENCES,
}))

local dossierGrimpeurs = creer("Folder", { Name = "Grimpeurs", Parent = ReplicatedStorage })
-- Les musiques proposées au vote (StringValue "1", "2", "3" : Value = nom, attributs Votes et Cle)
local dossierChoixMusiques = creer("Folder", { Name = "ChoixMusiques", Parent = ReplicatedStorage })
-- Les classements (un par état d'esprit, un par musique) : StringValue, attributs Type, Top1Nom, Top1Score
local dossierClassements = creer("Folder", { Name = "Classements", Parent = ReplicatedStorage })
dossierRemotes.Parent = ReplicatedStorage

-- 🎵 Marqueur de drop (touche B) : en Studio seulement, on partage la liste des musiques avec l'outil
if RunService:IsStudio() then
    local dossierTest = creer("Folder", { Name = "TesteurMusiques" })
    dossierTest:SetAttribute("DureeManche", CONFIG.DUREE_MANCHE)
    local numero = 0
    for _, m in ipairs(CONFIG.MUSIQUES) do
        if m.id == "" then
            continue -- pas encore mise en ligne
        end
        numero += 1
        local valeur = creer("StringValue", { Name = string.format("%02d", numero), Value = m.id, Parent = dossierTest })
        valeur:SetAttribute("Nom", m.nom or ("Musique " .. numero))
        valeur:SetAttribute("Bpm", m.bpm)
        valeur:SetAttribute("Debut", m.debut)
        valeur:SetAttribute("Drop", m.drop)
        valeur:SetAttribute("Decalage", m.decalage)
    end
    dossierTest.Parent = ReplicatedStorage
end

local function setPhase(phase)
    ReplicatedStorage:SetAttribute("Phase", phase)
end
local function setStatut(texte)
    ReplicatedStorage:SetAttribute("Statut", texte)
end
local function setTemps(secondes)
    ReplicatedStorage:SetAttribute("Temps", secondes)
end

-- on enlève les restes de l'ancien jeu (la scène 2D)
for _, nom in ipairs({ "MindsetScene", "MindsetEscalier", "MindsetDecor", "MindsetObstacles" }) do
    local vieux = workspace:FindFirstChild(nom)
    if vieux then
        vieux:Destroy()
    end
end

-- Lumière : nuit, escalier bien éclairé, néons qui brillent
Lighting.ClockTime = 0
Lighting.Brightness = 0
Lighting.Ambient = Color3.fromRGB(170, 170, 185)
Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 140)
local ancienBloom = Lighting:FindFirstChild("MindsetBloom")
if ancienBloom then
    ancienBloom:Destroy()
end
creer("BloomEffect", { Name = "MindsetBloom", Intensity = 1.2, Size = 30, Threshold = 0.85, Parent = Lighting })
-- ========================== SAUVEGARDE (DataStore) ==========================
-- ⚠️ Pour tester dans Studio : publie le jeu, puis
--    Paramètres du jeu > Sécurité > « Activer l'accès Studio aux services API ».
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

local HttpService = game:GetService("HttpService")
local reglagesJoueurs = {} -- [joueur] = { musique = 0..1, bruitages = 0..1, secousses = bool, flashs = bool }

-- 📊 Les stats du joueur.
--   En haut à droite (leaderstats) : TEMPS passé sur le jeu (en minutes), MARCHES gravies (au total), VICTOIRES.
--   Cachées (StatsCachees) : l'Aura (elle continue de monter et d'être sauvegardée) et les secondes déjà jouées.
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

-- secondes jouées au total = celles des fois d'avant (sauvegardées) + celles de maintenant
local function tempsTotal(joueur)
    local base = chercherStat(joueur, "Secondes")
    return (if base then base.Value else 0) + math.floor(os.clock() - (arrivees[joueur] or os.clock()))
end

-- le temps en haut à droite : juste un nombre, en minutes
local NOM_TEMPS = "Time (min)"
local function formatTemps(secondes)
    return secondes // 60
end

-- 🧠 Les niveaux de compétences de chaque joueur : [joueur] = { Motivation = {0, 0, 0}, Ego = {...}, ... }
local niveauxJoueurs = {}
local grimpeurDesJoueurs = {} -- [joueur] = config (voir GRIMPEURS plus bas)
local chargementFini = {} -- [joueur] = true quand ses données sont chargées (ou qu'il n'y a pas de sauvegarde)

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

-- on recopie les niveaux sauvegardés en vérifiant qu'ils sont corrects
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

local function finChargement(joueur, donnees)
    niveauxJoueurs[joueur] = lireNiveaux(donnees and donnees.niveaux)
    publierNiveaux(joueur)
    -- l'état d'esprit choisi la dernière fois
    local perso = donnees and donnees.perso
    if type(perso) == "string" and COMPETENCES[perso] and not joueur:GetAttribute("Perso") then
        joueur:SetAttribute("Perso", perso)
        local g = grimpeurDesJoueurs[joueur]
        if g and not g:GetAttribute("EnJeu") then
            g:SetAttribute("Perso", perso)
        end
    end
    -- 🎁 en Studio : de l'aura pour tester le marchand
    local aura = chercherStat(joueur, "Aura")
    if game:GetService("RunService"):IsStudio() and aura and aura.Value < CONFIG.AURA_CADEAU_STUDIO then
        aura.Value = CONFIG.AURA_CADEAU_STUDIO
    end
    chargementFini[joueur] = true
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
        chercherStat(joueur, "Wins").Value += donnees.victoires or 0
        chercherStat(joueur, "Steps").Value += donnees.marches or 0
        chercherStat(joueur, "Aura").Value += donnees.aura or 0
        chercherStat(joueur, "Secondes").Value += donnees.temps or 0
        chercherStat(joueur, NOM_TEMPS).Value = formatTemps(tempsTotal(joueur))
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
    if not donneesChargees[joueur] or not chercherStat(joueur, "Wins") then
        return
    end
    local victoires = chercherStat(joueur, "Wins").Value
    local marches = chercherStat(joueur, "Steps").Value
    local aura = chercherStat(joueur, "Aura").Value
    local temps = tempsTotal(joueur)
    local reglages = reglagesJoueurs[joueur]
    local niveaux = niveauxJoueurs[joueur]
    local perso = joueur:GetAttribute("Perso")
    essayer(function()
        sauvegarde:UpdateAsync("joueur_" .. joueur.UserId, function(anciennes)
            local donnees = anciennes or {}
            donnees.victoires = victoires
            donnees.marches = marches
            donnees.aura = aura
            donnees.temps = temps
            donnees.reglages = reglages or donnees.reglages
            donnees.niveaux = niveaux or donnees.niveaux
            donnees.perso = perso or donnees.perso
            return donnees
        end)
    end)
end

local function ajouterStat(joueur, nom, nombre)
    local valeur = chercherStat(joueur, nom)
    if valeur then
        valeur.Value += nombre
    end
end

-- le temps en haut à droite se met à jour toutes les 5 secondes
task.spawn(function()
    while true do
        task.wait(5)
        for joueur in pairs(arrivees) do
            local temps = chercherStat(joueur, NOM_TEMPS)
            if temps then
                temps.Value = formatTemps(tempsTotal(joueur))
            end
        end
    end
end)

-- ========================== L'ESCALIER INFINI ==========================
-- La marche n va de x = ORIGINE.X + n × PROFONDEUR à ORIGINE.X + (n + 1) × PROFONDEUR,
-- son dessus est à y = ORIGINE.Y + n × HAUTEUR. L'escalier monte vers +X, il est centré sur z = ORIGINE.Z.
-- Il est construit au fur et à mesure (toujours 150 marches devant le premier), et refait à chaque manche.
local D, H, W = CONFIG.PROFONDEUR, CONFIG.HAUTEUR, CONFIG.LARGEUR
local ORIGINE = Vector3.new(0, 50, 0) -- le dessus de la marche 0
for nom, valeur in pairs({ OrigineX = ORIGINE.X, OrigineY = ORIGINE.Y, OrigineZ = ORIGINE.Z, Profondeur = D, Hauteur = H, Largeur = W }) do
    ReplicatedStorage:SetAttribute("Escalier" .. nom, valeur)
end
ReplicatedStorage:SetAttribute("EscalierCheckpoint", CONFIG.CHECKPOINT)

local OR = Color3.fromRGB(255, 220, 80)
local COULEURS_LISERE = { PERSOS.Motivation.couleur, PERSOS.Ego.couleur, PERSOS.Discipline.couleur, PERSOS.Obsession.couleur }
local COULEUR_MARCHE = { Color3.fromRGB(238, 238, 246), Color3.fromRGB(222, 222, 234) }
local COULEUR_CASSANTE = Color3.fromRGB(110, 50, 35)

local function dessusMarche(n)
    return ORIGINE.Y + n * H
end
local function centreMarche(n)
    return Vector3.new(ORIGINE.X + (n + 0.5) * D, dessusMarche(n), ORIGINE.Z)
end
local function numeroSous(x)
    return math.floor((x - ORIGINE.X) / D)
end

local dossierEscalier = creer("Folder", { Name = "MindsetEscalier", Parent = workspace })
local dossierDecor = creer("Folder", { Name = "MindsetDecor", Parent = workspace })
local dossierObstacles = creer("Folder", { Name = "MindsetObstacles", Parent = workspace })

local function bloc(proprietes)
    proprietes.Anchored = true
    proprietes.TopSurface = Enum.SurfaceType.Smooth
    proprietes.BottomSurface = Enum.SurfaceType.Smooth
    proprietes.Material = proprietes.Material or Enum.Material.SmoothPlastic
    proprietes.Parent = proprietes.Parent or dossierEscalier
    return creer("Part", proprietes)
end
-- décor en néon : on passe à travers, on ne peut pas marcher dessus
local function neon(proprietes)
    proprietes.Material = Enum.Material.Neon
    proprietes.CanCollide = false
    proprietes.CanQuery = false
    proprietes.CanTouch = false
    proprietes.CastShadow = false
    return bloc(proprietes)
end
local function invisible(proprietes)
    proprietes.Transparency = 1
    proprietes.CastShadow = false
    proprietes.Parent = proprietes.Parent or dossierDecor
    return bloc(proprietes)
end
-- un texte sur une face d'une part
local function panneau(part, face, message, couleur, taille)
    local surface = creer("SurfaceGui", {
        Face = face,
        SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
        PixelsPerStud = taille or 30,
        LightInfluence = 0,
        Parent = part,
    })
    creer("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBlack,
        TextScaled = true,
        Text = message,
        TextColor3 = couleur,
        Parent = surface,
    })
    return surface
end

local marches = {} -- [n] = { type = "normal" / "trou" / "demi" / "cassante", cote = -1 ou 1, parts = {...} }
local derniereConstruite = -1
local hasard = Random.new()

local function typeDe(n)
    if n < CONFIG.ZONE_TRANQUILLE or n % CONFIG.CHECKPOINT <= 1 then
        return "normal"
    end
    local avant, avant2 = marches[n - 1], marches[n - 2]
    -- jamais deux pièges « à trou » collés : on doit toujours pouvoir passer
    local prudence = (avant and avant.type ~= "normal") or (avant2 and avant2.type == "trou")
    local k = math.clamp(n / 400, 0, 1)
    local function chance(p)
        return p[1] + (p[2] - p[1]) * k
    end
    local r = hasard:NextNumber()
    if not prudence then
        if r < chance(CONFIG.PIEGES.trou) then
            return "trou"
        end
        r -= chance(CONFIG.PIEGES.trou)
        if r < chance(CONFIG.PIEGES.demi) then
            return "demi"
        end
        r -= chance(CONFIG.PIEGES.demi)
    end
    if r < chance(CONFIG.PIEGES.cassante) then
        return "cassante"
    end
    return "normal"
end

local function construire(n)
    local t = typeDe(n)
    local m = { type = t, cote = if hasard:NextNumber() < 0.5 then -1 else 1, parts = {} }
    marches[n] = m
    local centre = centreMarche(n)
    local couleur = COULEUR_MARCHE[n % 2 + 1]
    if t == "demi" then
        table.insert(m.parts, bloc({
            Name = "Marche" .. n,
            Size = Vector3.new(D, 4, W / 2),
            CFrame = CFrame.new(centre + Vector3.new(0, -2, m.cote * W / 4)),
            Color = couleur,
        }))
    elseif t ~= "trou" then
        table.insert(m.parts, bloc({
            Name = "Marche" .. n,
            Size = Vector3.new(D, 4, W),
            CFrame = CFrame.new(centre - Vector3.new(0, 2, 0)),
            Color = if t == "cassante" then COULEUR_CASSANTE else couleur,
            Material = if t == "cassante" then Enum.Material.CrackedLava else Enum.Material.SmoothPlastic,
        }))
    end
    -- tous les 10 : un liseré de couleur et le numéro ; tous les 50 : en or (checkpoint de la DISCIPLINE)
    if n > 0 and n % 10 == 0 and m.parts[1] then
        local checkpoint = n % CONFIG.CHECKPOINT == 0
        local couleurLisere = if checkpoint then OR else COULEURS_LISERE[(n // 10) % 4 + 1]
        table.insert(m.parts, neon({
            Name = "Lisere" .. n,
            Size = Vector3.new(0.3, 0.12, m.parts[1].Size.Z),
            CFrame = CFrame.new(Vector3.new(ORIGINE.X + n * D + 0.15, dessusMarche(n) + 0.06, m.parts[1].Position.Z)),
            Color = couleurLisere,
        }))
        panneau(m.parts[1], Enum.NormalId.Left, tostring(n), if checkpoint then OR else Color3.fromRGB(90, 90, 110), 12)
    end
    -- les rambardes néon sur les deux bords (une tous les 10 marches)
    if n % 10 == 0 then
        local debut = Vector3.new(ORIGINE.X + n * D, dessusMarche(n) + 0.8, 0)
        local fin = Vector3.new(ORIGINE.X + (n + 10) * D, dessusMarche(n + 10) + 0.8, 0)
        local longueur = (fin - debut).Magnitude
        for _, z in ipairs({ -W / 2, W / 2 }) do
            local milieu = (debut + fin) / 2 + Vector3.new(0, 0, z + ORIGINE.Z)
            table.insert(m.parts, neon({
                Name = "Rambarde" .. n,
                Size = Vector3.new(longueur, 0.25, 0.25),
                CFrame = CFrame.lookAt(milieu, milieu + (fin - debut)) * CFrame.Angles(0, math.pi / 2, 0),
                Color = COULEURS_LISERE[(n // 10) % 4 + 1],
                Transparency = 0.2,
            }))
        end
    end
end

-- construit l'escalier jusqu'à la marche n
local function etendre(n)
    for k = derniereConstruite + 1, n do
        construire(k)
    end
    derniereConstruite = math.max(derniereConstruite, n)
end

-- nouvelle manche : nouvel escalier (les pièges ne sont jamais aux mêmes endroits)
local function reconstruire()
    dossierEscalier:ClearAllChildren()
    dossierObstacles:ClearAllChildren()
    marches = {}
    derniereConstruite = -1
    hasard = Random.new()
    etendre(200)
end

-- la marche sûre (pleine, pas cassée) la plus proche en dessous de n : pour réapparaître après une chute
local function marcheSure(n)
    for k = math.max(0, n), 0, -1 do
        local m = marches[k]
        if m and m.type == "normal" and not m.casse then
            return k
        end
    end
    return 0
end

-- une marche de lave craquelée : elle rougit, casse, puis revient 3 s plus tard
local function casser(n)
    local m = marches[n]
    if not m or m.type ~= "cassante" or m.craque then
        return
    end
    m.craque = true
    local part = m.parts[1]
    TweenService:Create(part, TweenInfo.new(0.5), { Color = Color3.fromRGB(255, 70, 30) }):Play()
    task.delay(0.55, function()
        if marches[n] ~= m then
            return
        end
        m.casse = true
        part.CanCollide = false
        part.Transparency = 1
        task.delay(3, function()
            if marches[n] == m then
                m.casse, m.craque = false, false
                part.Color = COULEUR_CASSANTE
                part.Transparency = 0
                part.CanCollide = true
            end
        end)
    end)
end

-- ---------- LE DÉPART : la plateforme, la barrière, l'arche ----------
local DEPART_LONGUEUR = 40
local barriere
do
    local largeurDepart = W + 10
    bloc({
        Name = "Depart",
        Size = Vector3.new(DEPART_LONGUEUR, 4, largeurDepart),
        CFrame = CFrame.new(ORIGINE.X - DEPART_LONGUEUR / 2, ORIGINE.Y - 2, ORIGINE.Z),
        Color = Color3.fromRGB(28, 26, 42),
        Parent = dossierDecor,
    })
    for _, z in ipairs({ -largeurDepart / 2, largeurDepart / 2 }) do
        neon({ Size = Vector3.new(DEPART_LONGUEUR, 0.15, 0.4), CFrame = CFrame.new(ORIGINE.X - DEPART_LONGUEUR / 2, ORIGINE.Y + 0.05, ORIGINE.Z + z), Color = OR, Parent = dossierDecor })
        -- murs invisibles sur les côtés
        invisible({ Size = Vector3.new(DEPART_LONGUEUR, 30, 1), CFrame = CFrame.new(ORIGINE.X - DEPART_LONGUEUR / 2, ORIGINE.Y + 15, ORIGINE.Z + z) })
    end
    invisible({ Size = Vector3.new(1, 30, largeurDepart), CFrame = CFrame.new(ORIGINE.X - DEPART_LONGUEUR, ORIGINE.Y + 15, ORIGINE.Z) })
    -- la barrière du départ (elle disparaît au GO)
    barriere = bloc({
        Name = "Barriere",
        Size = Vector3.new(0.6, 14, W),
        CFrame = CFrame.new(ORIGINE.X - 0.6, ORIGINE.Y + 7, ORIGINE.Z),
        Material = Enum.Material.ForceField,
        Color = OR,
        Parent = dossierDecor,
    })
    -- l'arche « CLIMB »
    for _, z in ipairs({ -W / 2 - 1, W / 2 + 1 }) do
        neon({ Size = Vector3.new(1, 16, 1), CFrame = CFrame.new(ORIGINE.X - 1, ORIGINE.Y + 8, ORIGINE.Z + z), Color = OR, Parent = dossierDecor })
    end
    local fronton = bloc({
        Name = "Fronton",
        Size = Vector3.new(1, 3, W + 3),
        CFrame = CFrame.new(ORIGINE.X - 1, ORIGINE.Y + 17, ORIGINE.Z),
        Color = Color3.fromRGB(18, 16, 28),
        CanCollide = false,
        Parent = dossierDecor,
    })
    panneau(fronton, Enum.NormalId.Left, "CLIMB", OR, 30)
end

-- ---------- LA TRIBUNE : ceux qui ne courent pas regardent d'ici ----------
local TRIBUNE = Vector3.new(ORIGINE.X - 20, ORIGINE.Y + 8, ORIGINE.Z + W / 2 + 16) -- le dessus de la tribune
do
    bloc({ Name = "Tribune", Size = Vector3.new(24, 1, 8), CFrame = CFrame.new(TRIBUNE - Vector3.new(0, 0.5, 0)), Color = Color3.fromRGB(28, 26, 42), Parent = dossierDecor })
    neon({ Size = Vector3.new(24, 0.3, 0.3), CFrame = CFrame.new(TRIBUNE + Vector3.new(0, 1, -4)), Color = OR, Parent = dossierDecor })
end

-- ---------- LA SCÈNE DU VAINQUEUR (loin de tout, la caméra de tout le monde y va à la fin) ----------
local SCENE = Vector3.new(ORIGINE.X - 160, ORIGINE.Y + 60, ORIGINE.Z) -- le dessus de la scène, au centre
ReplicatedStorage:SetAttribute("SceneCamera", CFrame.lookAt(SCENE + Vector3.new(0, 4.5, 21), SCENE + Vector3.new(0, 3.2, 0)))
do
    bloc({
        Name = "Scene",
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(2, 22, 22),
        CFrame = CFrame.new(SCENE - Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
        Color = Color3.fromRGB(14, 12, 22),
        Parent = dossierDecor,
    })
    for i, rayon in ipairs({ 11, 8, 5 }) do
        neon({
            Shape = Enum.PartType.Cylinder,
            Size = Vector3.new(0.1, rayon * 2, rayon * 2),
            CFrame = CFrame.new(SCENE + Vector3.new(0, 0.01 * i, 0)) * CFrame.Angles(0, 0, math.pi / 2),
            Color = COULEURS_LISERE[i],
            Transparency = 0.55,
            Parent = dossierDecor,
        })
    end
    -- le mur du fond, noir, avec 4 bandes de couleur
    bloc({ Name = "Fond", Size = Vector3.new(60, 40, 1), CFrame = CFrame.new(SCENE + Vector3.new(0, 15, -9)), Color = Color3.fromRGB(6, 6, 10), CanCollide = false, Parent = dossierDecor })
    for i, couleur in ipairs(COULEURS_LISERE) do
        neon({ Size = Vector3.new(0.6, 40, 0.3), CFrame = CFrame.new(SCENE + Vector3.new(-9 + (i - 1) * 6, 15, -8.4)), Color = couleur, Transparency = 0.3, Parent = dossierDecor })
    end
    -- deux projecteurs
    for _, x in ipairs({ -8, 8 }) do
        local projecteur = invisible({ Size = Vector3.new(1, 1, 1), CFrame = CFrame.lookAt(SCENE + Vector3.new(x, 14, 8), SCENE + Vector3.new(0, 2, 0)) })
        creer("SpotLight", { Face = Enum.NormalId.Front, Angle = 35, Range = 40, Brightness = 6, Color = Color3.fromRGB(255, 240, 220), Parent = projecteur })
    end
end

-- ========================== LE HUB (la place où on se balade) ==========================
-- La déco est construite par chaque client (script MindsetHub). Le serveur pose juste un sol et
-- un mur invisibles, pour qu'on ne tombe jamais (même avant que la déco soit chargée).
-- ⚠️ Mêmes nombres que dans MindsetHub : O = (-3000, 400, 0), place de 118 de large.
local HUB_O = Vector3.new(-3000, 400, 0)
local HUB_SOL = HUB_O.Y + 0.5
do
    local dossierHub = creer("Folder", { Name = "MindsetHubSol", Parent = workspace })
    local function invisible(proprietes)
        proprietes.Anchored = true
        proprietes.CanCollide = true
        proprietes.Transparency = 1
        proprietes.CastShadow = false
        proprietes.Parent = dossierHub
        return creer("Part", proprietes)
    end
    invisible({ Name = "Sol", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 118, 118), CFrame = CFrame.new(HUB_O) * CFrame.Angles(0, 0, math.pi / 2) })
    for i = 0, 47 do
        local a = i / 48 * math.pi * 2
        local position = Vector3.new(HUB_O.X + math.cos(a) * 58, HUB_SOL + 12, HUB_O.Z + math.sin(a) * 58)
        invisible({ Name = "Mur", Size = Vector3.new(2, 24, 2 * math.pi * 58 / 48 * 1.1), CFrame = CFrame.lookAt(position, position + Vector3.new(-math.sin(a), 0, math.cos(a))) })
    end
end

-- Met l'avatar d'un joueur sur la place du hub : il peut marcher et sauter
local function placerAuHub(joueur, modele)
    local racine = modele:WaitForChild("HumanoidRootPart", 10)
    local humanoid = modele:WaitForChild("Humanoid", 10)
    if not racine or not humanoid then
        return
    end
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- le hub affiche sa propre étiquette
    humanoid.UseJumpPower = false
    humanoid.WalkSpeed = 16
    humanoid.JumpHeight = 7.2
    humanoid.JumpPower = 50
    local hauteur = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight + racine.Size.Y / 2 else 3
    local position = Vector3.new(HUB_O.X + math.random(-8, 8), HUB_SOL + hauteur + 0.2, HUB_O.Z + 6 + math.random(0, 4))
    modele:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, -1))) -- tourné vers le portail
    racine.AssemblyLinearVelocity = Vector3.zero
    racine.Anchored = false
    pcall(function()
        racine:SetNetworkOwner(joueur)
    end)
end

-- ========================== GRIMPEURS ==========================
-- Chaque grimpeur (joueur ou bot) = une Configuration dans ReplicatedStorage.Grimpeurs, avec ses attributs :
--   Nom, Perso, Marche (sa marche maintenant), Rang, Vitesse, Chutes, NiveauAura (série sans tomber),
--   EnJeu (il court), Pret (il a passé le portail PLAY), Hub (il se balade dans le hub), Bot, UserId,
--   DoubleSaut (l'EGO), Danse / AuraFarmee (la danse du gagnant), Scene (sa place sur la scène de fin)
local joueurDuGrimpeur = {}   -- [config] = joueur
local compteurOrdre = 0
local manche = nil            -- la course en cours (voir RÈGLES et BOUCLE DU JEU)

local function nouveauGrimpeur(nom, perso, modele, joueur)
    compteurOrdre += 1
    local g = Instance.new("Configuration")
    g.Name = nom
    g:SetAttribute("Nom", nom)
    g:SetAttribute("Perso", perso)
    g:SetAttribute("Marche", 0)
    g:SetAttribute("Rang", 0)
    g:SetAttribute("Vitesse", 16)
    g:SetAttribute("Chutes", 0)
    g:SetAttribute("NiveauAura", 0)
    g:SetAttribute("EnJeu", false)
    g:SetAttribute("Ordre", compteurOrdre)
    g:SetAttribute("Bot", joueur == nil)
    g:SetAttribute("Pret", joueur == nil) -- un joueur doit d'abord passer le portail PLAY
    g:SetAttribute("UserId", if joueur then joueur.UserId else 0)
    creer("ObjectValue", { Name = "Modele", Value = modele, Parent = g })
    g.Parent = dossierGrimpeurs
    return g
end

local function hauteurRacine(modele)
    local humanoid = modele:FindFirstChildOfClass("Humanoid")
    local racine = modele:FindFirstChild("HumanoidRootPart")
    if humanoid and racine and humanoid.RigType == Enum.HumanoidRigType.R15 then
        return humanoid.HipHeight + racine.Size.Y / 2
    end
    return 3
end

-- pose un avatar à un endroit ; ancre = true : il ne peut plus bouger (tribune, scène de fin)
local function placer(modele, cf, ancre, joueur)
    local racine = modele:FindFirstChild("HumanoidRootPart")
    if not racine then
        return
    end
    modele:PivotTo(cf)
    racine.AssemblyLinearVelocity = Vector3.zero
    racine.Anchored = ancre
    if not ancre then
        pcall(function()
            racine:SetNetworkOwner(joueur) -- (nil pour un bot : c'est le serveur qui le fait bouger)
        end)
    end
end

local function preparerHumanoid(modele)
    local racine = modele:WaitForChild("HumanoidRootPart", 10)
    local humanoid = modele:WaitForChild("Humanoid", 10)
    if not racine or not humanoid then
        return nil
    end
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- on affiche notre propre étiquette
    humanoid.UseJumpPower = false
    humanoid.WalkSpeed = 16
    humanoid.JumpHeight = CONFIG.SAUT
    return humanoid
end

-- sur la plateforme de départ (derrière la barrière)
local function placerAuDepart(modele, joueur)
    if not preparerHumanoid(modele) then
        return
    end
    local position = Vector3.new(
        ORIGINE.X - 6 - math.random() * (DEPART_LONGUEUR - 12),
        ORIGINE.Y + hauteurRacine(modele) + 0.3,
        ORIGINE.Z + (math.random() - 0.5) * (W - 6)
    )
    placer(modele, CFrame.lookAt(position, position + Vector3.new(1, 0, 0)), false, joueur)
end

-- dans la tribune (il regarde la course sans courir)
local function placerEnTribune(modele, joueur)
    if not preparerHumanoid(modele) then
        return
    end
    local position = TRIBUNE + Vector3.new((math.random() - 0.5) * 20, hauteurRacine(modele) + 0.05, (math.random() - 0.5) * 4)
    placer(modele, CFrame.lookAt(position, position + Vector3.new(0.6, 0, -1)), true, joueur)
end

-- sur la marche n (après une chute) : on garde à peu près sa place sur la largeur
local function placerSurMarche(modele, joueur, n)
    local racine = modele:FindFirstChild("HumanoidRootPart")
    if not racine then
        return
    end
    local z = math.clamp(racine.Position.Z, ORIGINE.Z - W / 2 + 3, ORIGINE.Z + W / 2 - 3)
    local centre = centreMarche(n)
    local position = Vector3.new(centre.X, centre.Y + hauteurRacine(modele) + 0.4, z)
    placer(modele, CFrame.lookAt(position, position + Vector3.new(1, 0, 0)), false, joueur)
end

local chute -- (définie plus bas, partie RÈGLES)

local function joueurArrive(joueur)
    arrivees[joueur] = os.clock()
    -- en haut à droite, dans cet ordre : TEMPS, MARCHES, VICTOIRES
    local stats = Instance.new("Folder")
    stats.Name = "leaderstats"
    creer("IntValue", { Name = NOM_TEMPS, Parent = stats })
    creer("IntValue", { Name = "Steps", Parent = stats })
    creer("IntValue", { Name = "Wins", Parent = stats })
    stats.Parent = joueur
    local cachees = creer("Folder", { Name = "StatsCachees", Parent = joueur })
    creer("IntValue", { Name = "Aura", Parent = cachees })
    creer("IntValue", { Name = "Secondes", Parent = cachees })

    local g = nouveauGrimpeur(joueur.DisplayName, nil, joueur.Character, joueur)
    g:SetAttribute("Hub", true) -- au début, on se balade dans le hub
    grimpeurDesJoueurs[joueur] = g
    joueurDuGrimpeur[g] = joueur
    task.spawn(chargerJoueur, joueur) -- (après le grimpeur : on lui remet son état d'esprit sauvegardé)

    local function surPersonnage(personnage)
        g.Modele.Value = personnage
        if g:GetAttribute("Hub") then
            placerAuHub(joueur, personnage)
        elseif g:GetAttribute("EnJeu") and manche and manche.stats[g] then
            -- il est mort / a fait « Réinitialiser » en pleine course : comme une chute
            if preparerHumanoid(personnage) then
                chute(g, personnage, manche.stats[g])
            end
        elseif ReplicatedStorage:GetAttribute("Phase") == "Lobby" and g:GetAttribute("Pret") then
            placerAuDepart(personnage, joueur)
        else
            placerEnTribune(personnage, joueur)
        end
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
    donneesChargees[joueur] = nil
    reglagesJoueurs[joueur] = nil
    niveauxJoueurs[joueur] = nil
    chargementFini[joueur] = nil
    arrivees[joueur] = nil
    local g = grimpeurDesJoueurs[joueur]
    if g then
        joueurDuGrimpeur[g] = nil
        g:Destroy()
    end
    grimpeurDesJoueurs[joueur] = nil
end)

game:BindToClose(function()
    local restants = 0
    for _, joueur in ipairs(Players:GetPlayers()) do
        restants += 1
        task.spawn(function()
            sauverJoueur(joueur)
            restants -= 1
        end)
    end
    while restants > 0 do
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

-- PLAY (true)  : le joueur sort du hub et participe aux prochaines courses (il va au départ, ou en tribune
--                si une course est déjà lancée : il jouera la suivante).
-- AFK (false)  : il regarde depuis la tribune, sans courir.
-- "Hub"        : retour sur la place du hub.
JouerEvent.OnServerEvent:Connect(function(joueur, participe)
    local g = grimpeurDesJoueurs[joueur]
    if not g then
        return
    end
    local personnage = joueur.Character
    if participe == "Hub" then
        g:SetAttribute("Pret", false)
        g:SetAttribute("EnJeu", false) -- (s'il courait, il abandonne la course)
        if not g:GetAttribute("Hub") then
            g:SetAttribute("Hub", true)
            if personnage then
                task.spawn(placerAuHub, joueur, personnage)
            end
        end
        return
    end
    g:SetAttribute("Pret", participe ~= false)
    g:SetAttribute("Hub", false)
    if not personnage or g:GetAttribute("EnJeu") then
        return -- il court déjà : on ne le déplace pas
    end
    if participe ~= false and ReplicatedStorage:GetAttribute("Phase") == "Lobby" then
        task.spawn(placerAuDepart, personnage, joueur)
    else
        task.spawn(placerEnTribune, personnage, joueur)
    end
end)

-- PARAMÈTRES : on garde les réglages du joueur (sauvegardés avec ses victoires et son aura)
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
        -- langue : "auto" (celle de Roblox), "en" ou "fr"
        langue = if reglages.langue == "en" or reglages.langue == "fr" then reglages.langue else "auto",
    }
end)

ChoisirEvent.OnServerEvent:Connect(function(joueur, perso)
    if not PERSOS[perso] then
        return
    end
    local g = grimpeurDesJoueurs[joueur]
    if not g or g:GetAttribute("EnJeu") then
        return -- on ne change pas de perso en pleine manche
    end
    g:SetAttribute("Perso", perso)
    joueur:SetAttribute("Perso", perso)
end)

-- 🛒 LE MARCHAND : acheter le niveau suivant d'une compétence avec son aura.
-- Renvoie ok (true/false), puis le nouveau niveau ou la raison du refus.
-- (un achat en pleine manche ne compte qu'à partir de la manche suivante)
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
Players.PlayerRemoving:Connect(function(parti)
    achatEnCours[parti] = nil
end)

-- ========================== BOTS ==========================
local dossierBots = creer("Folder", { Name = "Bots", Parent = workspace })
local PEAUX = {
    Color3.fromRGB(255, 224, 189), Color3.fromRGB(255, 205, 148), Color3.fromRGB(234, 192, 134),
    Color3.fromRGB(198, 134, 66), Color3.fromRGB(141, 85, 36), Color3.fromRGB(90, 56, 37),
}
local PANTALONS = {
    Color3.fromRGB(30, 40, 70), Color3.fromRGB(40, 40, 40), Color3.fromRGB(90, 70, 50),
    Color3.fromRGB(60, 90, 140), Color3.fromRGB(110, 110, 120),
}
local PRENOMS = { "Lucas", "Emma", "Noah", "Lina", "Adam", "Jade", "Nathan", "Mia", "Enzo", "Chloe", "Sacha", "Ines", "Leo", "Zoe", "Hugo", "Lea", "Max", "Sara" }
local MOTS = { "Gamer", "Pro", "Speed", "Dark", "Shadow", "King", "Queen", "Ninja", "Flash", "Noob", "Turbo", "Dragon", "Wolf", "Blox", "Star" }

local function auHasard(liste)
    return liste[math.random(1, #liste)]
end

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

local function creerBot(perso)
    local ok, modele = pcall(function()
        local peau = auHasard(PEAUX)
        local tshirt = PERSOS[perso].couleur
        local bras = if math.random() < 0.5 then peau else tshirt
        local jambes = auHasard(PANTALONS)
        local description = Instance.new("HumanoidDescription")
        description.HeadColor = peau
        description.TorsoColor = tshirt
        description.LeftArmColor = bras
        description.RightArmColor = bras
        description.LeftLegColor = jambes
        description.RightLegColor = jambes
        return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
    end)
    if not ok or not modele then
        warn("Impossible de créer un bot :", modele)
        return nil
    end
    local pseudo = pseudoDeBot()
    modele.Name = pseudo
    local animate = modele:FindFirstChild("Animate")
    if animate then
        animate:Destroy()
    end
    modele.Parent = dossierBots
    return modele, pseudo
end

-- 🛒 Le MARCHAND D'AURA du menu 3D : un avatar Roblox tout en noir et violet.
-- Le serveur le fabrique (seul le serveur peut créer un avatar), chaque client en pose une copie dans son menu.
task.spawn(function()
    local ok, modele = pcall(function()
        local description = Instance.new("HumanoidDescription")
        local peau = Color3.fromRGB(40, 32, 52)
        local habit = Color3.fromRGB(28, 18, 44)
        description.HeadColor = peau
        description.TorsoColor = habit
        description.LeftArmColor = habit
        description.RightArmColor = habit
        description.LeftLegColor = Color3.fromRGB(18, 14, 26)
        description.RightLegColor = Color3.fromRGB(18, 14, 26)
        return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
    end)
    if not ok or not modele then
        warn("🛒 Impossible de créer le marchand :", modele)
        return
    end
    modele.Name = "MindsetMarchand"
    for _, objet in ipairs(modele:GetDescendants()) do
        if objet:IsA("Script") or objet:IsA("LocalScript") then
            objet:Destroy()
        end
    end
    modele.Parent = ReplicatedStorage
end)


-- ========================== RÈGLES DES ÉTATS D'ESPRIT ==========================
-- Sans compétence : MOTIVATION ralentit, OBSESSION accélère, EGO tombe de plus haut (mais double saut),
-- DISCIPLINE perd peu en tombant (checkpoints). Les compétences du marchand renforcent tout ça.
-- Les niveaux sont « figés » au début de la course (manche.niveaux).

-- la valeur de la compétence n° numero du grimpeur (ou nil s'il ne l'a pas encore achetée)
local function competence(g, numero)
    local perso = g:GetAttribute("Perso")
    local niveaux = manche and manche.niveaux[g]
    local niveau = niveaux and niveaux[numero] or 0
    local def = COMPETENCES[perso] and COMPETENCES[perso][numero]
    if not def or niveau <= 0 then
        return nil
    end
    return def.valeurs[math.min(niveau, #def.valeurs)]
end

-- donne de l'aura à un joueur (DISCIPLINE « HARD WORK » : un bonus en %)
local function donnerAura(joueur, g, montant)
    if not joueur or montant <= 0 then
        return
    end
    local bonus = if g:GetAttribute("Perso") == "Discipline" then competence(g, 3) else nil
    if bonus then
        local total = montant * (1 + bonus / 100)
        montant = math.floor(total) + (if math.random() < total % 1 then 1 else 0)
    end
    ajouterStat(joueur, "Aura", montant)
    local stats = manche and manche.stats[g]
    if stats then
        stats.aura += montant
    end
end

-- la vitesse du grimpeur à ce moment de la course (progression : 0 = départ, 1 = fin)
local function vitesseDe(g, progression, ecoule, rang)
    local perso = g:GetAttribute("Perso")
    local v = CONFIG.VITESSE[perso] or { debut = 16, fin = 16 }
    local vitesse
    if perso == "Obsession" then
        -- lent au début, puis ça monte de plus en plus vite
        local fin = v.fin + (competence(g, 1) or 0) -- LATE MONSTER
        vitesse = v.debut + (fin - v.debut) * progression ^ 1.4
        local rush = competence(g, 3) -- FINAL RUSH
        if rush and CONFIG.DUREE_MANCHE - ecoule <= rush then
            vitesse *= 1.3
        end
    else
        vitesse = v.debut + (v.fin - v.debut) * progression
    end
    if perso == "Motivation" then
        local feu = competence(g, 2) -- FIRE START
        if feu and progression < 0.3 then
            vitesse *= 1 + feu / 100
        end
        local souffle = competence(g, 3) -- SECOND WIND
        local milieu = CONFIG.DUREE_MANCHE / 2
        if souffle and ecoule >= milieu and ecoule < milieu + souffle then
            vitesse *= 1.35
        end
    elseif perso == "Ego" then
        local projecteur = competence(g, 2) -- SPOTLIGHT
        if projecteur and rang == 1 then
            vitesse *= 1 + projecteur / 100
        end
    elseif perso == "Discipline" then
        local routine = competence(g, 2) -- ROUTINE
        if routine then
            vitesse *= 1 + routine / 100
        end
    end
    return vitesse
end

local function niveauAuraDe(serie)
    return if serie >= 300 then 3 elseif serie >= 150 then 2 elseif serie >= 60 then 1 else 0
end

-- 💀 UNE CHUTE : on réapparaît plus bas (combien plus bas : ça dépend de l'état d'esprit)
chute = function(g, modele, s)
    local maintenant = os.clock()
    if maintenant < (s.protege or 0) then
        return
    end
    local perso = g:GetAttribute("Perso")
    local depuis = s.sol or 0
    local perte = CONFIG.CHUTE
    if perso == "Ego" then
        perte = CONFIG.CHUTE_EGO
        local bouclier = competence(g, 3) -- THICK SKIN
        if bouclier and s.chutes < bouclier then
            perte = math.floor(CONFIG.CHUTE_EGO / 2)
        end
    end
    local cible = math.max(0, depuis - perte)
    local checkpoint = false
    if perso == "Discipline" then
        local tous = competence(g, 1) or CONFIG.CHECKPOINT -- IRON WILL
        local dernier = math.floor(depuis / tous) * tous
        cible = math.max(dernier, depuis - CONFIG.CHUTE_DISCIPLINE)
        checkpoint = cible == dernier and dernier > 0
    end
    cible = marcheSure(cible)
    s.chutes += 1
    s.sol = cible
    s.departSerie = cible
    s.protege = maintenant + 1.5
    g:SetAttribute("Chutes", s.chutes)
    g:SetAttribute("Marche", cible)
    g:SetAttribute("NiveauAura", 0)
    placerSurMarche(modele, joueurDuGrimpeur[g], cible)
    EvenementEvent:FireAllClients("Chute", g, depuis - cible, checkpoint)
end

-- ---------- LES BOTS ----------
-- Ils courent tout droit, sautent les trous, changent de côté devant une demi-marche...
-- et ratent parfois (adresse = la chance de bien réagir à un piège).
local ANIMS_BOT = {
    course = "rbxassetid://913376220", -- les animations R15 de base de Roblox
    attente = "rbxassetid://507766388",
    saut = "rbxassetid://507765000",
    chute = "rbxassetid://507767968",
}
local infosBots = {} -- [config] = { adresse, z, decisions = {[n] = true/false} }

local function animerBot(modele)
    local humanoid = modele:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end
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

local function preparerBot(g, modele)
    local humanoid = preparerHumanoid(modele)
    if not humanoid then
        return
    end
    infosBots[g] = {
        adresse = 0.8 + math.random() * 0.17,
        z = (math.random() - 0.5) * (W - 8),
        decisions = {},
    }
    animerBot(modele)
    placerAuDepart(modele, nil)
end

-- un bot réagit-il bien au piège de la marche n ? (décidé une seule fois par piège)
local function botReussit(info, n)
    if info.decisions[n] == nil then
        info.decisions[n] = math.random() < info.adresse
    end
    return info.decisions[n]
end

local function piloterBot(g, modele)
    local info = infosBots[g]
    local humanoid = modele:FindFirstChildOfClass("Humanoid")
    local racine = modele:FindFirstChild("HumanoidRootPart")
    if not info or not humanoid or not racine or racine.Anchored then
        return
    end
    local p = racine.Position
    local n = math.max(0, numeroSous(p.X))
    local zVoulu = info.z
    for k = 1, 4 do
        local m = marches[n + k]
        if m then
            if m.type == "demi" and botReussit(info, n + k) then
                zVoulu = m.cote * W / 4 -- du côté où il reste une moitié de marche
            elseif m.type == "trou" and k <= 2 and botReussit(info, n + k) then
                humanoid.Jump = true
            end
        end
    end
    humanoid:MoveTo(Vector3.new(p.X + 14, p.Y, ORIGINE.Z + zVoulu))
end

-- ========================== DANSE DU GAGNANT (farm d'aura) ==========================
-- À la fin, le(s) premier(s) dansent : chaque clic / Espace = un pas de danse = de l'aura.
local danse = nil -- { gagnants = {[config] = true}, fin = heure serveur, dernier = {[config] = os.clock()} }

local function pasDeDanse(g)
    local n = (g:GetAttribute("AuraFarmee") or 0) + 1
    g:SetAttribute("AuraFarmee", n)
    g:SetAttribute("Danse", 1 + math.floor(n / 10) % 3) -- change de danse tous les 10 pas
    local joueurDanseur = joueurDuGrimpeur[g]
    if joueurDanseur then
        ajouterStat(joueurDanseur, "Aura", CONFIG.AURA_PAR_PAS)
    end
end

DanserEvent.OnServerEvent:Connect(function(danseur)
    local g = grimpeurDesJoueurs[danseur]
    if not danse or not g or not danse.gagnants[g] or workspace:GetServerTimeNow() > danse.fin then
        return
    end
    local maintenant = os.clock()
    if maintenant - (danse.dernier[g] or 0) < 0.08 then
        return -- max ~12 pas par seconde, pas d'autoclicker
    end
    danse.dernier[g] = maintenant
    pasDeDanse(g)
end)


-- ========================== CLASSEMENTS (records de marches) ==========================
-- Un classement par état d'esprit (toutes musiques) et un par musique (tous états d'esprit).
-- Le score = le plus de marches montées en UNE partie. Sauvegardé dans des OrderedDataStore
-- (il faut publier le jeu) ; sans ça, on garde quand même les records de la session du serveur.
local tableaux = {} -- [cle] = { store, session = {[userId] = score}, charges = {[userId] = true}, cache, cacheA, valeur }
local alerteClassement = false

local function cleMusique(m)
    return "M_" .. (string.match(m.id, "%d+") or string.gsub(m.nom or "?", "%W", ""))
end

-- typeTableau = "Perso" / "Musique" : il a son onglet dans le panneau ; nil = classement « caché »
-- (combinaison état d'esprit + musique, ou monde entier) qu'on demande avec sa clé.
local function creerTableau(cle, nom, typeTableau)
    local t = { session = {}, charges = {}, cache = nil, cacheA = -math.huge }
    local ok, store = pcall(function()
        -- (nom court pour les combinaisons : Roblox limite les noms à 50 caractères)
        return DataStoreService:GetOrderedDataStore(if typeTableau then "MindsetStairs_Record_" .. cle else "MSR_" .. cle)
    end)
    if ok then
        t.store = store
    end
    tableaux[cle] = t
    if not typeTableau then
        return
    end
    local valeur = Instance.new("StringValue")
    valeur.Name = cle
    valeur.Value = nom
    valeur:SetAttribute("Type", typeTableau)
    valeur:SetAttribute("Top1Nom", "")
    valeur:SetAttribute("Top1Score", 0)
    valeur.Parent = dossierClassements
    t.valeur = valeur
    tableaux[cle] = t
end
for ordre, perso in ipairs(ORDRE_PERSOS) do
    creerTableau("P_" .. perso, string.upper(perso), "Perso")
    tableaux["P_" .. perso].valeur:SetAttribute("Ordre", ordre)
end
for ordre, m in ipairs(CONFIG.MUSIQUES) do
    if m.id ~= "" and not tableaux[cleMusique(m)] then
        creerTableau(cleMusique(m), m.nom or ("Song " .. ordre), "Musique")
        tableaux[cleMusique(m)].valeur:SetAttribute("Ordre", ordre)
    end
end
-- 🌍 le classement du MONDE ENTIER (toutes musiques, tous états d'esprit)
creerTableau("G", "WORLDWIDE", nil)
-- 🪜 le classement du TOTAL de marches montées (toutes les parties additionnées = « Steps » en haut à droite)
creerTableau("T", "TOTAL STEPS", nil)
-- un classement pour chaque combinaison état d'esprit + musique (clé « C_Ego_M_123... »)
local function cleCombo(perso, cleM)
    return "C_" .. perso .. "_" .. cleM
end
for _, perso in ipairs(ORDRE_PERSOS) do
    for _, m in ipairs(CONFIG.MUSIQUES) do
        if m.id ~= "" and not tableaux[cleCombo(perso, cleMusique(m))] then
            creerTableau(cleCombo(perso, cleMusique(m)), perso .. " + " .. (m.nom or "?"), nil)
        end
    end
end

local function alerte(erreur)
    if not alerteClassement then
        alerteClassement = true
        warn("🏆 Classements : sauvegarde indisponible (publie le jeu + accès Studio aux services API). On garde les records de la session. ", erreur)
    end
end

local nomsCache = {}
local function nomDe(userId)
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

-- 🌍 Pour le classement MONDE ENTIER, on garde aussi avec quel état d'esprit et quelle musique
-- chaque record a été fait (un DataStore à part : un classement ne peut garder qu'un nombre).
local storeDetails = nil
do
    local ok, store = pcall(function()
        return DataStoreService:GetDataStore("MindsetStairs_RecordMonde_Details")
    end)
    if ok then
        storeDetails = store
    end
end
local detailsCache = {} -- [userId] = { perso, musique } ou false (= rien de sauvegardé)

local function detailsMonde(userId)
    if detailsCache[userId] == nil and storeDetails then
        local ok, details = pcall(function()
            return storeDetails:GetAsync(tostring(userId))
        end)
        detailsCache[userId] = if ok and type(details) == "table" then details else false
    end
    return detailsCache[userId] or nil
end

local function enregistrerDetailsMonde(userId, perso, musique)
    local details = { perso = perso, musique = musique }
    detailsCache[userId] = details
    if storeDetails then
        task.spawn(function()
            pcall(function()
                storeDetails:SetAsync(tostring(userId), details)
            end)
        end)
    end
end

-- Top 10 d'un classement (top 100 pour le monde entier), gardé 30 s en mémoire pour ne pas spammer la sauvegarde
local function lireClassement(cle)
    local t = tableaux[cle]
    if not t then
        return {}
    end
    if t.cache and os.clock() - t.cacheA < 30 then
        return t.cache
    end
    local nombre = if cle == "G" or cle == "T" then 100 else 10
    local scores = {}
    if t.store then
        local ok, page = pcall(function()
            return t.store:GetSortedAsync(false, nombre):GetCurrentPage()
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
    for i = 1, math.min(nombre, #liste) do
        if not nomsCache[liste[i].id] then
            enAttente += 1
            task.spawn(function()
                nomDe(liste[i].id)
                enAttente -= 1
            end)
        end
    end
    local limiteNoms = os.clock() + 5
    while enAttente > 0 and os.clock() < limiteNoms do
        task.wait(0.05)
    end
    local resultat = {}
    for i = 1, math.min(nombre, #liste) do
        resultat[i] = { nom = nomsCache[liste[i].id] or ("Player " .. liste[i].id), score = liste[i].score, userId = liste[i].id }
        if cle == "G" and i <= 10 then
            -- 🌍 monde entier : avec quel état d'esprit et quelle musique il a fait ce record
            local details = detailsMonde(liste[i].id)
            if details then
                resultat[i].perso = details.perso
                resultat[i].musique = details.musique
            end
        end
    end
    t.cache, t.cacheA = resultat, os.clock()
    if t.valeur then
        t.valeur:SetAttribute("Top1Nom", if resultat[1] then resultat[1].nom else "")
        t.valeur:SetAttribute("Top1Score", if resultat[1] then resultat[1].score else 0)
    end
    return resultat
end

-- Le record perso d'un joueur dans un classement
local function recordDe(cle, userId)
    local t = tableaux[cle]
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

-- Enregistre un score ; renvoie true si c'est un nouveau record perso
local function enregistrerRecord(cle, joueur, score)
    local t = tableaux[cle]
    if not t or score <= 0 then
        return false
    end
    local nouveau = score > recordDe(cle, joueur.UserId)
    if nouveau then
        t.session[joueur.UserId] = score
        t.cache = nil
    end
    if t.store and nouveau then
        local ok, erreur = pcall(function()
            t.store:UpdateAsync(tostring(joueur.UserId), function(ancien)
                if (ancien or 0) >= score then
                    return nil -- on garde l'ancien, il est meilleur
                end
                return score
            end)
        end)
        if not ok then
            alerte(erreur)
        end
    end
    return nouveau
end

local dernierAppelClassement = {}
-- (tout = true : le hub veut tout le top 100 ; sinon on n'envoie que les 10 premiers)
ClassementFonction.OnServerInvoke = function(demandeur, cle, tout)
    if typeof(cle) ~= "string" or not tableaux[cle] then
        return nil
    end
    local maintenant = os.clock()
    if maintenant - (dernierAppelClassement[demandeur] or 0) < 0.25 then
        task.wait(0.25) -- anti-spam
    end
    dernierAppelClassement[demandeur] = os.clock()
    local liste = lireClassement(cle)
    if tout ~= true and #liste > 10 then
        liste = table.move(liste, 1, 10, 1, {})
    end
    return { liste = liste, moi = recordDe(cle, demandeur.UserId) }
end
Players.PlayerRemoving:Connect(function(parti)
    dernierAppelClassement[parti] = nil
end)

-- 🏆 le record de chaque joueur (le plus de marches en une partie), affiché au-dessus de sa tête dans le hub
local function publierRecord(joueur)
    if joueur.Parent then
        joueur:SetAttribute("Record", recordDe("G", joueur.UserId))
    end
end
-- 🪜 le total de marches du joueur part dans le classement TOTAL STEPS
-- (seulement s'il a augmenté : enregistrerRecord garde le plus grand)
local function publierTotal(joueur)
    local steps = chercherStat(joueur, "Steps")
    if steps and steps.Value > 0 then
        enregistrerRecord("T", joueur, steps.Value)
    end
end

local function joueurArriveClassements(joueur)
    publierRecord(joueur)
    -- on attend que ses données soient chargées, pour mettre aussi son ancien total dans le classement
    local limite = os.clock() + 30
    while joueur.Parent and not chargementFini[joueur] and os.clock() < limite do
        task.wait(0.5)
    end
    if joueur.Parent and chargementFini[joueur] then
        publierTotal(joueur)
    end
end
Players.PlayerAdded:Connect(function(joueur)
    task.spawn(joueurArriveClassements, joueur)
end)
for _, joueur in ipairs(Players:GetPlayers()) do
    task.spawn(joueurArriveClassements, joueur)
end

-- ========================== VOTE DE LA MUSIQUE ==========================
local propositions = {}   -- les musiques proposées pendant ce lobby
local votesMusique = {}   -- [joueur] = numéro de la musique votée

local function compterVotes()
    local comptes = {}
    for i = 1, #propositions do
        comptes[i] = 0
    end
    for votant, i in pairs(votesMusique) do
        if votant.Parent and comptes[i] then
            comptes[i] += 1
        end
    end
    for i = 1, #propositions do
        local valeur = dossierChoixMusiques:FindFirstChild(tostring(i))
        if valeur then
            valeur:SetAttribute("Votes", comptes[i])
        end
    end
    return comptes
end

-- Niveau de difficulté affiché sur la carte de vote : d'après le tempo (et le moment dur du drop).
-- Tu peux le forcer dans CONFIG.MUSIQUES avec difficulte = 1 (facile) à 4 (extrême).
local function difficulteDe(m)
    if type(m.difficulte) == "number" then
        return math.clamp(math.floor(m.difficulte), 1, 4)
    end
    local bpm = m.bpm or 120
    local niveau = if bpm < 90 then 1 elseif bpm < 105 then 2 elseif bpm < 130 then 3 else 4
    if m.drop then -- (le drop = une tempête de rochers)
        niveau = math.min(4, niveau + 1)
    end
    return niveau
end

local function proposerMusiques()
    votesMusique = {}
    propositions = {}
    dossierChoixMusiques:ClearAllChildren()
    local dispo = {}
    for _, m in ipairs(CONFIG.MUSIQUES) do
        if m.id ~= "" then
            table.insert(dispo, m)
        end
    end
    for _ = 1, math.min(CONFIG.NB_PROPOSITIONS, #dispo) do
        table.insert(propositions, table.remove(dispo, math.random(1, #dispo)))
    end
    for i, m in ipairs(propositions) do
        local valeur = creer("StringValue", { Name = tostring(i), Value = m.nom or ("Song " .. i) })
        valeur:SetAttribute("Votes", 0)
        valeur:SetAttribute("Cle", cleMusique(m)) -- pour afficher le record de la musique sur sa carte
        valeur:SetAttribute("Difficulte", difficulteDe(m)) -- 1 facile, 2 moyen, 3 difficile, 4 extrême
        valeur.Parent = dossierChoixMusiques
    end
    -- on rafraîchit les records affichés sur les cartes (persos + musiques proposées)
    task.spawn(function()
        for _, perso in ipairs(ORDRE_PERSOS) do
            lireClassement("P_" .. perso)
        end
        for _, m in ipairs(propositions) do
            lireClassement(cleMusique(m))
        end
    end)
end

-- La plus votée gagne (égalité ou aucun vote : tirage au sort entre les ex æquo)
local function musiqueGagnante()
    if #propositions == 0 then
        return nil
    end
    local comptes = compterVotes()
    local meilleur, exAequo = -1, {}
    for i = 1, #propositions do
        if comptes[i] > meilleur then
            meilleur, exAequo = comptes[i], { i }
        elseif comptes[i] == meilleur then
            table.insert(exAequo, i)
        end
    end
    return propositions[exAequo[math.random(1, #exAequo)]]
end

VoterMusiqueEvent.OnServerEvent:Connect(function(votant, i)
    if ReplicatedStorage:GetAttribute("Phase") ~= "Lobby" then
        return
    end
    if typeof(i) ~= "number" or not propositions[i] then
        return
    end
    votesMusique[votant] = i
    compterVotes()
end)

Players.PlayerRemoving:Connect(function(parti)
    if votesMusique[parti] then
        votesMusique[parti] = nil
        compterVotes()
    end
end)

local function compteARebours(secondes)
    for t = secondes, 1, -1 do
        setTemps(t)
        task.wait(1)
    end
    setTemps(0)
end

-- ========================== ROCHERS ==========================
-- Un rocher apparaît un peu devant le premier et dévale l'escalier. Les joueurs sont renversés par leur
-- propre jeu (script client) ; ici on compte les coups et on renverse les bots.
local function lancerRocher(nTete)
    local n = nTete + math.random(18, 30)
    etendre(n + 10)
    local taille = 4.5 + math.random() * 2.5
    local z = ORIGINE.Z + (math.random() - 0.5) * (W - taille - 2)
    local rocher = creer("Part", {
        Name = "Rocher",
        Shape = Enum.PartType.Ball,
        Size = Vector3.new(taille, taille, taille),
        Material = Enum.Material.Basalt,
        Color = Color3.fromRGB(48, 42, 52),
        Position = Vector3.new(ORIGINE.X + (n + 0.5) * D, dessusMarche(n) + taille / 2 + 1.5, z),
        CustomPhysicalProperties = PhysicalProperties.new(4, 0.3, 0.25),
        Parent = dossierObstacles,
    })
    creer("PointLight", { Color = Color3.fromRGB(255, 80, 60), Range = 12, Brightness = 2, Parent = rocher })
    rocher.AssemblyLinearVelocity = Vector3.new(-(22 + math.random() * 10), 0, (math.random() - 0.5) * 8)
    pcall(function()
        rocher:SetNetworkOwner(nil) -- c'est le serveur qui le fait rouler (pareil pour tout le monde)
    end)
    Debris:AddItem(rocher, 14)
end

local function heurterRochers(vivants)
    local maintenant = os.clock()
    for _, rocher in ipairs(dossierObstacles:GetChildren()) do
        if rocher.Position.Y < ORIGINE.Y - 60 then
            rocher:Destroy()
            continue
        end
        local rayon = rocher.Size.X / 2 + 2
        for _, v in ipairs(vivants) do
            local s = v.s
            if (v.racine.Position - rocher.Position).Magnitude < rayon and maintenant > (s.dernierCoup or 0) + 1.2 then
                s.dernierCoup = maintenant
                s.coups += 1
                if v.g:GetAttribute("Bot") then
                    -- l'OBSESSION « UNSTOPPABLE » ne se fait pas toujours renverser
                    local tenace = if v.g:GetAttribute("Perso") == "Obsession" then competence(v.g, 2) else nil
                    if not (tenace and math.random(1, 100) <= tenace) then
                        local humanoid = v.modele:FindFirstChildOfClass("Humanoid")
                        if humanoid then
                            humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
                        end
                        v.racine.AssemblyLinearVelocity = Vector3.new(-40, 28, (math.random() - 0.5) * 20)
                    end
                end
                EvenementEvent:FireAllClients("Rocher", v.g)
            end
        end
    end
end

-- ============================ BOUCLE DU JEU ============================
while true do
    -- 1) LOBBY : tout le monde au départ, on choisit son état d'esprit et on vote la musique
    manche = nil
    reconstruire()
    barriere.CanCollide = true
    barriere.Transparency = 0.3
    proposerMusiques()
    setPhase("Lobby")
    for _, g in ipairs(dossierGrimpeurs:GetChildren()) do
        for nom, valeur in pairs({ Marche = 0, Rang = 0, Chutes = 0, NiveauAura = 0, EnJeu = false, Danse = 0, AuraFarmee = 0, DoubleSaut = false }) do
            g:SetAttribute(nom, valeur)
        end
        g:SetAttribute("Scene", nil)
    end
    for joueur, g in pairs(grimpeurDesJoueurs) do
        local personnage = joueur.Character
        if personnage and not g:GetAttribute("Hub") then
            if g:GetAttribute("Pret") then
                task.spawn(placerAuDepart, personnage, joueur)
            else
                task.spawn(placerEnTribune, personnage, joueur)
            end
        end
    end
    setStatut(if #propositions > 0 then "🧠 Choose your mindset and vote for the music!" else "🧠 Choose your mindset!")
    compteARebours(CONFIG.ATTENTE_LOBBY)

    local participants = {}
    local persosPris = {}
    for joueur, g in pairs(grimpeurDesJoueurs) do
        if joueur.Parent and joueur.Character and g:GetAttribute("Pret") and not g:GetAttribute("Hub") then
            local perso = g:GetAttribute("Perso")
            if not PERSOS[perso] then
                perso = auHasard(ORDRE_PERSOS)
                g:SetAttribute("Perso", perso)
                joueur:SetAttribute("Perso", perso)
            end
            persosPris[perso] = true
            table.insert(participants, g)
        end
    end
    if #participants == 0 then
        continue
    end

    -- 2) DES BOTS COMPLÈTENT
    local bots = {}
    local manque = CONFIG.COUREURS_MIN - #participants
    for _, perso in ipairs(ORDRE_PERSOS) do
        if manque <= 0 then
            break
        end
        if not persosPris[perso] then
            local modele, pseudo = creerBot(perso)
            if modele then
                local g = nouveauGrimpeur(pseudo, perso, modele, nil)
                task.spawn(preparerBot, g, modele)
                table.insert(bots, g)
                table.insert(participants, g)
                manque -= 1
            end
        end
    end

    -- 3) LA MUSIQUE + LE DÉPART
    local musique = musiqueGagnante()
    if not musique then
        warn("[Mindset] Aucune musique avec un ID dans CONFIG.MUSIQUES : course sans son.")
        musique = { id = "", nom = "(silence)", bpm = 120, debut = 0 }
    end
    local debut = workspace:GetServerTimeNow() + CONFIG.PREPARATION
    -- la TEMPÊTE DE ROCHERS arrive au drop de la musique (en secondes depuis le départ)
    local tempete = if musique.drop then musique.drop - (musique.debut or 0) else nil
    if tempete and (tempete < 3 or tempete > CONFIG.DUREE_MANCHE - 3) then
        tempete = nil
    end
    manche = { debut = debut, stats = {}, niveaux = {} }
    for _, g in ipairs(participants) do
        g:SetAttribute("EnJeu", true)
        manche.stats[g] = { sol = 0, max = 0, departSerie = 0, chutes = 0, coups = 0, aura = 0 }
        -- les niveaux de compétences pour cette course (les bots en ont un peu, au hasard)
        local perso = g:GetAttribute("Perso")
        local joueurG = joueurDuGrimpeur[g]
        local niveaux = {}
        for i = 1, #(COMPETENCES[perso] or {}) do
            if joueurG then
                local siens = niveauxJoueurs[joueurG] and niveauxJoueurs[joueurG][perso]
                niveaux[i] = siens and siens[i] or 0
            else
                niveaux[i] = math.random(0, 3)
            end
        end
        manche.niveaux[g] = niveaux
        g:SetAttribute("DoubleSaut", perso == "Ego")
    end
    setStatut(if musique.id ~= "" then "🎵 " .. musique.nom else "")
    setPhase("Manche")
    DebutEvent:FireAllClients({
        musique = musique.id,
        debutMusique = musique.debut or 0,
        bpm = musique.bpm or 120,
        debut = debut,
        duree = CONFIG.DUREE_MANCHE,
        tempete = tempete,
    })
    -- décompte : 3, 2, 1...
    while workspace:GetServerTimeNow() < debut do
        setTemps(math.ceil(CONFIG.DUREE_MANCHE))
        task.wait(0.05)
    end
    -- GO ! la barrière s'ouvre (et MOTIVATION « HEAD START » commence plus haut)
    setStatut("")
    barriere.CanCollide = false
    barriere.Transparency = 1
    for _, g in ipairs(participants) do
        local elan = if g:GetAttribute("Perso") == "Motivation" then competence(g, 1) else nil
        local modele = g.Modele.Value
        if elan and modele then
            local n = marcheSure(elan)
            manche.stats[g].sol = n
            manche.stats[g].departSerie = n
            placerSurMarche(modele, joueurDuGrimpeur[g], n)
        end
    end

    -- 4) LA COURSE
    local prochainRocher = os.clock() + 2.5
    local tempeteAnnoncee = false
    local dernierPilotage = 0
    local derniereVitesse = 0
    while true do
        task.wait(0.1)
        local maintenant = os.clock()
        local ecoule = workspace:GetServerTimeNow() - debut
        setTemps(math.max(0, math.ceil(CONFIG.DUREE_MANCHE - ecoule)))
        if ecoule >= CONFIG.DUREE_MANCHE then
            break
        end
        local progression = math.clamp(ecoule / CONFIG.DUREE_MANCHE, 0, 1)

        -- où est chacun ? (marche, chute, marche qui casse, série sans tomber)
        local vivants = {}
        local tete = 0
        for _, g in ipairs(participants) do
            local modele = g.Parent and g:GetAttribute("EnJeu") and g.Modele.Value
            local racine = modele and modele:FindFirstChild("HumanoidRootPart")
            if racine then
                local s = manche.stats[g]
                local p = racine.Position
                local pieds = p.Y - hauteurRacine(modele)
                local n = numeroSous(p.X)
                local nPieds = math.floor((pieds - ORIGINE.Y) / H + 0.5)
                local marche = math.max(0, math.min(n, nPieds))
                local m = marches[n]
                if n >= 0 and m and not m.casse and m.type ~= "trou" and math.abs(pieds - dessusMarche(n)) < 1.5 then
                    s.sol = n
                    if m.type == "cassante" then
                        casser(n)
                    end
                end
                local reference = if n >= 0 then dessusMarche(n) else ORIGINE.Y
                if pieds < reference - 12 then
                    chute(g, modele, s)
                    marche = g:GetAttribute("Marche") or 0
                elseif g:GetAttribute("Marche") ~= marche then
                    g:SetAttribute("Marche", marche)
                end
                s.max = math.max(s.max, marche)
                local niveau = niveauAuraDe(marche - s.departSerie)
                if g:GetAttribute("NiveauAura") ~= niveau then
                    g:SetAttribute("NiveauAura", niveau)
                end
                tete = math.max(tete, marche)
                table.insert(vivants, { g = g, s = s, modele = modele, racine = racine, marche = marche })
            end
        end
        etendre(tete + 150)

        -- le classement en direct + les vitesses (4 fois par seconde)
        if maintenant - derniereVitesse >= 0.25 then
            derniereVitesse = maintenant
            table.sort(vivants, function(a, b)
                return a.marche > b.marche
            end)
            for rang, v in ipairs(vivants) do
                if v.g:GetAttribute("Rang") ~= rang then
                    v.g:SetAttribute("Rang", rang)
                end
                local humanoid = v.modele:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    local vitesse = vitesseDe(v.g, progression, ecoule, rang)
                    if v.g:GetAttribute("Bot") then
                        vitesse *= 0.85 + 0.12 * (infosBots[v.g] and infosBots[v.g].adresse or 0.9)
                    end
                    humanoid.WalkSpeed = vitesse
                    local saut = if v.g:GetAttribute("Perso") == "Ego" then CONFIG.SAUT * (1 + (competence(v.g, 1) or 0) / 100) else CONFIG.SAUT
                    if humanoid.JumpHeight ~= saut then
                        humanoid.JumpHeight = saut
                    end
                    v.g:SetAttribute("Vitesse", math.floor(vitesse + 0.5))
                end
            end
        end

        -- les bots
        if maintenant - dernierPilotage >= 0.15 then
            dernierPilotage = maintenant
            for _, v in ipairs(vivants) do
                if v.g:GetAttribute("Bot") then
                    piloterBot(v.g, v.modele)
                end
            end
        end

        -- les rochers (plus souvent vers la fin, et la TEMPÊTE au drop)
        local enTempete = tempete and ecoule >= tempete and ecoule < tempete + CONFIG.TEMPETE
        if enTempete and not tempeteAnnoncee then
            tempeteAnnoncee = true
            EvenementEvent:FireAllClients("Tempete", CONFIG.TEMPETE)
        end
        if maintenant >= prochainRocher then
            lancerRocher(tete)
            local intervalle = CONFIG.ROCHERS_DEBUT + (CONFIG.ROCHERS_FIN - CONFIG.ROCHERS_DEBUT) * progression
            prochainRocher = maintenant + (if enTempete then 0.3 else intervalle * (0.7 + math.random() * 0.6))
        end
        heurterRochers(vivants)
    end

    -- 5) FIN : tout le monde s'arrête, le plus haut gagne
    setPhase("Fin")
    dossierObstacles:ClearAllChildren()
    local classement = {}
    for _, g in ipairs(participants) do
        if g.Parent and g:GetAttribute("EnJeu") then
            table.insert(classement, g)
            local modele = g.Modele.Value
            local racine = modele and modele:FindFirstChild("HumanoidRootPart")
            if racine then
                racine.Anchored = true
            end
        end
    end
    table.sort(classement, function(a, b)
        local ma, mb = a:GetAttribute("Marche") or 0, b:GetAttribute("Marche") or 0
        if ma ~= mb then
            return ma > mb
        end
        return (a:GetAttribute("Ordre") or 0) < (b:GetAttribute("Ordre") or 0)
    end)

    local meilleur = if classement[1] then classement[1]:GetAttribute("Marche") or 0 else 0
    local gagnants = {}
    for _, g in ipairs(classement) do
        if (g:GetAttribute("Marche") or 0) == meilleur then
            table.insert(gagnants, g)
        end
    end
    local function nomDuGrimpeur(g)
        return tostring(g:GetAttribute("Nom"))
    end

    -- l'aura : 1 toutes les 10 marches, + le bonus du gagnant
    for _, g in ipairs(classement) do
        local joueurG = joueurDuGrimpeur[g]
        if joueurG then
            donnerAura(joueurG, g, math.floor((g:GetAttribute("Marche") or 0) / CONFIG.AURA_PAR_MARCHES))
        end
    end
    for _, g in ipairs(gagnants) do
        local joueurGagnant = joueurDuGrimpeur[g]
        if joueurGagnant then
            ajouterStat(joueurGagnant, "Wins", 1)
            donnerAura(joueurGagnant, g, CONFIG.AURA_VICTOIRE)
        end
    end

    -- les records (en tâche de fond : la sauvegarde peut prendre un peu de temps)
    local nouveauxRecords = {}
    for _, g in ipairs(classement) do
        local joueurRecord = joueurDuGrimpeur[g]
        if joueurRecord then
            local score = g:GetAttribute("Marche") or 0
            ajouterStat(joueurRecord, "Steps", score) -- marches gravies au total (en haut à droite)
            local perso = g:GetAttribute("Perso")
            task.spawn(function()
                local recordPerso = enregistrerRecord("P_" .. tostring(perso), joueurRecord, score)
                local recordMusique = musique.id ~= "" and enregistrerRecord(cleMusique(musique), joueurRecord, score)
                local recordCombo = musique.id ~= "" and enregistrerRecord(cleCombo(tostring(perso), cleMusique(musique)), joueurRecord, score)
                -- 🌍 monde entier (et on retient avec quel état d'esprit + quelle musique)
                if enregistrerRecord("G", joueurRecord, score) then
                    enregistrerDetailsMonde(joueurRecord.UserId, tostring(perso), if musique.id ~= "" then musique.nom else "(no music)")
                    publierRecord(joueurRecord)
                end
                publierTotal(joueurRecord) -- 🪜 TOTAL STEPS
                nouveauxRecords[g] = recordPerso or recordMusique or recordCombo
            end)
        end
    end

    -- le(s) gagnant(s) montent sur la scène, la caméra de tout le monde y va
    for i, g in ipairs(gagnants) do
        local modele = g.Modele.Value
        if modele and modele:FindFirstChild("HumanoidRootPart") then
            local x = (i - (#gagnants + 1) / 2) * 4.5
            local position = SCENE + Vector3.new(x, hauteurRacine(modele) + 0.05, 0)
            local cf = CFrame.lookAt(position, position + Vector3.new(0, 0, 1))
            g:SetAttribute("Scene", cf)
            placer(modele, cf, true, joueurDuGrimpeur[g])
        end
    end
    if #gagnants >= 2 then
        setStatut("TIE! " .. nomDuGrimpeur(gagnants[1]) .. " & " .. nomDuGrimpeur(gagnants[2]) .. " — " .. meilleur .. " steps")
    elseif gagnants[1] then
        local g = gagnants[1]
        setStatut("👑 " .. nomDuGrimpeur(g) .. " WINS with " .. string.upper(tostring(g:GetAttribute("Perso"))) .. " — " .. meilleur .. " steps!")
    end
    if #gagnants > 0 then
        EvenementEvent:FireAllClients("Vainqueur", gagnants)
        task.wait(2.2)
    end

    -- la danse : le(s) gagnant(s) farment l'aura
    if #gagnants > 0 then
        danse = { gagnants = {}, fin = workspace:GetServerTimeNow() + CONFIG.DUREE_DANSE, dernier = {} }
        for _, g in ipairs(gagnants) do
            danse.gagnants[g] = true
            g:SetAttribute("Danse", 1)
        end
        EvenementEvent:FireAllClients("Danse", gagnants, danse.fin)
        while workspace:GetServerTimeNow() < danse.fin do
            task.wait(0.15)
            for _, g in ipairs(gagnants) do
                if g.Parent and g:GetAttribute("Bot") and math.random() < 0.6 then
                    pasDeDanse(g) -- les bots dansent tout seuls
                end
            end
        end
        for _, g in ipairs(gagnants) do
            if g.Parent then
                g:SetAttribute("Danse", 0)
            end
        end
        danse = nil
    end

    -- l'écran de fin de chaque joueur
    local nomsGagnants = {}
    for _, g in ipairs(gagnants) do
        table.insert(nomsGagnants, nomDuGrimpeur(g))
    end
    for _, g in ipairs(classement) do
        local joueurFin = joueurDuGrimpeur[g]
        if joueurFin and joueurFin.Parent then
            local stats = manche.stats[g]
            local marches = g:GetAttribute("Marche") or 0
            local place = 1
            for _, autre in ipairs(classement) do
                if (autre:GetAttribute("Marche") or 0) > marches then
                    place += 1
                end
            end
            FinEvent:FireClient(joueurFin, {
                perso = g:GetAttribute("Perso"),
                place = place,
                egalite = place == 1 and #gagnants >= 2,
                total = #classement,
                marches = marches,
                plusHaut = stats.max,
                chutes = stats.chutes,
                coups = stats.coups,
                record = recordDe("P_" .. tostring(g:GetAttribute("Perso")), joueurFin.UserId),
                nouveauRecord = nouveauxRecords[g] == true,
                auraFarmee = g:GetAttribute("AuraFarmee") or 0,
                auraGagnee = stats.aura, -- l'aura gagnée pendant la course (pour le marchand)
                gagnant = if #nomsGagnants > 0 then table.concat(nomsGagnants, " & ") else "nobody",
            })
        end
    end
    compteARebours(7)

    -- 6) ON RANGE (les joueurs retournent au départ au début du lobby suivant)
    for _, g in ipairs(bots) do
        infosBots[g] = nil
        local valeur = g:FindFirstChild("Modele")
        if valeur and valeur.Value then
            valeur.Value:Destroy()
        end
        g:Destroy()
    end
end
