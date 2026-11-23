--[[
    🧠 MINDSET STAIRS — Script CLIENT (caméra 2D, avatars, notes de rythme, effets d'aura)
    À mettre dans : StarterPlayer > StarterPlayerScripts  (type : LocalScript)
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
local NoteEvent = remotes:WaitForChild("Note")
local ChoisirEvent = remotes:WaitForChild("Choisir")
local EvenementEvent = remotes:WaitForChild("Evenement")
local FinEvent = remotes:WaitForChild("Fin")
local VoterMusiqueEvent = remotes:WaitForChild("VoterMusique")
local DanserEvent = remotes:WaitForChild("Danser")
local ClassementFonction = remotes:WaitForChild("Classement")
local dossierGrimpeurs = ReplicatedStorage:WaitForChild("Grimpeurs")
local dossierChoixMusiques = ReplicatedStorage:WaitForChild("ChoixMusiques")
local dossierClassements = ReplicatedStorage:WaitForChild("Classements")

local GEO = {
    X0 = ReplicatedStorage:GetAttribute("GeoX0"),
    Y0 = ReplicatedStorage:GetAttribute("GeoY0"),
    Z0 = ReplicatedStorage:GetAttribute("GeoZ0"),
    HAUTEUR = ReplicatedStorage:GetAttribute("GeoHAUTEUR"),
    PROFONDEUR = ReplicatedStorage:GetAttribute("GeoPROFONDEUR"),
    ECART = ReplicatedStorage:GetAttribute("GeoECART"),
}
local NB_COULOIRS = ReplicatedStorage:GetAttribute("NbCouloirs")

local COULEURS = {
    Motivation = Color3.fromRGB(255, 150, 30),
    Ego = Color3.fromRGB(170, 80, 255),
    Discipline = Color3.fromRGB(60, 140, 255),
    Obsession = Color3.fromRGB(230, 40, 60),
}
local ORDRE_PERSOS = { "Motivation", "Ego", "Discipline", "Obsession" }
-- Ce qui s'affiche sur les cartes du menu (les vraies règles sont dans le script serveur)
local DEVISES = {
    Motivation = "The fire of the start",
    Ego = "The king of combos",
    Discipline = "The unbreakable wall",
    Obsession = "The late-game monster",
}
-- 🧠 Les compétences (définies dans le script serveur, partie COMPETENCES) et TES niveaux,
-- achetés chez le marchand du menu 3D (le serveur les met dans l'attribut « Niveaux » du joueur)
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

-- Fenêtres de timing (en secondes)
local APPROCHE = 1.0       -- un cercle apparaît 1 s avant son temps
local FENETRE_PARFAIT = 0.07
local FENETRE_BIEN = 0.15
local FENETRE_MAX = 0.25

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

-- Pas de joystick ni de bouton saut, pas de bouton « Réinitialiser »
task.spawn(function()
    local ok, module = pcall(function()
        return require(joueur:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
    end)
    if ok and module then
        module:GetControls():Disable()
    end
end)
task.spawn(function()
    for _ = 1, 10 do
        if pcall(function()
            StarterGui:SetCore("ResetButtonCallback", false)
        end) then
            break
        end
        task.wait(1)
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
local REGLAGES = { musique = 1, bruitages = 1, secousses = true, flashs = true }
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
local comboTexte = texte({
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 130),
    Size = UDim2.new(0.4, 0, 0, 56),
    TextColor3 = OR,
    TextTransparency = 1,
    TextStrokeTransparency = 1,
    ZIndex = 4,
    Parent = gui,
})
local echelleCombo = nouveau("UIScale", { Parent = comboTexte })
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

-- Zone où apparaissent les cercles de rythme
local zoneNotes = nouveau("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = gui })

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
local FOV_BASE = 28
local fovPulse = 0       -- coup de zoom sur les temps, qui retombe tout seul
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

-- ========================== ESCALIERS INFINIS ==========================
-- Il n'y a plus de sommet : on ne construit que les marches autour de la caméra,
-- et on recycle celles qui sortent de l'écran. Comme ça, ça peut monter à l'infini.
-- (tout est dans un bloc do ... end : Luau limite le nombre de variables locales d'un script)
local sceneLocale = nouveau("Folder", { Name = "MindsetSceneLocale", Parent = workspace })
-- UN SEUL grand escalier, large, que tout le monde gravit ensemble (chacun à sa place sur la largeur).
local couloirs = {}  -- [0] = { ligne = part } : la ligne néon au bord de l'escalier (couleur de ton perso)
local FOND_Z = GEO.Z0 - NB_COULOIRS * GEO.ECART - 15
local majEscaliers, allumerMarche, eclats, ondeSol, fondScene, poussiere
do
local MARCHES_DERRIERE, MARCHES_DEVANT = 40, 50
local BLANC_MARCHE = Color3.fromRGB(235, 235, 245)
local LARGEUR_ESCALIER = (NB_COULOIRS - 1) * GEO.ECART + 6 -- de l'avant (couloir 0) au fond (dernier couloir)
local Z_CENTRE = GEO.Z0 - (NB_COULOIRS - 1) * GEO.ECART / 2
local Z_AVANT = GEO.Z0 + 3 -- le bord de l'escalier tourné vers la caméra
local marches = {}   -- [numero] = part
local reserve = {}   -- marches recyclées

local function blocLocal(proprietes)
    proprietes.Anchored = true
    proprietes.CanCollide = false
    proprietes.CanQuery = false
    proprietes.CanTouch = false
    proprietes.CastShadow = false
    proprietes.TopSurface = Enum.SurfaceType.Smooth
    proprietes.BottomSurface = Enum.SurfaceType.Smooth
    proprietes.Parent = proprietes.Parent or sceneLocale
    return nouveau("Part", proprietes)
end

-- couleur de base d'une marche : tous les 10 un peu dorée (avec son numéro), tous les 50 en néon
local function lookMarche(numero)
    if numero > 0 and numero % 50 == 0 then
        return OR, Enum.Material.Neon
    elseif numero > 0 and numero % 10 == 0 then
        return Color3.fromRGB(255, 236, 175), Enum.Material.SmoothPlastic
    end
    return BLANC_MARCHE, Enum.Material.SmoothPlastic
end

local function placerMarche(numero)
    local part = table.remove(reserve)
    if not part then
        part = blocLocal({ Name = "Marche" })
        local panneau = nouveau("SurfaceGui", {
            Name = "Numero",
            Face = Enum.NormalId.Back, -- la face tournée vers la caméra
            SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
            PixelsPerStud = 40,
            LightInfluence = 0,
            Parent = part,
        })
        texte({ Size = UDim2.fromScale(1, 0.45), TextColor3 = Color3.fromRGB(60, 50, 20), TextStrokeTransparency = 1, Parent = panneau })
    end
    local D, H = GEO.PROFONDEUR, GEO.HAUTEUR
    local longueur, x = D, GEO.X0 + (numero + 0.5) * D
    if numero == 0 then
        longueur = D * 4
        x = GEO.X0 + D - longueur / 2
    end
    -- des marches « pleines » (3 de haut) pour que ça ressemble à un vrai escalier
    part.Size = Vector3.new(longueur, H * 3, LARGEUR_ESCALIER)
    part.Position = Vector3.new(x, GEO.Y0 + numero * H - H * 1.5, Z_CENTRE)
    local couleur, matiere = lookMarche(numero)
    part.Color = couleur
    part.Material = matiere
    local panneau = part:FindFirstChild("Numero")
    if panneau then
        panneau.Enabled = numero > 0 and numero % 10 == 0
        panneau:FindFirstChildOfClass("TextLabel").Text = tostring(numero)
    end
    return part
end

-- ligne néon le long du bord de l'escalier
couloirs[0] = {
    ligne = blocLocal({ Name = "Ligne", Size = Vector3.new(1, 0.35, 0.35), Color = Color3.fromRGB(70, 70, 80), Material = Enum.Material.Neon }),
}

local fenetreA, fenetreB = nil, nil
majEscaliers = function(marcheCentre)
    local a = math.max(0, math.floor(marcheCentre) - MARCHES_DERRIERE)
    local b = math.max(a + 10, math.floor(marcheCentre) + MARCHES_DEVANT)
    if a == fenetreA and b == fenetreB then
        return
    end
    fenetreA, fenetreB = a, b
    local D, H = GEO.PROFONDEUR, GEO.HAUTEUR
    for numero, part in pairs(marches) do
        if numero < a or numero > b then
            marches[numero] = nil
            part.Position = Vector3.new(0, -1000, 0)
            table.insert(reserve, part)
        end
    end
    for numero = a, b do
        if not marches[numero] then
            marches[numero] = placerMarche(numero)
        end
    end
    local debut = Vector3.new(GEO.X0 + a * D, GEO.Y0 + a * H, Z_AVANT + 0.1)
    local fin = Vector3.new(GEO.X0 + (b + 1) * D, GEO.Y0 + (b + 1) * H, Z_AVANT + 0.1)
    couloirs[0].ligne.Size = Vector3.new((fin - debut).Magnitude, 0.35, 0.35)
    couloirs[0].ligne.CFrame = CFrame.new((debut + fin) / 2) * CFrame.Angles(0, 0, math.atan2(H, D))
end
majEscaliers(0)

-- Là où le pied se pose, une dalle de lumière s'allume sur la marche (à la place du joueur)
allumerMarche = function(couloir, numero, couleur)
    if not couloir or numero < 0 then
        return
    end
    local D, H = GEO.PROFONDEUR, GEO.HAUTEUR
    local dalle = blocLocal({
        Name = "Dalle",
        Size = Vector3.new(D * 0.92, 0.12, 4.2),
        Position = Vector3.new(GEO.X0 + (numero + 0.5) * D, GEO.Y0 + numero * H + 0.06, GEO.Z0 - couloir * GEO.ECART),
        Color = couleur,
        Material = Enum.Material.Neon,
        Transparency = 0.05,
    })
    tween(dalle, 0.5, { Transparency = 1, Size = Vector3.new(D, 0.12, 5) })
    task.delay(0.52, function()
        dalle:Destroy()
    end)
end

-- Fond noir + poussière d'aura : ils suivent la caméra (les escaliers n'ont pas de fin)
fondScene = blocLocal({ Name = "Fond", Size = Vector3.new(900, 600, 2), Color = Color3.fromRGB(8, 8, 14), Material = Enum.Material.SmoothPlastic })
poussiere = blocLocal({ Name = "Poussiere", Size = Vector3.new(500, 300, 1), Transparency = 1 })
nouveau("ParticleEmitter", {
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

-- Éclats (petites étincelles 3D) et onde au sol : pour les atterrissages, la danse et le check
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
        -- à plat sur la marche, ou face à la caméra (vertical)
        CFrame = CFrame.new(position) * (if vertical then CFrame.Angles(0, math.pi / 2, 0) else CFrame.Angles(0, 0, math.pi / 2)),
    })
    tween(onde, 0.4, { Size = Vector3.new(0.12, taille, taille), Transparency = 1 })
    task.delay(0.42, function()
        onde:Destroy()
    end)
end
end -- fin du bloc des escaliers

-- ========================== AVATARS SUR LES MARCHES ==========================
local ANIMS = {
    attente = "rbxassetid://507766388", -- animations R15 par défaut de Roblox
    saut = "rbxassetid://507765000",
    chute = "rbxassetid://507767968",
    -- les 3 danses de base de Roblox (/e dance, /e dance2, /e dance3)
    danses = { "rbxassetid://507771019", "rbxassetid://507776043", "rbxassetid://507777268" },
}
local avatars = {}  -- [config] = état de l'avatar
local monEtat = nil
local etatSuiviCamera = nil -- si défini, la caméra suit cet avatar (le vainqueur)

local function couleurDe(etat)
    return COULEURS[etat.config:GetAttribute("Perso")] or Color3.fromRGB(200, 200, 210)
end

local function positionMarche(couloir, marche, hauteur)
    return Vector3.new(
        GEO.X0 + (marche + 0.5) * GEO.PROFONDEUR,
        GEO.Y0 + marche * GEO.HAUTEUR + hauteur,
        GEO.Z0 - couloir * GEO.ECART
    )
end

local function hauteurRacine(modele)
    local humanoid = modele:FindFirstChildOfClass("Humanoid")
    local racine = modele:FindFirstChild("HumanoidRootPart")
    if humanoid and racine and humanoid.RigType == Enum.HumanoidRigType.R15 then
        return humanoid.HipHeight + racine.Size.Y / 2
    end
    return 3
end

local function chargerAnims(etat)
    local humanoid = etat.modele:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end
    local animator = humanoid:FindFirstChildOfClass("Animator") or nouveau("Animator", { Parent = humanoid })
    local function charger(id, priorite, boucle)
        local animation = Instance.new("Animation")
        animation.AnimationId = id
        local ok, piste = pcall(function()
            return animator:LoadAnimation(animation)
        end)
        if not ok then
            return nil
        end
        piste.Priority = priorite
        piste.Looped = boucle
        return piste
    end
    etat.animAttente = charger(ANIMS.attente, Enum.AnimationPriority.Action, true)
    etat.animSaut = charger(ANIMS.saut, Enum.AnimationPriority.Action2, false)
    etat.animChute = charger(ANIMS.chute, Enum.AnimationPriority.Action2, true)
    etat.animDanses = {}
    for i, id in ipairs(ANIMS.danses) do
        etat.animDanses[i] = charger(id, Enum.AnimationPriority.Action3, true)
    end
    etat.danseJouee = 0
    if etat.animAttente then
        etat.animAttente:Play()
    end

    -- traînée lumineuse pendant les sauts
    local racine = etat.modele:FindFirstChild("HumanoidRootPart")
    if racine then
        local a0 = nouveau("Attachment", { Name = "MindsetTrainee0", Position = Vector3.new(0, 1, 0), Parent = racine })
        local a1 = nouveau("Attachment", { Name = "MindsetTrainee1", Position = Vector3.new(0, -1.2, 0), Parent = racine })
        etat.trainee = nouveau("Trail", {
            Name = "MindsetTrainee",
            Attachment0 = a0,
            Attachment1 = a1,
            Lifetime = 0.22,
            MinLength = 0.05,
            FaceCamera = true,
            LightEmission = 1,
            Transparency = NumberSequence.new(0.3, 1),
            Color = ColorSequence.new(couleurDe(etat)),
            Enabled = false,
            Parent = racine,
        })
    end

    -- les articulations (R15) qu'on plie à la main pour monter les marches pied par pied
    etat.membres = {}
    for _, nom in ipairs({ "LeftHip", "RightHip", "LeftKnee", "RightKnee", "LeftShoulder", "RightShoulder", "Waist" }) do
        local moteur = etat.modele:FindFirstChild(nom, true)
        if moteur and moteur:IsA("Motor6D") then
            etat.membres[nom] = { moteur = moteur, c0 = moteur.C0, angle = 0 }
        end
    end
end

-- Plie les articulations : pose = { LeftHip = angle, ... } (en radians, rien = position normale)
--   hanche / épaule + = vers l'avant · genou - = plié · taille - = penché en avant
local POSE_REPOS = {}
local function poser(etat, pose)
    if not etat.membres then
        return
    end
    pose = pose or POSE_REPOS
    for nom, info in pairs(etat.membres) do
        local angle = pose[nom] or 0
        if math.abs(angle - info.angle) > 0.001 and info.moteur.Parent then
            info.angle = angle
            info.moteur.C0 = info.c0 * CFrame.Angles(angle, 0, 0)
        end
    end
end

-- La pose d'un pas : la jambe « pied » monte sur la marche, l'autre pousse, les bras balancent
local function posePas(pied, k, style)
    local b = math.sin(math.pi * k) -- 0 → 1 → 0 pendant le pas
    local leve, appui = if pied == 0 then "Left" else "Right", if pied == 0 then "Right" else "Left"
    local pose = {}
    pose[leve .. "Hip"] = 1.25 * b
    pose[leve .. "Knee"] = -1.5 * b
    pose[appui .. "Hip"] = -0.3 * b
    pose[appui .. "Knee"] = -0.25 * b
    -- bras opposé à la jambe vers l'avant (comme quand on court), plus ample avec du style
    pose[appui .. "Shoulder"] = (0.7 + 0.5 * style) * b
    pose[leve .. "Shoulder"] = -(0.5 + 0.3 * style) * b
    pose.Waist = -0.2 * b
    return pose
end

-- La danse du gagnant (attribut « Danse » : 0 = rien, 1/2/3 = la danse jouée)
local function majDanse(etat)
    if not etat.animDanses then
        return
    end
    local n = etat.config:GetAttribute("Danse") or 0
    if n == etat.danseJouee then
        return
    end
    local avant = etat.animDanses[etat.danseJouee]
    if avant then
        avant:Stop(0.25)
    end
    etat.danseJouee = n
    local piste = etat.animDanses[n]
    if piste then
        piste:Play(0.25)
    end
end

local function majEtiquette(etat)
    if not etat.etiquettePerso then
        return
    end
    local perso = etat.config:GetAttribute("Perso")
    local combo = etat.config:GetAttribute("Combo") or 0
    etat.etiquettePerso.Text = if perso then string.upper(perso) else "???"
    etat.etiquettePerso.TextColor3 = couleurDe(etat)
    if etat.trainee then
        etat.trainee.Color = ColorSequence.new(couleurDe(etat))
    end
    local nom = etat.config:GetAttribute("Nom") or ""
    etat.etiquetteNom.Text = if combo >= 5 then nom .. "  •  x" .. combo else nom
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
    local billboard = nouveau("BillboardGui", {
        Name = "MindsetEtiquette",
        Size = UDim2.fromOffset(if etat.estMoi then 240 else 190, if etat.estMoi then 76 else 60),
        StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0),
        AlwaysOnTop = true,
        MaxDistance = 3000,
        LightInfluence = 0,
        Parent = tete,
    })
    etat.etiquettePerso = texte({ Size = UDim2.fromScale(1, 0.62), Parent = billboard })
    etat.etiquetteNom = texte({
        Position = UDim2.fromScale(0, 0.62),
        Size = UDim2.fromScale(1, 0.38),
        TextColor3 = Color3.fromRGB(220, 220, 230),
        Parent = billboard,
    })
    majEtiquette(etat)
end

local NOMS_NIVEAUX = { "✨ AURA LEVEL 1", "🔥 AURA LEVEL 2", "👑 MAX AURA" }

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
        table.insert(etat.effets, nouveau("Fire", { Color = BLANC, SecondaryColor = couleur, Size = 8, Heat = 14, Parent = torse }))
        table.insert(etat.effets, nouveau("PointLight", { Color = couleur, Brightness = 5, Range = 20, Parent = racine }))
        table.insert(etat.effets, nouveau("Highlight", {
            FillColor = couleur,
            FillTransparency = 0.5,
            OutlineColor = BLANC,
            Parent = etat.modele,
        }))
    end
    if etat.estMoi and niveau > etat.niveauAffiche and NOMS_NIVEAUX[niveau] then
        auraTexte.TextColor3 = if niveau == 3 then OR else couleur
        apparaitre(auraTexte, NOMS_NIVEAUX[niveau], 1.6)
        flasher(couleur, 0.25 + niveau * 0.1)
        secousse(0.6 + niveau * 0.3)
    end
    etat.niveauAffiche = niveau
end

-- Chaque client se voit dans le couloir de devant ; les autres sont derrière
local function majCouloirs()
    local liste = {}
    for _, etat in pairs(avatars) do
        table.insert(liste, etat)
    end
    table.sort(liste, function(a, b)
        if a.estMoi ~= b.estMoi then
            return a.estMoi
        end
        return (a.config:GetAttribute("Ordre") or 0) < (b.config:GetAttribute("Ordre") or 0)
    end)
    local occupants = {}
    for i, etat in ipairs(liste) do
        etat.couloir = if i <= NB_COULOIRS then i - 1 else nil
        if etat.couloir then
            occupants[etat.couloir] = etat
        end
    end
    for couloir, co in pairs(couloirs) do
        co.ligne.Color = if occupants[couloir] then couleurDe(occupants[couloir]) else Color3.fromRGB(70, 70, 80)
    end
end

local effetsMoi -- défini plus bas (réactions quand TU montes/descends)

-- Une marche montée AVEC STYLE : l'avatar monte PIED PAR PIED.
--   chaque marche = un pas (pied gauche, puis pied droit, puis gauche...)
--   +2 marches = deux pas rapides enchaînés
--   avec du combo, les bras balancent plus fort ; tous les 10 de combo : une vrille sur le dernier pas
--   chaque pied qui se pose allume la marche (étincelles), une onde au sol à la fin
--   en ratant : il trébuche en arrière, les bras en l'air
local function nouvelleMarche(etat)
    local cible = etat.config:GetAttribute("Marche") or 0
    local depart = etat.marcheAffichee or cible
    if math.abs(cible - depart) < 0.01 then
        return
    end
    local monte = cible > depart
    if not monte and depart - cible > 6 then
        -- grosse remise à zéro (nouvelle partie) : on le pose direct en bas, sans animation
        etat.saut = nil
        etat.marcheAffichee = cible
        return
    end
    local ecart = math.abs(cible - depart)
    local combo = etat.config:GetAttribute("Combo") or 0
    local pas = if monte then math.max(1, math.floor(ecart + 0.5)) else 1
    etat.saut = {
        de = depart,
        a = cible,
        debut = os.clock(),
        duree = if monte then math.min(0.6, 0.22 * pas) else 0.32,
        monte = monte,
        pas = pas,
        pasFaits = 0,
        pied = etat.prochainPied or 0,
        style = math.clamp(combo / 20, 0, 1),
        vrille = monte and combo > 0 and combo % 10 == 0,
    }
    if monte then
        etat.prochainPied = ((etat.prochainPied or 0) + pas) % 2
    end
    if etat.trainee and monte and combo >= 5 then
        etat.trainee.Enabled = true
    end
    if not monte and etat.animChute then
        etat.animChute:Play(0.05)
    end
    if etat.estMoi and effetsMoi then
        effetsMoi(depart, cible)
    end
end

-- un pied se pose sur une marche
local function piedPose(etat, numero, fort)
    if not etat.couloir then
        return
    end
    local couleur = couleurDe(etat)
    allumerMarche(etat.couloir, numero, couleur)
    local sol = positionMarche(etat.couloir, numero, 0.1)
    eclats(sol, couleur, if fort then 10 else 4, 0.6)
    if fort then
        ondeSol(sol, couleur, 5)
    end
end

local function atterrir(etat, saut)
    if etat.trainee then
        etat.trainee.Enabled = false
    end
    if not etat.couloir then
        return
    end
    if not saut.monte then
        allumerMarche(etat.couloir, math.floor(saut.a + 0.5), ROUGE)
    elseif etat.estMoi then
        fovPulse = math.min(fovPulse, if saut.pas >= 2 then -2 else -0.7)
        if saut.vrille then
            secousse(0.5)
        end
    end
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
    tween(label, 0.8, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quint)
    task.delay(0.8, function()
        bulle:Destroy()
    end)
    eclats(tete.Position, couleur, 4, 0.6)
end
local surAuraFarmee -- défini plus bas (compteur à l'écran quand c'est TOI qui danses)

local function ajouterGrimpeur(config)
    if avatars[config] then
        return
    end
    local etat = {
        config = config,
        estMoi = config:GetAttribute("UserId") == joueur.UserId,
        effets = {},
        niveauAffiche = 0,
        marcheAffichee = config:GetAttribute("Marche") or 0,
    }
    avatars[config] = etat
    if etat.estMoi then
        monEtat = etat
    end

    local valeur = config:WaitForChild("Modele", 10)
    local function majModele()
        etat.modele = valeur and valeur.Value
        etat.hauteur = nil
        etat.animAttente, etat.animSaut, etat.animChute = nil, nil, nil
        etat.animDanses, etat.danseJouee, etat.trainee = nil, 0, nil
        etat.cinematique, etat.membres = nil, nil
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
            etat.hauteur = hauteurRacine(modele)
            chargerAnims(etat)
            creerEtiquette(etat)
            majAuraAvatar(etat)
            majDanse(etat)
        end)
    end
    if valeur then
        valeur.Changed:Connect(majModele)
    end
    majModele()

    config:GetAttributeChangedSignal("Marche"):Connect(function()
        nouvelleMarche(etat)
    end)
    config:GetAttributeChangedSignal("Perso"):Connect(function()
        majEtiquette(etat)
        majCouloirs()
    end)
    config:GetAttributeChangedSignal("Combo"):Connect(function()
        majEtiquette(etat)
    end)
    config:GetAttributeChangedSignal("NiveauAura"):Connect(function()
        majAuraAvatar(etat)
    end)
    config:GetAttributeChangedSignal("Danse"):Connect(function()
        majDanse(etat)
    end)
    config:GetAttributeChangedSignal("AuraFarmee"):Connect(function()
        local n = config:GetAttribute("AuraFarmee") or 0
        if n > 0 then
            popupAura(etat)
            if etat.estMoi and surAuraFarmee then
                surAuraFarmee(n)
            end
        end
    end)
    majCouloirs()
end

dossierGrimpeurs.ChildAdded:Connect(ajouterGrimpeur)
dossierGrimpeurs.ChildRemoved:Connect(function(config)
    if avatars[config] == monEtat then
        monEtat = nil
    end
    avatars[config] = nil
    majCouloirs()
end)
for _, config in ipairs(dossierGrimpeurs:GetChildren()) do
    task.spawn(ajouterGrimpeur, config)
end

-- ========================== MUSIQUE ==========================
local musique = nouveau("Sound", { Name = "MindsetMusique", Volume = 0.8, SoundGroup = groupeMusique, Parent = SoundService })
local partition = nil      -- infos de la manche en cours
local intervalle = 0.5
local musiqueLancee = false
local dernierRecalage = 0
local trainsPerdus = 0 -- combien de fois de suite la musique était perdue (voir la boucle d'affichage)

local function couperMusique(duree)
    tween(musique, duree, { Volume = 0 })
    task.delay(duree, function()
        if not partition then
            musique:Stop()
            musique.Volume = 0.8
        end
    end)
end

-- ========================== NOTES DE RYTHME ==========================
local notesActives = {}   -- [index] = { cercle, anneau, temps, position }
local prochaineNote = 1
local jeJoue = false
local dernierePosition = nil
local compteurNotes = 0
local clicsManche = 0 -- tes clics pendant la manche (0 = tu n'étais sûrement pas là → AFK)

local function maCouleur()
    return if monEtat then couleurDe(monEtat) else OR
end

local juger, creerNote
local dernierClicUtilise = 0 -- l'heure du dernier clic qui a validé une note (un clic = une note)
do
local function effetTouche(position, verdict)
    local couleur = if verdict == "Parfait" then OR elseif verdict == "Bien" then Color3.fromRGB(120, 255, 160) else ROUGE
    local message = if verdict == "Parfait" then "PERFECT!" elseif verdict == "Bien" then "GOOD" else "MISS"
    local popup = texte({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(position.X, position.Y - 0.06),
        Size = UDim2.fromOffset(200, 44),
        Text = message,
        Font = Enum.Font.Arcade, -- police rétro
        TextColor3 = couleur,
        ZIndex = 8,
        Parent = zoneNotes,
    })
    tween(popup, 0.6, { Position = UDim2.fromScale(position.X, position.Y - 0.12), TextTransparency = 1, TextStrokeTransparency = 1 })
    task.delay(0.6, function()
        popup:Destroy()
    end)
    if verdict ~= "Rate" then
        local onde = nouveau("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(position.X, position.Y),
            Size = UDim2.fromOffset(90, 90),
            BackgroundTransparency = 1,
            ZIndex = 7,
            Parent = zoneNotes,
        })
        nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = onde })
        local trait = nouveau("UIStroke", { Color = couleur, Thickness = 5, Parent = onde })
        tween(onde, 0.35, { Size = UDim2.fromOffset(200, 200) })
        tween(trait, 0.35, { Transparency = 1 })
        task.delay(0.35, function()
            onde:Destroy()
        end)
        fovPulse = math.min(fovPulse, if verdict == "Parfait" then -2 else -1)
    else
        secousse(0.8)
    end
end

juger = function(index, expire)
    local note = notesActives[index]
    if not note or not partition then
        return
    end
    notesActives[index] = nil
    local verdict = "Rate"
    if not expire then
        local ecart = math.abs(maintenantServeur() - (partition.debut + note.temps))
        if ecart <= FENETRE_PARFAIT then
            verdict = "Parfait"
        elseif ecart <= FENETRE_BIEN then
            verdict = "Bien"
        end
    end
    NoteEvent:FireServer(index, verdict)
    effetTouche(note.position, verdict)
    -- le cercle grossit et s'efface
    tween(note.echelle, 0.14, { Scale = 1.3 })
    for _, morceau in ipairs(note.morceaux) do
        tween(morceau, 0.14, { BackgroundTransparency = 1 })
    end
    note.anneau:Destroy()
    task.delay(0.15, function()
        note.cercle:Destroy()
    end)
end

-- un rond (Frame avec coins arrondis à fond)
local function rond(proprietes)
    local frame = nouveau("Frame", proprietes)
    frame.BorderSizePixel = 0
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = frame })
    return frame
end

-- le centre d'une note à l'écran (en pixels)
local function centreNote(note)
    return note.cercle.AbsolutePosition + note.cercle.AbsoluteSize / 2
end

creerNote = function(index, tempsNote)
    local taille = if surMobile then 110 else 90
    -- Une position qui ne touche AUCUN autre cercle à l'écran (sinon un clic pourrait en valider deux),
    -- pas trop loin de la précédente pour que ça reste fluide.
    local zone = zoneNotes.AbsoluteSize
    local ecartMin = taille * 1.4
    local meilleur, meilleurScore = nil, -math.huge
    for essai = 1, 40 do
        local candidat = Vector2.new(0.15 + math.random() * 0.62, 0.3 + math.random() * 0.42)
        local pixels = candidat * zone
        local plusProche = math.huge
        for _, autre in pairs(notesActives) do
            plusProche = math.min(plusProche, (autre.position * zone - pixels).Magnitude)
        end
        if dernierePosition then
            plusProche = math.min(plusProche, (dernierePosition * zone - pixels).Magnitude)
        end
        local score = math.min(plusProche, ecartMin * 1.5)
        -- bonus si on reste assez près de la note d'avant (le regard n'a pas à traverser l'écran)
        if dernierePosition and (candidat - dernierePosition).Magnitude < 0.35 then
            score += ecartMin * 0.5
        end
        if score > meilleurScore then
            meilleur, meilleurScore = candidat, score
        end
        if plusProche >= ecartMin and essai >= 8 then
            break
        end
    end
    local x, y = meilleur.X, meilleur.Y
    dernierePosition = meilleur
    compteurNotes += 1

    -- 💠 le cercle, style NÉON : un disque sombre et brillant, un anneau lumineux de la couleur du perso,
    -- un halo qui « respire » autour et un cœur lumineux au centre (aucune bordure blanche).
    local couleur = maCouleur()
    local cercle = nouveau("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(x, y),
        Size = UDim2.fromOffset(taille, taille),
        BackgroundTransparency = 1,
        ZIndex = 6,
        Parent = zoneNotes,
    })
    local echelleCercle = nouveau("UIScale", { Scale = 0.5, Parent = cercle })
    -- le halo flou autour (2 couches de plus en plus transparentes)
    local halo1 = rond({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1.45, 1.45),
        BackgroundColor3 = couleur,
        BackgroundTransparency = 0.88,
        ZIndex = 6,
        Parent = cercle,
    })
    local halo2 = rond({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1.22, 1.22),
        BackgroundColor3 = couleur,
        BackgroundTransparency = 0.75,
        ZIndex = 6,
        Parent = cercle,
    })
    -- le disque : sombre, teinté de la couleur, avec l'anneau néon
    local disque = rond({
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = couleur:Lerp(NOIR, 0.78),
        BackgroundTransparency = 0.05,
        ZIndex = 7,
        Parent = cercle,
    })
    nouveau("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(couleur:Lerp(NOIR, 0.55), couleur:Lerp(NOIR, 0.9)),
        Parent = disque,
    })
    nouveau("UIStroke", { Color = couleur:Lerp(BLANC, 0.15), Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = disque })
    -- un fin anneau intérieur
    local anneauInterieur = rond({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.6, 0.6),
        BackgroundTransparency = 1,
        ZIndex = 8,
        Parent = cercle,
    })
    nouveau("UIStroke", { Color = couleur, Thickness = 2, Transparency = 0.35, Parent = anneauInterieur })
    -- le cœur lumineux
    local coeur = rond({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.26, 0.26),
        BackgroundColor3 = couleur:Lerp(BLANC, 0.45),
        ZIndex = 9,
        Parent = cercle,
    })
    local morceaux = { halo1, halo2, disque, coeur }
    -- le halo respire au rythme de l'approche
    tween(halo1, 0.5, { Size = UDim2.fromScale(1.6, 1.6) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    tween(echelleCercle, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)

    -- 🖱️ la zone de clic : un bouton invisible un peu plus grand que le cercle (plus facile à toucher).
    -- Les cercles ne se superposent jamais, et un même clic ne peut valider qu'UNE note.
    local zoneClic = nouveau("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1.2, 1.2),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 12,
        Parent = cercle,
    })
    zoneClic.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        -- un même clic ne valide qu'une note : deux notes validées à moins de 30 ms d'écart,
        -- c'est forcément le même clic (⚠ Roblox réutilise le même objet pour tous les clics de souris,
        -- c'est pour ça qu'on compare l'heure et pas l'objet du clic)
        local maintenant = os.clock()
        if maintenant - dernierClicUtilise < 0.03 then
            return
        end
        dernierClicUtilise = maintenant
        juger(index, false)
    end)

    -- l'anneau qui se resserre (de la couleur du perso) : clique quand il touche le cercle !
    local anneau = nouveau("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(x, y),
        Size = UDim2.fromOffset(taille, taille),
        BackgroundTransparency = 1,
        ZIndex = 5,
        Parent = zoneNotes,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = anneau })
    local traitAnneau = nouveau("UIStroke", { Color = couleur:Lerp(BLANC, 0.25), Thickness = 3, Transparency = 0.6, Parent = anneau })
    local echelle = nouveau("UIScale", { Scale = 3, Parent = anneau })
    local reste = math.max(0.05, partition.debut + tempsNote - maintenantServeur())
    tween(echelle, reste, { Scale = 1 }, Enum.EasingStyle.Linear)
    tween(traitAnneau, reste, { Transparency = 0, Thickness = 4 }, Enum.EasingStyle.Linear)

    notesActives[index] = {
        cercle = cercle,
        anneau = anneau,
        echelle = echelleCercle,
        morceaux = morceaux,
        temps = tempsNote,
        position = Vector2.new(x, y),
        taille = taille,
    }
