--[[
    🌍 AURA SIMULATOR — Script CLIENT
    À mettre dans : StarterPlayer > StarterPlayerScripts  (type : LocalScript, nom : MindsetClient)
    ⚠️ C'est le SEUL script client du jeu.

    Ce script s'occupe de tout ce que TU vois et fais :
      - SE BATTRE contre les monstres : clic (ou maintenir le clic) = combo de 4 coups · bouton AUTO · sur téléphone : bouton PUNCH
      - les effets : étincelles, chiffres de dégâts, l'aura qui vole vers toi, l'EDIT NOIR ET BLANC des gros moments
      - l'interface : ton aura, tes stats, la prochaine zone, la boutique (améliorations, classes, renaissance)
      - l'ambiance de chaque zone (lumière, couleurs), les portes des zones, les phrases de la trend style TikTok
      - la musique, les paramètres et la langue (anglais / français)
    (le serveur, lui, décide de tout : les dégâts, l'aura, les achats)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local joueur = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("MindsetRemotes")
local FrapperEvent = remotes:WaitForChild("Frapper")
local ImpactEvent = remotes:WaitForChild("Impact")
local MortEvent = remotes:WaitForChild("Mort")
local CoupEvent = remotes:WaitForChild("Coup")
local EvenementEvent = remotes:WaitForChild("Evenement")
local MessageEvent = remotes:WaitForChild("Message")
local ReglagesEvent = remotes:WaitForChild("Reglages")
local AcheterFonction = remotes:WaitForChild("Acheter")

local function lireJson(texteJson, defaut)
    local ok, valeur = pcall(function()
        return HttpService:JSONDecode(texteJson)
    end)
    return if ok and type(valeur) == "table" then valeur else defaut
end
while not ReplicatedStorage:GetAttribute("Config") do
    task.wait(0.1)
end
local CONFIG = lireJson(ReplicatedStorage:GetAttribute("Config"), {})
local function couleurDe(rgb)
    return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end
local ZONES, ZONE_PAR_NOM = CONFIG.zones or {}, {}
for i, zone in ipairs(ZONES) do
    zone.index = i
    zone.couleur = couleurDe(zone.couleur)
    ZONE_PAR_NOM[zone.nom] = zone
end
local PERSOS = CONFIG.persos or {}
for _, p in pairs(PERSOS) do
    p.couleur = couleurDe(p.couleur)
end
local ORDRE_PERSOS = CONFIG.ordrePersos or { "Spark", "Flow", "Star", "Fury" }
local AMELIOS = CONFIG.ameliorations or {}
local RENAISSANCE = CONFIG.renaissance or { prixBase = 250000, croissance = 4, bonusAura = 0.5, bonusDegats = 0.25 }

local BLANC = Color3.new(1, 1, 1)
local NOIR = Color3.new(0, 0, 0)
local OR = Color3.fromRGB(255, 220, 80)
local ROUGE = Color3.fromRGB(255, 70, 70)
local GRIS = Color3.fromRGB(165, 165, 180)
local VERT = Color3.fromRGB(110, 230, 160)
local FOND = Color3.fromRGB(12, 12, 16)
local GRIS_FONCE = Color3.fromRGB(45, 45, 60)

local surMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local Actions = {} -- les fonctions que les blocs se partagent (ouvrirBoutique, basculerAuto...)

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
    proprietes.Font = proprietes.Font or Enum.Font.GothamBlack
    proprietes.TextScaled = true
    proprietes.TextColor3 = proprietes.TextColor3 or BLANC
    proprietes.TextStrokeTransparency = proprietes.TextStrokeTransparency or 1
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

local function enCouleur(mot, couleur)
    return string.format('<font color="#%02X%02X%02X">%s</font>', math.floor(couleur.R * 255), math.floor(couleur.G * 255), math.floor(couleur.B * 255), mot)
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

-- les infos du joueur (publiées par le serveur dans ses attributs)
local function attributJson(nom)
    local brut = joueur:GetAttribute(nom)
    return if type(brut) == "string" then lireJson(brut, {}) else {}
end
local function monAura()
    local stats = joueur:FindFirstChild("leaderstats")
    local aura = stats and stats:FindFirstChild("Aura")
    return if aura then aura.Value else 0
end

-- les commandes de Roblox (marcher, sauter) sont actives
task.spawn(function()
    local ok, module = pcall(function()
        return require(joueur:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
    end)
    if ok and module then
        module:GetControls():Enable()
    end
end)

-- ========================== RÉGLAGES + SONS ==========================
-- ⚙️ PARAMÈTRES du joueur (réglés dans le menu « SETTINGS », sauvegardés par le serveur)
local REGLAGES = { musique = 1, bruitages = 1, secousses = true, flashs = true, langue = "auto" }
local groupeMusique = nouveau("SoundGroup", { Name = "MindsetGroupeMusique", Volume = 1, Parent = SoundService })
local groupeBruitages = nouveau("SoundGroup", { Name = "MindsetGroupeBruitages", Volume = 1, Parent = SoundService })

local gui = nouveau("ScreenGui", {
    Name = "MindsetGui",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 5,
    Parent = joueur:WaitForChild("PlayerGui"),
})

-- 🔊 les sons (les « rbxasset:// » sont fournis avec Roblox : ils marchent toujours)
local jouerSon, sonClic, sonSurvol
do
local SONS = {
    tic = "rbxasset://sounds/volume_slider.ogg",
    clic = "rbxassetid://12221967",
    boum = "rbxasset://sounds/impact_explosion_03.mp3",
    pose = "rbxasset://sounds/action_jump_land.mp3",
    swoosh = "rbxasset://sounds/swordlunge.wav",
    coup = "rbxasset://sounds/hit.wav",
    eau = "rbxasset://sounds/impact_water.mp3",
    verre = "rbxasset://sounds/glassbreak.wav",
}
local modeles = {}
for nom, id in pairs(SONS) do
    modeles[nom] = nouveau("Sound", { Name = "MindsetSon_" .. nom, SoundId = id, Volume = 0.5, SoundGroup = groupeBruitages, Parent = SoundService })
end
-- coupe = au bout de combien de secondes on coupe le son (en fondu), pour garder juste l'attaque
jouerSon = function(nom, vitesse, volume, retard, coupe)
    local modele = modeles[nom]
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
local GAMME = { 1, 1.122, 1.26, 1.498, 1.682, 2, 2.245 }
sonSurvol = function(note)
    jouerSon("tic", 2.1 * (1 + ((GAMME[note] or 1) - 1) * 0.45), 0.12, nil, 0.09)
end
sonClic = function(note)
    local base = GAMME[note] or 1
    jouerSon("clic", 1, 0.6)
    jouerSon("tic", base * 0.75, 0.45)
    jouerSon("tic", base * 1.5, 0.35, 0.07)
end
end -- fin du bloc des sons

-- un bouton de l'interface (contour de couleur, grossit au survol)
local function bouton(proprietes, couleur, plein)
    proprietes.AutoButtonColor = false
    proprietes.Font = Enum.Font.GothamBlack
    proprietes.TextScaled = true
    proprietes.BackgroundColor3 = if plein then couleur else FOND
    proprietes.TextColor3 = if plein then NOIR else couleur
    proprietes.BackgroundTransparency = if plein then 0 else 0.12
    local b = nouveau("TextButton", proprietes)
    nouveau("UICorner", { CornerRadius = UDim.new(0, 10), Parent = b })
    local contour = nouveau("UIStroke", { Color = couleur, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
    nouveau("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = b })
    local echelle = nouveau("UIScale", { Parent = b })
    b.MouseEnter:Connect(function()
        sonSurvol(4)
        tween(echelle, 0.12, { Scale = 1.06 })
    end)
    b.MouseLeave:Connect(function()
        tween(echelle, 0.12, { Scale = 1 })
    end)
    return b, contour
end

-- ========================== LES EFFETS « EDIT » ==========================
-- Le style des edits de la trend : le noir et blanc très contrasté, les « impact frames »,
-- les bandes de cinéma, les légendes style TikTok, les secousses de caméra.
local effetEdit = nouveau("ColorCorrectionEffect", { Name = "MindsetEdit", Parent = Lighting })
local forceSecousse = 0
local fovPulse = 0
local FOV_BASE = 70

local function secousse(force)
    forceSecousse = math.max(forceSecousse, force * (if REGLAGES.secousses then 1 else 0))
end

-- ⏸️ le HITSTOP : l'image se fige une fraction de seconde sur un coup (comme dans les animes et les jeux de combat)
local gelJusqua, imageGelee = 0, nil
local function hitstop(duree)
    if os.clock() + duree > gelJusqua then
        gelJusqua = os.clock() + duree
    end
end

RunService:BindToRenderStep("MindsetCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    if os.clock() < gelJusqua then
        imageGelee = imageGelee or camera.CFrame
        camera.CFrame = imageGelee
        return
    end
    imageGelee = nil
    forceSecousse = math.max(0, forceSecousse - dt * 5)
    fovPulse += (0 - fovPulse) * math.min(1, dt * 7)
    if forceSecousse > 0.01 then
        local f = forceSecousse * 0.35
        camera.CFrame = camera.CFrame * CFrame.new((math.random() - 0.5) * f, (math.random() - 0.5) * f, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * f * 0.03)
    end
    if camera.CameraType == Enum.CameraType.Custom then
        camera.FieldOfView = FOV_BASE + fovPulse
    end
end)

local flash = nouveau("Frame", { BackgroundColor3 = BLANC, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 60, Parent = gui })
local function flasher(couleur, force)
    if not REGLAGES.flashs then
        return
    end
    flash.BackgroundColor3 = couleur
    flash.BackgroundTransparency = 1 - force
    tween(flash, 0.4, { BackgroundTransparency = 1 })
end

-- 🎞️ IMPACT FRAME : l'image devient noire, puis blanche, en un éclair
local cadreImpact = nouveau("Frame", { BackgroundColor3 = NOIR, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 59, Parent = gui })
local function impactFrame()
    if not REGLAGES.flashs then
        return
    end
    cadreImpact.BackgroundColor3 = NOIR
    cadreImpact.BackgroundTransparency = 0.15
    task.delay(0.05, function()
        cadreImpact.BackgroundColor3 = BLANC
        cadreImpact.BackgroundTransparency = 0.35
        tween(cadreImpact, 0.18, { BackgroundTransparency = 1 })
    end)
end

-- 🖤 L'EDIT NOIR ET BLANC (pendant « duree » secondes, puis la couleur revient en douceur)
local numeroEdit = 0
local function editNoirEtBlanc(duree, force)
    numeroEdit += 1
    local numero = numeroEdit
    force = force or 1
    effetEdit.Saturation = -1
    effetEdit.Contrast = 0.3 + 0.4 * force
    effetEdit.Brightness = -0.03
    fovPulse = -8 * force
    task.delay(duree, function()
        if numero == numeroEdit then
            tween(effetEdit, 0.6, { Saturation = 0, Contrast = 0, Brightness = 0 })
        end
    end)
end

-- les bandes noires de cinéma
local bandeHaut = nouveau("Frame", { BackgroundColor3 = NOIR, BorderSizePixel = 0, Size = UDim2.fromScale(1, 0), ZIndex = 40, Parent = gui })
local bandeBas = nouveau("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BackgroundColor3 = NOIR, BorderSizePixel = 0, Size = UDim2.fromScale(1, 0), ZIndex = 40, Parent = gui })
local numeroCinema = 0
local function modeCinema(duree)
    numeroCinema += 1
    local numero = numeroCinema
    tween(bandeHaut, 0.3, { Size = UDim2.fromScale(1, 0.09) })
    tween(bandeBas, 0.3, { Size = UDim2.fromScale(1, 0.09) })
    task.delay(duree, function()
        if numero == numeroCinema then
            tween(bandeHaut, 0.4, { Size = UDim2.fromScale(1, 0) })
            tween(bandeBas, 0.4, { Size = UDim2.fromScale(1, 0) })
        end
    end)
end

-- le GROS TEXTE du milieu, en couleurs
local annoncer
do
local grosTexte = texte({
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.36),
    Size = UDim2.new(0.9, 0, 0, 80),
    RichText = true,
    TextStrokeTransparency = 0,
    TextStrokeColor3 = NOIR,
    TextTransparency = 1,
    ZIndex = 45,
    Parent = gui,
})
nouveau("UISizeConstraint", { MaxSize = Vector2.new(1000, 80), Parent = grosTexte })
local sousGrosTexte = texte({
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0.36, 46),
    Size = UDim2.new(0.6, 0, 0, 30),
    Font = Enum.Font.GothamBold,
    RichText = true,
    TextColor3 = Color3.fromRGB(230, 230, 240),
    TextStrokeTransparency = 0.2,
    TextTransparency = 1,
    ZIndex = 45,
    Parent = gui,
})
local echelleGros = nouveau("UIScale", { Parent = grosTexte })
local numeroGros = 0
annoncer = function(message, sousMessage, duree)
    numeroGros += 1
    local numero = numeroGros
    grosTexte.Text = message
    sousGrosTexte.Text = sousMessage or ""
    grosTexte.TextTransparency, grosTexte.TextStrokeTransparency = 0, 0
    sousGrosTexte.TextTransparency, sousGrosTexte.TextStrokeTransparency = 0, 0.2
    echelleGros.Scale = 1.9
    tween(echelleGros, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
    task.delay(duree or 2, function()
        if numero == numeroGros then
            tween(grosTexte, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
            tween(sousGrosTexte, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
        end
    end)
end
end -- fin du bloc du gros texte

-- 💬 LA LÉGENDE style TikTok (en bas, blanc avec un gros contour noir, lettre par lettre)
local dire
do
local legende = texte({
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.72),
    Size = UDim2.new(0.86, 0, 0, 42),
    TextStrokeColor3 = NOIR,
    TextStrokeTransparency = 0,
    TextTransparency = 1,
    ZIndex = 44,
    Parent = gui,
})
nouveau("UISizeConstraint", { MaxSize = Vector2.new(900, 42), Parent = legende })
local trait = nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.fromOffset(0, 4), BorderSizePixel = 0, BackgroundColor3 = BLANC, ZIndex = 44, Parent = legende })
local echelle = nouveau("UIScale", { Parent = legende })
local enCours, attente = false, {}
local function montrer(message, couleur)
    enCours = true
    legende.Text = message
    legende.TextTransparency, legende.TextStrokeTransparency = 0, 0
    legende.MaxVisibleGraphemes = 0
    trait.BackgroundColor3 = couleur or BLANC
    trait.Size = UDim2.fromOffset(0, 4)
    tween(trait, 0.6, { Size = UDim2.fromOffset(220, 4) }, Enum.EasingStyle.Quint)
    echelle.Scale = 1.15
    tween(echelle, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
    task.spawn(function()
        task.wait() -- (le temps que le texte soit traduit)
        local debut = os.clock()
        local total = utf8.len(legende.Text) or #legende.Text
        while os.clock() - debut < 0.5 do
            legende.MaxVisibleGraphemes = math.floor(total * (os.clock() - debut) / 0.5)
            task.wait()
        end
        legende.MaxVisibleGraphemes = -1
        task.wait(2.2)
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
dire = function(message, couleur, prioritaire)
    if enCours then
        if prioritaire then
            attente = { { message, couleur } }
        elseif #attente < 2 then
            table.insert(attente, { message, couleur })
        end
        return
    end
    montrer(message, couleur)
end
end -- fin du bloc de la légende

-- 🔔 petits messages en haut
local notifier
do
local pile = nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.fromOffset(460, 140), BackgroundTransparency = 1, ZIndex = 30, Parent = gui })
nouveau("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pile })
local ordre = 0
notifier = function(message, couleur)
    ordre += 1
    local cadre = nouveau("Frame", { Size = UDim2.fromOffset(440, 30), BackgroundColor3 = FOND, BackgroundTransparency = 0.15, LayoutOrder = ordre, ZIndex = 30, Parent = pile })
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = cadre })
    nouveau("UIStroke", { Color = couleur or BLANC, Thickness = 1.5, Parent = cadre })
    local label = texte({ Position = UDim2.fromOffset(14, 5), Size = UDim2.new(1, -28, 1, -10), Text = message, TextColor3 = couleur or BLANC, ZIndex = 31, Parent = cadre })
    local echelle = nouveau("UIScale", { Scale = 0.6, Parent = cadre })
    tween(echelle, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
    task.delay(3, function()
        tween(cadre, 0.3, { BackgroundTransparency = 1 })
        tween(label, 0.3, { TextTransparency = 1 })
        task.wait(0.32)
        cadre:Destroy()
    end)
    if #pile:GetChildren() > 5 then
        for _, enfant in ipairs(pile:GetChildren()) do
            if enfant:IsA("Frame") then
                enfant:Destroy()
                break
            end
        end
    end
end
end -- fin du bloc des messages

-- ✨ étincelles et ondes de choc en 3D
local dossierEffets = nouveau("Folder", { Name = "MindsetEffetsLocaux", Parent = workspace })
local eclats, onde
do
local porte = nouveau("Part", { Name = "Eclats", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), Parent = dossierEffets })
local emetteur = nouveau("ParticleEmitter", {
    Rate = 0,
    Lifetime = NumberRange.new(0.25, 0.6),
    Speed = NumberRange.new(10, 26),
    SpreadAngle = Vector2.new(180, 180),
    Drag = 5,
    Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
    LightEmission = 1,
    Parent = porte,
})
eclats = function(position, couleur, nombre, vitesse)
    porte.Position = position
    emetteur.Color = ColorSequence.new(couleur, BLANC)
    emetteur.Speed = NumberRange.new(10 * (vitesse or 1), 26 * (vitesse or 1))
    emetteur:Emit(nombre)
end
-- un anneau qui s'agrandit (à plat au sol)
onde = function(position, couleur, taille, duree)
    local anneau = nouveau("Part", {
        Name = "Onde",
        Anchored = true,
        CanCollide = false,
        CanQuery = false,
        CanTouch = false,
        CastShadow = false,
        Shape = Enum.PartType.Cylinder,
        Material = Enum.Material.Neon,
        Color = couleur,
        Transparency = 0.1,
        Size = Vector3.new(0.15, 1, 1),
        CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2),
        Parent = dossierEffets,
    })
    tween(anneau, duree or 0.35, { Size = Vector3.new(0.15, taille, taille), Transparency = 1 })
    task.delay((duree or 0.35) + 0.02, function()
        anneau:Destroy()
    end)
end
end -- fin du bloc des étincelles

-- un texte qui flotte en 3D et monte (« -26 », « +1.2K »)
local function texteFlottant(position, message, couleur, taille, duree)
    local support = nouveau("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), Position = position, Parent = dossierEffets })
    local billboard = nouveau("BillboardGui", { Size = UDim2.fromOffset(160 * taille, 44 * taille), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 120, Parent = support })
    local label = texte({ Size = UDim2.fromScale(1, 1), Text = message, TextColor3 = couleur, TextStrokeTransparency = 0, TextStrokeColor3 = NOIR, Parent = billboard })
    local echelle = nouveau("UIScale", { Scale = 1.6, Parent = label })
    tween(echelle, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
    duree = duree or 0.8
    tween(billboard, duree, { StudsOffsetWorldSpace = Vector3.new((math.random() - 0.5) * 2, 3, 0) })
    task.delay(duree * 0.55, function()
        tween(label, duree * 0.45, { TextTransparency = 1, TextStrokeTransparency = 1 })
    end)
    task.delay(duree + 0.05, function()
        support:Destroy()
    end)
end

-- ========================== L'INTERFACE ==========================
local majHUD
do
-- ---------- en haut à gauche : ton aura et tes stats ----------
local carte = nouveau("Frame", { Position = UDim2.fromOffset(16, 62), Size = UDim2.fromOffset(270, 104), BackgroundColor3 = FOND, BackgroundTransparency = 0.2, ZIndex = 10, Parent = gui })
nouveau("UICorner", { CornerRadius = UDim.new(0, 14), Parent = carte })
nouveau("UIStroke", { Color = OR, Thickness = 2, Transparency = 0.2, Parent = carte })
texte({ Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(120, 16), Text = "AURA", Font = Enum.Font.GothamBold, TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = carte })
local texteAura = texte({ Position = UDim2.fromOffset(14, 24), Size = UDim2.fromOffset(240, 42), Text = "0", TextColor3 = OR, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = carte })
local echelleAura = nouveau("UIScale", { Parent = texteAura })
local texteStats = texte({ Position = UDim2.fromOffset(16, 70), Size = UDim2.fromOffset(240, 15), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(220, 220, 232), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = carte })
local texteStats2 = texte({ Position = UDim2.fromOffset(16, 86), Size = UDim2.fromOffset(240, 13), Font = Enum.Font.GothamMedium, TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = carte })

-- ---------- la prochaine zone à débloquer ----------
local cadreSuivante = nouveau("Frame", { Position = UDim2.fromOffset(16, 174), Size = UDim2.fromOffset(270, 44), BackgroundColor3 = FOND, BackgroundTransparency = 0.25, ZIndex = 10, Parent = gui })
nouveau("UICorner", { CornerRadius = UDim.new(0, 10), Parent = cadreSuivante })
local contourSuivante = nouveau("UIStroke", { Color = BLANC, Thickness = 1.5, Transparency = 0.3, Parent = cadreSuivante })
local texteSuivante = texte({ Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -24, 0, 16), Font = Enum.Font.GothamBold, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = cadreSuivante })
local railSuivante = nouveau("Frame", { Position = UDim2.fromOffset(12, 27), Size = UDim2.new(1, -24, 0, 8), BackgroundColor3 = GRIS_FONCE, BorderSizePixel = 0, ZIndex = 11, Parent = cadreSuivante })
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = railSuivante })
local rempliSuivante = nouveau("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = BLANC, BorderSizePixel = 0, ZIndex = 12, Parent = railSuivante })
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rempliSuivante })

-- ---------- la série de DISCIPLINE ----------
local cadreSerie = nouveau("Frame", { Position = UDim2.fromOffset(16, 226), Size = UDim2.fromOffset(270, 34), BackgroundColor3 = FOND, BackgroundTransparency = 0.25, Visible = false, ZIndex = 10, Parent = gui })
nouveau("UICorner", { CornerRadius = UDim.new(0, 10), Parent = cadreSerie })
nouveau("UIStroke", { Color = PERSOS.Flow and PERSOS.Flow.couleur or BLANC, Thickness = 1.5, Parent = cadreSerie })
local texteSerie = texte({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 16), Font = Enum.Font.GothamBlack, TextColor3 = PERSOS.Flow and PERSOS.Flow.couleur or BLANC, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = cadreSerie })
local railSerie = nouveau("Frame", { Position = UDim2.fromOffset(12, 23), Size = UDim2.new(1, -24, 0, 5), BackgroundColor3 = GRIS_FONCE, BorderSizePixel = 0, ZIndex = 11, Parent = cadreSerie })
local rempliSerie = nouveau("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = PERSOS.Flow and PERSOS.Flow.couleur or BLANC, BorderSizePixel = 0, ZIndex = 12, Parent = railSerie })
local derniereSerie, heureSerie = 0, 0
joueur:GetAttributeChangedSignal("Serie"):Connect(function()
    local s = joueur:GetAttribute("Serie") or 0
    if s > derniereSerie then
        heureSerie = os.clock()
        if s > 0 and s % 10 == 0 and joueur:GetAttribute("Perso") == "Flow" then
            dire("Unstoppable flow.", PERSOS.Flow.couleur)
        end
    end
    derniereSerie = s
end)

-- ---------- la bannière de la zone (en haut au milieu) ----------
local banniere = texte({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.fromOffset(600, 46), TextTransparency = 1, TextStrokeTransparency = 1, TextStrokeColor3 = NOIR, RichText = true, ZIndex = 20, Parent = gui })
local sousBanniere = texte({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(500, 22), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(230, 230, 240), TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 20, Parent = gui })
local echelleBanniere = nouveau("UIScale", { Parent = banniere })
local numeroBanniere = 0
Actions.banniere = function(titre, sousTitre, couleur)
    numeroBanniere += 1
    local numero = numeroBanniere
    banniere.Text = enCouleur(titre, couleur)
    sousBanniere.Text = sousTitre
    banniere.TextTransparency, banniere.TextStrokeTransparency = 0, 0
    sousBanniere.TextTransparency, sousBanniere.TextStrokeTransparency = 0, 0.3
    echelleBanniere.Scale = 0.6
    tween(echelleBanniere, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
    task.delay(3.2, function()
        if numero == numeroBanniere then
            tween(banniere, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
            tween(sousBanniere, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
        end
    end)
end

-- ---------- en bas au milieu : tes PV et ton niveau ----------
local cadreVie = nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.fromOffset(380, 24), BackgroundColor3 = FOND, BackgroundTransparency = 0.15, ZIndex = 10, Parent = gui })
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = cadreVie })
nouveau("UIStroke", { Color = BLANC, Thickness = 1.5, Transparency = 0.4, Parent = cadreVie })
local traineeVie = nouveau("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 230, 230), BorderSizePixel = 0, ZIndex = 11, Parent = cadreVie })
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = traineeVie })
local rempliVie = nouveau("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(235, 60, 70), BorderSizePixel = 0, ZIndex = 12, Parent = cadreVie })
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rempliVie })
local texteVie = texte({ Size = UDim2.fromScale(1, 1), TextStrokeTransparency = 0.3, ZIndex = 13, Parent = cadreVie })
nouveau("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = texteVie })
local cadreXp = nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(380, 10), BackgroundColor3 = FOND, BackgroundTransparency = 0.15, ZIndex = 10, Parent = gui })
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = cadreXp })
local rempliXp = nouveau("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(110, 190, 255), BorderSizePixel = 0, ZIndex = 11, Parent = cadreXp })
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rempliXp })
local texteNiveau = texte({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0, -10, 1, 2), Size = UDim2.fromOffset(90, 30), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(140, 200, 255), TextStrokeTransparency = 0.3, ZIndex = 11, Parent = cadreVie })
local partVieAffichee = 1

