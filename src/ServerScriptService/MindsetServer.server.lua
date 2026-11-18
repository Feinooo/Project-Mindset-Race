--[[
    🧠 MINDSET RACE — Script SERVEUR
    À mettre dans : ServerScriptService  (type : Script)

    Ce script construit TOUT seul : la piste, les podiums du lobby, l'arche d'arrivée.
    Il gère aussi les courses, les personnages, les événements et les bots.
]]

-- ===================== RÉGLAGES (tu peux les modifier) =====================
local CONFIG = {
    ATTENTE_LOBBY = 15,        -- secondes dans le lobby avant la course
    DUREE_MAX_COURSE = 60,     -- la course s'arrête au bout de X secondes
    LONGUEUR_PISTE = 700,      -- longueur de la piste (en studs)
    LARGEUR_PISTE = 44,
    COUREURS_MIN = 4,          -- des bots complètent jusqu'à ce nombre
    NB_DIAMANTS = 14,
    NB_CANAPES = 8,
    NB_EVENEMENTS_MAX = 3,     -- événements par course
    ID_MUSIQUE_AURA = "",      -- exemple : "rbxassetid://1234567890" (laisse vide = pas de son)
    VICTOIRES_POUR_TALENT = 10, -- victoires nécessaires pour débloquer Talent
    RECHARGE_ATTAQUE = 6,      -- secondes entre deux tacles/balayettes
    DUREE_CHUTE = 1.6,         -- temps au sol après un tacle ou une balayette
    PORTEE_TACLE = 9,          -- le tacle touche quelqu'un DEVANT toi
    PORTEE_BALAYETTE = 6,      -- la balayette touche quelqu'un AUTOUR de toi (parfait juste après un dépassement)
    AVATARS_BOTS = {},         -- optionnel : des UserId Roblox dont les bots copient l'avatar (ex. ceux de tes amis, avec leur accord)
}
-- ===========================================================================

local PERSOS = {
    Motivation = {
        couleur = Color3.fromRGB(255, 150, 30),
        description = "Très rapide au départ\nDéteste la pluie",
    },
    Ego = {
        couleur = Color3.fromRGB(170, 80, 255),
        description = "Accélère quand on le double\nS'arrête pour les diamants",
    },
    Discipline = {
        couleur = Color3.fromRGB(60, 140, 255),
        description = "Vitesse constante\nIgnore pluie et pièges",
    },
    Obsession = {
        couleur = Color3.fromRGB(230, 40, 60),
        description = "Lent au début\nPuis accélère sans arrêt",
    },
    Talent = {
        couleur = Color3.fromRGB(60, 220, 140),
        description = "Le plus rapide du jeu\nMais s'ennuie et s'arrête",
        verrou = true, -- se débloque avec CONFIG.VICTOIRES_POUR_TALENT victoires
    },
}
local ORDRE_PERSOS = { "Motivation", "Ego", "Discipline", "Obsession" } -- persos de base (bots et tirage au hasard)
local ORDRE_PODIUMS = { "Motivation", "Ego", "Discipline", "Obsession", "Talent" }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

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

-- ========================== COMMUNICATION ==========================
local dossierRemotes = Instance.new("Folder")
dossierRemotes.Name = "MindsetRemotes"
local function remote(nom)
    return creer("RemoteEvent", { Name = nom, Parent = dossierRemotes })
end
local AnnonceEvent = remote("Annonce")
local EvenementEvent = remote("Evenement")
local AuraEvent = remote("Aura")
local FinEvent = remote("Fin")
local ChuteEvent = remote("Chute")     -- serveur -> joueur : « tu t'es pris un tacle »
local AttaqueEvent = remote("Attaque") -- joueur -> serveur : « je tacle » / serveur -> joueur : résultat
dossierRemotes.Parent = ReplicatedStorage

ReplicatedStorage:SetAttribute("IdMusiqueAura", CONFIG.ID_MUSIQUE_AURA)

local function setStatut(texte)
    ReplicatedStorage:SetAttribute("Statut", texte)
end
local function setTemps(secondes)
    ReplicatedStorage:SetAttribute("Temps", secondes)
end

-- ========================== CONSTRUCTION DE LA MAP ==========================
local X0, Y0 = 300, 100 -- la piste est en hauteur, à côté du lobby
local L, W = CONFIG.LONGUEUR_PISTE, CONFIG.LARGEUR_PISTE
local SOL = Y0 + 1      -- hauteur du dessus de la piste

local carte = creer("Folder", { Name = "MindsetRaceCarte", Parent = workspace })
local dossierObstacles = creer("Folder", { Name = "Obstacles", Parent = carte })

local function bloc(proprietes)
    proprietes.Anchored = true
    proprietes.TopSurface = Enum.SurfaceType.Smooth
    proprietes.BottomSurface = Enum.SurfaceType.Smooth
    proprietes.Parent = proprietes.Parent or carte
    return creer("Part", proprietes)
end