end

-- on compte tes clics pendant la manche (0 clic de toute la manche = tu n'étais sûrement pas là → AFK)
UserInputService.InputBegan:Connect(function(input)
    if jeJoue and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        clicsManche += 1
    end
end)
end -- fin du bloc des notes

local function viderNotes()
    for index, note in pairs(notesActives) do
        note.cercle:Destroy()
        note.anneau:Destroy()
        notesActives[index] = nil
    end
    zoneNotes:ClearAllChildren()
end

-- ========================== RÉACTIONS QUAND TU MONTES / DESCENDS ==========================
local modeAura = false

effetsMoi = function(depart, cible)
    if cible < depart then
        flasher(ROUGE, 0.25)
        secousse(1.2)
        auraTexte.TextColor3 = ROUGE
        apparaitre(auraTexte, "💀 -" .. math.floor(depart - cible + 0.5) .. " STEP" .. (if depart - cible > 1.5 then "S" else ""), 0.8)
        return
    end
    if math.floor(cible / 10) > math.floor(depart / 10) then
        grosTexte.TextColor3 = maCouleur()
        apparaitre(grosTexte, "🪜 " .. math.floor(cible / 10) * 10 .. " STEPS!", 1, echelleGros)
        flasher(maCouleur(), 0.3)
        secousse(0.8)
    end
end

local function majModeAura(combo)
    local actif = combo >= 20
    if actif == modeAura then
        return
    end
    modeAura = actif
    if actif then
        -- ✨ MODE AURA : image en noir et blanc très contrastée, comme les edits TikTok
        tween(effetAura, 0.4, { Saturation = -1, Contrast = 0.35, Brightness = 0.02 })
        grosTexte.TextColor3 = OR
        apparaitre(grosTexte, "🔥 AURA MODE 🔥", 1.4, echelleGros)
        flasher(BLANC, 0.6)
        secousse(1.5)
        flou.Size = 14
        tween(flou, 0.6, { Size = 0 })
    else
        tween(effetAura, 0.6, { Saturation = 0, Contrast = 0, Brightness = 0 })
        grosTexte.TextColor3 = ROUGE
        apparaitre(grosTexte, "💀 AURA LOST", 1, echelleGros)
    end
end

local dernierComboAffiche = 0
local function majCombo()
    local combo = if monEtat then monEtat.config:GetAttribute("Combo") or 0 else 0
    if combo >= 3 then
        comboTexte.TextColor3 = if combo >= 20 then OR else maCouleur()
        comboTexte.Text = "x" .. combo .. " COMBO"
        comboTexte.TextTransparency = 0
        comboTexte.TextStrokeTransparency = 0
        if combo > dernierComboAffiche then
            echelleCombo.Scale = 1.25
            tween(echelleCombo, 0.15, { Scale = 1 })
        end
    else
        comboTexte.TextTransparency = 1
        comboTexte.TextStrokeTransparency = 1
    end
    dernierComboAffiche = combo
    majModeAura(combo)
end

-- on surveille le combo de TON grimpeur
task.spawn(function()
    while not monEtat do
        task.wait(0.2)
    end
    local config = monEtat.config
    config:GetAttributeChangedSignal("Combo"):Connect(majCombo)
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

-- ========================== SUR LES TEMPS DE LA MUSIQUE ==========================
local dernierTemps = -1
local function surTemps(numero)
    -- chaque temps : petit zoom ; tous les 4 temps : flash (plus fort en mode aura)
    fovPulse = math.min(fovPulse, if modeAura then -3 else -1.2)
    if numero % 4 == 0 then
        flasher(BLANC, if modeAura then 0.18 else 0.06)
        if modeAura then
            secousse(0.7)
        end
    end
    if modeAura then
        effetPulse.Contrast = 0.3
        tween(effetPulse, intervalle * 0.9, { Contrast = 0 })
    end
end

-- ========================== DÉBUT D'UNE MANCHE ==========================
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
    intervalle = 60 / infos.bpm
    prochaineNote = 1
    dernierTemps = -1
    compteurNotes = 0
    clicsManche = 0
    dernierePosition = nil
    musiqueLancee = false
    viderNotes()
    jeJoue = monEtat ~= nil and monEtat.config:GetAttribute("EnJeu") == true

    if infos.musique and infos.musique ~= "" then
        musique.SoundId = infos.musique
        musique.Volume = 0.8
        musique.PlaybackSpeed = 1
        trainsPerdus = 0
        task.spawn(function()
            pcall(function()
                ContentProvider:PreloadAsync({ musique }, function(_, statut)
                    if statut ~= Enum.AssetFetchStatus.Success then
                        warn("[MUSIQUE] Impossible de charger " .. tostring(infos.musique)
                            .. " (statut : " .. tostring(statut) .. "). Son privé, en modération, jeu pas publié ou mauvais ID ?")
                    end
                end)
            end)
            if not musique.IsLoaded then
                task.wait(3)
                if not musique.IsLoaded and musique.SoundId == infos.musique then
                    warn("[MUSIQUE] Toujours pas chargée après 3 s : " .. tostring(infos.musique))
                end
            end
        end)
    end

    -- (le drop n'est pas annoncé : juste plein de cercles d'un coup, sans boum ni texte)

    -- décompte 3, 2, 1
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
            -- bip... bip... bip... façon borne d'arcade (deux notes à l'octave = son « 8 bits »)
            jouerSon("tic", 0.75, 0.7, nil, 0.16)
            jouerSon("tic", 1.5, 0.35, nil, 0.16)
            flasher(BLANC, 0.15)
            secousse(0.5)
        end
        local attente = infos.debut - maintenantServeur()
        if attente > 0 then
            task.wait(attente)
        end
        if partition == infos then
            afficherDecompte(if jeJoue then "CLICK TO THE BEAT!" else "SPECTATING", OR)
            -- le dernier bip, plus aigu et plus long : GO !
            jouerSon("tic", 1.5, 0.7, nil, 0.4)
            jouerSon("tic", 3, 0.35, nil, 0.4)
            jouerSon("tic", 2, 0.3, 0.08, 0.3)
            flasher(BLANC, 0.5)
            secousse(1)
        end
    end)
