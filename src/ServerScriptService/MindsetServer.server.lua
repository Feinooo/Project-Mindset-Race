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
}
local ORDRE_PERSOS = { "Motivation", "Ego", "Discipline", "Obsession" }

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

for i, nom in ipairs(ORDRE_PERSOS) do
    local info = PERSOS[nom]
    local podium = bloc({
        Name = "Podium_" .. nom,
        Size = Vector3.new(10, 1, 10),
        Position = Vector3.new(-36 + (i - 1) * 24, 0.5, -30),
        Color = info.couleur,
        Material = Enum.Material.Neon,
    })
    panneau(podium, string.upper(nom), info.couleur, 14, 3, 7)
    panneau(podium, info.description, Color3.new(1, 1, 1), 14, 3, 4)

    podium.Touched:Connect(function(touche)
        local modele = touche:FindFirstAncestorOfClass("Model")
        local joueur = modele and Players:GetPlayerFromCharacter(modele)
        if joueur and joueur:GetAttribute("Perso") ~= nom then
            joueur:SetAttribute("Perso", nom)
        end
    end)
end

-- ========================== JOUEURS ==========================
local function joueurArrive(joueur)
    local stats = creer("Folder", { Name = "leaderstats", Parent = joueur })
    creer("IntValue", { Name = "Victoires", Parent = stats })
    creer("IntValue", { Name = "Aura", Parent = stats })
    joueur:SetAttribute("Rang", 0)
end
Players.PlayerAdded:Connect(joueurArrive)
for _, joueur in ipairs(Players:GetPlayers()) do
    joueurArrive(joueur)
end

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

local function creerBot(perso)
    local couleur = PERSOS[perso].couleur
    local ok, modele = pcall(function()
        local description = Instance.new("HumanoidDescription")
        description.HeadColor = couleur
        description.TorsoColor = couleur
        description.LeftArmColor = couleur
        description.RightArmColor = couleur
        description.LeftLegColor = couleur
        description.RightLegColor = couleur
        return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
    end)
    if not ok or not modele then
        warn("Impossible de créer un bot :", modele)
        return nil
    end
    modele.Name = "Bot " .. perso
    local humanoid = modele:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayName = "🤖 " .. perso
    end
    modele.Parent = workspace
    local racine = modele:FindFirstChild("HumanoidRootPart")
    if racine then
        racine:SetNetworkOwner(nil)
    end
    return modele
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
    else
        v = 20
    end

    if maintenant < telephoneJusqua and perso ~= "Discipline" and perso ~= "Obsession" then
        v *= 0.3
    end
    if maintenant < c.ralentiJusqua and perso ~= "Discipline" then
        v *= 0.35
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
        if not PERSOS[perso] then
            perso = ORDRE_PERSOS[math.random(1, #ORDRE_PERSOS)]
            joueur:SetAttribute("Perso", perso)
        end
        persosPris[perso] = true
        table.insert(coureurs, nouveauCoureur(joueur.Name, perso, joueur.Character, joueur))
    end

    -- Des bots complètent la course
    local manque = CONFIG.COUREURS_MIN - #coureurs
    for _, perso in ipairs(ORDRE_PERSOS) do
        if manque <= 0 then
            break
        end
        if not persosPris[perso] then
            local bot = creerBot(perso)
            if bot then
                table.insert(coureurs, nouveauCoureur("🤖 " .. perso, perso, bot, nil))
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
                c.humanoid.WalkSpeed = vitesse(c, t, maintenant)
                if not c.joueur then
                    c.humanoid:MoveTo(Vector3.new(c.laneX, SOL, L + 50))
                end

                if c.root.Position.Z >= L then
                    c.fini = true
                    c.temps = t
                    ordreArrivee += 1
                    c.place = ordreArrivee
                    c.humanoid.WalkSpeed = 16
                    if ordreArrivee == 1 then
                        gagnant = c
                        effetAura(c)
                        AnnonceEvent:FireAllClients("👑 " .. c.nom .. " GAGNE avec " .. string.upper(c.perso) .. " !", 3)
                        if c.joueur then
                            AuraEvent:FireClient(c.joueur, "👑 VICTOIRE 👑")
                            ajouterStat(c.joueur, "Victoires", 1)
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
