--[[
    🧠 MINDSET RACE — Script CLIENT (interface, caméra, musiques et effets)
    À mettre dans : StarterPlayer > StarterPlayerScripts  (type : LocalScript)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local joueur = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("MindsetRemotes")
local AnnonceEvent = remotes:WaitForChild("Annonce")
local EvenementEvent = remotes:WaitForChild("Evenement")
local AuraEvent = remotes:WaitForChild("Aura")
local FinEvent = remotes:WaitForChild("Fin")
local ChuteEvent = remotes:WaitForChild("Chute")
local AttaqueEvent = remotes:WaitForChild("Attaque")

local COULEURS = {
    Motivation = Color3.fromRGB(255, 150, 30),
    Ego = Color3.fromRGB(170, 80, 255),
    Discipline = Color3.fromRGB(60, 140, 255),
    Obsession = Color3.fromRGB(230, 40, 60),
    Talent = Color3.fromRGB(60, 220, 140),
}
local BLANC = Color3.new(1, 1, 1)
local NOIR = Color3.new(0, 0, 0)
local OR = Color3.fromRGB(255, 220, 80)

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
    proprietes.Font = Enum.Font.FredokaOne
    proprietes.TextScaled = true
    proprietes.TextColor3 = proprietes.TextColor3 or BLANC
    proprietes.TextStrokeTransparency = proprietes.TextStrokeTransparency or 0
    proprietes.Text = proprietes.Text or ""
    return nouveau("TextLabel", proprietes)
end

local function tween(objet, duree, proprietes, style)
    local animation = TweenService:Create(
        objet,
        TweenInfo.new(duree, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        proprietes
    )
    animation:Play()
    return animation
end

-- ========================== INTERFACE ==========================
local gui = nouveau("ScreenGui", {
    Name = "MindsetRaceGui",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    Parent = joueur:WaitForChild("PlayerGui"),
})

-- Lignes de vitesse (tout au fond de l'interface)
local conteneurLignes = nouveau("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    ZIndex = 1,
    Parent = gui,
})
local lignes = {}
for _ = 1, 26 do
    local cadre = nouveau("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = BLANC,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 2, 0, math.random(50, 120)),
        ZIndex = 1,
        Parent = conteneurLignes,
    })
    table.insert(lignes, { cadre = cadre, angle = math.random() * math.pi * 2, rayon = 0.3 + math.random() * 0.4 })
end

-- Flash plein écran
local flash = nouveau("Frame", {
    BackgroundColor3 = BLANC,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Size = UDim2.fromScale(1, 1),
    ZIndex = 2,
    Parent = gui,
})

-- Bandes noires « cinéma »
local bandeHaut = nouveau("Frame", {
    BackgroundColor3 = NOIR,
    BorderSizePixel = 0,
    Size = UDim2.fromScale(1, 0),
    ZIndex = 8,
    Parent = gui,
})
local bandeBas = nouveau("Frame", {
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.fromScale(0, 1),
    BackgroundColor3 = NOIR,
    BorderSizePixel = 0,
    Size = UDim2.fromScale(1, 0),
    ZIndex = 8,
    Parent = gui,
})

local statut = texte({
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 70),
    Size = UDim2.new(0.8, 0, 0, 38),
    ZIndex = 3,
    Parent = gui,
})
local chrono = texte({
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 110),
    Size = UDim2.new(0.3, 0, 0, 28),
    TextColor3 = Color3.fromRGB(255, 230, 120),
    ZIndex = 3,
    Parent = gui,
})
local banniere = texte({
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 150),
    Size = UDim2.new(0.85, 0, 0, 36),
    TextColor3 = Color3.fromRGB(150, 220, 255),
    Visible = false,
    ZIndex = 3,
    Parent = gui,
})
local grosTexte = texte({
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.3),
    Size = UDim2.new(0.9, 0, 0, 70),
    TextTransparency = 1,
    TextStrokeTransparency = 1,
    ZIndex = 9,
    Parent = gui,
})
local auraTexte = texte({
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.62),
    Size = UDim2.new(0.7, 0, 0, 64),
    TextColor3 = OR,
    TextTransparency = 1,
    TextStrokeTransparency = 1,
    ZIndex = 9,
    Parent = gui,
})
local echelleAura = nouveau("UIScale", { Parent = auraTexte })
local niveauTexte = texte({
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.72),
    Size = UDim2.new(0.5, 0, 0, 44),
    TextTransparency = 1,
    TextStrokeTransparency = 1,
    ZIndex = 9,
    Parent = gui,
})
local decompte = texte({
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.42),
    Size = UDim2.fromScale(0.5, 0.3),
    TextTransparency = 1,
    TextStrokeTransparency = 1,
    ZIndex = 9,
    Parent = gui,
})
local echelleDecompte = nouveau("UIScale", { Parent = decompte })
local persoTexte = texte({
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 20, 1, -20),
    Size = UDim2.new(0, 280, 0, 34),
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "🧠 Monte sur un podium !",
    ZIndex = 3,
    Parent = gui,
})
local rangTexte = texte({
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -20, 0, 110),
    Size = UDim2.new(0, 160, 0, 40),
    TextColor3 = OR,
    Visible = false,
    ZIndex = 3,
    Parent = gui,
})