-- ---------- l'aide (jusqu'au premier monstre battu) ----------
local aide = texte({
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -76),
    Size = UDim2.fromOffset(520, 22),
    Text = if surMobile then "Walk to a monster and hold PUNCH to fight" else "Walk to a monster and CLICK (or hold) to fight",
    Font = Enum.Font.GothamBold,
    TextStrokeTransparency = 0.3,
    ZIndex = 10,
    Parent = gui,
})
Actions.cacherAide = function()
    if aide.Visible then
        tween(aide, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
        task.delay(0.5, function()
            aide.Visible = false
        end)
    end
end

-- ---------- les boutons à droite ----------
local colonne = nouveau("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, -20), Size = UDim2.fromOffset(150, 250), BackgroundTransparency = 1, ZIndex = 10, Parent = gui })
nouveau("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = colonne })
local function boutonColonne(message, couleur, ordre, action)
    local b = bouton({ Size = UDim2.fromOffset(150, 40), Text = message, LayoutOrder = ordre, ZIndex = 11, Parent = colonne }, couleur, false)
    b.Activated:Connect(function()
        sonClic(3 + ordre % 4)
        action(b)
    end)
    return b
end
boutonColonne("SHOP", OR, 1, function()
    Actions.ouvrirBoutique("Ameliorations")
end)
boutonColonne("CLASSES", Color3.fromRGB(200, 140, 255), 2, function()
    Actions.ouvrirBoutique("Persos")
end)
boutonColonne("REBIRTH", BLANC, 3, function()
    Actions.ouvrirBoutique("Renaissance")
end)
local boutonAuto, contourAuto = bouton({ Size = UDim2.fromOffset(150, 40), Text = "AUTO: OFF", LayoutOrder = 4, ZIndex = 11, Parent = colonne }, GRIS, false)
Actions.afficherAuto = function(actif)
    boutonAuto.Text = if actif then "AUTO: ON" else "AUTO: OFF"
    boutonAuto.TextColor3 = if actif then NOIR else GRIS
    boutonAuto.BackgroundColor3 = if actif then VERT else FOND
    boutonAuto.BackgroundTransparency = if actif then 0 else 0.12
    contourAuto.Color = if actif then VERT else GRIS
end
boutonAuto.Activated:Connect(function()
    sonClic(5)
    Actions.basculerAuto()
end)
boutonColonne("SETTINGS", Color3.fromRGB(200, 200, 220), 5, function()
    Actions.ouvrirReglages()
end)

-- ---------- sur téléphone : le gros bouton PUNCH ----------
if UserInputService.TouchEnabled then
    local b = bouton({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -170), Size = UDim2.fromOffset(96, 96), Text = "PUNCH", ZIndex = 12, Parent = gui }, OR, false)
    b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
    b.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            Actions.appuyer(true)
        end
    end)
    b.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            Actions.appuyer(false)
        end
    end)
