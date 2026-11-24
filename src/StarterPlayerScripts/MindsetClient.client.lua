--[[
    🧠 MINDSET STAIRS — Script CLIENT (l'escalier infini en 3D)
    À mettre dans : StarterPlayer > StarterPlayerScripts  (type : LocalScript, nom : MindsetClient)

    Tu cours sur l'escalier avec ton avatar (caméra Roblox normale, 3e personne).
    Ce script s'occupe de : l'interface (marches, rang, vitesse, chrono, mini-carte), le menu du lobby
    (état d'esprit + vote de la musique), la musique, le DOUBLE SAUT de l'EGO, les ROCHERS qui te renversent,
    l'histoire de la trend, la scène du vainqueur et sa danse, l'écran de fin, les paramètres et la langue.
    (le serveur, lui, construit l'escalier et décide de tout : marches, chutes, vitesses, gagnant)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local joueur = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("MindsetRemotes")
local DebutEvent = remotes:WaitForChild("Debut")
local ChoisirEvent = remotes:WaitForChild("Choisir")
local EvenementEvent = remotes:WaitForChild("Evenement")
local FinEvent = remotes:WaitForChild("Fin")
local VoterMusiqueEvent = remotes:WaitForChild("VoterMusique")
local DanserEvent = remotes:WaitForChild("Danser")
local dossierGrimpeurs = ReplicatedStorage:WaitForChild("Grimpeurs")
local dossierChoixMusiques = ReplicatedStorage:WaitForChild("ChoixMusiques")
local dossierClassements = ReplicatedStorage:WaitForChild("Classements")

-- l'escalier (le serveur le construit, ici on a juste besoin de ses mesures)
local ESC = {
    X = ReplicatedStorage:GetAttribute("EscalierOrigineX") or 0,
    Y = ReplicatedStorage:GetAttribute("EscalierOrigineY") or 50,
    Z = ReplicatedStorage:GetAttribute("EscalierOrigineZ") or 0,
    D = ReplicatedStorage:GetAttribute("EscalierProfondeur") or 2.5,
    H = ReplicatedStorage:GetAttribute("EscalierHauteur") or 1,
    W = ReplicatedStorage:GetAttribute("EscalierLargeur") or 30,
}

local COULEURS = {
    Motivation = Color3.fromRGB(255, 150, 30),
    Ego = Color3.fromRGB(170, 80, 255),
    Discipline = Color3.fromRGB(60, 140, 255),
    Obsession = Color3.fromRGB(230, 40, 60),
}
local ORDRE_PERSOS = { "Motivation", "Ego", "Discipline", "Obsession" }
-- Ce qui s'affiche sur les cartes du menu (les vraies règles sont dans le script serveur)
local DEVISES = {
    Motivation = "Fast start. Then it fades.",
    Ego = "Double jump. Falls harder.",
    Discipline = "Steady. Checkpoints.",
    Obsession = "Slow start. Unstoppable end.",
}
-- 🧠 Les compétences (définies dans le script serveur, partie COMPETENCES) et TES niveaux,
-- achetés chez le marchand du hub (le serveur les met dans l'attribut « Niveaux » du joueur)
local DEFS = { couts = {}, persos = {} }
pcall(function()
    DEFS = game:GetService("HttpService"):JSONDecode(ReplicatedStorage:GetAttribute("Competences"))
end)
local function mesNiveaux(perso)
    local ok, niveaux = pcall(function()
        return game:GetService("HttpService"):JSONDecode(joueur:GetAttribute("Niveaux"))
    end)
    local liste = ok and type(niveaux) == "table" and niveaux[perso]
    return if type(liste) == "table" then liste else {}
end
local BLANC = Color3.new(1, 1, 1)
local NOIR = Color3.new(0, 0, 0)
local OR = Color3.fromRGB(255, 220, 80)
local ROUGE = Color3.fromRGB(255, 70, 70)

local surMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ========================== OUTILS ==========================
local function nouveau(classe, proprietes)
    local objet = Instance.new(classe)
    for nom, valeur in pairs(proprietes) do
        if nom ~= "Parent" then
            objet[nom] = valeur
        end
    end
    objet.Parent = proprietes.Parent
    return objet
end

local function texte(proprietes)
    proprietes.BackgroundTransparency = proprietes.BackgroundTransparency or 1
    proprietes.Font = proprietes.Font or Enum.Font.FredokaOne
    proprietes.TextScaled = true
    proprietes.TextColor3 = proprietes.TextColor3 or BLANC
    proprietes.TextStrokeTransparency = proprietes.TextStrokeTransparency or 0
    proprietes.Text = proprietes.Text or ""
    return nouveau("TextLabel", proprietes)
end

local function tween(objet, duree, proprietes, style, direction)
    local animation = TweenService:Create(
        objet,
        TweenInfo.new(duree, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
        proprietes
    )
    animation:Play()
    return animation
end

local function maintenantServeur()
    return workspace:GetServerTimeNow()
end

-- (on peut se déplacer et sauter : les commandes de Roblox sont actives, comme dans le hub)
task.spawn(function()
    local ok, module = pcall(function()
        return require(joueur:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
    end)
    if ok and module then
        module:GetControls():Enable()
    end
end)


-- ========================== INTERFACE ==========================
local gui = nouveau("ScreenGui", {
    Name = "MindsetStairsGui",
    ResetOnSpawn = false,
    DisplayOrder = 5, -- au-dessus du menu 3D (MindsetHub) : les panneaux CLASSEMENTS / PARAMÈTRES s'ouvrent par-dessus
    IgnoreGuiInset = true,
    Parent = joueur:WaitForChild("PlayerGui"),
})

-- ⚙️ PARAMÈTRES du joueur (réglés dans le menu « PARAMÈTRES », sauvegardés par le serveur)
local REGLAGES = { musique = 1, bruitages = 1, secousses = true, flashs = true, langue = "auto" } -- langue : "auto" (celle de Roblox), "en", "fr"
local groupeMusique = nouveau("SoundGroup", { Name = "MindsetGroupeMusique", Volume = 1, Parent = SoundService })
local groupeBruitages = nouveau("SoundGroup", { Name = "MindsetGroupeBruitages", Volume = 1, Parent = SoundService })

local flash = nouveau("Frame", {
    BackgroundColor3 = BLANC,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Size = UDim2.fromScale(1, 1),
    ZIndex = 1,
    Parent = gui,
})
local bandeHaut = nouveau("Frame", { BackgroundColor3 = NOIR, BorderSizePixel = 0, Size = UDim2.fromScale(1, 0), ZIndex = 20, Parent = gui })
local bandeBas = nouveau("Frame", {
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.fromScale(0, 1),
    BackgroundColor3 = NOIR,
    BorderSizePixel = 0,
    Size = UDim2.fromScale(1, 0),
    ZIndex = 20,
    Parent = gui,
})

local statut = texte({
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 60),
    Size = UDim2.new(0.8, 0, 0, 36),
    ZIndex = 3,
    Parent = gui,
})
-- ⏱️ Le chrono : une pastille sombre avec le temps (0:42) et une barre qui se vide.
-- Les 5 dernières secondes : il passe au rouge et pulse (le bip est joué plus bas, partie « CHRONO »).
local function creerChrono(parent, position, zIndex)
    local cadre = nouveau("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = position,
        Size = UDim2.fromOffset(150, 48),
        BackgroundColor3 = Color3.fromRGB(12, 12, 20),
        BackgroundTransparency = 0.12,
        Visible = false,
        ZIndex = zIndex,
        Parent = parent,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = cadre })
    local trait = nouveau("UIStroke", { Color = OR, Thickness = 2, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = cadre })
    nouveau("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(Color3.fromRGB(40, 40, 58), Color3.fromRGB(14, 14, 22)),
        Parent = cadre,
    })
    local echelle = nouveau("UIScale", { Parent = cadre })
    local label = texte({
        Position = UDim2.new(0, 0, 0, 5),
        Size = UDim2.new(1, 0, 1, -17),
        Font = Enum.Font.GothamBlack,
        TextStrokeTransparency = 1,
        ZIndex = zIndex + 1,
        Parent = cadre,
    })
    local fondBarre = nouveau("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -7),
        Size = UDim2.new(1, -40, 0, 4),
        BackgroundColor3 = Color3.fromRGB(50, 50, 68),
        BorderSizePixel = 0,
        ZIndex = zIndex + 1,
        Parent = cadre,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fondBarre })
    local barreTemps = nouveau("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = OR,
        BorderSizePixel = 0,
        ZIndex = zIndex + 2,
        Parent = fondBarre,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = barreTemps })

    local c = { cadre = cadre, actif = true, total = 1, dernier = 0, temps = 0 }
    local function majVisible()
        cadre.Visible = c.actif and c.temps > 0
    end
    function c.afficher(actif)
        c.actif = actif
        majVisible()
    end
    function c.maj(temps)
        c.temps = temps
        majVisible()
        if temps <= 0 then
            c.dernier = 0
            return
        end
        if temps > c.dernier then
            c.total = temps -- un nouveau compte à rebours commence
            barreTemps.Size = UDim2.fromScale(1, 1)
        end
        c.dernier = temps
        label.Text = string.format("%d:%02d", temps // 60, temps % 60)
        tween(barreTemps, 1, { Size = UDim2.fromScale(math.max(0, (temps - 1) / c.total), 1) }, Enum.EasingStyle.Linear)
        local urgent = temps <= 5
        local couleur = if urgent then ROUGE else OR
        barreTemps.BackgroundColor3 = couleur
        trait.Color = couleur
        label.TextColor3 = if urgent then Color3.fromRGB(255, 120, 120) else BLANC
        if urgent then
            echelle.Scale = 1.22
            tween(echelle, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
        end
    end
    return c
end
-- le chrono de la partie (toujours au même endroit, en haut au milieu)
local chrono = creerChrono(gui, UDim2.new(0.5, 0, 0, 98), 3)
local marcheTexte = texte({
    Position = UDim2.new(0, 20, 0, 60),
    Size = UDim2.new(0, 220, 0, 34),
    TextXAlignment = Enum.TextXAlignment.Left,
    Visible = false,
    ZIndex = 3,
    Parent = gui,
})
local grosTexte = texte({
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.25),
    Size = UDim2.new(0.9, 0, 0, 72),
    TextTransparency = 1,
    TextStrokeTransparency = 1,
    ZIndex = 21,
    Parent = gui,
})
local echelleGros = nouveau("UIScale", { Parent = grosTexte })
local auraTexte = texte({
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.88),
    Size = UDim2.new(0.6, 0, 0, 44),
    TextTransparency = 1,
    TextStrokeTransparency = 1,
    ZIndex = 4,
    Parent = gui,
})
local decompte = texte({
    Font = Enum.Font.Arcade, -- chiffres du décompte en police rétro
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.45),
    Size = UDim2.fromScale(0.5, 0.3),
    TextTransparency = 1,
    TextStrokeTransparency = 1,
    ZIndex = 21,
    Parent = gui,
})
local echelleDecompte = nouveau("UIScale", { Parent = decompte })

-- le rang (#2 / 6) et la vitesse, sous le compteur de marches
local rangTexte = texte({
    Position = UDim2.new(0, 20, 0, 96),
    Size = UDim2.new(0, 160, 0, 26),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = OR,
    Visible = false,
    ZIndex = 3,
    Parent = gui,
})
local vitesseTexte = texte({
    Position = UDim2.new(0, 20, 0, 124),
    Size = UDim2.new(0, 160, 0, 22),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Color3.fromRGB(200, 220, 255),
    Visible = false,
    ZIndex = 3,
    Parent = gui,
})

-- Mini-carte de la montée (à droite)
local barre = nouveau("Frame", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -24, 0.5, 0),
    Size = UDim2.new(0, 10, 0.6, 0),
    BackgroundColor3 = Color3.fromRGB(60, 60, 80),
    BackgroundTransparency = 0.3,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 3,
    Parent = gui,
})
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = barre })
-- en haut de la mini-carte : la marche du premier (l'échelle s'adapte, les escaliers sont infinis)
local hautBarre = texte({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.fromOffset(50, 24), TextColor3 = OR, ZIndex = 3, Parent = barre })

-- Effets d'image (seulement pour toi)
local effetAura = nouveau("ColorCorrectionEffect", { Name = "MindsetModeAura", Parent = Lighting })
local effetPulse = nouveau("ColorCorrectionEffect", { Name = "MindsetPulse", Parent = Lighting })
local flou = nouveau("BlurEffect", { Name = "MindsetFlou", Size = 0, Parent = Lighting })

local function apparaitre(label, message, duree, echelle)
    label.Text = message
    label.TextTransparency = 0
    label.TextStrokeTransparency = 0
    if echelle then
        echelle.Scale = 1.8
        tween(echelle, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
    end
    label:SetAttribute("Numero", (label:GetAttribute("Numero") or 0) + 1)
    local numero = label:GetAttribute("Numero")
    task.delay(duree, function()
        if label:GetAttribute("Numero") == numero then
            tween(label, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
        end
    end)
end

local function flasher(couleur, force)
    flash.BackgroundColor3 = couleur
    flash.BackgroundTransparency = 1 - force * (if REGLAGES.flashs then 1 else 0)
    tween(flash, 0.45, { BackgroundTransparency = 1 })
end

local function modeCinema(actif)
    local hauteur = if actif then 0.1 else 0
    tween(bandeHaut, 0.5, { Size = UDim2.fromScale(1, hauteur) })
    tween(bandeBas, 0.5, { Size = UDim2.fromScale(1, hauteur) })
end


-- ========================== CAMÉRA (effets) ==========================
local FOV_BASE = 70
local fovPulse = 0       -- coup de zoom, qui retombe tout seul
local forceSecousse = 0  -- secousse qui retombe toute seule
local function secousse(force)
    forceSecousse = math.max(forceSecousse, force * (if REGLAGES.secousses then 1 else 0))
end


-- ========================== MENU DU LOBBY ==========================
-- Plein écran pendant le lobby : les 4 états d'esprit + le vote de la musique, la map floutée derrière.
local BLEU_MUSIQUE = Color3.fromRGB(120, 170, 255)

-- 🔊 Petits bruits de l'interface
-- (les « rbxasset:// » sont fournis avec Roblox : ils marchent toujours, même jeu pas publié)
local jouerSon, sonSurvol, sonClic, sonClaque
do
local SONS = {
    -- (le son de survol est une « recette » qui mélange ces sons : voir RECETTES_SURVOL plus bas)
    eau = "rbxasset://sounds/impact_water.mp3",
    pas = "rbxasset://sounds/action_footsteps_plastic.mp3",
    tic = "rbxasset://sounds/volume_slider.ogg",    -- tic-tac du chrono + accords du clic
    clic = "rbxassetid://12221967",                 -- le « clic » classique de Roblox
    -- 👋 CLAQUE du check parfait : mets ici l'ID d'un son « slap » / « high five » de la Boutique (Toolbox → Audio)
    --    pour un rendu parfait. Laisse "" : on fabrique une claque avec les sons de Roblox.
    claque = "",
    boum = "rbxasset://sounds/impact_explosion_03.mp3",
    pose = "rbxasset://sounds/action_jump_land.mp3",
}
local sonsModeles = {}
for nom, id in pairs(SONS) do
    if id ~= "" then
        sonsModeles[nom] = nouveau("Sound", { Name = "MindsetUI_" .. nom, SoundId = id, Volume = 0.5, SoundGroup = groupeBruitages, Parent = SoundService })
    end
end
task.spawn(function()
    pcall(function()
        local aCharger = { sonsModeles.clic }
        if sonsModeles.claque then
            table.insert(aCharger, sonsModeles.claque)
        end
        ContentProvider:PreloadAsync(aCharger, function(id, etatChargement)
            if etatChargement ~= Enum.AssetFetchStatus.Success then
                if id == SONS.clic then
                    sonsModeles.clic.SoundId = SONS.tic -- secours si le clic ne se charge pas
                elseif id == SONS.claque then
                    sonsModeles.claque = nil -- on fabriquera la claque nous-mêmes
                end
            end
        end)
    end)
end)

-- coupe = au bout de combien de secondes on coupe le son (en fondu), pour garder juste l'attaque
jouerSon = function(nom, vitesse, volume, retard, coupe)
    local modele = sonsModeles[nom]
    if not modele then
        return
    end
    local function jouer()
        local son = modele:Clone()
        son.PlaybackSpeed = vitesse or 1
        son.Volume = volume or 0.5
        son.Parent = SoundService
        son:Play()
        if coupe then
            task.delay(coupe, function()
                if son.Parent then
                    tween(son, 0.08, { Volume = 0 })
                end
            end)
        end
        task.delay(if coupe then coupe + 0.15 else 3, function()
            son:Destroy()
        end)
    end
    if retard and retard > 0 then
        task.delay(retard, jouer)
    else
        jouer()
    end
end

-- Survol : un son doux, un peu plus aigu pour chaque carte, et qui monte si tu enchaînes vite.
-- 🔊 Plusieurs « recettes » de son : dans Studio, appuie sur H dans le lobby pour les essayer une par une
--    (le nom s'affiche en bas) → dis-moi laquelle tu préfères et je la mets par défaut (SON_SURVOL).
local SON_SURVOL = 1
local RECETTES_SURVOL = {
    { nom = "CRISTAL (doux et brillant)", jouer = function(v)
        jouerSon("tic", 2.1 * v, 0.12, nil, 0.09)
    end },
    { nom = "PLUME (très léger)", jouer = function(v)
        jouerSon("pas", 1.6 * v, 0.35, nil, 0.07)
    end },
    { nom = "TOC (feutré)", jouer = function(v)
        jouerSon("pose", 1.7 * v, 0.45, nil, 0.12)
        jouerSon("tic", 2.4 * v, 0.07, 0.015, 0.1)
    end },
    { nom = "BULLE (ploc)", jouer = function(v)
        jouerSon("eau", 1.9 * v, 0.28, nil, 0.16)
    end },
    { nom = "TIC (l'ancien, plus bas)", jouer = function(v)
        jouerSon("tic", 0.8 * v, 0.25, nil, 0.12)
    end },
}
local GAMME = { 1, 1.122, 1.26, 1.498, 1.682, 2, 2.245 }
local serieSurvol, dernierSurvol = 0, 0
sonSurvol = function(note)
    local maintenant = os.clock()
    serieSurvol = if maintenant - dernierSurvol < 0.7 then math.min(serieSurvol + 1, 6) else 0
    dernierSurvol = maintenant
    local hauteur = 1 + ((GAMME[note] or 1) - 1) * 0.45
    RECETTES_SURVOL[SON_SURVOL].jouer(hauteur * (1 + serieSurvol * 0.025))
end
if game:GetService("RunService"):IsStudio() then
    UserInputService.InputBegan:Connect(function(input, gere)
        if gere or input.KeyCode ~= Enum.KeyCode.H or ReplicatedStorage:GetAttribute("Phase") ~= "Lobby" then
            return
        end
        SON_SURVOL = SON_SURVOL % #RECETTES_SURVOL + 1
        print("[Son de survol] " .. SON_SURVOL .. "/" .. #RECETTES_SURVOL .. " : " .. RECETTES_SURVOL[SON_SURVOL].nom)
        for k = 1, 3 do
            task.delay((k - 1) * 0.18, function()
                RECETTES_SURVOL[SON_SURVOL].jouer(1 + (k - 1) * 0.12)
            end)
        end
        local panneauSon = gui:FindFirstChild("EssaiSonSurvol") or texte({
            Name = "EssaiSonSurvol",
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -8),
            Size = UDim2.new(0.6, 0, 0, 26),
            TextColor3 = OR,
            ZIndex = 50,
            Parent = gui,
        })
        panneauSon.Text = "Son de survol " .. SON_SURVOL .. "/" .. #RECETTES_SURVOL .. " : " .. RECETTES_SURVOL[SON_SURVOL].nom .. "   (H = suivant)"
    end)
end
sonClic = function(note)
    local base = GAMME[note] or 1
    jouerSon("clic", 1, 0.7)
    jouerSon("tic", base * 0.75, 0.5)
    jouerSon("tic", base * 1.5, 0.4, 0.07)
    jouerSon("tic", base * 2, 0.3, 0.14)
end
-- 👋 La claque du check parfait
sonClaque = function()
    if sonsModeles.claque then
        jouerSon("claque", 1, 1)
    else
        jouerSon("boum", 3.2, 0.55, nil, 0.12) -- l'attaque sèche d'une explosion, très aiguë = « clac »
        jouerSon("pose", 2.4, 1, nil, 0.15)
        jouerSon("tic", 0.6, 0.5)
    end
end
end -- fin du bloc des sons

-- Fond : la map floutée et un peu assombrie
local flouLobby = nouveau("BlurEffect", { Name = "MindsetFlouLobby", Size = 0, Parent = Lighting })
local teinteLobby = nouveau("ColorCorrectionEffect", { Name = "MindsetTeinteLobby", Parent = Lighting })

local menu = nouveau("Frame", {
    Name = "MenuLobby",
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Visible = false,
    ZIndex = 10,
    Parent = gui,
})
local voile = nouveau("Frame", {
    BackgroundColor3 = NOIR,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Size = UDim2.fromScale(1, 1),
    ZIndex = 10,
    Parent = menu,
})
nouveau("UIGradient", {
    Rotation = 90,
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.5, 0.6),
        NumberSequenceKeypoint.new(1, 0.15),
    }),
    Parent = voile,
})

local textesMenu = {}
local function texteMenu(proprietes)
    local label = texte(proprietes)
    table.insert(textesMenu, label)
    return label
end

local titreMenu = texteMenu({
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.03),
    Size = UDim2.fromScale(0.86, 0.08),
    Text = "CHOOSE YOUR MINDSET",
    ZIndex = 12,
    Parent = menu,
})
local degradeTitre = nouveau("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COULEURS.Motivation),
        ColorSequenceKeypoint.new(0.33, COULEURS.Ego),
        ColorSequenceKeypoint.new(0.66, COULEURS.Discipline),
        ColorSequenceKeypoint.new(1, COULEURS.Obsession),
    }),
    Parent = titreMenu,
})
local echelleTitre = nouveau("UIScale", { Parent = titreMenu })
local chronoMenu = creerChrono(menu, UDim2.fromScale(0.5, 0.115), 12)
local titreMusique = texteMenu({
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.655),
    Size = UDim2.fromScale(0.6, 0.04),
    Text = "VOTE FOR THE MUSIC",
    TextColor3 = BLEU_MUSIQUE,
    ZIndex = 12,
    Parent = menu,
})
local resume = texteMenu({
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.905),
    Size = UDim2.fromScale(0.8, 0.045),
    ZIndex = 12,
    Parent = menu,
})