-- Écran de fin
local ecranFin = nouveau("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(0, 420, 0, 300),
    BackgroundColor3 = Color3.fromRGB(20, 20, 30),
    BackgroundTransparency = 0.1,
    Visible = false,
    ZIndex = 10,
    Parent = gui,
})
nouveau("UICorner", { CornerRadius = UDim.new(0, 18), Parent = ecranFin })
local contourFin = nouveau("UIStroke", { Thickness = 4, Color = OR, Parent = ecranFin })
local finTitre = texte({ Position = UDim2.new(0, 15, 0, 15), Size = UDim2.new(1, -30, 0, 70), ZIndex = 11, Parent = ecranFin })
local finPlace = texte({ Position = UDim2.new(0, 15, 0, 95), Size = UDim2.new(1, -30, 0, 45), TextColor3 = OR, ZIndex = 11, Parent = ecranFin })
local finDetails = texte({ Position = UDim2.new(0, 15, 0, 150), Size = UDim2.new(1, -30, 0, 60), ZIndex = 11, Parent = ecranFin })
local finDrole = texte({
    Position = UDim2.new(0, 15, 0, 220),
    Size = UDim2.new(1, -30, 0, 60),
    TextColor3 = Color3.fromRGB(200, 200, 200),
    ZIndex = 11,
    Parent = ecranFin,
})

-- Effets d'image (seulement pour ce joueur)
local couleursAura = nouveau("ColorCorrectionEffect", { Name = "MindsetEffetAura", Parent = Lighting })
local couleursFinale = nouveau("ColorCorrectionEffect", { Name = "MindsetEffetFinale", Parent = Lighting })
local flou = nouveau("BlurEffect", { Name = "MindsetFlou", Size = 0, Parent = Lighting })