end

-- ---------- l'aura affichée compte jusqu'à la vraie ----------
local auraAffichee = 0
Actions.popAura = function()
    echelleAura.Scale = 1.25
    tween(echelleAura, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function prochaineZone()
    local zones = attributJson("Zones")
    for _, zone in ipairs(ZONES) do
        if not zones[zone.nom] then
            return zone
        end
    end
    return nil
end

majHUD = function(dt)
    local vraie = monAura()
    if math.abs(vraie - auraAffichee) < 1 then
        auraAffichee = vraie
    else
        auraAffichee += (vraie - auraAffichee) * math.min(1, dt * 10)
    end
    texteAura.Text = court(auraAffichee)
    local degats = joueur:GetAttribute("Degats") or 1
    local par = 1 / (joueur:GetAttribute("Intervalle") or 0.5)
    local mult = joueur:GetAttribute("MultAura") or 1
    texteStats.Text = court(degats) .. " DMG  ·  " .. string.format("%.1f", par) .. "/s  ·  x" .. string.format("%.2f", mult):gsub("%.?0+$", "") .. " AURA"
    local perso = joueur:GetAttribute("Perso") or "Spark"
    local rebirths = joueur:GetAttribute("Rebirths") or 0
    texteStats2.Text = string.upper(perso) .. "  ·  REBIRTHS " .. rebirths
    texteStats2.TextColor3 = if PERSOS[perso] then PERSOS[perso].couleur:Lerp(BLANC, 0.3) else GRIS

    local suivante = prochaineZone()
    if suivante then
        cadreSuivante.Visible = true
        local part = math.clamp(vraie / math.max(1, suivante.prix), 0, 1)
        texteSuivante.Text = "NEXT ZONE: " .. enCouleur(suivante.titre, suivante.couleur) .. "  ·  " .. court(suivante.prix) .. " AURA"
        rempliSuivante.Size = UDim2.fromScale(part, 1)
        rempliSuivante.BackgroundColor3 = if part >= 1 then VERT else suivante.couleur
        contourSuivante.Color = if part >= 1 then VERT else BLANC
    else
        cadreSuivante.Visible = false
    end

    -- PV (avec une traînée claire qui descend doucement) + niveau et XP
    local humanoid = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local part = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
        rempliVie.Size = UDim2.fromScale(part, 1)
        partVieAffichee = if part > partVieAffichee then part else partVieAffichee + (part - partVieAffichee) * math.min(1, dt * 3)
        traineeVie.Size = UDim2.fromScale(partVieAffichee, 1)
        texteVie.Text = court(math.ceil(humanoid.Health)) .. " / " .. court(humanoid.MaxHealth) .. " HP"
    end
    texteNiveau.Text = "LV " .. (joueur:GetAttribute("Niveau") or 1)
    rempliXp.Size = UDim2.fromScale(math.clamp((joueur:GetAttribute("Xp") or 0) / math.max(1, joueur:GetAttribute("XpMax") or 1), 0, 1), 1)

    local serie = joueur:GetAttribute("Serie") or 0
    if perso == "Flow" and serie > 0 then
        cadreSerie.Visible = true
        local s = CONFIG.serie or { delai = 8, bonus = 0.02, max = 1 }
        texteSerie.Text = "STREAK x" .. serie .. "  ·  +" .. math.floor(math.min(s.max, serie * s.bonus) * 100 + 0.5) .. "% AURA"
        rempliSerie.Size = UDim2.fromScale(math.clamp(1 - (os.clock() - heureSerie) / s.delai, 0, 1), 1)
    else
        cadreSerie.Visible = false
    end
end
end -- fin du bloc de l'interface

-- ========================== LE COMBAT : FRAPPER ==========================
-- Combo de 4 : droite, gauche, droite, puis un GROS COUP des deux bras (le serveur fait x2 et envoie voler)
do
local PORTEE = CONFIG.portee or 7
local dossierMonstres = workspace:WaitForChild("MindsetMonstres")
local appuye, auto = false, false
local prochaine = 0
local combo, dernierCoup = 0, 0
local originaux = setmetatable({}, { __mode = "k" })

-- l'épaule (R15 ou R6) et l'axe pour lever le bras vers l'avant
local function epaule(personnage, nom)
    local hautBras = personnage:FindFirstChild(nom .. "UpperArm")
    local m = hautBras and hautBras:FindFirstChild(nom .. "Shoulder")
    if m and m:IsA("Motor6D") then
        return m, true
    end
    local torse = personnage:FindFirstChild("Torso")
    m = torse and torse:FindFirstChild(nom .. " Shoulder")
    if m and m:IsA("Motor6D") then
        return m, false
    end
    return nil
end

local function animerCoup(personnage, n)
    local cotes = if n == 4 then { "Right", "Left" } elseif n % 2 == 1 then { "Right" } else { "Left" }
    for _, nom in ipairs(cotes) do
        local m, r15 = epaule(personnage, nom)
        if m then
            local angle = math.rad(if n == 4 then 150 else 95)
            local rotation = if r15 then CFrame.Angles(angle, 0, 0) else CFrame.Angles(0, 0, if nom == "Right" then angle else -angle)
            local origine = originaux[m] or m.C0
            originaux[m] = origine
            tween(m, 0.05, { C0 = origine * rotation })
            task.delay(if n == 4 then 0.2 else 0.11, function()
                if m.Parent then
                    tween(m, 0.14, { C0 = origine })
                end
            end)
        end
    end
end

local function cibleProche(racine)
    local meilleur, score = nil, math.huge
    local zones = attributJson("Zones")
    local devant = racine.CFrame.LookVector
    for _, modele in ipairs(dossierMonstres:GetChildren()) do
        local corps = modele.PrimaryPart
        if corps and not modele:GetAttribute("Mort") and zones[modele:GetAttribute("Zone") or ""] then
            local ecart = corps.Position - racine.Position
            local d = ecart.Magnitude - (modele:GetAttribute("Taille") or 4) * 0.5
            if d <= PORTEE then
                -- on préfère celui qui est devant soi
                local s = d - (if ecart.Magnitude > 0.1 and ecart.Unit:Dot(devant) > 0.3 then 3 else 0)
                if s < score then
                    meilleur, score = modele, s
                end
            end
        end
    end
    return meilleur
end

local function frapper(manuel)
    local personnage = joueur.Character
    local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
    local humanoid = personnage and personnage:FindFirstChildOfClass("Humanoid")
    if not racine or not humanoid or humanoid.Health <= 0 or humanoid.PlatformStand then
        return
    end
    local maintenant = os.clock()
    if maintenant < prochaine then
        return
    end
    local cible = cibleProche(racine)
    if not cible and not manuel then
        return
    end
    prochaine = maintenant + math.max(0.1, joueur:GetAttribute("Intervalle") or 0.45)
    if maintenant - dernierCoup > 1.1 then
        combo = 0
    end
    combo = combo % 4 + 1
    dernierCoup = maintenant
    animerCoup(personnage, combo)
    jouerSon("swoosh", (if combo == 4 then 1.05 else 1.4) + math.random() * 0.3, if combo == 4 then 0.3 else 0.18, nil, 0.2)
    if cible then
        -- on se tourne vers le monstre (et le gros coup fait avancer)
        local p = cible.PrimaryPart.Position
        local regard = Vector3.new(p.X, racine.Position.Y, p.Z)
        if (regard - racine.Position).Magnitude > 0.5 then
            racine.CFrame = CFrame.lookAt(racine.Position, regard)
        end
        if combo == 4 then
            racine.AssemblyLinearVelocity += racine.CFrame.LookVector * 22
        end
        FrapperEvent:FireServer(cible)
    end
end

Actions.appuyer = function(etat)
    appuye = etat
    if etat then
        frapper(true)
    end
end
Actions.basculerAuto = function()
    auto = not auto
    Actions.afficherAuto(auto)
    notifier(if auto then "AUTO PUNCH: ON (stay near monsters)" else "AUTO PUNCH: OFF", if auto then VERT else GRIS)
end

UserInputService.InputBegan:Connect(function(input, dejaPris)
    if dejaPris then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Actions.appuyer(true)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        appuye = false
    end
end)
RunService.Heartbeat:Connect(function()
    if appuye or auto then
        frapper(appuye)
    end
end)
end -- fin du bloc pour frapper

-- ========================== LES MONSTRES (ce que tu vois) ==========================
do
local dossierMonstres = workspace:WaitForChild("MindsetMonstres")

local function couleurZone(nom)
    local zone = ZONE_PAR_NOM[nom or ""]
    return if zone then zone.couleur else BLANC
end

-- le monstre flashe d'une couleur (blanc quand on le tape, rouge quand il prépare une attaque)
local function flasherMonstre(modele, couleur, depart, duree)
    local ancien = modele:FindFirstChild("MindsetFlash")
    if ancien then
        ancien:Destroy()
    end
    local h = nouveau("Highlight", {
        Name = "MindsetFlash",
        FillColor = couleur,
        OutlineColor = couleur,
        FillTransparency = depart,
        OutlineTransparency = 0.1,
        DepthMode = Enum.HighlightDepthMode.Occluded,
        Parent = modele,
    })
    tween(h, duree, { FillTransparency = 1, OutlineTransparency = 1 })
    task.delay(duree + 0.05, function()
        if h.Parent then
            h:Destroy()
        end
    end)
    return h
end

-- les bras du golem
local originauxBras = setmetatable({}, { __mode = "k" })
local function bras(modele, rotation, duree)
    for _, nom in ipairs({ "BrasGauche", "BrasDroit" }) do
        local b = modele:FindFirstChild(nom)
        local m = b and b:FindFirstChild("Epaule")
        if m then
            local origine = originauxBras[m] or m.C0
            originauxBras[m] = origine
            tween(m, duree, { C0 = origine * rotation }, Enum.EasingStyle.Quad)
        end
    end
end

-- ⚠️ chaque monstre : on regarde quand il prépare une attaque, et quand il frappe
local function suivreMonstre(modele)
    local cercle = nil
    modele:GetAttributeChangedSignal("Attaque"):Connect(function()
        local corps = modele.PrimaryPart
        if not corps or modele:GetAttribute("Mort") then
            return
        end
        local camera = workspace.CurrentCamera
        if camera and (camera.CFrame.Position - corps.Position).Magnitude > 140 then
            return
        end
        local preparation = modele:GetAttribute("Preparation") or 0.6
        local taille = modele:GetAttribute("Taille") or 4
        -- rouge qui monte + « ! » au-dessus de la tête + les bras qui se lèvent
        local h = flasherMonstre(modele, ROUGE, 0.9, preparation + 0.1)
        h.FillTransparency = 0.9
        tween(h, preparation, { FillTransparency = 0.35 })
        texteFlottant(corps.Position + Vector3.new(0, taille * 1.1 + 2, 0), "!", ROUGE, 1.1, preparation)
        bras(modele, CFrame.Angles(math.rad(160), 0, 0), preparation * 0.85)
        local rayon = modele:GetAttribute("Rayon")
        if rayon then
            -- le BOSS : un cercle rouge au sol = la zone qu'il va frapper
            if cercle then
                cercle:Destroy()
            end
            cercle = nouveau("Part", {
                Name = "ZoneBoss",
                Anchored = true,
                CanCollide = false,
                CanQuery = false,
                CanTouch = false,
                CastShadow = false,
                Shape = Enum.PartType.Cylinder,
                Material = Enum.Material.Neon,
                Color = ROUGE,
                Transparency = 0.55,
                Size = Vector3.new(0.2, 2, 2),
                CFrame = CFrame.new(corps.Position - Vector3.new(0, taille * 0.5 - 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2),
                Parent = dossierEffets,
            })
            tween(cercle, preparation, { Size = Vector3.new(0.2, rayon * 2, rayon * 2) })
            jouerSon("tic", 0.5, 0.5)
        end
    end)
    modele:GetAttributeChangedSignal("Frappe"):Connect(function()
        local corps = modele.PrimaryPart
        if not corps then
            return
        end
        local taille = modele:GetAttribute("Taille") or 4
        local sol = corps.Position - Vector3.new(0, taille * 0.5 - 0.2, 0)
        local couleur = couleurZone(modele:GetAttribute("Zone"))
        bras(modele, CFrame.Angles(math.rad(-25), 0, 0), 0.07)
        task.delay(0.12, function()
            bras(modele, CFrame.new(), 0.3)
        end)
        local camera = workspace.CurrentCamera
        local distance = if camera then (camera.CFrame.Position - corps.Position).Magnitude else 0
        if distance < 120 then
            onde(sol, couleur:Lerp(ROUGE, 0.4), (modele:GetAttribute("Rayon") or taille) * 2.2, 0.35)
            eclats(sol, couleur, 12, 1.2)
            jouerSon("pose", 0.7, 0.35)
        end
        if cercle then
            cercle:Destroy()
            cercle = nil
            secousse(if distance < 60 then 1 else 0.3)
            jouerSon("boum", 0.75, 0.5)
            flasher(ROUGE, 0.12)
        end
    end)
    modele.AncestryChanged:Connect(function()
        if not modele.Parent and cercle then
            cercle:Destroy()
            cercle = nil
        end
    end)
end
for _, modele in ipairs(dossierMonstres:GetChildren()) do
    suivreMonstre(modele)
end
dossierMonstres.ChildAdded:Connect(suivreMonstre)

-- 👊 un monstre prend un coup : flash blanc, éclats, chiffre, et (si c'est toi) le petit arrêt sur image
ImpactEvent.OnClientEvent:Connect(function(modele, degats, attaquant, critique, lourd)
    local corps = modele and modele.PrimaryPart
    local camera = workspace.CurrentCamera
    if not corps or not camera or (camera.CFrame.Position - corps.Position).Magnitude > 130 then
        return
    end
    local couleur = couleurZone(modele:GetAttribute("Zone"))
    local taille = modele:GetAttribute("Taille") or 4
    local moi = attaquant == joueur
    flasherMonstre(modele, BLANC, 0.05, 0.16)
    eclats(corps.Position, couleur:Lerp(BLANC, 0.3), if moi then (if lourd then 22 else 10) else 4, if lourd then 2 else 1.1)
    if not moi then
        return
    end
    local couleurChiffre = if critique then OR elseif lourd then Color3.fromRGB(255, 150, 60) else BLANC
    texteFlottant(corps.Position + Vector3.new(0, taille * 0.6, 0), (if critique then "CRIT " else "") .. court(degats), couleurChiffre, if lourd or critique then 1.25 else 0.85, 0.7)
    jouerSon("coup", (if lourd then 0.7 else 0.9) + math.random() * 0.25, if lourd then 0.5 else 0.32)
    if lourd then
        hitstop(0.08)
        secousse(0.55)
        fovPulse = -5
        onde(corps.Position, BLANC, taille * 2.4, 0.25)
        jouerSon("boum", 1.3, 0.3)
    else
        hitstop(0.035)
        secousse(if critique then 0.35 else 0.12)
    end
end)

-- 🤕 un monstre t'a touché : tu recules, l'écran flashe rouge
CoupEvent.OnClientEvent:Connect(function(direction, force, degats)
    local personnage = joueur.Character
    local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
    local humanoid = personnage and personnage:FindFirstChildOfClass("Humanoid")
    if not racine or not humanoid then
        return
    end
    humanoid.PlatformStand = true
    racine.AssemblyLinearVelocity = direction * force + Vector3.new(0, force * 0.45, 0)
    task.delay(0.3, function()
        if humanoid.Parent then
            humanoid.PlatformStand = false
        end
    end)
    flasher(ROUGE, 0.3)
    secousse(0.7)
    hitstop(0.05)
    jouerSon("coup", 0.6, 0.5)
    texteFlottant(racine.Position + Vector3.new(0, 3, 0), "-" .. court(degats), ROUGE, 1, 0.7)
    if degats >= humanoid.MaxHealth * 0.3 then
        impactFrame()
    end
end)

-- 💥 un monstre est battu : il explose (le serveur fait voler les morceaux), et ton aura vole vers toi
local orbes = {}
local noteOrbe = 0
MortEvent.OnClientEvent:Connect(function(position, gain, xp, typeMonstre, nomZone, taille)
    local camera = workspace.CurrentCamera
    local proche = camera and (camera.CFrame.Position - position).Magnitude < 160
    if not proche and gain <= 0 then
        return
    end
    local couleur = couleurZone(nomZone)
    local gros = typeMonstre ~= "Petit"
    eclats(position, couleur, if typeMonstre == "Boss" then 90 elseif gros then 40 else 24, if gros then 2.2 else 1.5)
    onde(position - Vector3.new(0, (taille or 4) * 0.45, 0), couleur, (taille or 4) * 3.2, 0.45)
    if proche then
        jouerSon("boum", if gros then 0.9 else 1.3, if gros then 0.5 else 0.3)
    end
    if gain <= 0 then
        return
    end
    Actions.cacherAide()
    local nombre = if typeMonstre == "Boss" then 26 elseif gros then 10 else 4
    for i = 1, nombre do
        local boule = nouveau("Part", {
            Shape = Enum.PartType.Ball,
            Size = Vector3.new(0.9, 0.9, 0.9),
            Material = Enum.Material.Neon,
            Color = if i % 3 == 0 then BLANC else couleur:Lerp(OR, 0.5),
            Anchored = true,
            CanCollide = false,
            CanQuery = false,
            CanTouch = false,
            CastShadow = false,
            Position = position,
            Parent = dossierEffets,
        })
        local direction = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.3, math.random() - 0.5).Unit
        table.insert(orbes, { part = boule, depart = position, eclatement = position + direction * (3 + math.random() * 4), debut = os.clock() + i * 0.025, duree = 0.55 + math.random() * 0.2 })
    end
    texteFlottant(position + Vector3.new(0, (taille or 4) * 0.7 + 1.5, 0), "+" .. court(gain) .. " AURA", OR, if gros then 1.3 else 0.95, 1.1)
    if xp > 0 then
        texteFlottant(position + Vector3.new(0, (taille or 4) * 0.7 + 0.2, 0), "+" .. court(xp) .. " XP", Color3.fromRGB(140, 200, 255), 0.75, 1.1)
    end
    if typeMonstre == "Gros" then
        hitstop(0.09)
        flasher(BLANC, 0.15)
        secousse(0.45)
    elseif typeMonstre == "Boss" then
        local zone = ZONE_PAR_NOM[nomZone]
        local nom = if zone and zone.noms then zone.noms.Boss else "BOSS"
        hitstop(0.15)
        editNoirEtBlanc(1.8, 1)
        impactFrame()
        modeCinema(2.4)
        secousse(1.2)
        jouerSon("boum", 0.7, 0.7)
        annoncer(enCouleur(nom, couleur) .. " DEFEATED", "+" .. court(gain) .. " AURA", 2.6)
        dire("Too much aura.", couleur, true)
    end
end)

RunService.RenderStepped:Connect(function()
    local personnage = joueur.Character
    local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
    local t = os.clock()
    for i = #orbes, 1, -1 do
        local o = orbes[i]
        local age = t - o.debut
        if age >= 0 then
            local cible = if racine then racine.Position else o.depart
            local p
            if age < 0.18 then
                local a = age / 0.18
                p = o.depart:Lerp(o.eclatement, 1 - (1 - a) * (1 - a))
            else
                local a = math.clamp((age - 0.18) / o.duree, 0, 1)
                p = o.eclatement:Lerp(cible, a * a)
            end
            o.part.Position = p
            if age >= 0.18 + o.duree then
                o.part:Destroy()
                table.remove(orbes, i)
                noteOrbe = noteOrbe % 7 + 1
                jouerSon("tic", 1.6 + noteOrbe * 0.12, 0.14, nil, 0.08)
                Actions.popAura()
            end
        end
    end
end)
end -- fin du bloc des monstres

-- ========================== LA BOUTIQUE ==========================
-- 3 onglets : UPGRADES (le marchand) · CLASSES · REBIRTH (la renaissance)
do
local fond = nouveau("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = NOIR, BackgroundTransparency = 1, AutoButtonColor = false, Text = "", Visible = false, ZIndex = 50, Parent = gui })
local cadre = nouveau("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(660, 460), BackgroundColor3 = FOND, AutoButtonColor = false, Text = "", ZIndex = 51, Parent = fond })
nouveau("UICorner", { CornerRadius = UDim.new(0, 18), Parent = cadre })
local contourCadre = nouveau("UIStroke", { Color = OR, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = cadre })
local echelleCadre = nouveau("UIScale", { Parent = cadre })

local onglets = {}
local pages = {}
local ongletActuel = "Ameliorations"
local ORDRE_ONGLETS = {
    { cle = "Ameliorations", nom = "UPGRADES", couleur = OR },
    { cle = "Persos", nom = "CLASSES", couleur = Color3.fromRGB(200, 140, 255) },
    { cle = "Renaissance", nom = "REBIRTH", couleur = BLANC },
}
local texteAuraBoutique = texte({ Position = UDim2.fromOffset(24, 64), Size = UDim2.fromOffset(400, 20), Font = Enum.Font.GothamBold, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 52, Parent = cadre })
local fermer = bouton({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 16), Size = UDim2.fromOffset(100, 34), Text = "CLOSE", ZIndex = 52, Parent = cadre }, Color3.fromRGB(200, 200, 220), false)
for i, o in ipairs(ORDRE_ONGLETS) do
    local b, contour = bouton({ Position = UDim2.fromOffset(24 + (i - 1) * 140, 16), Size = UDim2.fromOffset(130, 36), Text = o.nom, ZIndex = 52, Parent = cadre }, o.couleur, false)
    onglets[o.cle] = { bouton = b, contour = contour, couleur = o.couleur }
    pages[o.cle] = nouveau("Frame", { Position = UDim2.fromOffset(20, 94), Size = UDim2.new(1, -40, 1, -112), BackgroundTransparency = 1, Visible = false, ZIndex = 52, Parent = cadre })
end

-- acheter (la réponse du serveur : ok, ou la raison du refus)
local achatEnCours = false
local majBoutique
local function acheter(quoi, nom, silencieux)
    if achatEnCours then
        return false
    end
    achatEnCours = true
    local ok, resultat = AcheterFonction:InvokeServer(quoi, nom)
    achatEnCours = false
    if ok then
        if not silencieux then
            sonClic(6)
        end
    else
        if not silencieux then
            jouerSon("tic", 0.6, 0.5)
            notifier(tostring(resultat), ROUGE)
        end
    end
    majBoutique()
    return ok, resultat
end

-- ---------- UPGRADES ----------
local lignes = {}
local function formatValeur(cle, v)
    if cle == "Force" then
        return court(v)
    elseif cle == "Rapidite" then
        return string.format("%.1f", 1 / v)
    elseif cle == "Aimant" then
        return "+" .. math.floor(v) .. "%"
    elseif cle == "Vitalite" then
        return court(v) .. " HP"
    end
    return tostring(math.floor(v))
end
for i, def in ipairs(AMELIOS) do
    local ligne = nouveau("Frame", { Position = UDim2.fromOffset(0, (i - 1) * 84), Size = UDim2.new(1, 0, 0, 76), BackgroundColor3 = Color3.fromRGB(22, 22, 30), ZIndex = 53, Parent = pages.Ameliorations })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 12), Parent = ligne })
    local nomL = texte({ Position = UDim2.fromOffset(16, 9), Size = UDim2.fromOffset(300, 24), Text = def.nom, TextColor3 = OR, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 54, Parent = ligne })
    local effet = texte({ Position = UDim2.fromOffset(16, 37), Size = UDim2.fromOffset(330, 16), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(220, 220, 232), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 54, Parent = ligne })
    local niveau = texte({ Position = UDim2.fromOffset(16, 56), Size = UDim2.fromOffset(200, 13), Font = Enum.Font.GothamMedium, TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 54, Parent = ligne })
    local acheterB, contourA = bouton({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -96, 0.5, 0), Size = UDim2.fromOffset(150, 44), Text = "", ZIndex = 54, Parent = ligne }, VERT, true)
    local maxB, contourM = bouton({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(76, 44), Text = "MAX", ZIndex = 54, Parent = ligne }, VERT, false)
    lignes[i] = { def = def, effet = effet, niveau = niveau, acheter = acheterB, contourA = contourA, max = maxB, contourM = contourM, nom = nomL }
    acheterB.Activated:Connect(function()
        acheter("Amelioration", def.cle)
    end)
    -- MAX : on achète autant de niveaux que possible
    maxB.Activated:Connect(function()
        local achetes = 0
        for _ = 1, 100 do
            local ok = acheter("Amelioration", def.cle, true)
            if not ok then
                break
            end
            achetes += 1
        end
        if achetes > 0 then
            sonClic(7)
            notifier(def.nom .. " +" .. achetes, VERT)
        else
            jouerSon("tic", 0.6, 0.5)
            notifier("Not enough aura", ROUGE)
        end
    end)
