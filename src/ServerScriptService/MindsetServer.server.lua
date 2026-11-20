--[[
    🧠 MINDSET STAIRS — Script SERVEUR
    À mettre dans : ServerScriptService  (type : Script)

    Jeu de rythme en 2D : une musique d'aura se lance, tu cliques sur les cercles en rythme,
    chaque note réussie te fait monter les marches, chaque note ratée te fait redescendre.
    Ce script construit la scène (les escaliers), gère les manches, les persos, les bots et la sauvegarde.
]]

-- ===================== RÉGLAGES (tu peux les modifier) =====================
local CONFIG = {
    ATTENTE_LOBBY = 15,   -- secondes pour choisir son perso
    PREPARATION = 4,      -- secondes de décompte avant la musique
    DUREE_MANCHE = 60,    -- durée d'une manche (secondes de musique)
    NB_MARCHES = 100,     -- marches jusqu'au sommet
    NB_COULOIRS = 8,      -- grimpeurs affichés en même temps (mets le même nombre en « Max joueurs »)
    COUREURS_MIN = 4,     -- des bots complètent jusqu'à ce nombre

    NB_PROPOSITIONS = 3,  -- musiques proposées au vote dans le lobby

    -- 🎵 MUSIQUES : à chaque lobby, 3 sont tirées au hasard et les joueurs votent.
    --   id       = l'ID Roblox du son, ex. "rbxassetid://1234567890"
    --              ⚠ une musique avec id = "" est ignorée (pas encore mise en ligne)
    --   nom      = le nom affiché sur le bouton de vote
    --   bpm      = le tempo de la musique → mesure-le avec le testeur : lance le jeu dans Studio et appuie sur B
    --   debut    = à quelle seconde du son on commence (pour démarrer direct sur le drop !)
    --   decalage = si les cercles tombent un peu à côté du rythme, ajuste ici (ex. 0.05 ou -0.05)
    -- (les anciennes musiques sont dans l'historique git, commit 19623be)
    MUSIQUES = {
        { id = "rbxassetid://74842327948915", nom = "BUFÓN!", bpm = 130, debut = 0, decalage = 0 },
        { id = "rbxassetid://134372266822247", nom = "MONTAGE SENNTANA", bpm = 130, debut = 0, decalage = 0 },
        { id = "rbxassetid://117822777228038", nom = "ME VS ME", bpm = 130, debut = 0, decalage = 0 },
        { id = "rbxassetid://84227603413943", nom = "NO ERA AMOR", bpm = 130, debut = 0, decalage = 0 },
        { id = "rbxassetid://80140071567818", nom = "EMPIRE", bpm = 130, debut = 0, decalage = 0 },
        { id = "rbxassetid://135464211325455", nom = "TIKI TIKI", bpm = 130, debut = 0, decalage = 0 },
        { id = "rbxassetid://127965945833744", nom = "Your Next Opponent Is You", bpm = 130, debut = 0, decalage = 0 },
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
ReplicatedStorage:SetAttribute("NbMarches", CONFIG.NB_MARCHES)
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

local dossierGrimpeurs = creer("Folder", { Name = "Grimpeurs", Parent = ReplicatedStorage })
-- Les musiques proposées au vote (StringValue "1", "2", "3" : Value = nom, attribut Votes)
local dossierChoixMusiques = creer("Folder", { Name = "ChoixMusiques", Parent = ReplicatedStorage })
dossierRemotes.Parent = ReplicatedStorage

-- 🎵 Testeur BPM (touche B) : en Studio seulement, on partage la liste des musiques avec le testeur
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
local scene = creer("Folder", { Name = "MindsetScene", Parent = workspace })
local N, H, D = CONFIG.NB_MARCHES, GEO.HAUTEUR, GEO.PROFONDEUR

local function bloc(proprietes)
    proprietes.Anchored = true
    proprietes.TopSurface = Enum.SurfaceType.Smooth
    proprietes.BottomSurface = Enum.SurfaceType.Smooth
    proprietes.Parent = proprietes.Parent or scene
    return creer("Part", proprietes)
end

for couloir = 0, CONFIG.NB_COULOIRS - 1 do
    local dossier = creer("Folder", { Name = "Couloir" .. couloir, Parent = scene })
    local z = GEO.Z0 - couloir * GEO.ECART
    for i = 0, N do
        local largeur, x = D, GEO.X0 + (i + 0.5) * D
        if i == 0 then
            largeur = D * 4
            x = GEO.X0 + D - largeur / 2
        elseif i == N then
            largeur = D * 4
            x = GEO.X0 + N * D + largeur / 2
        end
        bloc({
            Name = "Marche" .. i,
            Size = Vector3.new(largeur, H, 5),
            Position = Vector3.new(x, GEO.Y0 + i * H - H / 2, z),
            Color = if i == N then Color3.fromRGB(255, 210, 60) else Color3.fromRGB(235, 235, 245),
            Material = if i == N then Enum.Material.Neon else Enum.Material.SmoothPlastic,
            CastShadow = false,
            Parent = dossier,
        })
    end
    -- Ligne néon le long des marches (le client la colore avec la couleur du perso)
    local dx, dy = N * D, N * H
    bloc({
        Name = "Ligne",
        Size = Vector3.new(math.sqrt(dx * dx + dy * dy), 0.35, 0.35),
        CFrame = CFrame.new(GEO.X0 + dx / 2, GEO.Y0 + dy / 2, z + 2.6) * CFrame.Angles(0, 0, math.atan2(dy, dx)),
        Color = Color3.fromRGB(200, 200, 210),
        Material = Enum.Material.Neon,
        CanCollide = false,
        CastShadow = false,
        Parent = dossier,
    })
end

-- Fond noir + poussière d'aura qui flotte
local centreScene = Vector3.new(GEO.X0 + N * D / 2, GEO.Y0 + N * H / 2, 0)
local fondZ = GEO.Z0 - CONFIG.NB_COULOIRS * GEO.ECART - 15
bloc({
    Name = "Fond",
    Size = Vector3.new(900, 600, 2),
    Position = Vector3.new(centreScene.X, centreScene.Y, fondZ),
    Color = Color3.fromRGB(8, 8, 14),
    Material = Enum.Material.SmoothPlastic,
    CastShadow = false,
})
local poussiere = bloc({
    Name = "Poussiere",
    Size = Vector3.new(500, 300, 1),
    Position = Vector3.new(centreScene.X, centreScene.Y, fondZ + 8),
    Transparency = 1,
    CanCollide = false,
})
creer("ParticleEmitter", {
    Rate = 60,
    Lifetime = NumberRange.new(6, 10),
    Speed = NumberRange.new(1, 3),
    SpreadAngle = Vector2.new(180, 180),
    Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, 0.7),
        NumberSequenceKeypoint.new(1, 0),
    }),
    Transparency = NumberSequence.new(0.3),
    LightEmission = 1,
    Color = ColorSequence.new(Color3.fromRGB(200, 200, 255)),
    Parent = poussiere,
})

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
    essayer(function()
        sauvegarde:UpdateAsync("joueur_" .. joueur.UserId, function(anciennes)
            local donnees = anciennes or {}
            donnees.victoires = victoires
            donnees.aura = aura
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

    local marche = math.clamp((g:GetAttribute("Marche") or 0) + gain, 0, CONFIG.NB_MARCHES)
    g:SetAttribute("Combo", combo)
    g:SetAttribute("NiveauAura", if combo >= 50 then 3 elseif combo >= 25 then 2 elseif combo >= 10 then 1 else 0)
    g:SetAttribute("Marche", marche)

    if marche >= CONFIG.NB_MARCHES and not stats.sommetA then
        stats.sommetA = os.clock()
        EvenementEvent:FireAllClients("Sommet", g:GetAttribute("Nom"), perso)
    end

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

-- ========================== PARTITION ==========================
-- Une note par temps (2 temps au début pour s'échauffer), et quelques doubles notes à la fin.
local function genererPartition(musique)
    local intervalle = 60 / musique.bpm
    local notes = {}
    local t = musique.decalage
    while t < 2 * intervalle do
        t += intervalle
    end
    while t < CONFIG.DUREE_MANCHE - 1 do
        local progression = t / CONFIG.DUREE_MANCHE
        table.insert(notes, t)
        if progression > 0.75 and math.random() < 0.25 then
            table.insert(notes, t + intervalle / 2)
        end
        t += intervalle * (if progression < 0.2 then 2 else 1)
    end
    return notes
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
        local valeur = creer("StringValue", { Name = tostring(i), Value = m.nom or ("Musique " .. i), Parent = dossierChoixMusiques })
        valeur:SetAttribute("Votes", 0)
    end
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
    end
    setStatut(if #propositions > 0 then "🧠 Choisis ton état d'esprit et vote pour la musique !" else "🧠 Choisis ton état d'esprit !")
    compteARebours(CONFIG.ATTENTE_LOBBY)

    local participants = {}
    local persosPris = {}
    for joueur, g in pairs(grimpeurDesJoueurs) do
        if joueur.Parent and joueur.Character then
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
    local notes = genererPartition(musique)
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

    -- 5) FIN : classement, cinématique du vainqueur, écrans de fin
    setPhase("Fin")
    local classement = {}
    for _, g in ipairs(participants) do
        if g.Parent then
            table.insert(classement, g)
        end
    end
    table.sort(classement, function(a, b)
        local sa, sb = manche.stats[a].sommetA, manche.stats[b].sommetA
        if sa and sb then
            return sa < sb
        end
        if sa ~= sb then
            return sa ~= nil
        end
        return (a:GetAttribute("Marche") or 0) > (b:GetAttribute("Marche") or 0)
    end)

    local vainqueur = classement[1]
    if vainqueur then
        setStatut("👑 " .. vainqueur:GetAttribute("Nom") .. " GAGNE avec " .. string.upper(vainqueur:GetAttribute("Perso")) .. " !")
        EvenementEvent:FireAllClients("Vainqueur", vainqueur)
        local joueurGagnant = joueurDuGrimpeur[vainqueur]
        if joueurGagnant then
            ajouterStat(joueurGagnant, "Victoires", 1)
            ajouterStat(joueurGagnant, "Aura", 25)
        end
    end

    task.wait(4) -- le temps de la cinématique du vainqueur

    for place, g in ipairs(classement) do
        local joueur = joueurDuGrimpeur[g]
        if joueur and joueur.Parent then
            local stats = manche.stats[g]
            local total = stats.parfaits + stats.biens + stats.rates
            FinEvent:FireClient(joueur, {
                perso = g:GetAttribute("Perso"),
                place = place,
                total = #classement,
                marches = g:GetAttribute("Marche") or 0,
                nbMarches = CONFIG.NB_MARCHES,
                parfaits = stats.parfaits,
                biens = stats.biens,
                rates = stats.rates,
                comboMax = stats.comboMax,
                precision = if total > 0 then math.floor((stats.parfaits + stats.biens) / total * 100) else 0,
                gagnant = if vainqueur then vainqueur:GetAttribute("Nom") else "personne",
            })
        end
    end
    compteARebours(8)

    -- 6) ON RANGE
    for _, g in ipairs(bots) do
        local valeur = g:FindFirstChild("Modele")
        if valeur and valeur.Value then
            valeur.Value:Destroy()
        end
        g:Destroy()
    end
end
