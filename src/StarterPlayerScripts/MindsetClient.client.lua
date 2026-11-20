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
local dossierGrimpeurs = ReplicatedStorage:WaitForChild("Grimpeurs")
local dossierChoixMusiques = ReplicatedStorage:WaitForChild("ChoixMusiques")

local GEO = {
    X0 = ReplicatedStorage:GetAttribute("GeoX0"),
    Y0 = ReplicatedStorage:GetAttribute("GeoY0"),
    Z0 = ReplicatedStorage:GetAttribute("GeoZ0"),
    HAUTEUR = ReplicatedStorage:GetAttribute("GeoHAUTEUR"),
    PROFONDEUR = ReplicatedStorage:GetAttribute("GeoPROFONDEUR"),
    ECART = ReplicatedStorage:GetAttribute("GeoECART"),
}
local NB_MARCHES = ReplicatedStorage:GetAttribute("NbMarches")
local NB_COULOIRS = ReplicatedStorage:GetAttribute("NbCouloirs")

local COULEURS = {
    Motivation = Color3.fromRGB(255, 150, 30),
    Ego = Color3.fromRGB(170, 80, 255),
    Discipline = Color3.fromRGB(60, 140, 255),
    Obsession = Color3.fromRGB(230, 40, 60),
}
local ORDRE_PERSOS = { "Motivation", "Ego", "Discipline", "Obsession" }
-- Ce qui s'affiche sur les cartes du menu (les vraies règles sont dans le script serveur)
local ICONES = { Motivation = "🔥", Ego = "👑", Discipline = "🧱", Obsession = "👁️" }
local DEVISES = {
    Motivation = "Le feu du départ",
    Ego = "Le roi du combo",
    Discipline = "Le mur inébranlable",
    Obsession = "Le monstre de la fin",
}
local COMPETENCES = {
    Motivation = { "⚡ +2 marches par note au début", "⚠️ Rate ensuite = -2" },
    Ego = { "💅 Combo 10+ : PARFAIT = +2", "⚠️ Une erreur = -2" },
    Discipline = { "🧱 +1 par note, toujours", "🛡️ Ne redescend JAMAIS" },
    Obsession = { "🐢 Début : que les PARFAIT", "🚀 2e moitié : +2 par note" },
}
local JAUGES = { "DÉBUT", "FIN", "SÉCURITÉ" }
local NOTES_PERSOS = { -- sur 5
    Motivation = { 5, 2, 2 },
    Ego = { 3, 4, 1 },
    Discipline = { 3, 3, 5 },
    Obsession = { 1, 5, 3 },
}
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
    IgnoreGuiInset = true,
    Parent = joueur:WaitForChild("PlayerGui"),
})

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
local chrono = texte({
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 98),
    Size = UDim2.new(0.3, 0, 0, 26),
    TextColor3 = Color3.fromRGB(255, 230, 120),
    ZIndex = 3,
    Parent = gui,
})
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
texte({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.fromOffset(40, 28), Text = "👑", ZIndex = 3, Parent = barre })

-- Écran de fin
local ecranFin = nouveau("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(0, 440, 0, 320),
    BackgroundColor3 = Color3.fromRGB(12, 12, 18),
    BackgroundTransparency = 0.05,
    Visible = false,
    ZIndex = 30,
    Parent = gui,
})
nouveau("UICorner", { CornerRadius = UDim.new(0, 18), Parent = ecranFin })
local contourFin = nouveau("UIStroke", { Thickness = 4, Color = OR, Parent = ecranFin })
local echelleFin = nouveau("UIScale", { Parent = ecranFin })
local finTitre = texte({ Position = UDim2.new(0, 15, 0, 15), Size = UDim2.new(1, -30, 0, 70), ZIndex = 31, Parent = ecranFin })
local finPlace = texte({ Position = UDim2.new(0, 15, 0, 92), Size = UDim2.new(1, -30, 0, 44), TextColor3 = OR, ZIndex = 31, Parent = ecranFin })
local finDetails = texte({ Position = UDim2.new(0, 15, 0, 144), Size = UDim2.new(1, -30, 0, 80), ZIndex = 31, Parent = ecranFin })
local finDrole = texte({
    Position = UDim2.new(0, 15, 0, 236),
    Size = UDim2.new(1, -30, 0, 64),
    TextColor3 = Color3.fromRGB(200, 200, 200),
    ZIndex = 31,
    Parent = ecranFin,
})

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
    flash.BackgroundTransparency = 1 - force
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
    forceSecousse = math.max(forceSecousse, force)