end

-- ---------- CLASSES ----------
local cartes = {}
for i, nom in ipairs(ORDRE_PERSOS) do
    local p = PERSOS[nom]
    if p then
        local carte = nouveau("Frame", { Position = UDim2.new((i - 1) * 0.25, 4, 0, 0), Size = UDim2.new(0.25, -8, 1, -4), BackgroundColor3 = Color3.fromRGB(22, 22, 30), ZIndex = 53, Parent = pages.Persos })
        nouveau("UICorner", { CornerRadius = UDim.new(0, 12), Parent = carte })
        local contour = nouveau("UIStroke", { Color = p.couleur, Thickness = 2, Transparency = 0.5, Parent = carte })
        local barre = nouveau("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = p.couleur, BorderSizePixel = 0, ZIndex = 54, Parent = carte })
        nouveau("UICorner", { CornerRadius = UDim.new(0, 12), Parent = barre })
        texte({ Position = UDim2.fromOffset(10, 16), Size = UDim2.new(1, -20, 0, 26), Text = string.upper(nom), TextColor3 = p.couleur, ZIndex = 54, Parent = carte })
        texte({ Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -20, 0, 30), Text = p.devise, Font = Enum.Font.GothamMedium, TextWrapped = true, TextColor3 = GRIS, ZIndex = 54, Parent = carte })
        texte({ Position = UDim2.fromOffset(10, 88), Size = UDim2.new(1, -20, 0, 18), Text = p.passif.nom, TextColor3 = BLANC, ZIndex = 54, Parent = carte })
        texte({ Position = UDim2.fromOffset(10, 110), Size = UDim2.new(1, -20, 0, 120), Text = p.passif.texte, Font = Enum.Font.GothamMedium, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(215, 215, 228), ZIndex = 54, Parent = carte })
        local b, contourB = bouton({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -20, 0, 42), Text = "", ZIndex = 54, Parent = carte }, p.couleur, true)
        cartes[nom] = { bouton = b, contourB = contourB, contour = contour, couleur = p.couleur, prix = p.prix }
        b.Activated:Connect(function()
            acheter("Perso", nom)
        end)
    end