-- ========================== OUTILS ==========================
local function apparaitre(label, message, duree)
    label.Text = message
    label.TextTransparency = 0
    label.TextStrokeTransparency = 0
    label:SetAttribute("Numero", (label:GetAttribute("Numero") or 0) + 1)
    local numero = label:GetAttribute("Numero")
    task.delay(duree, function()
        if label:GetAttribute("Numero") == numero then
            tween(label, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
        end
    end)
end

local function flasher(couleur, force)
    flash.BackgroundColor3 = couleur
    flash.BackgroundTransparency = 1 - force
    tween(flash, 0.5, { BackgroundTransparency = 1 })
end

local function modeCinema(actif)
    local hauteur = if actif then 0.11 else 0
    tween(bandeHaut, 0.6, { Size = UDim2.fromScale(1, hauteur) })
    tween(bandeBas, 0.6, { Size = UDim2.fromScale(1, hauteur) })
end

local fovBonus = 0 -- « coup de zoom » ajouté au champ de vision, qui retombe tout seul
local secousseEnCours = false

local function secousse(force, duree)
    task.spawn(function()
        local personnage = joueur.Character
        local humanoid = personnage and personnage:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            return
        end
        secousseEnCours = true
        local fin = os.clock() + duree
        while os.clock() < fin and humanoid.Parent do
            local reste = (fin - os.clock()) / duree
            humanoid.CameraOffset = Vector3.new(
                (math.random() - 0.5) * force * reste,
                (math.random() - 0.5) * force * reste,
                0
            )
            RunService.RenderStepped:Wait()
        end
        humanoid.CameraOffset = Vector3.zero
        secousseEnCours = false
    end)
end

-- ========================== MUSIQUES ==========================
local VOLUME_FOND = 0.45
local musiqueFond = nouveau("Sound", { Name = "MindsetMusique", Looped = true, Volume = 0, Parent = SoundService })
local jetonMusique = 0

local function idMusique(attribut)
    local id = ReplicatedStorage:GetAttribute(attribut)
    if typeof(id) == "string" and id ~= "" then
        return id
    end
    return nil
end

local function jouerSon(id, volume, vitesse)
    if not id or id == "" then
        return nil
    end
    local son = nouveau("Sound", { SoundId = id, Volume = volume or 1, PlaybackSpeed = vitesse or 1, Parent = SoundService })
    son:Play()
    Debris:AddItem(son, 12)
    return son
end

local function changerMusique(attribut)
    local id = idMusique(attribut)
    jetonMusique += 1
    local jeton = jetonMusique
    tween(musiqueFond, 0.5, { Volume = 0 })
    task.delay(0.5, function()
        if jeton ~= jetonMusique then
            return
        end
        musiqueFond:Stop()
        musiqueFond.PlaybackSpeed = 1
        if id then
            musiqueFond.SoundId = id
            musiqueFond.TimePosition = 0
            musiqueFond:Play()
            tween(musiqueFond, 1, { Volume = VOLUME_FOND })
        end
    end)
end

-- Un son phonk au hasard, et la musique de fond baisse pendant le moment aura
local function jouerMusiqueAura()
    local liste = {}
    for _, id in ipairs(string.split(ReplicatedStorage:GetAttribute("MusiquesAura") or "", ",")) do
        id = string.gsub(id, "%s", "")
        if id ~= "" then
            table.insert(liste, id)
        end
    end
    if #liste == 0 then
        return false
    end
    local son = jouerSon(liste[math.random(1, #liste)], 1)
    if son then
        tween(musiqueFond, 0.2, { Volume = VOLUME_FOND * 0.25 })
        task.delay(3.5, function()
            tween(son, 0.6, { Volume = 0 })
            tween(musiqueFond, 0.8, { Volume = VOLUME_FOND })
        end)
    end
    return true
end

-- ========================== LE PUBLIC QUI SAUTE ==========================
local ferveurBase = 0.2 -- calme dans le lobby, déchaîné à la fin
local ferveur = 0.2
local spectateurs = {} -- [partie] = { base = CFrame, phase = nombre }

local function ajouterSpectateur(partie)
    if partie:IsA("BasePart") then
        spectateurs[partie] = { base = partie.CFrame, phase = partie:GetAttribute("Phase") or 0 }
    end
end

task.spawn(function()
    local carte = workspace:WaitForChild("MindsetRaceCarte", 60)
    local dossier = carte and carte:WaitForChild("Foule", 60)
    if not dossier then
        return
    end
    for _, partie in ipairs(dossier:GetDescendants()) do
        ajouterSpectateur(partie)
    end
    dossier.DescendantAdded:Connect(ajouterSpectateur)
    dossier.DescendantRemoving:Connect(function(partie)
        spectateurs[partie] = nil
    end)
end)

local partiesFoule, cframesFoule = {}, {}
local accumulateurFoule = 0
RunService.Heartbeat:Connect(function(dt)
    ferveur += (ferveurBase - ferveur) * math.min(1, dt * 1.5)
    accumulateurFoule += dt
    if accumulateurFoule < 1 / 30 then
        return
    end
    accumulateurFoule = 0
    table.clear(partiesFoule)
    table.clear(cframesFoule)
    local t = os.clock()
    local rythme = 6 + ferveur * 8
    for partie, info in pairs(spectateurs) do
        local saut = math.max(0, math.sin(t * rythme + info.phase)) * ferveur * 1.6
        table.insert(partiesFoule, partie)
        table.insert(cframesFoule, info.base + Vector3.new(0, saut, 0))
    end
    if #partiesFoule > 0 then
        workspace:BulkMoveTo(partiesFoule, cframesFoule, Enum.BulkMoveMode.FireCFrameChanged)
    end
end)

-- ========================== SENSATION DE VITESSE ==========================
local enCourse = false
local fovActuel = 70

RunService.RenderStepped:Connect(function(dt)
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    local personnage = joueur.Character
    local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
    local humanoid = personnage and personnage:FindFirstChildOfClass("Humanoid")
    local vitesse = 0
    if racine then
        local v = racine.AssemblyLinearVelocity
        vitesse = Vector3.new(v.X, 0, v.Z).Magnitude
    end
    local rapide = enCourse and vitesse > 27
    local intensite = if rapide then math.clamp((vitesse - 27) / 12, 0.2, 1) else 0

    -- Champ de vision : plus tu vas vite, plus l'image s'étire
    if camera.CameraType ~= Enum.CameraType.Scriptable then
        local cible = 70 + fovBonus
        if enCourse then
            cible += math.clamp((vitesse - 16) * 0.9, 0, 24)
        end
        fovActuel += (cible - fovActuel) * math.min(1, dt * 6)
        camera.FieldOfView = fovActuel
    end
    fovBonus = math.max(0, fovBonus - dt * 25)

    -- Lignes de vitesse
    for _, ligne in ipairs(lignes) do
        if intensite > 0 then
            ligne.rayon += dt * (1.2 + intensite * 1.5)
            if ligne.rayon > 0.8 then
                ligne.rayon = 0.3 + math.random() * 0.15
                ligne.angle = math.random() * math.pi * 2
            end
            ligne.cadre.Position = UDim2.fromScale(
                0.5 + math.cos(ligne.angle) * ligne.rayon,
                0.5 + math.sin(ligne.angle) * ligne.rayon
            )
            ligne.cadre.Rotation = math.deg(ligne.angle) + 90
            ligne.cadre.BackgroundTransparency = 1 - 0.55 * intensite * math.clamp((ligne.rayon - 0.3) * 3, 0, 1)
        else
            ligne.cadre.BackgroundTransparency = 1
        end
    end

    -- Petite vibration de la caméra à pleine vitesse
    if humanoid and not secousseEnCours then
        if rapide then
            local force = 0.05 * intensite
            humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * force, (math.random() - 0.5) * force, 0)
        elseif humanoid.CameraOffset ~= Vector3.zero then
            humanoid.CameraOffset = Vector3.zero
        end
    end
end)

-- ========================== CAMÉRA : INTRO ET VAINQUEUR ==========================
local function cameraDerriereLeJoueur()
    local camera = workspace.CurrentCamera
    local personnage = joueur.Character
    local humanoid = personnage and personnage:FindFirstChildOfClass("Humanoid")
    local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
    if not camera then
        return
    end
    camera.CameraType = Enum.CameraType.Custom
    if humanoid then
        camera.CameraSubject = humanoid
    end
    if racine then
        -- on se place derrière le perso, tourné vers l'arrivée
        camera.CFrame = CFrame.lookAt(racine.Position + Vector3.new(0, 6, -14), racine.Position + Vector3.new(0, 2, 10))
    end
    modeCinema(false)
end

local function lancerIntro()
    local camera = workspace.CurrentCamera
    local carte = workspace:FindFirstChild("MindsetRaceCarte")
    local arche = carte and carte:FindFirstChild("Arche")
    local depart = carte and carte:FindFirstChild("LigneDepart")
    if not camera or not arche or not depart then
        return
    end
    modeCinema(true)
    camera.CameraType = Enum.CameraType.Scriptable
    camera.FieldOfView = 60
    local cibleDepart = depart.Position + Vector3.new(0, 3, -8)
    camera.CFrame = CFrame.lookAt(arche.Position + Vector3.new(0, 15, 30), cibleDepart)
    tween(camera, 3.2, { CFrame = CFrame.lookAt(depart.Position + Vector3.new(0, 8, 25), cibleDepart) }, Enum.EasingStyle.Sine)
    grosTexte.TextColor3 = OR
    apparaitre(grosTexte, "🏁 MINDSET RACE 🏁", 2.5)
end

local function celebrerVainqueur(duree, modele, nom, perso)
    local camera = workspace.CurrentCamera
    local racine = modele and modele:FindFirstChild("HumanoidRootPart")
    local couleur = COULEURS[perso] or OR

    grosTexte.TextColor3 = couleur
    apparaitre(grosTexte, "👑 " .. tostring(nom) .. " — " .. string.upper(tostring(perso)), duree)
    flasher(OR, 0.6)
    ferveur = 1.5
    if idMusique("MusiqueVictoire") then
        changerMusique("MusiqueVictoire")
    else
        jouerMusiqueAura()
    end

    if not camera or not racine then
        return
    end
    modeCinema(true)
    camera.CameraType = Enum.CameraType.Scriptable
    camera.FieldOfView = 55
    local debut = os.clock()
    local connexion
    connexion = RunService.RenderStepped:Connect(function()
        local t = os.clock() - debut
        if t > duree or not racine.Parent then
            connexion:Disconnect()
            cameraDerriereLeJoueur()
            return
        end
        local angle = t * 0.9
        local centre = racine.Position + Vector3.new(0, 1.5, 0)
        local position = centre + Vector3.new(math.sin(angle) * 12, 4 + t * 0.5, math.cos(angle) * 12)
        camera.CFrame = CFrame.lookAt(position, centre)
    end)
end

-- ========================== PHASES DU JEU ==========================
local function finale(active)
    if active then
        tween(couleursFinale, 1, { TintColor = Color3.fromRGB(255, 225, 215), Saturation = 0.3, Contrast = 0.1 })
        tween(musiqueFond, 1, { PlaybackSpeed = 1.08 })
    else
        tween(couleursFinale, 1, { TintColor = BLANC, Saturation = 0, Contrast = 0 })
    end
end

local function majPhase()
    local phase = ReplicatedStorage:GetAttribute("Phase")
    enCourse = phase == "Course"
    if phase == "Lobby" then
        cameraDerriereLeJoueur()
        changerMusique("MusiqueLobby")
        ferveurBase = 0.2
        finale(false)
    elseif phase == "Intro" then
        changerMusique("MusiqueCourse")
        ferveurBase = 0.6
        lancerIntro()
    elseif phase == "Decompte" then
        cameraDerriereLeJoueur()
    elseif phase == "Course" then
        ferveurBase = 0.5
    elseif phase == "Fin" then
        ferveurBase = 1
    end
end
ReplicatedStorage:GetAttributeChangedSignal("Phase"):Connect(majPhase)
majPhase()

-- ========================== STATUT / CHRONO / RANG ==========================
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

local function majRang()
    local rang = joueur:GetAttribute("Rang") or 0
    local total = joueur:GetAttribute("NbCoureurs") or 0
    if rang > 0 then
        rangTexte.Text = (if rang == 1 then "🥇 1er" else "🏃 " .. rang .. "e") .. " / " .. total
        rangTexte.Visible = true
    else
        rangTexte.Visible = false
    end
end
joueur:GetAttributeChangedSignal("Rang"):Connect(majRang)
joueur:GetAttributeChangedSignal("NbCoureurs"):Connect(majRang)

-- Choix du personnage
joueur:GetAttributeChangedSignal("Perso"):Connect(function()
    local perso = joueur:GetAttribute("Perso")
    if perso then
        persoTexte.Text = "🧠 Ton perso : " .. string.upper(perso)
        persoTexte.TextColor3 = COULEURS[perso] or BLANC
        grosTexte.TextColor3 = COULEURS[perso] or BLANC
        apparaitre(grosTexte, "Tu es : " .. string.upper(perso), 1.5)
    end
end)

-- ========================== MOMENTS AURA ==========================
local combo, dernierCombo = 0, 0

AnnonceEvent.OnClientEvent:Connect(function(message, duree)
    grosTexte.TextColor3 = BLANC
    apparaitre(grosTexte, message, duree or 1.5)
end)

AuraEvent.OnClientEvent:Connect(function(message, taille)
    if taille == "petit" then
        -- petit moment (turbo) : pas de musique, juste un coup de boost à l'écran
        apparaitre(auraTexte, message, 0.8)
        flasher(Color3.fromRGB(255, 240, 120), 0.25)
        fovBonus = math.max(fovBonus, 10)
        return
    end

    -- GROS moment aura : musique phonk, flash doré, zoom, flou, public en folie
    if os.clock() - dernierCombo < 6 then
        combo += 1
    else
        combo = 1
    end
    dernierCombo = os.clock()

    jouerMusiqueAura()
    auraTexte.TextColor3 = OR
    apparaitre(auraTexte, if combo > 1 then message .. "  x" .. combo else message, 1.4)
    echelleAura.Scale = 1.8
    tween(echelleAura, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)

    flasher(OR, 0.45)
    couleursAura.TintColor = Color3.fromRGB(255, 235, 180)
    couleursAura.Saturation = 0.5
    couleursAura.Contrast = 0.25
    tween(couleursAura, 1.2, { TintColor = BLANC, Saturation = 0, Contrast = 0 })
    flou.Size = 10
    tween(flou, 0.5, { Size = 0 })
    fovBonus = math.max(fovBonus, 16 + combo * 2)
    ferveur = math.max(ferveur, 1.2)
    secousse(0.4, 0.25)
end)

-- Ton niveau d'aura monte pendant la course
local NOMS_NIVEAUX = { "✨ AURA NIVEAU 1", "🔥 AURA NIVEAU 2", "👑 AURA MAX" }
local COULEURS_NIVEAUX = { Color3.fromRGB(150, 220, 255), Color3.fromRGB(255, 140, 40), OR }
joueur:GetAttributeChangedSignal("NiveauAura"):Connect(function()
    local niveau = joueur:GetAttribute("NiveauAura") or 0
    if niveau > 0 and NOMS_NIVEAUX[niveau] then
        niveauTexte.TextColor3 = COULEURS_NIVEAUX[niveau]
        apparaitre(niveauTexte, NOMS_NIVEAUX[niveau], 1.6)
        flasher(COULEURS_NIVEAUX[niveau], 0.3 + niveau * 0.1)
    end
end)

-- ========================== ÉVÉNEMENTS DE COURSE ==========================
local function pluie(duree)
    local nuage = nouveau("Part", {
        Name = "PluieLocale",
        Size = Vector3.new(80, 1, 80),
        Anchored = true,
        CanCollide = false,
        CanQuery = false,
        CanTouch = false,
        Transparency = 1,
        Parent = workspace,
    })
    nouveau("ParticleEmitter", {
        EmissionDirection = Enum.NormalId.Bottom,
        Color = ColorSequence.new(Color3.fromRGB(170, 200, 255)),
        Size = NumberSequence.new(0.15),
        Transparency = NumberSequence.new(0.3),
        Lifetime = NumberRange.new(0.8),
        Speed = NumberRange.new(60),
        Rate = 400,
        Parent = nuage,
    })
    local grisaille = nouveau("ColorCorrectionEffect", {
        Name = "MindsetPluie",
        TintColor = Color3.fromRGB(200, 215, 255),
        Saturation = -0.35,
        Parent = Lighting,
    })
    local connexion = RunService.RenderStepped:Connect(function()
        local camera = workspace.CurrentCamera
        if camera then
            nuage.Position = camera.CFrame.Position + Vector3.new(0, 30, 0)
        end
    end)
    task.delay(duree, function()
        connexion:Disconnect()
        nuage:Destroy()
        grisaille:Destroy()
    end)
end

local MESSAGES_EVENEMENTS = {
    Pluie = "🌧️ IL PLEUT ! Motivation perd toute sa motivation...",
    Telephone = "📱 DRING DRING ! Tout le monde regarde son téléphone (sauf Discipline et Obsession)",
    Public = "👏 LE PUBLIC APPLAUDIT ! L'Ego s'envole",
    DerniereLigne = "🔥 DERNIÈRE LIGNE DROITE ! TOUT DONNER ! 🔥",
}
local COULEURS_DECOMPTE = { Color3.fromRGB(120, 255, 140), Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 90, 90) }

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

EvenementEvent.OnClientEvent:Connect(function(typeEvt, duree, ...)
    if typeEvt == "Decompte" then
        afficherDecompte(tostring(duree), COULEURS_DECOMPTE[duree] or BLANC)
        flasher(BLANC, 0.15)
        fovBonus = math.max(fovBonus, 5)
        secousse(0.3, 0.2)
        return
    elseif typeEvt == "Go" then
        afficherDecompte("GO !", OR)
        flasher(BLANC, 0.6)
        fovBonus = 22
        secousse(0.7, 0.4)
        ferveur = 1.3
        return
    elseif typeEvt == "Vainqueur" then
        celebrerVainqueur(duree, ...)
        return
    end

    banniere.Text = MESSAGES_EVENEMENTS[typeEvt] or typeEvt
    banniere.Visible = true
    if typeEvt == "Pluie" then
        pluie(duree)
    elseif typeEvt == "DerniereLigne" then
        finale(true)
        flasher(Color3.fromRGB(255, 120, 60), 0.35)
        fovBonus = math.max(fovBonus, 12)
        ferveurBase = 0.9
    end
    task.delay(math.max(duree, 3), function()
        banniere.Visible = false
    end)
end)

-- ========================== BOUTONS : TACLE / BALAYETTE ==========================
local surMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local hauteurBouton = if surMobile then 56 else 64

local boutons = nouveau("Frame", {
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -20, 1, if surMobile then -150 else -20), -- sur mobile : au-dessus du bouton saut
    Size = UDim2.new(0, 120, 0, hauteurBouton * 2 + 8),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 3,
    Parent = gui,
})
nouveau("UIListLayout", {
    Padding = UDim.new(0, 8),
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = boutons,
})

local function bouton(texteBouton, couleur, ordre)
    local b = nouveau("TextButton", {
        Size = UDim2.new(0, 120, 0, hauteurBouton),
        BackgroundColor3 = couleur,
        BackgroundTransparency = 0.15,
        Font = Enum.Font.FredokaOne,
        TextScaled = true,
        TextColor3 = BLANC,
        Text = texteBouton,
        LayoutOrder = ordre,
        ZIndex = 3,
        Parent = boutons,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 14), Parent = b })
    nouveau("UIPadding", {
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 4),
        Parent = b,
    })
    return b