local function panneau(part, texte, couleur, largeur, hauteur, decalage)
    local gui = creer("BillboardGui", {
        Size = UDim2.fromScale(largeur, hauteur),
        StudsOffset = Vector3.new(0, decalage, 0),
        MaxDistance = 200,
        Parent = part,
    })
    creer("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Font = Enum.Font.FredokaOne,
        TextScaled = true,
        TextColor3 = couleur,
        TextStrokeTransparency = 0,
        Text = texte,
        Parent = gui,
    })
    return gui
end

-- Piste
bloc({
    Name = "Piste",
    Size = Vector3.new(W, 2, L + 80),
    Position = Vector3.new(X0, Y0, L / 2 + 20),
    Color = Color3.fromRGB(45, 45, 55),
    Material = Enum.Material.SmoothPlastic,
})
for _, cote in ipairs({ -1, 1 }) do
    bloc({
        Name = "Mur",
        Size = Vector3.new(2, 24, L + 80),
        Position = Vector3.new(X0 + cote * (W / 2 + 1), SOL + 12, L / 2 + 20),
        Color = Color3.fromRGB(25, 25, 35),
        Transparency = 0.3,
    })
end
bloc({ Name = "MurArriere", Size = Vector3.new(W + 4, 24, 2), Position = Vector3.new(X0, SOL + 12, -21), Transparency = 0.5 })
bloc({ Name = "MurFond", Size = Vector3.new(W + 4, 24, 2), Position = Vector3.new(X0, SOL + 12, L + 61), Transparency = 0.5 })

-- Ligne de départ
bloc({
    Name = "LigneDepart",
    Size = Vector3.new(W, 0.2, 1.5),
    Position = Vector3.new(X0, SOL + 0.1, 0),
    Color = Color3.fromRGB(255, 255, 255),
    Material = Enum.Material.Neon,
    CanCollide = false,
})

-- Ligne d'arrivée en damier + arche
for i = 0, math.floor(W / 4) - 1 do
    for rangee = 0, 1 do
        bloc({
            Name = "Damier",
            Size = Vector3.new(4, 0.2, 4),
            Position = Vector3.new(X0 - W / 2 + 2 + i * 4, SOL + 0.1, L + rangee * 4),
            Color = if (i + rangee) % 2 == 0 then Color3.new(1, 1, 1) else Color3.new(0, 0, 0),
            CanCollide = false,
        })
    end
end
for _, cote in ipairs({ -1, 1 }) do
    bloc({
        Name = "Pilier",
        Size = Vector3.new(2, 20, 2),
        Position = Vector3.new(X0 + cote * (W / 2 - 1), SOL + 10, L),
        Color = Color3.fromRGB(255, 200, 40),
        Material = Enum.Material.Neon,
    })
end
local poutre = bloc({
    Name = "Arche",
    Size = Vector3.new(W, 3, 2),
    Position = Vector3.new(X0, SOL + 21, L),
    Color = Color3.fromRGB(255, 200, 40),
    Material = Enum.Material.Neon,
})
panneau(poutre, "🏁 ARRIVÉE 🏁", Color3.new(1, 1, 1), 30, 6, 5)

-- Lobby : podiums de choix du personnage
local panneauLobby = bloc({
    Name = "PanneauLobby",
    Size = Vector3.new(1, 1, 1),
    Position = Vector3.new(0, 14, -40),
    Transparency = 1,
    CanCollide = false,
})
panneau(panneauLobby, "🧠 MINDSET RACE\nMonte sur un podium pour choisir ton état d'esprit", Color3.new(1, 1, 1), 40, 10, 0)

local function nombreVictoires(joueur)
    local stats = joueur:FindFirstChild("leaderstats")
    local victoires = stats and stats:FindFirstChild("Victoires")
    return if victoires then victoires.Value else 0
end

local avertis = setmetatable({}, { __mode = "k" }) -- évite de spammer le message « verrouillé »

for i, nom in ipairs(ORDRE_PODIUMS) do
    local info = PERSOS[nom]
    local podium = bloc({
        Name = "Podium_" .. nom,
        Size = Vector3.new(10, 1, 10),
        Position = Vector3.new(-48 + (i - 1) * 24, 0.5, -30),
        Color = info.couleur,
        Material = Enum.Material.Neon,
    })
    local titre = if info.verrou then "🔒 " .. string.upper(nom) else string.upper(nom)
    local description = if info.verrou
        then CONFIG.VICTOIRES_POUR_TALENT .. " victoires pour débloquer\n" .. info.description
        else info.description
    panneau(podium, titre, info.couleur, 14, 3, 7)
    panneau(podium, description, Color3.new(1, 1, 1), 14, 3, 4)

    podium.Touched:Connect(function(touche)
        local modele = touche:FindFirstAncestorOfClass("Model")
        local joueur = modele and Players:GetPlayerFromCharacter(modele)
        if not joueur or joueur:GetAttribute("Perso") == nom then
            return
        end
        if info.verrou then
            local victoires = nombreVictoires(joueur)
            if victoires < CONFIG.VICTOIRES_POUR_TALENT then
                local maintenant = os.clock()
                if maintenant - (avertis[joueur] or 0) > 2 then
                    avertis[joueur] = maintenant
                    AnnonceEvent:FireClient(
                        joueur,
                        "🔒 Gagne " .. CONFIG.VICTOIRES_POUR_TALENT .. " courses pour " .. string.upper(nom)
                            .. " (" .. victoires .. "/" .. CONFIG.VICTOIRES_POUR_TALENT .. ")",
                        2
                    )
                end
                return
            end
        end
        joueur:SetAttribute("Perso", nom)
    end)
