--[[
    🥊 MINDSET BATTLEGROUNDS — Script CLIENT
    À mettre dans : StarterPlayer > StarterPlayerScripts  (type : LocalScript, nom : MindsetClient)
    ⚠️ C'est le SEUL script client du jeu : supprime « MindsetHub » et « MarqueurDrop » s'ils sont encore là.

    Ce script s'occupe de tout ce que TU vois et fais :
      - les commandes : clic = coups (combo de 4) · F = bloquer · Q = esquive · 1 2 3 = capacités · G = ultime · T = provoquer
        (sur téléphone : des boutons à droite)
      - les animations de combat (faites à la main, sur tous les avatars), les étincelles, les chiffres de dégâts
      - l'EDIT NOIR ET BLANC des grands moments (ultime, kill) avec les phrases de la trend, style TikTok
      - l'interface : PV, jauge d'ultime, capacités, fil des kills, écran de mort
      - le lobby : boutique du marchand, tableaux TOP 100, écran géant de l'arène, fiches des états d'esprit
      - la musique, les paramètres et la langue (anglais / français)
    (le serveur, lui, décide de tout : qui touche qui, les dégâts, les kills)
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
local HttpService = game:GetService("HttpService")

local joueur = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("MindsetRemotes")
local ActionEvent = remotes:WaitForChild("Action")
local AnimEvent = remotes:WaitForChild("Anim")
local ImpactEvent = remotes:WaitForChild("Impact")
local CoupEvent = remotes:WaitForChild("Coup")
local KillEvent = remotes:WaitForChild("Kill")
local UltEvent = remotes:WaitForChild("Ult")
local FinEvent = remotes:WaitForChild("Fin")
local ZoneEvent = remotes:WaitForChild("Zone")
local MessageEvent = remotes:WaitForChild("Message")
local ReglagesEvent = remotes:WaitForChild("Reglages")
local ClassementFonction = remotes:WaitForChild("Classement")
local AmeliorerFonction = remotes:WaitForChild("Ameliorer")

local function lireJson(nom, defaut)
    local ok, valeur = pcall(function()
        return HttpService:JSONDecode(ReplicatedStorage:GetAttribute(nom))
    end)
    return if ok and type(valeur) == "table" then valeur else defaut
end
local KITS = lireJson("Kits", {})
for _, kit in pairs(KITS) do
    -- (les 3 capacités arrivent dans « capacites » : on les remet en kit[1], kit[2], kit[3])
    for i, capacite in ipairs(kit.capacites or {}) do
        kit[i] = capacite
    end
end
local DEFS = lireJson("Competences", { couts = {}, persos = {} })

local COULEURS = {
    Motivation = Color3.fromRGB(255, 150, 30),
    Ego = Color3.fromRGB(170, 80, 255),
    Discipline = Color3.fromRGB(60, 140, 255),
    Obsession = Color3.fromRGB(230, 40, 60),
}
local ORDRE_PERSOS = { "Motivation", "Ego", "Discipline", "Obsession" }
local BLANC = Color3.new(1, 1, 1)
local NOIR = Color3.new(0, 0, 0)
local OR = Color3.fromRGB(255, 220, 80)
local ROUGE = Color3.fromRGB(255, 70, 70)
local GRIS = Color3.fromRGB(165, 165, 180)
local VERT = Color3.fromRGB(110, 230, 160)
local FOND = Color3.fromRGB(12, 12, 16)

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

local function heureServeur()
    return workspace:GetServerTimeNow()
end

local function enCouleur(mot, couleur)
    return string.format('<font color="#%02X%02X%02X">%s</font>', math.floor(couleur.R * 255), math.floor(couleur.G * 255), math.floor(couleur.B * 255), mot)
end

local function mesNiveaux(perso)
    local ok, niveaux = pcall(function()
        return HttpService:JSONDecode(joueur:GetAttribute("Niveaux"))
    end)
    local liste = ok and type(niveaux) == "table" and niveaux[perso]
    return if type(liste) == "table" then liste else {}
end

local function effetCompetence(def, niveau)
    return string.format(def.texte, tostring(def.valeurs[math.min(niveau, #def.valeurs)]))
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
    vent = "rbxasset://sounds/action_falling.mp3",
    swoosh = "rbxasset://sounds/swordlunge.wav",
    coup = "rbxasset://sounds/hit.wav",
    eau = "rbxasset://sounds/impact_water.mp3",
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


-- ========================== LES EFFETS « EDIT » ==========================
-- Ce qui donne le style des edits de la trend : le noir et blanc très contrasté, les « impact frames »
-- (l'image qui flashe noir / blanc sur un gros coup), les bandes de cinéma, les légendes style TikTok,
-- les secousses de caméra et les coups de zoom.
local effetEdit = nouveau("ColorCorrectionEffect", { Name = "MindsetEdit", Parent = Lighting })
local flou = nouveau("BlurEffect", { Name = "MindsetFlou", Size = 0, Parent = Lighting })
local forceSecousse = 0
local fovPulse = 0
local FOV_BASE = 70

local function secousse(force)
    forceSecousse = math.max(forceSecousse, force * (if REGLAGES.secousses then 1 else 0))
end

-- la secousse et le zoom s'ajoutent à la caméra normale de Roblox, juste après elle
RunService:BindToRenderStep("MindsetCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
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

-- 🎞️ IMPACT FRAME : l'image devient noire, puis blanche, en un éclair (comme dans les animes / edits)
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
    task.delay(duree, function()
        if numero == numeroEdit then
            tween(effetEdit, 0.6, { Saturation = 0, Contrast = 0, Brightness = 0 })
        end
    end)
end

-- les bandes noires de cinéma (en haut et en bas)
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

-- le GROS TEXTE du milieu (« DISCIPLINE > EGO »), en couleurs
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
    TextColor3 = Color3.fromRGB(230, 230, 240),
    TextStrokeTransparency = 0.2,
    TextTransparency = 1,
    ZIndex = 45,
    Parent = gui,
})
local echelleGros = nouveau("UIScale", { Parent = grosTexte })
local numeroGros = 0
local function annoncer(message, sousMessage, duree)
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

-- 💬 LA LÉGENDE style TikTok (en bas, blanc avec un gros contour noir, mot par mot)
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

-- 🔔 petits messages en haut (« +15 AURA », « You can't leave during a fight! »...)
local notifier
do
local pile = nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 104), Size = UDim2.fromOffset(460, 140), BackgroundTransparency = 1, ZIndex = 30, Parent = gui })
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
    Lifetime = NumberRange.new(0.2, 0.5),
    Speed = NumberRange.new(10, 26),
    SpreadAngle = Vector2.new(180, 180),
    Drag = 6,
    Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
    LightEmission = 1,
    Parent = porte,
})
eclats = function(position, couleur, nombre, vitesse)
    porte.Position = position
    emetteur.Color = ColorSequence.new(couleur, BLANC)
    emetteur.Speed = NumberRange.new(10 * (vitesse or 1), 26 * (vitesse or 1))
    emetteur:Emit(nombre)
end
-- un anneau qui s'agrandit (à plat au sol, ou debout face à la caméra)
onde = function(position, couleur, taille, debout, duree)
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
        CFrame = if debout then CFrame.lookAt(position, workspace.CurrentCamera.CFrame.Position) * CFrame.Angles(0, math.pi / 2, 0)
            else CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2),
        Parent = dossierEffets,
    })
    tween(anneau, duree or 0.35, { Size = Vector3.new(0.15, taille, taille), Transparency = 1 })
    task.delay((duree or 0.35) + 0.02, function()
        anneau:Destroy()
    end)
end
end -- fin du bloc des étincelles