end

-- ---------- REBIRTH ----------
local pageR = pages.Renaissance
texte({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 40), Text = "REBIRTH", ZIndex = 53, Parent = pageR })
local texteRebirths = texte({ Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 22), Font = Enum.Font.GothamBold, RichText = true, ZIndex = 53, Parent = pageR })
local texteBonus = texte({ Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 20), Font = Enum.Font.GothamBold, RichText = true, TextColor3 = Color3.fromRGB(220, 220, 232), ZIndex = 53, Parent = pageR })
texte({ Position = UDim2.fromOffset(40, 116), Size = UDim2.new(1, -80, 0, 40), Text = "You lose your aura and your upgrades.\nYou keep your zones and your classes.", Font = Enum.Font.GothamMedium, TextColor3 = GRIS, ZIndex = 53, Parent = pageR })
local railR = nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 176), Size = UDim2.new(0.8, 0, 0, 14), BackgroundColor3 = GRIS_FONCE, BorderSizePixel = 0, ZIndex = 53, Parent = pageR })
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = railR })
local rempliR = nouveau("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = BLANC, BorderSizePixel = 0, ZIndex = 54, Parent = railR })
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rempliR })
local texteRailR = texte({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 196), Size = UDim2.new(0.8, 0, 0, 16), Font = Enum.Font.GothamBold, TextColor3 = GRIS, ZIndex = 53, Parent = pageR })
local boutonR, contourR = bouton({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 232), Size = UDim2.fromOffset(300, 54), Text = "", ZIndex = 53, Parent = pageR }, BLANC, true)
boutonR.Activated:Connect(function()
    local ok = acheter("Renaissance", nil, true)
    if ok then
        Actions.fermerBoutique()
    else
        jouerSon("tic", 0.6, 0.5)
        notifier("Not enough aura", ROUGE)
    end
end)

