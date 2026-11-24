--[[
    🧠 MINDSET STAIRS — MENU 3D (script CLIENT)
    À mettre dans : StarterPlayer > StarterPlayerScripts  (type : LocalScript, nom : MindsetHub)
    (à côté de MindsetClient : les deux scripts se parlent par le dossier « MindsetLiens » du joueur)

    Le HUB est une place 3D, loin des escaliers, où on se BALADE avec son avatar (comme dans la plupart
    des jeux Roblox) et où on voit les autres joueurs, avec leur état d'esprit, leur niveau et leur record :
      à GAUCHE  : le MARCHAND D'AURA → touche E devant lui : tu améliores les compétences de ton état d'esprit
      au MILIEU : le PORTAIL → tu marches dedans : la caméra plonge (transition) et tu arrives dans le jeu
      à DROITE  : 2 TOP 100 du monde entier (le plus de marches en UNE partie / en TOUT) → touche E pour les voir en grand
    Le serveur pose ton avatar sur la place (attribut « Hub » du grimpeur) ; le script du jeu ne le touche plus.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")

local joueur = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("MindsetRemotes")
local ChoisirEvent = remotes:WaitForChild("Choisir")
local AmeliorerFonction = remotes:WaitForChild("Ameliorer")
local ClassementFonction = remotes:WaitForChild("Classement")
local JouerEvent = remotes:WaitForChild("Jouer") -- "Hub" = retour sur la place
local liens = joueur:WaitForChild("MindsetLiens")
local versJeu = liens:WaitForChild("VersJeu") -- vers le script du jeu : "Jouer", "Afk", "Classements", "Reglages", "MenuOuvert"
local versHub = liens:WaitForChild("VersHub") -- du script du jeu : "Ouvrir" (bouton MENU)

local COULEURS = {
    Motivation = Color3.fromRGB(255, 150, 30),
    Ego = Color3.fromRGB(170, 80, 255),
    Discipline = Color3.fromRGB(60, 140, 255),
    Obsession = Color3.fromRGB(230, 40, 60),
}
local ORDRE_PERSOS = { "Motivation", "Ego", "Discipline", "Obsession" }
local DEVISES = {
    Motivation = "The fire of the start",
    Ego = "The king of combos",
    Discipline = "The unbreakable wall",
    Obsession = "The late-game monster",
}
local BLANC = Color3.new(1, 1, 1)
local NOIR = Color3.new(0, 0, 0)
local OR = Color3.fromRGB(255, 220, 80)
local ROUGE = Color3.fromRGB(255, 90, 90)
local VIOLET = Color3.fromRGB(170, 90, 255)
local VERT = Color3.fromRGB(110, 230, 160)
local GRIS = Color3.fromRGB(170, 170, 190)
local FOND_PANNEAU = Color3.fromRGB(12, 12, 20)
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
    proprietes.Font = proprietes.Font or Enum.Font.GothamBold
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

local function auHasard(liste)
    return liste[math.random(1, #liste)]
end

-- 🧠 Les compétences (définies dans le script serveur) et TES niveaux (attribut « Niveaux » du joueur)
local DEFS = { couts = {}, persos = {} }
local function lireDefs()
    local ok, defs = pcall(function()
        return HttpService:JSONDecode(ReplicatedStorage:GetAttribute("Competences"))
    end)
    if ok and type(defs) == "table" then
        DEFS = defs
    end
end
lireDefs()
ReplicatedStorage:GetAttributeChangedSignal("Competences"):Connect(lireDefs)

-- (cible = un autre joueur : ses niveaux à lui, pour son étiquette dans le hub)
local function mesNiveaux(perso, cible)
    local ok, niveaux = pcall(function()
        return HttpService:JSONDecode((cible or joueur):GetAttribute("Niveaux"))
    end)
    local liste = ok and type(niveaux) == "table" and niveaux[perso]
    return if type(liste) == "table" then liste else {}
end

local function effetCompetence(def, niveau)
    return string.format(def.texte, tostring(def.valeurs[math.min(niveau, #def.valeurs)]))
end

-- ========================== SONS ==========================
local jouerSon, sonSurvol, sonClic
do
    local groupe = SoundService:WaitForChild("MindsetGroupeBruitages", 10)
    local SONS = {
        tic = "rbxasset://sounds/volume_slider.ogg",
        clic = "rbxassetid://12221967",
        pose = "rbxasset://sounds/action_jump_land.mp3",
        vent = "rbxasset://sounds/action_falling.mp3",
        boum = "rbxasset://sounds/impact_explosion_03.mp3",
    }
    local modeles = {}
    for nom, id in pairs(SONS) do
        modeles[nom] = nouveau("Sound", { Name = "MindsetHub_" .. nom, SoundId = id, Volume = 0.5, SoundGroup = groupe, Parent = SoundService })
    end
    jouerSon = function(nom, vitesse, volume, retard, coupe)
        local modele = modeles[nom]
        if not modele then
            return
        end
        task.delay(retard or 0, function()
            local son = modele:Clone()
            son.PlaybackSpeed = vitesse or 1
            son.Volume = volume or 0.5
            son.Parent = SoundService
            son:Play()
            if coupe then
                task.delay(coupe, function()
                    if son.Parent then
                        tween(son, 0.1, { Volume = 0 })
                    end
                end)
            end
            task.delay(if coupe then coupe + 0.2 else 4, function()
                son:Destroy()
            end)
        end)
    end
    local GAMME = { 1, 1.122, 1.26, 1.498, 1.682, 2, 2.245 }
    sonSurvol = function(note)
        jouerSon("tic", 2.1 * (1 + ((GAMME[note] or 1) - 1) * 0.45), 0.12, nil, 0.09)
    end
    sonClic = function(note)
        local base = GAMME[note] or 1
        jouerSon("clic", 1, 0.7)
        jouerSon("tic", base * 0.75, 0.5)
        jouerSon("tic", base * 1.5, 0.4, 0.07)
        jouerSon("tic", base * 2, 0.3, 0.14)
    end
end

-- ========================== LA SCÈNE 3D ==========================
-- Elle est construite par ce script (chez toi seulement), très loin des escaliers.
local O = Vector3.new(-3000, 400, 0) -- le centre de la place
local SOL = O.Y + 0.5               -- le dessus du sol
local R = 34                        -- distance entre le centre et les 3 endroits
local SHOP, PORTAIL, TABLEAU = 1, 2, 3
local STATIONS = {
    { nom = "AURA SHOP", angle = math.rad(-55), couleur = VIOLET, vise = 6.5, decalage = 8 },
    { nom = "PLAY", angle = 0, couleur = OR, vise = 9, decalage = 0 },
    { nom = "LEADERBOARD", angle = math.rad(55), couleur = VERT, vise = 9.5, decalage = 0 },
}
local function direction(angle)
    return Vector3.new(math.sin(angle), 0, -math.cos(angle))
end
local function droite(angle)
    return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

local ancienneScene = workspace:FindFirstChild("MindsetHubScene")
if ancienneScene then
    ancienneScene:Destroy()
end
local scene = nouveau("Folder", { Name = "MindsetHubScene", Parent = workspace })
local animes = {} -- petites choses qui flottent : { part, cf, phase, amplitude }

local function bloc(proprietes)
    proprietes.Anchored = true
    proprietes.CanCollide = false
    proprietes.CanTouch = false
    proprietes.CastShadow = false
    proprietes.Material = proprietes.Material or Enum.Material.SmoothPlastic
    proprietes.TopSurface = Enum.SurfaceType.Smooth
    proprietes.BottomSurface = Enum.SurfaceType.Smooth
    return nouveau("Part", proprietes)
end

local function neon(proprietes)
    proprietes.Material = Enum.Material.Neon
    return bloc(proprietes)
end

-- une part contre laquelle on se cogne (comptoir, mur, socle...) : le reste de la déco, on passe à travers
local function solide(part)
    part.CanCollide = true
    return part
end

-- un texte posé sur une face d'une part (panneau, chiffre du podium...)
local function panneauTexte(part, message, couleur, police)
    local surface = nouveau("SurfaceGui", {
        Face = Enum.NormalId.Front,
        SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
        PixelsPerStud = 40,
        LightInfluence = 0,
        Parent = part,
    })
    local label = texte({ Size = UDim2.fromScale(1, 1), Text = message, TextColor3 = couleur, Font = police or Enum.Font.GothamBlack, Parent = surface })
    nouveau("UIPadding", { PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0), PaddingLeft = UDim.new(0.05, 0), PaddingRight = UDim.new(0.05, 0), Parent = label })
    return label, surface
end

local function couleurAnneau(fraction)
    local f = (fraction % 1) * 4
    local c1 = COULEURS[ORDRE_PERSOS[math.floor(f) % 4 + 1]]
    local c2 = COULEURS[ORDRE_PERSOS[(math.floor(f) + 1) % 4 + 1]]
    return c1:Lerp(c2, f % 1)
end

-- un avatar (marchand ou copie du tien) posé, ancré, avec son animation d'attente
local function hauteurRacine(modele)
    local humanoid = modele:FindFirstChildOfClass("Humanoid")
    local racine = modele:FindFirstChild("HumanoidRootPart")
    if humanoid and racine and humanoid.RigType == Enum.HumanoidRigType.R15 then
        return humanoid.HipHeight + racine.Size.Y / 2
    end
    return 3
end

local function poserAvatar(modele, cfSol)
    local racine = modele:FindFirstChild("HumanoidRootPart")
    local humanoid = modele:FindFirstChildOfClass("Humanoid")
    if not racine or not humanoid then
        return nil
    end
    racine.Anchored = true
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    for _, objet in ipairs(modele:GetDescendants()) do
        if objet:IsA("BasePart") then
            objet.CanCollide = false
            objet.CanTouch = false
            objet.CanQuery = true
        end
    end
    modele:PivotTo(cfSol * CFrame.new(0, hauteurRacine(modele), 0))
    local animator = humanoid:FindFirstChildOfClass("Animator") or nouveau("Animator", { Parent = humanoid })
    local pistes = {}
    local function charger(nom, id, boucle, priorite)
        local animation = Instance.new("Animation")
        animation.AnimationId = id
        local ok, piste = pcall(function()
            return animator:LoadAnimation(animation)
        end)
        if ok and piste then
            piste.Looped = boucle
            piste.Priority = priorite
            pistes[nom] = piste
        end
    end
    -- animations R15 de base de Roblox : attente, coucou, joie
    charger("attente", "rbxassetid://507766388", true, Enum.AnimationPriority.Idle)
    charger("coucou", "rbxassetid://507770239", false, Enum.AnimationPriority.Action)
    charger("joie", "rbxassetid://507770677", false, Enum.AnimationPriority.Action)
    if pistes.attente then
        pistes.attente:Play()
    end
    return pistes
end

-- colle une petite part (yeux, chapeau...) sur une part d'un avatar
local function coller(cible, proprietes)
    proprietes.Anchored = false
    proprietes.Massless = true
    proprietes.CanCollide = false
    proprietes.CanTouch = false
    proprietes.CastShadow = false
    local part = nouveau("Part", proprietes)
    nouveau("WeldConstraint", { Part0 = cible, Part1 = part, Parent = part })
    return part
end

local modelesStations = {}
local function modeleStation(numero, nom)
    local modele = nouveau("Model", { Name = nom, Parent = scene })
    modele:SetAttribute("Station", numero)
    modelesStations[numero] = modele
    return modele
end

-- ---------- le sol : une grande place ronde avec des cercles néon ----------
do
    bloc({
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(1, 118, 118),
        CFrame = CFrame.new(O) * CFrame.Angles(0, 0, math.pi / 2),
        Color = Color3.fromRGB(16, 14, 26),
        Parent = scene,
    })
    local function anneauSol(rayon, nombre, largeur, couleurFixe)
        for i = 0, nombre - 1 do
            local a = i / nombre * math.pi * 2
            local position = Vector3.new(O.X + math.cos(a) * rayon, SOL + 0.03, O.Z + math.sin(a) * rayon)
            local tangente = Vector3.new(-math.sin(a), 0, math.cos(a))
            neon({
                Size = Vector3.new(largeur, 0.06, 2 * math.pi * rayon / nombre * 1.03),
                CFrame = CFrame.lookAt(position, position + tangente),
                Color = couleurFixe or couleurAnneau(i / nombre),
                Parent = scene,
            })
        end
    end
    anneauSol(57, 80, 0.6, nil)
    anneauSol(12, 40, 0.3, Color3.fromRGB(90, 80, 140))
    -- un chemin lumineux vers chaque endroit
    for _, station in ipairs(STATIONS) do
        local d = direction(station.angle)
        local position = Vector3.new(O.X, SOL + 0.03, O.Z) + d * ((12 + R - 8) / 2)
        neon({
            Size = Vector3.new(0.35, 0.06, R - 20),
            CFrame = CFrame.lookAt(position, position + d),
            Color = station.couleur,
            Transparency = 0.25,
            Parent = scene,
        })
    end
    -- des cubes qui flottent autour de la place
    for i = 1, 24 do
        local a = i / 24 * math.pi * 2 + math.random() * 0.2
        local distance = 66 + math.random() * 30
        local position = Vector3.new(O.X + math.cos(a) * distance, SOL + 6 + math.random() * 30, O.Z + math.sin(a) * distance)
        local cote = 1 + math.random() * 2.5
        local cube = neon({
            Size = Vector3.new(cote, cote, cote),
            CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 3, math.random() * 3, 0),
            Color = couleurAnneau(math.random()),
            Transparency = 0.15,
            Parent = scene,
        })
        table.insert(animes, { part = cube, cf = cube.CFrame, phase = math.random() * 6, amplitude = 1.5, tourne = true })
    end
    -- de la poussière lumineuse dans l'air
    local poussiere = bloc({ Size = Vector3.new(110, 30, 110), CFrame = CFrame.new(O + Vector3.new(0, 18, 0)), Transparency = 1, CanQuery = false, Parent = scene })
    nouveau("ParticleEmitter", {
        Rate = 25,
        Lifetime = NumberRange.new(5, 9),
        Speed = NumberRange.new(0.2, 0.8),
        SpreadAngle = Vector2.new(180, 180),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 0) }),
        LightEmission = 1,
        Color = ColorSequence.new(Color3.fromRGB(200, 180, 255)),
        Parent = poussiere,
    })
end

-- ---------- AU MILIEU : le PORTAIL (PLAY) + ta copie devant + l'escalier infini derrière ----------
local CENTRE_PORTAIL, anneauPortail, emetteurPortail, lumierePortail, socleAvatar
do
    local modele = modeleStation(PORTAIL, "Portail")
    local d = direction(0)
    local base = Vector3.new(O.X, SOL, O.Z) + d * R
    local RAYON = 9
    CENTRE_PORTAIL = base + Vector3.new(0, 10.5, 0)

    -- le socle avec ses marches
    solide(bloc({ Size = Vector3.new(24, 1, 9), CFrame = CFrame.new(base + Vector3.new(0, 0.5, 0)), Color = Color3.fromRGB(26, 22, 40), Parent = modele }))
    -- une petite marche devant le socle pour monter dessus sans sauter
    solide(bloc({ Size = Vector3.new(24, 0.5, 2), CFrame = CFrame.new(base + Vector3.new(0, 0.25, 5.5)), Color = Color3.fromRGB(26, 22, 40), Parent = modele }))
    neon({ Size = Vector3.new(24.1, 0.15, 0.2), CFrame = CFrame.new(base + Vector3.new(0, 1, 4.5)), Color = OR, Parent = modele })
    socleAvatar = CFrame.lookAt(base + Vector3.new(0, 1, 2), base + Vector3.new(0, 1, 10)) -- là où tu te tiens (tourné vers la caméra)

    -- le fond du portail (un vide sombre) et sa « membrane » qui ondule
    bloc({
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(0.2, RAYON * 2 - 0.4, RAYON * 2 - 0.4),
        CFrame = CFrame.new(CENTRE_PORTAIL - Vector3.new(0, 0, 0.5)) * CFrame.Angles(0, math.pi / 2, 0),
        Color = Color3.fromRGB(10, 5, 20),
        Parent = modele,
    })
    bloc({
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(0.2, RAYON * 2 - 0.4, RAYON * 2 - 0.4),
        CFrame = CFrame.new(CENTRE_PORTAIL) * CFrame.Angles(0, math.pi / 2, 0),
        Material = Enum.Material.ForceField,
        Color = Color3.fromRGB(170, 110, 255),
        Parent = modele,
    })
    -- le cadre sombre (fixe) et l'anneau néon aux 4 couleurs (qui tourne)
    local NB = 44
    for i = 0, NB - 1 do
        local a = i / NB * math.pi * 2
        local position = CENTRE_PORTAIL + Vector3.new(math.cos(a) * (RAYON + 1.1), math.sin(a) * (RAYON + 1.1), -0.2)
        local tangente = Vector3.new(-math.sin(a), math.cos(a), 0)
        bloc({
            Size = Vector3.new(1.4, 1.6, 2 * math.pi * (RAYON + 1.1) / NB * 1.08),
            CFrame = CFrame.lookAt(position, position + tangente, Vector3.new(0, 0, 1)),
            Color = Color3.fromRGB(30, 26, 46),
            Parent = modele,
        })
    end
    anneauPortail = nouveau("Model", { Name = "Anneau", Parent = modele })
    anneauPortail.PrimaryPart = bloc({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(CENTRE_PORTAIL), Parent = anneauPortail })
    for i = 0, NB - 1 do
        local a = i / NB * math.pi * 2
        local position = CENTRE_PORTAIL + Vector3.new(math.cos(a) * RAYON, math.sin(a) * RAYON, 0.3)
        local tangente = Vector3.new(-math.sin(a), math.cos(a), 0)
        neon({
            Size = Vector3.new(0.9, 0.9, 2 * math.pi * RAYON / NB * 1.05),
            CFrame = CFrame.lookAt(position, position + tangente, Vector3.new(0, 0, 1)),
            Color = couleurAnneau(i / NB),
            Parent = anneauPortail,
        })
    end
    -- les étincelles qui sortent du portail + sa lumière
    local coeur = bloc({ Size = Vector3.new(11, 11, 0.2), Transparency = 1, CFrame = CFrame.new(CENTRE_PORTAIL + Vector3.new(0, 0, 0.4)), Parent = modele })
    emetteurPortail = nouveau("ParticleEmitter", {
        EmissionDirection = Enum.NormalId.Back, -- vers la caméra
        Rate = 35,
        Lifetime = NumberRange.new(1, 2.2),
        Speed = NumberRange.new(1.5, 4.5),
        SpreadAngle = Vector2.new(25, 25),
        RotSpeed = NumberRange.new(-120, 120),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
        Transparency = NumberSequence.new(0.1, 1),
        LightEmission = 1,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, COULEURS.Motivation),
            ColorSequenceKeypoint.new(0.33, COULEURS.Ego),
            ColorSequenceKeypoint.new(0.66, COULEURS.Discipline),
            ColorSequenceKeypoint.new(1, COULEURS.Obsession),
        }),
        Parent = coeur,
    })
    lumierePortail = nouveau("PointLight", { Range = 30, Brightness = 2.5, Color = VIOLET, Parent = coeur })
    -- au-dessus : « PLAY »
    local positionEnseigne = CENTRE_PORTAIL + Vector3.new(0, RAYON + 3.2, 0)
    local enseigne = bloc({
        Size = Vector3.new(10, 2.6, 0.3),
        CFrame = CFrame.lookAt(positionEnseigne, positionEnseigne + Vector3.new(0, 0, 1)), -- tournée vers la place
        Transparency = 1,
        Parent = modele,
    })
    panneauTexte(enseigne, "PLAY", OR)

    -- derrière : l'escalier infini qui monte en spirale dans le ciel (il tourne doucement)
    local spirale = nouveau("Model", { Name = "Spirale", Parent = scene })
    local centreSpirale = base + d * 32
    spirale.PrimaryPart = bloc({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(centreSpirale), Parent = spirale })
    for i = 1, 70 do
        local a = i * 0.3
        local position = centreSpirale + Vector3.new(math.cos(a) * 15, 1 + i * 1.3, math.sin(a) * 15)
        local cf = CFrame.lookAt(position, position + Vector3.new(-math.sin(a), 0, math.cos(a)))
        bloc({ Size = Vector3.new(6, 0.8, 3), CFrame = cf, Color = Color3.fromRGB(34, 30, 52), Parent = spirale })
        neon({ Size = Vector3.new(6.05, 0.15, 0.2), CFrame = cf * CFrame.new(0, 0.45, -1.45), Color = COULEURS[ORDRE_PERSOS[i % 4 + 1]], Parent = spirale })
    end
    table.insert(animes, { modele = spirale, cf = spirale:GetPivot(), vitesse = 0.05 })