end

-- ========================== MENU DU LOBBY ==========================
-- Plein écran pendant le lobby : les 4 états d'esprit + le vote de la musique, la map floutée derrière.
local BLEU_MUSIQUE = Color3.fromRGB(120, 170, 255)

-- 🔊 Petits bruits de l'interface
local SONS = {
    survol = "rbxasset://sounds/volume_slider.ogg", -- son fourni avec Roblox : marche toujours
    clic = "rbxassetid://12221967",                 -- le « clic » classique de Roblox
}
local sonsModeles = {}
for nom, id in pairs(SONS) do
    sonsModeles[nom] = nouveau("Sound", { Name = "MindsetUI_" .. nom, SoundId = id, Volume = 0.5, Parent = SoundService })
end
task.spawn(function()
    pcall(function()
        ContentProvider:PreloadAsync({ sonsModeles.clic }, function(_, etatChargement)
            if etatChargement ~= Enum.AssetFetchStatus.Success then
                sonsModeles.clic.SoundId = SONS.survol -- secours si le clic ne se charge pas
            end
        end)
    end)
end)

local function jouerSon(nom, vitesse, volume, retard)
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
        task.delay(3, function()
            son:Destroy()
        end)
    end
    if retard and retard > 0 then
        task.delay(retard, jouer)
    else
        jouer()
    end
end

-- Survol : chaque carte a sa note (do, ré, mi, sol, la, do), et ça monte si tu enchaînes vite
local GAMME = { 1, 1.122, 1.26, 1.498, 1.682, 2 }
local serieSurvol, dernierSurvol = 0, 0
local function sonSurvol(note)
    local maintenant = os.clock()
    serieSurvol = if maintenant - dernierSurvol < 0.7 then math.min(serieSurvol + 1, 8) else 0
    dernierSurvol = maintenant
    jouerSon("survol", (GAMME[note] or 1) * (1 + serieSurvol * 0.03), 0.45)
end
local function sonClic(note)
    local base = GAMME[note] or 1
    jouerSon("clic", 1, 0.7)
    jouerSon("survol", base * 0.75, 0.5)
    jouerSon("survol", base * 1.5, 0.4, 0.07)
    jouerSon("survol", base * 2, 0.3, 0.14)