local function prixRenaissance(n)
    return math.floor(RENAISSANCE.prixBase * RENAISSANCE.croissance ^ n)
end

-- tout remettre à jour (prix, niveaux, boutons)
majBoutique = function()
    local aura = monAura()
    texteAuraBoutique.Text = "YOUR AURA: " .. enCouleur(court(aura), OR)
    local niveaux = attributJson("Niveaux")
    for _, l in ipairs(lignes) do
        local n = niveaux[l.def.cle] or 0
        local auMax = n >= l.def.max
        local actuelle = formatValeur(l.def.cle, l.def.valeurs[n + 1] or 0)
        if auMax then
            l.effet.Text = l.def.texte .. ": " .. actuelle
            l.acheter.Text = "MAX LEVEL"
        else
            l.effet.Text = l.def.texte .. ": " .. actuelle .. " → " .. formatValeur(l.def.cle, l.def.valeurs[n + 2] or 0)
            l.acheter.Text = "BUY · " .. court(l.def.prix[n + 1] or 0)
        end
        l.niveau.Text = "LV " .. n .. " / " .. l.def.max
        local peut = not auMax and aura >= (l.def.prix[n + 1] or math.huge)
        l.acheter.BackgroundColor3 = if peut then VERT else GRIS_FONCE
        l.acheter.TextColor3 = if peut then NOIR else GRIS
        l.contourA.Color = if peut then VERT else GRIS_FONCE
        l.max.TextColor3 = if peut then VERT else GRIS
        l.contourM.Color = if peut then VERT else GRIS_FONCE
        l.max.Visible = not auMax
    end
    local persos = attributJson("Persos")
    local equipe = joueur:GetAttribute("Perso")
    for nom, c in pairs(cartes) do
        if equipe == nom then
            c.bouton.Text = "EQUIPPED"
            c.bouton.BackgroundColor3 = GRIS_FONCE
            c.bouton.TextColor3 = c.couleur
            c.contourB.Color = c.couleur
            c.contour.Transparency = 0
        elseif persos[nom] then
            c.bouton.Text = "EQUIP"
            c.bouton.BackgroundColor3 = c.couleur
            c.bouton.TextColor3 = NOIR
            c.contourB.Color = c.couleur
            c.contour.Transparency = 0.5
        else
            local peut = aura >= c.prix
            c.bouton.Text = "BUY · " .. court(c.prix)
            c.bouton.BackgroundColor3 = if peut then OR else GRIS_FONCE
            c.bouton.TextColor3 = if peut then NOIR else GRIS
            c.contourB.Color = if peut then OR else GRIS_FONCE
            c.contour.Transparency = 0.7
        end
    end
    local r = joueur:GetAttribute("Rebirths") or 0
    local prix = prixRenaissance(r)
    texteRebirths.Text = "REBIRTHS: " .. enCouleur(tostring(r), OR)
    local function bonus(n)
        return "+" .. math.floor(RENAISSANCE.bonusAura * n * 100 + 0.5) .. "% aura  ·  +" .. math.floor(RENAISSANCE.bonusDegats * n * 100 + 0.5) .. "% damage"
    end
    texteBonus.Text = "NOW: " .. bonus(r) .. "   →   " .. enCouleur(bonus(r + 1), VERT)
    rempliR.Size = UDim2.fromScale(math.clamp(aura / prix, 0, 1), 1)
    texteRailR.Text = court(aura) .. " / " .. court(prix) .. " AURA"
    local peut = aura >= prix
    boutonR.Text = "REBIRTH · " .. court(prix)
    boutonR.BackgroundColor3 = if peut then BLANC else GRIS_FONCE
    boutonR.TextColor3 = if peut then NOIR else GRIS
    contourR.Color = if peut then BLANC else GRIS_FONCE
end

local function montrerOnglet(cle)
    ongletActuel = cle
    for k, o in pairs(onglets) do
        local actif = k == cle
        pages[k].Visible = actif
        o.bouton.BackgroundColor3 = if actif then o.couleur else FOND
        o.bouton.BackgroundTransparency = if actif then 0 else 0.12
        o.bouton.TextColor3 = if actif then NOIR else o.couleur
    end
    contourCadre.Color = onglets[cle].couleur
    majBoutique()
end
for cle, o in pairs(onglets) do
    o.bouton.Activated:Connect(function()
        sonClic(4)
        montrerOnglet(cle)
    end)
end

local function echelleEcran()
    local camera = workspace.CurrentCamera
    local taille = if camera then camera.ViewportSize else Vector2.new(1280, 720)
    return math.min(1, (taille.X - 24) / 680, (taille.Y - 24) / 480)
end
Actions.ouvrirBoutique = function(cle)
    montrerOnglet(cle or ongletActuel)
    if fond.Visible then
        return
    end
    fond.Visible = true
    fond.BackgroundTransparency = 1
    tween(fond, 0.3, { BackgroundTransparency = 0.45 })
    local e = echelleEcran()
    echelleCadre.Scale = e * 0.75
    tween(echelleCadre, 0.4, { Scale = e }, Enum.EasingStyle.Back)
end
Actions.fermerBoutique = function()
    if not fond.Visible then
        return
    end
    tween(fond, 0.2, { BackgroundTransparency = 1 })
    tween(echelleCadre, 0.2, { Scale = echelleEcran() * 0.8 })
    task.delay(0.2, function()
        fond.Visible = false
    end)
end
fermer.Activated:Connect(function()
    sonClic(1)
    Actions.fermerBoutique()
end)
fond.Activated:Connect(Actions.fermerBoutique)

-- mise à jour quand ton aura ou tes infos changent (seulement si la boutique est ouverte)
local function siOuverte()
    if fond.Visible then
        majBoutique()
    end
end
for _, nom in ipairs({ "Niveaux", "Persos", "Perso", "Rebirths" }) do
    joueur:GetAttributeChangedSignal(nom):Connect(siOuverte)
end
task.spawn(function()
    local aura = joueur:WaitForChild("leaderstats"):WaitForChild("Aura")
    aura.Changed:Connect(siOuverte)
end)
end -- fin du bloc de la boutique

-- ========================== LES BOUTONS « E » ET LES PORTES DES ZONES ==========================
do
local dossierPortes = workspace:WaitForChild("MindsetMap"):WaitForChild("Portes")
ProximityPromptService.PromptTriggered:Connect(function(prompt)
    local action = prompt:GetAttribute("Action")
    if action == "Boutique" then
        sonClic(4)
        Actions.ouvrirBoutique("Ameliorations")
    elseif action == "Persos" then
        sonClic(4)
        Actions.ouvrirBoutique("Persos")
    elseif action == "Renaissance" then
        sonClic(4)
        Actions.ouvrirBoutique("Renaissance")
    elseif action == "Porte" then
        local nom = prompt:GetAttribute("Zone")
        local ok, resultat = AcheterFonction:InvokeServer("Zone", nom)
        if not ok then
            jouerSon("tic", 0.6, 0.5)
            local zone = ZONE_PAR_NOM[nom or ""]
            if resultat == "Not enough aura" and zone then
                notifier("You need " .. court(zone.prix - monAura()) .. " more aura", ROUGE)
            else
                notifier(tostring(resultat), ROUGE)
            end
        end
    end
end)

-- une zone débloquée = sa porte disparaît (seulement pour toi)
local function majPortes()
    local zones = attributJson("Zones")
    for _, porte in ipairs(dossierPortes:GetChildren()) do
        if porte:IsA("BasePart") then
            local ouverte = zones[porte:GetAttribute("Zone") or ""] == true
            porte.CanCollide = not ouverte
            porte.Transparency = if ouverte then 1 else 0.45
            for _, enfant in ipairs(porte:GetChildren()) do
                if enfant:IsA("SurfaceGui") then
                    enfant.Enabled = not ouverte
                elseif enfant:IsA("ProximityPrompt") then
                    enfant.Enabled = not ouverte
                end
            end
        end
    end
end
joueur:GetAttributeChangedSignal("Zones"):Connect(majPortes)
dossierPortes.ChildAdded:Connect(majPortes)
majPortes()
end -- fin du bloc des portes

-- ========================== L'AMBIANCE DES ZONES ==========================
do
local AMBIANCES = {
    Ville = { heure = 15, teinte = BLANC, atmo = Color3.fromRGB(200, 200, 215), densite = 0.28 },
    Forest = { heure = 7.5, teinte = Color3.fromRGB(228, 255, 228), atmo = Color3.fromRGB(170, 215, 165), densite = 0.34 },
    Ice = { heure = 12, teinte = Color3.fromRGB(215, 235, 255), atmo = Color3.fromRGB(205, 228, 245), densite = 0.38 },
    Volcano = { heure = 18.2, teinte = Color3.fromRGB(255, 212, 185), atmo = Color3.fromRGB(200, 80, 40), densite = 0.42 },
    Cosmos = { heure = 0.2, teinte = Color3.fromRGB(222, 205, 255), atmo = Color3.fromRGB(60, 30, 110), densite = 0.35 },
}
local teinte = nouveau("ColorCorrectionEffect", { Name = "MindsetAmbiance", Parent = Lighting })
local derniereZone = nil
local dejaDit = {}
local function appliquer(nom)
    local a = AMBIANCES[nom]
    if not a then
        return -- (sur un pont : on garde l'ambiance d'avant)
    end
    tween(Lighting, 2.5, { ClockTime = a.heure }, Enum.EasingStyle.Sine)
    tween(teinte, 2.5, { TintColor = a.teinte })
    local atmo = Lighting:FindFirstChild("MindsetAtmo")
    if atmo then
        tween(atmo, 2.5, { Color = a.atmo, Density = a.densite })
    end
end
local function surZone()
    local nom = joueur:GetAttribute("Zone") or "Ville"
    if nom == derniereZone then
        return
    end
    derniereZone = nom
    appliquer(nom)
    local zone = ZONE_PAR_NOM[nom]
    if zone then
        Actions.banniere(zone.titre, "ZONE " .. zone.index .. "  ·  x" .. court(zone.aura) .. " AURA", zone.couleur)
        if os.clock() - (dejaDit[nom] or -1000) > 90 then
            dejaDit[nom] = os.clock()
            dire(zone.phrase, zone.couleur)
        end
        jouerSon("eau", 0.7, 0.3)
    elseif nom == "Ville" then
        Actions.banniere("AURA CITY", "SAFE ZONE  ·  SHOP  ·  CLASSES  ·  REBIRTH", BLANC)
    end
end
joueur:GetAttributeChangedSignal("Zone"):Connect(surZone)
task.delay(1, surZone)
end -- fin du bloc de l'ambiance