end

-- ---------- À GAUCHE : l'échoppe du MARCHAND D'AURA ----------
local marchand = { pistes = nil, bulle = nil, texteBulle = nil, echelleBulle = nil, eclats = nil }
local F_SHOP
do
    local modele = modeleStation(SHOP, "Marchand")
    local base = Vector3.new(O.X, SOL, O.Z) + direction(STATIONS[SHOP].angle) * R
    F_SHOP = CFrame.lookAt(base, Vector3.new(O.X, SOL, O.Z)) -- -Z = vers le centre de la place
    local function ici(x, y, z)
        return F_SHOP * CFrame.new(x, y, z)
    end
    local BOIS = Color3.fromRGB(70, 45, 32)
    local BOIS_SOMBRE = Color3.fromRGB(45, 30, 24)
    bloc({ Size = Vector3.new(17, 0.4, 11), CFrame = ici(0, 0.2, 0), Color = BOIS_SOMBRE, Material = Enum.Material.WoodPlanks, Parent = modele })
    -- le comptoir
    solide(bloc({ Size = Vector3.new(12, 3.4, 2.4), CFrame = ici(0, 2.1, -3.6), Color = BOIS, Material = Enum.Material.Wood, Parent = modele }))
    bloc({ Size = Vector3.new(12.4, 0.3, 2.8), CFrame = ici(0, 3.95, -3.6), Color = Color3.fromRGB(40, 30, 56), Parent = modele })
    neon({ Size = Vector3.new(12.4, 0.12, 0.12), CFrame = ici(0, 3.85, -5.0), Color = VIOLET, Parent = modele })
    neon({ Size = Vector3.new(12.1, 0.12, 0.12), CFrame = ici(0, 0.9, -4.82), Color = VIOLET, Parent = modele })
    -- le mur du fond, les poteaux, le toit
    solide(bloc({ Size = Vector3.new(15, 13, 0.8), CFrame = ici(0, 6.9, 4), Color = Color3.fromRGB(26, 20, 40), Parent = modele }))
    for _, x in ipairs({ -7, 7 }) do
        solide(bloc({ Size = Vector3.new(0.8, 13, 0.8), CFrame = ici(x, 6.9, -4.6), Color = BOIS_SOMBRE, Material = Enum.Material.Wood, Parent = modele }))
        solide(bloc({ Size = Vector3.new(0.8, 13, 0.8), CFrame = ici(x, 6.9, 3.4), Color = BOIS_SOMBRE, Material = Enum.Material.Wood, Parent = modele }))
    end
    bloc({ Size = Vector3.new(17, 0.7, 11.5), CFrame = ici(0, 13.6, -0.4) * CFrame.Angles(math.rad(-9), 0, 0), Color = Color3.fromRGB(60, 30, 90), Parent = modele })
    neon({ Size = Vector3.new(17.1, 0.25, 0.25), CFrame = ici(0, 12.7, -6.1), Color = VIOLET, Parent = modele })
    -- l'enseigne
    local enseigne = bloc({ Size = Vector3.new(11, 2.6, 0.4), CFrame = ici(0, 16, -4.4), Color = Color3.fromRGB(18, 14, 28), Parent = modele })
    local _, surfaceEnseigne = panneauTexte(enseigne, "AURA SHOP", OR)
    nouveau("UIStroke", { Color = VIOLET, Thickness = 6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = surfaceEnseigne:FindFirstChildOfClass("TextLabel") })
    -- les étagères pleines de fioles d'aura
    for etage = 0, 1 do
        local y = 7.6 + etage * 2.6
        bloc({ Size = Vector3.new(12, 0.25, 1.2), CFrame = ici(0, y, 3.0), Color = BOIS, Material = Enum.Material.Wood, Parent = modele })
        for k = 0, 6 do
            local hauteur = 0.7 + math.random() * 0.6
            neon({
                Size = Vector3.new(0.6, hauteur, 0.6),
                CFrame = ici(-5 + k * 1.65, y + 0.12 + hauteur / 2, 3.0),
                Color = COULEURS[ORDRE_PERSOS[(k + etage) % 4 + 1]],
                Transparency = 0.2,
                Parent = modele,
            })
        end
    end
    -- 4 cristaux d'aura qui flottent sur le comptoir (un par état d'esprit)
    for k, perso in ipairs(ORDRE_PERSOS) do
        local cristal = neon({
            Size = Vector3.new(0.8, 1.2, 0.8),
            CFrame = ici(-4.5 + (k - 1) * 3, 5, -3.6) * CFrame.Angles(0, math.rad(45), 0),
            Color = COULEURS[perso],
            Parent = modele,
        })
        table.insert(animes, { part = cristal, cf = cristal.CFrame, phase = k, amplitude = 0.35, tourne = true })
    end
    -- deux lanternes
    for _, x in ipairs({ -5.5, 5.5 }) do
        local lanterne = neon({ Size = Vector3.new(0.8, 1.1, 0.8), CFrame = ici(x, 11.4, -4.2), Color = Color3.fromRGB(255, 190, 110), Parent = modele })
        nouveau("PointLight", { Range = 20, Brightness = 1.6, Color = Color3.fromRGB(255, 180, 100), Parent = lanterne })
    end
    -- les étincelles qui partent quand tu achètes
    local pointEclats = bloc({ Size = Vector3.new(10, 1, 1), CFrame = ici(0, 4.5, -3.6), Transparency = 1, Parent = modele })
    marchand.eclats = nouveau("ParticleEmitter", {
        Rate = 0,
        Lifetime = NumberRange.new(0.6, 1.2),
        Speed = NumberRange.new(6, 14),
        SpreadAngle = Vector2.new(60, 60),
        EmissionDirection = Enum.NormalId.Top,
        Acceleration = Vector3.new(0, -14, 0),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
        LightEmission = 1,
        Color = ColorSequence.new(OR),
        Parent = pointEclats,
    })

    -- le marchand lui-même (fabriqué par le serveur), avec des yeux qui brillent et un haut-de-forme
    task.spawn(function()
        local source = ReplicatedStorage:WaitForChild("MindsetMarchand", 30)
        if not source then
            warn("[MindsetHub] Pas de marchand (ReplicatedStorage.MindsetMarchand) : vérifie le script serveur.")
            return
        end
        local copie = source:Clone()
        copie.Parent = modele
        marchand.pistes = poserAvatar(copie, ici(0, 0.4, -0.8))
        local tete = copie:FindFirstChild("Head")
        if tete then
            for _, x in ipairs({ -0.22, 0.22 }) do
                coller(tete, { Size = Vector3.new(0.2, 0.12, 0.05), CFrame = tete.CFrame * CFrame.new(x, 0.12, -0.6), Material = Enum.Material.Neon, Color = OR, Parent = copie })
            end
            coller(tete, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 2.2, 2.2), CFrame = tete.CFrame * CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(15, 12, 22), Parent = copie })
            coller(tete, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, 1.3, 1.3), CFrame = tete.CFrame * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(15, 12, 22), Parent = copie })
            coller(tete, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.22, 1.34, 1.34), CFrame = tete.CFrame * CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, math.pi / 2), Material = Enum.Material.Neon, Color = VIOLET, Parent = copie })
            -- sa bulle de dialogue
            marchand.bulle = nouveau("BillboardGui", {
                Adornee = tete,
                Size = UDim2.fromOffset(300, 64),
                StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0),
                AlwaysOnTop = true,
                MaxDistance = 90,
                Enabled = false,
                Parent = copie,
            })
            local cadreBulle = nouveau("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(245, 240, 255), Parent = marchand.bulle })
            nouveau("UICorner", { CornerRadius = UDim.new(0, 14), Parent = cadreBulle })
            nouveau("UIStroke", { Color = VIOLET, Thickness = 3, Parent = cadreBulle })
            marchand.echelleBulle = nouveau("UIScale", { Parent = cadreBulle })
            marchand.texteBulle = texte({
                Position = UDim2.fromOffset(12, 8),
                Size = UDim2.new(1, -24, 1, -16),
                TextColor3 = Color3.fromRGB(30, 20, 50),
                Parent = cadreBulle,
            })
            -- son nom
            local nom = nouveau("BillboardGui", { Adornee = tete, Size = UDim2.fromOffset(200, 26), StudsOffsetWorldSpace = Vector3.new(0, 1.9, 0), MaxDistance = 90, Parent = copie })
            texte({ Size = UDim2.fromScale(1, 1), Text = "AURA MERCHANT", Font = Enum.Font.GothamBlack, TextColor3 = OR, TextStrokeTransparency = 0.4, Parent = nom })
        end
        local torse = copie:FindFirstChild("UpperTorso")
        if torse then
            nouveau("ParticleEmitter", {
                Rate = 10,
                Lifetime = NumberRange.new(1, 2),
                Speed = NumberRange.new(0.5, 1.5),
                SpreadAngle = Vector2.new(40, 40),
                EmissionDirection = Enum.NormalId.Top,
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
                LightEmission = 1,
                Color = ColorSequence.new(VIOLET),
                Parent = torse,
            })
        end
    end)