local toutesCartes = {} -- les cartes animées (persos + musiques)
local menuOuvert = false
local dernierClicPerso = nil
local panneauOuvert = false -- le panneau des classements est ouvert (les cartes ne réagissent plus)
local majRecordsCartes -- défini plus bas (records affichés sur les cartes)

-- 💥 Onde + étincelles qui partent de la carte cliquée
local function explosion(objet, couleur)
    local taille = objet.AbsoluteSize
    local centre = objet.AbsolutePosition + taille / 2 - menu.AbsolutePosition
    local onde = nouveau("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(centre.X, centre.Y),
        Size = UDim2.fromOffset(taille.X, taille.Y),
        BackgroundTransparency = 1,
        ZIndex = 19,
        Parent = menu,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 18), Parent = onde })
    local trait = nouveau("UIStroke", { Color = couleur, Thickness = 6, Parent = onde })
    tween(onde, 0.45, { Size = UDim2.fromOffset(taille.X * 1.3, taille.Y * 1.2) })
    tween(trait, 0.45, { Transparency = 1, Thickness = 1 })
    task.delay(0.5, function()
        onde:Destroy()
    end)
    for _ = 1, 16 do
        local angle = math.random() * math.pi * 2
        local distance = 90 + math.random() * 140
        local cote = math.random(6, 14)
        local etincelle = nouveau("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(centre.X, centre.Y),
            Size = UDim2.fromOffset(cote, cote),
            BackgroundColor3 = if math.random() < 0.3 then BLANC else couleur,
            BorderSizePixel = 0,
            Rotation = math.random(0, 90),
            ZIndex = 19,
            Parent = menu,
        })
        if math.random() < 0.5 then
            nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = etincelle })
        end
        local duree = 0.45 + math.random() * 0.35
        tween(etincelle, duree, {
            Position = UDim2.fromOffset(centre.X + math.cos(angle) * distance, centre.Y + math.sin(angle) * distance),
            Size = UDim2.fromOffset(2, 2),
            BackgroundTransparency = 1,
            Rotation = etincelle.Rotation + 200,
        }, Enum.EasingStyle.Quint)
        task.delay(duree + 0.05, function()
            etincelle:Destroy()
        end)
    end
end

-- Une carte (perso ou musique) : halo, contour qui brille, badge « choisi », rebond à ressort
local function creerCarte(parent, couleur, taille, note)
    local slot = nouveau("Frame", { Size = taille, BackgroundTransparency = 1, ZIndex = 12, Parent = parent })
    local halo = nouveau("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = couleur,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 12,
        Parent = slot,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 24), Parent = halo })
    local carte = nouveau("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = BLANC,
        BackgroundTransparency = 0.06,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 13,
        Parent = slot,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 16), Parent = carte })
    nouveau("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(couleur:Lerp(NOIR, 0.6), Color3.fromRGB(12, 12, 18)),
        Parent = carte,
    })
    local contour = nouveau("UIStroke", {
        Color = BLANC,
        Thickness = 2,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = carte,
    })
    local reflet = nouveau("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, couleur),
            ColorSequenceKeypoint.new(0.42, couleur),
            ColorSequenceKeypoint.new(0.5, BLANC),
            ColorSequenceKeypoint.new(0.58, couleur),
            ColorSequenceKeypoint.new(1, couleur),
        }),
        Parent = contour,
    })
    local voileCarte = nouveau("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = NOIR,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 17,
        Parent = carte,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 16), Parent = voileCarte })
    local badge = texte({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0),
        Size = UDim2.new(0.62, 0, 0, 24),
        BackgroundTransparency = 0,
        BackgroundColor3 = couleur,
        Font = Enum.Font.GothamBlack,
        Text = "PICKED",
        TextStrokeTransparency = 1,
        Visible = false,
        ZIndex = 18,
        Parent = carte,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
    nouveau("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = badge })

    local c = {
        slot = slot,
        halo = halo,
        carte = carte,
        echelle = nouveau("UIScale", { Scale = 0, Parent = carte }),
        contour = contour,
        reflet = reflet,
        voile = voileCarte,
        badge = badge,
        couleur = couleur,
        note = note,
        x = 0, -- taille actuelle (ressort)
        v = 0, -- vitesse du ressort
        lift = 0,
        survole = false,
        choisi = false,
        delai = 0,
    }
    carte.MouseEnter:Connect(function()
        if c.survole or not menuOuvert or panneauOuvert then
            return
        end
        c.survole = true
        sonSurvol(note)
        if c.surSurvol then
            c.surSurvol()
        end
    end)
    carte.MouseLeave:Connect(function()
        c.survole = false
        if c.finSurvol then
            c.finSurvol()
        end
    end)
    if menuOuvert then
        c.delai = os.clock() + 0.25
    end
    table.insert(toutesCartes, c)
    return c
end

-- ---------- Les 4 états d'esprit ----------
local rangeePersos = nouveau("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.18),
    Size = UDim2.fromScale(0.92, 0.45),
    BackgroundTransparency = 1,
    ZIndex = 12,
    Parent = menu,
})
nouveau("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0.016, 0),
    Parent = rangeePersos,
})

local cartes = {}
local persoChoisi = nil
local boutonsMusique = {}
local monVote = nil

local function majResume()
    local morceaux = {}
    if persoChoisi then
        table.insert(morceaux, string.upper(persoChoisi))
    else
        table.insert(morceaux, "Choose your mindset")
    end
    if next(boutonsMusique) then
        local b = monVote and boutonsMusique[monVote]
        table.insert(morceaux, if b then b.valeur.Value else "Vote for a song")
    end
    resume.Text = table.concat(morceaux, "   •   ")
    resume.TextColor3 = if persoChoisi then COULEURS[persoChoisi] else Color3.fromRGB(200, 200, 215)
end

local function majSegments(c)
    for _, s in ipairs(c.segments) do
        tween(s.seg, 0.25, { BackgroundTransparency = if c.choisi then 0.1 else 0.45 })
    end
end

local function choisirPersoAffiche(perso)
    persoChoisi = perso
    for nom, c in pairs(cartes) do
        local avant = c.choisi
        c.choisi = nom == perso
        c.badge.Visible = c.choisi
        if avant ~= c.choisi and not c.survole then
            majSegments(c)
        end
    end
    majResume()
end

for i, perso in ipairs(ORDRE_PERSOS) do
    local couleur = COULEURS[perso]
    local c = creerCarte(rangeePersos, couleur, UDim2.fromScale(0.235, 1), i)
    c.slot.LayoutOrder = i
    local carte = c.carte
    -- le nom en grand en haut de la carte (plus d'icône)
    c.icone = texte({
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0.07),
        Size = UDim2.fromScale(0.9, 0.13),
        Text = string.upper(perso),
        TextColor3 = couleur,
        ZIndex = 15,
        Parent = carte,
    })
    c.echelleIcone = nouveau("UIScale", { Parent = c.icone })
    texte({
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0.21),
        Size = UDim2.fromScale(0.85, 0.055),
        Text = DEVISES[perso],
        Font = Enum.Font.GothamMedium,
        TextColor3 = Color3.fromRGB(200, 200, 215),
        TextStrokeTransparency = 1,
        ZIndex = 15,
        Parent = carte,
    })
    nouveau("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0.29),
        Size = UDim2.new(0.7, 0, 0, 2),
        BackgroundColor3 = couleur,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        ZIndex = 14,
        Parent = carte,
    })
    -- tes 3 compétences : le nom, le niveau (5 cases) et ce qu'elle fait à ton niveau
    c.lignes = {}
    c.segments = {}
    for j = 1, 3 do
        local y = 0.325 + (j - 1) * 0.165
        local ligne = { segs = {} }
        ligne.nom = texte({
            Position = UDim2.fromScale(0.07, y),
            Size = UDim2.fromScale(0.42, 0.055),
            Font = Enum.Font.GothamBlack,
            TextColor3 = Color3.fromRGB(235, 235, 245),
            TextStrokeTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 15,
            Parent = carte,
        })
        for k = 1, 5 do
            local seg = nouveau("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.fromScale(0.52 + (k - 1) * 0.085, y + 0.028),
                Size = UDim2.fromScale(0.07, 0.04),
                BackgroundColor3 = Color3.fromRGB(45, 45, 60),
                BackgroundTransparency = 0.2,
                BorderSizePixel = 0,
                ZIndex = 15,
                Parent = carte,
            })
            nouveau("UICorner", { CornerRadius = UDim.new(0, 3), Parent = seg })
            ligne.segs[k] = seg
        end
        ligne.effet = texte({
            Position = UDim2.fromScale(0.07, y + 0.065),
            Size = UDim2.fromScale(0.86, 0.045),
            Font = Enum.Font.GothamMedium,
            TextColor3 = Color3.fromRGB(190, 190, 205),
            TextStrokeTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 15,
            Parent = carte,
        })
        c.lignes[j] = ligne
    end
    -- remet la carte à jour avec tes niveaux (après un achat chez le marchand)
    c.majCompetences = function()
        local niveaux = mesNiveaux(perso)
        local defs = DEFS.persos and DEFS.persos[perso] or {}
        c.segments = {}
        for j, ligne in ipairs(c.lignes) do
            local def = defs[j]
            local niveau = tonumber(niveaux[j]) or 0
            ligne.nom.Text = if def then def.nom else "?"
            for k, seg in ipairs(ligne.segs) do
                local allume = k <= niveau
                seg.BackgroundColor3 = if allume then couleur else Color3.fromRGB(45, 45, 60)
                seg.BackgroundTransparency = if allume then (if c.choisi then 0.1 else 0.45) else 0.2
                if allume then
                    table.insert(c.segments, { seg = seg, k = k })
                end
            end
            if def and niveau > 0 then
                ligne.effet.Text = string.format(def.texte, tostring(def.valeurs[math.min(niveau, #def.valeurs)]))
                ligne.effet.TextColor3 = Color3.fromRGB(210, 210, 225)
            else
                ligne.effet.Text = "Locked · upgrade it at the AURA SHOP"
                ligne.effet.TextColor3 = Color3.fromRGB(120, 120, 140)
            end
        end
    end
    -- le record de cet état d'esprit (tous joueurs)
    c.record = texte({
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0.85),
        Size = UDim2.fromScale(0.86, 0.055),
        Text = "RECORD: —",
        Font = Enum.Font.GothamBold,
        TextColor3 = OR,
        TextStrokeTransparency = 1,
        ZIndex = 15,
        Parent = carte,
    })
    c.majCompetences()
    -- au survol, les cases s'allument une par une
    c.surSurvol = function()
        for _, s in ipairs(c.segments) do
            task.delay(s.k * 0.045, function()
                if c.survole then
                    s.seg.BackgroundTransparency = 0
                    s.seg.Size = UDim2.fromScale(0.07, 0.065)
                    tween(s.seg, 0.22, { Size = UDim2.fromScale(0.07, 0.04) }, Enum.EasingStyle.Back)
                end
            end)
        end
    end
    c.finSurvol = function()
        majSegments(c)
    end
    carte.Activated:Connect(function()
        if not menuOuvert then
            return
        end
        dernierClicPerso = perso
        ChoisirEvent:FireServer(perso)
        choisirPersoAffiche(perso)
        c.v -= 6 -- écrasement, puis rebond
        explosion(carte, couleur)
        flasher(couleur, 0.3)
        secousse(0.7)
        sonClic(i)
    end)
    cartes[perso] = c
end
-- un achat chez le marchand → les cartes montrent tes nouveaux niveaux
joueur:GetAttributeChangedSignal("Niveaux"):Connect(function()
    for _, c in pairs(cartes) do
        c.majCompetences()
    end
end)

-- ---------- Vote de la musique ----------
local rangeeMusiques = nouveau("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.71),
    Size = UDim2.fromScale(if surMobile then 0.92 else 0.66, 0.17),
    BackgroundTransparency = 1,
    ZIndex = 12,
    Parent = menu,
})
nouveau("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0.02, 0),
    Parent = rangeeMusiques,
})

local function majVotesMusique()
    local total = 0
    for _, b in pairs(boutonsMusique) do
        total += b.valeur:GetAttribute("Votes") or 0
    end
    for i, b in pairs(boutonsMusique) do
        local votes = b.valeur:GetAttribute("Votes") or 0
        b.votes.Text = votes .. (if votes > 1 then " votes" else " vote")
        tween(b.remplissage, 0.3, { Size = UDim2.fromScale(if total > 0 then votes / total else 0, 1) }, Enum.EasingStyle.Back)
        b.choisi = monVote == i
        b.badge.Visible = b.choisi
    end
    majResume()
end

local function reconstruireMusiques()
    for _, b in pairs(boutonsMusique) do
        b.mort = true
        b.slot:Destroy()
    end
    boutonsMusique = {}
    monVote = nil
    local valeurs = dossierChoixMusiques:GetChildren()
    table.sort(valeurs, function(a, b)
        return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0)
    end)
    for _, valeur in ipairs(valeurs) do
        local i = tonumber(valeur.Name)
        if not i then
            continue
        end
        local c = creerCarte(rangeeMusiques, BLEU_MUSIQUE, UDim2.fromScale(1 / #valeurs - 0.02, 1), 3 + i)
        c.slot.LayoutOrder = i
        c.badge.Text = "YOUR VOTE"
        c.valeur = valeur
        if menuOuvert then
            c.delai = os.clock() + 0.3 + i * 0.07
        end
        -- petit égaliseur qui danse au survol
        c.barres = {}
        for k = 1, 4 do
            local barreEq = nouveau("Frame", {
                AnchorPoint = Vector2.new(0, 1),
                Position = UDim2.fromScale(0.05 + (k - 1) * 0.045, 0.72),
                Size = UDim2.fromScale(0.03, 0.12),
                BackgroundColor3 = BLEU_MUSIQUE,
                BorderSizePixel = 0,
                ZIndex = 15,
                Parent = c.carte,
            })
            nouveau("UICorner", { CornerRadius = UDim.new(0, 2), Parent = barreEq })
            table.insert(c.barres, barreEq)
        end
        texte({
            Position = UDim2.fromScale(0.26, 0.08),
            Size = UDim2.fromScale(0.7, 0.32),
            Text = valeur.Value,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 15,
            Parent = c.carte,
        })
        -- le niveau de difficulté : 4 petites barres + le mot, dans la couleur du niveau
        local NIVEAUX = {
            { "EASY", Color3.fromRGB(110, 230, 140) },
            { "MEDIUM", Color3.fromRGB(255, 210, 80) },
            { "HARD", Color3.fromRGB(255, 140, 60) },
            { "EXTREME", Color3.fromRGB(255, 70, 90) },
        }
        local niveau = math.clamp(valeur:GetAttribute("Difficulte") or 2, 1, 4)
        local nomNiveau, couleurNiveau = NIVEAUX[niveau][1], NIVEAUX[niveau][2]
        for k = 1, 4 do
            local barreNiveau = nouveau("Frame", {
                AnchorPoint = Vector2.new(0, 1),
                Position = UDim2.fromScale(0.26 + (k - 1) * 0.028, 0.53),
                Size = UDim2.fromScale(0.018, 0.04 + k * 0.025),
                BackgroundColor3 = if k <= niveau then couleurNiveau else Color3.fromRGB(55, 55, 72),
                BorderSizePixel = 0,
                ZIndex = 15,
                Parent = c.carte,
            })
            nouveau("UICorner", { CornerRadius = UDim.new(0, 2), Parent = barreNiveau })
        end
        texte({
            Position = UDim2.fromScale(0.38, 0.4),
            Size = UDim2.fromScale(0.5, 0.14),
            Text = nomNiveau,
            Font = Enum.Font.GothamBlack,
            TextColor3 = couleurNiveau,
            TextStrokeTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 15,
            Parent = c.carte,
        })
        c.votes = texte({
            Position = UDim2.fromScale(0.26, 0.55),
            Size = UDim2.fromScale(0.3, 0.2),
            Font = Enum.Font.GothamBold,
            TextColor3 = OR,
            TextStrokeTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 15,
            Parent = c.carte,
        })
        -- le record de la musique (tous états d'esprit)
        c.record = texte({
            Position = UDim2.fromScale(0.56, 0.57),
            Size = UDim2.fromScale(0.4, 0.16),
            Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(200, 200, 215),
            TextStrokeTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 15,
            Parent = c.carte,
        })
        valeur:GetAttributeChangedSignal("Cle"):Connect(function()
            majRecordsCartes()
        end)
        local fond = nouveau("Frame", {
            Position = UDim2.fromScale(0.05, 0.83),
            Size = UDim2.fromScale(0.9, 0.07),
            BackgroundColor3 = Color3.fromRGB(40, 40, 55),
            BorderSizePixel = 0,
            ZIndex = 15,
            Parent = c.carte,
        })
        nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fond })
        c.remplissage = nouveau("Frame", {
            Size = UDim2.fromScale(0, 1),
            BackgroundColor3 = OR,
            BorderSizePixel = 0,
            ZIndex = 16,
            Parent = fond,
        })
        nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = c.remplissage })
        c.carte.Activated:Connect(function()
            if not menuOuvert then
                return
            end
            monVote = i
            VoterMusiqueEvent:FireServer(i)
            majVotesMusique()
            c.v -= 5
            explosion(c.carte, BLEU_MUSIQUE)
            flasher(BLEU_MUSIQUE, 0.2)
            secousse(0.4)
            sonClic(3 + i)
        end)
        valeur:GetAttributeChangedSignal("Votes"):Connect(majVotesMusique)
        boutonsMusique[i] = c
    end
    titreMusique.Visible = next(boutonsMusique) ~= nil
    majVotesMusique()
    majRecordsCartes()