end

-- ========================== SAUVEGARDE (DataStore) ==========================
-- Garde les victoires et l'aura de chaque joueur d'une partie à l'autre.
-- ⚠️ Pour tester dans Studio : publie le jeu, puis
--    Paramètres du jeu > Sécurité > « Activer l'accès Studio aux services API ».
local DataStoreService = game:GetService("DataStoreService")
local donneesChargees = {} -- [joueur] = true seulement si le chargement a réussi
local sauvegarde = nil
do
    -- Si le jeu n'est pas publié, Roblox refuse l'accès : on joue quand même, mais sans sauvegarde
    local ok, resultat = pcall(function()
        return DataStoreService:GetDataStore("MindsetRace_Joueurs_v1")
    end)
    if ok then
        sauvegarde = resultat
    else
        warn("💾 Sauvegarde désactivée (publie le jeu et active l'accès Studio aux services API) :", resultat)
    end
end

local function cle(joueur)
    return "joueur_" .. joueur.UserId
end

-- Réessaie jusqu'à 3 fois, car les serveurs Roblox ratent parfois une requête
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
        return sauvegarde:GetAsync(cle(joueur))
    end)
    if not joueur.Parent then
        return
    end
    if ok then
        donnees = donnees or {}
        -- « += » : on garde aussi ce qu'il a gagné pendant le chargement
        stats.Victoires.Value += donnees.victoires or 0
        stats.Aura.Value += donnees.aura or 0
        donneesChargees[joueur] = true
    else
        -- On ne sauvegardera PAS ce joueur, pour ne pas écraser ses vraies données par des zéros
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
    local victoires = stats.Victoires.Value
    local aura = stats.Aura.Value
    essayer(function()
        sauvegarde:UpdateAsync(cle(joueur), function(anciennes)
            local donnees = anciennes or {}
            donnees.victoires = victoires
            donnees.aura = aura
            return donnees
        end)
    end)
end

-- ========================== JOUEURS ==========================
local function joueurArrive(joueur)
    local stats = creer("Folder", { Name = "leaderstats", Parent = joueur })
    creer("IntValue", { Name = "Victoires", Parent = stats })
    creer("IntValue", { Name = "Aura", Parent = stats })
    joueur:SetAttribute("Rang", 0)
    task.spawn(chargerJoueur, joueur, stats)
end
Players.PlayerAdded:Connect(joueurArrive)
for _, joueur in ipairs(Players:GetPlayers()) do
    joueurArrive(joueur)
end

Players.PlayerRemoving:Connect(function(joueur)
    sauverJoueur(joueur)
    donneesChargees[joueur] = nil
end)

-- Quand le serveur s'éteint : on sauvegarde tout le monde avant
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

-- Sauvegarde automatique toutes les 2 minutes (au cas où le serveur plante)
task.spawn(function()
    while true do
        task.wait(120)
        for _, joueur in ipairs(Players:GetPlayers()) do
            task.spawn(sauverJoueur, joueur)
        end
    end
end)

local function ajouterStat(joueur, nom, nombre)
    local stats = joueur and joueur:FindFirstChild("leaderstats")
    local valeur = stats and stats:FindFirstChild(nom)
    if valeur then
        valeur.Value += nombre
    end
end

-- ========================== COUREURS ==========================
local coureurs = {}
local diamants = {}
local canapes = {}
local pluieJusqua = 0
local telephoneJusqua = 0
local courseEnCours = false
local debutCourse = 0

local function nouveauCoureur(nom, perso, modele, joueur)
    return {
        nom = nom,
        perso = perso,
        modele = modele,
        joueur = joueur,
        humanoid = modele:FindFirstChildOfClass("Humanoid"),
        root = modele:FindFirstChild("HumanoidRootPart"),
        fini = false,
        temps = nil,
        place = nil,
        rang = nil,
        rangPrecedent = nil,
        diamants = 0,
        depassements = 0,
        ralentiJusqua = 0,
        boostJusqua = 0,
        arretJusqua = 0,
        derniereAura = 0,
        dashJusqua = 0,         -- élan du tacle
        protegeJusqua = 0,      -- ne peut pas être re-taclé tout de suite
        prochaineAttaque = 0,
        attaques = 0,           -- tacles/balayettes réussis
        prochainEnnui = math.huge, -- Talent : prochaine pause
        pauses = 0,
        -- bots uniquement
        forme = 1,
        reaction = 0,
        vigilant = false,
        cibleX = nil,
        prochainChangement = 0,
    }
end