end

local TEXTE_TACLE = if surMobile then "🦵 TACLE" else "🦵 TACLE\n[E]"
local TEXTE_BALAYETTE = if surMobile then "🌀 BALAYETTE" else "🌀 BALAYETTE\n[F]"
local boutonTacle = bouton(TEXTE_TACLE, Color3.fromRGB(220, 90, 40), 1)
local boutonBalayette = bouton(TEXTE_BALAYETTE, Color3.fromRGB(150, 60, 220), 2)

local function envoyerAttaque(typeAttaque)
    if ReplicatedStorage:GetAttribute("CourseEnCours") then
        AttaqueEvent:FireServer(typeAttaque)
    end
end

-- Clavier et manette (E et F marchent pareil en AZERTY et en QWERTY)
ContextActionService:BindAction("MindsetTacle", function(_, etat)
    if etat == Enum.UserInputState.Begin then
        envoyerAttaque("Tacle")
    end
    return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonX)

ContextActionService:BindAction("MindsetBalayette", function(_, etat)
    if etat == Enum.UserInputState.Begin then
        envoyerAttaque("Balayette")
    end
    return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonB)

boutonTacle.Activated:Connect(function()
    envoyerAttaque("Tacle")
end)
boutonBalayette.Activated:Connect(function()
    envoyerAttaque("Balayette")
end)