end)

-- ========================== FIN DE PARTIE : GAGNANT ET CHECK PARFAIT ==========================
-- Pour bien voir le(s) gagnant(s) : ils sautent dans le couloir de DEVANT (le plus près de la caméra),
-- celui qui était devant est caché, puis ils se tournent vers la caméra pour danser.
-- Égalité : les deux s'élancent l'un vers l'autre, se tapent dans la main en l'air (CLAC !),
-- atterrissent côte à côte et se tournent vers la caméra.
local focusCheck = nil -- si défini, la caméra regarde ce point
local jouerCheck, presenterGagnant
do
local COULOIR_SCENE = 0
local BRAS_LEVE = math.rad(150)

local function versCF(position, sens, tour)
    return CFrame.lookAt(position, position + Vector3.new(sens, 0, 0)) * CFrame.Angles(0, tour or 0, 0)
end

-- on cache ceux qui sont dans le couloir de devant (sauf les gagnants)
local function libererScene(gagnants)
    for _, etat in pairs(avatars) do
        if not table.find(gagnants, etat) and etat.couloir == COULOIR_SCENE then
            etat.cache = true
        end
    end
end

local function preparer(etat)
    etat.saut = nil
    if etat.animAttente then
        etat.animAttente:Stop(0.1)
    end
    if etat.trainee then
        etat.trainee.Enabled = true
    end