-- ========================== LES ANIMATIONS DE COMBAT (faites à la main) ==========================
-- On plie les articulations des avatars (Motor6D, R15) nous-mêmes : chaque client anime TOUS les combattants
-- quand le serveur dit « untel fait un M1 / un RUSH / un uppercut... ».
-- Une pose = { articulation = angle } ; un nombre = rotation avant/arrière, un Vector3 = (avant, tourner, côté).
--   épaule / hanche + = vers l'avant · coude + = plié · genou - = plié · taille - = penché en avant
--   cou - = tête baissée · épaule droite Z + = bras écarté (épaule gauche : Z -) · taille Y + = épaule droite en avant
local V = Vector3.new
local POSES = {
    armeD = { RightShoulder = V(0.5, 0, 0.35), RightElbow = V(1.9, 0, 0), LeftShoulder = V(1.3, 0, 0.3), LeftElbow = V(1.9, 0, 0), Waist = V(0, -0.35, 0) },
    frappeD = { RightShoulder = V(1.55, 0, -0.1), RightElbow = V(0.1, 0, 0), LeftShoulder = V(1.2, 0, 0.35), LeftElbow = V(2, 0, 0), Waist = V(-0.1, 0.5, 0), RightHip = V(0.25, 0, 0), LeftHip = V(-0.2, 0, 0) },
    armeG = { LeftShoulder = V(0.5, 0, -0.35), LeftElbow = V(1.9, 0, 0), RightShoulder = V(1.3, 0, -0.3), RightElbow = V(1.9, 0, 0), Waist = V(0, 0.35, 0) },
    frappeG = { LeftShoulder = V(1.55, 0, 0.1), LeftElbow = V(0.1, 0, 0), RightShoulder = V(1.2, 0, -0.35), RightElbow = V(2, 0, 0), Waist = V(-0.1, -0.5, 0), LeftHip = V(0.25, 0, 0), RightHip = V(-0.2, 0, 0) },
    crochetArme = { RightShoulder = V(1.1, 0, 1.3), RightElbow = V(1.6, 0, 0), LeftShoulder = V(1.3, 0, 0.3), LeftElbow = V(1.9, 0, 0), Waist = V(0, -0.55, 0) },
    crochet = { RightShoulder = V(1.5, 0, -0.45), RightElbow = V(1.4, 0, 0), LeftShoulder = V(1.2, 0, 0.35), LeftElbow = V(2, 0, 0), Waist = V(-0.1, 0.75, 0) },
    piedArme = { RightHip = V(-0.2, 0, 0), RightKnee = V(-1.4, 0, 0), LeftKnee = V(-0.3, 0, 0), Waist = V(0.1, 0, 0), LeftShoulder = V(0.6, 0, -0.5), RightShoulder = V(0.6, 0, 0.5) },
    coupPied = { RightHip = V(1.75, 0, 0), RightKnee = V(-0.1, 0, 0), LeftKnee = V(-0.25, 0, 0), Waist = V(0.3, 0, 0), LeftShoulder = V(0.3, 0, -0.9), RightShoulder = V(0.3, 0, 0.9) },
    rush = { RightShoulder = V(1.6, 0, 0), RightElbow = V(0, 0, 0), LeftShoulder = V(-0.5, 0, -0.3), LeftElbow = V(0.6, 0, 0), Waist = V(-0.35, 0.45, 0), RightHip = V(0.7, 0, 0), RightKnee = V(-0.6, 0, 0), LeftHip = V(-0.6, 0, 0), LeftKnee = V(-0.3, 0, 0) },
    cri = { LeftShoulder = V(-0.2, 0, -0.95), RightShoulder = V(-0.2, 0, 0.95), LeftElbow = V(1.2, 0, 0), RightElbow = V(1.2, 0, 0), Waist = V(0.3, 0, 0), Neck = V(0.5, 0, 0), LeftKnee = V(-0.3, 0, 0), RightKnee = V(-0.3, 0, 0) },
    accroupi = { RightShoulder = V(-0.3, 0, 0.2), RightElbow = V(1.6, 0, 0), LeftShoulder = V(1.2, 0, 0.3), LeftElbow = V(1.9, 0, 0), LeftKnee = V(-0.8, 0, 0), RightKnee = V(-0.8, 0, 0), LeftHip = V(0.5, 0, 0), RightHip = V(0.5, 0, 0), Waist = V(-0.3, -0.3, 0) },
    uppercut = { RightShoulder = V(3, 0, -0.1), RightElbow = V(0.4, 0, 0), LeftShoulder = V(0.6, 0, 0.3), LeftElbow = V(1.5, 0, 0), Waist = V(0.3, 0.3, 0), Neck = V(0.3, 0, 0) },
    slamHaut = { LeftShoulder = V(2.9, 0, 0.2), RightShoulder = V(2.9, 0, -0.2), LeftElbow = V(0.4, 0, 0), RightElbow = V(0.4, 0, 0), LeftKnee = V(-1, 0, 0), RightKnee = V(-1, 0, 0), LeftHip = V(0.9, 0, 0), RightHip = V(0.9, 0, 0) },
    slamBas = { LeftShoulder = V(1, 0, 0.2), RightShoulder = V(1, 0, -0.2), Waist = V(-0.6, 0, 0), LeftKnee = V(-1.1, 0, 0), RightKnee = V(-1.1, 0, 0), LeftHip = V(1, 0, 0), RightHip = V(1, 0, 0), Neck = V(-0.2, 0, 0) },
    miroir = { LeftShoulder = V(1.6, 0, 0.75), RightShoulder = V(1.6, 0, -0.75), LeftElbow = V(1.1, 0, 0), RightElbow = V(1.1, 0, 0), Neck = V(0.3, 0, 0), Waist = V(0.1, 0, 0) },
    contre = { LeftShoulder = V(1.5, 0, 0.15), LeftElbow = V(0.5, 0, 0), RightShoulder = V(1.1, 0, -0.3), RightElbow = V(2.1, 0, 0), LeftKnee = V(-0.35, 0, 0), RightKnee = V(-0.35, 0, 0), LeftHip = V(0.35, 0, -0.1), Waist = V(0, -0.25, 0) },
    pousserArme = { LeftShoulder = V(0.8, 0, 0.6), RightShoulder = V(0.8, 0, -0.6), LeftElbow = V(2.2, 0, 0), RightElbow = V(2.2, 0, 0), Waist = V(0.15, 0, 0) },
    pousser = { LeftShoulder = V(1.6, 0, 0.15), RightShoulder = V(1.6, 0, -0.15), LeftElbow = V(0.05, 0, 0), RightElbow = V(0.05, 0, 0), Waist = V(-0.2, 0, 0), LeftHip = V(0.5, 0, -0.2), LeftKnee = V(-0.5, 0, 0), RightHip = V(-0.3, 0, 0.2) },
    saisie = { LeftShoulder = V(1.5, 0, 0.1), RightShoulder = V(1.5, 0, -0.1), LeftElbow = V(0.5, 0, 0), RightElbow = V(0.5, 0, 0), Waist = V(-0.2, 0, 0) },
    esquive = { Waist = V(-0.45, 0, 0), LeftShoulder = V(-0.7, 0, -0.2), RightShoulder = V(-0.7, 0, 0.2), LeftHip = V(0.6, 0, 0), LeftKnee = V(-0.9, 0, 0), RightHip = V(-0.4, 0, 0) },
    sigmaA = { LeftShoulder = V(1.35, 0, 0.55), RightShoulder = V(1.35, 0, -0.55), LeftElbow = V(1.75, 0, 0), RightElbow = V(1.75, 0, 0), Waist = V(0.15, 0.2, 0), Neck = V(0.25, 0, 0) },
    sigmaB = { LeftShoulder = V(1.35, 0, 0.55), RightShoulder = V(1.35, 0, -0.55), LeftElbow = V(1.75, 0, 0), RightElbow = V(1.75, 0, 0), Waist = V(0.1, -0.2, 0), Neck = V(-0.25, 0, 0.15) },
    viensA = { RightShoulder = V(1.6, 0, 0.1), RightElbow = V(0.2, 0, 0), LeftShoulder = V(0.1, 0, -0.25), Neck = V(0.2, 0, 0.2), Waist = V(0.1, 0, 0) },
    viensB = { RightShoulder = V(1.6, 0, 0.1), RightElbow = V(1.7, 0, 0), LeftShoulder = V(0.1, 0, -0.25), Neck = V(0.25, 0, 0.2), Waist = V(0.12, 0, 0) },
    ultime = { LeftShoulder = V(0.4, 0, -2.4), RightShoulder = V(0.4, 0, 2.4), LeftElbow = V(0.3, 0, 0), RightElbow = V(0.3, 0, 0), Waist = V(0.35, 0, 0), Neck = V(0.6, 0, 0), LeftKnee = V(-0.2, 0, 0), RightKnee = V(-0.2, 0, 0) },
    gardeCassee = { Waist = V(0.5, 0, 0), LeftShoulder = V(0.8, 0, -1.4), RightShoulder = V(0.8, 0, 1.4), Neck = V(0.5, 0, 0) },
    etourdi = { Neck = V(-0.45, 0, 0.2), Waist = V(-0.2, 0, 0.1), LeftShoulder = V(0, 0, -0.15), RightShoulder = V(0, 0, 0.15), LeftKnee = V(-0.25, 0, 0), RightKnee = V(-0.25, 0, 0) },
    garde = { LeftShoulder = V(1.45, 0, 0.45), RightShoulder = V(1.45, 0, -0.45), LeftElbow = V(2.05, 0, 0), RightElbow = V(2.05, 0, 0), LeftKnee = V(-0.2, 0, 0), RightKnee = V(-0.2, 0, 0), Waist = V(-0.1, 0, 0) },
}
-- une animation = des poses clés dans le temps (nil = position normale) + les traînées lumineuses
--   trainee : D = main droite, G = main gauche, P = pied droit
local ANIMS = {
    M1 = { trainee = "D", { 0, "armeD" }, { 0.05, "frappeD" }, { 0.2, "frappeD" }, { 0.32 } },
    M2 = { trainee = "G", { 0, "armeG" }, { 0.05, "frappeG" }, { 0.2, "frappeG" }, { 0.32 } },
    M3 = { trainee = "D", { 0, "crochetArme" }, { 0.07, "crochet" }, { 0.22, "crochet" }, { 0.35 } },
    M4 = { trainee = "P", { 0, "piedArme" }, { 0.1, "coupPied" }, { 0.35, "coupPied" }, { 0.55 } },
    Rush = { trainee = "D", { 0, "armeD" }, { 0.08, "rush" }, { 0.35, "rush" }, { 0.5 } },
    Rafale = { trainee = "DG", { 0, "armeD" }, { 0.05, "frappeD" }, { 0.15, "frappeG" }, { 0.27, "frappeD" }, { 0.39, "frappeG" }, { 0.51, "frappeD" }, { 0.66, "frappeD" }, { 0.82 } },
    Cri = { { 0 }, { 0.15, "cri" }, { 0.75, "cri" }, { 0.95 } },
    Uppercut = { trainee = "D", { 0, "accroupi" }, { 0.12, "uppercut" }, { 0.35, "uppercut" }, { 0.5 } },
    Slam = { trainee = "DG", { 0, "accroupi" }, { 0.12, "slamHaut" }, { 0.45, "slamHaut" }, { 0.6, "slamBas" }, { 0.8, "slamBas" }, { 0.95 } },
    Miroir = { { 0 }, { 0.1, "miroir" }, { 0.95, "miroir" }, { 1.1 } },
    MiroirReussi = { trainee = "D", { 0, "armeD" }, { 0.05, "rush" }, { 0.3, "rush" }, { 0.45 } },
    Contre = { { 0 }, { 0.08, "contre" }, { 0.6, "contre" }, { 0.75 } },
    ContreReussi = { trainee = "D", { 0, "armeD" }, { 0.05, "rush" }, { 0.3, "rush" }, { 0.45 } },
    Routine = { trainee = "DGP", { 0, "armeD" }, { 0.12, "frappeD" }, { 0.3, "armeG" }, { 0.42, "frappeG" }, { 0.6, "piedArme" }, { 0.75, "coupPied" }, { 0.95, "coupPied" }, { 1.1 } },
    Onde = { trainee = "DG", { 0, "pousserArme" }, { 0.18, "pousser" }, { 0.45, "pousser" }, { 0.6 } },
    Traque = { trainee = "D", { 0, "rush" }, { 0.1, "frappeD" }, { 0.3, "frappeD" }, { 0.42 } },
    Saisie = { trainee = "DG", { 0, "saisie" }, { 0.15, "saisie" }, { 0.3, "frappeD" }, { 0.45, "frappeG" }, { 0.65, "uppercut" }, { 0.9 } },
    Esquive = { { 0, "esquive" }, { 0.2, "esquive" }, { 0.32 } },
    ProvocSigma = { { 0 }, { 0.15, "sigmaA" }, { 0.4, "sigmaB" }, { 0.65, "sigmaA" }, { 0.9, "sigmaB" }, { 1.15 } },
    ProvocViens = { { 0 }, { 0.15, "viensA" }, { 0.35, "viensB" }, { 0.55, "viensA" }, { 0.75, "viensB" }, { 0.95, "viensA" }, { 1.15 } },
    Ultime = { { 0, "accroupi" }, { 0.2, "ultime" }, { 0.9, "ultime" }, { 1.1 } },
    GardeCassee = { { 0, "gardeCassee" }, { 0.5, "gardeCassee" }, { 0.8 } },
}
for _, anim in pairs(ANIMS) do
    anim.duree = anim[#anim][1]
end

local ARTICULATIONS = { "LeftHip", "RightHip", "LeftKnee", "RightKnee", "LeftShoulder", "RightShoulder", "Waist", "LeftElbow", "RightElbow", "Neck" }
local function lisse(k)
    return k * k * (3 - 2 * k)
end
local function angleDe(pose, nom)
    local valeur = pose and pose[nom]
    if not valeur then
        return Vector3.zero
    end
    return if typeof(valeur) == "Vector3" then valeur else Vector3.new(valeur, 0, 0)
end

-- la pose d'une animation à l'instant t (on glisse d'une pose clé à la suivante)
local function poseAnimee(anim, t)
    local cles = anim
    for i = 1, #cles - 1 do
        local a, b = cles[i], cles[i + 1]
        if t <= b[1] then
            local k = lisse(math.clamp((t - a[1]) / math.max(b[1] - a[1], 0.001), 0, 1))
            local poseA, poseB = POSES[a[2]], POSES[b[2]]
            local resultat = {}
            for _, nom in ipairs(ARTICULATIONS) do
                resultat[nom] = angleDe(poseA, nom):Lerp(angleDe(poseB, nom), k)
            end
            return resultat
        end
    end
    return nil
end

-- ========================== LES COMBATTANTS (vus par ce client) ==========================
-- Pour chaque combattant : ses articulations, ses traînées lumineuses, son étiquette (état d'esprit, pseudo, PV),
-- et ses effets (flamme de la MOTIVATION, aura de l'OBSESSION, bouclier de la garde, aura d'ultime).
local etats = {} -- [modele] = état
local monEtat = nil

local function couleurDe(etat)
    return COULEURS[etat.modele:GetAttribute("Perso")] or BLANC
end

local function jouerAnim(modele, nom)
    local etat = etats[modele]
    local anim = ANIMS[nom]
    if not etat or not anim then
        return
    end
    etat.anim, etat.debutAnim = anim, os.clock()
    etat.nomAnim = nom
    if anim.trainee then
        for lettre, trainee in pairs(etat.trainees) do
            if string.find(anim.trainee, lettre, 1, true) then
                trainee.Color = ColorSequence.new(couleurDe(etat), BLANC)
                trainee.Enabled = true
                etat.finTrainee = os.clock() + anim.duree
            end
        end
    end
end

local function creerTrainees(etat)
    etat.trainees = {}
    for lettre, nomPart in pairs({ D = "RightHand", G = "LeftHand", P = "RightFoot" }) do
        local part = etat.modele:FindFirstChild(nomPart)
        if part then
            local a0 = nouveau("Attachment", { Name = "MindsetTrainee0", Position = Vector3.new(0, 0.3, 0), Parent = part })
            local a1 = nouveau("Attachment", { Name = "MindsetTrainee1", Position = Vector3.new(0, -0.3, 0), Parent = part })
            etat.trainees[lettre] = nouveau("Trail", {
                Attachment0 = a0,
                Attachment1 = a1,
                Lifetime = 0.16,
                MinLength = 0.05,
                FaceCamera = true,
                LightEmission = 1,
                Transparency = NumberSequence.new(0.1, 1),
                WidthScale = NumberSequence.new(1, 0),
                Enabled = false,
                Parent = part,
            })
        end
    end
end

-- l'étiquette au-dessus de la tête : état d'esprit, pseudo, barre de vie, série / AFK
local function creerEtiquette(etat)
    local tete = etat.modele:FindFirstChild("Head")
    if not tete then
        return
    end
    local gui3d = nouveau("BillboardGui", {
        Name = "MindsetEtiquette",
        Size = UDim2.fromOffset(180, 54),
        StudsOffsetWorldSpace = Vector3.new(0, 2.7, 0),
        AlwaysOnTop = true,
        MaxDistance = 110,
        LightInfluence = 0,
        Enabled = not etat.estMoi,
        Parent = tete,
    })
    etat.etiquette = gui3d
    etat.lPerso = texte({ Size = UDim2.fromScale(1, 0.34), TextStrokeTransparency = 0.3, Parent = gui3d })
    etat.lNom = texte({ Position = UDim2.fromScale(0, 0.34), Size = UDim2.fromScale(1, 0.34), Font = Enum.Font.GothamBold, TextStrokeTransparency = 0.3, Parent = gui3d })
    local fond = nouveau("Frame", { Position = UDim2.fromScale(0.15, 0.76), Size = UDim2.fromScale(0.7, 0.14), BackgroundColor3 = Color3.fromRGB(20, 20, 24), BorderSizePixel = 0, Parent = gui3d })
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fond })
    nouveau("UIStroke", { Color = NOIR, Thickness = 1, Parent = fond })
    etat.barrePV = nouveau("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLANC, BorderSizePixel = 0, Parent = fond })
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = etat.barrePV })
    etat.fondPV = fond
end

local function majEtiquette(etat)
    if not etat.etiquette then
        return
    end
    local modele = etat.modele
    local perso = modele:GetAttribute("Perso")
    etat.lPerso.Text = string.upper(tostring(perso or "?"))
    etat.lPerso.TextColor3 = couleurDe(etat)
    local suffixe = ""
    if modele:GetAttribute("AFK") then
        suffixe = "  ·  AFK"
    elseif (modele:GetAttribute("Serie") or 0) >= 2 then
        suffixe = "  ·  🔥" .. modele:GetAttribute("Serie")
    end
    etat.lNom.Text = tostring(modele:GetAttribute("Nom") or modele.Name) .. suffixe
    etat.fondPV.Visible = modele:GetAttribute("Arene") == true
end

-- les effets permanents d'un combattant (créés une fois, réglés à chaque image)
local function creerEffets(etat)
    local modele = etat.modele
    local torse = modele:FindFirstChild("UpperTorso") or etat.racine
    etat.flamme = nouveau("Fire", { Size = 2, Heat = 6, Color = COULEURS.Motivation, SecondaryColor = OR, Enabled = false, Parent = torse })
    etat.particulesObsession = nouveau("ParticleEmitter", {
        Rate = 0,
        Lifetime = NumberRange.new(0.4, 0.9),
        Speed = NumberRange.new(1, 4),
        SpreadAngle = Vector2.new(40, 40),
        EmissionDirection = Enum.NormalId.Top,
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
        LightEmission = 1,
        Color = ColorSequence.new(COULEURS.Obsession, NOIR),
        Parent = torse,
    })
    etat.particulesUlt = nouveau("ParticleEmitter", {
        Rate = 0,
        Lifetime = NumberRange.new(0.6, 1.2),
        Speed = NumberRange.new(6, 12),
        SpreadAngle = Vector2.new(20, 20),
        EmissionDirection = Enum.NormalId.Top,
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 0) }),
        Transparency = NumberSequence.new(0.1, 1),
        LightEmission = 1,
        Parent = etat.racine,
    })
    etat.lumiereUlt = nouveau("PointLight", { Range = 18, Brightness = 0, Parent = etat.racine })
    etat.contour = nouveau("Highlight", { FillTransparency = 1, OutlineTransparency = 1, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = modele })
    -- le bouclier de la garde : une bulle devant lui
    etat.bouclier = nouveau("Part", {
        Name = "MindsetBouclier",
        Anchored = true,
        CanCollide = false,
        CanQuery = false,
        CanTouch = false,
        CastShadow = false,
        Shape = Enum.PartType.Ball,
        Size = Vector3.new(6.5, 6.5, 6.5),
        Material = Enum.Material.ForceField,
        Transparency = 1,
        Parent = dossierEffets,
    })
end

local function oublier(modele)
    local etat = etats[modele]
    if not etat then
        return
    end
    etats[modele] = nil
    if etat.bouclier then
        etat.bouclier:Destroy()
    end
    if etat == monEtat then
        monEtat = nil
    end
end

local function suivreModele(modele)
    if etats[modele] or not modele:GetAttribute("Combattant") then
        return
    end
    local humanoid = modele:FindFirstChildOfClass("Humanoid")
    local racine = modele:FindFirstChild("HumanoidRootPart")
    if not humanoid or not racine then
        return
    end
    local etat = { modele = modele, humanoid = humanoid, racine = racine, estMoi = modele == joueur.Character, membres = {} }
    for _, nom in ipairs(ARTICULATIONS) do
        local moteur = modele:FindFirstChild(nom, true)
        if moteur and moteur:IsA("Motor6D") then
            etat.membres[nom] = { moteur = moteur, c0 = moteur.C0, angle = Vector3.zero }
        end
    end
    etats[modele] = etat
    if etat.estMoi then
        monEtat = etat
    end
    creerTrainees(etat)
    creerEtiquette(etat)
    creerEffets(etat)
    majEtiquette(etat)
    for _, nom in ipairs({ "Perso", "Nom", "AFK", "Serie", "Arene" }) do
        modele:GetAttributeChangedSignal(nom):Connect(function()
            majEtiquette(etat)
        end)
    end
    humanoid.Died:Connect(function()
        task.delay(0.1, function()
            oublier(modele)
        end)
    end)
    modele.AncestryChanged:Connect(function(_, parent)
        if not parent then
            oublier(modele)
        end
    end)