end

-- Les records affichés sur les cartes (le serveur les met dans ReplicatedStorage.Classements)
local function texteRecord(cle)
    local valeur = cle and dossierClassements:FindFirstChild(cle)
    local score = if valeur then valeur:GetAttribute("Top1Score") or 0 else 0
    if score <= 0 then
        return "RECORD: —"
    end
    return "RECORD: " .. score .. "  •  " .. tostring(valeur:GetAttribute("Top1Nom"))
end
majRecordsCartes = function()
    for perso, c in pairs(cartes) do
        if c.record then
            c.record.Text = texteRecord("P_" .. perso)
        end
    end
    for _, b in pairs(boutonsMusique) do
        if b.record then
            b.record.Text = texteRecord(b.valeur:GetAttribute("Cle"))
        end
    end
end
local function suivreClassement(valeur)
    valeur.AttributeChanged:Connect(majRecordsCartes)
    majRecordsCartes()
end
dossierClassements.ChildAdded:Connect(suivreClassement)
for _, valeur in ipairs(dossierClassements:GetChildren()) do
    suivreClassement(valeur)
end

-- Le serveur remplace les 3 musiques d'un coup : on attend un poil avant de reconstruire
local reconstructionPrevue = false
local function prevoirReconstruction()
    if reconstructionPrevue then
        return
    end
    reconstructionPrevue = true
    task.delay(0.1, function()
        reconstructionPrevue = false
        reconstruireMusiques()
    end)
end
dossierChoixMusiques.ChildAdded:Connect(prevoirReconstruction)
dossierChoixMusiques.ChildRemoved:Connect(prevoirReconstruction)
reconstruireMusiques()

-- ---------- CHRONO : les deux pastilles + le bip du décompte les 5 dernières secondes ----------
local dernierTempsChrono = 0
ReplicatedStorage:GetAttributeChangedSignal("Temps"):Connect(function()
    local temps = ReplicatedStorage:GetAttribute("Temps") or 0
    chronoMenu.maj(temps)
    chrono.maj(temps)
    local phase = ReplicatedStorage:GetAttribute("Phase")
    -- (pas de bip si tu es encore dans le menu principal)
    if (phase == "Lobby" and menu.Visible) or (phase == "Manche" and statut.Visible) then
        if temps >= 1 and temps <= 5 and temps < dernierTempsChrono then
            -- bip... bip... bip... de plus en plus aigu
            local hauteur = if temps == 1 then 1.5 else 1 + (5 - temps) * 0.04
            jouerSon("tic", hauteur, 0.6)
            jouerSon("pose", 1.3 * hauteur, 0.35, nil, 0.1)
        elseif temps == 0 and dernierTempsChrono == 1 then
            -- c'est fini ! (pas de gros boum quand la partie se lance, juste à la fin de la manche)
            if phase == "Manche" then
                jouerSon("boum", 0.85, 0.45, nil, 0.9)
            end
            jouerSon("tic", 2, 0.5)
            jouerSon("tic", 1.5, 0.4, 0.05)
        end
    end
    dernierTempsChrono = temps
end)

-- ---------- Ouvrir / fermer ----------
local function ouvrirMenu()
    if menuOuvert then
        return
    end
    menuOuvert = true
    menu.Visible = true
    tween(voile, 0.5, { BackgroundTransparency = 0 })
    tween(flouLobby, 0.6, { Size = 24 })
    tween(teinteLobby, 0.6, { Brightness = -0.04, Contrast = 0.12, Saturation = 0.15 })
    for _, label in ipairs(textesMenu) do
        tween(label, 0.4, { TextTransparency = 0, TextStrokeTransparency = 0 })
    end
    echelleTitre.Scale = 0.4
    tween(echelleTitre, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
    -- les cartes arrivent une par une, avec un petit arpège
    local depart = os.clock() + 0.15
    local rang = 0
    for _, perso in ipairs(ORDRE_PERSOS) do
        local c = cartes[perso]
        c.x, c.v = 0, 0
        c.delai = depart + rang * 0.07
        local noteArpege = rang + 1
        task.delay(math.max(0, c.delai - os.clock()), function()
            sonSurvol(noteArpege)
        end)
        rang += 1
    end
    for i = 1, #toutesCartes do
        local c = toutesCartes[i]
        if c.valeur then
            c.x, c.v = 0, 0
            c.delai = depart + (rang + (tonumber(c.valeur.Name) or 0)) * 0.07
        end
    end
end

local function fermerMenu()
    if not menuOuvert then
        return
    end
    menuOuvert = false
    for _, c in ipairs(toutesCartes) do
        c.survole = false
    end
    tween(voile, 0.4, { BackgroundTransparency = 1 })
    tween(flouLobby, 0.5, { Size = 0 })
    tween(teinteLobby, 0.5, { Brightness = 0, Contrast = 0, Saturation = 0 })
    for _, label in ipairs(textesMenu) do
        tween(label, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
    end
    task.delay(0.5, function()
        if not menuOuvert then
            menu.Visible = false
        end
    end)
end

-- ---------- Animation des cartes (à chaque image) ----------
RunService.RenderStepped:Connect(function(dt)
    if not menu.Visible then
        return
    end
    local t = os.clock()
    degradeTitre.Offset = Vector2.new(math.sin(t * 0.9) * 0.35, 0)
    local quelqueChoseSurvole = false
    for _, c in ipairs(toutesCartes) do
        if c.survole and not c.mort then
            quelqueChoseSurvole = true
        end
    end
    local pas = math.min(dt, 1 / 30)
    local lisse = math.min(1, dt * 12)
    local i = 1
    while i <= #toutesCartes do
        local c = toutesCartes[i]
        if c.mort then
            table.remove(toutesCartes, i)
            continue
        end
        i += 1
        -- taille visée : grossit au survol, rétrécit un peu quand on survole une autre carte
        local cible
        if not menuOuvert or t < c.delai then
            cible = 0
        elseif c.survole then
            cible = 1.07
        elseif c.choisi then
            cible = 1.03
        elseif quelqueChoseSurvole then
            cible = 0.97
        else
            cible = 1
        end
        -- ressort : ça dépasse un peu puis ça se stabilise (effet « boing »)
        c.v += (-(c.x - cible) * 320 - c.v * 19) * pas
        c.x += c.v * pas
        c.echelle.Scale = math.max(0, c.x)
        local apparu = math.clamp(c.x, 0, 1)

        c.lift += ((if c.survole then -12 else 0) - c.lift) * lisse
        c.carte.Position = UDim2.new(0.5, 0, 0.5, c.lift)
        local grossi = if c.survole then 26 elseif c.choisi then 14 else 0
        c.halo.Position = c.carte.Position
        c.halo.Size = c.halo.Size:Lerp(UDim2.new(c.x, grossi, c.x, grossi), lisse)
        local opaciteHalo = if c.survole then 0.35 elseif c.choisi then 0.22 + 0.1 * math.sin(t * 5) else 0
        c.halo.BackgroundTransparency = 1 - opaciteHalo * apparu

        c.contour.Thickness += ((if c.survole then 5 elseif c.choisi then 4 else 2) - c.contour.Thickness) * lisse
        c.reflet.Rotation = (c.reflet.Rotation + dt * (if c.survole then 260 elseif c.choisi then 110 else 35)) % 360
        local sombre = quelqueChoseSurvole and not c.survole and not c.choisi
        c.voile.BackgroundTransparency += ((if sombre then 0.5 else 1) - c.voile.BackgroundTransparency) * lisse

        if c.icone then
            c.echelleIcone.Scale += ((if c.survole then 1.12 else 1) - c.echelleIcone.Scale) * lisse
        end
        if c.barres then
            for k, barreEq in ipairs(c.barres) do
                local hauteur = if c.survole or c.choisi then 0.12 + 0.4 * math.abs(math.sin(t * (5 + k * 1.7) + k)) else 0.12
                barreEq.Size = barreEq.Size:Lerp(UDim2.fromScale(0.03, hauteur), math.min(1, dt * 20))
            end
        end
    end
end)


-- ========================== EFFETS 3D (éclats, ondes au sol) ==========================
local dossierEffets = nouveau("Folder", { Name = "MindsetEffetsLocaux", Parent = workspace })
local eclats, ondeSol
do
local function blocLocal(proprietes)
    proprietes.Anchored = true
    proprietes.CanCollide = false
    proprietes.CanQuery = false
    proprietes.CanTouch = false
    proprietes.CastShadow = false
    proprietes.Parent = dossierEffets
    return nouveau("Part", proprietes)
end
local porteEclats = blocLocal({ Name = "Eclats", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 })
local emetteurEclats = nouveau("ParticleEmitter", {
    Rate = 0,
    Lifetime = NumberRange.new(0.3, 0.7),
    Speed = NumberRange.new(6, 16),
    SpreadAngle = Vector2.new(180, 180),
    Drag = 4,
    Acceleration = Vector3.new(0, -12, 0),
    Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) }),
    LightEmission = 1,
    Parent = porteEclats,
})
eclats = function(position, couleur, nombre, vitesse)
    porteEclats.Position = position
    emetteurEclats.Color = ColorSequence.new(couleur, BLANC)
    emetteurEclats.Speed = NumberRange.new(6 * (vitesse or 1), 16 * (vitesse or 1))
    emetteurEclats:Emit(nombre)
end
ondeSol = function(position, couleur, taille, vertical)
    local onde = blocLocal({
        Name = "Onde",
        Shape = Enum.PartType.Cylinder,
        Material = Enum.Material.Neon,
        Color = couleur,
        Transparency = 0.15,
        Size = Vector3.new(0.12, 1, 1),
        -- à plat sur le sol, ou debout (vertical)
        CFrame = CFrame.new(position) * (if vertical then CFrame.Angles(0, math.pi / 2, 0) else CFrame.Angles(0, 0, math.pi / 2)),
    })
    tween(onde, 0.4, { Size = Vector3.new(0.12, taille, taille), Transparency = 1 })
    task.delay(0.42, function()
        onde:Destroy()
    end)
end
end -- fin du bloc des effets 3D

-- ========================== AVATARS ==========================
-- Chaque grimpeur (toi, les autres joueurs, les bots) : son étiquette au-dessus de la tête,
-- ses effets d'aura (série sans tomber) et sa danse s'il gagne.
local avatars = {}  -- [config] = état de l'avatar
local monEtat = nil

local function couleurDe(etat)
    return COULEURS[etat.config:GetAttribute("Perso")] or Color3.fromRGB(200, 200, 210)
end
local function maCouleur()
    return if monEtat then couleurDe(monEtat) else OR
end

local function hauteurRacine(modele)
    local humanoid = modele:FindFirstChildOfClass("Humanoid")
    local racine = modele:FindFirstChild("HumanoidRootPart")
    if humanoid and racine and humanoid.RigType == Enum.HumanoidRigType.R15 then
        return humanoid.HipHeight + racine.Size.Y / 2
    end
    return 3
end

-- les articulations (R15) qu'on plie à la main pour la danse du gagnant
local function chargerMembres(etat)
    etat.membres = {}
    for _, nom in ipairs({ "LeftHip", "RightHip", "LeftKnee", "RightKnee", "LeftShoulder", "RightShoulder", "Waist", "LeftElbow", "RightElbow", "Neck" }) do
        local moteur = etat.modele:FindFirstChild(nom, true)
        if moteur and moteur:IsA("Motor6D") then
            etat.membres[nom] = { moteur = moteur, c0 = moteur.C0, angle = Vector3.zero }
        end
    end
end

-- Plie les articulations : pose = { LeftHip = angle, ... } (en radians, rien = position normale)
--   un nombre = rotation avant / arrière ; un Vector3 = rotation sur les 3 axes (X avant, Y tourner, Z de côté)
--   hanche / épaule + = vers l'avant · genou - = plié · taille - = penché en avant · cou - = tête baissée
--   épaule droite Z + = bras écarté sur le côté (épaule gauche : Z -)
local POSE_REPOS = {}
local function poser(etat, pose)
    if not etat.membres then
        return
    end
    pose = pose or POSE_REPOS
    for nom, info in pairs(etat.membres) do
        local angle = pose[nom] or 0
        local v = if typeof(angle) == "Vector3" then angle else Vector3.new(angle, 0, 0)
        if (v - info.angle).Magnitude > 0.001 and info.moteur.Parent then
            info.angle = v
            info.moteur.C0 = info.c0 * CFrame.Angles(v.X, v.Y, v.Z)
        end
    end
end

-- La danse du gagnant (attribut « Danse » : 0 = rien, 1/2/3 = le mouvement en cours).
-- Faite à la main, calée sur le rythme (voir danseBadass, plus bas).
local function majDanse(etat)
    local n = etat.config:GetAttribute("Danse") or 0
    if n == (etat.danseJouee or 0) then
        return
    end
    etat.danseJouee = n
    if n > 0 then
        etat.danse = etat.danse or { debut = os.clock(), dernierTemps = -1, effets = {} }
        etat.danse.mouvement = n
        etat.danse.changement = os.clock()
    elseif etat.danse then
        for _, effet in ipairs(etat.danse.effets) do
            effet:Destroy()
        end
        etat.danse = nil
        poser(etat, nil)
    end
end

-- l'étiquette : l'état d'esprit en grand, et en dessous « pseudo • marche »
local function majEtiquette(etat)
    if not etat.etiquettePerso then
        return
    end
    local perso = etat.config:GetAttribute("Perso")
    etat.etiquettePerso.Text = if perso then string.upper(perso) else "???"
    etat.etiquettePerso.TextColor3 = couleurDe(etat)
    local nom = etat.config:GetAttribute("Nom") or ""
    local marche = etat.config:GetAttribute("Marche") or 0
    etat.etiquetteNom.Text = if etat.config:GetAttribute("EnJeu") then nom .. "  •  " .. marche else nom
    etat.etiquette.Enabled = not etat.config:GetAttribute("Hub") -- (dans le hub, c'est MindsetHub qui met son étiquette)
end

local function creerEtiquette(etat)
    local tete = etat.modele:FindFirstChild("Head") or etat.modele:FindFirstChild("HumanoidRootPart")
    if not tete then
        return
    end
    local ancienne = tete:FindFirstChild("MindsetEtiquette")
    if ancienne then
        ancienne:Destroy()
    end
    etat.etiquette = nouveau("BillboardGui", {
        Name = "MindsetEtiquette",
        Size = UDim2.fromOffset(if etat.estMoi then 200 else 170, if etat.estMoi then 58 else 50),
        StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0),
        AlwaysOnTop = true,
        MaxDistance = 250,
        LightInfluence = 0,
        Parent = tete,
    })
    etat.etiquettePerso = texte({ Size = UDim2.fromScale(1, 0.58), Parent = etat.etiquette })
    etat.etiquetteNom = texte({
        Position = UDim2.fromScale(0, 0.58),
        Size = UDim2.fromScale(1, 0.42),
        TextColor3 = Color3.fromRGB(225, 225, 235),
        Parent = etat.etiquette,
    })
    majEtiquette(etat)
end

local NOMS_NIVEAUX = { "✨ AURA LEVEL 1", "🔥 AURA LEVEL 2", "👑 MAX AURA" }

-- les effets d'aura : plus tu enchaînes de marches sans tomber, plus tu brilles
local function majAuraAvatar(etat)
    if not etat.modele then
        return
    end
    local niveau = etat.config:GetAttribute("NiveauAura") or 0
    if niveau == etat.niveauAffiche then
        return
    end
    for _, effet in ipairs(etat.effets) do
        effet:Destroy()
    end
    etat.effets = {}
    local couleur = couleurDe(etat)
    local racine = etat.modele:FindFirstChild("HumanoidRootPart")
    local torse = etat.modele:FindFirstChild("UpperTorso") or etat.modele:FindFirstChild("Torso") or racine
    if racine and niveau >= 1 then
        table.insert(etat.effets, nouveau("Sparkles", { SparkleColor = couleur, Parent = racine }))
    end
    if torse and niveau >= 2 then
        table.insert(etat.effets, nouveau("Fire", { Color = couleur, SecondaryColor = BLANC, Size = 5, Heat = 8, Parent = torse }))
    end
    if racine and niveau >= 3 then
        table.insert(etat.effets, nouveau("PointLight", { Color = couleur, Brightness = 5, Range = 20, Parent = racine }))
        table.insert(etat.effets, nouveau("Highlight", {
            FillColor = couleur,
            FillTransparency = 0.6,
            OutlineColor = BLANC,
            DepthMode = Enum.HighlightDepthMode.Occluded,
            Parent = etat.modele,
        }))
    end
    if etat.estMoi and niveau > (etat.niveauAffiche or 0) and NOMS_NIVEAUX[niveau] then
        auraTexte.TextColor3 = if niveau == 3 then OR else couleur
        apparaitre(auraTexte, NOMS_NIVEAUX[niveau], 1.6)
        flasher(couleur, 0.25 + niveau * 0.1)
        secousse(0.6 + niveau * 0.3)
    end
    etat.niveauAffiche = niveau
end

-- « +1 AURA » qui s'envole au-dessus du danseur
local function popupAura(etat)
    local tete = etat.modele and (etat.modele:FindFirstChild("Head") or etat.modele:FindFirstChild("HumanoidRootPart"))
    if not tete then
        return
    end
    local couleur = couleurDe(etat)
    local decalX = (math.random() - 0.5) * 3
    local bulle = nouveau("BillboardGui", {
        Size = UDim2.fromOffset(140, 40),
        StudsOffsetWorldSpace = Vector3.new(decalX, 4.5, 0),
        AlwaysOnTop = true,
        LightInfluence = 0,
        MaxDistance = 3000,
        Parent = tete,
    })
    local label = texte({ Size = UDim2.fromScale(1, 1), Text = "+1 AURA", TextColor3 = if math.random() < 0.3 then OR else couleur, Parent = bulle })
    tween(bulle, 0.8, { StudsOffsetWorldSpace = Vector3.new(decalX * 1.4, 8, 0) }, Enum.EasingStyle.Quint)
    tween(label, 0.8, { TextTransparency = 1, TextStrokeTransparency = 1 })
    task.delay(0.8, function()
        bulle:Destroy()
    end)
    eclats(tete.Position, couleur, 4, 0.6)
