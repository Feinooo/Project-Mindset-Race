--[[
    🧠 MINDSET STAIRS — Script SERVEUR
    À mettre dans : ServerScriptService  (type : Script)

    Jeu de rythme en 2D : une musique d'aura se lance, tu cliques sur les cercles en rythme,
    chaque note réussie te fait monter les marches, chaque note ratée te fait redescendre.
    Ce script construit la scène (les escaliers), gère les manches, les persos, les bots et la sauvegarde.
]]

-- ===================== RÉGLAGES (tu peux les modifier) =====================
local CONFIG = {
    ATTENTE_LOBBY = 30,   -- secondes pour choisir son état d'esprit et voter la musique
    PREPARATION = 4,      -- secondes de décompte avant la musique
    DUREE_MANCHE = 60,    -- durée d'une manche (secondes de musique)
    -- (plus de sommet : les escaliers sont infinis, le plus haut à la fin gagne)
    DUREE_DANSE = 8,      -- secondes où le gagnant danse pour farm l'aura à la fin
    AURA_PAR_PAS = 1,     -- aura gagnée à chaque pas de danse du gagnant
    NB_COULOIRS = 8,      -- grimpeurs affichés en même temps (mets le même nombre en « Max joueurs »)
    COUREURS_MIN = 4,     -- des bots complètent jusqu'à ce nombre

    NB_PROPOSITIONS = 3,  -- musiques proposées au vote dans le lobby
    DUREE_DROP = 15,      -- secondes de « moment dur » à partir du drop
    DENSITE_DROP = 0.7,   -- pendant le drop : chance d'ajouter une note entre deux temps (0 = rien, 1 = toutes)

    -- 🎵 MUSIQUES : à chaque lobby, 3 sont tirées au hasard et les joueurs votent.
    --   id       = l'ID Roblox du son, ex. "rbxassetid://1234567890"
    --              ⚠ une musique avec id = "" est ignorée (pas encore mise en ligne)
    --   nom      = le nom affiché sur le bouton de vote
    --   bpm      = le tempo de la musique (mesuré avec un analyseur de MP3)
    --   debut    = à quelle seconde du son la manche commence (0 = au tout début de la musique)
    --   drop     = à quelle seconde du son arrive le DROP = le moment DUR (plein de cercles)
    --              → marque-le avec l'outil : Play dans Studio, touche B (pas de drop = enlève « drop = ... »)
    --   decalage = si les cercles tombent un peu à côté du rythme, ajuste ici (ex. 0.05 ou -0.05)
    -- (les anciennes musiques sont dans l'historique git, commit 19623be)
    MUSIQUES = {
        { id = "rbxassetid://74842327948915", nom = "BUFÓN!", bpm = 82, debut = 0, drop = 9.57, decalage = 0 },
        { id = "rbxassetid://134372266822247", nom = "MONTAGE SENNTANA", bpm = 95, debut = 0, drop = 20.22, decalage = 0 },
        { id = "rbxassetid://117822777228038", nom = "ME VS ME", bpm = 120, debut = 0, drop = 19.14, decalage = 0 },
        { id = "rbxassetid://84227603413943", nom = "NO ERA AMOR", bpm = 103, debut = 0, drop = 10.21, decalage = 0 },
        { id = "rbxassetid://80140071567818", nom = "EMPIRE", bpm = 93, debut = 0, drop = 23.38, decalage = 0 },
        { id = "rbxassetid://135464211325455", nom = "TIKI TIKI", bpm = 84, debut = 0, drop = 8.68, decalage = 0 },
        { id = "rbxassetid://127965945833744", nom = "Your Next Opponent Is You", bpm = 143, debut = 0, drop = 20.11, decalage = 0 },
    },
}
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

-- ========================== GÉOMÉTRIE (partagée avec les clients) ==========================
local GEO = { X0 = 0, Y0 = 300, Z0 = 0, HAUTEUR = 1.6, PROFONDEUR = 3, ECART = 7 }
for nom, valeur in pairs(GEO) do
    ReplicatedStorage:SetAttribute("Geo" .. nom, valeur)
end
ReplicatedStorage:SetAttribute("NbCouloirs", CONFIG.NB_COULOIRS)

local function positionMarche(couloir, marche)
    return Vector3.new(
        GEO.X0 + (marche + 0.5) * GEO.PROFONDEUR,
        GEO.Y0 + marche * GEO.HAUTEUR + 3,
        GEO.Z0 - couloir * GEO.ECART
    )
end

-- ========================== COMMUNICATION ==========================
local dossierRemotes = Instance.new("Folder")
dossierRemotes.Name = "MindsetRemotes"
local function remote(nom)
    return creer("RemoteEvent", { Name = nom, Parent = dossierRemotes })
end
local DebutEvent = remote("Debut")         -- serveur -> clients : la partition et la musique de la manche
local NoteEvent = remote("Note")           -- client -> serveur : « j'ai eu PARFAIT / BIEN / RATÉ sur la note n »
local ChoisirEvent = remote("Choisir")     -- client -> serveur : choix du perso
local EvenementEvent = remote("Evenement") -- serveur -> clients : sommet atteint, vainqueur...
local FinEvent = remote("Fin")             -- serveur -> joueur : son écran de fin
local VoterMusiqueEvent = remote("VoterMusique") -- client -> serveur : vote pour une des 3 musiques
local DanserEvent = remote("Danser")       -- client -> serveur : le gagnant fait un pas de danse (farm d'aura)
local JouerEvent = remote("Jouer")         -- client -> serveur : le joueur a appuyé sur PLAY dans le menu principal
local ReglagesEvent = remote("Reglages")   -- client -> serveur : ses paramètres (volumes...) à sauvegarder
local ClassementFonction = creer("RemoteFunction", { Name = "Classement", Parent = dossierRemotes }) -- top 10 d'un classement

local dossierGrimpeurs = creer("Folder", { Name = "Grimpeurs", Parent = ReplicatedStorage })
-- Les musiques proposées au vote (StringValue "1", "2", "3" : Value = nom, attributs Votes et Cle)
local dossierChoixMusiques = creer("Folder", { Name = "ChoixMusiques", Parent = ReplicatedStorage })
-- Les classements (un par état d'esprit, un par musique) : StringValue, attributs Type, Top1Nom, Top1Score
local dossierClassements = creer("Folder", { Name = "Classements", Parent = ReplicatedStorage })
dossierRemotes.Parent = ReplicatedStorage

-- 🎵 Marqueur de drop (touche B) : en Studio seulement, on partage la liste des musiques avec l'outil
if game:GetService("RunService"):IsStudio() then
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

-- ========================== LA SCÈNE 2D ==========================
-- Les escaliers sont INFINIS : c'est chaque client qui construit les marches autour de sa caméra
-- (voir le script client, partie « ESCALIERS »). On enlève une éventuelle vieille scène.
local scene = workspace:FindFirstChild("MindsetScene")
if scene then
    scene:Destroy()
end

-- Lumière : nuit, scène bien éclairée, néons qui brillent
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

local function chargerJoueur(joueur, stats)
    if not sauvegarde then
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
        stats.Victoires.Value += donnees.victoires or 0
        stats.Aura.Value += donnees.aura or 0
        if type(donnees.reglages) == "table" then
            reglagesJoueurs[joueur] = donnees.reglages
            joueur:SetAttribute("Reglages", HttpService:JSONEncode(donnees.reglages))
        end
        donneesChargees[joueur] = true
    else
        warn("💾 Impossible de charger les données de " .. joueur.Name .. " : pas de sauvegarde pour cette partie.")
    end
end

local function sauverJoueur(joueur)
    if not donneesChargees[joueur] then
        return
    end
    local stats = joueur:FindFirstChild("leaderstats")
    if not stats then
        return
    end
    local victoires, aura = stats.Victoires.Value, stats.Aura.Value
    local reglages = reglagesJoueurs[joueur]
    essayer(function()
        sauvegarde:UpdateAsync("joueur_" .. joueur.UserId, function(anciennes)
            local donnees = anciennes or {}
            donnees.victoires = victoires
            donnees.aura = aura
            donnees.reglages = reglages or donnees.reglages
            return donnees
        end)
    end)
end

local function ajouterStat(joueur, nom, nombre)
    local stats = joueur and joueur:FindFirstChild("leaderstats")
    local valeur = stats and stats:FindFirstChild(nom)
    if valeur then
        valeur.Value += nombre
    end
end

-- ========================== GRIMPEURS ==========================
-- Chaque grimpeur (joueur ou bot) = une Configuration dans ReplicatedStorage.Grimpeurs,
-- avec ses attributs (Perso, Marche, Combo...). Les clients s'en servent pour animer les avatars.
local grimpeurDesJoueurs = {} -- [joueur] = config
local joueurDuGrimpeur = {}   -- [config] = joueur
local compteurOrdre = 0

local function nouveauGrimpeur(nom, perso, modele, joueur)
    compteurOrdre += 1
    local g = Instance.new("Configuration")
    g.Name = nom
    g:SetAttribute("Nom", nom)
    g:SetAttribute("Perso", perso)
    g:SetAttribute("Marche", 0)
    g:SetAttribute("Combo", 0)
    g:SetAttribute("NiveauAura", 0)
    g:SetAttribute("EnJeu", false)
    g:SetAttribute("Ordre", compteurOrdre)
    g:SetAttribute("Bot", joueur == nil)
    g:SetAttribute("Pret", joueur == nil) -- un joueur doit d'abord appuyer sur PLAY
    g:SetAttribute("UserId", if joueur then joueur.UserId else 0)
    creer("ObjectValue", { Name = "Modele", Value = modele, Parent = g })
    g.Parent = dossierGrimpeurs
    return g
end

local function preparerAvatar(modele, ordre)
    local racine = modele:WaitForChild("HumanoidRootPart", 10)
    local humanoid = modele:WaitForChild("Humanoid", 10)
    if not racine or not humanoid then
        return
    end
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- on affiche notre propre étiquette
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0
    humanoid.JumpHeight = 0
    racine.Anchored = true -- c'est le client qui fait bouger les avatars sur les marches
    local position = positionMarche((ordre - 1) % CONFIG.NB_COULOIRS, 0)
    modele:PivotTo(CFrame.lookAt(position, position + Vector3.new(1, 0, 0)))
end

local function joueurArrive(joueur)
    local stats = creer("Folder", { Name = "leaderstats", Parent = joueur })
    creer("IntValue", { Name = "Victoires", Parent = stats })
    creer("IntValue", { Name = "Aura", Parent = stats })
    task.spawn(chargerJoueur, joueur, stats)

    local g = nouveauGrimpeur(joueur.DisplayName, nil, joueur.Character, joueur)
    grimpeurDesJoueurs[joueur] = g
    joueurDuGrimpeur[g] = joueur

    local function surPersonnage(personnage)
        g.Modele.Value = personnage
        preparerAvatar(personnage, g:GetAttribute("Ordre"))
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

-- PLAY : le joueur quitte le menu principal et participe aux prochaines manches
-- PLAY (true) : le joueur participe aux prochaines manches.
-- AFK / retour au menu (false) : il regarde les autres jouer, sans être lancé dans la partie.
JouerEvent.OnServerEvent:Connect(function(joueur, participe)
    local g = grimpeurDesJoueurs[joueur]
    if g then
        g:SetAttribute("Pret", participe ~= false)
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

-- Comment joue chaque bot (chance de réussir une note, selon le perso)
local function verdictBot(g, progression)
    local perso = g:GetAttribute("Perso")
    local chance
    if perso == "Discipline" then
        chance = 0.85
    elseif perso == "Motivation" then
        chance = if progression < 0.35 then 0.95 else 0.55
    elseif perso == "Ego" then
        chance = 0.8
    else
        chance = 0.55 + 0.45 * progression -- Obsession : de plus en plus fort
    end
    if math.random() > chance then
        return "Rate"
    end
    return if math.random() < 0.5 then "Parfait" else "Bien"
end

-- ========================== RÈGLES DES PERSOS ==========================
-- C'est ici qu'on équilibre le jeu : combien de marches on gagne ou perd à chaque note.
--   MOTIVATION : +2 par note au début (35 % de la musique), +1 ensuite. Rater au début = -1, ensuite = -2.
--   EGO        : +1 par note, +2 sur les PARFAIT dès que le combo atteint 10. Rater = -2 (il perd la face).
--   DISCIPLINE : +1 par note, jamais plus. Rater = 0 : il ne redescend JAMAIS.
--   OBSESSION  : au début seuls les PARFAIT comptent, puis +1, puis +2 sur la 2e moitié. Rater = -1.
local manche = nil

local function appliquer(g, verdict, progression)
    local stats = manche.stats[g]
    local perso = g:GetAttribute("Perso")
    local combo = g:GetAttribute("Combo") or 0
    local gain

    if verdict == "Rate" then
        combo = 0
        stats.rates += 1
        if perso == "Discipline" then
            gain = 0
        elseif perso == "Ego" then
            gain = -2
        elseif perso == "Motivation" then
            gain = if progression < 0.35 then -1 else -2
        else
            gain = -1
        end
    else
        combo += 1
        if verdict == "Parfait" then
            stats.parfaits += 1
        else
            stats.biens += 1
        end
        stats.comboMax = math.max(stats.comboMax, combo)
        if perso == "Motivation" then
            gain = if progression < 0.35 then 2 else 1
        elseif perso == "Ego" then
            gain = if combo >= 10 and verdict == "Parfait" then 2 else 1
        elseif perso == "Obsession" then
            if progression < 0.25 then
                gain = if verdict == "Parfait" then 1 else 0
            elseif progression < 0.5 then
                gain = 1
            else
                gain = 2
            end
        else
            gain = 1
        end
    end

    local marche = math.max(0, (g:GetAttribute("Marche") or 0) + gain) -- pas de plafond : ça monte à l'infini
    g:SetAttribute("Combo", combo)
    g:SetAttribute("NiveauAura", if combo >= 50 then 3 elseif combo >= 25 then 2 elseif combo >= 10 then 1 else 0)
    g:SetAttribute("Marche", marche)

    local joueur = joueurDuGrimpeur[g]
    if joueur and verdict ~= "Rate" then
        ajouterStat(joueur, "Aura", if verdict == "Parfait" then 2 else 1)
    end
end

NoteEvent.OnServerEvent:Connect(function(joueur, index, verdict)
    if not manche or typeof(index) ~= "number" or index % 1 ~= 0 then
        return
    end
    if verdict ~= "Parfait" and verdict ~= "Bien" and verdict ~= "Rate" then
        return
    end
    local g = grimpeurDesJoueurs[joueur]
    if not g or not manche.juges[g] then
        return
    end
    local tempsNote = manche.notes[index]
    if not tempsNote or manche.juges[g][index] then
        return
    end
    if workspace:GetServerTimeNow() - (manche.debut + tempsNote) < -1 then
        return -- trop tôt pour être honnête
    end
    manche.juges[g][index] = true
    appliquer(g, verdict, tempsNote / CONFIG.DUREE_MANCHE)
end)

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

-- ========================== PARTITION ==========================
-- Une note par temps (1 sur 2 au début pour s'échauffer), et quelques doubles notes à la fin.
-- 💥 Si la musique a un DROP : à partir du drop et pendant CONFIG.DUREE_DROP secondes, c'est le moment DUR :
--    une note sur chaque temps + presque toutes les demi-temps (beaucoup de cercles d'un coup).
-- Renvoie aussi le moment du drop dans la manche (en secondes), ou nil.
local function genererPartition(musique)
    local intervalle = 60 / musique.bpm
    local notes = {}
    local dropManche = nil
    if musique.drop then
        dropManche = musique.drop - (musique.debut or 0)
        if dropManche < 0 or dropManche > CONFIG.DUREE_MANCHE - 2 then
            warn("[Mindset] Le drop de « " .. tostring(musique.nom) .. " » tombe en dehors de la manche : vérifie debut et drop.")
            dropManche = nil
        end
    end
    local t = musique.decalage
    while t < 2 * intervalle do
        t += intervalle
    end
    while t < CONFIG.DUREE_MANCHE - 1 do
        local progression = t / CONFIG.DUREE_MANCHE
        local dansLeDrop = dropManche and t >= dropManche - 0.01 and t < dropManche + CONFIG.DUREE_DROP
        table.insert(notes, t)
        if dansLeDrop then
            if math.random() < CONFIG.DENSITE_DROP then
                table.insert(notes, t + intervalle / 2)
            end
            t += intervalle
        else
            if progression > 0.75 and math.random() < 0.25 then
                table.insert(notes, t + intervalle / 2)
            end
            local pas = if progression < 0.2 then 2 else 1
            -- on ne saute pas le début du drop pendant l'échauffement
            if dropManche and pas == 2 and t + 2 * intervalle > dropManche and t < dropManche then
                pas = 1
            end
            t += intervalle * pas
        end
    end
    return notes, dropManche
end

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
        creerTableau(cleMusique(m), m.nom or ("Musique " .. ordre), "Musique")
        tableaux[cleMusique(m)].valeur:SetAttribute("Ordre", ordre)
    end
end
-- 🌍 le classement du MONDE ENTIER (toutes musiques, tous états d'esprit)
creerTableau("G", "MONDE ENTIER", nil)
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
    nomsCache[userId] = if ok and nom then nom else ("Joueur " .. userId)
    return nomsCache[userId]
end

-- Top 10 d'un classement (gardé 30 s en mémoire pour ne pas spammer la sauvegarde)
local function lireClassement(cle)
    local t = tableaux[cle]
    if not t then
        return {}
    end
    if t.cache and os.clock() - t.cacheA < 30 then
        return t.cache
    end
    local scores = {}
    if t.store then
        local ok, page = pcall(function()
            return t.store:GetSortedAsync(false, 10):GetCurrentPage()
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
    local resultat = {}
    for i = 1, math.min(10, #liste) do
        resultat[i] = { nom = nomDe(liste[i].id), score = liste[i].score, userId = liste[i].id }
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
ClassementFonction.OnServerInvoke = function(demandeur, cle)
    if typeof(cle) ~= "string" or not tableaux[cle] then
        return nil
    end
    local maintenant = os.clock()
    if maintenant - (dernierAppelClassement[demandeur] or 0) < 0.25 then
        task.wait(0.25) -- anti-spam
    end
    dernierAppelClassement[demandeur] = os.clock()
    return { liste = lireClassement(cle), moi = recordDe(cle, demandeur.UserId) }
end
Players.PlayerRemoving:Connect(function(parti)
    dernierAppelClassement[parti] = nil
end)

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
    if m.drop and CONFIG.DENSITE_DROP >= 0.8 then
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
        local valeur = creer("StringValue", { Name = tostring(i), Value = m.nom or ("Musique " .. i) })
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

-- ============================ BOUCLE DU JEU ============================
while true do
    -- 1) LOBBY : tout le monde en bas, on choisit son perso
    manche = nil
    proposerMusiques()
    setPhase("Lobby")
    for _, g in ipairs(dossierGrimpeurs:GetChildren()) do
        g:SetAttribute("Marche", 0)
        g:SetAttribute("Combo", 0)
        g:SetAttribute("NiveauAura", 0)
        g:SetAttribute("EnJeu", false)
        g:SetAttribute("Danse", 0)
        g:SetAttribute("AuraFarmee", 0)
    end
    setStatut(if #propositions > 0 then "🧠 Choisis ton état d'esprit et vote pour la musique !" else "🧠 Choisis ton état d'esprit !")
    compteARebours(CONFIG.ATTENTE_LOBBY)

    local participants = {}
    local persosPris = {}
    for joueur, g in pairs(grimpeurDesJoueurs) do
        if joueur.Parent and joueur.Character and g:GetAttribute("Pret") then -- seulement ceux qui ont appuyé sur PLAY
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
                task.spawn(preparerAvatar, modele, g:GetAttribute("Ordre"))
                table.insert(bots, g)
                table.insert(participants, g)
                manque -= 1
            end
        end
    end

    -- 3) MUSIQUE + PARTITION
    local musique = musiqueGagnante()
    if not musique then
        -- aucune musique avec un ID : on joue quand même, en silence, à 130 BPM
        warn("[Mindset] Aucune musique avec un ID dans CONFIG.MUSIQUES : manche sans son.")
        musique = { id = "", nom = "(silence)", bpm = 130, debut = 0, decalage = 0 }
    end
    local notes, dropManche = genererPartition(musique)
    local debut = workspace:GetServerTimeNow() + CONFIG.PREPARATION
    manche = { debut = debut, notes = notes, juges = {}, stats = {}, prochaineNote = {} }
    for _, g in ipairs(participants) do
        g:SetAttribute("EnJeu", true)
        manche.juges[g] = {}
        manche.stats[g] = { parfaits = 0, biens = 0, rates = 0, comboMax = 0, sommetA = nil }
        manche.prochaineNote[g] = 1
    end
    -- on annonce la musique gagnante pendant le décompte
    setStatut(if musique.id ~= "" then "🎵 " .. musique.nom else "")
    task.delay(CONFIG.PREPARATION, function()
        if ReplicatedStorage:GetAttribute("Phase") == "Manche" then
            setStatut("")
        end
    end)
    setPhase("Manche")
    DebutEvent:FireAllClients({
        musique = musique.id,
        bpm = musique.bpm,
        decalage = musique.decalage,
        debutMusique = musique.debut,
        drop = dropManche, -- le moment dur (secondes depuis le début de la manche), ou nil
        debut = debut,
        notes = notes,
        duree = CONFIG.DUREE_MANCHE,
    })

    -- 4) LA MANCHE
    while true do
        task.wait(0.05)
        local ecoule = workspace:GetServerTimeNow() - debut
        setTemps(math.max(0, math.ceil(CONFIG.DUREE_MANCHE - math.max(ecoule, 0))))
        if ecoule >= CONFIG.DUREE_MANCHE then
            break
        end
        for _, g in ipairs(participants) do
            if g.Parent then
                local estBot = g:GetAttribute("Bot")
                local i = manche.prochaineNote[g]
                while notes[i] do
                    -- les bots jouent pile sur la note ; les joueurs ont 2 s pour envoyer leur résultat
                    local limite = if estBot then notes[i] else notes[i] + 2
                    if ecoule < limite then
                        break
                    end
                    if not manche.juges[g][i] then
                        manche.juges[g][i] = true
                        local progression = notes[i] / CONFIG.DUREE_MANCHE
                        appliquer(g, if estBot then verdictBot(g, progression) else "Rate", progression)
                    end
                    i += 1
                end
                manche.prochaineNote[g] = i
            end
        end
    end

    -- 5) FIN : le plus haut gagne. Égalité au sommet = CHECK PARFAIT entre les deux, puis ils dansent.
    setPhase("Fin")
    local classement = {}
    for _, g in ipairs(participants) do
        if g.Parent then
            table.insert(classement, g)
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

    for _, g in ipairs(gagnants) do
        local joueurGagnant = joueurDuGrimpeur[g]
        if joueurGagnant then
            ajouterStat(joueurGagnant, "Victoires", 1)
            ajouterStat(joueurGagnant, "Aura", 25)
        end
    end

    -- les records (en tâche de fond : la sauvegarde peut prendre un peu de temps)
    local nouveauxRecords = {}
    for _, g in ipairs(classement) do
        local joueurRecord = joueurDuGrimpeur[g]
        if joueurRecord then
            local score = g:GetAttribute("Marche") or 0
            local perso = g:GetAttribute("Perso")
            task.spawn(function()
                local recordPerso = enregistrerRecord("P_" .. tostring(perso), joueurRecord, score)
                local recordMusique = musique.id ~= "" and enregistrerRecord(cleMusique(musique), joueurRecord, score)
                local recordCombo = musique.id ~= "" and enregistrerRecord(cleCombo(tostring(perso), cleMusique(musique)), joueurRecord, score)
                enregistrerRecord("G", joueurRecord, score) -- 🌍 monde entier
                nouveauxRecords[g] = recordPerso or recordMusique or recordCombo
            end)
        end
    end

    if #gagnants >= 2 then
        setStatut("ÉGALITÉ ! " .. nomDuGrimpeur(gagnants[1]) .. " & " .. nomDuGrimpeur(gagnants[2]) .. " — " .. meilleur .. " marches")
        EvenementEvent:FireAllClients("Check", gagnants[1], gagnants[2])
        task.wait(2.6) -- le temps du check
    elseif gagnants[1] then
        local g = gagnants[1]
        setStatut("👑 " .. nomDuGrimpeur(g) .. " GAGNE avec " .. string.upper(tostring(g:GetAttribute("Perso"))) .. " — " .. meilleur .. " marches !")
        EvenementEvent:FireAllClients("Vainqueur", g)
        task.wait(2)
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

    local nomsGagnants = {}
    for _, g in ipairs(gagnants) do
        table.insert(nomsGagnants, nomDuGrimpeur(g))
    end
    for _, g in ipairs(classement) do
        local joueurFin = joueurDuGrimpeur[g]
        if joueurFin and joueurFin.Parent then
            local stats = manche.stats[g]
            local total = stats.parfaits + stats.biens + stats.rates
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
                record = recordDe("P_" .. tostring(g:GetAttribute("Perso")), joueurFin.UserId),
                nouveauRecord = nouveauxRecords[g] == true,
                auraFarmee = g:GetAttribute("AuraFarmee") or 0,
                parfaits = stats.parfaits,
                biens = stats.biens,
                rates = stats.rates,
                comboMax = stats.comboMax,
                precision = if total > 0 then math.floor((stats.parfaits + stats.biens) / total * 100) else 0,
                gagnant = if #nomsGagnants > 0 then table.concat(nomsGagnants, " & ") else "personne",
            })
        end
    end
    compteARebours(7)

    -- 6) ON RANGE
    for _, g in ipairs(bots) do
        local valeur = g:FindFirstChild("Modele")
        if valeur and valeur.Value then
            valeur.Value:Destroy()
        end
        g:Destroy()
    end
end