end

local function poserSurScene(etat, marche, sens, retardTour)
    poser(etat, nil)
    if etat.trainee then
        etat.trainee.Enabled = false
    end
    if etat.animAttente then
        etat.animAttente:Play(0.2)
    end
    -- il se tourne vers la caméra (petit délai pour le style)
    etat.positionForcee = { couloir = COULOIR_SCENE, marche = marche, sens = sens, versCamera = os.clock() + (retardTour or 0) }
    allumerMarche(COULOIR_SCENE, marche, couleurDe(etat))
    local sol = positionMarche(COULOIR_SCENE, marche, 0.1)
    ondeSol(sol, couleurDe(etat), 6)
    eclats(sol, couleurDe(etat), 12)
    secousse(0.6)
end

-- Un seul gagnant : il saute dans le couloir de devant en faisant une vrille, les bras en l'air
presenterGagnant = function(etat)
    if not (etat and etat.modele and etat.hauteur and etat.couloir) then
        return
    end
    libererScene({ etat })
    preparer(etat)
    local m = math.floor((etat.config:GetAttribute("Marche") or 0) + 0.5)
    local depart = positionMarche(etat.couloir, m, etat.hauteur)
    local fin = positionMarche(COULOIR_SCENE, m, etat.hauteur)
    local t0 = os.clock()
    etat.cinematique = function(horloge)
        local t = horloge - t0
        if t < 0.3 then -- il prend son élan
            local k = t / 0.3
            poser(etat, { LeftKnee = -0.8 * k, RightKnee = -0.8 * k, LeftHip = 0.5 * k, RightHip = 0.5 * k, Waist = -0.25 * k })
            return versCF(depart - Vector3.new(0, 0.6 * k, 0), 1)
        elseif t < 1.05 then -- le saut, vrille, bras en l'air
            local k = (t - 0.3) / 0.75
            local doux = k * k * (3 - 2 * k)
            local bosse = math.sin(math.pi * k)
            poser(etat, { LeftShoulder = BRAS_LEVE * bosse, RightShoulder = BRAS_LEVE * bosse, LeftKnee = -0.6 * bosse, RightKnee = -0.6 * bosse })
            local position = depart:Lerp(fin, doux) + Vector3.new(0, bosse * 5, 0)
            return versCF(position, 1, 2 * math.pi * doux)
        end
        return nil
    end
    etat.finCinematique = function()
        poserSurScene(etat, m, 1, 0.1)
    end
    etatSuiviCamera = etat