end
local surAuraFarmee -- (défini plus bas : compteur à l'écran quand c'est TOI qui danses)
local surMaMarche   -- (défini plus bas : les réactions quand TU montes)

local function ajouterGrimpeur(config)
    if avatars[config] then
        return
    end
    local etat = {
        config = config,
        estMoi = config:GetAttribute("UserId") == joueur.UserId,
        effets = {},
        niveauAffiche = 0,
    }
    avatars[config] = etat
    if etat.estMoi then
        monEtat = etat
    end

    local valeur = config:WaitForChild("Modele", 10)
    local function majModele()
        etat.modele = valeur and valeur.Value
        etat.hauteur = nil
        etat.membres = nil
        etat.danseJouee = 0
        if etat.danse then
            for _, effet in ipairs(etat.danse.effets) do
                effet:Destroy()
            end
            etat.danse = nil
        end
        etat.effets = {}
        etat.niveauAffiche = 0
        local modele = etat.modele
        if not modele then
            return
        end
        task.spawn(function()
            if not modele:WaitForChild("HumanoidRootPart", 10) or etat.modele ~= modele then
                return
            end
            modele:WaitForChild("Head", 5)
            etat.hauteur = hauteurRacine(modele)
            chargerMembres(etat)
            creerEtiquette(etat)
            majAuraAvatar(etat)
            majDanse(etat)
        end)
    end
    if valeur then
        valeur.Changed:Connect(majModele)
    end
    majModele()

    for _, attribut in ipairs({ "Perso", "Nom", "EnJeu", "Hub" }) do
        config:GetAttributeChangedSignal(attribut):Connect(function()
            majEtiquette(etat)
        end)
    end
    local derniereMarche = config:GetAttribute("Marche") or 0
    config:GetAttributeChangedSignal("Marche"):Connect(function()
        majEtiquette(etat)
        local marche = config:GetAttribute("Marche") or 0
        if etat.estMoi and surMaMarche then
            surMaMarche(derniereMarche, marche)
        end
        derniereMarche = marche
    end)
    config:GetAttributeChangedSignal("NiveauAura"):Connect(function()
        majAuraAvatar(etat)
    end)
    config:GetAttributeChangedSignal("Danse"):Connect(function()
        majDanse(etat)
    end)
    config:GetAttributeChangedSignal("AuraFarmee"):Connect(function()
        local n = config:GetAttribute("AuraFarmee") or 0
        if n > 0 and etat.danse then
            etat.danse.coup = os.clock() -- chaque pas de danse = un coup d'accent dans la danse
            etat.danse.nbCoups = n
        end
        if n > 0 then
            popupAura(etat)
            if etat.estMoi and surAuraFarmee then
                surAuraFarmee(n)
            end
        end
    end)
end

dossierGrimpeurs.ChildAdded:Connect(ajouterGrimpeur)
dossierGrimpeurs.ChildRemoved:Connect(function(config)
    if avatars[config] == monEtat then
        monEtat = nil
    end
    avatars[config] = nil
end)
for _, config in ipairs(dossierGrimpeurs:GetChildren()) do
    task.spawn(ajouterGrimpeur, config)
end

-- est-ce que TU cours en ce moment ?
local function jeCours()
    return monEtat ~= nil and monEtat.config:GetAttribute("EnJeu") == true and ReplicatedStorage:GetAttribute("Phase") == "Manche"
end

-- ========================== MUSIQUE ==========================
local musique = nouveau("Sound", { Name = "MindsetMusique", Volume = 0.8, SoundGroup = groupeMusique, Parent = SoundService })
local partition = nil      -- infos de la course en cours : debut, duree, bpm, musique, debutMusique, tempete
local intervalle = 0.5     -- un temps de la musique (secondes) : la danse du gagnant est calée dessus

local function couperMusique(duree)
    tween(musique, duree, { Volume = 0 })
    task.delay(duree, function()
        if not partition then
            musique:Stop()
            musique.Volume = 0.8
        end
    end)
end

-- ========================== RÉACTIONS QUAND TU MONTES ==========================
local sceneActive = false -- la caméra est sur la scène du vainqueur
surMaMarche = function(avant, apres)
    if not jeCours() or apres <= avant then
        return
    end
    if math.floor(apres / 50) > math.floor(avant / 50) then
        grosTexte.TextColor3 = maCouleur()
        apparaitre(grosTexte, "🪜 " .. math.floor(apres / 50) * 50 .. " STEPS!", 1, echelleGros)
        flasher(maCouleur(), 0.3)
        secousse(0.8)
        fovPulse = math.min(fovPulse, -4)
    end
end

-- ✨ MODE AURA : au niveau d'aura max (300 marches sans tomber), image en noir et blanc, comme les edits TikTok
local modeAura = false
task.spawn(function()
    while not monEtat do
        task.wait(0.2)
    end
    local config = monEtat.config
    config:GetAttributeChangedSignal("NiveauAura"):Connect(function()
        local actif = (config:GetAttribute("NiveauAura") or 0) >= 3
        if actif == modeAura or sceneActive then
            return
        end
        modeAura = actif
        if actif then
            tween(effetAura, 0.4, { Saturation = -1, Contrast = 0.35, Brightness = 0.02 })
            grosTexte.TextColor3 = OR
            apparaitre(grosTexte, "🔥 AURA MODE 🔥", 1.4, echelleGros)
            flasher(BLANC, 0.6)
            secousse(1.5)
        else
            tween(effetAura, 0.6, { Saturation = 0, Contrast = 0, Brightness = 0 })
            grosTexte.TextColor3 = ROUGE
            apparaitre(grosTexte, "💀 AURA LOST", 1, echelleGros)
        end
    end)
    config:GetAttributeChangedSignal("Perso"):Connect(function()
        local perso = config:GetAttribute("Perso")
        choisirPersoAffiche(perso)
        -- pas de gros texte si tu viens de cliquer la carte (le menu fait déjà le show)
        if perso and perso ~= dernierClicPerso then
            grosTexte.TextColor3 = COULEURS[perso] or BLANC
            apparaitre(grosTexte, "You are: " .. string.upper(perso), 1.4, echelleGros)
        end
    end)
    choisirPersoAffiche(config:GetAttribute("Perso"))
end)