end

-- on attend que le serveur ait préparé l'avatar (attribut « Combattant »)
local function guetter(modele)
    if not modele:IsA("Model") then
        return
    end
    if modele:GetAttribute("Combattant") then
        task.defer(suivreModele, modele)
    else
        local connexion
        connexion = modele:GetAttributeChangedSignal("Combattant"):Connect(function()
            connexion:Disconnect()
            task.defer(suivreModele, modele)
        end)
    end
end
local function suivreJoueur(autre)
    autre.CharacterAdded:Connect(guetter)
    if autre.Character then
        guetter(autre.Character)
    end
end
Players.PlayerAdded:Connect(suivreJoueur)
for _, autre in ipairs(Players:GetPlayers()) do
    suivreJoueur(autre)
end
task.spawn(function()
    local dossierBots = workspace:WaitForChild("MindsetBots", 30)
    if dossierBots then
        dossierBots.ChildAdded:Connect(guetter)
        for _, bot in ipairs(dossierBots:GetChildren()) do
            guetter(bot)
        end
    end
end)

-- à chaque image : les poses (animation > étourdi > garde > normal) et les effets de chacun
local function animerCombattants()
    local t = os.clock()
    local tServeur = heureServeur()
    local camera = workspace.CurrentCamera
    local oeil = camera and camera.CFrame.Position or Vector3.zero
    for modele, etat in pairs(etats) do
        local racine = etat.racine
        if not racine.Parent then
            continue
        end
        local loin = (racine.Position - oeil).Magnitude > 220
        -- 1) la pose
        local pose = nil
        if etat.anim then
            local ecoule = t - etat.debutAnim
            if ecoule >= etat.anim.duree then
                etat.anim = nil
            else
                pose = poseAnimee(etat.anim, ecoule)
            end
        end
        local etourdi = (modele:GetAttribute("Etourdi") or 0) > tServeur
        local enGarde = modele:GetAttribute("Garde") == true
        if not pose then
            if etourdi then
                pose = POSES.etourdi
            elseif enGarde then
                pose = POSES.garde
            end
        end
        if not loin then
            for nom, info in pairs(etat.membres) do
                local cible = angleDe(pose, nom)
                -- (on glisse vers la pose voulue : pas de saut brutal)
                local v = if etat.anim then cible else info.angle:Lerp(cible, 0.35)
                if (v - info.angle).Magnitude > 0.002 and info.moteur.Parent then
                    info.angle = v
                    info.moteur.C0 = info.c0 * CFrame.Angles(v.X, v.Y, v.Z)
                end
            end
        end
        if etat.finTrainee and t > etat.finTrainee then
            etat.finTrainee = nil
            for _, trainee in pairs(etat.trainees) do
                trainee.Enabled = false
            end
        end
        -- 2) les effets
        local perso = modele:GetAttribute("Perso")
        local dansArene = modele:GetAttribute("Arene") == true
        local enUlt = (modele:GetAttribute("Ult") or 0) > tServeur
        local couleur = couleurDe(etat)
        local energie = modele:GetAttribute("Energie") or 1
        etat.flamme.Enabled = perso == "Motivation" and dansArene and energie > 0.32
        etat.flamme.Size = 2 + 7 * energie
        etat.flamme.Heat = 4 + 10 * energie
        local crans = if perso == "Obsession" then modele:GetAttribute("Crans") or 0 else 0
        etat.particulesObsession.Rate = if dansArene then crans * 2.5 else 0
        local auMax = perso == "Obsession" and crans >= (modele:GetAttribute("CransMax") or 20)
        etat.particulesUlt.Rate = if enUlt then 45 else 0
        etat.particulesUlt.Color = ColorSequence.new(couleur, BLANC)
        etat.lumiereUlt.Color = couleur
        etat.lumiereUlt.Brightness = if enUlt then 4 + math.sin(t * 8) else 0
        etat.contour.OutlineColor = couleur
        etat.contour.FillColor = couleur
        etat.contour.OutlineTransparency = if enUlt or auMax then 0 else 1
        etat.contour.FillTransparency = if enUlt then 0.75 else 1
        if enGarde and not loin then
            etat.bouclier.Transparency = 0.55
            etat.bouclier.Color = if perso == "Discipline" then COULEURS.Discipline else Color3.fromRGB(200, 210, 230)
            etat.bouclier.CFrame = racine.CFrame * CFrame.new(0, 0.3, -1.6)
        elseif etat.bouclier.Transparency < 1 then
            etat.bouclier.Transparency = 1
        end
        -- 3) la barre de vie de l'étiquette
        if etat.barrePV and etat.fondPV.Visible then
            local k = math.clamp(etat.humanoid.Health / math.max(etat.humanoid.MaxHealth, 1), 0, 1)
            etat.barrePV.Size = UDim2.fromScale(k, 1)
            etat.barrePV.BackgroundColor3 = if k < 0.3 then ROUGE else BLANC
        end
    end
end


-- ========================== L'INTERFACE DU COMBAT ==========================
local hud = {}
do
local bas = nouveau("Frame", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -18),
    Size = UDim2.fromOffset(440, 150),
    BackgroundTransparency = 1,
    ZIndex = 10,
    Parent = gui,
})
nouveau("UIScale", { Scale = if surMobile then 0.8 else 1, Parent = bas })
hud.bas = bas

-- le passif (au-dessus de tout) : son nom + sa jauge (énergie de la MOTIVATION, crans de l'OBSESSION)
hud.passif = texte({ Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0.6, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = bas })
hud.passifValeur = texte({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.4, 0, 0, 18), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 11, Parent = bas })
local fondPassif = nouveau("Frame", { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = Color3.fromRGB(30, 30, 36), BorderSizePixel = 0, ZIndex = 11, Parent = bas })
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fondPassif })
hud.barrePassif = nouveau("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 12, Parent = fondPassif })
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = hud.barrePassif })
hud.fondPassif = fondPassif

-- les PV
local fondPV = nouveau("Frame", { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Color3.fromRGB(18, 18, 22), BorderSizePixel = 0, ZIndex = 11, Parent = bas })
nouveau("UICorner", { CornerRadius = UDim.new(0, 6), Parent = fondPV })
nouveau("UIStroke", { Color = Color3.fromRGB(235, 235, 245), Thickness = 1.5, Transparency = 0.3, Parent = fondPV })
hud.barrePVPerdue = nouveau("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = ROUGE, BorderSizePixel = 0, ZIndex = 12, Parent = fondPV })
nouveau("UICorner", { CornerRadius = UDim.new(0, 6), Parent = hud.barrePVPerdue })
hud.barrePV = nouveau("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLANC, BorderSizePixel = 0, ZIndex = 13, Parent = fondPV })
nouveau("UICorner", { CornerRadius = UDim.new(0, 6), Parent = hud.barrePV })
hud.textePV = texte({ Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 1, -6), TextColor3 = NOIR, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 14, Parent = fondPV })
hud.fondPV = fondPV

-- la jauge d'ultime
local fondUlt = nouveau("Frame", { Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = Color3.fromRGB(30, 30, 36), BorderSizePixel = 0, ZIndex = 11, Parent = bas })
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fondUlt })
hud.barreUlt = nouveau("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = OR, BorderSizePixel = 0, ZIndex = 12, Parent = fondUlt })
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = hud.barreUlt })

-- les 4 cases : capacités 1, 2, 3 et l'ultime G
hud.cases = {}
local rangee = nouveau("Frame", { Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, ZIndex = 11, Parent = bas })
nouveau("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = rangee })
for i, touche in ipairs({ "1", "2", "3", "G" }) do
    local case = nouveau("TextButton", {
        Size = UDim2.fromOffset(104, 64),
        BackgroundColor3 = FOND,
        BackgroundTransparency = 0.1,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = i,
        ZIndex = 11,
        Parent = rangee,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 10), Parent = case })
    local trait = nouveau("UIStroke", { Color = Color3.fromRGB(235, 235, 245), Thickness = 1.5, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = case })
    local voile = nouveau("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = NOIR, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 14, Parent = case })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 10), Parent = voile })
    local cle = texte({ Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(20, 16), Text = touche, TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13, Parent = case })
    local nom = texte({ Position = UDim2.fromOffset(6, 22), Size = UDim2.new(1, -12, 0, 30), Font = Enum.Font.GothamBlack, ZIndex = 13, Parent = case })
    local temps = texte({ Size = UDim2.fromScale(1, 1), TextColor3 = BLANC, TextStrokeTransparency = 0, ZIndex = 15, Visible = false, Parent = case })
    nouveau("UIPadding", { PaddingTop = UDim.new(0, 18), PaddingBottom = UDim.new(0, 18), Parent = temps })
    hud.cases[i] = { case = case, trait = trait, voile = voile, cle = cle, nom = nom, temps = temps, echelle = nouveau("UIScale", { Parent = case }) }
end

-- en haut au milieu : la zone (LOBBY sans danger / ARÈNE) et la série de kills
hud.zone = texte({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(360, 26), TextStrokeTransparency = 0.4, ZIndex = 10, Parent = gui })
hud.serie = texte({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 42), Size = UDim2.fromOffset(240, 30), TextColor3 = OR, TextStrokeTransparency = 0.2, Visible = false, ZIndex = 10, Parent = gui })
hud.echelleSerie = nouveau("UIScale", { Parent = hud.serie })

-- les commandes (en bas à gauche, ordinateur)
hud.aide = texte({
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 16, 1, -14),
    Size = UDim2.fromOffset(300, 64),
    Font = Enum.Font.GothamBold,
    TextColor3 = Color3.fromRGB(190, 190, 205),
    TextStrokeTransparency = 0.5,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Bottom,
    Text = "CLICK  punch combo\nF  block   ·   Q  dodge   ·   T  taunt\n1 2 3  skills   ·   G  ultimate",
    Visible = not surMobile,
    ZIndex = 10,
    Parent = gui,
})

-- 📜 le fil des kills (en haut à droite)
local fil = nouveau("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 60), Size = UDim2.fromOffset(330, 200), BackgroundTransparency = 1, ZIndex = 10, Parent = gui })
nouveau("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = fil })
local ordreFil = 0
hud.ajouterKill = function(infos)
    ordreFil += 1
    local ligne = nouveau("Frame", { Size = UDim2.fromOffset(330, 26), BackgroundColor3 = NOIR, BackgroundTransparency = 0.35, LayoutOrder = -ordreFil, ZIndex = 10, Parent = fil })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 6), Parent = ligne })
    local tueur = if infos.tueur then enCouleur(tostring(infos.tueur), COULEURS[infos.tueurPerso] or BLANC) else "☠"
    local victime = enCouleur(tostring(infos.victime), COULEURS[infos.victimePerso] or BLANC)
    local moi = (infos.tueurModele and infos.tueurModele == joueur.Character) or (infos.victimeModele and infos.victimeModele == joueur.Character)
    if moi then
        nouveau("UIStroke", { Color = OR, Thickness = 1.5, Parent = ligne })
    end
    texte({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 1, -8), RichText = true, Text = tueur .. "  ›  " .. victime, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 11, Parent = ligne })
    task.delay(7, function()
        tween(ligne, 0.4, { BackgroundTransparency = 1 })
        for _, enfant in ipairs(ligne:GetChildren()) do
            if enfant:IsA("TextLabel") then
                tween(enfant, 0.4, { TextTransparency = 1 })
            end
        end
        task.wait(0.45)
        ligne:Destroy()
    end)
    local lignes = {}
    for _, enfant in ipairs(fil:GetChildren()) do
        if enfant:IsA("Frame") then
            table.insert(lignes, enfant)
        end
    end
    if #lignes > 6 then
        table.sort(lignes, function(a, b)
            return a.LayoutOrder > b.LayoutOrder
        end)
        lignes[1]:Destroy()
    end
end
end -- fin du bloc de l'interface