-- Les boutons n'apparaissent que pendant la course
local function majCourse()
    boutons.Visible = ReplicatedStorage:GetAttribute("CourseEnCours") == true
end
ReplicatedStorage:GetAttributeChangedSignal("CourseEnCours"):Connect(majCourse)
majCourse()

-- Affiche la recharge sur les boutons
RunService.Heartbeat:Connect(function()
    if not boutons.Visible then
        return
    end
    local reste = (joueur:GetAttribute("RechargeFin") or 0) - workspace:GetServerTimeNow()
    if reste > 0 then
        local attente = "⏳ " .. math.ceil(reste)
        boutonTacle.Text = attente
        boutonBalayette.Text = attente
        boutonTacle.BackgroundTransparency = 0.6
        boutonBalayette.BackgroundTransparency = 0.6
    else
        boutonTacle.Text = TEXTE_TACLE
        boutonBalayette.Text = TEXTE_BALAYETTE
        boutonTacle.BackgroundTransparency = 0.15
        boutonBalayette.BackgroundTransparency = 0.15
    end
end)

-- ========================== RÉSULTATS DES ATTAQUES ==========================
local SON_ATTAQUE = "rbxasset://sounds/swordlunge.wav" -- son intégré à Roblox
local NOMS_ATTAQUES = { Tacle = "🦵 TACLE", Balayette = "🌀 BALAYETTE" }