-- ========================== DÉBUT D'UNE COURSE ==========================
local function afficherDecompte(message, couleur)
    decompte.Text = message
    decompte.TextColor3 = couleur
    decompte.TextTransparency = 0
    decompte.TextStrokeTransparency = 0
    echelleDecompte.Scale = 2.2
    tween(echelleDecompte, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
    task.delay(0.7, function()
        if decompte.Text == message then
            tween(decompte, 0.25, { TextTransparency = 1, TextStrokeTransparency = 1 })
        end
    end)
end

DebutEvent.OnClientEvent:Connect(function(infos)
    partition = infos
    intervalle = 60 / (infos.bpm or 120)
    if infos.musique and infos.musique ~= "" then
        musique.SoundId = infos.musique
        musique.Volume = 0.8
        task.spawn(function()
            pcall(function()
                ContentProvider:PreloadAsync({ musique }, function(_, statutChargement)
                    if statutChargement ~= Enum.AssetFetchStatus.Success then
                        warn("[MUSIQUE] Impossible de charger " .. tostring(infos.musique) .. " (statut : " .. tostring(statutChargement) .. ")")
                    end
                end)
            end)
        end)
    end
    -- décompte 3, 2, 1, GO
    task.spawn(function()
        local couleurs = { Color3.fromRGB(120, 255, 140), Color3.fromRGB(255, 220, 80), ROUGE }
        for n = 3, 1, -1 do
            local attente = infos.debut - n - maintenantServeur()
            if attente > 0 then
                task.wait(attente)
            end
            if partition ~= infos then
                return
            end
            afficherDecompte(tostring(n), couleurs[n])
            jouerSon("tic", 0.75, 0.7, nil, 0.16)
            jouerSon("tic", 1.5, 0.35, nil, 0.16)
            flasher(BLANC, 0.15)
            secousse(0.5)
        end
        local attente = infos.debut - maintenantServeur()
        if attente > 0 then
            task.wait(attente)
        end
        if partition ~= infos then
            return
        end
        afficherDecompte(if jeCours() then "CLIMB!" else "SPECTATING", OR)
        jouerSon("tic", 1.5, 0.7, nil, 0.4)
        jouerSon("tic", 3, 0.35, nil, 0.4)
        jouerSon("tic", 2, 0.3, 0.08, 0.3)
        flasher(BLANC, 0.5)
        secousse(1)
        fovPulse = -8
        -- la musique part au GO
        if infos.musique and infos.musique ~= "" then
            musique.TimePosition = (infos.debutMusique or 0) + math.max(0, maintenantServeur() - infos.debut)
            musique.PlaybackSpeed = 1
            musique:Play()
        end
    end)
end)

-- ========================== LE DOUBLE SAUT DE L'EGO ==========================
-- En l'air, appuie encore sur SAUT : tu repars vers le haut (une fois par saut).
do
local sautUtilise = false
local decollage = 0
local function suivreHumanoid(personnage)
    local humanoid = personnage:WaitForChild("Humanoid", 10)
    if not humanoid then
        return
    end
    humanoid.StateChanged:Connect(function(_, nouvel)
        if nouvel == Enum.HumanoidStateType.Jumping then
            decollage = os.clock()
        elseif nouvel == Enum.HumanoidStateType.Landed or nouvel == Enum.HumanoidStateType.Running then
            sautUtilise = false
        end
    end)
end
joueur.CharacterAdded:Connect(suivreHumanoid)
if joueur.Character then
    task.spawn(suivreHumanoid, joueur.Character)
end
UserInputService.JumpRequest:Connect(function()
    if not jeCours() or not monEtat.config:GetAttribute("DoubleSaut") or sautUtilise then
        return
    end
    local personnage = joueur.Character
    local humanoid = personnage and personnage:FindFirstChildOfClass("Humanoid")
    local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
    if not humanoid or not racine or humanoid.FloorMaterial ~= Enum.Material.Air or os.clock() - decollage < 0.18 then
        return
    end
    local etatHumanoid = humanoid:GetState()
    if etatHumanoid ~= Enum.HumanoidStateType.Freefall and etatHumanoid ~= Enum.HumanoidStateType.Jumping then
        return
    end
    sautUtilise = true
    local v = racine.AssemblyLinearVelocity
    racine.AssemblyLinearVelocity = Vector3.new(v.X, math.sqrt(2 * workspace.Gravity * humanoid.JumpHeight), v.Z)
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    local pieds = racine.Position - Vector3.new(0, hauteurRacine(personnage), 0)
    ondeSol(pieds, COULEURS.Ego, 6)
    eclats(pieds, COULEURS.Ego, 10, 0.8)
    jouerSon("tic", 2.2, 0.35, nil, 0.12)
end)
end -- fin du bloc du double saut

-- ========================== LES ROCHERS ==========================
-- Un rocher qui te touche te renverse et te fait dévaler quelques marches (sauf la chance de l'OBSESSION « UNSTOPPABLE »).
do
local dossierObstacles = workspace:WaitForChild("MindsetObstacles", 20)
local dernierCoup = 0
local function chanceTenace()
    if not monEtat or monEtat.config:GetAttribute("Perso") ~= "Obsession" then
        return 0
    end
    local def = DEFS.persos and DEFS.persos.Obsession and DEFS.persos.Obsession[2]
    local niveau = tonumber(mesNiveaux("Obsession")[2]) or 0
    if not def or niveau <= 0 then
        return 0
    end
    return def.valeurs[math.min(niveau, #def.valeurs)] or 0
end
RunService.Heartbeat:Connect(function()
    if not dossierObstacles or not jeCours() or os.clock() - dernierCoup < 1.2 then
        return
    end
    local personnage = joueur.Character
    local humanoid = personnage and personnage:FindFirstChildOfClass("Humanoid")
    local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
    if not humanoid or not racine or racine.Anchored then
        return
    end
    for _, rocher in ipairs(dossierObstacles:GetChildren()) do
        if rocher:IsA("BasePart") and (rocher.Position - racine.Position).Magnitude < rocher.Size.X / 2 + 1.8 then
            dernierCoup = os.clock()
            if math.random(1, 100) <= chanceTenace() then
                grosTexte.TextColor3 = COULEURS.Obsession
                apparaitre(grosTexte, "UNSTOPPABLE!", 0.9, echelleGros)
                eclats(racine.Position, COULEURS.Obsession, 14, 1)
                return
            end
            humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
            racine.AssemblyLinearVelocity = Vector3.new(-45, 30, math.clamp((racine.Position.Z - rocher.Position.Z) * 6, -25, 25))
            flasher(ROUGE, 0.35)
            secousse(2)
            fovPulse = 6
            auraTexte.TextColor3 = ROUGE
            apparaitre(auraTexte, "💥 BOULDER!", 0.9)
            jouerSon("boum", 0.9, 0.45, nil, 0.6)
            return
        end
    end
end)
end -- fin du bloc des rochers


-- ========================== DANSE DU GAGNANT ==========================
local arreterDanseUI, demarrerDanseUI
do
local uiDanse =nouveau("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 34, Parent = gui })
local boutonDanse = nouveau("TextButton", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 0.86, 0),
    Size = UDim2.fromOffset(if surMobile then 300 else 340, 84),
    BackgroundColor3 = OR,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBlack,
    Text = "DANCE!",
    TextScaled = true,
    TextColor3 = NOIR,
    ZIndex = 36,
    Parent = uiDanse,
})
nouveau("UICorner", { CornerRadius = UDim.new(0, 18), Parent = boutonDanse })
nouveau("UIStroke", { Color = BLANC, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = boutonDanse })
nouveau("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14), Parent = boutonDanse })
local echelleBoutonDanse = nouveau("UIScale", { Parent = boutonDanse })
texte({
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 0.86, -92),
    Size = UDim2.new(0.6, 0, 0, 28),
    Text = if surMobile then "Tap DANCE to farm aura!" else "Click DANCE or press SPACE to farm aura!",
    ZIndex = 36,
    Parent = uiDanse,
})
local compteurDanse = texte({
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.36),
    Size = UDim2.new(0.6, 0, 0, 60),
    TextColor3 = OR,
    Text = "",
    ZIndex = 36,
    Parent = uiDanse,
})
local echelleCompteurDanse = nouveau("UIScale", { Parent = compteurDanse })
local danseActive, danseFin = false, 0

arreterDanseUI = function()
    danseActive = false
    uiDanse.Visible = false
end
demarrerDanseUI = function(fin)
    danseActive, danseFin = true, fin
    compteurDanse.Text = "FARM YOUR AURA!"
    uiDanse.Visible = true
    echelleBoutonDanse.Scale = 0
    tween(echelleBoutonDanse, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
end
-- le bouton DANSE pulse, et disparaît tout seul à la fin de la danse
RunService.RenderStepped:Connect(function()
    if danseActive then
        if maintenantServeur() > danseFin then
            arreterDanseUI()
        else
            boutonDanse.Rotation = math.sin(os.clock() * 9) * 3
        end
    end
end)

local function danser()
    if not danseActive or maintenantServeur() > danseFin then
        return
    end
    DanserEvent:FireServer()
    echelleBoutonDanse.Scale = 0.86
    tween(echelleBoutonDanse, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
    sonSurvol(math.random(1, 7))
end
boutonDanse.Activated:Connect(danser)
UserInputService.InputBegan:Connect(function(input, gere)
    if input.KeyCode == Enum.KeyCode.Space and danseActive and not gere then
        danser()
    end
end)

surAuraFarmee = function(n)
    compteurDanse.Text = "+" .. n .. " AURA FARMED"
    echelleCompteurDanse.Scale = 1.25
    tween(echelleCompteurDanse, 0.15, { Scale = 1 })
    if n % 10 == 0 then
        -- changement de danse : petit boost
        flasher(OR, 0.25)
        secousse(0.8)
        fovPulse = math.min(fovPulse, -3)
        jouerSon("tic", 1.5, 0.4)
        jouerSon("tic", 2, 0.3, 0.06)
    end
end
end -- fin du bloc de la danse



-- ========================== ÉVÉNEMENTS ==========================
EvenementEvent.OnClientEvent:Connect(function(typeEvt, a, b, c)
    if typeEvt == "Chute" then
        -- a = le grimpeur qui est tombé, b = combien de marches il a perdues, c = il est retombé sur son checkpoint
        local etat = avatars[a]
        if etat and etat.estMoi then
            flasher(ROUGE, 0.35)
            secousse(1.4)
            auraTexte.TextColor3 = if c then COULEURS.Discipline else ROUGE
            apparaitre(auraTexte, if c then "🛡 CHECKPOINT" else "💀 -" .. tostring(b or 0) .. " STEPS", 1.2)
            jouerSon("pose", 0.6, 0.5)
        end
        local racine = etat and etat.modele and etat.modele:FindFirstChild("HumanoidRootPart")
        if racine then
            task.delay(0.05, function()
                ondeSol(racine.Position - Vector3.new(0, etat.hauteur or 3, 0), couleurDe(etat), 7)
                eclats(racine.Position, couleurDe(etat), 12, 1)
            end)
        end
    elseif typeEvt == "Tempete" then
        -- le drop de la musique : TEMPÊTE DE ROCHERS
        grosTexte.TextColor3 = ROUGE
        apparaitre(grosTexte, "🪨 BOULDER STORM!", 2, echelleGros)
        flasher(ROUGE, 0.5)
        secousse(2)
        fovPulse = -8
    elseif typeEvt == "Vainqueur" then
        -- a = la liste des gagnants : ils sont sur la scène, la caméra y va
        sceneActive = true
        modeCinema(true)
        tween(effetAura, 0.5, { Saturation = -1, Contrast = 0.4 })
        flasher(OR, 0.7)
        secousse(2)
        local premier = a and a[1] and avatars[a[1]]
        if premier then
            local noms = {}
            for _, config in ipairs(a) do
                table.insert(noms, tostring(config:GetAttribute("Nom")))
            end
            grosTexte.TextColor3 = couleurDe(premier)
            apparaitre(grosTexte, table.concat(noms, " & ") .. " — " .. string.upper(tostring(premier.config:GetAttribute("Perso"))), 2.2, echelleGros)
        end
    elseif typeEvt == "Danse" then
        -- a = la liste des gagnants, b = l'heure (serveur) de fin de la danse
        -- noir et blanc bien contrasté, comme dans les edits de la trend (le danseur, lui, brille)
        tween(effetAura, 0.6, { Saturation = -1, Contrast = 0.45 })
        local jeDanse = false
        local noms = {}
        for _, config in ipairs(a or {}) do
            table.insert(noms, tostring(config:GetAttribute("Nom")))
            if monEtat and config == monEtat.config then
                jeDanse = true
            end
        end
        if jeDanse then
            demarrerDanseUI(b or (maintenantServeur() + 8))
        else
            grosTexte.TextColor3 = OR
            apparaitre(grosTexte, table.concat(noms, " & ") .. " FARMING AURA", 2.5, echelleGros)
        end
    end
end)

-- ========================== LA TREND : MOTIVATION vs EGO vs DISCIPLINE vs OBSESSION ==========================
-- Pendant la manche, le jeu raconte l'histoire de la trend TikTok, avec des phrases en bas de l'écran
-- (style légende TikTok : blanc, gros contour noir, mot par mot) et des effets sur les avatars :
--   début       : MOTIVATION brûle (grosse flamme sur le torse)  → « MOTIVATION gets you started. »
--   38 %        : la flamme de MOTIVATION s'éteint, il fume       → « But MOTIVATION fades... »
--   EGO 1er     : une couronne en or apparaît sur sa tête         → « EGO wants everyone to watch. »
--   EGO qui tombe : la couronne tombe                             → « EGO made <pseudo> fall. »
--   50 %        : DISCIPLINE (calme, régulier)                    → « DISCIPLINE keeps you going. »
--   72 %        : OBSESSION se réveille (aura rouge sang)         → « OBSESSION makes you unstoppable. »
--   à la fin    : une phrase selon l'état d'esprit du gagnant
-- (seulement pour les états d'esprit qui sont dans la manche)
do
local legende = texte({
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.84),
    Size = UDim2.new(0.86, 0, 0, 40),
    Font = Enum.Font.GothamBlack,
    TextColor3 = BLANC,
    TextStrokeColor3 = NOIR,
    TextStrokeTransparency = 0,
    TextTransparency = 1,
    ZIndex = 30,
    Parent = gui,
})
nouveau("UISizeConstraint", { MaxSize = Vector2.new(900, 40), Parent = legende })
local trait = nouveau("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 1, 4),
    Size = UDim2.fromOffset(0, 4),
    BorderSizePixel = 0,
    BackgroundColor3 = BLANC,
    ZIndex = 30,
    Parent = legende,
})
local echelleLegende = nouveau("UIScale", { Parent = legende })
local enCours = false
local attente = {}

-- affiche une phrase mot par mot (en dessous : un trait de la couleur de l'état d'esprit)
local function montrer(message, couleur)
    enCours = true
    legende.Text = message
    legende.TextTransparency = 0
    legende.TextStrokeTransparency = 0
    legende.MaxVisibleGraphemes = 0
    trait.BackgroundColor3 = couleur or BLANC
    trait.Size = UDim2.fromOffset(0, 4)
    tween(trait, 0.6, { Size = UDim2.fromOffset(220, 4) }, Enum.EasingStyle.Quint)
    echelleLegende.Scale = 1.15
    tween(echelleLegende, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
    task.spawn(function()
        task.wait() -- (le temps que le texte soit traduit)
        local debut = os.clock()
        local total = utf8.len(legende.Text) or #legende.Text
        while os.clock() - debut < 0.55 do
            legende.MaxVisibleGraphemes = math.floor(total * (os.clock() - debut) / 0.55)
            task.wait()
        end
        legende.MaxVisibleGraphemes = -1
        task.wait(2.4)
        tween(legende, 0.35, { TextTransparency = 1, TextStrokeTransparency = 1 })
        tween(trait, 0.35, { Size = UDim2.fromOffset(0, 4) })
        task.wait(0.4)
        enCours = false
        local suivante = table.remove(attente, 1)
        if suivante then
            montrer(suivante[1], suivante[2])
        end
    end)
end

local function dire(message, couleur)
    if enCours then
        if #attente < 2 then
            table.insert(attente, { message, couleur })
        end
        return
    end
    montrer(message, couleur)
end

-- les effets posés sur les avatars pendant la manche (tout est détruit à la manche suivante)
local effets = {}
local function garder(objet)
    table.insert(effets, objet)
    return objet
end
local function nettoyer()
    for _, objet in ipairs(effets) do
        objet:Destroy()
    end
    effets = {}
    attente = {}
end

local function joueursDe(perso)
    local liste = {}
    for _, etat in pairs(avatars) do
        if etat.modele and etat.config:GetAttribute("EnJeu") and etat.config:GetAttribute("Perso") == perso then
            table.insert(liste, etat)
        end
    end
    return liste
end

local function torse(etat)
    return etat.modele:FindFirstChild("UpperTorso") or etat.modele:FindFirstChild("Torso") or etat.modele:FindFirstChild("HumanoidRootPart")
end

-- la couronne de l'EGO (5 pointes en or autour de la tête)
local function couronne(etat)
    local tete = etat.modele:FindFirstChild("Head")
    if not tete or etat.couronne then
        return
    end
    local modele = nouveau("Model", { Name = "MindsetCouronne", Parent = etat.modele })
    for i = 0, 4 do
        local a = i / 5 * math.pi * 2
        local pointe = nouveau("Part", {
            Size = Vector3.new(0.22, 0.55, 0.22),
            CFrame = tete.CFrame * CFrame.new(math.cos(a) * 0.5, 0.85, math.sin(a) * 0.5),
            Material = Enum.Material.Neon,
            Color = OR,
            CanCollide = false,
            CanQuery = false,
            CanTouch = false,
            Massless = true,
            CastShadow = false,
            Parent = modele,
        })
        nouveau("WeldConstraint", { Part0 = tete, Part1 = pointe, Parent = pointe })
    end
    etat.couronne = garder(modele)
end

local function enleverCouronne(etat)
    local modele = etat.couronne
    etat.couronne = nil
    if modele and modele.Parent then
        local pointes = modele:GetChildren()
        for _, pointe in ipairs(pointes) do
            local soudure = pointe:FindFirstChildOfClass("WeldConstraint")
            if soudure then
                soudure:Destroy()
            end
            pointe.Anchored = true
            pointe.Parent = workspace -- (sinon elle suivrait encore l'avatar)
            tween(pointe, 0.7, { CFrame = pointe.CFrame * CFrame.new(0, -6, 0) * CFrame.Angles(2, 0, 1), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
        task.delay(0.8, function()
            for _, pointe in ipairs(pointes) do
                pointe:Destroy()
            end
            modele:Destroy()
        end)
    end
end

-- les étapes de l'histoire, selon l'avancée de la musique (0 = début, 1 = fin)
local ETAPES = {
    { a = 0.02, perso = "Motivation", action = function(liste)
        for _, etat in ipairs(liste) do
            local t = torse(etat)
            if t then
                etat.flammeMotivation = garder(nouveau("Fire", { Size = 7, Heat = 12, Color = COULEURS.Motivation, SecondaryColor = OR, Parent = t }))
            end
        end
        dire("MOTIVATION gets you started.", COULEURS.Motivation)
    end },
    { a = 0.38, perso = "Motivation", action = function(liste)
        for _, etat in ipairs(liste) do
            local t = torse(etat)
            if etat.flammeMotivation then
                tween(etat.flammeMotivation, 6, { Size = 0.5, Heat = 0 }, Enum.EasingStyle.Linear)
                local flamme = etat.flammeMotivation
                task.delay(6, function()
                    flamme.Enabled = false
                end)
            end
            if t then
                garder(nouveau("Smoke", { Color = Color3.fromRGB(120, 120, 120), Opacity = 0.15, RiseVelocity = 3, Size = 1.5, Parent = t }))
            end
        end
        dire("But MOTIVATION fades...", COULEURS.Motivation)
    end },
    { a = 0.5, perso = "Discipline", action = function(liste)
        for _, etat in ipairs(liste) do
            local racine = etat.modele:FindFirstChild("HumanoidRootPart")
            if racine then
                garder(nouveau("PointLight", { Color = COULEURS.Discipline, Brightness = 1.5, Range = 10, Parent = racine }))
            end
        end
        dire("DISCIPLINE keeps you going.", COULEURS.Discipline)
    end },
    { a = 0.72, perso = "Obsession", action = function(liste)
        for _, etat in ipairs(liste) do
            local t = torse(etat)
            garder(nouveau("Highlight", {
                FillColor = COULEURS.Obsession,
                FillTransparency = 0.75,
                OutlineColor = COULEURS.Obsession,
                OutlineTransparency = 0,
                DepthMode = Enum.HighlightDepthMode.Occluded,
                Parent = etat.modele,
            }))
            if t then
                garder(nouveau("ParticleEmitter", {
                    Rate = 30,
                    Lifetime = NumberRange.new(0.5, 1),
                    Speed = NumberRange.new(2, 5),
                    SpreadAngle = Vector2.new(30, 30),
                    EmissionDirection = Enum.NormalId.Top,
                    Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
                    LightEmission = 1,
                    Color = ColorSequence.new(COULEURS.Obsession, NOIR),
                    Parent = t,
                }))
            end
        end
        if REGLAGES.flashs then
            flasher(COULEURS.Obsession, 0.35)
        end
        dire("OBSESSION makes you unstoppable.", COULEURS.Obsession)
    end },
}

local LIGNES_GAGNANT = {
    Motivation = "MOTIVATION started it... and finished it.",
    Ego = "EGO won. Everyone will hear about it.",
    Discipline = "DISCIPLINE wins. As always.",
    Obsession = "OBSESSION took everything.",
}

local suivi = { partition = nil }
RunService.Heartbeat:Connect(function()
    if not partition or ReplicatedStorage:GetAttribute("Phase") ~= "Manche" then
        return
    end
    if suivi.partition ~= partition then
        -- nouvelle manche
        nettoyer()
        for _, etat in pairs(avatars) do
            etat.flammeMotivation, etat.couronne, etat.comboEgo = nil, nil, 0
        end
        suivi = { partition = partition, faits = {}, egoMontre = false, egoTombe = 0 }
    end
    local progression = (maintenantServeur() - partition.debut) / (partition.duree or 60)
    if progression < 0 then
        return
    end
    for i, etape in ipairs(ETAPES) do
        if not suivi.faits[i] and progression >= etape.a then
            suivi.faits[i] = true
            local liste = joueursDe(etape.perso)
            if #liste > 0 then
                etape.action(liste)
            end
        end
    end
    -- l'EGO : une couronne quand il est PREMIER (il frime), elle tombe s'il perd la tête de la course
    for _, etat in ipairs(joueursDe("Ego")) do
        local premier = etat.config:GetAttribute("Rang") == 1 and progression > 0.05
        if premier and not etat.couronne then
            couronne(etat)
            if not suivi.egoMontre then
                suivi.egoMontre = true
                dire("EGO wants everyone to watch.", COULEURS.Ego)
            end
        elseif not premier and etat.couronne then
            enleverCouronne(etat)
        end
    end
end)

-- l'EGO qui tombe : la couronne tombe avec lui
-- à la fin : la phrase du gagnant ; au lobby : on enlève tout
EvenementEvent.OnClientEvent:Connect(function(typeEvt, a)
    if typeEvt == "Chute" and a and a:GetAttribute("Perso") == "Ego" and ReplicatedStorage:GetAttribute("Phase") == "Manche" then
        local etat = avatars[a]
        if etat then
            enleverCouronne(etat)
        end
        if suivi.egoTombe and suivi.egoTombe < 2 then
            suivi.egoTombe += 1
            dire("EGO made " .. tostring(a:GetAttribute("Nom")) .. " fall.", COULEURS.Ego)
        end
    elseif typeEvt == "Vainqueur" and a and a[1] then
        local perso = a[1]:GetAttribute("Perso")
        if LIGNES_GAGNANT[perso] then
            task.delay(1.3, function()
                attente = {}
                dire(LIGNES_GAGNANT[perso], COULEURS[perso])
            end)
        end
    end
end)
ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(function()
    if ReplicatedStorage:GetAttribute("Phase") == "Lobby" then
        nettoyer()
        suivi = { partition = nil }
    end
end)
end -- fin du bloc de la trend


-- ========================== LANGUE (anglais / français) ==========================
-- Tout le jeu est écrit en anglais. Ce bloc traduit À LA VOLÉE chaque texte affiché (ce script,
-- le hub, les tableaux 3D, les étiquettes, les messages du serveur, les boutons « E ») :
--   FR_EXACT  = les phrases fixes
--   FR_MOTIFS = les phrases avec des nombres ou des noms dedans (motifs Lua, %1 = ce qui est entre parenthèses)
-- Pour ajouter une traduction : ajoute une ligne ici, rien d'autre à toucher.
-- La langue se choisit dans PARAMÈTRES (AUTO = la langue de Roblox du joueur).
local Langue = {}
do
local LocalizationService = game:GetService("LocalizationService")

local FR_EXACT = {
    -- lobby du jeu
    ["CHOOSE YOUR MINDSET"] = "CHOISIS TON ÉTAT D'ESPRIT",
    ["VOTE FOR THE MUSIC"] = "VOTE POUR LA MUSIQUE",
    ["PICKED"] = "CHOISI",
    ["Choose your mindset"] = "Choisis ton état d'esprit",
    ["Vote for a song"] = "Vote pour une musique",
    ["Locked · upgrade it at the AURA SHOP"] = "Verrouillé · améliore-le à l'AURA SHOP",
    ["RECORD: —"] = "RECORD : —",
    ["YOUR VOTE"] = "TON VOTE",
    ["EASY"] = "FACILE",
    ["MEDIUM"] = "MOYEN",
    ["HARD"] = "DIFFICILE",
    ["EXTREME"] = "EXTRÊME",
    ["The fire of the start"] = "Le feu du départ",
    ["Fast start. Then it fades."] = "Départ en feu. Puis ça s'éteint.",
    ["Double jump. Falls harder."] = "Double saut. Tombe de plus haut.",
    ["Steady. Checkpoints."] = "Régulier. Des checkpoints.",
    ["Slow start. Unstoppable end."] = "Départ lent. Fin inarrêtable.",
    -- l'escalier 3D
    ["CLIMB!"] = "GRIMPE !",
    ["🪨 BOULDER STORM!"] = "🪨 TEMPÊTE DE ROCHERS !",
    ["💥 BOULDER!"] = "💥 ROCHER !",
    ["UNSTOPPABLE!"] = "INARRÊTABLE !",
    ["HIGHEST"] = "PLUS HAUT",
    ["FALLS"] = "CHUTES",
    ["BOULDERS"] = "ROCHERS",
    ["Slow and steady. As always."] = "Lentement mais sûrement. Comme toujours.",
    ["Didn't move the whole round: AFK MODE on"] = "Tu n'as pas bougé de toute la course : MODE AFK activé",
    ["The king of combos"] = "Le roi des combos",
    ["The unbreakable wall"] = "Le mur incassable",
    ["The late-game monster"] = "Le monstre de fin de partie",
    ["🧠 Choose your mindset and vote for the music!"] = "🧠 Choisis ton état d'esprit et vote pour la musique !",
    ["🧠 Choose your mindset!"] = "🧠 Choisis ton état d'esprit !",
    -- pendant la manche
    ["✨ AURA LEVEL 1"] = "✨ AURA NIVEAU 1",
    ["🔥 AURA LEVEL 2"] = "🔥 AURA NIVEAU 2",
    ["👑 MAX AURA"] = "👑 AURA MAX",
    ["🔥 AURA MODE 🔥"] = "🔥 MODE AURA 🔥",
    ["💀 AURA LOST"] = "💀 AURA PERDUE",
    ["CLICK TO THE BEAT!"] = "CLIQUE EN RYTHME !",
    ["SPECTATING"] = "SPECTATEUR",
    ["PERFECT HIGH FIVE!"] = "CHECK PARFAIT !",
    ["TIE!"] = "ÉGALITÉ !",
    ["A round is in progress: you'll play the next one!"] = "Une manche est en cours : tu joueras la prochaine !",
    -- la trend
    ["MOTIVATION gets you started."] = "La MOTIVATION te fait commencer.",
    ["But MOTIVATION fades..."] = "Mais la MOTIVATION s'éteint...",
    ["DISCIPLINE keeps you going."] = "La DISCIPLINE te fait continuer.",
    ["EGO wants everyone to watch."] = "L'EGO veut que tout le monde regarde.",
    ["OBSESSION makes you unstoppable."] = "L'OBSESSION te rend inarrêtable.",
    ["MOTIVATION started it... and finished it."] = "La MOTIVATION a commencé... et a fini.",
    ["EGO won. Everyone will hear about it."] = "L'EGO a gagné. Tout le monde va le savoir.",
    ["DISCIPLINE wins. As always."] = "La DISCIPLINE gagne. Comme toujours.",
    ["OBSESSION took everything."] = "L'OBSESSION a tout pris.",
    -- danse
    ["DANCE!"] = "DANSE !",
    ["Tap DANCE to farm aura!"] = "Appuie sur DANSE pour farmer l'aura !",
    ["Click DANCE or press SPACE to farm aura!"] = "Clique sur DANSE ou appuie sur ESPACE pour farmer l'aura !",
    ["FARM YOUR AURA!"] = "FARME TON AURA !",
    -- classements
    ["LEADERBOARDS"] = "CLASSEMENTS",
    ["Most steps climbed in one game"] = "Le plus de marches montées en une partie",
    ["CLOSE"] = "FERMER",
    ["WORLDWIDE"] = "MONDE ENTIER",
    ["MINDSETS"] = "ÉTATS D'ESPRIT",
    ["SONGS"] = "MUSIQUES",
    ["Loading..."] = "Chargement...",
    ["Leaderboard unavailable right now"] = "Classement indisponible pour l'instant",
    ["Leaderboard unavailable for now"] = "Classement indisponible pour l'instant",
    ["Nobody yet. Be the first!"] = "Personne pour l'instant. Sois le premier !",
    ["No record yet: be the first!"] = "Pas encore de record : sois le premier !",
    ["YOUR RECORD: none yet"] = "TON RECORD : aucun",
    ["WORLDWIDE  ·  the best of all players, every song and mindset"] = "MONDE ENTIER  ·  les meilleurs, toutes musiques et tous états d'esprit",
    -- AFK
    ["AFK MODE  ·  watching the others play"] = "MODE AFK  ·  tu regardes les autres jouer",
    ["AFK MODE  ·  you won't be put in the next game"] = "MODE AFK  ·  tu ne seras pas dans la prochaine partie",
    ["JOIN"] = "REJOINDRE",
    ["Are you away? AFK MODE on"] = "Tu es là ? MODE AFK activé",
    ["No clicks the whole round: AFK MODE on"] = "Aucun clic de toute la manche : MODE AFK activé",
    -- paramètres
    ["SETTINGS"] = "PARAMÈTRES",
    ["MUSIC"] = "MUSIQUE",
    ["SOUND EFFECTS (clicks, menu sounds, effects)"] = "BRUITAGES (clics, sons du menu, effets)",
    ["SCREEN SHAKE"] = "SECOUSSES DE L'ÉCRAN",
    ["FLASHING LIGHTS"] = "FLASHS LUMINEUX",
    ["LANGUAGE"] = "LANGUE",
    ["Your settings are saved for next time."] = "Tes paramètres sont sauvegardés pour la prochaine fois.",
    -- écran de fin
    ["STEPS"] = "MARCHES",
    ["ACCURACY"] = "PRÉCISION",
    ["PERFECTS"] = "PARFAITS",
    ["MAX COMBO"] = "COMBO MAX",
    ["YOUR RECORD"] = "TON RECORD",
    ["AURA EARNED"] = "AURA GAGNÉE",
    ["NEW!"] = "NOUVEAU !",
    ["GAME OVER"] = "FIN DE PARTIE",
    ["WINNER"] = "GAGNANT",
    ["Never looked down."] = "N'a jamais regardé en bas.",
    ["Fiery start... and then?"] = "Départ en feu... et après ?",
    ["Steps lost: 0. Obviously."] = "Marches perdues : 0. Évidemment.",
    ["nobody"] = "personne",
    ["1st"] = "1er",
    -- hub
    ["PLAY"] = "JOUER",
    ["AFK · WATCH"] = "AFK · REGARDER",
    ["NO MINDSET YET"] = "PAS ENCORE D'ÉTAT D'ESPRIT",
    ["NEW CLIMBER"] = "NOUVEAU GRIMPEUR",
    ["TOP 100  ·  BEST GAME"] = "TOP 100  ·  MEILLEURE PARTIE",
    ["TOP 100  ·  TOTAL STEPS"] = "TOP 100  ·  TOTAL DE MARCHES",
    ["the most steps climbed in ONE game"] = "le plus de marches montées en UNE partie",
    ["all the steps ever climbed, every game added up"] = "toutes les marches montées, toutes les parties additionnées",
    ["Spend the aura you farm in game to upgrade your mindset."] = "Dépense l'aura que tu farmes en jeu pour améliorer ton état d'esprit.",
    ['Walk into the <font color="#FFDC50">PORTAL</font> to play  ·  Talk to the <font color="#AA5AFF">AURA MERCHANT</font> to upgrade  ·  Check the <font color="#6EE6A0">TOP 100s</font>']
        = 'Entre dans le <font color="#FFDC50">PORTAIL</font> pour jouer  ·  Parle au <font color="#AA5AFF">MARCHAND D\'AURA</font> pour t\'améliorer  ·  Regarde les <font color="#6EE6A0">TOP 100</font>',
    ["UPGRADE"] = "AMÉLIORER",
    ["MAX LEVEL"] = "NIVEAU MAX",
    ["Already at max level."] = "Déjà au niveau max.",
    ["Already at max level"] = "Déjà au niveau max",
    ["Not enough aura"] = "Pas assez d'aura",
    ["Still loading your data..."] = "Chargement de tes données...",
    ["Wait a second..."] = "Attends une seconde...",
    ["Try again in a second..."] = "Réessaie dans une seconde...",
    ["Unknown skill"] = "Compétence inconnue",
    ["Upgrade"] = "Améliorer",
    ["Aura Merchant"] = "Marchand d'aura",
    ["View"] = "Voir",
    ["Top 100 · Total steps"] = "Top 100 · Total de marches",
    ["Top 100 · Best game"] = "Top 100 · Meilleure partie",
    -- le marchand
    ["Welcome, climber. Your aura is my currency."] = "Bienvenue, grimpeur. Ton aura, c'est ma monnaie.",
    ["A stronger mindset climbs higher stairs."] = "Un mental plus fort monte plus haut.",
    ["Spend aura, earn steps. Simple."] = "Tu dépenses de l'aura, tu gagnes des marches. Simple.",
    ["Every level counts at the top..."] = "Tout en haut, chaque niveau compte...",
    ["Pleasure doing business!"] = "Un plaisir de faire affaire !",
    ["Feel that? That's power."] = "Tu sens ça ? C'est la puissance.",
    ["Your mindset just got stronger."] = "Ton mental vient de devenir plus fort.",
    ["Now go climb!"] = "Maintenant, va grimper !",
    ["Not enough aura... go farm some!"] = "Pas assez d'aura... va en farmer !",
    ["Come back richer, climber."] = "Reviens plus riche, grimpeur.",
    ["Aura first, upgrades after."] = "L'aura d'abord, les améliorations après.",
    ["That one is already maxed out!"] = "Celle-là est déjà au max !",
    ["Can't go higher than that, champ."] = "Impossible d'aller plus haut, champion.",
}

local traduire -- (défini plus bas : les motifs s'en servent pour traduire un morceau de phrase)
local FR_MOTIFS = {
    { "^x(%d+) COMBO$", "COMBO x%1" },
    { "^💀 %-(%d+) STEP$", "💀 -%1 MARCHE" },
    { "^💀 %-(%d+) STEPS$", "💀 -%1 MARCHES" },
    { "^🪜 (%d+) STEPS!$", "🪜 %1 MARCHES !" },
    { "^🪜 (%d+) steps$", "🪜 %1 marches" },
    { "^(%-?%d+) steps$", "%1 marches" },
    { "^You are: (.+)$", "Tu es : %1" },
    { "^%+(%d+) AURA FARMED$", "+%1 AURA FARMÉE" },
    { "^(.+) FARMING AURA$", "%1 FARME L'AURA" },
    { "^EGO broke (.+)'s combo%.$", "L'EGO a cassé le combo de %1." },
    { "^TIE! (.+) — (%d+) steps$", "ÉGALITÉ ! %1 — %2 marches" },
    { "^👑 (.+) WINS with (.+) — (%d+) steps!$", "👑 %1 GAGNE avec %2 — %3 marches !" },
    { "^YOUR RECORD: (%d+) steps$", "TON RECORD : %1 marches" },
    { "^RECORD: (.+)$", function(reste)
        return "RECORD : " .. traduire(reste)
    end },
    { "^AFK MODE  ·  watching: (.+)$", function(nom)
        return "MODE AFK  ·  tu regardes : " .. string.gsub(nom, " %(leading%)$", " (en tête)")
    end },
    { "^Combo max x(%d+)%. He'll tell everyone%.$", "Combo max x%1. Il va le dire à tout le monde." },
    { "^(%d+)[snrt][tdh]$", "%1e" }, -- 2nd, 3rd, 4th... → 2e, 3e, 4e
    { "^TIED  •  OUT OF (%d+)$", "ÉGALITÉ  •  SUR %1" },
    { "^OUT OF (%d+)$", "SUR %1" },
    { "^(.+)  ·  all songs %(also pick a song%)$", "%1  ·  toutes les musiques (choisis aussi une musique)" },
    { "^(.+)  ·  all mindsets %(also pick a mindset%)$", "%1  ·  tous les états d'esprit (choisis aussi un état d'esprit)" },
    -- hub
    { "^YOUR BEST: —  %(go climb!%)$", "TON RECORD : —  (va grimper !)" },
    { "^YOUR TOTAL: —  %(go climb!%)$", "TON TOTAL : —  (va grimper !)" },
    { "^YOUR BEST: (%d+) steps  ·  RANK #(%d+)$", "TON RECORD : %1 marches  ·  RANG #%2" },
    { "^YOUR TOTAL: (%d+) steps  ·  RANK #(%d+)$", "TON TOTAL : %1 marches  ·  RANG #%2" },
    { "^YOUR BEST: (%d+) steps  ·  not in the top 100 yet$", "TON RECORD : %1 marches  ·  pas encore dans le top 100" },
    { "^YOUR TOTAL: (%d+) steps  ·  not in the top 100 yet$", "TON TOTAL : %1 marches  ·  pas encore dans le top 100" },
    { "^BEST: (%d+) STEPS$", "RECORD : %1 MARCHES" },
    { "^(.-)  ·  LV (.+)$", function(debut, niveau)
        return traduire(debut) .. "  ·  NIV " .. niveau
    end },
    { "^NOW: locked$", "ACTUEL : verrouillé" },
    { "^NOW: (.+)$", function(effet)
        return "ACTUEL : " .. traduire(effet)
    end },
    { "^NEXT: (.+)$", function(effet)
        return "SUIVANT : " .. traduire(effet)
    end },
    { "^LEVEL UP!  (.+) is now level (%d+)$", "NIVEAU SUPÉRIEUR !  %1 passe niveau %2" },
    { "^Not enough aura: you need (%d+) more%. Play to farm some!$", "Pas assez d'aura : il t'en manque %1. Joue pour en farmer !" },
    -- les compétences (textes du serveur)
    { "^Start every round (%d+) steps up$", "Commence chaque course %1 marches plus haut" },
    { "^%+(%d+)%% speed in the first 30%% of the round$", "+%1 %% de vitesse pendant les premiers 30 %% de la course" },
    { "^A (%d+)%-second speed boost at mid%-round$", "Un boost de vitesse de %1 s au milieu de la course" },
    { "^%+(%d+)%% jump height$", "+%1 %% de hauteur de saut" },
    { "^%+(%d+)%% speed while you're 1st$", "+%1 %% de vitesse quand tu es 1er" },
    { "^Your first (%d+) falls cost half$", "Tes %1 premières chutes coûtent moitié moins" },
    { "^A checkpoint every (%d+) steps$", "Un checkpoint toutes les %1 marches" },
    { "^%+(%d+)%% speed, all round long$", "+%1 %% de vitesse, toute la course" },
    { "^%+(%d+)%% aura earned$", "+%1 %% d'aura gagnée" },
    { "^%+(%d+) top speed at the end$", "+%1 de vitesse max à la fin" },
    { "^(%d+)%% chance boulders don't knock you$", "%1 %% de chance que les rochers ne te renversent pas" },
    { "^%+30%% speed in the last (%d+) seconds$", "+30 %% de vitesse dans les %1 dernières secondes" },
    -- le nouveau jeu (escalier 3D)
    { "^EGO made (.+) fall%.$", "L'EGO a fait tomber %1." },
    { "^Fell (%d+) times?%. Still the main character%.$", "Tombé %1 fois. Toujours le personnage principal." },
}

local actuelle = "en"
traduire = function(s)
    if actuelle ~= "fr" or type(s) ~= "string" or s == "" then
        return s
    end
    local exact = FR_EXACT[s]
    if exact then
        return exact
    end
    for _, motif in ipairs(FR_MOTIFS) do
        if string.find(s, motif[1]) then
            return (string.gsub(s, motif[1], motif[2], 1))
        end
    end
    return s
end

-- on suit chaque texte : quand un script le change, on le retraduit
local suivis = setmetatable({}, { __mode = "k" })   -- [objet] = { [propriété] = { orig = anglais, mis = affiché } }
local connectes = setmetatable({}, { __mode = "k" })
local PROPS_TEXTE = { "Text" }
local PROPS_BOUTON_E = { "ActionText", "ObjectText" }

local function appliquer(objet, prop)
    local infos = suivis[objet]
    if not infos then
        infos = {}
        suivis[objet] = infos
    end
    local actuel = objet[prop]
    local deja = infos[prop]
    if deja and deja.mis == actuel then
        return -- c'est nous qui venons de le mettre
    end
    local t = traduire(actuel)
    infos[prop] = { orig = actuel, mis = t }
    if t ~= actuel then
        objet[prop] = t
    end
end

local function suivre(objet)
    if connectes[objet] then
        return
    end
    local props
    if objet:IsA("TextLabel") or objet:IsA("TextButton") then
        props = PROPS_TEXTE
    elseif objet:IsA("ProximityPrompt") then
        props = PROPS_BOUTON_E
    else
        return
    end
    connectes[objet] = true
    for _, prop in ipairs(props) do
        appliquer(objet, prop)
        objet:GetPropertyChangedSignal(prop):Connect(function()
            appliquer(objet, prop)
        end)
    end
end

-- "auto" = la langue de Roblox du joueur (français si elle commence par « fr », sinon anglais)
local function langueVoulue(code)
    if code == "en" or code == "fr" then
        return code
    end
    local locale = ""
    pcall(function()
        locale = LocalizationService.RobloxLocaleId
    end)
    if locale == "" then
        locale = joueur.LocaleId or ""
    end
    return if string.sub(string.lower(locale), 1, 2) == "fr" then "fr" else "en"
end

Langue.traduire = traduire
Langue.changer = function(code)
    local voulue = langueVoulue(code)
    if voulue == actuelle then
        return
    end
    actuelle = voulue
    for objet, infos in pairs(suivis) do
        if objet.Parent then
            for prop, e in pairs(infos) do
                local t = traduire(e.orig)
                e.mis = t
                objet[prop] = t
            end
        end
    end
end

actuelle = langueVoulue(REGLAGES.langue)
for _, dossier in ipairs({ joueur:WaitForChild("PlayerGui"), workspace }) do
    dossier.DescendantAdded:Connect(suivre)
    task.defer(function()
        for _, objet in ipairs(dossier:GetDescendants()) do
            suivre(objet)
        end
    end)
end
end -- fin du bloc de la langue



-- ========================== PHASES ==========================
local menuPrincipalOuvert = true -- au lancement : le hub (script MindsetHub)
local modeAfk = false -- AFK : on regarde les autres jouer depuis la tribune
local boutonsCoin = {} -- les petits boutons du lobby (PARAMÈTRES, AFK, MENU), créés plus bas
local majBandeauAfk -- (défini plus bas)
local function majPhase()
    local phase = ReplicatedStorage:GetAttribute("Phase")
    local enMenu = menuPrincipalOuvert -- tant qu'on n'a pas passé le portail, on est dans le hub
    if phase == "Lobby" and not enMenu and not modeAfk then
        ouvrirMenu()
    else
        fermerMenu()
    end
    statut.Visible = (phase ~= "Lobby" or modeAfk) and not enMenu -- le menu a son propre titre et son chrono
    chrono.afficher((phase ~= "Lobby" or modeAfk) and not enMenu)
    barre.Visible = phase == "Manche" and not enMenu
    local enCourse = phase == "Manche" and not enMenu and jeCours()
    marcheTexte.Visible = enCourse
    rangTexte.Visible = enCourse
    vitesseTexte.Visible = enCourse
    -- la liste des joueurs de Roblox (en haut à droite) : seulement dans le hub
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, enMenu)
    end)
    for _, bouton in ipairs(boutonsCoin) do
        bouton.Visible = phase ~= "Manche" and not enMenu -- pas pendant la course
    end
    if majBandeauAfk then
        majBandeauAfk()
    end
    if phase == "Lobby" then
        partition = nil
        sceneActive = false
        arreterDanseUI()
        modeCinema(false)
        modeAura = false
        tween(effetAura, 0.5, { Saturation = 0, Contrast = 0, Brightness = 0 })
        couperMusique(1)
    elseif phase == "Fin" then
        couperMusique(4)
    end
end
ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(majPhase)
task.spawn(function()
    while not monEtat do
        task.wait(0.2)
    end
    monEtat.config:GetAttributeChangedSignal("EnJeu"):Connect(majPhase)
    majPhase()
end)
majPhase()

-- ========================== MENU PRINCIPAL + PARAMÈTRES ==========================
-- Au lancement, on n'est pas jeté direct dans la partie : le MENU 3D (script MindsetHub) avec le marchand,
-- le portail PLAY et le classement. Ici : le lien avec lui, le mode AFK et les PARAMÈTRES.
-- PARAMÈTRES : volume de la musique, volume des bruitages, secousses de l'écran, flashs (sauvegardés).
do
local HttpService = game:GetService("HttpService")
local JouerEvent = remotes:WaitForChild("Jouer")
local ReglagesEvent = remotes:WaitForChild("Reglages")

-- ---------- Le lien avec le MENU 3D (script MindsetHub, à côté de celui-ci) ----------
-- Le menu principal est maintenant une scène 3D (marchand, portail PLAY, classement) : c'est le script
-- « MindsetHub » qui la gère. Les deux scripts se parlent avec ces 2 BindableEvent :
--   VersJeu (hub → ici) : "Jouer", "Afk", "Classements", "Reglages"
--   VersHub (ici → hub) : "Ouvrir" (retour au menu 3D)
local liens = nouveau("Folder", { Name = "MindsetLiens" })
local versJeu = nouveau("BindableEvent", { Name = "VersJeu", Parent = liens })
local versHub = nouveau("BindableEvent", { Name = "VersHub", Parent = liens })
-- le hub s'en sert pour traduire une phrase avant de l'écrire lettre par lettre (le marchand)
nouveau("BindableFunction", { Name = "Traduire", Parent = liens }).OnInvoke = function(phrase)
    return Langue.traduire(phrase)
end
liens.Parent = joueur
local COULEUR_AFK = Color3.fromRGB(140, 200, 255)

-- ---------- Le bandeau AFK (en bas) : tu regardes les autres, bouton pour revenir ----------
local bandeauAfk = nouveau("Frame", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -20),
    Size = UDim2.fromOffset(560, 58),
    BackgroundColor3 = Color3.fromRGB(12, 14, 24),
    BackgroundTransparency = 0.1,
    Visible = false,
    ZIndex = 24,
    Parent = gui,
})
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bandeauAfk })
nouveau("UIStroke", { Color = COULEUR_AFK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = bandeauAfk })
local texteAfk = texte({
    Position = UDim2.new(0, 26, 0, 12),
    Size = UDim2.new(1, -230, 1, -24),
    Text = "AFK MODE  ·  watching the others play",
    Font = Enum.Font.GothamBold,
    TextColor3 = COULEUR_AFK,
    TextStrokeTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 25,
    Parent = bandeauAfk,
})
local boutonRejoindre = nouveau("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -10, 0.5, 0),
    Size = UDim2.fromOffset(190, 40),
    BackgroundColor3 = OR,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBlack,
    Text = "JOIN",
    TextScaled = true,
    TextColor3 = NOIR,
    ZIndex = 25,
    Parent = bandeauAfk,
})
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = boutonRejoindre })
nouveau("UIPadding", { PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9), Parent = boutonRejoindre })
boutonRejoindre.MouseEnter:Connect(function()
    sonSurvol(5)
end)
-- regarde = le nom de celui que la caméra suit (pendant une manche)
majBandeauAfk = function(regarde)
    bandeauAfk.Visible = modeAfk and not menuPrincipalOuvert
    local phase = ReplicatedStorage:GetAttribute("Phase")
    if phase == "Manche" and regarde then
        texteAfk.Text = "AFK MODE  ·  watching: " .. regarde
    elseif phase == "Manche" then
        texteAfk.Text = "AFK MODE  ·  watching the others play"
    else
        texteAfk.Text = "AFK MODE  ·  you won't be put in the next game"
    end