-- remet l'interface à jour (à chaque image)
local pvAffiche = 1
local function majHUD()
    local modele = joueur.Character
    local etat = monEtat
    local dansArene = modele and modele:GetAttribute("Arene") == true
    if not etat or not modele then
        hud.bas.Visible = false
        return
    end
    hud.bas.Visible = true
    local perso = modele:GetAttribute("Perso") or "Motivation"
    local couleur = COULEURS[perso] or BLANC
    local kit = KITS[perso] or {}
    local tServeur = heureServeur()
    -- le passif
    hud.passif.Text = (kit.passif and kit.passif.nom or "") .. "  ·  " .. string.upper(perso)
    hud.passif.TextColor3 = couleur
    hud.barrePassif.BackgroundColor3 = couleur
    if perso == "Motivation" then
        local e = modele:GetAttribute("Energie") or 1
        hud.passifValeur.Text = "ENERGY " .. math.floor(e * 100) .. "%"
        hud.barrePassif.Size = UDim2.fromScale(e, 1)
        hud.fondPassif.Visible = true
    elseif perso == "Obsession" then
        local crans, maximum = modele:GetAttribute("Crans") or 0, modele:GetAttribute("CransMax") or 20
        hud.passifValeur.Text = if crans >= maximum then "UNSTOPPABLE" else "STACKS " .. crans .. " / " .. maximum
        hud.barrePassif.Size = UDim2.fromScale(crans / math.max(maximum, 1), 1)
        hud.fondPassif.Visible = true
    else
        hud.passifValeur.Text = ""
        hud.fondPassif.Visible = false
    end
    -- les PV (la partie perdue reste rouge un instant, comme dans les jeux de combat)
    local k = math.clamp(etat.humanoid.Health / math.max(etat.humanoid.MaxHealth, 1), 0, 1)
    hud.barrePV.Size = UDim2.fromScale(k, 1)
    pvAffiche += (k - pvAffiche) * 0.06
    hud.barrePVPerdue.Size = UDim2.fromScale(math.max(k, pvAffiche), 1)
    hud.barrePV.BackgroundColor3 = if k < 0.3 then Color3.fromRGB(255, 120, 120) else BLANC
    hud.textePV.Text = math.ceil(etat.humanoid.Health) .. " / " .. math.floor(etat.humanoid.MaxHealth)
    -- la jauge d'ultime
    local jauge = modele:GetAttribute("Jauge") or 0
    local enUlt = (modele:GetAttribute("Ult") or 0) > tServeur
    hud.barreUlt.Size = UDim2.fromScale(if enUlt then ((modele:GetAttribute("Ult") or 0) - tServeur) / 8 else jauge / 100, 1)
    hud.barreUlt.BackgroundColor3 = if jauge >= 100 or enUlt then couleur:Lerp(BLANC, 0.3 + 0.3 * math.sin(os.clock() * 8)) else OR
    -- les cases
    for i, case in ipairs(hud.cases) do
        local def = if i <= 3 then kit[i] else kit.ult
        case.nom.Text = def and def.nom or ""
        case.nom.TextColor3 = couleur
        local pret, reste = true, 0
        if i <= 3 then
            local fin = modele:GetAttribute("Recharge" .. i) or 0
            reste = fin - tServeur
            pret = reste <= 0
            local duree = def and def.recharge or 1
            case.voile.Size = UDim2.fromScale(1, if pret then 0 else math.clamp(reste / duree, 0, 1))
        else
            pret = jauge >= 100 and not enUlt
            case.voile.Size = UDim2.fromScale(1, if pret or enUlt then 0 else 1 - jauge / 100)
        end
        case.temps.Visible = i <= 3 and not pret
        case.temps.Text = if reste >= 1 then tostring(math.ceil(reste)) else string.format("%.1f", math.max(reste, 0))
        case.trait.Color = if pret then couleur else Color3.fromRGB(235, 235, 245)
        case.trait.Transparency = if pret then 0 else 0.6
        if pret and not case.etaitPret then
            case.echelle.Scale = 1.15
            tween(case.echelle, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
        end
        case.etaitPret = pret
    end
    hud.cases[4].trait.Thickness = if jauge >= 100 then 3 else 1.5
    -- la zone et la série
    if dansArene then
        local nombre = 0
        for m in pairs(etats) do
            if m:GetAttribute("Arene") then
                nombre += 1
            end
        end
        hud.zone.Text = "⚔ ARENA  ·  " .. nombre .. " FIGHTERS"
        hud.zone.TextColor3 = Color3.fromRGB(255, 110, 110)
    else
        hud.zone.Text = "SAFE ZONE  ·  LOBBY"
        hud.zone.TextColor3 = VERT
    end
    local serie = modele:GetAttribute("Serie") or 0
    hud.serie.Visible = dansArene and serie >= 1
    hud.serie.Text = "🔥 " .. serie .. " KILL STREAK"
end


-- ========================== LES COMMANDES ==========================
-- On joue TOUT DE SUITE ton animation et ton élan (pour que ça réponde bien), et on prévient le serveur,
-- qui décide si le coup touche. Le serveur renvoie l'animation à tout le monde (on ignore l'écho chez toi).
local echos = {} -- [nom d'animation] = os.clock() : ce que tu viens de jouer toi-même
local commandes = { dernierM1 = 0, combo = 0, finAttaque = 0, frenesie = 0, garde = false, souris = false, derniereEsquive = 0 }

-- ce que fait chaque capacité chez toi : l'animation et l'élan
--   elan = vitesse vers l'avant (pendant « duree »), saut = vitesse vers le haut puis on retombe fort
local LANCEMENTS = {
    Motivation = { { anim = "Rush", elan = 78, duree = 0.22 }, { anim = "Rafale" }, { anim = "Cri" } },
    Ego = { { anim = "Uppercut" }, { anim = "Slam", saut = 55, elan = 12 }, { anim = "Miroir" } },
    Discipline = { { anim = "Contre" }, { anim = "Routine", elan = 10, duree = 0.9 }, { anim = "Onde" } },
    Obsession = { {}, { anim = "Saisie" }, { anim = "Cri", frenesie = true } }, -- (HUNT : c'est le serveur qui te téléporte)
}

local function monAvatar()
    local modele = joueur.Character
    local humanoid = modele and modele:FindFirstChildOfClass("Humanoid")
    local racine = modele and modele:FindFirstChild("HumanoidRootPart")
    if not humanoid or not racine or humanoid.Health <= 0 then
        return nil
    end
    return modele, humanoid, racine
end

local function etourdi(modele)
    return (modele:GetAttribute("Etourdi") or 0) > heureServeur()
end

-- tu frappes dans la direction où regarde la caméra
local function orienter(racine)
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    local regard = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
    if regard.Magnitude > 0.1 then
        racine.CFrame = CFrame.lookAt(racine.Position, racine.Position + regard.Unit)
    end
end

-- un élan vers l'avant pendant un court instant
local function elan(racine, vitesse, duree)
    local fin = os.clock() + (duree or 0.12)
    local connexion
    connexion = RunService.Heartbeat:Connect(function()
        if os.clock() > fin or not racine.Parent then
            connexion:Disconnect()
            return
        end
        local v = racine.CFrame.LookVector * vitesse
        racine.AssemblyLinearVelocity = Vector3.new(v.X, racine.AssemblyLinearVelocity.Y, v.Z)
    end)
end

local function jouerMoi(modele, nom)
    echos[nom] = os.clock()
    jouerAnim(modele, nom)
end

local function coupDeBase()
    local modele, _, racine = monAvatar()
    local t = os.clock()
    if not modele or etourdi(modele) or commandes.garde or t < commandes.finAttaque then
        return
    end
    if t - commandes.dernierM1 < (if t < commandes.frenesie then 0.2 else 0.3) then
        return
    end
    if t - commandes.dernierM1 > 1.2 then
        commandes.combo = 0
    end
    commandes.combo = commandes.combo % 4 + 1
    commandes.dernierM1 = t
    local fin = commandes.combo == 4
    commandes.finAttaque = t + (if fin then 0.55 elseif t < commandes.frenesie then 0.12 else 0.2)
    orienter(racine)
    jouerMoi(modele, "M" .. commandes.combo)
    elan(racine, if fin then 22 else 10, 0.1)
    jouerSon("swoosh", 1.2 + math.random() * 0.4, if fin then 0.35 else 0.2, nil, 0.25)
    ActionEvent:FireServer("M1")
end

local function capacite(numero)
    local modele, _, racine = monAvatar()
    if not modele or etourdi(modele) or commandes.garde or os.clock() < commandes.finAttaque then
        return
    end
    if (modele:GetAttribute("Recharge" .. numero) or 0) > heureServeur() then
        return -- encore en recharge
    end
    local perso = modele:GetAttribute("Perso")
    local lancement = LANCEMENTS[perso] and LANCEMENTS[perso][numero] or {}
    commandes.finAttaque = os.clock() + 0.3
    orienter(racine)
    if lancement.anim then
        jouerMoi(modele, lancement.anim)
    end
    if lancement.frenesie then
        commandes.frenesie = os.clock() + 5
    end
    if lancement.saut then
        local v = racine.CFrame.LookVector * (lancement.elan or 0)
        racine.AssemblyLinearVelocity = Vector3.new(v.X, lancement.saut, v.Z)
        task.delay(0.38, function()
            if racine.Parent then
                racine.AssemblyLinearVelocity = Vector3.new(0, -95, 0) -- on retombe fort (le SLAM)
            end
        end)
    elseif lancement.elan then
        elan(racine, lancement.elan, lancement.duree)
    end
    jouerSon("swoosh", 0.9, 0.35, nil, 0.35)
    ActionEvent:FireServer("Capacite", numero)
end

local function lancerUltime()
    local modele = monAvatar()
    if modele and (modele:GetAttribute("Jauge") or 0) >= 100 and not etourdi(modele) then
        ActionEvent:FireServer("Ultime")
    end
end

local function provoquer()
    local modele = monAvatar()
    if not modele or etourdi(modele) or os.clock() < commandes.finAttaque then
        return
    end
    commandes.finAttaque = os.clock() + 1.2
    jouerMoi(modele, if modele:GetAttribute("Perso") == "Ego" then "ProvocViens" else "ProvocSigma")
    echos.Provoc = os.clock()
    ActionEvent:FireServer("Provoc")
end

local function esquiver()
    local modele, humanoid, racine = monAvatar()
    local t = os.clock()
    if not modele or etourdi(modele) or t - commandes.derniereEsquive < 1.6 then
        return
    end
    commandes.derniereEsquive = t
    local direction = humanoid.MoveDirection * Vector3.new(1, 0, 1)
    if direction.Magnitude < 0.1 then
        direction = racine.CFrame.LookVector * Vector3.new(1, 0, 1)
    end
    direction = direction.Unit
    racine.CFrame = CFrame.lookAt(racine.Position, racine.Position + direction)
    jouerMoi(modele, "Esquive")
    elan(racine, 80, 0.16)
    onde(racine.Position - Vector3.new(0, 2.5, 0), BLANC, 6)
    jouerSon("vent", 2.4, 0.2, nil, 0.3)
    ActionEvent:FireServer("Esquive")
end

local function mettreGarde(actif)
    if commandes.garde == actif then
        return
    end
    commandes.garde = actif
    ActionEvent:FireServer("Garde", actif)
end

-- le clavier et la souris
UserInputService.InputBegan:Connect(function(input, gere)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if not gere then
            commandes.souris = true
            coupDeBase()
        end
        return
    end
    if gere then
        return
    end
    local touche = input.KeyCode
    if touche == Enum.KeyCode.F then
        mettreGarde(true)
    elseif touche == Enum.KeyCode.Q then
        esquiver()
    elseif touche == Enum.KeyCode.One then
        capacite(1)
    elseif touche == Enum.KeyCode.Two then
        capacite(2)
    elseif touche == Enum.KeyCode.Three then
        capacite(3)
    elseif touche == Enum.KeyCode.G then
        lancerUltime()
    elseif touche == Enum.KeyCode.T then
        provoquer()
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        commandes.souris = false
    elseif input.KeyCode == Enum.KeyCode.F then
        mettreGarde(false)
    end
end)
-- en gardant le clic enfoncé, on enchaîne le combo
RunService.Heartbeat:Connect(function()
    if commandes.souris then
        coupDeBase()
    end
    local modele = joueur.Character
    if commandes.garde and modele and etourdi(modele) then
        commandes.garde = false -- (garde cassée)
    elseif commandes.garde and modele and not modele:GetAttribute("Garde") and os.clock() - (commandes.renvoiGarde or 0) > 0.3 then
        -- le serveur a refusé la garde (tu étais en train de frapper) : on redemande tant que F est enfoncé
        commandes.renvoiGarde = os.clock()
        ActionEvent:FireServer("Garde", true)
    end
end)

-- les cases de capacités se touchent aussi (téléphone / souris)
for i, case in ipairs(hud.cases) do
    case.case.Activated:Connect(function()
        if i <= 3 then
            capacite(i)
        else
            lancerUltime()
        end
    end)
end

-- 📱 les boutons du téléphone (à droite) : COUP, GARDE (maintenir), ESQUIVE, PROVOC
if surMobile then
    local function boutonRond(texteBouton, position, taille, couleur)
        local b = nouveau("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = position,
            Size = UDim2.fromOffset(taille, taille),
            BackgroundColor3 = FOND,
            BackgroundTransparency = 0.2,
            AutoButtonColor = false,
            Font = Enum.Font.GothamBlack,
            Text = texteBouton,
            TextScaled = true,
            TextColor3 = couleur,
            ZIndex = 20,
            Parent = gui,
        })
        nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = b })
        nouveau("UIStroke", { Color = couleur, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
        nouveau("UIPadding", { PaddingTop = UDim.new(0.3, 0), PaddingBottom = UDim.new(0.3, 0), PaddingLeft = UDim.new(0.1, 0), PaddingRight = UDim.new(0.1, 0), Parent = b })
        return b
    end
    local coup = boutonRond("PUNCH", UDim2.new(1, -90, 1, -230), 96, BLANC)
    coup.MouseButton1Down:Connect(function()
        commandes.souris = true
        coupDeBase()
    end)
    coup.MouseButton1Up:Connect(function()
        commandes.souris = false
    end)
    coup.MouseLeave:Connect(function()
        commandes.souris = false
    end)
    local garde = boutonRond("BLOCK", UDim2.new(1, -190, 1, -280), 64, COULEURS.Discipline)
    garde.MouseButton1Down:Connect(function()
        mettreGarde(true)
    end)
    garde.MouseButton1Up:Connect(function()
        mettreGarde(false)
    end)
    garde.MouseLeave:Connect(function()
        mettreGarde(false)
    end)
    boutonRond("DODGE", UDim2.new(1, -60, 1, -340), 60, VERT).Activated:Connect(esquiver)
    boutonRond("TAUNT", UDim2.new(1, -170, 1, -370), 50, COULEURS.Ego).Activated:Connect(provoquer)
end

-- 💥 TU ES TOUCHÉ : le serveur t'envoie le recul (c'est toi qui bouges ton avatar)
CoupEvent.OnClientEvent:Connect(function(vitesse)
    local _, humanoid, racine = monAvatar()
    if not racine or typeof(vitesse) ~= "Vector3" then
        return
    end
    racine.AssemblyLinearVelocity = vitesse
    if vitesse.Magnitude > 35 then
        humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
        secousse(2.2)
    end
end)

-- 🦅 LE DOUBLE SAUT DE L'EGO (en l'air, appuie encore sur saut)
do
local sautUtilise, decollage = false, 0
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
    local modele, humanoid, racine = monAvatar()
    if not modele or modele:GetAttribute("Perso") ~= "Ego" or sautUtilise or etourdi(modele) then
        return
    end
    if humanoid.FloorMaterial ~= Enum.Material.Air or os.clock() - decollage < 0.18 then
        return
    end
    local etatHumanoid = humanoid:GetState()
    if etatHumanoid ~= Enum.HumanoidStateType.Freefall and etatHumanoid ~= Enum.HumanoidStateType.Jumping then
        return
    end
    sautUtilise = true
    local v = racine.AssemblyLinearVelocity
    racine.AssemblyLinearVelocity = Vector3.new(v.X, math.sqrt(2 * workspace.Gravity * math.max(humanoid.JumpHeight, 7.2)), v.Z)
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    local pieds = racine.Position - Vector3.new(0, 3, 0)
    onde(pieds, COULEURS.Ego, 6)
    eclats(pieds, COULEURS.Ego, 10, 0.8)
    jouerSon("tic", 2.2, 0.35, nil, 0.12)
end)
end -- fin du bloc du double saut


-- ========================== LE LOBBY : aura, boutique, TOP 100, écran géant, fiches ==========================
local carte = workspace:WaitForChild("MindsetMap", 30)
local lobbyCarte = carte and carte:WaitForChild("Lobby", 30)