AttaqueEvent.OnClientEvent:Connect(function(resultat, typeAttaque, nomCible)
    if resultat == "Touche" then
        jouerSon(SON_ATTAQUE)
        auraTexte.TextColor3 = Color3.fromRGB(255, 150, 80)
        apparaitre(auraTexte, (NOMS_ATTAQUES[typeAttaque] or "") .. " sur " .. tostring(nomCible) .. " ! +3 ✨", 1.2)
        flasher(Color3.fromRGB(255, 150, 80), 0.3)
        fovBonus = math.max(fovBonus, 12)
        secousse(0.5, 0.25)
        ferveur = math.max(ferveur, 1)
    else
        local message = if typeAttaque == "Tacle" then "🤦 Tacle dans le vide..." else "💨 Balayette dans le vent..."
        auraTexte.TextColor3 = Color3.fromRGB(200, 200, 200)
        apparaitre(auraTexte, message, 1)
    end
end)

-- Quand c'est TOI qui te fais tacler
ChuteEvent.OnClientEvent:Connect(function(nomAttaquant, typeAttaque, duree)
    grosTexte.TextColor3 = Color3.fromRGB(255, 90, 90)
    apparaitre(grosTexte, "😵 " .. (NOMS_ATTAQUES[typeAttaque] or "") .. " de " .. tostring(nomAttaquant) .. " !", duree)
    jouerSon(SON_ATTAQUE, 1, 0.7)
    flasher(Color3.fromRGB(255, 60, 60), 0.4)
    secousse(1.2, 0.5)

    local personnage = joueur.Character
    local humanoid = personnage and personnage:FindFirstChildOfClass("Humanoid")
    local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
    if not humanoid then
        return
    end
    humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
    if racine then
        racine.AssemblyLinearVelocity += Vector3.new(0, 18, 0)
    end
    task.delay(duree, function()
        if humanoid.Parent then
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)
end)