-- ========================== CE QUI ARRIVE (messages du serveur) ==========================
EvenementEvent.OnClientEvent:Connect(function(quoi, a, b)
    if quoi == "Debloque" then
        local zone = ZONE_PAR_NOM[a]
        if not zone then
            return
        end
        editNoirEtBlanc(1.6, 1)
        impactFrame()
        modeCinema(2.4)
        secousse(1)
        jouerSon("boum", 0.9, 0.6)
        annoncer(enCouleur(zone.titre, zone.couleur), "ZONE UNLOCKED  ·  x" .. court(zone.aura) .. " AURA", 2.6)
        dire(zone.phrase, zone.couleur, true)
    elseif quoi == "Renaissance" then
        editNoirEtBlanc(2.2, 1)
        impactFrame()
        modeCinema(2.8)
        secousse(1.3)
        flasher(BLANC, 0.8)
        jouerSon("boum", 0.7, 0.7)
        annoncer("REBIRTH " .. tostring(a), "+" .. math.floor(RENAISSANCE.bonusAura * a * 100 + 0.5) .. "% AURA  ·  +" .. math.floor(RENAISSANCE.bonusDegats * a * 100 + 0.5) .. "% DAMAGE  ·  FOREVER", 3)
        dire("Reborn stronger.", BLANC, true)
    elseif quoi == "NouveauPerso" then
        local p = PERSOS[a]
        if not p then
            return
        end
        editNoirEtBlanc(1.2, 0.8)
        impactFrame()
        jouerSon("boum", 1.1, 0.45)
        annoncer(enCouleur(string.upper(a), p.couleur), "NEW CLASS  ·  " .. p.passif.nom, 2.4)
        dire(p.devise or "", p.couleur, true)
    elseif quoi == "Boss" then
        local zone = ZONE_PAR_NOM[a]
        if not zone then
            return
        end
        local nom = zone.noms and zone.noms.Boss or "BOSS"
        jouerSon("boum", 0.6, 0.4)
        notifier("BOSS: " .. nom .. " appeared in " .. zone.titre .. "!", zone.couleur)
        if joueur:GetAttribute("Zone") == a then
            editNoirEtBlanc(1, 0.7)
            impactFrame()
            secousse(0.8)
            annoncer(enCouleur(nom, zone.couleur), "Beat it together: everyone gets a share!", 2.4)
        end
    elseif quoi == "BossMort" then
        local zone = ZONE_PAR_NOM[a]
        if b and b ~= "" then
            notifier(b .. " dealt the most damage to " .. (if zone and zone.noms then zone.noms.Boss else "the boss"), if zone then zone.couleur else BLANC)
        end
    elseif quoi == "BossFuite" then
        local zone = ZONE_PAR_NOM[a]
        notifier((if zone and zone.noms then zone.noms.Boss else "The boss") .. " left...", GRIS)
    elseif quoi == "Niveau" then
        -- ⬆️ un niveau de plus
        local personnage = joueur.Character
        local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
        flasher(Color3.fromRGB(140, 200, 255), 0.3)
        jouerSon("tic", 1, 0.5)
        jouerSon("tic", 1.5, 0.45, 0.08)
        jouerSon("tic", 2, 0.4, 0.16)
        if racine then
            onde(racine.Position - Vector3.new(0, 2.8, 0), Color3.fromRGB(140, 200, 255), 16, 0.5)
            eclats(racine.Position, Color3.fromRGB(140, 200, 255), 30, 1.4)
        end
        annoncer("LEVEL " .. tostring(a), "+3% DAMAGE  ·  +2% HEALTH  ·  FULL HEALTH", 1.8)
    end
end)
MessageEvent.OnClientEvent:Connect(function(message, couleur)
    notifier(message, if typeof(couleur) == "Color3" then couleur else BLANC)
end)

-- la ville : le halo tourne, l'orbe et les rochers flottent, la zone AFK respire
do
local carte = workspace:WaitForChild("MindsetMap")
local tournants, flottants, pulses = {}, {}, {}
for _, objet in ipairs(carte:GetDescendants()) do
    if objet:IsA("BasePart") then
        if objet:GetAttribute("Tourne") then
            table.insert(tournants, { part = objet, cf = objet.CFrame })
        elseif objet:GetAttribute("Flotte") then
            table.insert(flottants, { part = objet, cf = objet.CFrame, g = math.random() * 6 })
        elseif objet:GetAttribute("Pulse") then
            table.insert(pulses, objet)
        end
    end
end
RunService.RenderStepped:Connect(function()
    local t = os.clock()
    for _, o in ipairs(tournants) do
        o.part.CFrame = CFrame.new(o.cf.Position) * CFrame.Angles(0, t * 0.8, 0) * (o.cf - o.cf.Position)
    end
    for _, o in ipairs(flottants) do
        o.part.CFrame = o.cf + Vector3.new(0, math.sin(t * 0.9 + o.g) * 1.2, 0)
    end
    for _, p in ipairs(pulses) do
        p.Transparency = 0.55 + math.sin(t * 2) * 0.2
    end
end)
end

-- ========================== LANGUE (anglais / français) ==========================
-- Tout le jeu est écrit en anglais. Ce bloc traduit À LA VOLÉE chaque texte affiché (l'interface,
-- les panneaux de la carte, les barres des cristaux, les boutons « E ») :
--   FR_EXACT  = les phrases fixes
--   FR_MOTIFS = les phrases avec des nombres ou des noms dedans (motifs Lua, %1 = ce qui est entre parenthèses)
--   FR_NOMS   = les noms des zones, remplacés partout où ils apparaissent
-- Pour ajouter une traduction : ajoute une ligne ici, rien d'autre à toucher.
local Langue = {}
do
local LocalizationService = game:GetService("LocalizationService")

local FR_NOMS = {
    { "EMERALD FOREST", "FORÊT D'ÉMERAUDE" },
    { "FROZEN PEAKS", "PICS GELÉS" },
    { "MAGMA CORE", "CŒUR DE MAGMA" },
    { "COSMIC VOID", "VIDE COSMIQUE" },
    { "AURA CITY", "VILLE DE L'AURA" },
    -- les monstres
    { "ANCIENT TREANT", "TRÉANT ANCIEN" },
    { "FROST TITAN", "TITAN DE GIVRE" },
    { "INFERNO LORD", "SEIGNEUR DES FLAMMES" },
    { "COSMIC OVERLORD", "SEIGNEUR COSMIQUE" },
    { "MOSS GOLEM", "GOLEM DE MOUSSE" },
    { "ICE GOLEM", "GOLEM DE GLACE" },
    { "LAVA GOLEM", "GOLEM DE LAVE" },
    { "STAR GOLEM", "GOLEM STELLAIRE" },
    { "SNOW SLIME", "SLIME DE NEIGE" },
    { "MAGMA SLIME", "SLIME DE MAGMA" },
    { "VOID SLIME", "SLIME DU VIDE" },
}

local FR_EXACT = {
    -- l'interface
    ["SHOP"] = "BOUTIQUE",
    ["REBIRTH"] = "RENAISSANCE",
    ["AUTO: ON"] = "AUTO : OUI",
    ["AUTO: OFF"] = "AUTO : NON",
    ["SETTINGS"] = "PARAMÈTRES",
    ["PUNCH"] = "FRAPPER",
    ["CLOSE"] = "FERMER",
    ["UPGRADES"] = "AMÉLIORATIONS",
    ["MAX"] = "MAX",
    ["MAX LEVEL"] = "NIVEAU MAX",
    ["EQUIPPED"] = "ÉQUIPÉ",
    ["EQUIP"] = "ÉQUIPER",
    ["POWER"] = "FORCE",
    ["PUNCH SPEED"] = "VITESSE DE FRAPPE",
    ["AURA BOOST"] = "BONUS D'AURA",
    ["HEALTH"] = "VIE",
    ["Walk to a monster and CLICK (or hold) to fight"] = "Va près d'un monstre et CLIQUE (ou maintiens) pour te battre",
    ["Walk to a monster and hold PUNCH to fight"] = "Va près d'un monstre et maintiens FRAPPER pour te battre",
    ["AUTO PUNCH: ON (stay near monsters)"] = "COUPS AUTO : OUI (reste près des monstres)",
    ["SLIME"] = "SLIME",
    ["Beat it together: everyone gets a share!"] = "Battez-le ensemble : chacun a sa part !",
    ["+3% DAMAGE  ·  +2% HEALTH  ·  FULL HEALTH"] = "+3 % DÉGÂTS  ·  +2 % PV  ·  PV AU MAX",
    ["AUTO PUNCH: OFF"] = "COUPS AUTO : NON",
    ["You lose your aura and your upgrades.\nYou keep your zones and your classes."] = "Tu perds ton aura et tes améliorations.\nTu gardes tes zones et tes classes.",
    ["Your settings are saved for next time."] = "Tes réglages sont gardés pour la prochaine fois.",
    ["MUSIC"] = "MUSIQUE",
    ["SOUND EFFECTS (clicks, menu sounds, effects)"] = "BRUITAGES (clics, sons du menu, effets)",
    ["SCREEN SHAKE"] = "SECOUSSES DE L'ÉCRAN",
    ["FLASHING LIGHTS"] = "FLASHS LUMINEUX",
    ["LANGUAGE"] = "LANGUE",
    ["ON"] = "OUI",
    ["OFF"] = "NON",
    -- les messages du serveur
    ["Not enough aura"] = "Pas assez d'aura",
    ["Already at max level"] = "Déjà au niveau max",
    ["Already unlocked"] = "Déjà débloquée",
    ["Already equipped"] = "Déjà équipé",
    ["Unlock the previous zone first"] = "Débloque d'abord la zone d'avant",
    ["Still loading your data..."] = "Chargement de tes données...",
    ["Wait a second..."] = "Attends une seconde...",
    ["Try again in a second..."] = "Réessaie dans une seconde...",
    ["This zone is locked!"] = "Cette zone est fermée !",
    -- la carte
    ["AURA MERCHANT"] = "MARCHAND D'AURA",
    ["AFK ZONE"] = "ZONE AFK",
    ["TOP 10 · TOTAL AURA"] = "TOP 10 · AURA TOTALE",
    ["TOP 10 · REBIRTHS"] = "TOP 10 · RENAISSANCES",
    ["Loading..."] = "Chargement...",
    ["No record yet: be the first!"] = "Pas encore de record : sois le premier !",
    -- les boutons « E »
    ["Shop"] = "Boutique",
    ["Aura Merchant"] = "Marchand d'aura",
    ["Rebirth"] = "Renaissance",
    ["Rebirth Altar"] = "Autel de renaissance",
    ["Unlock"] = "Débloquer",
    -- les phrases style TikTok
    ["Every legend starts somewhere."] = "Toute légende commence quelque part.",
    ["Only the strong survive the cold."] = "Seuls les forts survivent au froid.",
    ["Feel the heat."] = "Sens la chaleur.",
    ["Beyond every limit."] = "Au-delà de toutes les limites.",
    ["Too much aura."] = "Trop d'aura.",
    ["Reborn stronger."] = "Renaître plus fort.",
    ["Unstoppable flow."] = "Un flow inarrêtable.",
    -- les classes
    ["Hits first. Hits hard."] = "Frappe en premier. Frappe fort.",
    ["Never stops."] = "Ne s'arrête jamais.",
    ["All eyes on you."] = "Tous les regards sur toi.",
    ["Slow start. Unstoppable end."] = "Départ lent. Fin inarrêtable.",
    ["FIRST STRIKE"] = "PREMIER COUP",
    ["STREAK"] = "SÉRIE",
    ["SPOTLIGHT"] = "PROJECTEUR",
    ["RAGE"] = "RAGE",
    ["Your first hit on every monster deals x3 damage."] = "Ton premier coup sur chaque monstre fait x3 dégâts.",
    ["Every monster you beat in a row gives +2% aura (up to +100%). Stop for 10 s and it resets."] = "Chaque monstre battu d'affilée donne +2 % d'aura (jusqu'à +100 %). Arrête-toi 10 s et ça repart à zéro.",
    ["x2 aura from monsters, but -25% damage. Crown when you're the richest on the server."] = "x2 aura sur les monstres, mais -25 % de dégâts. Une couronne quand tu es le plus riche du serveur.",
    ["Every hit on the same monster deals +15% damage (up to x4)."] = "Chaque coup sur le même monstre fait +15 % de dégâts (jusqu'à x4).",
}