-- un bouton (survol = grossit + son, clic = rebond)
local function bouton(proprietes, couleur, plein, note)
    proprietes.BackgroundColor3 = if plein then couleur else FOND
    proprietes.BackgroundTransparency = if plein then 0 else 0.1
    proprietes.AutoButtonColor = false
    proprietes.Font = proprietes.Font or Enum.Font.GothamBlack
    proprietes.TextScaled = true
    proprietes.TextColor3 = if plein then NOIR else couleur
    local b = nouveau("TextButton", proprietes)
    nouveau("UICorner", { CornerRadius = UDim.new(0, 10), Parent = b })
    local trait = nouveau("UIStroke", { Color = couleur, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
    nouveau("UIPadding", { PaddingTop = UDim.new(0.22, 0), PaddingBottom = UDim.new(0.22, 0), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = b })
    local echelle = nouveau("UIScale", { Parent = b })
    b.MouseEnter:Connect(function()
        sonSurvol(note or 4)
        tween(echelle, 0.15, { Scale = 1.05 }, Enum.EasingStyle.Back)
    end)
    b.MouseLeave:Connect(function()
        tween(echelle, 0.15, { Scale = 1 })
    end)
    b.Activated:Connect(function()
        echelle.Scale = 0.92
        tween(echelle, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
    end)
    return b, trait
end

-- ---------- en haut à gauche : ton aura ----------
local auraValeur = joueur:WaitForChild("StatsCachees", 30) and joueur.StatsCachees:WaitForChild("Aura", 30)
local pastilleAura = nouveau("Frame", { Position = UDim2.new(0, 16, 0, 60), Size = UDim2.fromOffset(200, 40), BackgroundColor3 = FOND, BackgroundTransparency = 0.1, ZIndex = 10, Parent = gui })
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pastilleAura })
nouveau("UIStroke", { Color = OR, Thickness = 2, Parent = pastilleAura })
texte({ Position = UDim2.new(0, 16, 0.22, 0), Size = UDim2.new(0, 56, 0.56, 0), Text = "AURA", TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = pastilleAura })
local texteAura = texte({ Position = UDim2.new(0, 70, 0.15, 0), Size = UDim2.new(1, -86, 0.7, 0), TextColor3 = OR, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 11, Parent = pastilleAura })
local echelleAura = nouveau("UIScale", { Parent = pastilleAura })
local function aura()
    return if auraValeur then auraValeur.Value else 0
end

-- un panneau qui s'ouvre au milieu de l'écran (boutique, top 100)
local panneauOuvert = nil -- { cadre, point } : se ferme si on s'éloigne du point
local function fermerPanneaux()
    if panneauOuvert then
        panneauOuvert.cadre.Visible = false
        panneauOuvert = nil
    end
end
local function ouvrirPanneau(cadre, echelle, point)
    if panneauOuvert and panneauOuvert.cadre ~= cadre then
        panneauOuvert.cadre.Visible = false
    end
    panneauOuvert = { cadre = cadre, point = point }
    cadre.Visible = true
    echelle.Scale = 0.85
    tween(echelle, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- ---------- 🛒 LA BOUTIQUE DU MARCHAND ----------
local afficherBoutique
do
local boutique = { onglets = {}, lignes = {}, perso = nil }
local cadre = nouveau("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -24, 0.5, 0), Size = UDim2.fromScale(0.44, 0.7), BackgroundColor3 = FOND, BackgroundTransparency = 0.04, Visible = false, ZIndex = 30, Parent = gui })
nouveau("UISizeConstraint", { MaxSize = Vector2.new(560, 620), Parent = cadre })
nouveau("UICorner", { CornerRadius = UDim.new(0, 18), Parent = cadre })
local trait = nouveau("UIStroke", { Color = OR, Thickness = 2, Parent = cadre })
local echelle = nouveau("UIScale", { Parent = cadre })
local function t(p)
    p.ZIndex = 31
    p.Parent = p.Parent or cadre
    return texte(p)
end
t({ Position = UDim2.fromScale(0.05, 0.025), Size = UDim2.fromScale(0.5, 0.065), Text = "AURA SHOP", TextColor3 = OR, TextXAlignment = Enum.TextXAlignment.Left })
boutique.solde = t({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.85, 0.03), Size = UDim2.fromScale(0.32, 0.05), TextColor3 = OR, TextXAlignment = Enum.TextXAlignment.Right })
local fermer = bouton({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(36, 36), Text = "X", ZIndex = 32, Parent = cadre }, ROUGE, false, 2)
fermer.Activated:Connect(fermerPanneaux)
t({ Position = UDim2.fromScale(0.05, 0.088), Size = UDim2.fromScale(0.9, 0.032), Text = "Spend the aura you farm in the arena to upgrade your mindset.", Font = Enum.Font.GothamMedium, TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Left })
local rangee = nouveau("Frame", { Position = UDim2.fromScale(0.05, 0.14), Size = UDim2.fromScale(0.9, 0.065), BackgroundTransparency = 1, ZIndex = 31, Parent = cadre })
nouveau("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.02, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = rangee })
for i, perso in ipairs(ORDRE_PERSOS) do
    local b = bouton({ Size = UDim2.fromScale(0.235, 1), Text = string.upper(perso), LayoutOrder = i, ZIndex = 32, Parent = rangee }, COULEURS[perso], false, i)
    b.Activated:Connect(function()
        sonClic(i)
        boutique.perso = perso
        afficherBoutique()
    end)
    boutique.onglets[perso] = b
end
boutique.nom = t({ Position = UDim2.fromScale(0.05, 0.23), Size = UDim2.fromScale(0.6, 0.07), TextXAlignment = Enum.TextXAlignment.Left })
boutique.devise = t({ Position = UDim2.fromScale(0.05, 0.3), Size = UDim2.fromScale(0.9, 0.035), Font = Enum.Font.GothamMedium, TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Left })
for j = 1, 3 do
    local ligne = nouveau("Frame", { Position = UDim2.fromScale(0.05, 0.36 + (j - 1) * 0.185), Size = UDim2.fromScale(0.9, 0.17), BackgroundColor3 = Color3.fromRGB(24, 24, 32), ZIndex = 31, Parent = cadre })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 12), Parent = ligne })
    local l = { cadre = ligne, pips = {} }
    l.nom = t({ Position = UDim2.fromScale(0.04, 0.1), Size = UDim2.fromScale(0.36, 0.26), TextXAlignment = Enum.TextXAlignment.Left, Parent = ligne })
    for k = 1, 5 do
        local pip = nouveau("Frame", { Position = UDim2.fromScale(0.42 + (k - 1) * 0.048, 0.14), Size = UDim2.fromScale(0.038, 0.18), BackgroundColor3 = Color3.fromRGB(50, 50, 66), BorderSizePixel = 0, ZIndex = 32, Parent = ligne })
        nouveau("UICorner", { CornerRadius = UDim.new(0, 3), Parent = pip })
        l.pips[k] = pip
    end
    l.maintenant = t({ Position = UDim2.fromScale(0.04, 0.42), Size = UDim2.fromScale(0.62, 0.22), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = ligne })
    l.ensuite = t({ Position = UDim2.fromScale(0.04, 0.68), Size = UDim2.fromScale(0.62, 0.2), Font = Enum.Font.GothamMedium, TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Left, Parent = ligne })
    l.bouton, l.trait = bouton({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.97, 0.5), Size = UDim2.fromScale(0.29, 0.56), Text = "UPGRADE", ZIndex = 32, Parent = ligne }, OR, true, 3 + j)
    boutique.lignes[j] = l
end
boutique.message = t({ Position = UDim2.fromScale(0.05, 0.925), Size = UDim2.fromScale(0.9, 0.045), Font = Enum.Font.GothamBold, TextColor3 = GRIS })
local function messageBoutique(message, couleur)
    boutique.message.Text = message
    boutique.message.TextColor3 = couleur or GRIS
end

afficherBoutique = function()
    local perso = boutique.perso or joueur:GetAttribute("Perso") or "Motivation"
    boutique.perso = perso
    local couleur = COULEURS[perso]
    local niveaux = mesNiveaux(perso)
    local defs = DEFS.persos and DEFS.persos[perso] or {}
    local couts = DEFS.couts or {}
    for nom, b in pairs(boutique.onglets) do
        local actif = nom == perso
        b.BackgroundColor3 = if actif then COULEURS[nom] else FOND
        b.TextColor3 = if actif then NOIR else COULEURS[nom]
    end
    trait.Color = couleur
    boutique.nom.Text = string.upper(perso)
    boutique.nom.TextColor3 = couleur
    local total, maximum = 0, 0
    for j = 1, #defs do
        total += tonumber(niveaux[j]) or 0
        maximum += #couts
    end
    boutique.devise.Text = (KITS[perso] and KITS[perso].devise or "") .. "  ·  LV " .. total .. " / " .. maximum
    for j, l in ipairs(boutique.lignes) do
        local def = defs[j]
        l.cadre.Visible = def ~= nil
        if def then
            local niveau = tonumber(niveaux[j]) or 0
            local prix = couts[niveau + 1]
            l.nom.Text = def.nom
            l.nom.TextColor3 = if niveau > 0 then couleur else BLANC
            for k, pip in ipairs(l.pips) do
                pip.BackgroundColor3 = if k <= niveau then couleur else Color3.fromRGB(50, 50, 66)
            end
            l.maintenant.Text = if niveau > 0 then "NOW: " .. effetCompetence(def, niveau) else "NOW: locked"
            l.maintenant.TextColor3 = if niveau > 0 then BLANC else Color3.fromRGB(130, 130, 150)
            if prix then
                l.ensuite.Text = "NEXT: " .. effetCompetence(def, niveau + 1)
                l.bouton.Text = prix .. " AURA"
                local assez = aura() >= prix
                l.bouton.BackgroundColor3 = if assez then OR else Color3.fromRGB(50, 50, 66)
                l.bouton.TextColor3 = if assez then NOIR else Color3.fromRGB(150, 150, 170)
                l.trait.Color = if assez then OR else Color3.fromRGB(70, 70, 90)
            else
                l.ensuite.Text = "MAX LEVEL"
                l.bouton.Text = "MAX"
                l.bouton.BackgroundColor3 = couleur
                l.bouton.TextColor3 = NOIR
                l.trait.Color = couleur
            end
        end
    end
end

local achatEnCours = false
for j, l in ipairs(boutique.lignes) do
    l.bouton.Activated:Connect(function()
        if achatEnCours then
            return
        end
        local perso = boutique.perso
        achatEnCours = true
        local appelOk, reussi, info = pcall(function()
            return AmeliorerFonction:InvokeServer(perso, j)
        end)
        achatEnCours = false
        if appelOk and reussi == true then
            local def = DEFS.persos and DEFS.persos[perso] and DEFS.persos[perso][j]
            sonClic(5)
            jouerSon("tic", 1.5, 0.4, 0.2)
            jouerSon("tic", 2, 0.4, 0.28)
            jouerSon("tic", 3, 0.35, 0.36)
            flasher(COULEURS[perso], 0.25)
            messageBoutique("LEVEL UP!  " .. (if def then def.nom else "SKILL") .. " is now level " .. tostring(info), OR)
            for k, pip in ipairs(l.pips) do
                task.delay(k * 0.04, function()
                    pip.Size = UDim2.fromScale(0.038, 0.3)
                    tween(pip, 0.3, { Size = UDim2.fromScale(0.038, 0.18) }, Enum.EasingStyle.Back)
                end)
            end
        else
            jouerSon("pose", 0.6, 0.5)
            local niveau = tonumber(mesNiveaux(perso)[j]) or 0
            local prix = DEFS.couts and DEFS.couts[niveau + 1]
            if not prix then
                messageBoutique("Already at max level.", ROUGE)
            elseif aura() < prix then
                messageBoutique("Not enough aura: you need " .. (prix - aura()) .. " more. Fight to farm some!", ROUGE)
            else
                messageBoutique(if appelOk and type(info) == "string" then info else "Try again in a second...", ROUGE)
            end
        end
        afficherBoutique()
    end)
end
joueur:GetAttributeChangedSignal("Perso"):Connect(afficherBoutique)
joueur:GetAttributeChangedSignal("Niveaux"):Connect(afficherBoutique)