-- ========================== ÉCRAN DE FIN ==========================
local function statDrole(data)
    if data.perso == "Obsession" then
        return "Diamants ramassés : 0. Respect. 🗿"
    elseif data.perso == "Ego" then
        return "Diamants ramassés : " .. data.diamants .. ". Poses pour la caméra : beaucoup trop. 💅"
    elseif data.perso == "Motivation" then
        return "Motivation restante : 0 %. Mais c'était beau au début. 🔥"
    elseif data.perso == "Discipline" then
        return "Excuses données : 0. Pluie ignorée. 🧱"
    elseif data.perso == "Talent" then
        return "Pauses par ennui : " .. (data.pauses or 0) .. ". Trop fort pour forcer. 🥱"
    end
    return ""
end

FinEvent.OnClientEvent:Connect(function(data)
    local couleur = COULEURS[data.perso] or BLANC
    finTitre.Text = "TU ES : " .. string.upper(data.perso)
    finTitre.TextColor3 = couleur
    contourFin.Color = couleur
    finPlace.Text = (if data.place == 1 then "🥇 1er" else "🏁 " .. data.place .. "e") .. " sur " .. data.total
    finDetails.Text = "⏱️ " .. data.temps .. "   ✨ Dépassements : " .. data.depassements
        .. "   🦵 Tacles : " .. (data.attaques or 0) .. "\n👑 Gagnant : " .. data.gagnant
    finDrole.Text = statDrole(data)
    ecranFin.Visible = true
    local echelle = ecranFin:FindFirstChildOfClass("UIScale") or nouveau("UIScale", { Parent = ecranFin })
    echelle.Scale = 0.6
    tween(echelle, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
    task.delay(7, function()
        ecranFin.Visible = false
    end)
end)
