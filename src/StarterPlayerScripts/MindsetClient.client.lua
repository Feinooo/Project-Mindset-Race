--[[
    🧠 MINDSET RACE — Script CLIENT (interface et effets)
    À mettre dans : StarterPlayer > StarterPlayerScripts  (type : LocalScript)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local joueur = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("MindsetRemotes")
local AnnonceEvent = remotes:WaitForChild("Annonce")
local EvenementEvent = remotes:WaitForChild("Evenement")
local AuraEvent = remotes:WaitForChild("Aura")
local FinEvent = remotes:WaitForChild("Fin")

local COULEURS = {
    Motivation = Color3.fromRGB(255, 150, 30),
    Ego = Color3.fromRGB(170, 80, 255),
    Discipline = Color3.fromRGB(60, 140, 255),
    Obsession = Color3.fromRGB(230, 40, 60),
}
local BLANC = Color3.new(1, 1, 1)
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

-- ========================== INTERFACE ==========================
local gui = nouveau("ScreenGui", {
    Name = "MindsetRaceGui",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    Parent = joueur:WaitForChild("PlayerGui"),
})

local statut = texte({
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 70),
    Size = UDim2.new(0.8, 0, 0, 38),
    Parent = gui,
})
local chrono = texte({
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 110),
    Size = UDim2.new(0.3, 0, 0, 28),
    TextColor3 = Color3.fromRGB(255, 230, 120),
    Parent = gui,
})
local banniere = texte({
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 150),
    Size = UDim2.new(0.85, 0, 0, 36),
    TextColor3 = Color3.fromRGB(150, 220, 255),
    Visible = false,
    Parent = gui,
})
local grosTexte = texte({
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.4),
    Size = UDim2.new(0.9, 0, 0, 70),
    TextTransparency = 1,
    TextStrokeTransparency = 1,
    Parent = gui,
})
local auraTexte = texte({
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.6),
    Size = UDim2.new(0.6, 0, 0, 60),
    TextColor3 = OR,
    TextTransparency = 1,
    TextStrokeTransparency = 1,
    Parent = gui,
})
local persoTexte = texte({
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 20, 1, -20),
    Size = UDim2.new(0, 280, 0, 34),
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "🧠 Monte sur un podium !",
    Parent = gui,
})
local rangTexte = texte({
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -20, 0.5, 0),
    Size = UDim2.new(0, 160, 0, 60),
    TextColor3 = OR,
    Visible = false,
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
    Parent = gui,
})
nouveau("UICorner", { CornerRadius = UDim.new(0, 18), Parent = ecranFin })
local contourFin = nouveau("UIStroke", { Thickness = 4, Color = OR, Parent = ecranFin })
local finTitre = texte({ Position = UDim2.new(0, 15, 0, 15), Size = UDim2.new(1, -30, 0, 70), Parent = ecranFin })
local finPlace = texte({ Position = UDim2.new(0, 15, 0, 95), Size = UDim2.new(1, -30, 0, 45), TextColor3 = OR, Parent = ecranFin })
local finDetails = texte({ Position = UDim2.new(0, 15, 0, 150), Size = UDim2.new(1, -30, 0, 60), Parent = ecranFin })
local finDrole = texte({
    Position = UDim2.new(0, 15, 0, 220),
    Size = UDim2.new(1, -30, 0, 60),
    TextColor3 = Color3.fromRGB(200, 200, 200),
    Parent = ecranFin,
})

-- ========================== OUTILS ==========================
local function apparaitre(label, message, duree)
    label.Text = message
    label.TextTransparency = 0
    label.TextStrokeTransparency = 0
    label:SetAttribute("Numero", (label:GetAttribute("Numero") or 0) + 1)
    local numero = label:GetAttribute("Numero")
    task.delay(duree, function()
        if label:GetAttribute("Numero") == numero then
            TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
        end
    end)
end

local function jouerSon(id, vitesse)
    if id and id ~= "" then
        local son = nouveau("Sound", { SoundId = id, Volume = 1, PlaybackSpeed = vitesse or 1, Parent = SoundService })
        son:Play()
        Debris:AddItem(son, 10)
    end
end

local function coupDeZoom()
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    local aller = TweenService:Create(camera, TweenInfo.new(0.15), { FieldOfView = 85 })
    aller:Play()
    aller.Completed:Wait()
    TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { FieldOfView = 70 }):Play()
end

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

-- ========================== ÉVÉNEMENTS ==========================
AnnonceEvent.OnClientEvent:Connect(function(message, duree)
    grosTexte.TextColor3 = BLANC
    apparaitre(grosTexte, message, duree or 1.5)
end)

AuraEvent.OnClientEvent:Connect(function(message)
    jouerSon(ReplicatedStorage:GetAttribute("IdMusiqueAura"))
    apparaitre(auraTexte, message, 1.2)
    task.spawn(coupDeZoom)
end)

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
    local connexion = RunService.RenderStepped:Connect(function()
        local camera = workspace.CurrentCamera
        if camera then
            nuage.Position = camera.CFrame.Position + Vector3.new(0, 30, 0)
        end
    end)
    task.delay(duree, function()
        connexion:Disconnect()
        nuage:Destroy()
    end)
end

local MESSAGES_EVENEMENTS = {
    Pluie = "🌧️ IL PLEUT ! Motivation perd toute sa motivation...",
    Telephone = "📱 DRING DRING ! Tout le monde regarde son téléphone (sauf Discipline et Obsession)",
    Public = "👏 LE PUBLIC APPLAUDIT ! L'Ego s'envole",
}

EvenementEvent.OnClientEvent:Connect(function(type, duree)
    banniere.Text = MESSAGES_EVENEMENTS[type] or type
    banniere.Visible = true
    if type == "Pluie" then
        pluie(duree)
    end
    task.delay(math.max(duree, 3), function()
        banniere.Visible = false
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
    end
    return ""
end

FinEvent.OnClientEvent:Connect(function(data)
    local couleur = COULEURS[data.perso] or BLANC
    finTitre.Text = "TU ES : " .. string.upper(data.perso)
    finTitre.TextColor3 = couleur
    contourFin.Color = couleur
    finPlace.Text = (if data.place == 1 then "🥇 1er" else "🏁 " .. data.place .. "e") .. " sur " .. data.total
    finDetails.Text = "⏱️ " .. data.temps .. "   ✨ Dépassements : " .. data.depassements .. "\n👑 Gagnant : " .. data.gagnant
    finDrole.Text = statDrole(data)
    ecranFin.Visible = true
    if data.place == 1 then
        jouerSon(ReplicatedStorage:GetAttribute("IdMusiqueAura"))
    end
    task.delay(7, function()
        ecranFin.Visible = false
    end)
end)