local function valide(c)
    return c.modele.Parent ~= nil
        and c.humanoid ~= nil
        and c.humanoid.Health > 0
        and c.root ~= nil
        and c.root.Parent ~= nil
        and (c.joueur == nil or c.joueur.Parent ~= nil)
end

-- ---------- Bots réalistes : look, pseudo, animations ----------
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
local ANIM_COURSE = "rbxassetid://913376220"  -- animation de course R15 par défaut de Roblox
local ANIM_ATTENTE = "rbxassetid://507766388" -- animation d'attente R15 par défaut de Roblox

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

local function descriptionDeBot(perso)
    if #CONFIG.AVATARS_BOTS > 0 then
        local ok, description = pcall(function()
            return Players:GetHumanoidDescriptionFromUserId(auHasard(CONFIG.AVATARS_BOTS))
        end)
        if ok and description then
            return description
        end
    end
    local peau = auHasard(PEAUX)
    local tshirt = PERSOS[perso].couleur
    local bras = if math.random() < 0.5 then peau else tshirt -- manches courtes ou longues
    local jambes = auHasard(PANTALONS)
    local description = Instance.new("HumanoidDescription")
    description.HeadColor = peau
    description.TorsoColor = tshirt
    description.LeftArmColor = bras
    description.RightArmColor = bras
    description.LeftLegColor = jambes
    description.RightLegColor = jambes
    return description
end

local function animerBot(humanoid)
    local animator = humanoid:FindFirstChildOfClass("Animator") or creer("Animator", { Parent = humanoid })
    local function charger(id)
        local animation = Instance.new("Animation")
        animation.AnimationId = id
        local piste = animator:LoadAnimation(animation)
        piste.Looped = true
        return piste
    end
    local course = charger(ANIM_COURSE)
    local attente = charger(ANIM_ATTENTE)
    attente:Play()
    humanoid.Running:Connect(function(vitesseActuelle)
        if vitesseActuelle > 1 then
            if not course.IsPlaying then
                attente:Stop(0.2)
                course:Play(0.2)
            end
            course:AdjustSpeed(math.clamp(vitesseActuelle / 22, 0.6, 1.8))
        elseif not attente.IsPlaying then
            course:Stop(0.2)
            attente:Play(0.2)
        end
    end)
end

local function creerBot(perso)
    local ok, modele = pcall(function()
        return Players:CreateHumanoidModelFromDescription(descriptionDeBot(perso), Enum.HumanoidRigType.R15)
    end)
    if not ok or not modele then
        warn("Impossible de créer un bot :", modele)
        return nil
    end
    local pseudo = pseudoDeBot()
    modele.Name = pseudo
    local animate = modele:FindFirstChild("Animate")
    if animate then
        animate:Destroy() -- on gère les animations nous-mêmes
    end
    modele.Parent = workspace
    local humanoid = modele:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayName = pseudo
        local okAnim, erreur = pcall(animerBot, humanoid)
        if not okAnim then
            warn("Animations du bot impossibles :", erreur)
        end
    end
    local racine = modele:FindFirstChild("HumanoidRootPart")
    if racine then
        racine:SetNetworkOwner(nil)
    end
    return modele, pseudo
end

local function bloquer(c, bloque)
    if not c.humanoid then
        return
    end
    if bloque then
        c.humanoid.WalkSpeed = 0
        c.humanoid.JumpPower = 0
        c.humanoid.JumpHeight = 0
    else
        c.humanoid.JumpPower = 50
        c.humanoid.JumpHeight = 7.2
    end
end

local function etiquettePerso(c)
    local tete = c.modele:FindFirstChild("Head")
    if tete then
        local gui = panneau(tete, string.upper(c.perso), PERSOS[c.perso].couleur, 6, 1.5, 3.2)
        gui.AlwaysOnTop = true
        gui.MaxDistance = 120
        gui.PlayerToHideFrom = c.joueur -- en 1re personne, on ne voit pas sa propre étiquette
    end
end

local function effetAura(c)
    if not valide(c) then
        return
    end
    local surbrillance = creer("Highlight", {
        FillColor = Color3.fromRGB(255, 220, 80),
        OutlineColor = Color3.new(1, 1, 1),
        FillTransparency = 0.4,
        Parent = c.modele,
    })
    Debris:AddItem(surbrillance, 1.5)
    local etincelles = creer("ParticleEmitter", {
        Texture = "rbxasset://textures/particles/sparkles_main.dds",
        Color = ColorSequence.new(Color3.fromRGB(255, 220, 80)),
        LightEmission = 1,
        Rate = 60,
        Lifetime = NumberRange.new(0.5, 1),
        Speed = NumberRange.new(4, 8),
        SpreadAngle = Vector2.new(180, 180),
        Size = NumberSequence.new(0.8, 0),
        Parent = c.root,
    })
    Debris:AddItem(etincelles, 1.5)
end

local function prevenir(c, texte, duree)
    if c.joueur then
        AnnonceEvent:FireClient(c.joueur, texte, duree or 1.5)
    end