end

-- ---------- Passer d'un mode à l'autre ----------
-- PLAY / REJOINDRE : on participe aux prochaines manches
-- (depuisHub = on arrive du menu 3D : le hub a déjà fait sa transition, pas de flash en plus)
local function allerJouer(depuisHub)
    if not depuisHub then
        sonClic(1)
        flasher(BLANC, 0.4)
    end
    menuPrincipalOuvert = false
    modeAfk = false
    JouerEvent:FireServer(true)
    majPhase() -- on arrive dans le lobby (ou en spectateur si une manche est en cours)
    if ReplicatedStorage:GetAttribute("Phase") ~= "Lobby" then
        grosTexte.TextColor3 = OR
        apparaitre(grosTexte, "A round is in progress: you'll play the next one!", 3, echelleGros)
    end
end

-- AFK : on regarde les autres, on n'est pas lancé dans la partie
local function passerAfk(raison)
    menuPrincipalOuvert = false
    modeAfk = true
    JouerEvent:FireServer(false)
    majPhase()
    if raison then
        grosTexte.TextColor3 = COULEUR_AFK
        apparaitre(grosTexte, raison, 3, echelleGros)
    end
end

-- le menu 3D est revenu à l'écran (après sa transition) : on cache tout ce qui est du jeu
local function menuEstOuvert()
    menuPrincipalOuvert = true
    modeAfk = false
    majPhase()
end