end

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
    Text = "CHOISIS TON ÉTAT D'ESPRIT",
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
local chronoMenu = texteMenu({
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.115),
    Size = UDim2.fromScale(0.3, 0.045),
    TextColor3 = OR,
    ZIndex = 12,
    Parent = menu,
})
local echelleChrono = nouveau("UIScale", { Parent = chronoMenu })
local titreMusique = texteMenu({
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.655),
    Size = UDim2.fromScale(0.6, 0.04),
    Text = "🎵 VOTE POUR LA MUSIQUE",
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
        Text = "✔ CHOISI",
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
        if c.survole or not menuOuvert then
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
        table.insert(morceaux, ICONES[persoChoisi] .. " " .. string.upper(persoChoisi))
    else
        table.insert(morceaux, "👆 Choisis ton état d'esprit")
    end
    if next(boutonsMusique) then
        local b = monVote and boutonsMusique[monVote]
        table.insert(morceaux, if b then "🎵 " .. b.valeur.Value else "🎵 Vote pour une musique")
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
    c.icone = texte({
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0.05),
        Size = UDim2.fromScale(0.6, 0.19),
        Text = ICONES[perso],
        TextStrokeTransparency = 1,
        ZIndex = 15,
        Parent = carte,
    })
    c.echelleIcone = nouveau("UIScale", { Parent = c.icone })
    texte({
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0.245),
        Size = UDim2.fromScale(0.9, 0.1),
        Text = string.upper(perso),
        TextColor3 = couleur,
        ZIndex = 15,
        Parent = carte,
    })
    texte({
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0.345),
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
        Position = UDim2.fromScale(0.5, 0.42),
        Size = UDim2.new(0.7, 0, 0, 2),
        BackgroundColor3 = couleur,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        ZIndex = 14,
        Parent = carte,
    })
    for j, ligne in ipairs(COMPETENCES[perso]) do
        texte({
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.fromScale(0.5, 0.445 + (j - 1) * 0.085),
            Size = UDim2.fromScale(0.9, 0.07),
            Text = ligne,
            Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(235, 235, 245),
            TextStrokeTransparency = 1,
            ZIndex = 15,
            Parent = carte,
        })
    end
    -- jauges DÉBUT / FIN / SÉCURITÉ (5 cases)
    c.segments = {}
    for j, nomJauge in ipairs(JAUGES) do
        local y = 0.64 + (j - 1) * 0.095
        texte({
            Position = UDim2.fromScale(0.07, y),
            Size = UDim2.fromScale(0.36, 0.06),
            Text = nomJauge,
            Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(170, 170, 190),
            TextStrokeTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 15,
            Parent = carte,
        })
        local valeur = NOTES_PERSOS[perso][j]
        for k = 1, 5 do
            local allume = k <= valeur
            local seg = nouveau("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.fromScale(0.45 + (k - 1) * 0.098, y + 0.03),
                Size = UDim2.fromScale(0.085, 0.04),
                BackgroundColor3 = if allume then couleur else Color3.fromRGB(45, 45, 60),
                BackgroundTransparency = if allume then 0.45 else 0.2,
                BorderSizePixel = 0,
                ZIndex = 15,
                Parent = carte,
            })
            nouveau("UICorner", { CornerRadius = UDim.new(0, 3), Parent = seg })
            if allume then
                table.insert(c.segments, { seg = seg, k = k })
            end
        end
    end
    -- au survol, les cases s'allument une par une
    c.surSurvol = function()
        for _, s in ipairs(c.segments) do
            task.delay(s.k * 0.045, function()
                if c.survole then
                    s.seg.BackgroundTransparency = 0
                    s.seg.Size = UDim2.fromScale(0.085, 0.065)
                    tween(s.seg, 0.22, { Size = UDim2.fromScale(0.085, 0.04) }, Enum.EasingStyle.Back)
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
        c.badge.Text = "✔ TON VOTE"
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
            Position = UDim2.fromScale(0.26, 0.1),
            Size = UDim2.fromScale(0.7, 0.44),
            Text = valeur.Value,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 15,
            Parent = c.carte,
        })
        c.votes = texte({
            Position = UDim2.fromScale(0.26, 0.55),
            Size = UDim2.fromScale(0.45, 0.2),
            Font = Enum.Font.GothamBold,
            TextColor3 = OR,
            TextStrokeTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 15,
            Parent = c.carte,
        })
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