end

-- Vitesse de chaque personnage (c'est ici qu'on équilibre le jeu !)
local function vitesse(c, t, maintenant)
    local perso = c.perso
    local v
    if perso == "Motivation" then
        v = math.max(20, 36 - t) -- part très vite puis s'essouffle
        if maintenant < pluieJusqua then
            v *= 0.5
        end
    elseif perso == "Ego" then
        v = 24
        if maintenant < c.boostJusqua then
            v = 34
        end
    elseif perso == "Discipline" then
        v = 23
    elseif perso == "Obsession" then
        if t < 8 then
            v = 14
        else
            v = math.min(34, 14 + (t - 8) * 1.5) -- accélère sans arrêt
        end
    elseif perso == "Talent" then
        v = 38 -- le plus rapide... quand il veut bien courir (voir gererTalent)
    else
        v = 20
    end
    v *= c.forme -- les bots ont une petite « forme du jour »

    if maintenant < telephoneJusqua and perso ~= "Discipline" and perso ~= "Obsession" then
        v *= 0.3
    end
    if maintenant < c.ralentiJusqua and perso ~= "Discipline" then
        v *= 0.35
    end
    if maintenant < c.dashJusqua then
        v *= 1.6 -- élan du tacle
    end
    if maintenant < c.arretJusqua then
        v = 0
    end
    return v
end

local function placerObstacles()
    dossierObstacles:ClearAllChildren()
    diamants = {}
    canapes = {}
    local function positionAuHasard()
        return X0 + math.random(-W / 2 + 4, W / 2 - 4), math.random(60, L - 40)
    end
    for _ = 1, CONFIG.NB_DIAMANTS do
        local x, z = positionAuHasard()
        local diamant = bloc({
            Name = "Diamant",
            Size = Vector3.new(2, 2, 2),
            CFrame = CFrame.new(x, SOL + 2, z) * CFrame.Angles(0, math.rad(45), math.rad(45)),
            Color = Color3.fromRGB(80, 230, 255),
            Material = Enum.Material.Neon,
            CanCollide = false,
            Parent = dossierObstacles,
        })
        table.insert(diamants, { part = diamant, position = diamant.Position })
    end
    for _ = 1, CONFIG.NB_CANAPES do
        local x, z = positionAuHasard()
        local assise = bloc({
            Name = "Canape",
            Size = Vector3.new(10, 2, 4),
            Position = Vector3.new(x, SOL + 1, z),
            Color = Color3.fromRGB(150, 90, 60),
            Material = Enum.Material.Fabric,
            CanCollide = false,
            Parent = dossierObstacles,
        })
        bloc({
            Name = "Dossier",
            Size = Vector3.new(10, 3, 1),
            Position = Vector3.new(x, SOL + 2.5, z + 2),
            Color = Color3.fromRGB(130, 75, 50),
            Material = Enum.Material.Fabric,
            CanCollide = false,
            Parent = dossierObstacles,
        })
        panneau(assise, "🛋️", Color3.new(1, 1, 1), 3, 3, 4)
        table.insert(canapes, { position = assise.Position })
    end
end

local function verifierObstacles(c, maintenant)
    local position = c.root.Position
    for i = #diamants, 1, -1 do
        local diamant = diamants[i]
        local dx, dz = position.X - diamant.position.X, position.Z - diamant.position.Z
        if dx * dx + dz * dz < 3.5 * 3.5 and c.perso ~= "Obsession" then
            c.diamants += 1
            diamant.part:Destroy()
            table.remove(diamants, i)
            ajouterStat(c.joueur, "Aura", 2)
            if c.perso == "Ego" then
                c.arretJusqua = maintenant + 1.2
                prevenir(c, "💎 Trop beau... l'Ego s'arrête pour poser 💅", 1.2)
            else
                prevenir(c, "💎 +1 diamant", 0.8)
            end
        end
    end
    if c.perso ~= "Discipline" then
        for _, canape in ipairs(canapes) do
            if math.abs(position.X - canape.position.X) < 6 and math.abs(position.Z - canape.position.Z) < 3 then
                if maintenant > c.ralentiJusqua then
                    prevenir(c, "🛋️ Ce canapé a l'air tellement confortable...", 1.2)
                end
                c.ralentiJusqua = maintenant + 1.5
            end
        end
    end
end

local function declencherEvenement(type, maintenant)
    if type == "Pluie" then
        pluieJusqua = maintenant + 7
        EvenementEvent:FireAllClients("Pluie", 7)
    elseif type == "Telephone" then
        telephoneJusqua = maintenant + 2.5
        EvenementEvent:FireAllClients("Telephone", 2.5)
    elseif type == "Public" then
        for _, c in ipairs(coureurs) do
            if c.perso == "Ego" then
                c.boostJusqua = maintenant + 3
            end
        end
        EvenementEvent:FireAllClients("Public", 3)
    end
end