-- MENU : retour au menu 3D (on n'est plus lancé dans la partie non plus)
local function retourMenu()
    sonClic(2)
    JouerEvent:FireServer(false)
    if liens:GetAttribute("HubPret") then
        versHub:Fire("Ouvrir") -- le hub fait sa transition, puis nous renvoie « MenuOuvert »
    else
        menuEstOuvert()
    end
end

boutonRejoindre.Activated:Connect(function()
    if modeAfk then
        allerJouer(false)
    end
end)

-- AFK tout seul : si tu ne touches plus à rien pendant 2 minutes (Roblox nous prévient),
-- ou si tu as laissé passer toute une manche sans cliquer une seule fois.
joueur.Idled:Connect(function()
    if not modeAfk and not menuPrincipalOuvert then
        passerAfk("Are you away? AFK MODE on")
    end
end)
local jouaitCetteManche = false
ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(function()
    local phase = ReplicatedStorage:GetAttribute("Phase")
    if phase == "Manche" then
        jouaitCetteManche = monEtat ~= nil and monEtat.config:GetAttribute("EnJeu") == true
    elseif phase == "Fin" and jouaitCetteManche then
        jouaitCetteManche = false
        if monEtat and (monEtat.config:GetAttribute("Marche") or 0) < 3 and not modeAfk and not menuPrincipalOuvert then
            passerAfk("Didn't move the whole round: AFK MODE on")
        end
    end
end)

-- ---------- Le panneau des paramètres ----------
local fondReglages = nouveau("TextButton", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = NOIR,
    BackgroundTransparency = 1,
    AutoButtonColor = false,
    Text = "",
    Visible = false,
    ZIndex = 45,
    Parent = gui,
})
local cadre = nouveau("TextButton", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(480, 440),
    BackgroundColor3 = Color3.fromRGB(12, 12, 18),
    AutoButtonColor = false,
    Text = "",
    ZIndex = 46,
    Parent = fondReglages,
})
nouveau("UICorner", { CornerRadius = UDim.new(0, 18), Parent = cadre })
nouveau("UIStroke", { Color = Color3.fromRGB(200, 200, 220), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = cadre })
local echelleCadre = nouveau("UIScale", { Parent = cadre })
texte({ Position = UDim2.new(0, 24, 0, 18), Size = UDim2.new(1, -170, 0, 36), Text = "SETTINGS", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 47, Parent = cadre })
local boutonFermerReglages = nouveau("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -18, 0, 20),
    Size = UDim2.fromOffset(110, 34),
    BackgroundColor3 = Color3.fromRGB(40, 40, 55),
    AutoButtonColor = false,
    Font = Enum.Font.GothamBlack,
    Text = "CLOSE",
    TextScaled = true,
    TextColor3 = BLANC,
    ZIndex = 47,
    Parent = cadre,
})
nouveau("UICorner", { CornerRadius = UDim.new(0, 10), Parent = boutonFermerReglages })
nouveau("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = boutonFermerReglages })

local function appliquerReglages()
    groupeMusique.Volume = REGLAGES.musique
    groupeBruitages.Volume = REGLAGES.bruitages
    Langue.changer(REGLAGES.langue)
end

-- envoi au serveur (pas à chaque pixel du curseur : une fois qu'on a fini de régler)
local envoiPrevu = false
local function sauverReglages()
    if envoiPrevu then
        return
    end
    envoiPrevu = true
    task.delay(0.6, function()
        envoiPrevu = false
        ReglagesEvent:FireServer(REGLAGES)
    end)
end

local majAffichage = {} -- fonctions qui remettent les curseurs / interrupteurs à jour

-- un curseur de volume (0 à 100 %)
local function curseur(y, titreCurseur, cle)
    texte({
        Position = UDim2.new(0, 24, 0, y),
        Size = UDim2.new(0.6, 0, 0, 20),
        Text = titreCurseur,
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(200, 200, 215),
        TextStrokeTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 47,
        Parent = cadre,
    })
    local valeurTexte = texte({
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -24, 0, y),
        Size = UDim2.new(0, 80, 0, 20),
        Font = Enum.Font.GothamBlack,
        TextColor3 = OR,
        TextStrokeTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 47,
        Parent = cadre,
    })
    local rail = nouveau("TextButton", {
        Position = UDim2.new(0, 24, 0, y + 30),
        Size = UDim2.new(1, -48, 0, 10),
        BackgroundColor3 = Color3.fromRGB(45, 45, 60),
        AutoButtonColor = false,
        Text = "",
        ZIndex = 47,
        Parent = cadre,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rail })
    local rempli = nouveau("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = OR, BorderSizePixel = 0, ZIndex = 48, Parent = rail })
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rempli })
    local poignee = nouveau("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(24, 24),
        BackgroundColor3 = BLANC,
        ZIndex = 49,
        Parent = rail,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = poignee })
    nouveau("UIStroke", { Color = OR, Thickness = 2, Parent = poignee })
    local function afficher()
        local v = REGLAGES[cle]
        rempli.Size = UDim2.fromScale(v, 1)
        poignee.Position = UDim2.fromScale(v, 0.5)
        valeurTexte.Text = math.floor(v * 100 + 0.5) .. " %"
    end
    table.insert(majAffichage, afficher)
    local glisse = false
    local function regler(x)
        REGLAGES[cle] = math.clamp((x - rail.AbsolutePosition.X) / rail.AbsoluteSize.X, 0, 1)
        appliquerReglages()
        afficher()
    end
    rail.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            glisse = true
            regler(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if glisse and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            regler(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if glisse and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            glisse = false
            sonClic(3) -- pour entendre le volume des bruitages
            sauverReglages()
        end
    end)
    afficher()
end

-- un interrupteur OUI / NON
local function interrupteur(y, titreInter, cle)
    texte({
        Position = UDim2.new(0, 24, 0, y + 6),
        Size = UDim2.new(0.6, 0, 0, 20),
        Text = titreInter,
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(200, 200, 215),
        TextStrokeTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 47,
        Parent = cadre,
    })
    local bouton = nouveau("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -24, 0, y),
        Size = UDim2.fromOffset(90, 32),
        AutoButtonColor = false,
        Font = Enum.Font.GothamBlack,
        TextScaled = true,
        ZIndex = 47,
        Parent = cadre,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bouton })
    nouveau("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), Parent = bouton })
    local function afficher()
        local actif = REGLAGES[cle]
        bouton.Text = if actif then "ON" else "OFF"
        bouton.BackgroundColor3 = if actif then OR else Color3.fromRGB(45, 45, 60)
        bouton.TextColor3 = if actif then NOIR else Color3.fromRGB(170, 170, 190)
    end
    table.insert(majAffichage, afficher)
    bouton.MouseEnter:Connect(function()
        sonSurvol(4)
    end)
    bouton.Activated:Connect(function()
        REGLAGES[cle] = not REGLAGES[cle]
        afficher()
        sonClic(if REGLAGES[cle] then 5 else 2)
        if cle == "secousses" and REGLAGES.secousses then
            secousse(1) -- petit aperçu
        elseif cle == "flashs" and REGLAGES.flashs then
            flasher(BLANC, 0.3)
        end
        sauverReglages()
    end)
    afficher()
end

curseur(76, "MUSIC", "musique")
curseur(146, "SOUND EFFECTS (clicks, menu sounds, effects)", "bruitages")
interrupteur(222, "SCREEN SHAKE", "secousses")
interrupteur(272, "FLASHING LIGHTS", "flashs")

-- LANGUE : AUTO (celle de Roblox) / EN / FR — tout le jeu change tout de suite
do
    texte({
        Position = UDim2.new(0, 24, 0, 328),
        Size = UDim2.new(0.4, 0, 0, 20),
        Text = "LANGUAGE",
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(200, 200, 215),
        TextStrokeTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 47,
        Parent = cadre,
    })
    local CHOIX = { { "auto", "AUTO" }, { "en", "EN" }, { "fr", "FR" } }
    local boutonsLangue = {}
    local function afficher()
        for code, bouton in pairs(boutonsLangue) do
            local actif = REGLAGES.langue == code
            bouton.BackgroundColor3 = if actif then OR else Color3.fromRGB(45, 45, 60)
            bouton.TextColor3 = if actif then NOIR else Color3.fromRGB(170, 170, 190)
        end
    end
    for i, choix in ipairs(CHOIX) do
        local bouton = nouveau("TextButton", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -24 - (#CHOIX - i) * 76, 0, 322),
            Size = UDim2.fromOffset(68, 32),
            AutoButtonColor = false,
            Font = Enum.Font.GothamBlack,
            Text = choix[2],
            TextScaled = true,
            ZIndex = 47,
            Parent = cadre,
        })
        nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bouton })
        nouveau("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), Parent = bouton })
        boutonsLangue[choix[1]] = bouton
        bouton.MouseEnter:Connect(function()
            sonSurvol(4)
        end)
        bouton.Activated:Connect(function()
            REGLAGES.langue = choix[1]
            Langue.changer(choix[1])
            afficher()
            sonClic(4 + i)
            sauverReglages()
        end)
    end
    table.insert(majAffichage, afficher)
    afficher()
end
texte({
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -18),
    Size = UDim2.new(1, -48, 0, 18),
    Text = "Your settings are saved for next time.",
    Font = Enum.Font.GothamMedium,
    TextColor3 = Color3.fromRGB(140, 140, 160),
    TextStrokeTransparency = 1,
    ZIndex = 47,
    Parent = cadre,
})

local function ouvrirReglages()
    fondReglages.Visible = true
    fondReglages.BackgroundTransparency = 1
    tween(fondReglages, 0.3, { BackgroundTransparency = 0.45 })
    echelleCadre.Scale = 0.75
    tween(echelleCadre, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
end
local function fermerReglages()
    tween(fondReglages, 0.2, { BackgroundTransparency = 1 })
    tween(echelleCadre, 0.2, { Scale = 0.8 })
    task.delay(0.2, function()
        fondReglages.Visible = false
    end)
    sauverReglages()
end
boutonFermerReglages.Activated:Connect(function()
    sonClic(1)
    fermerReglages()
end)
fondReglages.Activated:Connect(fermerReglages)

-- les petits boutons du lobby, sous CLASSEMENTS : PARAMÈTRES, AFK, MENU (retour à l'écran titre)
local function boutonCoin(y, texteBouton, couleur, action)
    local bouton = nouveau("TextButton", {
        Position = UDim2.new(0, 20, 0, y),
        Size = UDim2.fromOffset(200, 40),
        BackgroundColor3 = Color3.fromRGB(14, 14, 22),
        BackgroundTransparency = 0.1,
        AutoButtonColor = false,
        Font = Enum.Font.GothamBlack,
        Text = texteBouton,
        TextScaled = true,
        TextColor3 = couleur,
        Visible = false,
        ZIndex = 25,
        Parent = gui,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 12), Parent = bouton })
    nouveau("UIStroke", { Color = couleur, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = bouton })
    nouveau("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), Parent = bouton })
    local echelle = nouveau("UIScale", { Parent = bouton })
    bouton.MouseEnter:Connect(function()
        sonSurvol(4)
        tween(echelle, 0.2, { Scale = 1.06 }, Enum.EasingStyle.Back)
    end)
    bouton.MouseLeave:Connect(function()
        tween(echelle, 0.2, { Scale = 1 })
    end)
    bouton.Activated:Connect(action)
    table.insert(boutonsCoin, bouton)
    return bouton
end
boutonCoin(70, "SETTINGS", Color3.fromRGB(200, 200, 220), function()
    sonClic(4)
    ouvrirReglages()
end)
boutonCoin(118, "AFK", COULEUR_AFK, function()
    if modeAfk then
        allerJouer(false)
    else
        sonClic(3)
        passerAfk(nil)
    end
end)
boutonCoin(166, "MENU", Color3.fromRGB(255, 120, 120), retourMenu)

-- les paramètres sauvegardés (le serveur les met dans l'attribut « Reglages » du joueur)
local function chargerReglages()
    local brut = joueur:GetAttribute("Reglages")
    if type(brut) ~= "string" then
        return
    end
    local ok, donnees = pcall(function()
        return HttpService:JSONDecode(brut)
    end)
    if not ok or type(donnees) ~= "table" then
        return
    end
    for cle, valeur in pairs(donnees) do
        if REGLAGES[cle] ~= nil and type(valeur) == type(REGLAGES[cle]) then
            REGLAGES[cle] = valeur
        end
    end
    appliquerReglages()
    for _, f in ipairs(majAffichage) do
        f()
    end
end
joueur:GetAttributeChangedSignal("Reglages"):Connect(chargerReglages)
chargerReglages()

-- ce que demande le menu 3D (script MindsetHub)
versJeu.Event:Connect(function(action)
    if action == "Jouer" then
        allerJouer(true)
    elseif action == "Afk" then
        passerAfk(nil)
    elseif action == "Classements" then
        -- (plus de panneau des classements : ils sont sur les tableaux du hub)
    elseif action == "Reglages" then
        ouvrirReglages()
    elseif action == "MenuOuvert" then
        menuEstOuvert()
    end
end)
-- secours : si le script MindsetHub n'est pas dans le jeu, on ne reste pas bloqué sur un écran vide
task.delay(15, function()
    if not liens:GetAttribute("HubPret") and menuPrincipalOuvert then
        warn("[Mindset] Le script MindsetHub (menu 3D) est introuvable : mets-le dans StarterPlayerScripts. On lance le jeu sans menu.")
        allerJouer(true)
    end
end)
majPhase()
end -- fin du bloc du menu principal

local function majStatut()
    statut.Text = ReplicatedStorage:GetAttribute("Statut") or ""
end
ReplicatedStorage:GetAttributeChangedSignal("Statut"):Connect(majStatut)
majStatut()
chrono.maj(ReplicatedStorage:GetAttribute("Temps") or 0)
chronoMenu.maj(ReplicatedStorage:GetAttribute("Temps") or 0)


-- ========================== ÉCRAN DE FIN ==========================
-- Une carte propre : bandeau avec ton état d'esprit et ta place, 4 cases de stats,
-- ton record et l'aura farmée, puis le gagnant.
do
local GRIS = Color3.fromRGB(150, 150, 170)
local FOND_CASE = Color3.fromRGB(24, 24, 34)

local ecranFin = nouveau("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.52),
    Size = UDim2.fromOffset(540, 390),
    BackgroundColor3 = Color3.fromRGB(12, 12, 18),
    Visible = false,
    ZIndex = 30,
    Parent = gui,
})
nouveau("UICorner", { CornerRadius = UDim.new(0, 20), Parent = ecranFin })
local contourFin = nouveau("UIStroke", { Thickness = 3, Color = OR, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ecranFin })
local echelleFin = nouveau("UIScale", { Parent = ecranFin })
-- petit écran (mobile) : la carte rétrécit pour tenir
nouveau("UIAspectRatioConstraint", { AspectRatio = 540 / 390, Parent = ecranFin })
nouveau("UISizeConstraint", { MaxSize = Vector2.new(540, 390), Parent = ecranFin })
ecranFin.Size = UDim2.new(0.9, 0, 0.8, 0)

-- le bandeau du haut, aux couleurs de ton état d'esprit
local bandeau = nouveau("Frame", {
    Size = UDim2.new(1, 0, 0.22, 0),
    BackgroundColor3 = BLANC,
    BorderSizePixel = 0,
    ZIndex = 31,
    Parent = ecranFin,
})
nouveau("UICorner", { CornerRadius = UDim.new(0, 20), Parent = bandeau })
local degradeBandeau = nouveau("UIGradient", { Parent = bandeau })
local function petitTexte(proprietes)
    proprietes.Font = proprietes.Font or Enum.Font.GothamBold
    proprietes.TextColor3 = proprietes.TextColor3 or GRIS
    proprietes.TextStrokeTransparency = 1
    proprietes.ZIndex = proprietes.ZIndex or 33
    return texte(proprietes)
end
petitTexte({ Position = UDim2.fromScale(0.05, 0.16), Size = UDim2.fromScale(0.5, 0.2), Text = "GAME OVER", TextColor3 = Color3.fromRGB(230, 230, 240), TextXAlignment = Enum.TextXAlignment.Left, Parent = bandeau })
local finPerso = texte({ Position = UDim2.fromScale(0.05, 0.38), Size = UDim2.fromScale(0.6, 0.48), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 33, Parent = bandeau })
local finPlace = texte({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.95, 0.1), Size = UDim2.fromScale(0.3, 0.55), TextColor3 = OR, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 33, Parent = bandeau })
local finSur = petitTexte({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.95, 0.66), Size = UDim2.fromScale(0.3, 0.22), TextColor3 = Color3.fromRGB(230, 230, 240), TextXAlignment = Enum.TextXAlignment.Right, Parent = bandeau })

-- les 4 cases de stats
local cases = {}
local NOMS_CASES = { "STEPS", "HIGHEST", "FALLS", "BOULDERS" }
for i, nom in ipairs(NOMS_CASES) do
    local case = nouveau("Frame", {
        Position = UDim2.new(0.04 + (i - 1) * 0.235, 0, 0.27, 0),
        Size = UDim2.fromScale(0.215, 0.24),
        BackgroundColor3 = FOND_CASE,
        ZIndex = 31,
        Parent = ecranFin,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 12), Parent = case })
    local valeur = texte({ Position = UDim2.fromScale(0.06, 0.12), Size = UDim2.fromScale(0.88, 0.5), Font = Enum.Font.GothamBlack, TextStrokeTransparency = 1, ZIndex = 32, Parent = case })
    petitTexte({ Position = UDim2.fromScale(0.06, 0.68), Size = UDim2.fromScale(0.88, 0.18), Text = nom, ZIndex = 32, Parent = case })
    cases[i] = { case = case, valeur = valeur, echelle = nouveau("UIScale", { Parent = case }) }
end

-- record + aura farmée
local function ligneInfo(x, titre)
    local cadre = nouveau("Frame", {
        Position = UDim2.fromScale(x, 0.56),
        Size = UDim2.fromScale(0.45, 0.15),
        BackgroundColor3 = FOND_CASE,
        ZIndex = 31,
        Parent = ecranFin,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 12), Parent = cadre })
    petitTexte({ Position = UDim2.fromScale(0.07, 0.12), Size = UDim2.fromScale(0.86, 0.3), Text = titre, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32, Parent = cadre })
    local valeur = texte({ Position = UDim2.fromScale(0.07, 0.45), Size = UDim2.fromScale(0.6, 0.42), Font = Enum.Font.GothamBlack, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32, Parent = cadre })
    return cadre, valeur
end
local _, finRecord = ligneInfo(0.04, "YOUR RECORD")
local _, finAura = ligneInfo(0.51, "AURA EARNED")
finAura.TextColor3 = OR
local badgeRecord = petitTexte({
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.fromScale(0.47, 0.635),
    Size = UDim2.fromScale(0.2, 0.06),
    Text = "NEW!",
    Font = Enum.Font.GothamBlack,
    TextColor3 = NOIR,
    BackgroundTransparency = 0,
    BackgroundColor3 = OR,
    ZIndex = 34,
    Visible = false,
    Parent = ecranFin,
})
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badgeRecord })
nouveau("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3), Parent = badgeRecord })

-- le gagnant + la petite phrase
nouveau("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.76),
    Size = UDim2.new(0.92, 0, 0, 1),
    BackgroundColor3 = Color3.fromRGB(50, 50, 66),
    BorderSizePixel = 0,
    ZIndex = 31,
    Parent = ecranFin,
})
petitTexte({ Position = UDim2.fromScale(0.04, 0.79), Size = UDim2.fromScale(0.25, 0.06), Text = "WINNER", TextXAlignment = Enum.TextXAlignment.Left, Parent = ecranFin })
local finGagnant = texte({ Position = UDim2.fromScale(0.04, 0.85), Size = UDim2.fromScale(0.5, 0.08), TextColor3 = OR, TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 1, ZIndex = 33, Parent = ecranFin })
local finDrole = petitTexte({
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.fromScale(0.96, 0.84),
    Size = UDim2.fromScale(0.42, 0.09),
    Font = Enum.Font.GothamMedium,
    TextXAlignment = Enum.TextXAlignment.Right,
    Parent = ecranFin,
})