-- ---------- Chrono du menu (tic-tac les 5 dernières secondes) ----------
ReplicatedStorage:GetAttributeChangedSignal("Temps"):Connect(function()
    local temps = ReplicatedStorage:GetAttribute("Temps") or 0
    chronoMenu.Text = if temps > 0 then "⏱️ " .. temps else ""
    if menuOuvert and temps > 0 and temps <= 5 then
        chronoMenu.TextColor3 = ROUGE
        echelleChrono.Scale = 1.4
        tween(echelleChrono, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
        jouerSon("survol", 0.5 + (6 - temps) * 0.1, 0.35)
    else
        chronoMenu.TextColor3 = OR
    end
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
        jouerSon("survol", 0.7 + rang * 0.1, 0.25, c.delai - os.clock())
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
            c.echelleIcone.Scale += ((if c.survole then 1.25 else 1) - c.echelleIcone.Scale) * lisse
            c.icone.Rotation = if c.survole then math.sin(t * 12) * 9 else c.icone.Rotation * (1 - lisse)
        end
        if c.barres then
            for k, barreEq in ipairs(c.barres) do
                local hauteur = if c.survole or c.choisi then 0.12 + 0.4 * math.abs(math.sin(t * (5 + k * 1.7) + k)) else 0.12
                barreEq.Size = barreEq.Size:Lerp(UDim2.fromScale(0.03, hauteur), math.min(1, dt * 20))
            end
        end
    end
end)

-- ========================== AVATARS SUR LES MARCHES ==========================
local ANIMS = {
    attente = "rbxassetid://507766388", -- animations R15 par défaut de Roblox
    saut = "rbxassetid://507765000",
    chute = "rbxassetid://507767968",
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
    if etat.animAttente then
        etat.animAttente:Play()
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

local NOMS_NIVEAUX = { "✨ AURA NIVEAU 1", "🔥 AURA NIVEAU 2", "👑 AURA MAX" }

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
    local scene = workspace:FindFirstChild("MindsetScene")
    for couloir = 0, NB_COULOIRS - 1 do
        local dossier = scene and scene:FindFirstChild("Couloir" .. couloir)
        local ligne = dossier and dossier:FindFirstChild("Ligne")
        if ligne then
            ligne.Color = if occupants[couloir] then couleurDe(occupants[couloir]) else Color3.fromRGB(70, 70, 80)
        end
    end
end

local effetsMoi -- défini plus bas (réactions quand TU montes/descends)

local function nouvelleMarche(etat)
    local cible = etat.config:GetAttribute("Marche") or 0
    local depart = etat.marcheAffichee or cible
    if math.abs(cible - depart) < 0.01 then
        return
    end
    local monte = cible > depart
    etat.saut = {
        de = depart,
        a = cible,
        debut = os.clock(),
        duree = math.min(0.4, 0.16 + 0.04 * math.abs(cible - depart)),
        monte = monte,
    }
    if monte and etat.animSaut then
        etat.animSaut:Play(0.05)
    elseif not monte and etat.animChute then
        etat.animChute:Play(0.05)
    end
    if etat.estMoi and effetsMoi then
        effetsMoi(depart, cible)
    end
end

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
local musique = nouveau("Sound", { Name = "MindsetMusique", Volume = 0.8, Parent = SoundService })
local partition = nil      -- infos de la manche en cours
local intervalle = 0.5
local musiqueLancee = false
local dernierRecalage = 0

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

local function maCouleur()
    return if monEtat then couleurDe(monEtat) else OR
end

local function effetTouche(position, verdict)
    local couleur = if verdict == "Parfait" then OR elseif verdict == "Bien" then Color3.fromRGB(120, 255, 160) else ROUGE
    local message = if verdict == "Parfait" then "PARFAIT ✨" elseif verdict == "Bien" then "BIEN" else "RATÉ ✖"
    local popup = texte({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(position.X, position.Y - 0.06),
        Size = UDim2.fromOffset(200, 44),
        Text = message,
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

local function juger(index, expire)
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
    tween(note.cercle, 0.12, { BackgroundTransparency = 1, Size = UDim2.fromOffset(note.taille * 1.3, note.taille * 1.3) })
    note.anneau:Destroy()
    task.delay(0.12, function()
        note.cercle:Destroy()
    end)
end

local function creerNote(index, tempsNote)
    -- une position pas trop loin, pas trop près de la précédente
    local x, y
    for _ = 1, 12 do
        x = 0.15 + math.random() * 0.62
        y = 0.3 + math.random() * 0.42
        if not dernierePosition then
            break
        end
        local distance = (Vector2.new(x, y) - dernierePosition).Magnitude
        if distance > 0.1 and distance < 0.35 then
            break
        end
    end
    dernierePosition = Vector2.new(x, y)
    compteurNotes += 1

    local couleur = maCouleur()
    local taille = if surMobile then 110 else 90
    local cercle = nouveau("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(x, y),
        Size = UDim2.fromOffset(taille, taille),
        BackgroundColor3 = couleur,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Font = Enum.Font.FredokaOne,
        TextScaled = true,
        TextColor3 = BLANC,
        TextStrokeTransparency = 0,
        Text = tostring((compteurNotes - 1) % 4 + 1),
        ZIndex = 6,
        Parent = zoneNotes,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = cercle })
    nouveau("UIStroke", { Color = BLANC, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = cercle })
    nouveau("UIPadding", {
        PaddingTop = UDim.new(0.22, 0),
        PaddingBottom = UDim.new(0.22, 0),
        PaddingLeft = UDim.new(0.22, 0),
        PaddingRight = UDim.new(0.22, 0),
        Parent = cercle,
    })
    tween(cercle, 0.15, { BackgroundTransparency = 0.1 })

    -- l'anneau qui se resserre : clique quand il touche le cercle !
    local anneau = nouveau("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(x, y),
        Size = UDim2.fromOffset(taille, taille),
        BackgroundTransparency = 1,
        ZIndex = 5,
        Parent = zoneNotes,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = anneau })
    nouveau("UIStroke", { Color = couleur, Thickness = 4, Parent = anneau })
    local echelle = nouveau("UIScale", { Scale = 3, Parent = anneau })
    local reste = math.max(0.05, partition.debut + tempsNote - maintenantServeur())
    tween(echelle, reste, { Scale = 1 }, Enum.EasingStyle.Linear)

    notesActives[index] = { cercle = cercle, anneau = anneau, temps = tempsNote, position = Vector2.new(x, y), taille = taille }
    cercle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            juger(index, false)
        end
    end)
end

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
        apparaitre(auraTexte, "💀 -" .. math.floor(depart - cible + 0.5) .. " MARCHE" .. (if depart - cible > 1.5 then "S" else ""), 0.8)
        return
    end
    if math.floor(cible / 10) > math.floor(depart / 10) and cible < NB_MARCHES then
        grosTexte.TextColor3 = maCouleur()
        apparaitre(grosTexte, "🪜 " .. math.floor(cible / 10) * 10 .. " MARCHES !", 1, echelleGros)
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
        apparaitre(grosTexte, "🔥 MODE AURA 🔥", 1.4, echelleGros)
        flasher(BLANC, 0.6)
        secousse(1.5)
        flou.Size = 14
        tween(flou, 0.6, { Size = 0 })
    else
        tween(effetAura, 0.6, { Saturation = 0, Contrast = 0, Brightness = 0 })
        grosTexte.TextColor3 = ROUGE
        apparaitre(grosTexte, "💀 AURA PERDUE", 1, echelleGros)
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
            apparaitre(grosTexte, "Tu es : " .. string.upper(perso), 1.4, echelleGros)
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
    dernierePosition = nil
    musiqueLancee = false
    viderNotes()
    jeJoue = monEtat ~= nil and monEtat.config:GetAttribute("EnJeu") == true

    if infos.musique and infos.musique ~= "" then
        musique.SoundId = infos.musique
        musique.Volume = 0.8
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
            flasher(BLANC, 0.15)
            secousse(0.5)
        end
        local attente = infos.debut - maintenantServeur()
        if attente > 0 then
            task.wait(attente)
        end
        if partition == infos then
            afficherDecompte(if jeJoue then "CLIQUE EN RYTHME !" else "👀 SPECTATEUR", OR)
            flasher(BLANC, 0.5)
            secousse(1)
        end
    end)