local traduire
local function traduireNoms(s)
    for _, paire in ipairs(FR_NOMS) do
        s = string.gsub(s, paire[1], paire[2])
    end
    return s
end
local FR_MOTIFS = {
    { "^BUY · (.+)$", "ACHETER · %1" },
    { "^REBIRTH · (.+)$", "RENAISSANCE · %1" },
    { "^REBIRTH (%d+)$", "RENAISSANCE %1" },
    { "^LV (%d+) / (%d+)$", "NIV %1 / %2" },
    { "^YOUR AURA: (.+)$", "TON AURA : %1" },
    { "^REBIRTHS: (.+)$", "RENAISSANCES : %1" },
    { "^(.-) DMG  ·  (.-)/s  ·  x(.-) AURA$", "%1 DÉGÂTS  ·  %2/s  ·  x%3 AURA" },
    { "^(.-)  ·  REBIRTHS (%d+)$", "%1  ·  RENAISSANCES %2" },
    { "^NEXT ZONE: (.+)$", function(reste)
        return "ZONE SUIVANTE : " .. traduireNoms(reste)
    end },
    { "^STREAK x(%d+)  ·  %+(%d+)%% AURA$", "SÉRIE x%1  ·  +%2 %% AURA" },
    { "^Damage per hit: (.+)$", "Dégâts par coup : %1" },
    { "^Punches per second: (.+)$", "Coups par seconde : %1" },
    { "^Bonus aura: (.+)$", "Aura en plus : %1" },
    { "^NOW: (.+)$", function(reste)
        reste = string.gsub(reste, "%% aura", " %% d'aura")
        reste = string.gsub(reste, "%% damage", " %% de dégâts")
        return "ACTUEL : " .. reste
    end },
    { "^(.-) AURA  ·  (.-) DAMAGE  ·  FOREVER$", "%1 AURA  ·  %2 DÉGÂTS  ·  POUR TOUJOURS" },
    { "^ZONE UNLOCKED  ·  x(.+) AURA$", "ZONE DÉBLOQUÉE  ·  x%1 AURA" },
    { "^NEW CLASS  ·  (.+)$", function(nom)
        return "NOUVELLE CLASSE  ·  " .. traduire(nom)
    end },
    { "^SAFE ZONE  ·  SHOP  ·  CLASSES  ·  REBIRTH$", "ZONE SANS DANGER  ·  BOUTIQUE  ·  CLASSES  ·  RENAISSANCE" },
    { "^FREE  ·  x(.+) AURA$", "GRATUIT  ·  x%1 AURA" },
    { "^(.-)\nLOCKED · (.+) AURA$", function(titre, prix)
        return traduireNoms(titre) .. "\nFERMÉE · " .. prix .. " AURA"
    end },
    { "^You need (.+) more aura$", "Il te manque %1 d'aura" },
    { "^%+(.+) AURA %(AFK%)$", "+%1 AURA (AFK)" },
    { "^BOSS: (.+) appeared in (.+)!$", function(nom, zone)
        return "BOSS : " .. traduireNoms(nom) .. " est apparu : " .. traduireNoms(zone) .. " !"
    end },
    { "^(.+) dealt the most damage to (.+)$", function(qui, nom)
        return qui .. " a fait le plus de dégâts à " .. traduireNoms(nom)
    end },
    { "^(.+) left%.%.%.$", function(nom)
        return traduireNoms(nom) .. " est reparti..."
    end },
    { "^(.+) DEFEATED$", function(reste)
        return traduireNoms(reste) .. " VAINCU"
    end },
    { "^LEVEL (%d+)$", "NIVEAU %1" },
    { "^(.+) / (.+) HP$", "%1 / %2 PV" },
    { "^LV (%d+)$", "NIV %1" },
    { "^%+(.+) XP$", "+%1 XP" },
    { "^Max health: (.+)$", function(reste)
        return "PV max : " .. string.gsub(reste, "HP", "PV")
    end },
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
    return traduireNoms(s)
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

-- ========================== PARAMÈTRES ==========================
-- volume de la musique, des bruitages, secousses, flashs, langue (sauvegardés par le serveur)
do
local fondReglages = nouveau("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = NOIR, BackgroundTransparency = 1, AutoButtonColor = false, Text = "", Visible = false, ZIndex = 55, Parent = gui })
local cadre = nouveau("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(480, 440), BackgroundColor3 = Color3.fromRGB(12, 12, 18), AutoButtonColor = false, Text = "", ZIndex = 56, Parent = fondReglages })
nouveau("UICorner", { CornerRadius = UDim.new(0, 18), Parent = cadre })
nouveau("UIStroke", { Color = Color3.fromRGB(200, 200, 220), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = cadre })
local echelleCadre = nouveau("UIScale", { Parent = cadre })
texte({ Position = UDim2.new(0, 24, 0, 18), Size = UDim2.new(1, -170, 0, 36), Text = "SETTINGS", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 57, Parent = cadre })
local boutonFermer = bouton({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 20), Size = UDim2.fromOffset(110, 34), Text = "CLOSE", ZIndex = 57, Parent = cadre }, Color3.fromRGB(200, 200, 220), false)

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

local majAffichage = {}

-- un curseur de volume (0 à 100 %)
local function curseur(y, titreCurseur, cle)
    texte({ Position = UDim2.new(0, 24, 0, y), Size = UDim2.new(0.6, 0, 0, 20), Text = titreCurseur, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 200, 215), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 57, Parent = cadre })
    local valeurTexte = texte({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, y), Size = UDim2.new(0, 80, 0, 20), TextColor3 = OR, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 57, Parent = cadre })
    local rail = nouveau("TextButton", { Position = UDim2.new(0, 24, 0, y + 30), Size = UDim2.new(1, -48, 0, 10), BackgroundColor3 = GRIS_FONCE, AutoButtonColor = false, Text = "", ZIndex = 57, Parent = cadre })
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rail })
    local rempli = nouveau("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = OR, BorderSizePixel = 0, ZIndex = 58, Parent = rail })
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rempli })
    local poignee = nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = BLANC, ZIndex = 59, Parent = rail })
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
            sonClic(3)
            sauverReglages()
        end
    end)
    afficher()
end

-- un interrupteur OUI / NON
local function interrupteur(y, titreInter, cle)
    texte({ Position = UDim2.new(0, 24, 0, y + 6), Size = UDim2.new(0.6, 0, 0, 20), Text = titreInter, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 200, 215), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 57, Parent = cadre })
    local b = nouveau("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, y), Size = UDim2.fromOffset(90, 32), AutoButtonColor = false, Font = Enum.Font.GothamBlack, TextScaled = true, ZIndex = 57, Parent = cadre })
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = b })
    nouveau("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), Parent = b })
    local function afficher()
        local actif = REGLAGES[cle]
        b.Text = if actif then "ON" else "OFF"
        b.BackgroundColor3 = if actif then OR else GRIS_FONCE
        b.TextColor3 = if actif then NOIR else Color3.fromRGB(170, 170, 190)
    end
    table.insert(majAffichage, afficher)
    b.MouseEnter:Connect(function()
        sonSurvol(4)
    end)
    b.Activated:Connect(function()
        REGLAGES[cle] = not REGLAGES[cle]
        afficher()
        sonClic(if REGLAGES[cle] then 5 else 2)
        if cle == "secousses" and REGLAGES.secousses then
            secousse(1)
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
    texte({ Position = UDim2.new(0, 24, 0, 328), Size = UDim2.new(0.4, 0, 0, 20), Text = "LANGUAGE", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 200, 215), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 57, Parent = cadre })
    local CHOIX = { { "auto", "AUTO" }, { "en", "EN" }, { "fr", "FR" } }
    local boutonsLangue = {}
    local function afficher()
        for code, b in pairs(boutonsLangue) do
            local actif = REGLAGES.langue == code
            b.BackgroundColor3 = if actif then OR else GRIS_FONCE
            b.TextColor3 = if actif then NOIR else Color3.fromRGB(170, 170, 190)
        end
    end
    for i, choix in ipairs(CHOIX) do
        local b = nouveau("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24 - (#CHOIX - i) * 76, 0, 322), Size = UDim2.fromOffset(68, 32), AutoButtonColor = false, Font = Enum.Font.GothamBlack, Text = choix[2], TextScaled = true, ZIndex = 57, Parent = cadre })
        nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = b })
        nouveau("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), Parent = b })
        boutonsLangue[choix[1]] = b
        b.MouseEnter:Connect(function()
            sonSurvol(4)
        end)
        b.Activated:Connect(function()
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
texte({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.new(1, -48, 0, 18), Text = "Your settings are saved for next time.", Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(140, 140, 160), ZIndex = 57, Parent = cadre })

local function echelleEcran()
    local camera = workspace.CurrentCamera
    local taille = if camera then camera.ViewportSize else Vector2.new(1280, 720)
    return math.min(1, (taille.X - 24) / 500, (taille.Y - 24) / 460)
end
Actions.ouvrirReglages = function()
    fondReglages.Visible = true
    fondReglages.BackgroundTransparency = 1
    tween(fondReglages, 0.3, { BackgroundTransparency = 0.45 })
    local e = echelleEcran()
    echelleCadre.Scale = e * 0.75
    tween(echelleCadre, 0.4, { Scale = e }, Enum.EasingStyle.Back)
end
local function fermerReglages()
    tween(fondReglages, 0.2, { BackgroundTransparency = 1 })
    tween(echelleCadre, 0.2, { Scale = echelleEcran() * 0.8 })
    task.delay(0.2, function()
        fondReglages.Visible = false
    end)
    sauverReglages()
end
boutonFermer.Activated:Connect(function()
    sonClic(1)
    fermerReglages()
end)
fondReglages.Activated:Connect(fermerReglages)

local function chargerReglages()
    local brut = joueur:GetAttribute("Reglages")
    if type(brut) ~= "string" then
        return
    end
    local donnees = lireJson(brut, nil)
    if not donnees then
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
end -- fin du bloc des paramètres

-- ========================== LA MUSIQUE ==========================
-- Une musique au hasard en fond, puis la suivante (le volume se règle dans SETTINGS).
do
local MUSIQUES = lireJson(ReplicatedStorage:GetAttribute("Musiques") or "[]", {})
local musique = nouveau("Sound", { Name = "MindsetMusique", Volume = 0.35, SoundGroup = groupeMusique, Parent = SoundService })
local derniere = 0
local function suivante()
    if #MUSIQUES == 0 then
        return
    end
    local n = math.random(1, #MUSIQUES)
    if n == derniere and #MUSIQUES > 1 then
        n = n % #MUSIQUES + 1
    end
    derniere = n
    musique.SoundId = MUSIQUES[n].id
    musique.TimePosition = 0
    musique:Play()
end
musique.Ended:Connect(suivante)
task.delay(2, suivante)
-- si une musique ne se charge pas (son refusé, jeu pas publié...), on passe à la suivante
task.spawn(function()
    while true do
        task.wait(8)
        if #MUSIQUES > 0 and not musique.IsPlaying and not musique.IsLoaded then
            suivante()
        end
    end
end)
end -- fin du bloc de la musique

-- ========================== À CHAQUE IMAGE ==========================
RunService.RenderStepped:Connect(function(dt)
    majHUD(dt)
end)