-- ========================== TALENT ==========================
local function gererTalent(c, maintenant)
    if maintenant >= c.prochainEnnui then
        local pause = math.random(20, 35) / 10
        c.arretJusqua = math.max(c.arretJusqua, maintenant + pause)
        c.prochainEnnui = maintenant + pause + math.random(40, 80) / 10
        c.pauses += 1
        prevenir(c, "🥱 Talent s'ennuie... petite pause", 1.5)
    end
end

-- ========================== TACLES ET BALAYETTES ==========================
local ATTAQUES_VALIDES = { Tacle = true, Balayette = true }

local function trouverCoureur(joueur)
    for _, c in ipairs(coureurs) do
        if c.joueur == joueur then
            return c
        end
    end
    return nil
end

-- Tacle : quelqu'un DEVANT toi. Balayette : quelqu'un AUTOUR de toi.
local function cibleProche(attaquant, typeAttaque, maintenant)
    local position = attaquant.root.Position
    local meilleure, meilleureDistance = nil, math.huge
    for _, c in ipairs(coureurs) do
        if c ~= attaquant and not c.fini and valide(c) and maintenant >= c.protegeJusqua then
            local ecart = c.root.Position - position
            local distance = Vector3.new(ecart.X, 0, ecart.Z).Magnitude
            local aPortee
            if typeAttaque == "Tacle" then
                aPortee = distance <= CONFIG.PORTEE_TACLE and ecart.Z > -1
            else
                aPortee = distance <= CONFIG.PORTEE_BALAYETTE
            end
            if aPortee and distance < meilleureDistance then
                meilleure, meilleureDistance = c, distance
            end
        end
    end
    return meilleure
end

local function attaquer(c, typeAttaque, maintenant)
    if not courseEnCours or maintenant - debutCourse < 2 then
        return -- pas de bagarre sur la ligne de départ
    end
    if maintenant < c.prochaineAttaque or maintenant < c.arretJusqua then
        return -- encore en recharge, ou déjà par terre
    end
    c.prochaineAttaque = maintenant + CONFIG.RECHARGE_ATTAQUE
    if c.joueur then
        c.joueur:SetAttribute("RechargeFin", workspace:GetServerTimeNow() + CONFIG.RECHARGE_ATTAQUE)
    end
    if typeAttaque == "Tacle" then
        c.dashJusqua = maintenant + 0.5 -- on se jette en avant
    end

    local cible = cibleProche(c, typeAttaque, maintenant)
    if not cible then
        if typeAttaque == "Tacle" then
            c.ralentiJusqua = maintenant + 1.2 -- tacle dans le vide : on se relève lentement
        end
        if c.joueur then
            AttaqueEvent:FireClient(c.joueur, "Rate", typeAttaque)
        end
        return
    end

    local duree = if cible.perso == "Discipline" then CONFIG.DUREE_CHUTE * 0.5 else CONFIG.DUREE_CHUTE
    cible.arretJusqua = math.max(cible.arretJusqua, maintenant + duree)
    cible.protegeJusqua = maintenant + duree + 2.5 -- pas de tacles à la chaîne sur la même personne
    c.attaques += 1

    if cible.joueur then
        ChuteEvent:FireClient(cible.joueur, c.nom, typeAttaque, duree)
    else
        local humanoid = cible.humanoid
        humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
        cible.root.AssemblyLinearVelocity += Vector3.new(0, 18, 0)
        task.delay(duree, function()
            if humanoid.Parent then
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end)
    end
    if c.joueur then
        ajouterStat(c.joueur, "Aura", 3)
        AttaqueEvent:FireClient(c.joueur, "Touche", typeAttaque, cible.nom)
    end
end

AttaqueEvent.OnServerEvent:Connect(function(joueur, typeAttaque)
    if not ATTAQUES_VALIDES[typeAttaque] then
        return
    end
    local c = trouverCoureur(joueur)
    if c and not c.fini and valide(c) then
        attaquer(c, typeAttaque, os.clock())
    end
end)

-- ========================== CERVEAU DES BOTS ==========================
local GAUCHE, DROITE = X0 - W / 2 + 3, X0 + W / 2 - 3

local function piloterBot(c, t, maintenant)
    if t < c.reaction then
        return -- temps de réaction au départ, comme un vrai joueur
    end
    local position = c.root.Position

    -- 1) il change un peu de couloir de temps en temps
    if maintenant >= c.prochainChangement then
        c.prochainChangement = maintenant + math.random(15, 35) / 10
        c.cibleX = math.clamp(c.laneX + math.random(-6, 6), GAUCHE, DROITE)
    end
    local cibleX = c.cibleX or c.laneX

    if c.perso == "Ego" then
        -- 2) l'Ego fonce vers les diamants
        for _, diamant in ipairs(diamants) do
            local dz = diamant.position.Z - position.Z
            if dz > 0 and dz < 25 and math.abs(diamant.position.X - position.X) < 12 then
                cibleX = diamant.position.X
                break
            end
        end
    elseif c.vigilant and c.perso ~= "Discipline" then
        -- 3) les autres esquivent les canapés... s'ils les voient à temps
        for _, canape in ipairs(canapes) do
            local dz = canape.position.Z - position.Z
            if dz > 3 and dz < 20 and math.abs(canape.position.X - cibleX) < 7 then
                local aGauche, aDroite = canape.position.X - 8, canape.position.X + 8
                if aGauche > GAUCHE and (math.abs(aGauche - position.X) < math.abs(aDroite - position.X) or aDroite > DROITE) then
                    cibleX = aGauche
                else
                    cibleX = aDroite
                end
                break
            end
        end
    end

    -- 4) petit saut de temps en temps
    if math.random() < 0.004 then
        c.humanoid.Jump = true
    end

    -- 5) balayette sur un adversaire tout proche
    if maintenant >= c.prochaineAttaque and math.random() < 0.04 and cibleProche(c, "Balayette", maintenant) then
        attaquer(c, "Balayette", maintenant)
    end

    c.humanoid:MoveTo(Vector3.new(cibleX, SOL, math.min(position.Z + 30, L + 50)))