local function statDrole(data)
    if data.perso == "Obsession" then
        return "Never looked down."
    elseif data.perso == "Ego" then
        return "Fell " .. tostring(data.chutes or 0) .. (if data.chutes == 1 then " time" else " times") .. ". Still the main character."
    elseif data.perso == "Motivation" then
        return "Fiery start... and then?"
    elseif data.perso == "Discipline" then
        return "Slow and steady. As always."
    end
    return ""
end

-- un nombre qui défile de 0 à sa valeur
local function compter(label, cible, suffixe, duree)
    task.spawn(function()
        local debut = os.clock()
        while os.clock() - debut < duree do
            local k = (os.clock() - debut) / duree
            label.Text = math.floor(cible * (1 - (1 - k) ^ 3)) .. suffixe
            task.wait()
        end
        label.Text = cible .. suffixe
    end)
end

local numeroFin = 0
FinEvent.OnClientEvent:Connect(function(data)
    arreterDanseUI()
    numeroFin += 1
    local numero = numeroFin
    local couleur = COULEURS[data.perso] or BLANC
    contourFin.Color = couleur
    degradeBandeau.Color = ColorSequence.new(couleur:Lerp(NOIR, 0.15), couleur:Lerp(NOIR, 0.75))
    finPerso.Text = string.upper(tostring(data.perso))
    local p = data.place
    local suffixe = if p % 100 >= 11 and p % 100 <= 13 then "th" elseif p % 10 == 1 then "st" elseif p % 10 == 2 then "nd" elseif p % 10 == 3 then "rd" else "th"
    finPlace.Text = p .. suffixe -- 1st, 2nd, 3rd, 4th...
    finSur.Text = (if data.egalite then "TIED  •  " else "") .. "OUT OF " .. data.total
    finRecord.Text = (data.record or 0) .. " steps"
    badgeRecord.Visible = data.nouveauRecord == true
    -- l'aura gagnée pendant la manche (notes + victoire) + celle farmée en dansant → à dépenser chez le marchand
    local auraTotale = (data.auraGagnee or 0) + (data.auraFarmee or 0)
    finAura.Text = if auraTotale > 0 then "+" .. auraTotale else "—"
    finGagnant.Text = tostring(data.gagnant)
    finDrole.Text = statDrole(data)

    ecranFin.Visible = true
    echelleFin.Scale = 0.6
    tween(echelleFin, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
    local valeurs = { { data.marches or 0, "" }, { data.plusHaut or 0, "" }, { data.chutes or 0, "" }, { data.coups or 0, "" } }
    for i, c in ipairs(cases) do
        c.valeur.Text = "0" .. valeurs[i][2]
        c.valeur.TextColor3 = if i == 1 then couleur else BLANC
        c.echelle.Scale = 0
        task.delay(0.15 + i * 0.09, function()
            if numero ~= numeroFin then
                return
            end
            tween(c.echelle, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
            compter(c.valeur, valeurs[i][1], valeurs[i][2], 0.6)
            jouerSon("tic", 1 + i * 0.12, 0.25)
        end)
    end
    if data.nouveauRecord then
        task.delay(0.7, function()
            flasher(OR, 0.4)
            jouerSon("tic", 1, 0.4)
            jouerSon("tic", 1.26, 0.4, 0.08)
            jouerSon("tic", 1.5, 0.4, 0.16)
            jouerSon("tic", 2, 0.4, 0.24)
        end)
    end
    task.delay(6.5, function()
        if numero == numeroFin then
            tween(echelleFin, 0.25, { Scale = 0.8 })
            task.wait(0.25)
            if numero == numeroFin then
                ecranFin.Visible = false
            end
        end
    end)
end)
end -- fin du bloc de l'écran de fin


-- ========================== LA DANSE DU GAGNANT (vraiment badass) ==========================
-- Faite à la main, calée sur le rythme de la musique. 3 mouvements (attribut « Danse », change tous les 10 pas) :
--   1 SIGMA LEAN : bras croisés, penché en arrière, la tête frappe chaque temps
--   2 AURA FLEX  : double biceps, jambes écartées, le buste se tord sur les temps
--   3 POINT & SPIN : il pointe la caméra du doigt, et tous les 4 temps : vrille en sautant
-- Autour de lui : pilier de lumière, flammes, contour lumineux, éclair + onde au sol tous les 4 temps.
-- Chaque clic sur DANCE = un coup d'accent (il frappe plus fort).
local danseBadass
do
local function lisse(k)
    return k * k * (3 - 2 * k)
end

local function piece(proprietes)
    proprietes.Anchored = true
    proprietes.CanCollide = false
    proprietes.CanQuery = false
    proprietes.CanTouch = false
    proprietes.CastShadow = false
    proprietes.Material = Enum.Material.Neon
    proprietes.Parent = workspace
    return nouveau("Part", proprietes)
end

-- la mise en scène autour du danseur (créée une fois, détruite quand la danse s'arrête)
local function miseEnScene(etat)
    local d = etat.danse
    local racine = etat.modele and etat.modele:FindFirstChild("HumanoidRootPart")
    if d.pilier or not racine then
        return
    end
    local couleur = couleurDe(etat)
    d.pilier = piece({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(60, 4, 4), Color = couleur, Transparency = 0.8 })
    d.lumiere = nouveau("PointLight", { Color = couleur, Brightness = 4, Range = 24, Parent = racine })
    d.contour = nouveau("Highlight", {
        FillColor = couleur,
        FillTransparency = 0.8,
        OutlineColor = BLANC,
        OutlineTransparency = 0,
        DepthMode = Enum.HighlightDepthMode.Occluded,
        Parent = etat.modele,
    })
    local flammes = nouveau("ParticleEmitter", {
        Rate = 60,
        Lifetime = NumberRange.new(0.6, 1.2),
        Speed = NumberRange.new(8, 16),
        SpreadAngle = Vector2.new(12, 12),
        EmissionDirection = Enum.NormalId.Top,
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) }),
        Transparency = NumberSequence.new(0.1, 1),
        LightEmission = 1,
        Color = ColorSequence.new(couleur, BLANC),
        Parent = racine,
    })
    for _, effet in ipairs({ d.pilier, d.lumiere, d.contour, flammes }) do
        table.insert(d.effets, effet)
    end
end

-- un éclair (zigzag de néon) qui tombe du ciel à côté du danseur
local function eclair(sol, couleur)
    if not REGLAGES.flashs then
        return
    end
    local haut = sol + Vector3.new((math.random() - 0.5) * 8, 45, -3)
    local precedent = haut
    for i = 1, 7 do
        local suivant = haut:Lerp(sol, i / 7) + (if i < 7 then Vector3.new((math.random() - 0.5) * 5, 0, 0) else Vector3.zero)
        local morceau = piece({
            Color = couleur:Lerp(BLANC, 0.65),
            Size = Vector3.new(0.4, 0.4, (suivant - precedent).Magnitude),
            CFrame = CFrame.lookAt((precedent + suivant) / 2, suivant),
        })
        tween(morceau, 0.3, { Transparency = 1 })
        task.delay(0.35, function()
            morceau:Destroy()
        end)
        precedent = suivant
    end
end

-- renvoie la pose (articulations), la rotation et la hauteur du danseur pour cette image
danseBadass = function(etat, horloge)
    local d = etat.danse
    miseEnScene(etat)
    local origine = if partition then partition.debut else 0
    local b = (maintenantServeur() - origine) / math.max(intervalle, 0.2) -- le temps qui passe, en battements
    local temps = math.floor(b)
    local f = b - temps -- où on en est dans le battement (0 → 1)
    local hit = (1 - f) ^ 3 -- 1 pile sur le temps, puis retombe vite
    local coup = if d.coup then math.max(0, 1 - (horloge - d.coup) / 0.22) else 0
    local entree = math.clamp((horloge - (d.changement or d.debut)) / 0.25, 0, 1)
    local racine = etat.modele:FindFirstChild("HumanoidRootPart")
    local couleur = couleurDe(etat)

    -- chaque temps : petit zoom + contraste ; tous les 4 temps : éclair, onde au sol, secousse, flash
    if temps ~= d.dernierTemps and racine then
        d.dernierTemps = temps
        local sol = racine.Position - Vector3.new(0, etat.hauteur or 3, 0)
        if temps % 4 == 0 then
            ondeSol(sol, couleur, 10)
            eclats(sol + Vector3.new(0, 1, 0), couleur, 16, 1.3)
            eclair(sol, couleur)
            secousse(0.9)
            fovPulse = math.min(fovPulse, -4)
            if REGLAGES.flashs then
                effetPulse.Brightness = 0.25
                tween(effetPulse, 0.3, { Brightness = 0 })
            end
        else
            fovPulse = math.min(fovPulse, -1.5)
            effetPulse.Contrast = 0.35
            tween(effetPulse, intervalle * 0.8, { Contrast = 0 })
        end
    end
    if d.pilier and racine then
        local epaisseur = 4 + 2.5 * hit + 2 * coup
        d.pilier.Size = Vector3.new(60, epaisseur, epaisseur)
        d.pilier.CFrame = CFrame.new(racine.Position + Vector3.new(0, 26, -3)) * CFrame.Angles(0, 0, math.pi / 2)
        d.pilier.Transparency = 0.82 - 0.25 * hit
        d.lumiere.Brightness = 3 + 5 * hit + 4 * coup
        d.contour.FillTransparency = 0.85 - 0.4 * math.max(hit, coup)
    end

    local pose, rotation, arc
    local rebond = 0.35 * hit + 0.4 * coup -- les genoux plient sur le temps
    local mouvement = d.mouvement or 1
    if mouvement == 1 then
        -- SIGMA LEAN
        local balance = math.sin(b * math.pi / 2)
        pose = {
            LeftShoulder = Vector3.new(1.35, 0, 0.55),
            RightShoulder = Vector3.new(1.35, 0, -0.55),
            LeftElbow = Vector3.new(1.75, 0, 0),
            RightElbow = Vector3.new(1.75, 0, 0),
            Waist = Vector3.new(0.14 - 0.1 * hit, 0.25 * balance, 0),
            Neck = Vector3.new(0.18 - 0.45 * hit - 0.3 * coup, 0, 0.12 * balance),
            LeftKnee = -rebond, RightKnee = -rebond, LeftHip = 0.4 * rebond, RightHip = 0.4 * rebond,
        }
        rotation = CFrame.Angles(0, 0.35 * balance, 0)
        arc = -0.35 * rebond
    elseif mouvement == 2 then
        -- AURA FLEX
        local cote = if temps % 2 == 0 then 1 else -1
        local flex = 0.25 * hit + 0.3 * coup
        pose = {
            LeftShoulder = Vector3.new(0, 0, -(1.45 + flex)),
            RightShoulder = Vector3.new(0, 0, 1.45 + flex),
            LeftElbow = Vector3.new(0, 0, -(1.7 + flex)),
            RightElbow = Vector3.new(0, 0, 1.7 + flex),
            LeftHip = Vector3.new(0.3 * rebond, 0, -0.3),
            RightHip = Vector3.new(0.3 * rebond, 0, 0.3),
            LeftKnee = -0.3 - rebond, RightKnee = -0.3 - rebond,
            Waist = Vector3.new(-0.2 * hit, 0.35 * cote * lisse(math.min(1, f * 3)), 0),
            Neck = Vector3.new(0.25 - 0.3 * hit, 0, 0),
        }
        rotation = CFrame.Angles(0, 0.2 * cote, 0)
        arc = -0.6 * (0.3 + rebond)
    elseif temps % 4 == 3 then
        -- POINT & SPIN : la vrille en sautant, bras écartés
        local saut = math.sin(math.pi * f)
        pose = {
            LeftShoulder = Vector3.new(0, 0, -2.6 * saut), RightShoulder = Vector3.new(0, 0, 2.6 * saut),
            LeftKnee = -1.2 * saut, RightKnee = -1.2 * saut, LeftHip = 0.8 * saut, RightHip = 0.8 * saut,
        }
        rotation = CFrame.Angles(0, 2 * math.pi * lisse(f), 0)
        arc = 2.2 * saut
    else
        -- POINT & SPIN : il te pointe du doigt, la tête penchée
        pose = {
            RightShoulder = Vector3.new(1.55 + 0.15 * hit, 0, 0.1),
            RightElbow = Vector3.new(0.1, 0, 0),
            LeftShoulder = Vector3.new(0.2, 0, -0.25),
            Neck = Vector3.new(-0.1 - 0.25 * hit, 0, 0.25),
            Waist = Vector3.new(-0.1 - 0.15 * coup, -0.2, 0),
            LeftKnee = -rebond, RightKnee = -rebond, LeftHip = 0.4 * rebond, RightHip = 0.4 * rebond,
        }
        rotation = CFrame.Angles(0, -0.25, 0)
        arc = -0.35 * rebond
    end
    -- en douceur quand on passe d'un mouvement à l'autre
    if entree < 1 then
        for nom, v in pairs(pose) do
            pose[nom] = (if typeof(v) == "Vector3" then v else Vector3.new(v, 0, 0)) * entree
        end
    end
    return pose, rotation, arc
end
end -- fin du bloc de la danse badass



-- ========================== BOUCLE D'AFFICHAGE ==========================
-- La caméra : la caméra Roblox normale derrière ton avatar pendant la course ;
-- en spectateur (tribune / AFK) elle suit le premier ; dans le menu du lobby elle survole l'escalier ;
-- à la fin elle filme la scène du vainqueur. (Dans le hub, c'est le script MindsetHub qui la tient.)
local pointsCarte = {} -- [config] = point sur la mini-carte
local modeCamera = nil
local sujetCamera = nil
local dernierSuiviAfk = nil

local function enTete()
    local meilleur = nil
    for _, etat in pairs(avatars) do
        if etat.config:GetAttribute("EnJeu") and etat.modele and etat.modele.Parent
            and (not meilleur or (etat.config:GetAttribute("Marche") or 0) > (meilleur.config:GetAttribute("Marche") or 0)) then
            meilleur = etat
        end
    end
    return meilleur
end

RunService.RenderStepped:Connect(function(dt)
    local horloge = os.clock()
    local camera = workspace.CurrentCamera
    local phase = ReplicatedStorage:GetAttribute("Phase")
    local personnage = joueur.Character
    local monHumanoid = personnage and personnage:FindFirstChildOfClass("Humanoid")

    -- 1) le(s) gagnant(s) dansent sur la scène
    for _, etat in pairs(avatars) do
        if etat.danse and etat.modele and etat.modele.Parent then
            local base = etat.config:GetAttribute("Scene")
            if typeof(base) == "CFrame" then
                local pose, rotation, arc = danseBadass(etat, horloge)
                poser(etat, pose)
                etat.modele:PivotTo(base * CFrame.new(0, arc or 0, 0) * (rotation or CFrame.identity))
            end
        end
    end

    -- 2) la caméra
    forceSecousse = math.max(0, forceSecousse - dt * 4)
    fovPulse += (0 - fovPulse) * math.min(1, dt * 6)
    local tremble = Vector3.new((math.random() - 0.5) * forceSecousse, (math.random() - 0.5) * forceSecousse, 0) * 0.5
    if camera and not menuPrincipalOuvert then
        local vueScene = ReplicatedStorage:GetAttribute("SceneCamera")
        local voulu
        if sceneActive and phase == "Fin" and typeof(vueScene) == "CFrame" then
            voulu = "scene"
        elseif menuOuvert then
            voulu = "survol"
        else
            voulu = "normal"
        end
        if voulu == "scene" then
            camera.CameraType = Enum.CameraType.Scriptable
            camera.CFrame = vueScene * CFrame.new(math.sin(horloge * 0.4) * 1.5, math.sin(horloge * 0.3) * 0.4, 0) * CFrame.new(tremble)
            camera.FieldOfView = 50 + fovPulse
        elseif voulu == "survol" then
            -- derrière le menu flouté : la caméra longe doucement l'escalier
            camera.CameraType = Enum.CameraType.Scriptable
            local n = 25 + 20 * math.sin(horloge * 0.08)
            local vise = Vector3.new(ESC.X + n * ESC.D, ESC.Y + n * ESC.H + 4, ESC.Z)
            local oeil = vise + Vector3.new(-30, 16, 34 * math.cos(horloge * 0.05))
            camera.CFrame = CFrame.lookAt(oeil, vise)
            camera.FieldOfView = 60
        else
            -- la caméra Roblox normale : sur toi, ou sur le premier si tu ne cours pas (spectateur)
            local suivi = monHumanoid
            if phase == "Manche" and not jeCours() then
                local premier = enTete()
                local humanoidPremier = premier and premier.modele:FindFirstChildOfClass("Humanoid")
                if humanoidPremier then
                    suivi = humanoidPremier
                    if premier ~= dernierSuiviAfk and majBandeauAfk then
                        dernierSuiviAfk = premier
                        majBandeauAfk(tostring(premier.config:GetAttribute("Nom")) .. " (leading)")
                    end
                end
            end
            if modeCamera ~= "normal" or camera.CameraType ~= Enum.CameraType.Custom then
                camera.CameraType = Enum.CameraType.Custom
            end
            if suivi and sujetCamera ~= suivi then
                sujetCamera = suivi
                camera.CameraSubject = suivi
            end
            camera.FieldOfView = FOV_BASE + fovPulse
            if monHumanoid then
                monHumanoid.CameraOffset = tremble
            end
        end
        if voulu ~= "normal" and monHumanoid then
            monHumanoid.CameraOffset = Vector3.zero
        end
        modeCamera = voulu
    else
        modeCamera = "hub"
        sujetCamera = nil
        if monHumanoid and monHumanoid.CameraOffset ~= Vector3.zero then
            monHumanoid.CameraOffset = Vector3.zero
        end
    end

    -- 3) le compteur de marches, le rang, la vitesse
    if monEtat and marcheTexte.Visible then
        local config = monEtat.config
        marcheTexte.Text = "🪜 " .. (config:GetAttribute("Marche") or 0)
        marcheTexte.TextColor3 = maCouleur()
        local nombre = 0
        for _, etat in pairs(avatars) do
            if etat.config:GetAttribute("EnJeu") then
                nombre += 1
            end
        end
        rangTexte.Text = "#" .. (config:GetAttribute("Rang") or 0) .. " / " .. nombre
        vitesseTexte.Text = "⚡ " .. (config:GetAttribute("Vitesse") or 16)
    end

    -- 4) la mini-carte à droite : un point par coureur (le haut = le premier)
    if barre.Visible then
        local plusHaut = 0
        for _, etat in pairs(avatars) do
            if etat.config:GetAttribute("EnJeu") then
                plusHaut = math.max(plusHaut, etat.config:GetAttribute("Marche") or 0)
            end
        end
        hautBarre.Text = tostring(plusHaut)
        local echelleBarre = math.max(10, plusHaut)
        for config, etat in pairs(avatars) do
            local point = pointsCarte[config]
            if not point then
                point = nouveau("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BorderSizePixel = 0,
                    ZIndex = 4,
                    Parent = barre,
                })
                nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = point })
                pointsCarte[config] = point
            end
            point.Visible = config:GetAttribute("EnJeu") == true
            local taille = if etat.estMoi then 22 else 14
            point.Size = UDim2.fromOffset(taille, taille)
            point.BackgroundColor3 = couleurDe(etat)
            point.Position = UDim2.fromScale(0.5, 1 - math.clamp((config:GetAttribute("Marche") or 0) / echelleBarre, 0, 1))
            point.ZIndex = if etat.estMoi then 5 else 4
        end
        for config, point in pairs(pointsCarte) do
            if not avatars[config] then
                point:Destroy()
                pointsCarte[config] = nil
            end
        end
    end
end)