-- l'aura affichée (le compteur défile quand elle change)
local auraAffichee = aura()
local function majAura()
    afficherBoutique()
    local cible, depart = aura(), auraAffichee
    if cible ~= depart then
        echelleAura.Scale = 1.15
        tween(echelleAura, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
    end
    task.spawn(function()
        local debut = os.clock()
        while os.clock() - debut < 0.5 do
            auraAffichee = math.floor(depart + (cible - depart) * (os.clock() - debut) / 0.5)
            texteAura.Text = tostring(auraAffichee)
            boutique.solde.Text = auraAffichee .. " AURA"
            task.wait()
        end
        auraAffichee = cible
        texteAura.Text = tostring(cible)
        boutique.solde.Text = cible .. " AURA"
    end)
end
if auraValeur then
    auraValeur.Changed:Connect(majAura)
end
majAura()

-- le bouton E devant le marchand ouvre la boutique
task.spawn(function()
    local point = lobbyCarte and lobbyCarte:WaitForChild("PointMarchand", 30)
    local prompt = point and point:WaitForChild("Boutique", 10)
    if prompt then
        prompt.Triggered:Connect(function()
            boutique.perso = joueur:GetAttribute("Perso")
            afficherBoutique()
            messageBoutique("", GRIS)
            sonClic(2)
            ouvrirPanneau(cadre, echelle, point)
        end)
    end
end)
end -- fin du bloc de la boutique

-- ---------- 🏆 LES DEUX TOP 100 (sur les tableaux du lobby, et en grand avec le bouton E) ----------
do
local COULEURS_PODIUM = { OR, Color3.fromRGB(210, 215, 230), Color3.fromRGB(220, 140, 80) }
local TOPS = {
    { cle = "K", part = "TableauKills", titre = "TOP 100  ·  KILLS", sous = "the most kills of all time", unite = " kills", couleur = OR, moi = "YOU" },
    { cle = "S", part = "TableauSerie", titre = "TOP 100  ·  BEST STREAK", sous = "the most kills in a row without dying", unite = " in a row", couleur = Color3.fromRGB(255, 90, 90), moi = "YOU" },
}
local function creerLigne(parent, rang, hauteur, zIndex)
    local ligne = nouveau("Frame", { Size = UDim2.new(1, -10, 0, hauteur), LayoutOrder = rang, BackgroundColor3 = if rang % 2 == 0 then Color3.fromRGB(24, 24, 32) else Color3.fromRGB(16, 16, 22), BorderSizePixel = 0, Visible = false, ZIndex = zIndex, Parent = parent })
    nouveau("UICorner", { CornerRadius = UDim.new(0.3, 0), Parent = ligne })
    local couleurRang = COULEURS_PODIUM[rang] or GRIS
    texte({ Position = UDim2.fromScale(0.015, 0.14), Size = UDim2.fromScale(0.11, 0.72), Text = "#" .. rang, TextColor3 = couleurRang, ZIndex = zIndex + 1, Parent = ligne })
    return {
        cadre = ligne, rang = rang,
        nom = texte({ Position = UDim2.fromScale(0.14, 0.14), Size = UDim2.fromScale(0.5, 0.72), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = zIndex + 1, Parent = ligne }),
        score = texte({ Position = UDim2.fromScale(0.64, 0.14), Size = UDim2.fromScale(0.34, 0.72), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = couleurRang, ZIndex = zIndex + 1, Parent = ligne }),
    }
end
local function remplir(lignes, liste, unite)
    for rang, ligne in ipairs(lignes) do
        local entree = liste[rang]
        ligne.cadre.Visible = entree ~= nil
        if entree then
            local estMoi = entree.userId == joueur.UserId
            ligne.nom.Text = tostring(entree.nom)
            ligne.nom.TextColor3 = if estMoi then VERT else BLANC
            ligne.score.Text = tostring(entree.score) .. unite
            ligne.cadre.BackgroundColor3 = if estMoi then Color3.fromRGB(22, 56, 40) elseif rang % 2 == 0 then Color3.fromRGB(24, 24, 32) else Color3.fromRGB(16, 16, 22)
        end
    end
end
local function texteMoi(top)
    local record = top.record or 0
    if record <= 0 then
        return "YOU: —  (go fight!)"
    end
    for rang, entree in ipairs(top.liste or {}) do
        if entree.userId == joueur.UserId then
            return "YOU: " .. record .. top.unite .. "  ·  RANK #" .. rang
        end
    end
    return "YOU: " .. record .. top.unite .. "  ·  not in the top 100 yet"
end

-- le panneau en grand (un seul, pour les deux tops)
local grand = nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.5, 0.78), BackgroundColor3 = FOND, BackgroundTransparency = 0.04, Visible = false, ZIndex = 30, Parent = gui })
nouveau("UISizeConstraint", { MinSize = Vector2.new(320, 300), MaxSize = Vector2.new(540, 680), Parent = grand })
nouveau("UICorner", { CornerRadius = UDim.new(0, 18), Parent = grand })
local traitGrand = nouveau("UIStroke", { Color = OR, Thickness = 2, Parent = grand })
local echelleGrand = nouveau("UIScale", { Parent = grand })
local titreGrand = texte({ Position = UDim2.new(0.05, 0, 0, 16), Size = UDim2.new(0.75, 0, 0, 30), TextColor3 = OR, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = grand })
local sousGrand = texte({ Position = UDim2.new(0.05, 0, 0, 48), Size = UDim2.new(0.9, 0, 0, 16), Font = Enum.Font.GothamMedium, TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = grand })
bouton({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(36, 36), Text = "X", ZIndex = 32, Parent = grand }, ROUGE, false, 2).Activated:Connect(fermerPanneaux)
local listeGrand = nouveau("ScrollingFrame", { Position = UDim2.new(0.04, 0, 0, 76), Size = UDim2.new(0.92, 0, 1, -126), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 31, Parent = grand })
nouveau("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = listeGrand })
local lignesGrand = {}
for rang = 1, 100 do
    lignesGrand[rang] = creerLigne(listeGrand, rang, 34, 32)
end
local moiGrand = texte({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.05, 0, 1, -14), Size = UDim2.new(0.9, 0, 0, 24), TextColor3 = VERT, ZIndex = 31, Parent = grand })
local topAffiche = nil
local function remplirGrand(top)
    if top ~= topAffiche then
        return
    end
    titreGrand.Text, titreGrand.TextColor3 = top.titre, top.couleur
    sousGrand.Text = top.sous
    traitGrand.Color = top.couleur
    remplir(lignesGrand, top.liste or {}, top.unite)
    moiGrand.Text = texteMoi(top)
end

local function majTop(top)
    task.spawn(function()
        local ok, resultat = pcall(function()
            return ClassementFonction:InvokeServer(top.cle)
        end)
        if not ok or type(resultat) ~= "table" then
            if top.statut then
                top.statut.Text = "Leaderboard unavailable for now"
                top.statut.Visible = true
            end
            return
        end
        top.liste = resultat.liste or {}
        top.record = tonumber(resultat.moi) or 0
        if top.lignes then
            remplir(top.lignes, top.liste, top.unite)
            top.statut.Visible = #top.liste == 0
            top.statut.Text = "No record yet: be the first!"
            top.texteMoi.Text = texteMoi(top)
        end
        remplirGrand(top)
    end)
end