end

local function clacParfait(point, couleurA, couleurB)
    sonClaque()
    flasher(BLANC, 0.85)
    secousse(2.5)
    fovPulse = -7
    flou.Size = 12
    tween(flou, 0.5, { Size = 0 })
    eclats(point, couleurA, 30, 1.4)
    eclats(point, couleurB, 30, 1.4)
    eclats(point, OR, 20, 2)
    ondeSol(point, BLANC, 12, true)
    task.delay(0.08, function()
        ondeSol(point, OR, 8, true)
    end)
    grosTexte.TextColor3 = OR
    apparaitre(grosTexte, "PERFECT HIGH FIVE!", 2, echelleGros)
end

jouerCheck = function(configA, configB)
    local a, b = avatars[configA], avatars[configB]
    if not (a and b and a.modele and b.modele and a.hauteur and b.hauteur and a.couloir and b.couloir) then
        return
    end
    libererScene({ a, b })
    local m = math.floor((a.config:GetAttribute("Marche") or 0) + 0.5)
    local D, H = GEO.PROFONDEUR, GEO.HAUTEUR
    local zScene = positionMarche(COULOIR_SCENE, m, 0).Z
    local departA = positionMarche(a.couloir, m, a.hauteur)
    local departB = positionMarche(b.couloir, m, b.hauteur)
    local xMilieu = GEO.X0 + (m + 1) * D
    local yPied = GEO.Y0 + m * H + 4.5 -- ils sautent à 4,5 studs au-dessus de la marche
    local hautA = Vector3.new(xMilieu - 1.1, yPied + a.hauteur, zScene)
    local hautB = Vector3.new(xMilieu + 1.1, yPied + b.hauteur, zScene)
    local finA = positionMarche(COULOIR_SCENE, m, a.hauteur)
    local finB = positionMarche(COULOIR_SCENE, m + 1, b.hauteur) -- B atterrit sur la marche d'après
    local pointClac = Vector3.new(xMilieu, yPied + math.max(a.hauteur, b.hauteur) + 2.6, zScene + 0.6)
    -- la caméra regarde pile le point du check, de face
    focusCheck = Vector3.new(xMilieu, yPied + 1, zScene)
    preparer(a)
    preparer(b)

    local t0 = os.clock()
    -- A lève le bras droit, B (qui se retourne) lève le gauche : les deux mains sont côté caméra
    local function trajectoire(etat, depart, haut, fin, epaule, tourne)
        etat.cinematique = function(horloge)
            local t = horloge - t0
            local position, bras, tour, genoux
            if t < 0.35 then -- il se baisse pour prendre son élan
                local k = t / 0.35
                position = depart - Vector3.new(0, 0.7 * math.sin(k * math.pi / 2), 0)
                bras, tour, genoux = 0.25 * k, 0, k
            elseif t < 0.85 then -- le bond
                local k = (t - 0.35) / 0.5
                local doux = 1 - (1 - k) ^ 3
                position = (depart - Vector3.new(0, 0.7, 0)):Lerp(haut, doux)
                bras, tour, genoux = 0.25 + 0.75 * doux, (if tourne then math.pi * doux else 0), 1 - doux
            elseif t < 1.35 then -- suspendus en l'air après le CLAC
                local k = (t - 0.85) / 0.5
                position = haut + Vector3.new(0, math.sin(k * math.pi) * 0.3, 0)
                bras, tour, genoux = 1, (if tourne then math.pi else 0), 0.3 * math.sin(k * math.pi)
            elseif t < 1.85 then -- ils redescendent
                local k = (t - 1.35) / 0.5
                position = haut:Lerp(fin, k * k) + Vector3.new(0, math.sin(k * math.pi) * 0.8, 0)
                bras, tour, genoux = 1 - k, (if tourne then math.pi else 0), 0.5 * k
            else
                return nil
            end
            poser(etat, { [epaule] = BRAS_LEVE * bras, LeftKnee = -0.7 * genoux, RightKnee = -0.7 * genoux, Waist = -0.15 * genoux })
            return versCF(position, 1, tour)
        end
        etat.finCinematique = function()
            poserSurScene(etat, if etat == a then m else m + 1, if tourne then -1 else 1, 0.45)
            -- la caméra recule un peu pour avoir les deux, de face
            focusCheck = Vector3.new(xMilieu, GEO.Y0 + (m + 0.5) * H + 2.5, zScene)
        end
    end
    trajectoire(a, departA, hautA, finA, "RightShoulder", false)
    trajectoire(b, departB, hautB, finB, "LeftShoulder", true)
    task.delay(0.85, function()
        clacParfait(pointClac, couleurDe(a), couleurDe(b))
    end)
