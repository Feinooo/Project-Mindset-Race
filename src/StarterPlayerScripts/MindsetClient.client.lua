--[[
    🎵 STEAL A PHONK — Script CLIENT
    À mettre dans : StarterPlayer > StarterPlayerScripts  (type : LocalScript, nom : MindsetClient)
    ⚠️ C'est le SEUL script client du jeu.

    Ce script s'occupe de tout ce que TU vois et fais :
      - le TAPIS ROULANT : chaque client dessine les Phonks qui défilent (fluide), avec leur nom, leur rareté, leur prix
      - ACHETER (touche E devant un Phonk du tapis), REVENDRE (maintenir E devant un de tes emplacements)
      - les Phonks de ta base qui bougent la tête en rythme
      - l'interface : ton argent, ton revenu par seconde, les places libres dans ta base
      - les effets : l'EDIT NOIR ET BLANC quand tu achètes un Phonk légendaire (ou mieux), les « +$ » qui volent
      - la musique, les paramètres et la langue (anglais / français)
    (le serveur, lui, décide de tout : l'argent, les achats, la position des Phonks sur le tapis)
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
local EvenementEvent = remotes:WaitForChild("Evenement")
local MessageEvent = remotes:WaitForChild("Message")
local ReglagesEvent = remotes:WaitForChild("Reglages")
local ActionFonction = remotes:WaitForChild("Action")

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
local RARETES, RARETE_PAR_CLE = CONFIG.raretes or {}, {}
for i, r in ipairs(RARETES) do
    r.rang = i
    r.couleur = Color3.fromRGB(r.couleur[1], r.couleur[2], r.couleur[3])
    RARETE_PAR_CLE[r.cle] = r
end
local PHONKS = CONFIG.phonks or {}

local BLANC = Color3.new(1, 1, 1)
local NOIR = Color3.new(0, 0, 0)
local OR = Color3.fromRGB(255, 220, 80)
local ROUGE = Color3.fromRGB(255, 70, 70)
local GRIS = Color3.fromRGB(165, 165, 180)
local VERT = Color3.fromRGB(110, 230, 160)
local ROSE = Color3.fromRGB(255, 60, 120)
local FOND = Color3.fromRGB(12, 12, 16)
local GRIS_FONCE = Color3.fromRGB(45, 45, 60)

local surMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local Actions = {} -- les fonctions que les blocs se partagent

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
local function monArgent()
    local stats = joueur:FindFirstChild("leaderstats")
    local aura = stats and stats:FindFirstChild("Cash")
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
-- ---------- en haut à gauche : ton argent ----------
local carte = nouveau("Frame", { Position = UDim2.fromOffset(16, 62), Size = UDim2.fromOffset(260, 100), BackgroundColor3 = FOND, BackgroundTransparency = 0.2, ZIndex = 10, Parent = gui })
nouveau("UICorner", { CornerRadius = UDim.new(0, 14), Parent = carte })
nouveau("UIStroke", { Color = VERT, Thickness = 2, Transparency = 0.2, Parent = carte })
texte({ Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(120, 16), Text = "CASH", Font = Enum.Font.GothamBold, TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = carte })
local texteArgent = texte({ Position = UDim2.fromOffset(14, 24), Size = UDim2.fromOffset(230, 42), Text = "$0", TextColor3 = VERT, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = carte })
local echelleArgent = nouveau("UIScale", { Parent = texteArgent })
local texteRevenu = texte({ Position = UDim2.fromOffset(16, 68), Size = UDim2.fromOffset(230, 15), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(220, 220, 232), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = carte })
local textePlaces = texte({ Position = UDim2.fromOffset(16, 84), Size = UDim2.fromOffset(230, 12), Font = Enum.Font.GothamMedium, TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = carte })

-- ---------- l'aide en bas (au début) ----------
local aide = texte({
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -24),
    Size = UDim2.fromOffset(620, 22),
    Text = "Buy Phonks on the belt (E): they make cash in your base!",
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
local colonne = nouveau("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, -20), Size = UDim2.fromOffset(150, 100), BackgroundTransparency = 1, ZIndex = 10, Parent = gui })
nouveau("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = colonne })
local boutonBase = bouton({ Size = UDim2.fromOffset(150, 40), Text = "MY BASE", LayoutOrder = 1, ZIndex = 11, Parent = colonne }, ROSE, false)
boutonBase.Activated:Connect(function()
    sonClic(4)
    Actions.allerALaBase()
end)
local boutonReglages = bouton({ Size = UDim2.fromOffset(150, 40), Text = "SETTINGS", LayoutOrder = 2, ZIndex = 11, Parent = colonne }, Color3.fromRGB(200, 200, 220), false)
boutonReglages.Activated:Connect(function()
    sonClic(5)
    Actions.ouvrirReglages()
end)

-- l'argent affiché compte jusqu'au vrai
local argentAffiche = 0
Actions.popArgent = function()
    echelleArgent.Scale = 1.25
    tween(echelleArgent, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

majHUD = function(dt)
    local vrai = monArgent()
    if math.abs(vrai - argentAffiche) < 1 then
        argentAffiche = vrai
    else
        argentAffiche += (vrai - argentAffiche) * math.min(1, dt * 10)
    end
    texteArgent.Text = "$" .. court(argentAffiche)
    texteRevenu.Text = "+$" .. court(joueur:GetAttribute("Revenu") or 0) .. " / s"
    local libres = joueur:GetAttribute("Libres") or 10
    textePlaces.Text = "BASE  " .. (10 - libres) .. " / 10"
    textePlaces.TextColor3 = if libres == 0 then ROUGE else GRIS
end
end -- fin du bloc de l'interface

-- aller à sa base (le client contrôle son avatar : il peut le déplacer)
Actions.allerALaBase = function()
    local numero = joueur:GetAttribute("Base") or 0
    local base = workspace:WaitForChild("MindsetMap"):WaitForChild("Bases"):FindFirstChild("Base" .. numero)
    local collect = base and base:FindFirstChild("Collect")
    local personnage = joueur.Character
    if collect and personnage then
        personnage:PivotTo(collect.CFrame + Vector3.new(0, 4, 0))
    end
end

-- ========================== LE TAPIS ROULANT ==========================
-- Le serveur met une « fiche » par Phonk (attributs Phonk + Debut) : ici, on dessine le modèle et on le fait avancer.
do
local dossierTapis = ReplicatedStorage:WaitForChild("MindsetTapis")
local dossierModeles = ReplicatedStorage:WaitForChild("MindsetPhonks")
local depart = dossierTapis:GetAttribute("Depart") or Vector3.new(-170, 101.2, 0)
local longueur = dossierTapis:GetAttribute("Longueur") or 340
local vitesse = CONFIG.vitesseTapis or 7
local dossierLocal = nouveau("Folder", { Name = "MindsetTapisLocal", Parent = workspace })
local locaux = {} -- [fiche] = { modele, debut, graine, prix, labelPrix }

local function ajouter(fiche)
    if locaux[fiche] then
        return
    end
    local cle = fiche:GetAttribute("Phonk")
    local def = PHONKS[cle or ""]
    local modeleBase = dossierModeles:WaitForChild(cle or "", 5)
    if not def or not modeleBase or not fiche.Parent then
        return
    end
    local rarete = RARETE_PAR_CLE[def.rarete] or RARETES[1]
    local modele = modeleBase:Clone()
    local racine = modele.PrimaryPart
    local hauteur = modele:GetAttribute("Hauteur") or 5
    -- les infos au-dessus : nom, rareté, prix, revenu
    local billboard = nouveau("BillboardGui", { Size = UDim2.fromOffset(170, 66), StudsOffsetWorldSpace = Vector3.new(0, hauteur + 2.4, 0), MaxDistance = 60, LightInfluence = 0, Parent = racine })
    texte({ Size = UDim2.new(1, 0, 0.36, 0), Text = def.nom, TextStrokeTransparency = 0.2, TextColor3 = BLANC, Parent = billboard })
    texte({ Position = UDim2.fromScale(0, 0.36), Size = UDim2.new(1, 0, 0.28, 0), Text = rarete.nom, TextStrokeTransparency = 0.2, TextColor3 = rarete.couleur, Parent = billboard })
    local labelPrix = texte({ Position = UDim2.fromScale(0, 0.64), Size = UDim2.new(1, 0, 0.36, 0), Text = "$" .. court(def.prix) .. "  ·  +$" .. court(def.revenu) .. "/s", Font = Enum.Font.GothamBold, TextStrokeTransparency = 0.2, TextColor3 = VERT, Parent = billboard })
    -- le bouton E pour l'acheter
    local prompt = nouveau("ProximityPrompt", {
        ActionText = "Buy",
        ObjectText = def.nom .. " · $" .. court(def.prix),
        KeyboardKeyCode = Enum.KeyCode.E,
        HoldDuration = 0,
        MaxActivationDistance = 11,
        RequiresLineOfSight = false,
        Parent = racine,
    })
    prompt:SetAttribute("Action", "Acheter")
    prompt:SetAttribute("Id", tonumber(fiche.Name))
    modele.Parent = dossierLocal
    locaux[fiche] = { modele = modele, debut = fiche:GetAttribute("Debut") or workspace:GetServerTimeNow(), graine = math.random() * 6, prix = def.prix, labelPrix = labelPrix, rang = rarete.rang }
end

local function enlever(fiche)
    local l = locaux[fiche]
    if l then
        locaux[fiche] = nil
        local racine = l.modele.PrimaryPart
        if racine then
            eclats(racine.Position + Vector3.new(0, 2, 0), BLANC, 12, 1)
        end
        l.modele:Destroy()
    end
end

for _, fiche in ipairs(dossierTapis:GetChildren()) do
    task.spawn(ajouter, fiche)
end
dossierTapis.ChildAdded:Connect(ajouter)
dossierTapis.ChildRemoved:Connect(enlever)

-- ils avancent et bougent la tête en rythme (~ 130 BPM)
local BATTEMENT = 60 / 130
local derniereMaj = 0
RunService.RenderStepped:Connect(function()
    local maintenant = workspace:GetServerTimeNow()
    local t = os.clock()
    local argent = monArgent()
    local majPrix = t - derniereMaj > 0.4
    if majPrix then
        derniereMaj = t
    end
    for _, l in pairs(locaux) do
        local avance = math.clamp((maintenant - l.debut) * vitesse, 0, longueur)
        local position = depart + Vector3.new(avance, 0, 0)
        local phase = ((t + l.graine) % BATTEMENT) / BATTEMENT
        local saut = math.abs(math.sin(phase * math.pi)) * 0.35
        local balance = math.sin((t + l.graine) * math.pi / BATTEMENT) * 0.12
        l.modele:PivotTo(CFrame.lookAt(position, position + Vector3.new(1, 0, 0)) * CFrame.new(0, saut, 0) * CFrame.Angles(0, 0, balance))
        if majPrix then
            l.labelPrix.TextColor3 = if argent >= l.prix then VERT else ROUGE
        end
    end
end)
end -- fin du bloc du tapis

-- ========================== LES BASES (ce que tu vois) ==========================
do
local dossierBases = workspace:WaitForChild("MindsetMap"):WaitForChild("Bases")
local dansants = {} -- [modele] = { base = CFrame, graine }

-- les Phonks des bases bougent la tête en rythme
local function suivre(objet)
    if objet:IsA("Model") and objet:GetAttribute("Base") then
        dansants[objet] = { base = objet:GetAttribute("Base"), graine = math.random() * 0.4 }
    end
end
for _, objet in ipairs(dossierBases:GetDescendants()) do
    suivre(objet)
end
dossierBases.DescendantAdded:Connect(suivre)
dossierBases.DescendantRemoving:Connect(function(objet)
    dansants[objet] = nil
end)

local BATTEMENT = 60 / 130
RunService.RenderStepped:Connect(function()
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    local oeil = camera.CFrame.Position
    local t = os.clock()
    for modele, d in pairs(dansants) do
        if modele.Parent and (d.base.Position - oeil).Magnitude < 160 then
            local phase = ((t + d.graine) % BATTEMENT) / BATTEMENT
            local saut = math.abs(math.sin(phase * math.pi)) * 0.3
            local penche = math.sin((t + d.graine) * math.pi / BATTEMENT) * 0.1
            modele:PivotTo(d.base * CFrame.new(0, saut, 0) * CFrame.Angles(penche * 0.5, 0, penche))
        end
    end
end)

-- les boutons « Sell » : seulement sur TA base
local function filtrer(prompt)
    if not prompt:IsA("ProximityPrompt") or prompt:GetAttribute("Action") ~= "Vendre" then
        return
    end
    local function appliquer()
        if prompt.Enabled and prompt:GetAttribute("Base") ~= joueur:GetAttribute("Base") then
            prompt.Enabled = false
        end
    end
    prompt:GetPropertyChangedSignal("Enabled"):Connect(appliquer)
    appliquer()
end
for _, objet in ipairs(dossierBases:GetDescendants()) do
    filtrer(objet)
end
dossierBases.DescendantAdded:Connect(filtrer)
end -- fin du bloc des bases

-- ========================== LES BOUTONS « E » ==========================
-- les phrases qui s'affichent (style TikTok) quand tu achètes un Phonk rare
local PHRASES = { "Phonk secured.", "Too much aura.", "Nobody can stop you now." }

local function effetAchat(cle)
    local def = PHONKS[cle]
    local rarete = def and RARETE_PAR_CLE[def.rarete]
    if not def or not rarete then
        return
    end
    Actions.cacherAide()
    local personnage = joueur.Character
    local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
    if racine then
        eclats(racine.Position, rarete.couleur, 20 + rarete.rang * 8, 1.4)
        onde(racine.Position - Vector3.new(0, 2.8, 0), rarete.couleur, 10 + rarete.rang * 3, 0.45)
    end
    sonClic(4 + math.min(3, rarete.rang))
    if rarete.rang >= 4 then
        -- LÉGENDAIRE, MYTHIQUE, SECRET : le grand moment, en noir et blanc
        editNoirEtBlanc(1.6 + (rarete.rang - 4) * 0.4, 1)
        impactFrame()
        modeCinema(2.4)
        secousse(0.8 + (rarete.rang - 4) * 0.3)
        jouerSon("boum", 0.8, 0.6)
        annoncer(enCouleur(def.nom, rarete.couleur), rarete.nom, 2.6)
        dire(PHRASES[math.random(1, #PHRASES)], rarete.couleur, true)
    elseif rarete.rang == 3 then
        flasher(rarete.couleur, 0.25)
        secousse(0.35)
        annoncer(enCouleur(def.nom, rarete.couleur), rarete.nom, 1.8)
    else
        notifier(def.nom .. " is in your base!", rarete.couleur)
    end
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
    local action = prompt:GetAttribute("Action")
    if action == "Acheter" then
        local ok, resultat = ActionFonction:InvokeServer("Acheter", prompt:GetAttribute("Id"))
        if ok then
            effetAchat(resultat)
        else
            jouerSon("tic", 0.6, 0.5)
            notifier(tostring(resultat), ROUGE)
        end
    elseif action == "Vendre" then
        local ok, resultat = ActionFonction:InvokeServer("Vendre", prompt:GetAttribute("Base"), prompt:GetAttribute("Emplacement"))
        if ok then
            sonClic(3)
            notifier("+$" .. court(resultat) .. " (sold)", VERT)
            Actions.popArgent()
        else
            jouerSon("tic", 0.6, 0.5)
            notifier(tostring(resultat), ROUGE)
        end
    end
end)

-- ========================== CE QUI ARRIVE (messages du serveur) ==========================
EvenementEvent.OnClientEvent:Connect(function(quoi, a, b)
    if quoi == "Collecte" then
        -- 💰 l'argent récupéré sur le carré COLLECT
        local personnage = joueur.Character
        local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
        if racine then
            texteFlottant(racine.Position + Vector3.new(0, 3.5, 0), "+$" .. court(a), VERT, 1.3, 1.1)
            eclats(racine.Position, VERT, 26, 1.3)
        end
        for i = 0, 4 do
            jouerSon("tic", 1.5 + i * 0.15, 0.25, i * 0.05, 0.08)
        end
        Actions.popArgent()
    elseif quoi == "RareTapis" then
        local def = PHONKS[a]
        local rarete = def and RARETE_PAR_CLE[def.rarete]
        if rarete then
            jouerSon("boum", 1.2, 0.35)
            notifier("A " .. rarete.nom .. " Phonk is on the belt: " .. def.nom .. "!", rarete.couleur)
        end
    elseif quoi == "AchatRare" then
        local def = PHONKS[b]
        local rarete = def and RARETE_PAR_CLE[def.rarete]
        if rarete and a ~= joueur.DisplayName then
            notifier(a .. " bought " .. def.nom .. "!", rarete.couleur)
        end
    end
end)
MessageEvent.OnClientEvent:Connect(function(message, couleur)
    notifier(message, if typeof(couleur) == "Color3" then couleur else BLANC)
end)

-- ========================== LANGUE (anglais / français) ==========================
-- Tout le jeu est écrit en anglais. Ce bloc traduit À LA VOLÉE chaque texte affiché (l'interface,
-- les panneaux de la map, les boutons « E ») :
--   FR_EXACT  = les phrases fixes
--   FR_MOTIFS = les phrases avec des nombres ou des noms dedans (motifs Lua, %1 = ce qui est entre parenthèses)
-- Les noms des Phonks restent en anglais (comme des noms de persos).
-- Pour ajouter une traduction : ajoute une ligne ici, rien d'autre à toucher.
local Langue = {}
do
local LocalizationService = game:GetService("LocalizationService")

local FR_EXACT = {
    -- l'interface
    ["CASH"] = "ARGENT",
    ["MY BASE"] = "MA BASE",
    ["SETTINGS"] = "PARAMÈTRES",
    ["CLOSE"] = "FERMER",
    ["Buy Phonks on the belt (E): they make cash in your base!"] = "Achète des Phonks sur le tapis (E) : ils rapportent de l'argent dans ta base !",
    ["Your settings are saved for next time."] = "Tes réglages sont gardés pour la prochaine fois.",
    ["MUSIC"] = "MUSIQUE",
    ["SOUND EFFECTS (clicks, menu sounds, effects)"] = "BRUITAGES (clics, sons du menu, effets)",
    ["SCREEN SHAKE"] = "SECOUSSES DE L'ÉCRAN",
    ["FLASHING LIGHTS"] = "FLASHS LUMINEUX",
    ["LANGUAGE"] = "LANGUE",
    ["ON"] = "OUI",
    ["OFF"] = "NON",
    -- les raretés
    ["COMMON"] = "COMMUN",
    ["RARE"] = "RARE",
    ["EPIC"] = "ÉPIQUE",
    ["LEGENDARY"] = "LÉGENDAIRE",
    ["MYTHIC"] = "MYTHIQUE",
    ["SECRET"] = "SECRET",
    -- la map et les boutons « E »
    ["COLLECT"] = "RÉCUPÉRER",
    ["EMPTY BASE"] = "BASE LIBRE",
    ["Buy"] = "Acheter",
    ["Sell"] = "Revendre",
    ["TOP 10 · MOST CASH EARNED"] = "TOP 10 · LE PLUS D'ARGENT GAGNÉ",
    ["TOP 10 · BEST INCOME"] = "TOP 10 · MEILLEUR REVENU",
    ["Loading..."] = "Chargement...",
    ["No record yet: be the first!"] = "Pas encore de record : sois le premier !",
    -- les messages du serveur
    ["Too late!"] = "Trop tard !",
    ["Get closer!"] = "Rapproche-toi !",
    ["You don't have a base yet"] = "Tu n'as pas encore de base",
    ["Your base is full! Sell a Phonk first."] = "Ta base est pleine ! Revends d'abord un Phonk.",
    ["Not enough cash"] = "Pas assez d'argent",
    ["That's not yours!"] = "Ce n'est pas à toi !",
    ["Still loading your data..."] = "Chargement de tes données...",
    ["Wait a second..."] = "Attends une seconde...",
    ["Try again in a second..."] = "Réessaie dans une seconde...",
    ["The server is full: no free base."] = "Le serveur est plein : plus de base libre.",
    -- les phrases style TikTok
    ["Phonk secured."] = "Phonk sécurisé.",
    ["Too much aura."] = "Trop d'aura.",
    ["Nobody can stop you now."] = "Plus personne ne peut t'arrêter.",
}

local traduire
local FR_MOTIFS = {
    { "^(.+)'S BASE$", "BASE DE %1" },
    { "^(.+) is in your base!$", "%1 est dans ta base !" },
    { "^A (%u+) Phonk is on the belt: (.+)!$", function(rarete, nom)
        return "Un Phonk " .. traduire(rarete) .. " est sur le tapis : " .. nom .. " !"
    end },
    { "^(.+) bought (.+)!$", "%1 a acheté %2 !" },
    { "^%+%$(.+) %(sold%)$", "+$%1 (vendu)" },
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