-- sur chaque tableau du lobby : la liste qui défile toute seule
for _, top in ipairs(TOPS) do
    task.spawn(function()
        local planche = lobbyCarte and lobbyCarte:WaitForChild(top.part, 30)
        if not planche then
            return
        end
        local surface = nouveau("SurfaceGui", { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, LightInfluence = 0, Parent = planche })
        texte({ Position = UDim2.fromScale(0.04, 0.03), Size = UDim2.fromScale(0.92, 0.08), Text = top.titre, TextColor3 = top.couleur, Parent = surface })
        texte({ Position = UDim2.fromScale(0.04, 0.11), Size = UDim2.fromScale(0.92, 0.035), Text = top.sous, Font = Enum.Font.GothamMedium, TextColor3 = GRIS, Parent = surface })
        top.statut = texte({ Position = UDim2.fromScale(0.04, 0.45), Size = UDim2.fromScale(0.92, 0.07), Text = "Loading...", TextColor3 = GRIS, Parent = surface })
        top.defile = nouveau("ScrollingFrame", { Position = UDim2.fromScale(0.03, 0.17), Size = UDim2.fromScale(0.94, 0.7), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollingEnabled = false, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = surface })
        nouveau("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = top.defile })
        top.lignes = {}
        for rang = 1, 100 do
            top.lignes[rang] = creerLigne(top.defile, rang, 36, 1)
        end
        top.texteMoi = texte({ Position = UDim2.fromScale(0.04, 0.89), Size = UDim2.fromScale(0.92, 0.07), TextColor3 = VERT, Parent = surface })
        top.y, top.pause = 0, 4
        majTop(top)
        -- le bouton E devant le tableau
        local point = lobbyCarte:WaitForChild("Point" .. top.part, 10)
        local prompt = point and point:WaitForChild("Voir", 10)
        if prompt then
            prompt.Triggered:Connect(function()
                topAffiche = top
                sonClic(7)
                remplirGrand(top)
                majTop(top)
                ouvrirPanneau(grand, echelleGrand, point)
            end)
        end
    end)
end
task.spawn(function()
    while true do
        task.wait(30)
        for _, top in ipairs(TOPS) do
            majTop(top)
        end
    end
end)
RunService.RenderStepped:Connect(function(dt)
    for _, top in ipairs(TOPS) do
        local defile = top.defile
        if defile then
            local maximum = math.max(0, defile.AbsoluteCanvasSize.Y - defile.AbsoluteWindowSize.Y)
            if maximum > 0 then
                if top.pause > 0 then
                    top.pause -= dt
                    if top.pause <= 0 and top.enBas then
                        top.enBas, top.y, top.pause = false, 0, 4
                    end
                else
                    top.y += dt * 40
                    if top.y >= maximum then
                        top.y, top.enBas, top.pause = maximum, true, 3
                    end
                end
                defile.CanvasPosition = Vector2.new(0, math.min(top.y, maximum))
            end
        end
    end
end)
end -- fin du bloc des tops

-- ---------- 📺 L'ÉCRAN GÉANT : qui se bat dans l'arène, en direct ----------
local ajouterKillEcran
do
local lignesEcran, killsEcran = {}, {}
local zoneListe, zoneKills
task.spawn(function()
    local ecran = lobbyCarte and lobbyCarte:WaitForChild("EcranGeant", 30)
    if not ecran then
        return
    end
    local surface = nouveau("SurfaceGui", { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 25, LightInfluence = 0, Parent = ecran })
    local fondEcran = nouveau("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 6, 8), BorderSizePixel = 0, Parent = surface })
    texte({ Position = UDim2.fromScale(0.03, 0.03), Size = UDim2.fromScale(0.5, 0.12), Text = "🔴 LIVE  ·  ARENA", TextColor3 = Color3.fromRGB(255, 90, 90), TextXAlignment = Enum.TextXAlignment.Left, Parent = fondEcran })
    texte({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.97, 0.03), Size = UDim2.fromScale(0.4, 0.12), Text = "LAST KILLS", TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Right, Parent = fondEcran })
    zoneListe = nouveau("Frame", { Position = UDim2.fromScale(0.03, 0.18), Size = UDim2.fromScale(0.5, 0.78), BackgroundTransparency = 1, Parent = fondEcran })
    nouveau("UIListLayout", { Padding = UDim.new(0.01, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = zoneListe })
    zoneKills = nouveau("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.97, 0.18), Size = UDim2.fromScale(0.42, 0.78), BackgroundTransparency = 1, Parent = fondEcran })
    nouveau("UIListLayout", { Padding = UDim.new(0.015, 0), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Parent = zoneKills })
    for k = 1, 8 do
        local ligne = nouveau("Frame", { Size = UDim2.fromScale(1, 0.115), BackgroundColor3 = Color3.fromRGB(18, 18, 22), BorderSizePixel = 0, LayoutOrder = k, Visible = false, Parent = zoneListe })
        nouveau("UICorner", { CornerRadius = UDim.new(0.2, 0), Parent = ligne })
        local l = { cadre = ligne }
        l.nom = texte({ Position = UDim2.fromScale(0.03, 0.1), Size = UDim2.fromScale(0.55, 0.8), RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = ligne })
        local fond = nouveau("Frame", { Position = UDim2.fromScale(0.6, 0.35), Size = UDim2.fromScale(0.28, 0.3), BackgroundColor3 = Color3.fromRGB(40, 40, 46), BorderSizePixel = 0, Parent = ligne })
        l.pv = nouveau("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLANC, BorderSizePixel = 0, Parent = fond })
        l.serie = texte({ Position = UDim2.fromScale(0.9, 0.1), Size = UDim2.fromScale(0.09, 0.8), TextColor3 = OR, Parent = ligne })
        lignesEcran[k] = l
    end
end)
ajouterKillEcran = function(infos)
    if not zoneKills then
        return
    end
    local ligne = texte({
        Size = UDim2.fromScale(1, 0.13),
        RichText = true,
        Text = (if infos.tueur then enCouleur(tostring(infos.tueur), COULEURS[infos.tueurPerso] or BLANC) else "☠") .. "  ›  " .. enCouleur(tostring(infos.victime), COULEURS[infos.victimePerso] or BLANC),
        TextXAlignment = Enum.TextXAlignment.Right,
        LayoutOrder = -math.floor(os.clock() * 100),
        Parent = zoneKills,
    })
    table.insert(killsEcran, 1, ligne)
    while #killsEcran > 6 do
        table.remove(killsEcran):Destroy()
    end
end
task.spawn(function()
    while true do
        task.wait(0.25)
        if #lignesEcran > 0 then
            local liste = {}
            for modele, etat in pairs(etats) do
                if modele:GetAttribute("Arene") and etat.humanoid.Health > 0 then
                    table.insert(liste, etat)
                end
            end
            table.sort(liste, function(a, b)
                return (a.modele:GetAttribute("Serie") or 0) > (b.modele:GetAttribute("Serie") or 0)
            end)
            for k, l in ipairs(lignesEcran) do
                local etat = liste[k]
                l.cadre.Visible = etat ~= nil
                if etat then
                    local perso = etat.modele:GetAttribute("Perso")
                    l.nom.Text = tostring(etat.modele:GetAttribute("Nom")) .. "  " .. enCouleur(string.upper(tostring(perso)), COULEURS[perso] or BLANC)
                    l.pv.Size = UDim2.fromScale(math.clamp(etat.humanoid.Health / math.max(etat.humanoid.MaxHealth, 1), 0, 1), 1)
                    local serie = etat.modele:GetAttribute("Serie") or 0
                    l.serie.Text = if serie > 0 then "🔥" .. serie else ""
                end
            end
        end
    end
end)
end -- fin du bloc de l'écran géant

-- ---------- 🧠 LA FICHE D'UN ÉTAT D'ESPRIT : quand tu t'approches de son sanctuaire (ou quand tu le choisis) ----------
local montrerFiche
do
local fiche = nouveau("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0), Size = UDim2.fromOffset(330, 330), BackgroundColor3 = FOND, BackgroundTransparency = 0.08, Visible = false, ZIndex = 25, Parent = gui })
nouveau("UICorner", { CornerRadius = UDim.new(0, 16), Parent = fiche })
local traitFiche = nouveau("UIStroke", { Thickness = 2, Parent = fiche })
local echelleFiche = nouveau("UIScale", { Scale = if surMobile then 0.75 else 1, Parent = fiche })
local function t(p)
    p.ZIndex = 26
    p.Parent = fiche
    p.TextXAlignment = p.TextXAlignment or Enum.TextXAlignment.Left
    return texte(p)
end
local fNom = t({ Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 34) })
local fDevise = t({ Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -32, 0, 18), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(220, 220, 230) })
local fLignes = {}
for k = 1, 5 do
    local y = 74 + (k - 1) * 50
    fLignes[k] = {
        nom = t({ Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, 18) }),
        texte = t({ Position = UDim2.fromOffset(16, y + 19), Size = UDim2.new(1, -32, 0, 26), Font = Enum.Font.GothamMedium, TextColor3 = GRIS, TextWrapped = true }),
    }
end
local ficheActuelle, finFiche = nil, 0
montrerFiche = function(perso, duree)
    local kit = KITS[perso]
    if not kit then
        fiche.Visible = false
        ficheActuelle = nil
        return
    end
    finFiche = if duree then os.clock() + duree else math.huge
    if ficheActuelle == perso and fiche.Visible then
        return
    end
    ficheActuelle = perso
    local couleur = COULEURS[perso]
    traitFiche.Color = couleur
    fNom.Text = string.upper(perso)
    fNom.TextColor3 = couleur
    fDevise.Text = kit.devise
    local lignes = {
        { "PASSIVE · " .. kit.passif.nom, kit.passif.texte },
        { "[1] " .. kit[1].nom, kit[1].texte },
        { "[2] " .. kit[2].nom, kit[2].texte },
        { "[3] " .. kit[3].nom, kit[3].texte },
        { "[G] ULT · " .. kit.ult.nom, kit.ult.texte },
    }
    for k, l in ipairs(fLignes) do
        l.nom.Text = lignes[k][1]
        l.nom.TextColor3 = if k == 5 then OR else couleur
        l.texte.Text = lignes[k][2]
    end
    fiche.Visible = true
    fiche.Position = UDim2.new(0, -340, 0.5, 0)
    tween(fiche, 0.35, { Position = UDim2.new(0, 16, 0.5, 0) }, Enum.EasingStyle.Back)
end
-- près d'un sanctuaire : sa fiche
task.spawn(function()
    local sanctuaires = {}
    for _, perso in ipairs(ORDRE_PERSOS) do
        sanctuaires[perso] = lobbyCarte and lobbyCarte:WaitForChild("Sanctuaire_" .. perso, 30)
    end
    while true do
        task.wait(0.25)
        local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
        local proche = nil
        if racine then
            for perso, socle in pairs(sanctuaires) do
                if socle and (socle.Position - racine.Position).Magnitude < 16 then
                    proche = perso
                end
            end
        end
        if proche then
            montrerFiche(proche)
        elseif ficheActuelle and os.clock() > finFiche - 1e9 and finFiche == math.huge then
            fiche.Visible = false
            ficheActuelle = nil
        elseif ficheActuelle and os.clock() > finFiche then
            fiche.Visible = false
            ficheActuelle = nil
        end
        -- un panneau ouvert se ferme si on s'éloigne
        if panneauOuvert and racine and panneauOuvert.point and (panneauOuvert.point.Position - racine.Position).Magnitude > 20 then
            fermerPanneaux()
        end
    end
end)
end -- fin du bloc des fiches


-- ========================== CE QUI ARRIVE (messages du serveur) ==========================
-- Les phrases de la trend (elles sortent à l'ultime de chacun, et quand la MOTIVATION s'éteint)
local LIGNES_TREND = {
    Motivation = "MOTIVATION gets you started.",
    Ego = "EGO wants everyone to watch.",
    Discipline = "DISCIPLINE keeps you going.",
    Obsession = "OBSESSION makes you unstoppable.",
}

-- 🎬 les animations des autres (et l'écho des tiennes, qu'on ignore)
AnimEvent.OnClientEvent:Connect(function(modele, nom)
    if not modele then
        return
    end
    if modele == joueur.Character then
        local deja = echos[nom]
        if nom == "Provoc" or (deja and os.clock() - deja < 0.45) then
            return
        end
    end
    if nom == "Provoc" then
        nom = if modele:GetAttribute("Perso") == "Ego" then "ProvocViens" else "ProvocSigma"
    end
    jouerAnim(modele, nom)
    local racine = modele:FindFirstChild("HumanoidRootPart")
    if not racine then
        return
    end
    local couleur = COULEURS[modele:GetAttribute("Perso")] or BLANC
    local proche = workspace.CurrentCamera and (racine.Position - workspace.CurrentCamera.CFrame.Position).Magnitude < 120
    if not proche then
        return
    end
    if nom == "Cri" or nom == "Miroir" or nom == "Contre" then
        onde(racine.Position, couleur, 10, true, 0.4)
        jouerSon("tic", 0.6, 0.4)
    elseif nom == "Traque" then
        onde(racine.Position, COULEURS.Obsession, 8, true)
        eclats(racine.Position, COULEURS.Obsession, 16, 1)
        jouerSon("vent", 2.8, 0.3, nil, 0.25)
    elseif nom == "GardeCassee" then
        eclats(racine.Position + Vector3.new(0, 1, 0), Color3.fromRGB(200, 210, 230), 20, 1.2)
        jouerSon("coup", 0.6, 0.6)
        notifier(if modele == joueur.Character then "GUARD BROKEN!" else "GUARD BREAK!", Color3.fromRGB(200, 210, 230))
    elseif nom == "MiroirReussi" or nom == "ContreReussi" then
        onde(racine.Position, BLANC, 12, true)
        jouerSon("boum", 1.4, 0.4, nil, 0.4)
        if modele == joueur.Character then
            impactFrame()
            notifier("COUNTER!", couleur)
        end
    end
end)

-- 💥 un coup a touché : étincelles, chiffre des dégâts, son, et les secousses si ça te concerne
ImpactEvent.OnClientEvent:Connect(function(cible, point, degats, bloque, attaquant, lourd, critique, rayon)
    local couleur = attaquant and COULEURS[attaquant:GetAttribute("Perso")] or BLANC
    local camera = workspace.CurrentCamera
    if typeof(point) ~= "Vector3" or not camera then
        return
    end
    local distance = (point - camera.CFrame.Position).Magnitude
    if rayon then
        -- une onde de choc au sol (SLAM, WALL)
        onde(point, couleur, rayon * 2, false, 0.45)
        onde(point, BLANC, rayon * 1.3, false, 0.3)
        eclats(point + Vector3.new(0, 1, 0), couleur, 24, 1.4)
        if distance < 60 then
            secousse(1.4)
        end
        jouerSon("boum", 1.1, 0.35, nil, 0.6)
        return
    end
    if distance > 160 then
        return
    end
    eclats(point, if bloque then Color3.fromRGB(190, 200, 220) else couleur, if lourd then 20 else 8, if lourd then 1.3 else 0.8)
    if lourd then
        onde(point, BLANC, if critique then 9 else 6, true, 0.25)
    end
    -- le chiffre qui s'envole
    local porteur = nouveau("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), Position = point, Parent = dossierEffets })
    local bulle = nouveau("BillboardGui", { Size = UDim2.fromOffset(if critique then 150 else 110, if critique then 46 else 36), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 150, Parent = porteur })
    local valeur = texte({
        Size = UDim2.fromScale(1, 1),
        Text = if bloque then "BLOCKED" elseif critique then "CRIT " .. degats else tostring(degats),
        TextColor3 = if bloque then Color3.fromRGB(190, 200, 220) elseif critique then OR elseif lourd then couleur:Lerp(BLANC, 0.4) else BLANC,
        TextStrokeTransparency = 0,
        Parent = bulle,
    })
    local decalage = Vector3.new((math.random() - 0.5) * 2, 0, (math.random() - 0.5) * 2)
    tween(porteur, 0.7, { Position = point + Vector3.new(0, 3.5, 0) + decalage }, Enum.EasingStyle.Quint)
    tween(valeur, 0.7, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quint)
    task.delay(0.75, function()
        porteur:Destroy()
    end)
    -- le son
    if bloque then
        jouerSon("tic", 0.55, 0.45, nil, 0.15)
    else
        jouerSon("coup", if lourd then 0.8 else 1 + math.random() * 0.2, if lourd then 0.6 else 0.4)
        if lourd then
            jouerSon("boum", 1.6, 0.25, nil, 0.3)
        end
    end
    -- ça te concerne ?
    local moi = joueur.Character
    if cible and cible == moi then
        if not bloque then
            flasher(ROUGE, if lourd then 0.3 else 0.12)
        end
        secousse(if lourd then 1.6 else 0.6)
        if lourd then
            impactFrame()
        end
    elseif attaquant and attaquant == moi then
        secousse(if lourd then 1 else 0.3)
        fovPulse = math.min(fovPulse, if lourd then -5 else -1.5)
        if lourd then
            impactFrame()
        end
    end
end)

-- ☠️ UN KILL : le fil des kills, l'écran géant, et l'EDIT NOIR ET BLANC si ça te concerne
KillEvent.OnClientEvent:Connect(function(infos)
    if type(infos) ~= "table" then
        return
    end
    hud.ajouterKill(infos)
    ajouterKillEcran(infos)
    local moi = joueur.Character
    local couleurTueur = COULEURS[infos.tueurPerso] or BLANC
    local couleurVictime = COULEURS[infos.victimePerso] or BLANC
    -- « DISCIPLINE > EGO » : comme dans la trend
    local phrase = if infos.tueurPerso
        then enCouleur(string.upper(infos.tueurPerso), couleurTueur) .. '  <font color="#FFFFFF">&gt;</font>  ' .. enCouleur(string.upper(tostring(infos.victimePerso)), couleurVictime)
        else enCouleur(string.upper(tostring(infos.victimePerso)), couleurVictime)
    local victime = infos.victimeModele
    local racine = victime and victime:FindFirstChild("HumanoidRootPart")
    if racine then
        onde(racine.Position, BLANC, 14, true, 0.5)
        eclats(racine.Position, couleurVictime, 30, 1.6)
    end
    if infos.tueurModele and infos.tueurModele == moi then
        editNoirEtBlanc(1.6, 1)
        modeCinema(1.6)
        impactFrame()
        fovPulse = -12
        secousse(2)
        jouerSon("boum", 0.7, 0.6, nil, 1)
        jouerSon("tic", 1, 0.5, 0.05)
        jouerSon("tic", 1.5, 0.45, 0.12)
        local serie = infos.serie or 1
        annoncer(phrase, if serie >= 2 then serie .. " KILL STREAK" else "KILL", 1.8)
        if serie == 3 or serie == 5 or serie == 10 then
            dire(LIGNES_TREND[infos.tueurPerso] or "", couleurTueur, true)
        end
    elseif victime and victime == moi then
        editNoirEtBlanc(3.5, 1.3)
        modeCinema(3.5)
        impactFrame()
        flou.Size = 10
        tween(flou, 3, { Size = 0 })
        annoncer(phrase, if infos.tueur then "Defeated by " .. tostring(infos.tueur) else "Defeated", 3)
        jouerSon("boum", 0.5, 0.6, nil, 1.5)
    elseif racine and workspace.CurrentCamera and (racine.Position - workspace.CurrentCamera.CFrame.Position).Magnitude < 90 then
        editNoirEtBlanc(0.45, 0.6)
    end
end)

-- ⚡ UN ULTIME : l'edit noir et blanc + la phrase de la trend, pour tous ceux qui sont autour
UltEvent.OnClientEvent:Connect(function(modele, perso)
    local racine = modele and modele:FindFirstChild("HumanoidRootPart")
    local camera = workspace.CurrentCamera
    if not racine or not camera then
        return
    end
    local couleur = COULEURS[perso] or BLANC
    local estMoi = modele == joueur.Character
    onde(racine.Position, couleur, 22, true, 0.6)
    onde(racine.Position - Vector3.new(0, 2.5, 0), BLANC, 30, false, 0.6)
    eclats(racine.Position, couleur, 40, 1.8)
    if estMoi or (racine.Position - camera.CFrame.Position).Magnitude < 120 then
        editNoirEtBlanc(1.4, 1.1)
        modeCinema(1.4)
        impactFrame()
        fovPulse = if estMoi then -16 else -8
        secousse(1.6)
        jouerSon("boum", 0.6, 0.55, nil, 1.2)
        jouerSon("tic", 0.75, 0.5, 0.1)
        jouerSon("tic", 1.12, 0.45, 0.2)
        jouerSon("tic", 1.5, 0.4, 0.3)
        local kit = KITS[perso]
        annoncer(enCouleur(kit and kit.ult.nom or "ULTIMATE", couleur), tostring(modele:GetAttribute("Nom") or ""), 1.6)
        dire(LIGNES_TREND[perso] or "", couleur, true)
    end
end)

-- 🪦 L'ÉCRAN DE MORT : qui t'a eu, tes stats de cette vie, le retour au lobby
do
local ecran = nouveau("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(420, 170), BackgroundColor3 = FOND, BackgroundTransparency = 0.1, Visible = false, ZIndex = 50, Parent = gui })
nouveau("UICorner", { CornerRadius = UDim.new(0, 16), Parent = ecran })
local traitEcran = nouveau("UIStroke", { Thickness = 2, Color = BLANC, Parent = ecran })
local echelle = nouveau("UIScale", { Parent = ecran })
local function t(p)
    p.ZIndex = 51
    p.Parent = p.Parent or ecran
    return texte(p)
end
local titre = t({ Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 34), Text = "DEFEATED" })
local parQui = t({ Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -32, 0, 20), RichText = true, Font = Enum.Font.GothamBold, TextColor3 = GRIS })
local cases = {}
for i, nom in ipairs({ "KILLS", "DAMAGE", "SURVIVED" }) do
    local case = nouveau("Frame", { Position = UDim2.new((i - 1) / 3, 12, 0, 76), Size = UDim2.new(1 / 3, -24, 0, 54), BackgroundColor3 = Color3.fromRGB(24, 24, 32), ZIndex = 51, Parent = ecran })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 10), Parent = case })
    cases[i] = t({ Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 28), Parent = case })
    t({ Position = UDim2.fromOffset(6, 33), Size = UDim2.new(1, -12, 0, 16), Text = nom, Font = Enum.Font.GothamBold, TextColor3 = GRIS, Parent = case })