end
end -- fin du bloc du check

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
EvenementEvent.OnClientEvent:Connect(function(typeEvt, a, b)
    if typeEvt == "Vainqueur" then
        local etat = avatars[a]
        jeJoue = false
        viderNotes()
        etatSuiviCamera = etat
        presenterGagnant(etat)
        modeCinema(true)
        tween(effetAura, 0.5, { Saturation = -1, Contrast = 0.4 })
        flasher(OR, 0.7)
        secousse(2)
        if etat then
            grosTexte.TextColor3 = couleurDe(etat)
            apparaitre(
                grosTexte,
                tostring(etat.config:GetAttribute("Nom")) .. " — " .. string.upper(tostring(etat.config:GetAttribute("Perso"))),
                2.2,
                echelleGros
            )
        end
    elseif typeEvt == "Check" then
        jeJoue = false
        viderNotes()
        modeCinema(true)
        tween(effetAura, 0.5, { Saturation = -1, Contrast = 0.4 })
        grosTexte.TextColor3 = BLANC
        apparaitre(grosTexte, "TIE!", 0.8, echelleGros)
        jouerCheck(a, b)
    elseif typeEvt == "Danse" then
        -- a = la liste des gagnants, b = l'heure (serveur) de fin de la danse
        tween(effetAura, 0.6, { Saturation = 0.15, Contrast = 0.15 })
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

-- ========================== CLASSEMENTS ==========================
local boutonClassement, fermerPanneau, ouvrirPanneau
do
boutonClassement = nouveau("TextButton", {
    Position = UDim2.new(0, 20, 0, 70),
    Size = UDim2.fromOffset(200, 44),
    BackgroundColor3 = Color3.fromRGB(14, 14, 22),
    BackgroundTransparency = 0.1,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBlack,
    Text = "LEADERBOARDS",
    TextScaled = true,
    TextColor3 = OR,
    ZIndex = 25,
    Parent = gui,
})
nouveau("UICorner", { CornerRadius = UDim.new(0, 12), Parent = boutonClassement })
nouveau("UIStroke", { Color = OR, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = boutonClassement })
nouveau("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = boutonClassement })
local echelleBoutonClassement = nouveau("UIScale", { Parent = boutonClassement })
boutonClassement.MouseEnter:Connect(function()
    sonSurvol(6)
    tween(echelleBoutonClassement, 0.2, { Scale = 1.06 }, Enum.EasingStyle.Back)
end)
boutonClassement.MouseLeave:Connect(function()
    tween(echelleBoutonClassement, 0.2, { Scale = 1 })
end)

local fondPanneau = nouveau("TextButton", { -- clic à côté du panneau = fermer
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = NOIR,
    BackgroundTransparency = 1,
    AutoButtonColor = false,
    Text = "",
    Visible = false,
    ZIndex = 40,
    Parent = gui,
})
local panneau = nouveau("TextButton", { -- bouton « vide » : un clic sur le panneau ne le ferme pas
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromScale(0.92, 0.88),
    BackgroundColor3 = Color3.fromRGB(12, 12, 18),
    AutoButtonColor = false,
    Text = "",
    ZIndex = 41,
    Parent = fondPanneau,
})
nouveau("UISizeConstraint", { MaxSize = Vector2.new(660, 620), Parent = panneau })
nouveau("UICorner", { CornerRadius = UDim.new(0, 18), Parent = panneau })
nouveau("UIStroke", { Color = OR, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = panneau })
local echellePanneau = nouveau("UIScale", { Parent = panneau })
texte({
    Position = UDim2.new(0, 20, 0, 14),
    Size = UDim2.new(1, -310, 0, 38),
    Text = "LEADERBOARDS",
    TextColor3 = OR,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 42,
    Parent = panneau,
})
-- ce qu'on regarde : « EGO + EMPIRE », « MONDE ENTIER »...
local sousTitre = texte({
    Position = UDim2.new(0, 20, 0, 54),
    Size = UDim2.new(1, -40, 0, 18),
    Text = "Most steps climbed in one game",
    Font = Enum.Font.GothamMedium,
    TextColor3 = Color3.fromRGB(170, 170, 190),
    TextStrokeTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 42,
    Parent = panneau,
})
local boutonFermer = nouveau("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -16, 0, 16),
    Size = UDim2.fromOffset(110, 34),
    BackgroundColor3 = Color3.fromRGB(40, 40, 55),
    AutoButtonColor = false,
    Font = Enum.Font.GothamBlack,
    Text = "CLOSE",
    TextScaled = true,
    TextColor3 = BLANC,
    ZIndex = 42,
    Parent = panneau,
})
nouveau("UICorner", { CornerRadius = UDim.new(0, 10), Parent = boutonFermer })
nouveau("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = boutonFermer })
-- 🌍 le classement du monde entier (toutes musiques, tous états d'esprit, tous les joueurs)
local COULEUR_MONDE = Color3.fromRGB(110, 230, 160)
local boutonMonde = nouveau("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -134, 0, 16),
    Size = UDim2.fromOffset(160, 34),
    BackgroundColor3 = Color3.fromRGB(24, 24, 34),
    AutoButtonColor = false,
    Font = Enum.Font.GothamBlack,
    Text = "WORLDWIDE",
    TextScaled = true,
    TextColor3 = COULEUR_MONDE,
    ZIndex = 42,
    Parent = panneau,
})
nouveau("UICorner", { CornerRadius = UDim.new(0, 10), Parent = boutonMonde })
nouveau("UIStroke", { Color = COULEUR_MONDE, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = boutonMonde })
nouveau("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = boutonMonde })

local function titreRangee(y, message)
    texte({
        Position = UDim2.new(0, 20, 0, y),
        Size = UDim2.new(1, -40, 0, 16),
        Text = message,
        Font = Enum.Font.GothamBlack,
        TextColor3 = Color3.fromRGB(140, 140, 160),
        TextStrokeTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 42,
        Parent = panneau,
    })
end
titreRangee(84, "MINDSETS")
local rangeeOngletsPersos = nouveau("Frame", {
    Position = UDim2.new(0, 20, 0, 104),
    Size = UDim2.new(1, -40, 0, 36),
    BackgroundTransparency = 1,
    ZIndex = 42,
    Parent = panneau,
})
nouveau("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = rangeeOngletsPersos })
titreRangee(150, "SONGS")
local rangeeOngletsMusiques = nouveau("ScrollingFrame", {
    Position = UDim2.new(0, 20, 0, 170),
    Size = UDim2.new(1, -40, 0, 44),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.X,
    ScrollingDirection = Enum.ScrollingDirection.X,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = BLEU_MUSIQUE,
    ZIndex = 42,
    Parent = panneau,
})
nouveau("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = rangeeOngletsMusiques })

local listeClassement = nouveau("ScrollingFrame", {
    Position = UDim2.new(0, 20, 0, 224),
    Size = UDim2.new(1, -40, 1, -284),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = OR,
    ZIndex = 42,
    Parent = panneau,
})
nouveau("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = listeClassement })
local etatListe = texte({
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 260),
    Size = UDim2.new(1, -60, 0, 24),
    Font = Enum.Font.GothamBold,
    TextColor3 = Color3.fromRGB(170, 170, 190),
    TextStrokeTransparency = 1,
    ZIndex = 43,
    Parent = panneau,
})
local monRecordTexte = texte({
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -14),
    Size = UDim2.new(1, -40, 0, 30),
    TextColor3 = OR,
    ZIndex = 42,
    Parent = panneau,
})

local onglets = {} -- [cle] = { bouton, couleur }
-- Ce qu'on regarde : clique un état d'esprit, PUIS une musique → le classement de cette combinaison.
-- (un seul des deux = toutes les musiques / tous les états d'esprit ; MONDE ENTIER = tout)
local choixPerso, choixMusique, modeMonde = nil, nil, false
local demandeClassement = 0
local COULEURS_PODIUM = { OR, Color3.fromRGB(210, 215, 230), Color3.fromRGB(220, 140, 80) }

local function nomOnglet(cle)
    local valeur = cle and dossierClassements:FindFirstChild(cle)
    return if valeur then valeur.Value else "?"
end

local function cleSelection()
    if modeMonde or not (choixPerso or choixMusique) then
        return "G", "WORLDWIDE  ·  the best of all players, every song and mindset"
    end
    if choixPerso and choixMusique then
        return "C_" .. string.sub(choixPerso, 3) .. "_" .. choixMusique, nomOnglet(choixPerso) .. "  +  " .. nomOnglet(choixMusique)
    end
    if choixPerso then
        return choixPerso, nomOnglet(choixPerso) .. "  ·  all songs (also pick a song)"
    end
    return choixMusique, nomOnglet(choixMusique) .. "  ·  all mindsets (also pick a mindset)"
end

local function styleOnglets()
    for cle, o in pairs(onglets) do
        local choisi = not modeMonde and (cle == choixPerso or cle == choixMusique)
        tween(o.bouton, 0.2, { BackgroundColor3 = if choisi then o.couleur else Color3.fromRGB(24, 24, 34) })
        o.bouton.TextColor3 = if choisi then NOIR else o.couleur
    end
    local monde = cleSelection() == "G"
    tween(boutonMonde, 0.2, { BackgroundColor3 = if monde then COULEUR_MONDE else Color3.fromRGB(24, 24, 34) })
    boutonMonde.TextColor3 = if monde then NOIR else COULEUR_MONDE
end

local function ligneClassement(rang, nom, score, estMoi, details)
    local ligne = nouveau("Frame", {
        Size = UDim2.new(1, -8, 0, if details and details.perso then 44 else 34),
        BackgroundTransparency = 1,
        LayoutOrder = rang,
        ZIndex = 42,
        Parent = listeClassement,
    })
    -- le contenu glisse depuis la droite, une ligne après l'autre
    local contenu = nouveau("Frame", {
        Position = UDim2.new(0, 60, 0, 0),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = if estMoi then Color3.fromRGB(60, 52, 20) elseif rang % 2 == 1 then Color3.fromRGB(26, 26, 38) else Color3.fromRGB(20, 20, 30),
        BackgroundTransparency = 1,
        ZIndex = 42,
        Parent = ligne,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 8), Parent = contenu })
    if estMoi then
        nouveau("UIStroke", { Color = OR, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = contenu })
    end
    local couleurRang = COULEURS_PODIUM[rang] or Color3.fromRGB(170, 170, 190)
    local labels = {
        texte({ Position = UDim2.new(0, 10, 0, 5), Size = UDim2.new(0, 40, 1, -10), Text = tostring(rang), TextColor3 = couleurRang, ZIndex = 43, Parent = contenu }),
        texte({
            Position = UDim2.new(0, 60, 0, 6),
            Size = UDim2.new(1, -200, 1, -12),
            Text = nom,
            Font = Enum.Font.GothamBold,
            TextStrokeTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 43,
            Parent = contenu,
        }),
        texte({
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -12, 0, 5),
            Size = UDim2.new(0, 130, 1, -10),
            Text = score .. " steps",
            TextColor3 = couleurRang,
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 43,
            Parent = contenu,
        }),
    }
    -- 🌍 monde entier : avec quel état d'esprit et quelle musique (petite ligne sous le pseudo)
    if details and details.perso then
        local couleurPerso = COULEURS[details.perso] or Color3.fromRGB(170, 170, 190)
        local ligneDetails = texte({
            Position = UDim2.new(0, 60, 0, 25),
            Size = UDim2.new(1, -200, 0, 14),
            Text = string.upper(details.perso) .. "  ·  " .. tostring(details.musique or "?"),
            Font = Enum.Font.GothamBold,
            TextColor3 = couleurPerso,
            TextStrokeTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 43,
            Parent = contenu,
        })
        table.insert(labels, ligneDetails)
        -- le pseudo remonte un peu pour laisser la place
        labels[2].Position = UDim2.new(0, 60, 0, 5)
        labels[2].Size = UDim2.new(1, -200, 0, 18)
    end
    for _, label in ipairs(labels) do
        label.TextTransparency = 1
        label.TextStrokeTransparency = 1
    end
    task.delay(rang * 0.035, function()
        tween(contenu, 0.35, { Position = UDim2.new(), BackgroundTransparency = 0 }, Enum.EasingStyle.Quint)
        for i, label in ipairs(labels) do
            tween(label, 0.3, { TextTransparency = 0, TextStrokeTransparency = if i == 1 or i == 3 then 0.4 else 1 })
        end
    end)
end

local function afficherClassement()
    local cle, description = cleSelection()
    sousTitre.Text = description
    styleOnglets()
    demandeClassement += 1
    local numero = demandeClassement
    for _, enfant in ipairs(listeClassement:GetChildren()) do
        if enfant:IsA("Frame") then
            enfant:Destroy()
        end
    end
    etatListe.Text = "Loading..."
    etatListe.Visible = true
    monRecordTexte.Text = ""
    task.spawn(function()
        local ok, resultat = pcall(function()
            return ClassementFonction:InvokeServer(cle)
        end)
        if numero ~= demandeClassement then
            return -- on a changé d'onglet entre temps
        end
        if not ok or type(resultat) ~= "table" then
            etatListe.Text = "Leaderboard unavailable right now"
            return
        end
        local lignes = resultat.liste or {}
        etatListe.Visible = #lignes == 0
        etatListe.Text = "Nobody yet. Be the first!"
        for rang, l in ipairs(lignes) do
            ligneClassement(rang, tostring(l.nom), l.score or 0, l.userId == joueur.UserId, { perso = l.perso, musique = l.musique })
        end
        local moi = resultat.moi or 0
        monRecordTexte.Text = if moi > 0 then "YOUR RECORD: " .. moi .. " steps" else "YOUR RECORD: none yet"
    end)
end

local function creerOnglet(valeur)
    if onglets[valeur.Name] then
        return
    end
    local estPerso = valeur:GetAttribute("Type") == "Perso"
    local couleur = if estPerso then (COULEURS[string.sub(valeur.Name, 3)] or OR) else BLEU_MUSIQUE
    local bouton = nouveau("TextButton", {
        Size = if estPerso then UDim2.new(0.25, -5, 1, 0) else UDim2.new(0, 0, 1, -8),
        AutomaticSize = if estPerso then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
        BackgroundColor3 = Color3.fromRGB(24, 24, 34),
        AutoButtonColor = false,
        Font = Enum.Font.GothamBlack,
        Text = valeur.Value,
        TextScaled = estPerso,
        TextSize = 15,
        TextColor3 = couleur,
        LayoutOrder = valeur:GetAttribute("Ordre") or 99,
        ZIndex = 43,
        Parent = if estPerso then rangeeOngletsPersos else rangeeOngletsMusiques,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 10), Parent = bouton })
    nouveau("UIStroke", { Color = couleur, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = bouton })
    nouveau("UIPadding", {
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        Parent = bouton,
    })
    local echelle = nouveau("UIScale", { Parent = bouton })
    local note = if estPerso then (valeur:GetAttribute("Ordre") or 1) else 5
    bouton.MouseEnter:Connect(function()
        sonSurvol(note)
        tween(echelle, 0.18, { Scale = 1.06 }, Enum.EasingStyle.Back)
    end)
    bouton.MouseLeave:Connect(function()
        tween(echelle, 0.18, { Scale = 1 })
    end)
    bouton.Activated:Connect(function()
        echelle.Scale = 0.9
        tween(echelle, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
        sonClic(note)
        -- recliquer le même onglet le désélectionne
        modeMonde = false
        if estPerso then
            choixPerso = if choixPerso == valeur.Name then nil else valeur.Name
        else
            choixMusique = if choixMusique == valeur.Name then nil else valeur.Name
        end
        afficherClassement()
    end)
    onglets[valeur.Name] = { bouton = bouton, couleur = couleur }
end
dossierClassements.ChildAdded:Connect(creerOnglet)
for _, valeur in ipairs(dossierClassements:GetChildren()) do
    creerOnglet(valeur)
end

ouvrirPanneau = function()
    if panneauOuvert then
        return
    end
    panneauOuvert = true
    for _, c in ipairs(toutesCartes) do
        c.survole = false
    end
    fondPanneau.Visible = true
    fondPanneau.BackgroundTransparency = 1
    tween(fondPanneau, 0.3, { BackgroundTransparency = 0.45 })
    echellePanneau.Scale = 0.75
    tween(echellePanneau, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
    if not (choixPerso or choixMusique or modeMonde) then
        choixPerso = "P_" .. (persoChoisi or "Motivation")
    end
    afficherClassement()
end
boutonMonde.MouseEnter:Connect(function()
    sonSurvol(7)
end)
boutonMonde.Activated:Connect(function()
    sonClic(7)
    modeMonde = true
    afficherClassement()
end)
fermerPanneau = function()
    if not panneauOuvert then
        return
    end
    panneauOuvert = false
    tween(fondPanneau, 0.2, { BackgroundTransparency = 1 })
    tween(echellePanneau, 0.2, { Scale = 0.8 })
    task.delay(0.2, function()
        if not panneauOuvert then
            fondPanneau.Visible = false
        end
    end)
end
boutonClassement.Activated:Connect(function()
    sonClic(6)
    if panneauOuvert then
        fermerPanneau()
    else
        ouvrirPanneau()
    end
end)
boutonFermer.Activated:Connect(function()
    sonClic(1)
    fermerPanneau()
end)
fondPanneau.Activated:Connect(fermerPanneau)
end -- fin du bloc des classements

-- ========================== PHASES ==========================
local menuPrincipalOuvert = true -- au lancement : le menu principal (PLAY / CLASSEMENTS / PARAMÈTRES)
local modeAfk = false -- AFK : on regarde les autres jouer, on n'est pas lancé dans la partie
local boutonsCoin = {} -- les petits boutons du lobby sous CLASSEMENTS (PARAMÈTRES, AFK, MENU), créés plus bas
local majBandeauAfk -- (défini plus bas)
local function majPhase()
    local phase = ReplicatedStorage:GetAttribute("Phase")
    local enMenu = menuPrincipalOuvert -- tant qu'on n'a pas appuyé sur PLAY, on ne voit que le menu principal
    if phase == "Lobby" and not enMenu and not modeAfk then
        ouvrirMenu()
    else
        fermerMenu()
    end
    statut.Visible = (phase ~= "Lobby" or modeAfk) and not enMenu -- le menu a son propre titre et son chrono
    chrono.afficher((phase ~= "Lobby" or modeAfk) and not enMenu)
    barre.Visible = (phase == "Manche" or phase == "Fin") and not enMenu
    marcheTexte.Visible = phase == "Manche" and not enMenu and not modeAfk
    boutonClassement.Visible = phase ~= "Manche" and not enMenu -- pas pendant qu'on clique les cercles
    for _, bouton in ipairs(boutonsCoin) do
        bouton.Visible = boutonClassement.Visible
    end
    if majBandeauAfk then
        majBandeauAfk()
    end
    if phase == "Manche" then
        fermerPanneau()
    end
    if phase == "Lobby" then
        partition = nil
        jeJoue = false
        etatSuiviCamera = nil
        focusCheck = nil
        arreterDanseUI()
        for _, etat in pairs(avatars) do
            if etat.cinematique then
                etat.cinematique = nil
                if etat.finCinematique then
                    etat.finCinematique()
                end
            end
            etat.positionForcee = nil
            etat.cache = nil
        end
        viderNotes()
        modeCinema(false)
        modeAura = false
        tween(effetAura, 0.5, { Saturation = 0, Contrast = 0, Brightness = 0 })
        couperMusique(1)
    elseif phase == "Fin" then
        jeJoue = false
        viderNotes()
    end
end
ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(majPhase)
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
    fermerPanneau()
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
        if clicsManche == 0 and not modeAfk and not menuPrincipalOuvert then
            passerAfk("No clicks the whole round: AFK MODE on")
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
    Size = UDim2.fromOffset(480, 390),
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
boutonCoin(122, "SETTINGS", Color3.fromRGB(200, 200, 220), function()
    sonClic(4)
    ouvrirReglages()
end)
boutonCoin(170, "AFK", COULEUR_AFK, function()
    if modeAfk then
        allerJouer(false)
    else
        sonClic(3)
        passerAfk(nil)
    end
end)
boutonCoin(218, "MENU", Color3.fromRGB(255, 120, 120), retourMenu)

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
        ouvrirPanneau()
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
local NOMS_CASES = { "STEPS", "ACCURACY", "PERFECTS", "MAX COMBO" }
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
        return "Combo max x" .. data.comboMax .. ". He'll tell everyone."
    elseif data.perso == "Motivation" then
        return "Fiery start... and then?"
    elseif data.perso == "Discipline" then
        return "Steps lost: 0. Obviously."
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
    local valeurs = { { data.marches, "" }, { data.precision, " %" }, { data.parfaits, "" }, { data.comboMax, "" } }
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


-- ========================== BOUCLE D'AFFICHAGE ==========================
local positionCamera = nil
local pointsCarte = {} -- [config] = point sur la mini-carte
local dernierSuiviAfk = nil -- celui que la caméra suit en mode AFK

RunService.RenderStepped:Connect(function(dt)
    local horloge = os.clock()

    -- 1) Les avatars montent les marches pied par pied (avec style)
    for _, etat in pairs(avatars) do
        local modele = etat.modele
        if modele and modele.Parent and etat.hauteur then
            local cfCinematique = etat.cinematique and etat.cinematique(horloge)
            if etat.cinematique and not cfCinematique then
                -- fin de la cinématique (gagnant / check parfait)
                etat.cinematique = nil
                if etat.finCinematique then
                    etat.finCinematique()
                end
            end
            if etat.cache then
                modele:PivotTo(CFrame.new(0, -500, 0)) -- caché pendant la scène de fin
            elseif cfCinematique then
                modele:PivotTo(cfCinematique)
            else
                local m = etat.config:GetAttribute("Marche") or 0
                local arc, rotation, pose = 0, CFrame.identity, nil
                if etat.saut then
                    local s = etat.saut
                    local t = math.clamp((horloge - s.debut) / s.duree, 0, 1)
                    if s.monte then
                        -- quel pas, et où on en est dans ce pas
                        local progres = t * s.pas
                        local numeroPas = math.min(math.floor(progres), s.pas - 1)
                        local k = progres - numeroPas
                        local lisseK = k * k * (3 - 2 * k)
                        m = s.de + (s.a - s.de) * (numeroPas + lisseK) / s.pas
                        local bosse = math.sin(math.pi * k)
                        local pied = (s.pied + numeroPas) % 2
                        arc = bosse * (0.35 + 0.3 * s.style) -- petit rebond à chaque pas
                        pose = posePas(pied, k, s.style)
                        -- penché en avant + léger déhanché du côté du pied qui monte
                        rotation = CFrame.Angles(-bosse * 0.12, (if pied == 0 then 1 else -1) * bosse * 0.15, 0)
                        if s.vrille and numeroPas == s.pas - 1 then
                            rotation = rotation * CFrame.Angles(0, 2 * math.pi * lisseK, 0)
                        end
                        -- chaque pied posé allume sa marche
                        local faits = if t >= 1 then s.pas else math.floor(progres)
                        while s.pasFaits < faits do
                            s.pasFaits += 1
                            local numero = math.floor(s.de + (s.a - s.de) * s.pasFaits / s.pas + 0.5)
                            piedPose(etat, numero, s.pasFaits == s.pas and (s.pas >= 2 or s.vrille))
                        end
                    else
                        -- raté : il trébuche en arrière, les bras en l'air
                        local lisse = t * t * (3 - 2 * t)
                        m = s.de + (s.a - s.de) * lisse
                        local bosse = math.sin(math.pi * t)
                        arc = bosse * 0.6
                        rotation = CFrame.Angles(bosse * 0.6, 0, 0)
                        pose = { LeftShoulder = 2.4 * bosse, RightShoulder = 2.1 * bosse, LeftHip = 0.6 * bosse, RightKnee = -0.7 * bosse }
                    end
                    if t >= 1 then
                        etat.saut = nil
                        pose = nil
                        if etat.animChute then
                            etat.animChute:Stop(0.15)
                        end
                        atterrir(etat, s)
                    end
                end
                poser(etat, pose)
                etat.marcheAffichee = m
                local forcee = etat.positionForcee
                local couloir = if forcee then forcee.couloir else etat.couloir
                if forcee then
                    m = forcee.marche
                end
                if couloir then
                    local position = positionMarche(couloir, m, etat.hauteur) + Vector3.new(0, arc, 0)
                    local direction = Vector3.new(1, 0, 0)
                    if forcee then
                        -- scène de fin : il se tourne vers la caméra
                        local k = math.clamp((horloge - forcee.versCamera) / 0.4, 0, 1)
                        k = k * k * (3 - 2 * k)
                        direction = Vector3.new(forcee.sens * (1 - k), 0, k)
                    end
                    modele:PivotTo(CFrame.lookAt(position, position + direction) * rotation)
                else
                    modele:PivotTo(CFrame.new(0, -500, 0)) -- plus de place : caché
                end
            end
        end
    end

    -- 2) Caméra 2D : vue de côté qui suit ton avatar ; à la fin, de face sur le(s) gagnant(s)
    -- (dans le menu 3D, c'est le script MindsetHub qui tient la caméra)
    local camera = workspace.CurrentCamera
    if camera and not menuPrincipalOuvert then
        camera.CameraType = Enum.CameraType.Scriptable
        local focus
        local decalage = Vector3.new(7, 3, 0)
        local distance = 75
        local vitesseCamera = 5
        local suiviModele = etatSuiviCamera and etatSuiviCamera.modele
        if not partition then
            dernierSuiviAfk = nil -- nouvelle manche : on réaffichera le nom de celui qu'on suit
        end
        if focusCheck then
            focus = focusCheck
            decalage = Vector3.new(0, 1, 0)
            distance = 26
            vitesseCamera = 4
        elseif suiviModele and suiviModele.Parent then
            focus = suiviModele:GetPivot().Position
            decalage = Vector3.new(0, 1.2, 0)
            distance = 22
            vitesseCamera = 4
        elseif modeAfk and not menuPrincipalOuvert and partition and not jeJoue then
            -- AFK / spectateur pendant une manche : la caméra suit celui qui est en tête
            local enTete = nil
            for _, etat in pairs(avatars) do
                if etat.config:GetAttribute("EnJeu") and etat.couloir and etat.hauteur
                    and (not enTete or (etat.marcheAffichee or 0) > (enTete.marcheAffichee or 0)) then
                    enTete = etat
                end
            end
            if enTete then
                focus = positionMarche(enTete.couloir, enTete.marcheAffichee or 0, enTete.hauteur)
                vitesseCamera = 3
                distance = 58 -- un peu plus près pour bien le voir jouer
                if enTete ~= dernierSuiviAfk then
                    dernierSuiviAfk = enTete
                    majBandeauAfk(tostring(enTete.config:GetAttribute("Nom")) .. " (leading)")
                end
            else
                focus = positionMarche(2, 30 + 24 * math.sin(horloge * 0.06), 3)
                distance = 100
                vitesseCamera = 1.2
            end
        elseif menuOuvert or menuPrincipalOuvert or modeAfk then
            -- menu du lobby : la caméra se balade doucement le long des escaliers (floutés derrière le menu)
            focus = positionMarche(2, 30 + 24 * math.sin(horloge * 0.06), 3)
            distance = 100
            vitesseCamera = 1.2
        elseif monEtat and monEtat.couloir and monEtat.hauteur then
            focus = positionMarche(monEtat.couloir, monEtat.marcheAffichee or 0, monEtat.hauteur)
        else
            focus = positionMarche(0, 0, 3)
        end
        local cible = focus + decalage + Vector3.new(0, 0, distance)
        positionCamera = if positionCamera then positionCamera:Lerp(cible, math.min(1, dt * vitesseCamera)) else cible
        forceSecousse = math.max(0, forceSecousse - dt * 4)
        local tremble = Vector3.new((math.random() - 0.5) * forceSecousse, (math.random() - 0.5) * forceSecousse, 0)
        local roulis = (math.random() - 0.5) * forceSecousse * 0.01
        local oeil = positionCamera + tremble
        camera.CFrame = CFrame.lookAt(oeil, oeil - Vector3.new(0, 0, 1)) * CFrame.Angles(0, 0, roulis)
        fovPulse += (0 - fovPulse) * math.min(1, dt * 8)
        camera.FieldOfView = FOV_BASE + fovPulse

        -- les escaliers infinis se construisent autour de la caméra, le fond la suit
        majEscaliers((positionCamera.X - GEO.X0) / GEO.PROFONDEUR)
        fondScene.Position = Vector3.new(positionCamera.X, positionCamera.Y, FOND_Z)
        poussiere.Position = Vector3.new(positionCamera.X, positionCamera.Y, FOND_Z + 8)
    end

    -- 3) Musique, temps et notes
    if partition then
        local maintenant = maintenantServeur()
        local ecoule = maintenant - partition.debut

        if partition.musique ~= "" and ecoule >= 0 and ecoule < partition.duree + 4 then
            local attendu = partition.debutMusique + ecoule
            if not musiqueLancee then
                musiqueLancee = true
                musique.TimePosition = attendu
                musique:Play()
            elseif horloge - dernierRecalage > 0.5 and musique.IsPlaying then
                -- On recolle la musique au rythme SANS la faire sauter (sauter = la musique saccade) :
                -- on l'accélère ou la ralentit très légèrement (2 % max, inaudible) pour qu'elle rattrape.
                -- On ne saute que si elle est vraiment perdue (plus de 0,4 s d'écart deux fois de suite).
                dernierRecalage = horloge
                local ecart = musique.TimePosition - attendu
                if math.abs(ecart) > 0.4 then
                    trainsPerdus += 1
                    if trainsPerdus >= 2 then
                        trainsPerdus = 0
                        musique.TimePosition = attendu
                        musique.PlaybackSpeed = 1
                    end
                else
                    trainsPerdus = 0
                    musique.PlaybackSpeed = if math.abs(ecart) > 0.03 then 1 - math.clamp(ecart * 0.5, -0.02, 0.02) else 1
                end
            end
        elseif ecoule >= partition.duree + 4 and musique.IsPlaying then
            couperMusique(1)
        end

        local tempsMusique = ecoule - partition.decalage
        if tempsMusique >= 0 and ecoule < partition.duree then
            local numero = math.floor(tempsMusique / intervalle)
            if numero ~= dernierTemps then
                dernierTemps = numero
                surTemps(numero)
            end
        end

        if jeJoue then
            while partition.notes[prochaineNote] and partition.notes[prochaineNote] - APPROCHE <= ecoule do
                creerNote(prochaineNote, partition.notes[prochaineNote])
                prochaineNote += 1
            end
            for index, note in pairs(notesActives) do
                if ecoule > note.temps + FENETRE_MAX then
                    juger(index, true)
                end
            end
        end
    end

    -- 4) Compteur de marches + mini-carte
    if monEtat then
        marcheTexte.Text = "🪜 " .. (monEtat.config:GetAttribute("Marche") or 0) .. " steps"
        marcheTexte.TextColor3 = maCouleur()
    end
    if barre.Visible then
        -- pas de sommet : le haut de la barre = le premier (au moins 10 marches)
        local plusHaut = 0
        for _, etat in pairs(avatars) do
            plusHaut = math.max(plusHaut, etat.config:GetAttribute("Marche") or 0)
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
            local taille = if etat.estMoi then 22 else 14
            point.Size = UDim2.fromOffset(taille, taille)
            point.BackgroundColor3 = couleurDe(etat)
            point.Position = UDim2.fromScale(0.5, 1 - math.clamp((etat.marcheAffichee or 0) / echelleBarre, 0, 1))
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