end

local function calculerRangs(t, maintenant)
    local liste = {}
    for _, c in ipairs(coureurs) do
        if c.fini or valide(c) then
            table.insert(liste, c)
        end
    end
    table.sort(liste, function(a, b)
        if a.fini and b.fini then
            return a.place < b.place
        end
        if a.fini ~= b.fini then
            return a.fini
        end
        return a.root.Position.Z > b.root.Position.Z
    end)

    for i, c in ipairs(liste) do
        c.rangPrecedent = c.rang
        c.rang = i
        if c.joueur and c.joueur.Parent then
            c.joueur:SetAttribute("Rang", i)
            c.joueur:SetAttribute("NbCoureurs", #liste)
        end
        if c.rangPrecedent and t > 2 then
            if c.rang < c.rangPrecedent and maintenant - c.derniereAura > 1.5 then
                -- ✨ MOMENT AURA : on vient de doubler quelqu'un
                c.derniereAura = maintenant
                c.depassements += 1
                effetAura(c)
                if c.joueur then
                    AuraEvent:FireClient(c.joueur, "✨ DÉPASSEMENT ✨")
                    ajouterStat(c.joueur, "Aura", 5)
                end
            elseif c.rang > c.rangPrecedent and c.perso == "Ego" and not c.fini then
                c.boostJusqua = maintenant + 2
                prevenir(c, "😤 PERSONNE NE DOUBLE L'EGO !", 1.2)
            end
        end
    end
    return liste
end

local function compteARebours(secondes)
    for t = secondes, 1, -1 do
        setTemps(t)
        task.wait(1)
    end
    setTemps(0)
end

-- ============================ BOUCLE DU JEU ============================
while true do
    -- 1) LOBBY
    setStatut("🧠 Choisis ton état d'esprit sur un podium !")
    compteARebours(CONFIG.ATTENTE_LOBBY)

    local joueurs = {}
    for _, joueur in ipairs(Players:GetPlayers()) do
        local personnage = joueur.Character
        if personnage and personnage:FindFirstChild("HumanoidRootPart") and personnage:FindFirstChildOfClass("Humanoid") then
            table.insert(joueurs, joueur)
        end
    end
    if #joueurs == 0 then
        continue
    end

    -- 2) PRÉPARATION DES COUREURS
    coureurs = {}
    pluieJusqua, telephoneJusqua = 0, 0
    local persosPris = {}
    for _, joueur in ipairs(joueurs) do
        local perso = joueur:GetAttribute("Perso")
        if PERSOS[perso] and PERSOS[perso].verrou and nombreVictoires(joueur) < CONFIG.VICTOIRES_POUR_TALENT then
            perso = nil
        end
        if not PERSOS[perso] then
            perso = ORDRE_PERSOS[math.random(1, #ORDRE_PERSOS)]
            joueur:SetAttribute("Perso", perso)
        end
        persosPris[perso] = true
        table.insert(coureurs, nouveauCoureur(joueur.DisplayName, perso, joueur.Character, joueur))
    end

    -- Des bots complètent la course
    local manque = CONFIG.COUREURS_MIN - #coureurs
    for _, perso in ipairs(ORDRE_PERSOS) do
        if manque <= 0 then
            break
        end
        if not persosPris[perso] then
            local bot, pseudo = creerBot(perso)
            if bot then
                table.insert(coureurs, nouveauCoureur(pseudo, perso, bot, nil))
                manque -= 1
            end
        end
    end

    placerObstacles()

    local nombre = #coureurs
    local espace = math.min(6, (W - 4) / nombre)
    for i, c in ipairs(coureurs) do
        c.laneX = X0 - (nombre - 1) * espace / 2 + (i - 1) * espace
        local position = Vector3.new(c.laneX, SOL + 3, -8)
        c.modele:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, 1)))
        bloquer(c, true)
        etiquettePerso(c)
        if not c.joueur then
            c.forme = math.random(94, 104) / 100   -- chaque bot a sa « forme du jour »
            c.reaction = math.random(10, 50) / 100 -- temps de réaction au départ
            c.vigilant = math.random() < 0.7       -- voit (ou pas) les canapés arriver
        end
    end

    -- 3) DÉPART : 3, 2, 1
    setStatut("Prêts ?")
    task.wait(1)
    for i = 3, 1, -1 do
        AnnonceEvent:FireAllClients(tostring(i), 0.9)
        task.wait(1)
    end
    AnnonceEvent:FireAllClients("GO ! 🔥", 1.2)
    for _, c in ipairs(coureurs) do
        if valide(c) then
            bloquer(c, false)
        end
    end

    -- Événements au hasard
    local types = { "Pluie", "Telephone", "Public" }
    local evenements = {}
    local tempsEvt = math.random(5, 9)
    while tempsEvt < CONFIG.DUREE_MAX_COURSE - 10 and #evenements < CONFIG.NB_EVENEMENTS_MAX do
        table.insert(evenements, { temps = tempsEvt, type = types[math.random(1, #types)] })
        tempsEvt += math.random(7, 12)
    end
    local prochainEvt = 1

    -- 4) LA COURSE
    setStatut("🏃 COURS ! (maintiens la touche avancer)")
    local debut = os.clock()
    debutCourse = debut
    courseEnCours = true
    ReplicatedStorage:SetAttribute("CourseEnCours", true)
    for _, c in ipairs(coureurs) do
        if c.perso == "Talent" then
            c.prochainEnnui = debut + math.random(30, 60) / 10
        end
    end
    local ordreArrivee = 0
    local gagnant = nil

    while true do
        task.wait(0.1)
        local maintenant = os.clock()
        local t = maintenant - debut
        setTemps(math.max(0, math.ceil(CONFIG.DUREE_MAX_COURSE - t)))

        local evt = evenements[prochainEvt]
        if evt and t >= evt.temps then
            prochainEvt += 1
            declencherEvenement(evt.type, maintenant)
        end

        local actifs = 0
        for _, c in ipairs(coureurs) do
            if not c.fini and valide(c) then
                actifs += 1
                verifierObstacles(c, maintenant)
                if c.perso == "Talent" then
                    gererTalent(c, maintenant)
                end
                c.humanoid.WalkSpeed = vitesse(c, t, maintenant)
                if not c.joueur then
                    piloterBot(c, t, maintenant)
                end

                if c.root.Position.Z >= L then
                    c.fini = true
                    c.temps = t
                    ordreArrivee += 1
                    c.place = ordreArrivee
                    c.humanoid.WalkSpeed = 16
                    if not c.joueur then
                        c.humanoid:MoveTo(Vector3.new(c.root.Position.X, SOL, L + 45))
                    end
                    if ordreArrivee == 1 then
                        gagnant = c
                        effetAura(c)
                        AnnonceEvent:FireAllClients("👑 " .. c.nom .. " GAGNE avec " .. string.upper(c.perso) .. " !", 3)
                        if c.joueur then
                            AuraEvent:FireClient(c.joueur, "👑 VICTOIRE 👑")
                            ajouterStat(c.joueur, "Victoires", 1)
                            if nombreVictoires(c.joueur) == CONFIG.VICTOIRES_POUR_TALENT then
                                local champion = c.joueur
                                task.delay(3.5, function()
                                    if champion.Parent then
                                        AnnonceEvent:FireClient(champion, "🔓 TALENT DÉBLOQUÉ ! Monte sur son podium 🏆", 3)
                                    end
                                end)
                            end
                            ajouterStat(c.joueur, "Aura", 25)
                        end
                    else
                        prevenir(c, "🏁 Arrivé " .. ordreArrivee .. "e !", 2)
                    end
                end
            end
        end

        calculerRangs(t, maintenant)
        if actifs == 0 or t >= CONFIG.DUREE_MAX_COURSE then
            break
        end
    end

    -- 5) FIN DE LA COURSE
    courseEnCours = false
    ReplicatedStorage:SetAttribute("CourseEnCours", false)
    setStatut("🏁 Course terminée !")
    local classement = calculerRangs(0, os.clock())
    for _, c in ipairs(coureurs) do
        if c.joueur and c.joueur.Parent then
            if c.fini then
                ajouterStat(c.joueur, "Aura", 10)
            end
            FinEvent:FireClient(c.joueur, {
                perso = c.perso,
                place = c.rang or #classement,
                total = #coureurs,
                temps = if c.temps then string.format("%.1f s", c.temps) else "Pas arrivé",
                diamants = c.diamants,
                depassements = c.depassements,
                attaques = c.attaques,
                pauses = c.pauses,
                gagnant = if gagnant then gagnant.nom else "personne",
            })
        end
    end
    compteARebours(8)

    -- 6) RETOUR AU LOBBY
    for _, c in ipairs(coureurs) do
        if c.joueur then
            if c.joueur.Parent then
                c.joueur:SetAttribute("Rang", 0)
                c.joueur:LoadCharacter()
            end
        elseif c.modele then
            c.modele:Destroy()
        end
    end
    dossierObstacles:ClearAllChildren()
    coureurs = {}
end