end
local retour = t({ Position = UDim2.fromOffset(16, 138), Size = UDim2.new(1, -32, 0, 20), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 200, 215) })
local numero = 0
FinEvent.OnClientEvent:Connect(function(data)
    if type(data) ~= "table" then
        return
    end
    numero += 1
    local moi = numero
    local couleur = COULEURS[data.tueurPerso] or BLANC
    traitEcran.Color = couleur
    parQui.Text = if data.tueur then "by " .. enCouleur(tostring(data.tueur), couleur) .. "  ·  " .. enCouleur(string.upper(tostring(data.tueurPerso)), couleur) else ""
    cases[1].Text = tostring(data.kills or 0)
    cases[2].Text = tostring(data.degats or 0)
    cases[3].Text = tostring(data.survie or 0) .. "s"
    ecran.Visible = true
    echelle.Scale = 0.6
    tween(echelle, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
    local fin = os.clock() + (data.reapparition or 4)
    task.spawn(function()
        while moi == numero and os.clock() < fin do
            retour.Text = "Back to the lobby in " .. math.ceil(fin - os.clock()) .. "..."
            task.wait(0.1)
        end
        if moi == numero then
            ecran.Visible = false
        end
    end)
end)
end -- fin du bloc de l'écran de mort

-- 🗺️ tu entres dans l'arène / tu reviens au lobby
ZoneEvent.OnClientEvent:Connect(function(zone)
    if zone == "Arene" then
        fermerPanneaux()
        editNoirEtBlanc(0.8, 0.8)
        impactFrame()
        fovPulse = -10
        annoncer('<font color="#FF5A5A">FIGHT</font>', "Arena  ·  no mercy", 1.4)
        jouerSon("boum", 0.8, 0.45, nil, 0.8)
    elseif zone == "Lobby" then
        notifier("SAFE ZONE · Lobby", VERT)
    end
end)

-- 🔔 les petits messages du serveur
MessageEvent.OnClientEvent:Connect(function(type_, valeur)
    if type_ == "Choisi" then
        local couleur = COULEURS[valeur] or BLANC
        annoncer(enCouleur(string.upper(tostring(valeur)), couleur), KITS[valeur] and KITS[valeur].devise or "", 2)
        flasher(couleur, 0.3)
        secousse(0.6)
        sonClic(5)
        montrerFiche(valeur, 6)
        local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
        if racine then
            onde(racine.Position - Vector3.new(0, 2.5, 0), couleur, 14)
            eclats(racine.Position, couleur, 30, 1.2)
        end
    elseif type_ == "Parkour" then
        annoncer(enCouleur("PARKOUR CLEARED", OR), "+" .. tostring(valeur) .. " AURA", 2.5)
        flasher(OR, 0.4)
        jouerSon("tic", 1, 0.5)
        jouerSon("tic", 1.26, 0.5, 0.08)
        jouerSon("tic", 1.5, 0.5, 0.16)
        jouerSon("tic", 2, 0.5, 0.24)
    elseif type_ == "AFK" then
        notifier("+" .. tostring(valeur) .. " AURA  ·  AFK", Color3.fromRGB(150, 200, 255))
    elseif type_ == "SortieCombat" then
        notifier("You can't leave during a fight!", ROUGE)
    end
end)


-- ========================== LANGUE (anglais / français) ==========================
-- Tout le jeu est écrit en anglais. Ce bloc traduit À LA VOLÉE chaque texte affiché (l'interface,
-- les panneaux de la carte, les étiquettes, les boutons « E ») :
--   FR_EXACT  = les phrases fixes
--   FR_MOTIFS = les phrases avec des nombres ou des noms dedans (motifs Lua, %1 = ce qui est entre parenthèses)
-- Pour ajouter une traduction : ajoute une ligne ici, rien d'autre à toucher.
-- La langue se choisit dans SETTINGS (AUTO = la langue de Roblox du joueur).
local Langue = {}
do
local LocalizationService = game:GetService("LocalizationService")

local FR_EXACT = {
    -- les commandes, l'interface
    ["CLICK  punch combo\nF  block   ·   Q  dodge   ·   T  taunt\n1 2 3  skills   ·   G  ultimate"] = "CLIC  combo de coups\nF  bloquer   ·   Q  esquiver   ·   T  provoquer\n1 2 3  capacités   ·   G  ultime",
    ["UNSTOPPABLE"] = "INARRÊTABLE",
    ["SAFE ZONE  ·  LOBBY"] = "ZONE SANS DANGER  ·  LOBBY",
    ["SAFE ZONE · Lobby"] = "ZONE SANS DANGER · Lobby",
    ["PUNCH"] = "COUP",
    ["BLOCK"] = "GARDE",
    ["DODGE"] = "ESQUIVE",
    ["TAUNT"] = "PROVOC",
    ["BLOCKED"] = "BLOQUÉ",
    ["GUARD BROKEN!"] = "GARDE CASSÉE !",
    ["GUARD BREAK!"] = "GARDE BRISÉE !",
    ["COUNTER!"] = "CONTRE !",
    ["KILL"] = "KILL",
    ["Defeated"] = "Vaincu",
    ["DEFEATED"] = "VAINCU",
    ["DAMAGE"] = "DÉGÂTS",
    ["SURVIVED"] = "SURVIE",
    ['<font color="#FF5A5A">FIGHT</font>'] = '<font color="#FF5A5A">COMBAT</font>',
    ["Arena  ·  no mercy"] = "Arène  ·  aucune pitié",
    ['<font color="#FFDC50">PARKOUR CLEARED</font>'] = '<font color="#FFDC50">PARKOUR RÉUSSI</font>',
    ["You can't leave during a fight!"] = "Impossible de sortir pendant un combat !",
    ["SETTINGS"] = "PARAMÈTRES",
    -- la trend
    ["MOTIVATION gets you started."] = "La MOTIVATION te fait commencer.",
    ["But MOTIVATION fades..."] = "Mais la MOTIVATION s'éteint...",
    ["DISCIPLINE keeps you going."] = "La DISCIPLINE te fait continuer.",
    ["EGO wants everyone to watch."] = "L'EGO veut que tout le monde regarde.",
    ["OBSESSION makes you unstoppable."] = "L'OBSESSION te rend inarrêtable.",
    -- les kits (devises, passifs, capacités, ultimes)
    ["Fast start. Then it fades."] = "Départ en feu. Puis ça s'éteint.",
    ["Main character. Glass jaw."] = "Personnage principal. Mâchoire de verre.",
    ["Steady. Hard to kill."] = "Régulier. Dur à tuer.",
    ["Slow start. Unstoppable end."] = "Départ lent. Fin inarrêtable.",
    ["Huge damage and speed at full energy. Energy fades over time. Kills light it back up."] = "Énormes dégâts et vitesse à pleine énergie. L'énergie s'éteint avec le temps. Les kills la rallument.",
    ["+25% damage but less health. Double jump. Taunt (T) charges your ultimate."] = "+25 % de dégâts mais moins de PV. Double saut. Provoquer (T) charge ton ultime.",
    ["More health. Blocking stops 90% of the damage."] = "Plus de PV. Bloquer arrête 90 % des dégâts.",
    ["Every hit you land makes you stronger and faster (20 stacks max: unstoppable)."] = "Chaque coup donné te rend plus fort et plus rapide (20 crans max : inarrêtable).",
    ["Dash forward with a burning punch"] = "Fonce en avant avec un poing en feu",
    ["A flurry of 5 fast punches"] = "Une rafale de 5 coups rapides",
    ["Get 40% of your energy back"] = "Récupère 40 % de ton énergie",
    ["An uppercut that launches the enemy"] = "Un uppercut qui envoie l'ennemi en l'air",
    ["Jump and slam the ground (breaks guards)"] = "Saute et frappe le sol (casse les gardes)",
    ["Counter stance: the next hit is sent back"] = "Posture de contre : le prochain coup est renvoyé",
    ["Parry stance: punish the next attack"] = "Parade : punis la prochaine attaque",
    ["3 heavy hits that nothing can interrupt"] = "3 coups lourds que rien n'arrête",
    ["A shockwave that pushes everyone away"] = "Une onde de choc qui repousse tout le monde",
    ["Teleport behind the closest enemy and hit"] = "Téléporte-toi derrière l'ennemi le plus proche et frappe",
    ["Grab the enemy and hit 3 times"] = "Attrape l'ennemi et frappe 3 fois",
    ["5 s of much faster punches"] = "5 s de coups beaucoup plus rapides",
    ["8 s at full energy: +50% damage, faster"] = "8 s à pleine énergie : +50 % de dégâts, plus rapide",
    ["8 s: every hit is a critical hit"] = "8 s : chaque coup est un coup critique",
    ["8 s: 70% less damage, can't be stunned"] = "8 s : 70 % de dégâts en moins, impossible à étourdir",
    ["8 s: max stacks and every hit heals you"] = "8 s : crans au max et chaque coup te soigne",
    -- le lobby
    ["Spend the aura you farm in the arena to upgrade your mindset."] = "Dépense l'aura que tu farmes dans l'arène pour améliorer ton état d'esprit.",
    ["UPGRADE"] = "AMÉLIORER",
    ["MAX LEVEL"] = "NIVEAU MAX",
    ["Already at max level."] = "Déjà au niveau max.",
    ["Already at max level"] = "Déjà au niveau max",
    ["Not enough aura"] = "Pas assez d'aura",
    ["Still loading your data..."] = "Chargement de tes données...",
    ["Wait a second..."] = "Attends une seconde...",
    ["Try again in a second..."] = "Réessaie dans une seconde...",
    ["Unknown skill"] = "Compétence inconnue",
    ["TOP 100  ·  BEST STREAK"] = "TOP 100  ·  MEILLEURE SÉRIE",
    ["the most kills of all time"] = "le plus de kills de tous les temps",
    ["the most kills in a row without dying"] = "le plus de kills d'affilée sans mourir",
    ["Loading..."] = "Chargement...",
    ["Leaderboard unavailable for now"] = "Classement indisponible pour l'instant",
    ["No record yet: be the first!"] = "Pas encore de record : sois le premier !",
    ["YOU: —  (go fight!)"] = "TOI : —  (va te battre !)",
    ["🔴 LIVE  ·  ARENA"] = "🔴 EN DIRECT  ·  ARÈNE",
    ["LAST KILLS"] = "DERNIERS KILLS",
    ["ENTER THE ARENA"] = "ENTRER DANS L'ARÈNE",
    ["EXIT"] = "SORTIE",
    ["AFK ZONE · FREE AURA"] = "ZONE AFK · AURA GRATUITE",
    ["AURA MERCHANT"] = "MARCHAND D'AURA",
    ["Mindset"] = "État d'esprit",
    ["Upgrade"] = "Améliorer",
    ["Aura Merchant"] = "Marchand d'aura",
    ["View"] = "Voir",
    ["Top 100 · Best streak"] = "Top 100 · Meilleure série",
    -- les paramètres
    ["CLOSE"] = "FERMER",
    ["MUSIC"] = "MUSIQUE",
    ["SOUND EFFECTS (clicks, menu sounds, effects)"] = "BRUITAGES (clics, sons du menu, effets)",
    ["SCREEN SHAKE"] = "SECOUSSES DE L'ÉCRAN",
    ["FLASHING LIGHTS"] = "FLASHS LUMINEUX",
    ["LANGUAGE"] = "LANGUE",
    ["Your settings are saved for next time."] = "Tes paramètres sont sauvegardés pour la prochaine fois.",
}

local traduire -- (défini plus bas : les motifs s'en servent pour traduire un morceau de phrase)
local FR_MOTIFS = {
    { "^ENERGY (%d+)%%$", "ÉNERGIE %1 %%" },
    { "^STACKS (%d+) / (%d+)$", "CRANS %1 / %2" },
    { "^⚔ ARENA  ·  (%d+) FIGHTERS$", "⚔ ARÈNE  ·  %1 COMBATTANTS" },
    { "^🔥 (%d+) KILL STREAK$", "🔥 SÉRIE DE %1 KILLS" },
    { "^(%d+) KILL STREAK$", "SÉRIE DE %1 KILLS" },
    { "^CRIT (%d+)$", "CRITIQUE %1" },
    { "^Defeated by (.+)$", "Vaincu par %1" },
    { "^by (.+)$", "par %1" },
    { "^Back to the lobby in (%d+)%.%.%.$", "Retour au lobby dans %1..." },
    { "^Become (.+)$", "Devenir %1" },
    { "^PASSIVE · (.+)$", "PASSIF · %1" },
    { "^%[G%] ULT · (.+)$", "[G] ULTIME · %1" },
    { "^(%d+) kills$", "%1 kills" },
    { "^(%d+) in a row$", "%1 d'affilée" },
    { "^YOU: (.+)  ·  RANK #(%d+)$", function(score, rang)
        return "TOI : " .. traduire(score) .. "  ·  RANG #" .. rang
    end },
    { "^YOU: (.+)  ·  not in the top 100 yet$", function(score)
        return "TOI : " .. traduire(score) .. "  ·  pas encore dans le top 100"
    end },
    -- le texte des sanctuaires : la devise, puis « PASSIF · son texte »
    { '^(.-)\n\n<font color="#AAAAB4">(.-) · (.-)</font>$', function(devise, nom, explication)
        return traduire(devise) .. '\n\n<font color="#AAAAB4">' .. nom .. " · " .. traduire(explication) .. "</font>"
    end },
    -- la boutique
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
    { "^Not enough aura: you need (%d+) more%. Fight to farm some!$", "Pas assez d'aura : il t'en manque %1. Bats-toi pour en farmer !" },
    -- les compétences du marchand (textes du serveur)
    { "^Energy fades (%d+)%% slower$", "L'énergie s'éteint %1 %% moins vite" },
    { "^RUSH and FIRE FISTS deal %+(%d+)%% damage$", "RUSH et FIRE FISTS font +%1 %% de dégâts" },
    { "^Kills give back (%d+)%% more energy$", "Les kills rendent %1 %% d'énergie en plus" },
    { "^%+(%d+) max health$", "+%1 PV max" },
    { "^SHOWTIME and SLAM deal %+(%d+)%% damage$", "SHOWTIME et SLAM font +%1 %% de dégâts" },
    { "^Your ultimate charges (%d+)%% faster$", "Ton ultime se charge %1 %% plus vite" },
    { "^Every blocked hit heals you (%d+) HP$", "Chaque coup bloqué te soigne de %1 PV" },
    { "^ROUTINE deals %+(%d+)%% damage$", "ROUTINE fait +%1 %% de dégâts" },
    { "^%+(%d+)%% aura earned$", "+%1 %% d'aura gagnée" },
    { "^%+(%d+) max stacks$", "+%1 crans max" },
    { "^HUNT recharges (%d+)%% faster$", "HUNT se recharge %1 %% plus vite" },
    { "^Heal (%d+)%% of the damage you deal$", "Tu récupères %1 %% des dégâts que tu fais" },
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
local ouvrirReglages
do
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

ouvrirReglages = function()
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
end -- fin du bloc des paramètres

-- le bouton SETTINGS (en haut à gauche, sous l'aura)
do
    local b = bouton({ Position = UDim2.new(0, 16, 0, 108), Size = UDim2.fromOffset(150, 36), Text = "SETTINGS", ZIndex = 10, Parent = gui }, Color3.fromRGB(200, 200, 220), false, 3)
    b.Activated:Connect(function()
        sonClic(4)
        ouvrirReglages()
    end)
end

-- ========================== LA MUSIQUE ==========================
-- Une musique au hasard en fond, puis la suivante (le volume se règle dans SETTINGS).
do
local MUSIQUES = lireJson("Musiques", {})
local musique = nouveau("Sound", { Name = "MindsetMusique", Volume = 0.4, SoundGroup = groupeMusique, Parent = SoundService })
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
-- les animations de tout le monde, l'interface, et les moments de la trend propres à TON état d'esprit
local moments = { modele = nil, motivationEteinte = false, obsessionMax = false }
RunService.RenderStepped:Connect(function()
    animerCombattants()
    majHUD()
    local modele = joueur.Character
    if not modele or not modele:GetAttribute("Arene") then
        return
    end
    if moments.modele ~= modele then
        moments.modele, moments.motivationEteinte, moments.obsessionMax = modele, false, false
    end
    local perso = modele:GetAttribute("Perso")
    if perso == "Motivation" then
        local energie = modele:GetAttribute("Energie") or 1
        if energie < 0.45 and not moments.motivationEteinte then
            -- « But MOTIVATION fades... » : comme dans la trend
            moments.motivationEteinte = true
            dire("But MOTIVATION fades...", COULEURS.Motivation)
            editNoirEtBlanc(0.8, 0.6)
        elseif energie > 0.85 then
            moments.motivationEteinte = false
        end
    elseif perso == "Obsession" then
        local auMax = (modele:GetAttribute("Crans") or 0) >= (modele:GetAttribute("CransMax") or 20)
        if auMax and not moments.obsessionMax then
            moments.obsessionMax = true
            annoncer(enCouleur("UNSTOPPABLE", COULEURS.Obsession), "", 1.4)
            editNoirEtBlanc(0.9, 0.8)
            impactFrame()
            dire("OBSESSION makes you unstoppable.", COULEURS.Obsession)
        end
    end
end)