end

-- Le marchand parle (bulle qui apparaît, texte tapé lettre par lettre)
local REPLIQUES = {
    salut = {
        "Welcome, climber. Your aura is my currency.",
        "A stronger mindset climbs higher stairs.",
        "Spend aura, earn steps. Simple.",
        "Every level counts at the top...",
    },
    achat = { "Pleasure doing business!", "Feel that? That's power.", "Your mindset just got stronger.", "Now go climb!" },
    pauvre = { "Not enough aura... go farm some!", "Come back richer, climber.", "Aura first, upgrades after." },
    max = { "That one is already maxed out!", "Can't go higher than that, champ." },
}
local numeroReplique = 0
local function direMarchand(categorie, message)
    if not marchand.bulle then
        return
    end
    numeroReplique += 1
    local numero = numeroReplique
    local phrase = message or auHasard(REPLIQUES[categorie])
    -- traduite d'abord (par le script du jeu), pour l'écrire lettre par lettre dans la bonne langue
    local traduire = liens:FindFirstChild("Traduire")
    if traduire then
        local ok, traduite = pcall(function()
            return traduire:Invoke(phrase)
        end)
        if ok and type(traduite) == "string" then
            phrase = traduite
        end
    end
    marchand.bulle.Enabled = true
    marchand.echelleBulle.Scale = 0.6
    tween(marchand.echelleBulle, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
    marchand.texteBulle.Text = phrase
    marchand.texteBulle.MaxVisibleGraphemes = 0
    task.spawn(function()
        for n = 1, #phrase do
            if numero ~= numeroReplique then
                return
            end
            marchand.texteBulle.MaxVisibleGraphemes = n
            if n % 3 == 0 then
                jouerSon("tic", 2.6 + math.random() * 0.4, 0.05, nil, 0.05)
            end
            task.wait(0.022)
        end
        marchand.texteBulle.MaxVisibleGraphemes = -1
        task.wait(3.5)
        if numero == numeroReplique and marchand.bulle then
            marchand.bulle.Enabled = false
        end
    end)
end

local function animerMarchand(nom)
    local piste = marchand.pistes and marchand.pistes[nom]
    if piste then
        piste:Play(0.15)
    end
end

-- le point où apparaît le bouton « E » du marchand (devant son comptoir)
local pointShop = bloc({ Size = Vector3.new(1, 1, 1), CFrame = F_SHOP * CFrame.new(0, 3, -6.5), Transparency = 1, CanQuery = false, Parent = modelesStations[SHOP] })

-- ---------- À DROITE : DEUX grands tableaux TOP 100 ----------
--   BEST GAME   : le plus de marches montées en UNE partie (clé "G" du serveur)
--   TOTAL STEPS : le plus de marches montées EN TOUT, toutes les parties (clé "T" du serveur)
local NB_TOP = 100
local COULEURS_PODIUM = { OR, Color3.fromRGB(210, 215, 230), Color3.fromRGB(220, 140, 80) }
local BLEU = Color3.fromRGB(90, 200, 255)
local TABLEAU_TOTAL = 4 -- (le 2e tableau n'a pas de bouton en bas, juste son numéro)
local tableaux3D = {} -- les 2 tableaux

-- une ligne du classement (sur un tableau 3D et dans le panneau en grand)
local function couleurFondLigne(rang, estMoi)
    if estMoi then
        return Color3.fromRGB(22, 56, 40)
    end
    return if rang % 2 == 0 then Color3.fromRGB(24, 24, 36) else Color3.fromRGB(18, 18, 28)
end

local function creerLigne(parent, rang, hauteur)
    local ligne = nouveau("Frame", {
        Size = UDim2.new(1, -12, 0, hauteur),
        LayoutOrder = rang,
        BackgroundColor3 = couleurFondLigne(rang, false),
        BorderSizePixel = 0,
        Visible = false,
        Parent = parent,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(0.3, 0), Parent = ligne })
    local couleurRang = COULEURS_PODIUM[rang] or GRIS
    texte({ Position = UDim2.fromScale(0.015, 0.14), Size = UDim2.fromScale(0.11, 0.72), Text = "#" .. rang, Font = Enum.Font.GothamBlack, TextColor3 = couleurRang, Parent = ligne })
    return {
        rang = rang,
        cadre = ligne,
        nom = texte({ Position = UDim2.fromScale(0.14, 0.14), Size = UDim2.fromScale(0.54, 0.72), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack, Parent = ligne }),
        score = texte({ Position = UDim2.fromScale(0.7, 0.14), Size = UDim2.fromScale(0.28, 0.72), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBlack, TextColor3 = couleurRang, Parent = ligne }),
    }
end

local function remplirLigne(ligne, entree)
    ligne.cadre.Visible = entree ~= nil
    if entree then
        local estMoi = entree.userId == joueur.UserId
        ligne.nom.Text = tostring(entree.nom)
        ligne.nom.TextColor3 = if estMoi then VERT else BLANC
        ligne.score.Text = tostring(entree.score) .. " steps"
        ligne.cadre.BackgroundColor3 = couleurFondLigne(ligne.rang, estMoi)
    end
end

-- construit un tableau (écran qui défile + podium des 3 premiers + bouton « E » devant)
local function construireTableau(numero, angle, infos)
    local tableau = {
        cle = infos.cle, titre = infos.titre, sousTitre = infos.sousTitre, couleur = infos.couleur, motMoi = infos.motMoi,
        lignes = {}, podium = {}, liste = {}, record = 0, y = 0, pause = 4, enBas = false, dernier = -math.huge,
    }
    local couleur = infos.couleur
    local modele = modeleStation(numero, "Classement_" .. infos.cle)
    local base = Vector3.new(O.X, SOL, O.Z) + direction(angle) * R
    local F = CFrame.lookAt(base, Vector3.new(O.X, SOL, O.Z))
    local function ici(x, y, z)
        return F * CFrame.new(x, y, z)
    end
    local planche = solide(bloc({ Size = Vector3.new(22, 14, 0.8), CFrame = ici(0, 10.5, 0), Color = Color3.fromRGB(12, 12, 20), Parent = modele }))
    for _, barre in ipairs({
        { Vector3.new(22.8, 0.4, 0.4), ici(0, 17.7, -0.3) },
        { Vector3.new(22.8, 0.4, 0.4), ici(0, 3.3, -0.3) },
        { Vector3.new(0.4, 14.8, 0.4), ici(-11.2, 10.5, -0.3) },
        { Vector3.new(0.4, 14.8, 0.4), ici(11.2, 10.5, -0.3) },
    }) do
        neon({ Size = barre[1], CFrame = barre[2], Color = couleur, Parent = modele })
    end
    for _, x in ipairs({ -8, 8 }) do
        solide(bloc({ Size = Vector3.new(1, 3.2, 1), CFrame = ici(x, 1.9, 0), Color = Color3.fromRGB(30, 28, 44), Parent = modele }))
    end
    nouveau("PointLight", { Range = 22, Brightness = 1.2, Color = couleur, Parent = planche })

    -- l'écran du tableau : les 100 premiers défilent tout seuls
    local surface = nouveau("SurfaceGui", {
        Face = Enum.NormalId.Front,
        SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
        PixelsPerStud = 45,
        LightInfluence = 0,
        Parent = planche,
    })
    texte({ Position = UDim2.fromScale(0.04, 0.025), Size = UDim2.fromScale(0.92, 0.08), Text = infos.titre, Font = Enum.Font.GothamBlack, TextColor3 = couleur, Parent = surface })
    texte({ Position = UDim2.fromScale(0.04, 0.105), Size = UDim2.fromScale(0.92, 0.035), Text = infos.sousTitre, Font = Enum.Font.GothamMedium, TextColor3 = GRIS, Parent = surface })
    tableau.statut = texte({ Position = UDim2.fromScale(0.04, 0.45), Size = UDim2.fromScale(0.92, 0.07), Text = "Loading...", TextColor3 = GRIS, Parent = surface })
    tableau.defile = nouveau("ScrollingFrame", {
        Position = UDim2.fromScale(0.03, 0.16),
        Size = UDim2.fromScale(0.94, 0.71),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 5,
        ScrollBarImageColor3 = couleur,
        ScrollingEnabled = false,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = surface,
    })
    nouveau("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tableau.defile })
    for rang = 1, NB_TOP do
        tableau.lignes[rang] = creerLigne(tableau.defile, rang, 40)
    end
    tableau.moi = texte({ Position = UDim2.fromScale(0.04, 0.89), Size = UDim2.fromScale(0.92, 0.07), TextColor3 = VERT, Font = Enum.Font.GothamBlack, Parent = surface })

    -- le podium devant, avec les 3 premiers
    for rang, place in ipairs({ { 0, 3.2 }, { -4.4, 2.2 }, { 4.4, 1.5 } }) do
        local x, hauteur = place[1], place[2]
        local marche = solide(bloc({ Size = Vector3.new(4.2, hauteur, 3), CFrame = ici(x, hauteur / 2, -6), Color = Color3.fromRGB(30, 28, 44), Parent = modele }))
        neon({ Size = Vector3.new(4.25, 0.15, 3.05), CFrame = ici(x, hauteur, -6), Color = COULEURS_PODIUM[rang], Parent = modele })
        local chiffre = bloc({ Size = Vector3.new(2, math.min(hauteur - 0.2, 1.6), 0.05), CFrame = ici(x, hauteur / 2, -7.53), Transparency = 1, Parent = modele })
        panneauTexte(chiffre, tostring(rang), COULEURS_PODIUM[rang])
        local etiquette = nouveau("BillboardGui", { Adornee = marche, Size = UDim2.fromOffset(170, 44), StudsOffsetWorldSpace = Vector3.new(0, hauteur / 2 + 1.6, 0), MaxDistance = 90, Parent = modele })
        tableau.podium[rang] = {
            nom = texte({ Size = UDim2.fromScale(1, 0.58), Font = Enum.Font.GothamBlack, TextColor3 = BLANC, TextStrokeTransparency = 0.3, Parent = etiquette }),
            score = texte({ Position = UDim2.fromScale(0, 0.58), Size = UDim2.fromScale(1, 0.42), TextColor3 = COULEURS_PODIUM[rang], TextStrokeTransparency = 0.3, Parent = etiquette }),
        }
    end
    -- le point où apparaît le bouton « E » (devant le podium)
    tableau.point = bloc({ Size = Vector3.new(1, 1, 1), CFrame = ici(0, 3, -10), Transparency = 1, CanQuery = false, Parent = modele })
    table.insert(tableaux3D, tableau)
    return tableau
end

construireTableau(TABLEAU, STATIONS[TABLEAU].angle, {
    cle = "G", titre = "TOP 100  ·  BEST GAME", sousTitre = "the most steps climbed in ONE game", couleur = OR, motMoi = "YOUR BEST",
})
construireTableau(TABLEAU_TOTAL, math.rad(115), {
    cle = "T", titre = "TOP 100  ·  TOTAL STEPS", sousTitre = "all the steps ever climbed, every game added up", couleur = BLEU, motMoi = "YOUR TOTAL",
})

-- ton score et ta place dans un top 100
local function texteMonRang(tableau)
    local record = tableau.record or 0
    if record <= 0 then
        return tableau.motMoi .. ": —  (go climb!)"
    end
    for rang, entree in ipairs(tableau.liste) do
        if entree.userId == joueur.UserId then
            return tableau.motMoi .. ": " .. record .. " steps  ·  RANK #" .. rang
        end
    end
    return tableau.motMoi .. ": " .. record .. " steps  ·  not in the top 100 yet"
end

-- On demande un top 100 au serveur (pas plus d'une fois toutes les 10 secondes)
local remplirPanneauTop -- (défini plus bas : le top 100 en grand, à l'écran)
local function majTableau(tableau, force)
    if not force and os.clock() - tableau.dernier < 10 then
        return
    end
    tableau.dernier = os.clock()
    task.spawn(function()
        local ok, resultat = pcall(function()
            return ClassementFonction:InvokeServer(tableau.cle, true)
        end)
        if not ok or type(resultat) ~= "table" then
            tableau.statut.Visible = true
            tableau.statut.Text = "Leaderboard unavailable for now"
            return
        end
        local liste = resultat.liste or {}
        tableau.liste = liste
        tableau.record = tonumber(resultat.moi) or 0
        tableau.statut.Visible = #liste == 0
        tableau.statut.Text = "No record yet: be the first!"
        for rang, ligne in ipairs(tableau.lignes) do
            remplirLigne(ligne, liste[rang])
        end
        for rang, place in ipairs(tableau.podium) do
            local entree = liste[rang]
            place.nom.Text = if entree then tostring(entree.nom) else "—"
            place.score.Text = if entree then tostring(entree.score) .. " steps" else ""
        end
        tableau.moi.Text = texteMonRang(tableau)
        if remplirPanneauTop then
            remplirPanneauTop(tableau)
        end
    end)
end

local function majTableaux(force)
    for _, tableau in ipairs(tableaux3D) do
        majTableau(tableau, force)
    end
end

-- ---------- LES JOUEURS : une étiquette au-dessus de chaque joueur du hub ----------
-- (état d'esprit + niveau, pseudo, record) : c'est comme ça qu'on voit l'évolution des autres
local dossierGrimpeurs = ReplicatedStorage:WaitForChild("Grimpeurs")
local etiquettes = {} -- [config] = { gui, perso, nom, record }

local function majEtiquetteHub(config)
    local e = etiquettes[config]
    if not e then
        return
    end
    local cible = Players:GetPlayerByUserId(config:GetAttribute("UserId") or 0)
    local perso = config:GetAttribute("Perso")
    local total = 0
    if cible and perso then
        for _, n in ipairs(mesNiveaux(perso, cible)) do
            total += tonumber(n) or 0
        end
    end
    e.perso.Text = if perso then string.upper(perso) .. "  ·  LV " .. total else "NO MINDSET YET"
    e.perso.TextColor3 = COULEURS[perso] or GRIS
    e.nom.Text = tostring(config:GetAttribute("Nom") or "")
    local record = if cible then tonumber(cible:GetAttribute("Record")) or 0 else 0
    e.record.Text = if record > 0 then "BEST: " .. record .. " STEPS" else "NEW CLIMBER"
    e.gui.Enabled = config:GetAttribute("Hub") == true
end

local function poserEtiquetteHub(config)
    local ancienne = etiquettes[config]
    if ancienne then
        ancienne.gui:Destroy()
    end
    etiquettes[config] = nil
    local valeur = config:FindFirstChild("Modele")
    local modele = valeur and valeur.Value
    if not modele then
        return
    end
    task.spawn(function()
        local tete = modele:WaitForChild("Head", 10)
        if not tete or valeur.Value ~= modele or etiquettes[config] then
            return
        end
        local gui = nouveau("BillboardGui", {
            Name = "MindsetHubEtiquette",
            Adornee = tete,
            Size = UDim2.fromOffset(210, 64),
            StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0),
            MaxDistance = 80,
            LightInfluence = 0,
            Parent = tete,
        })
        etiquettes[config] = {
            gui = gui,
            perso = texte({ Size = UDim2.fromScale(1, 0.4), Font = Enum.Font.GothamBlack, TextStrokeTransparency = 0.3, Parent = gui }),
            nom = texte({ Position = UDim2.fromScale(0, 0.4), Size = UDim2.fromScale(1, 0.32), TextStrokeTransparency = 0.4, Parent = gui }),
            record = texte({ Position = UDim2.fromScale(0, 0.72), Size = UDim2.fromScale(1, 0.28), Font = Enum.Font.GothamBold, TextColor3 = OR, TextStrokeTransparency = 0.4, Parent = gui }),
        }
        majEtiquetteHub(config)
    end)
end

local function suivreGrimpeur(config)
    if (config:GetAttribute("UserId") or 0) == 0 then
        return -- les bots ne viennent jamais dans le hub
    end
    local valeur = config:WaitForChild("Modele", 10)
    if valeur then
        valeur.Changed:Connect(function()
            poserEtiquetteHub(config)
        end)
    end
    poserEtiquetteHub(config)
    for _, attribut in ipairs({ "Hub", "Perso", "Nom" }) do
        config:GetAttributeChangedSignal(attribut):Connect(function()
            majEtiquetteHub(config)
        end)
    end
    local cible = Players:GetPlayerByUserId(config:GetAttribute("UserId"))
    if cible then
        for _, attribut in ipairs({ "Niveaux", "Record" }) do
            cible:GetAttributeChangedSignal(attribut):Connect(function()
                majEtiquetteHub(config)
            end)
        end
    end
end
dossierGrimpeurs.ChildAdded:Connect(suivreGrimpeur)
dossierGrimpeurs.ChildRemoved:Connect(function(config)
    etiquettes[config] = nil
end)
for _, config in ipairs(dossierGrimpeurs:GetChildren()) do
    task.spawn(suivreGrimpeur, config)
end

-- ========================== L'INTERFACE ==========================
local playerGui = joueur:WaitForChild("PlayerGui")
local gui = nouveau("ScreenGui", {
    Name = "MindsetHubGui",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 1, -- sous le jeu : PARAMÈTRES s'ouvre par-dessus
    Parent = playerGui,
})
-- le voile des transitions (au-dessus de tout)
local guiTransition = nouveau("ScreenGui", { Name = "MindsetTransition", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50, Parent = playerGui })
local fondu = nouveau("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = NOIR, BackgroundTransparency = 0, BorderSizePixel = 0, Parent = guiTransition })

local racine = nouveau("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })

-- le titre du jeu (au début seulement), chaque état d'esprit dans sa couleur
local function enCouleur(mot, couleur)
    local function octet(x)
        return math.floor(x * 255 + 0.5)
    end
    return string.format('<font color="#%02X%02X%02X">%s</font>', octet(couleur.R), octet(couleur.G), octet(couleur.B), mot)
end
local titre = texte({
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.06),
    Size = UDim2.fromScale(0.56, 0.09),
    RichText = true,
    Font = Enum.Font.GothamBlack,
    Text = enCouleur("EGO", COULEURS.Ego) .. ' <font color="#DCDCE6">vs</font> ' .. enCouleur("DISCIPLINE", COULEURS.Discipline) .. "\n"
        .. '<font color="#DCDCE6">vs</font> ' .. enCouleur("OBSESSION", COULEURS.Obsession) .. ' <font color="#DCDCE6">vs</font> ' .. enCouleur("MOTIVATION", COULEURS.Motivation),
    TextStrokeTransparency = 0,
    TextStrokeColor3 = Color3.fromRGB(12, 8, 24),
    Parent = racine,
})
local echelleTitre = nouveau("UIScale", { Parent = titre })

-- un bouton (survol = grossit + son, clic = rebond)
local function bouton(proprietes, couleur, plein, note)
    proprietes.BackgroundColor3 = if plein then couleur else FOND_PANNEAU
    proprietes.BackgroundTransparency = if plein then 0 else 0.1
    proprietes.AutoButtonColor = false
    proprietes.Font = proprietes.Font or Enum.Font.GothamBlack
    proprietes.TextScaled = true
    proprietes.TextColor3 = if plein then NOIR else couleur
    local b = nouveau("TextButton", proprietes)
    nouveau("UICorner", { CornerRadius = UDim.new(0, 12), Parent = b })
    local trait = nouveau("UIStroke", { Color = couleur, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
    nouveau("UIPadding", { PaddingTop = UDim.new(0.22, 0), PaddingBottom = UDim.new(0.22, 0), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = b })
    local echelle = nouveau("UIScale", { Parent = b })
    b.MouseEnter:Connect(function()
        sonSurvol(note or 4)
        tween(echelle, 0.18, { Scale = 1.05 }, Enum.EasingStyle.Back)
    end)
    b.MouseLeave:Connect(function()
        tween(echelle, 0.18, { Scale = 1 })
    end)
    b.Activated:Connect(function()
        echelle.Scale = 0.92
        tween(echelle, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
    end)
    return b, trait
end

-- ---------- en haut à gauche : ton aura + PARAMÈTRES + AFK ----------
local auraValeur = joueur:WaitForChild("StatsCachees", 30) and joueur.StatsCachees:WaitForChild("Aura", 30)
local pastilleAura = nouveau("Frame", {
    Position = UDim2.new(0, 20, 0, 70),
    Size = UDim2.fromOffset(220, 48),
    BackgroundColor3 = FOND_PANNEAU,
    BackgroundTransparency = 0.1,
    Parent = racine,
})
nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pastilleAura })
nouveau("UIStroke", { Color = OR, Thickness = 2, Parent = pastilleAura })
texte({ Position = UDim2.new(0, 18, 0.22, 0), Size = UDim2.new(0, 60, 0.56, 0), Text = "AURA", Font = Enum.Font.GothamBlack, TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Left, Parent = pastilleAura })
local texteAura = texte({ Position = UDim2.new(0, 80, 0.15, 0), Size = UDim2.new(1, -98, 0.7, 0), Font = Enum.Font.GothamBlack, TextColor3 = OR, TextXAlignment = Enum.TextXAlignment.Right, Parent = pastilleAura })
local echelleAura = nouveau("UIScale", { Parent = pastilleAura })

local boutonReglages = bouton({ Position = UDim2.new(0, 20, 0, 128), Size = UDim2.fromOffset(160, 40), Text = "SETTINGS", Parent = racine }, Color3.fromRGB(200, 200, 220), false, 3)
local boutonAfk = bouton({ Position = UDim2.new(0, 20, 0, 176), Size = UDim2.fromOffset(160, 40), Text = "AFK · WATCH", Parent = racine }, Color3.fromRGB(140, 200, 255), false, 2)

-- ---------- en bas : ce qu'on peut faire ici ----------
local aide = texte({
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, if surMobile then -150 else -24),
    Size = UDim2.new(0.9, 0, 0, 22),
    RichText = true,
    Text = 'Walk into the <font color="#FFDC50">PORTAL</font> to play  ·  Talk to the <font color="#AA5AFF">AURA MERCHANT</font> to upgrade  ·  Check the <font color="#6EE6A0">TOP 100s</font>',
    Font = Enum.Font.GothamBold,
    TextColor3 = Color3.fromRGB(220, 220, 235),
    TextStrokeTransparency = 0.4,
    Parent = racine,
})
nouveau("UISizeConstraint", { MaxSize = Vector2.new(900, 22), Parent = aide })

-- ---------- MARCHAND : la boutique (à droite) ----------
local boutique = { onglets = {}, lignes = {}, perso = nil }
local panneauShop = nouveau("Frame", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -24, 0.5, 0),
    Size = UDim2.fromScale(0.44, 0.68),
    BackgroundColor3 = FOND_PANNEAU,
    BackgroundTransparency = 0.06,
    Visible = false,
    Parent = racine,
})
nouveau("UISizeConstraint", { MaxSize = Vector2.new(560, 620), Parent = panneauShop })
nouveau("UICorner", { CornerRadius = UDim.new(0, 18), Parent = panneauShop })
local traitShop = nouveau("UIStroke", { Color = VIOLET, Thickness = 2, Parent = panneauShop })
local echelleShop = nouveau("UIScale", { Parent = panneauShop })
texte({ Position = UDim2.fromScale(0.05, 0.025), Size = UDim2.fromScale(0.5, 0.065), Text = "AURA SHOP", Font = Enum.Font.GothamBlack, TextColor3 = OR, TextXAlignment = Enum.TextXAlignment.Left, Parent = panneauShop })
boutique.solde = texte({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.85, 0.03), Size = UDim2.fromScale(0.32, 0.05), Font = Enum.Font.GothamBlack, TextColor3 = OR, TextXAlignment = Enum.TextXAlignment.Right, Parent = panneauShop })
local boutonFermerShop = bouton({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(38, 38), Text = "X", Parent = panneauShop }, ROUGE, false, 2)
texte({ Position = UDim2.fromScale(0.05, 0.088), Size = UDim2.fromScale(0.9, 0.032), Text = "Spend the aura you farm in game to upgrade your mindset.", Font = Enum.Font.GothamMedium, TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Left, Parent = panneauShop })

-- les 4 onglets (un par état d'esprit)
local rangeeOnglets = nouveau("Frame", { Position = UDim2.fromScale(0.05, 0.14), Size = UDim2.fromScale(0.9, 0.065), BackgroundTransparency = 1, Parent = panneauShop })
nouveau("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.02, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = rangeeOnglets })
local afficherBoutique -- (défini plus bas)
for i, perso in ipairs(ORDRE_PERSOS) do
    local b, trait = bouton({ Size = UDim2.fromScale(0.235, 1), Text = string.upper(perso), LayoutOrder = i, Parent = rangeeOnglets }, COULEURS[perso], false, i)
    b.Activated:Connect(function()
        sonClic(i)
        boutique.perso = perso
        afficherBoutique()
    end)
    boutique.onglets[perso] = { bouton = b, trait = trait }
end

-- l'état d'esprit affiché : nom, devise, niveau total, bouton ÉQUIPER
boutique.nom = texte({ Position = UDim2.fromScale(0.05, 0.23), Size = UDim2.fromScale(0.55, 0.07), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = panneauShop })
boutique.devise = texte({ Position = UDim2.fromScale(0.05, 0.3), Size = UDim2.fromScale(0.55, 0.035), Font = Enum.Font.GothamMedium, TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Left, Parent = panneauShop })

-- les 3 compétences
for j = 1, 3 do
    local ligne = nouveau("Frame", {
        Position = UDim2.fromScale(0.05, 0.36 + (j - 1) * 0.185),
        Size = UDim2.fromScale(0.9, 0.17),
        BackgroundColor3 = Color3.fromRGB(22, 22, 34),
        Parent = panneauShop,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 12), Parent = ligne })
    local l = { cadre = ligne, pips = {} }
    l.nom = texte({ Position = UDim2.fromScale(0.04, 0.1), Size = UDim2.fromScale(0.36, 0.26), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = ligne })
    for k = 1, 5 do
        local pip = nouveau("Frame", {
            Position = UDim2.fromScale(0.42 + (k - 1) * 0.048, 0.14),
            Size = UDim2.fromScale(0.038, 0.18),
            BackgroundColor3 = Color3.fromRGB(50, 50, 66),
            BorderSizePixel = 0,
            Parent = ligne,
        })
        nouveau("UICorner", { CornerRadius = UDim.new(0, 3), Parent = pip })
        l.pips[k] = pip
    end
    l.maintenant = texte({ Position = UDim2.fromScale(0.04, 0.42), Size = UDim2.fromScale(0.62, 0.22), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = ligne })
    l.ensuite = texte({ Position = UDim2.fromScale(0.04, 0.68), Size = UDim2.fromScale(0.62, 0.2), Font = Enum.Font.GothamMedium, TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Left, Parent = ligne })
    l.bouton, l.trait = bouton({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.97, 0.5), Size = UDim2.fromScale(0.29, 0.56), Text = "UPGRADE", Parent = ligne }, OR, true, 3 + j)
    boutique.lignes[j] = l
end
boutique.message = texte({ Position = UDim2.fromScale(0.05, 0.925), Size = UDim2.fromScale(0.9, 0.045), Font = Enum.Font.GothamBold, TextColor3 = GRIS, Parent = panneauShop })

local function messageBoutique(message, couleur)
    boutique.message.Text = message
    boutique.message.TextColor3 = couleur or GRIS
end

local function aura()
    return if auraValeur then auraValeur.Value else 0
end

afficherBoutique = function()
    local perso = boutique.perso or joueur:GetAttribute("Perso") or "Motivation"
    boutique.perso = perso
    local couleur = COULEURS[perso]
    local niveaux = mesNiveaux(perso)
    local defs = DEFS.persos and DEFS.persos[perso] or {}
    local couts = DEFS.couts or {}
    for nom, onglet in pairs(boutique.onglets) do
        local actif = nom == perso
        onglet.bouton.BackgroundColor3 = if actif then COULEURS[nom] else FOND_PANNEAU
        onglet.bouton.TextColor3 = if actif then NOIR else COULEURS[nom]
    end
    traitShop.Color = couleur
    boutique.nom.Text = string.upper(perso)
    boutique.nom.TextColor3 = couleur
    local total, maximum = 0, 0
    for j = 1, #defs do
        total += tonumber(niveaux[j]) or 0
        maximum += #couts
    end
    boutique.devise.Text = DEVISES[perso] .. "  ·  LV " .. total .. " / " .. maximum
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

-- 🛒 ACHETER le niveau suivant
local achatEnCours = false
for j, l in ipairs(boutique.lignes) do
    l.bouton.Activated:Connect(function()
        if achatEnCours then
            return
        end
        local perso = boutique.perso
        achatEnCours = true
        -- le serveur renvoie : true + le nouveau niveau, ou false + la raison du refus
        local appelOk, reussi, info = pcall(function()
            return AmeliorerFonction:InvokeServer(perso, j)
        end)
        achatEnCours = false
        reussi = appelOk and reussi == true
        if reussi then
            local def = DEFS.persos and DEFS.persos[perso] and DEFS.persos[perso][j]
            sonClic(5)
            jouerSon("tic", 1.5, 0.4, 0.2)
            jouerSon("tic", 2, 0.4, 0.28)
            jouerSon("tic", 3, 0.35, 0.36)
            messageBoutique("LEVEL UP!  " .. (if def then def.nom else "SKILL") .. " is now level " .. tostring(info), OR)
            direMarchand("achat")
            animerMarchand("joie")
            if marchand.eclats then
                marchand.eclats.Color = ColorSequence.new(COULEURS[perso])
                marchand.eclats:Emit(40)
            end
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
                direMarchand("max")
            elseif aura() < prix then
                messageBoutique("Not enough aura: you need " .. (prix - aura()) .. " more. Play to farm some!", ROUGE)
                direMarchand("pauvre")
            else
                messageBoutique(if appelOk and type(info) == "string" then info else "Try again in a second...", ROUGE)
            end
            local depart = l.cadre.Position
            for k = 1, 4 do
                task.delay(k * 0.04, function()
                    l.cadre.Position = depart + UDim2.fromOffset(if k % 2 == 0 then -6 else 6, 0)
                end)
            end
            task.delay(0.2, function()
                l.cadre.Position = depart
            end)
        end
        afficherBoutique()
    end)
end

-- (pas de bouton ÉQUIPER ici : on choisit son état d'esprit dans le lobby du jeu, avant chaque manche)
joueur:GetAttributeChangedSignal("Perso"):Connect(afficherBoutique)
joueur:GetAttributeChangedSignal("Niveaux"):Connect(afficherBoutique)
ReplicatedStorage:GetAttributeChangedSignal("Competences"):Connect(afficherBoutique)

-- l'aura affichée (le compteur défile quand elle change)
local auraAffichee = aura()
local function majAura()
    afficherBoutique()
    local cible = aura()
    local depart = auraAffichee
    if cible ~= depart then
        echelleAura.Scale = 1.12
        tween(echelleAura, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
    end
    task.spawn(function()
        local debut = os.clock()
        while os.clock() - debut < 0.5 do
            local k = (os.clock() - debut) / 0.5
            auraAffichee = math.floor(depart + (cible - depart) * k)
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

-- ---------- TOP 100 en grand (bouton « E » devant le tableau) ----------
local panneauTop = nouveau("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.52),
    Size = UDim2.fromScale(0.5, 0.78),
    BackgroundColor3 = FOND_PANNEAU,
    BackgroundTransparency = 0.04,
    Visible = false,
    Parent = racine,
})
nouveau("UISizeConstraint", { MinSize = Vector2.new(320, 300), MaxSize = Vector2.new(540, 680), Parent = panneauTop })
nouveau("UICorner", { CornerRadius = UDim.new(0, 18), Parent = panneauTop })
local traitTop = nouveau("UIStroke", { Color = OR, Thickness = 2, Parent = panneauTop })
local echelleTop = nouveau("UIScale", { Parent = panneauTop })
local titreTop = texte({ Position = UDim2.new(0.05, 0, 0, 16), Size = UDim2.new(0.75, 0, 0, 30), Font = Enum.Font.GothamBlack, TextColor3 = OR, TextXAlignment = Enum.TextXAlignment.Left, Parent = panneauTop })
local sousTitreTop = texte({ Position = UDim2.new(0.05, 0, 0, 48), Size = UDim2.new(0.9, 0, 0, 16), Font = Enum.Font.GothamMedium, TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Left, Parent = panneauTop })
local boutonFermerTop = bouton({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(38, 38), Text = "X", Parent = panneauTop }, ROUGE, false, 2)
local listeTop = nouveau("ScrollingFrame", {
    Position = UDim2.new(0.04, 0, 0, 76),
    Size = UDim2.new(0.92, 0, 1, -126),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 6,
    ScrollBarImageColor3 = OR,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Parent = panneauTop,
})
nouveau("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = listeTop })
local lignesTop = {}
for rang = 1, NB_TOP do
    lignesTop[rang] = creerLigne(listeTop, rang, 34)
end
local statutTop = texte({ Position = UDim2.new(0.05, 0, 0.4, 0), Size = UDim2.new(0.9, 0, 0, 24), Text = "Loading...", TextColor3 = GRIS, Parent = panneauTop })
local moiTop = texte({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.05, 0, 1, -14), Size = UDim2.new(0.9, 0, 0, 24), Font = Enum.Font.GothamBlack, TextColor3 = VERT, Parent = panneauTop })

local tableauAffiche = tableaux3D[1] -- celui qu'on regarde en grand (BEST GAME ou TOTAL STEPS)
remplirPanneauTop = function(tableau)
    if tableau ~= tableauAffiche then
        return -- c'est l'autre tableau qui vient de se mettre à jour
    end
    titreTop.Text = tableau.titre
    titreTop.TextColor3 = tableau.couleur
    sousTitreTop.Text = tableau.sousTitre
    traitTop.Color = tableau.couleur
    listeTop.ScrollBarImageColor3 = tableau.couleur
    local liste = tableau.liste
    statutTop.Visible = #liste == 0
    statutTop.Text = "No record yet: be the first!"
    for rang, ligne in ipairs(lignesTop) do
        remplirLigne(ligne, liste[rang])
    end
    moiTop.Text = texteMonRang(tableau)
end

-- ========================== SE BALADER ==========================
local etat = {
    ouvert = true,    -- on est dans le hub
    transition = nil, -- la plongée dans le portail
    occupe = false,   -- une transition en fondu est en cours
    intro = os.clock(),
    panneau = nil,    -- "shop" / "top" / nil
}

local function maRacine()
    local personnage = joueur.Character
    return personnage and personnage:FindFirstChild("HumanoidRootPart")
end

local function monHumanoid()
    local personnage = joueur.Character
    return personnage and personnage:FindFirstChildOfClass("Humanoid")
end

-- la caméra Roblox normale, derrière ton avatar
local function cameraHub()
    local camera = workspace.CurrentCamera
    local humanoid = monHumanoid()
    local r = maRacine()
    if r then
        camera.CFrame = CFrame.lookAt(r.Position + Vector3.new(0, 7, 16), r.Position + Vector3.new(0, 2, 0))
    end
    camera.CameraType = Enum.CameraType.Custom
    if humanoid then
        camera.CameraSubject = humanoid
        humanoid.WalkSpeed = 16
    end
    camera.FieldOfView = 70
end

-- on attend que le serveur ait posé ton avatar sur la place (max secondes)
local function attendreAuHub(max)
    local limite = os.clock() + max
    while os.clock() < limite do
        local r = maRacine()
        if r and (r.Position - O).Magnitude < 80 then
            return
        end
        task.wait(0.05)
    end
end

local function fermerPanneaux()
    panneauShop.Visible = false
    panneauTop.Visible = false
    etat.panneau = nil
end

local function ouvrirShop()
    if not etat.ouvert or etat.transition then
        return
    end
    panneauTop.Visible = false
    if not panneauShop.Visible then
        echelleShop.Scale = 0.85
        tween(echelleShop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
    end
    panneauShop.Visible = true
    etat.panneau = "shop"
    sonClic(2)
    afficherBoutique()
    messageBoutique("", GRIS)
    direMarchand("salut")
    animerMarchand("coucou")
end

local function ouvrirTop(tableau)
    if not etat.ouvert or etat.transition then
        return
    end
    panneauShop.Visible = false
    if not panneauTop.Visible or tableauAffiche ~= tableau then
        echelleTop.Scale = 0.85
        tween(echelleTop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
    end
    tableauAffiche = tableau
    panneauTop.Visible = true
    etat.panneau = "top"
    sonClic(7)
    remplirPanneauTop(tableau)
    majTableau(tableau, false)
    -- on descend la liste jusqu'à toi si tu es dans le top 100
    for rang, entree in ipairs(tableauAffiche.liste) do
        if entree.userId == joueur.UserId then
            listeTop.CanvasPosition = Vector2.new(0, math.max(0, (rang - 4) * 38))
            return
        end
    end
    listeTop.CanvasPosition = Vector2.zero
end

-- les boutons « E » (ProximityPrompt) devant le marchand et devant le tableau
local function boutonE(part, action, objet, quand)
    local prompt = nouveau("ProximityPrompt", {
        ActionText = action,
        ObjectText = objet,
        KeyboardKeyCode = Enum.KeyCode.E,
        HoldDuration = 0,
        MaxActivationDistance = 12,
        RequiresLineOfSight = false,
        Parent = part,
    })
    prompt.Triggered:Connect(quand)
    return prompt
end
boutonE(pointShop, "Upgrade", "Aura Merchant", ouvrirShop)
for _, tableau in ipairs(tableaux3D) do
    boutonE(tableau.point, "View", if tableau.cle == "T" then "Top 100 · Total steps" else "Top 100 · Best game", function()
        ouvrirTop(tableau)
    end)
end

-- PORTAIL : quand tu marches dedans, la caméra plonge, flash blanc, et on arrive dans le jeu
local function jouer()
    if not etat.ouvert or etat.transition or etat.occupe then
        return
    end
    local camera = workspace.CurrentCamera
    local humanoid = monHumanoid()
    if humanoid then
        humanoid.WalkSpeed = 0 -- on ne bouge plus pendant la plongée
    end
    fermerPanneaux()
    camera.CameraType = Enum.CameraType.Scriptable
    etat.transition = { debut = os.clock(), duree = 1.1, de = camera.CFrame, fov = camera.FieldOfView, flash = false }
    sonClic(1)
    jouerSon("vent", 1.1, 0.7, nil, 1.6)
    tween(racine, 0.25, { GroupTransparency = 1 })
    emetteurPortail.Rate = 220
    emetteurPortail.Speed = NumberRange.new(6, 14)
    tween(lumierePortail, 1.0, { Brightness = 8, Range = 50 })
end

-- un fondu au noir, puis action() au milieu, puis on revient
local function enFondu(action)
    if etat.occupe then
        return
    end
    etat.occupe = true
    fondu.BackgroundColor3 = NOIR
    tween(fondu, 0.35, { BackgroundTransparency = 0 })
    task.wait(0.38)
    action()
    task.wait(0.1)
    tween(fondu, 0.6, { BackgroundTransparency = 1 })
    etat.occupe = false
end

local function fermerHub()
    etat.ouvert = false
    etat.transition = nil
    fermerPanneaux()
    racine.Visible = false
    emetteurPortail.Rate = 35
    emetteurPortail.Speed = NumberRange.new(1.5, 4.5)
    lumierePortail.Brightness = 2.5
    lumierePortail.Range = 30
end

local function afficherTitre()
    titre.Visible = true
    titre.TextTransparency = 0
    titre.TextStrokeTransparency = 0
    local numero = os.clock()
    etat.titre = numero
    task.delay(6, function()
        if etat.titre == numero then
            tween(titre, 1, { TextTransparency = 1, TextStrokeTransparency = 1 })
        end
    end)
end

-- retour dans le hub : le serveur remet ton avatar sur la place
local function ouvrirHub()
    JouerEvent:FireServer("Hub")
    versJeu:Fire("MenuOuvert") -- le script du jeu lâche la caméra
    etat.ouvert = true
    etat.transition = nil
    etat.intro = os.clock()
    attendreAuHub(3)
    cameraHub()
    racine.Visible = true
    racine.GroupTransparency = 1
    tween(racine, 0.6, { GroupTransparency = 0 })
    afficherTitre()
    afficherBoutique()
    majTableaux(true)
end

-- les boutons
boutonFermerShop.Activated:Connect(function()
    sonClic(1)
    fermerPanneaux()
end)
boutonFermerTop.Activated:Connect(function()
    sonClic(1)
    fermerPanneaux()
end)
boutonAfk.Activated:Connect(function()
    if not etat.ouvert or etat.transition then
        return
    end
    sonClic(3)
    task.spawn(enFondu, function()
        fermerHub()
        versJeu:Fire("Afk")
    end)
end)
boutonReglages.Activated:Connect(function()
    sonClic(4)
    versJeu:Fire("Reglages")
end)

-- le bouton MENU du jeu : retour au hub (on ressort du portail)
versHub.Event:Connect(function(action)
    if action == "Ouvrir" and not etat.ouvert then
        task.spawn(enFondu, ouvrirHub)
    end
end)

-- un nouvel avatar (mort, reset...) : la caméra le suit
joueur.CharacterAdded:Connect(function()
    if etat.ouvert and not etat.transition then
        task.wait(0.5)
        attendreAuHub(3)
        if etat.ouvert and not etat.transition then
            cameraHub()
        end
    end
end)

-- Échap / Retour arrière ferme le panneau ouvert
UserInputService.InputBegan:Connect(function(input, gere)
    if etat.panneau and not gere and (input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Escape) then
        fermerPanneaux()
    end
end)

-- ========================== À CHAQUE IMAGE ==========================
RunService.RenderStepped:Connect(function(dt)
    if not etat.ouvert then
        return
    end
    local t = os.clock()
    local camera = workspace.CurrentCamera

    -- 1) la scène bouge : l'anneau du portail tourne, les cristaux et les cubes flottent
    anneauPortail:PivotTo(CFrame.new(CENTRE_PORTAIL) * CFrame.Angles(0, 0, t * 0.5))
    lumierePortail.Color = couleurAnneau(t * 0.08)
    for _, a in ipairs(animes) do
        if a.modele then
            a.modele:PivotTo(a.cf * CFrame.Angles(0, t * a.vitesse, 0))
        else
            local cf = a.cf + Vector3.new(0, math.sin(t * 1.4 + a.phase) * a.amplitude, 0)
            if a.tourne then
                cf = cf * CFrame.Angles(0, t * 0.8 + a.phase, 0)
            end
            a.part.CFrame = cf
        end
    end
    echelleTitre.Scale = 1 + math.sin(t * 2.2) * 0.02

    -- 2) le tableau du top 100 défile tout seul (pause en haut, pause en bas, puis on remonte)
    for _, tableau in ipairs(tableaux3D) do
        local defile = tableau.defile
        local maximum = math.max(0, defile.AbsoluteCanvasSize.Y - defile.AbsoluteWindowSize.Y)
        if maximum > 0 then
            if tableau.pause > 0 then
                tableau.pause -= dt
                if tableau.pause <= 0 and tableau.enBas then
                    tableau.enBas = false
                    tableau.y = 0 -- retour en haut
                    tableau.pause = 4
                end
            else
                tableau.y += dt * 45
                if tableau.y >= maximum then
                    tableau.y = maximum
                    tableau.enBas = true
                    tableau.pause = 3
                end
            end
            defile.CanvasPosition = Vector2.new(0, math.min(tableau.y, maximum))
        end
    end

    -- 3) la plongée dans le portail
    local tr = etat.transition
    if tr then
        local k = math.clamp((t - tr.debut) / tr.duree, 0, 1)
        local e = k * k * k
        local but = CFrame.lookAt(CENTRE_PORTAIL + Vector3.new(0, 0, -2), CENTRE_PORTAIL - Vector3.new(0, 0, 20))
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = tr.de:Lerp(but, e) * CFrame.Angles(0, 0, e * 0.7)
        camera.FieldOfView = tr.fov + (95 - tr.fov) * e
        if k >= 0.72 and not tr.flash then
            tr.flash = true
            fondu.BackgroundColor3 = BLANC
            tween(fondu, 0.3, { BackgroundTransparency = 0 })
        end
        if k >= 1 then
            -- on est dans le portail : on passe au jeu
            fermerHub()
            versJeu:Fire("Jouer")
            task.delay(0.15, function()
                tween(fondu, 0.8, { BackgroundTransparency = 1 })
            end)
        end
        return
    end

    local r = maRacine()
    if not r or etat.occupe then
        return
    end
    local p = r.Position

    -- 4) tu marches dans le portail → PLAY
    local d = p - CENTRE_PORTAIL
    if t - etat.intro > 1.5 and math.abs(d.X) < 7.5 and d.Z < 0.8 and d.Z > -3.5 and d.Y > -12 and d.Y < 8 then
        jouer()
        return
    end

    -- 5) tombé de la place (ça ne devrait pas arriver) : on te remet au milieu
    if p.Y < SOL - 40 then
        r.AssemblyLinearVelocity = Vector3.zero
        r.CFrame = CFrame.lookAt(Vector3.new(O.X, SOL + 4, O.Z + 8), Vector3.new(O.X, SOL + 4, O.Z - 10))
    end

    -- 6) tu t'éloignes du marchand / du tableau : son panneau se ferme
    if etat.panneau == "shop" and (p - pointShop.Position).Magnitude > 18 then
        fermerPanneaux()
    elseif etat.panneau == "top" and (p - tableauAffiche.point.Position).Magnitude > 22 then
        fermerPanneaux()
    end
end)

-- ========================== DÉPART ==========================
afficherBoutique()
majTableaux(true)
-- le tableau se remet à jour tout seul de temps en temps
task.spawn(function()
    while true do
        task.wait(30)
        if etat.ouvert then
            majTableaux(true)
        end
    end
end)
liens:SetAttribute("HubPret", true) -- le script du jeu sait que le hub est là
afficherTitre()
attendreAuHub(6)
cameraHub()
tween(fondu, 1.2, { BackgroundTransparency = 1 })