end)

-- ========================== ÉVÉNEMENTS ==========================
EvenementEvent.OnClientEvent:Connect(function(typeEvt, a, b)
    if typeEvt == "Sommet" then
        local couleur = COULEURS[b] or OR
        grosTexte.TextColor3 = couleur
        apparaitre(grosTexte, "👑 " .. tostring(a) .. " A ATTEINT LE SOMMET !", 2, echelleGros)
        flasher(OR, 0.4)
        secousse(1.5)
    elseif typeEvt == "Vainqueur" then
        local etat = avatars[a]
        jeJoue = false
        viderNotes()
        etatSuiviCamera = etat
        modeCinema(true)
        tween(effetAura, 0.5, { Saturation = -1, Contrast = 0.4 })
        flasher(OR, 0.7)
        secousse(2)
        if etat then
            grosTexte.TextColor3 = couleurDe(etat)
            apparaitre(
                grosTexte,
                "👑 " .. tostring(etat.config:GetAttribute("Nom")) .. " — " .. string.upper(tostring(etat.config:GetAttribute("Perso"))),
                3.8,
                echelleGros
            )
        end
    end
end)

-- ========================== PHASES ==========================
local function majPhase()
    local phase = ReplicatedStorage:GetAttribute("Phase")
    if phase == "Lobby" then
        ouvrirMenu()
    else
        fermerMenu()
    end
    statut.Visible = phase ~= "Lobby" -- le menu a son propre titre et son chrono
    chrono.Visible = phase ~= "Lobby"
    barre.Visible = phase == "Manche" or phase == "Fin"
    marcheTexte.Visible = phase == "Manche"
    if phase == "Lobby" then
        partition = nil
        jeJoue = false
        etatSuiviCamera = nil
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

local function majStatut()
    statut.Text = ReplicatedStorage:GetAttribute("Statut") or ""
end
local function majChrono()
    local temps = ReplicatedStorage:GetAttribute("Temps") or 0
    chrono.Text = if temps > 0 then "⏱️ " .. temps else ""
end
ReplicatedStorage:GetAttributeChangedSignal("Statut"):Connect(majStatut)
ReplicatedStorage:GetAttributeChangedSignal("Temps"):Connect(majChrono)
majStatut()
majChrono()

-- ========================== ÉCRAN DE FIN ==========================
local function statDrole(data)
    if data.perso == "Obsession" then
        return "Il n'a jamais regardé en bas. 🗿"
    elseif data.perso == "Ego" then
        return "Combo max x" .. data.comboMax .. ". Il va le dire à tout le monde. 💅"
    elseif data.perso == "Motivation" then
        return "Départ en feu 🔥... et après ?"
    elseif data.perso == "Discipline" then
        return "Marches perdues : 0. Logique. 🧱"
    end
    return ""
end

FinEvent.OnClientEvent:Connect(function(data)
    local couleur = COULEURS[data.perso] or BLANC
    finTitre.Text = "TU ES : " .. string.upper(data.perso)
    finTitre.TextColor3 = couleur
    contourFin.Color = couleur
    finPlace.Text = (if data.place == 1 then "👑 1er" else "🏁 " .. data.place .. "e") .. " sur " .. data.total
    finDetails.Text = "🪜 " .. data.marches .. " / " .. data.nbMarches .. " marches   🎯 " .. data.precision .. " %\n"
        .. "✨ " .. data.parfaits .. " parfaits   🔥 combo max x" .. data.comboMax .. "\n👑 Gagnant : " .. data.gagnant
    finDrole.Text = statDrole(data)
    ecranFin.Visible = true
    echelleFin.Scale = 0.6
    tween(echelleFin, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
    task.delay(7.5, function()
        ecranFin.Visible = false
    end)
end)

-- ========================== BOUCLE D'AFFICHAGE ==========================
local positionCamera = nil
local pointsCarte = {} -- [config] = point sur la mini-carte

RunService.RenderStepped:Connect(function(dt)
    local horloge = os.clock()

    -- 1) Les avatars sautent de marche en marche
    for _, etat in pairs(avatars) do
        local modele = etat.modele
        if modele and modele.Parent and etat.hauteur then
            local m = etat.config:GetAttribute("Marche") or 0
            local arc, inclinaison = 0, 0
            if etat.saut then
                local s = etat.saut
                local t = math.clamp((horloge - s.debut) / s.duree, 0, 1)
                local lisse = t * t * (3 - 2 * t)
                m = s.de + (s.a - s.de) * lisse
                if s.monte then
                    arc = math.sin(math.pi * t) * (1.2 + 0.25 * math.abs(s.a - s.de))
                else
                    arc = math.sin(math.pi * t) * 0.6
                    inclinaison = math.sin(math.pi * t) * 0.6 -- il bascule en arrière
                end
                if t >= 1 then
                    etat.saut = nil
                    if etat.animSaut then
                        etat.animSaut:Stop(0.1)
                    end
                    if etat.animChute then
                        etat.animChute:Stop(0.15)
                    end
                end
            end
            etat.marcheAffichee = m
            if etat.couloir then
                local position = positionMarche(etat.couloir, m, etat.hauteur) + Vector3.new(0, arc, 0)
                modele:PivotTo(CFrame.lookAt(position, position + Vector3.new(1, 0, 0)) * CFrame.Angles(inclinaison, 0, 0))
            else
                modele:PivotTo(CFrame.new(0, -500, 0)) -- plus de place : caché
            end
        end
    end

    -- 2) Caméra 2D : vue de côté qui suit ton avatar (ou le vainqueur)
    local camera = workspace.CurrentCamera
    if camera then
        camera.CameraType = Enum.CameraType.Scriptable
        local suivi = etatSuiviCamera or monEtat
        local focus
        local zoom = if etatSuiviCamera then 0.45 else 1
        local distance = 75 * zoom
        local vitesseCamera = 5
        if menuOuvert and not etatSuiviCamera then
            -- menu du lobby : la caméra se balade doucement le long des escaliers (floutés derrière le menu)
            focus = positionMarche(2, NB_MARCHES * (0.45 + 0.4 * math.sin(horloge * 0.06)), 3)
            distance = 100
            vitesseCamera = 1.2
        elseif suivi and suivi.couloir and suivi.hauteur then
            focus = positionMarche(suivi.couloir, suivi.marcheAffichee or 0, suivi.hauteur)
        else
            focus = positionMarche(0, 0, 3)
        end
        local cible = focus + Vector3.new(7 * zoom, 3, distance)
        positionCamera = if positionCamera then positionCamera:Lerp(cible, math.min(1, dt * vitesseCamera)) else cible
        forceSecousse = math.max(0, forceSecousse - dt * 4)
        local tremble = Vector3.new((math.random() - 0.5) * forceSecousse, (math.random() - 0.5) * forceSecousse, 0)
        local roulis = (math.random() - 0.5) * forceSecousse * 0.01
        local oeil = positionCamera + tremble
        camera.CFrame = CFrame.lookAt(oeil, oeil - Vector3.new(0, 0, 1)) * CFrame.Angles(0, 0, roulis)
        fovPulse += (0 - fovPulse) * math.min(1, dt * 8)
        camera.FieldOfView = FOV_BASE + fovPulse
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
            elseif horloge - dernierRecalage > 1 then
                dernierRecalage = horloge
                if musique.IsPlaying and math.abs(musique.TimePosition - attendu) > 0.08 then
                    musique.TimePosition = attendu -- on recolle la musique au rythme
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
        marcheTexte.Text = "🪜 " .. (monEtat.config:GetAttribute("Marche") or 0) .. " / " .. NB_MARCHES
        marcheTexte.TextColor3 = maCouleur()
    end
    if barre.Visible then
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
            point.Position = UDim2.fromScale(0.5, 1 - math.clamp((etat.marcheAffichee or 0) / NB_MARCHES, 0, 1))
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
