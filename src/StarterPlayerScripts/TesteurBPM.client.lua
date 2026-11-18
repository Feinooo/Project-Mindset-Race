--[[
    🎵 TESTEUR BPM — Script CLIENT (marche UNIQUEMENT dans Studio, les vrais joueurs ne le voient pas)
    À mettre dans : StarterPlayer > StarterPlayerScripts  (type : LocalScript, nom : TesteurBPM)

    Lance le jeu dans Studio (Play) et appuie sur B pour ouvrir le testeur.

      Espace   = tape en rythme sur les temps (au moins 20-30 secondes : plus c'est long, plus c'est précis)
      D        = « le drop est ici » → la manche commencera à ce moment du son
      ← / →    = reculer / avancer de 5 secondes
      N / P    = musique suivante / précédente
      R        = effacer les taps
      C        = métronome sonore on/off (pour vérifier que le BPM tombe juste)
      L        = écrire toute la liste dans l'Output → copie-la et envoie-la à Claude

    La pastille « JEU » clignote sur les temps calculés, la pastille « TOI » à chaque tap :
    si elles clignotent ensemble (et avec la musique), c'est bon !
]]

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local dossier = ReplicatedStorage:WaitForChild("TesteurMusiques", 30)
if not dossier then
    warn("[Testeur BPM] Liste des musiques introuvable : recolle aussi le script MindsetServer.")
    return
end
local DUREE_MANCHE = dossier:GetAttribute("DureeManche") or 60

-- ========================== LES MUSIQUES ==========================
local musiques = dossier:GetChildren()
table.sort(musiques, function(a, b)
    return a.Name < b.Name
end)
if #musiques == 0 then
    warn("[Testeur BPM] Aucune musique dans CONFIG.MUSIQUES.")
    return
end

-- Pour chaque musique : bpm, debut, et « ancre » = un moment du son qui tombe pile sur un temps.
local reglages = {}
for i, valeur in ipairs(musiques) do
    local debut = valeur:GetAttribute("Debut") or 0
    reglages[i] = {
        id = valeur.Value,
        nom = valeur:GetAttribute("Nom") or ("Musique " .. i),
        bpm = valeur:GetAttribute("Bpm") or 130,
        debut = debut,
        ancre = debut + (valeur:GetAttribute("Decalage") or 0),
        teste = false,
        mesure = nil, -- { brut, marge, nb }
    }
end

local function decalageDe(r)
    local intervalle = 60 / r.bpm
    local d = (r.ancre - r.debut) % intervalle
    if d >= intervalle / 2 then
        d -= intervalle
    end
    return d
end

local function arrondi(x)
    x = math.floor(x * 100 + 0.5) / 100
    if x == math.floor(x) then
        return tostring(math.floor(x))
    end
    local texte = string.format("%.2f", x):gsub("0$", "")
    return texte
end

local function ligne(i)
    local r = reglages[i]
    return string.format(
        '        { id = "%s", nom = "%s", bpm = %s, debut = %s, decalage = %s },%s',
        r.id, r.nom, arrondi(r.bpm), arrondi(r.debut), arrondi(decalageDe(r)),
        if r.teste then "" else " -- pas encore testée"
    )
end

local function toutAfficher()
    print("\n===== 🎵 TESTEUR BPM : copie tout ce bloc et envoie-le à Claude =====")
    for i = 1, #reglages do
        print(ligne(i))
    end
    print("=====================================================================")
end

-- ========================== LES SONS ==========================
local son = Instance.new("Sound")
son.Name = "TesteurBPM_Musique"
son.Volume = 0.8
son.Parent = SoundService

local tic = Instance.new("Sound")
tic.Name = "TesteurBPM_Tic"
tic.SoundId = "rbxasset://sounds/electronicpingshort.wav"
tic.Volume = 0.6
tic.Parent = SoundService

-- Pour couper la musique du jeu pendant qu'on teste
local groupeMuet = Instance.new("SoundGroup")
groupeMuet.Name = "TesteurBPM_Muet"
groupeMuet.Volume = 0
groupeMuet.Parent = SoundService

-- ========================== L'ÉCRAN ==========================
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

local gui = nouveau("ScreenGui", {
    Name = "TesteurBPM",
    ResetOnSpawn = false,
    DisplayOrder = 100,
    Enabled = false,
    Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
})

local panneau = nouveau("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 20),
    Size = UDim2.fromOffset(520, 330),
    BackgroundColor3 = Color3.fromRGB(15, 15, 20),
    BackgroundTransparency = 0.1,
    Parent = gui,
})
nouveau("UICorner", { CornerRadius = UDim.new(0, 12), Parent = panneau })
nouveau("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.7, Thickness = 1.5, Parent = panneau })

local function texte(y, hauteur, taille, couleur, police)
    return nouveau("TextLabel", {
        Position = UDim2.new(0, 16, 0, y),
        Size = UDim2.new(1, -32, 0, hauteur),
        BackgroundTransparency = 1,
        TextColor3 = couleur or Color3.new(1, 1, 1),
        TextSize = taille,
        Font = police or Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        Text = "",
        Parent = panneau,
    })
end

local titre = texte(10, 20, 14, Color3.fromRGB(150, 150, 160), Enum.Font.GothamBold)
titre.Text = "🎵 TESTEUR BPM  ·  Studio uniquement  ·  B pour fermer"

local nomLabel = texte(34, 26, 20, Color3.new(1, 1, 1), Enum.Font.GothamBlack)
local tempsLabel = texte(62, 20, 15, Color3.fromRGB(200, 200, 210))
local tapLabel = texte(88, 20, 15, Color3.fromRGB(200, 200, 210))
local resultatLabel = texte(112, 40, 16, Color3.fromRGB(120, 255, 160), Enum.Font.GothamBold)
local alerteLabel = texte(154, 20, 14, Color3.fromRGB(255, 170, 60), Enum.Font.GothamBold)

local aide = texte(236, 86, 13, Color3.fromRGB(150, 150, 160))
aide.Text = "Espace = taper en rythme (20-30 s)   ·   D = le drop est ici   ·   ← / → = -5 s / +5 s\n"
    .. "N / P = musique suivante / précédente   ·   R = effacer les taps   ·   C = métronome\n"
    .. "L = écrire toute la liste dans l'Output (à envoyer à Claude)"

-- Les deux pastilles : JEU (temps calculés) et TOI (tes taps)
local function pastille(x, etiquette, couleur)
    local rond = nouveau("Frame", {
        Position = UDim2.new(0, x, 0, 182),
        Size = UDim2.fromOffset(40, 40),
        BackgroundColor3 = couleur,
        BackgroundTransparency = 0.85,
        Parent = panneau,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rond })
    nouveau("TextLabel", {
        Position = UDim2.new(0, x + 48, 0, 182),
        Size = UDim2.fromOffset(60, 40),
        BackgroundTransparency = 1,
        TextColor3 = couleur,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = etiquette,
        Parent = panneau,
    })
    return rond
end
local pastilleJeu = pastille(16, "JEU", Color3.fromRGB(255, 220, 80))
local pastilleToi = pastille(130, "TOI", Color3.fromRGB(80, 200, 255))

local function flash(rond)
    rond.BackgroundTransparency = 0
    TweenService:Create(rond, TweenInfo.new(0.18), { BackgroundTransparency = 0.85 }):Play()
end

-- Boutons
local function bouton(x, largeur, etiquette)
    local b = nouveau("TextButton", {
        Position = UDim2.new(0, x, 0, 186),
        Size = UDim2.fromOffset(largeur, 32),
        BackgroundColor3 = Color3.fromRGB(45, 45, 55),
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        Text = etiquette,
        AutoButtonColor = true,
        Parent = panneau,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 8), Parent = b })
    return b
end
local boutonPrec = bouton(250, 40, "◀")
local boutonLecture = bouton(296, 70, "⏯")
local boutonSuiv = bouton(372, 40, "▶")
local boutonListe = bouton(418, 86, "📋 Output")

-- ========================== LOGIQUE ==========================
local index = 1
local taps = {}
local chargeDepuis = os.clock()
local metronome = false
local dernierTemps = nil

local function formatTemps(t)
    return string.format("%d:%04.1f", math.floor(t / 60), t % 60)
end

local function charger(i)
    index = (i - 1) % #musiques + 1
    taps = {}
    dernierTemps = nil
    son:Stop()
    son.SoundId = reglages[index].id
    son.TimePosition = 0
    chargeDepuis = os.clock()
    son:Play()
end

-- Calcule le BPM à partir des taps (droite de régression : plus on tape longtemps, plus c'est précis)
local function calculer()
    local n = #taps
    if n < 4 then
        return
    end
    local mx, my = (n - 1) / 2, 0
    for _, t in ipairs(taps) do
        my += t
    end
    my /= n
    local sxy, sxx = 0, 0
    for k, t in ipairs(taps) do
        local dx = (k - 1) - mx
        sxy += dx * (t - my)
        sxx += dx * dx
    end
    local pente = sxy / sxx -- secondes par temps
    if pente <= 0 then
        return
    end
    local residus = 0
    for k, t in ipairs(taps) do
        local attendu = my + pente * ((k - 1) - mx)
        residus += (t - attendu) ^ 2
    end
    local erreurPente = math.sqrt(residus / math.max(n - 2, 1) / sxx)
    local brut = 60 / pente
    local marge = 60 / (pente * pente) * erreurPente

    local r = reglages[index]
    local entier = math.floor(brut + 0.5)
    if math.abs(brut - entier) <= 2 * marge + 0.15 then
        r.bpm = entier -- la plupart des musiques ont un BPM entier
    else
        r.bpm = math.floor(brut * 10 + 0.5) / 10
    end
    r.mesure = { brut = brut, marge = marge, nb = n }
    r.teste = true

    -- Où tombent les temps (moyenne « circulaire » des taps)
    local intervalle = 60 / r.bpm
    local sx, sy = 0, 0
    for _, t in ipairs(taps) do
        local angle = 2 * math.pi * (t % intervalle) / intervalle
        sx += math.cos(angle)
        sy += math.sin(angle)
    end
    r.ancre = (math.atan2(sy, sx) / (2 * math.pi)) % 1 * intervalle
end

local function taper()
    if not son.IsPlaying then
        return
    end
    flash(pastilleToi)
    local t = son.TimePosition
    local dernier = taps[#taps]
    if dernier and (t - dernier > 2 or t < dernier) then
        taps = {} -- trop longue pause ou retour en arrière : on recommence la série
    end
    table.insert(taps, t)
    calculer()
end

local function marquerDrop()
    local r = reglages[index]
    local t = son.TimePosition
    -- on cale le début pile sur le temps le plus proche
    local intervalle = 60 / r.bpm
    local debut = r.ancre + math.floor((t - r.ancre) / intervalle + 0.5) * intervalle
    r.debut = math.max(0, math.floor(debut * 100 + 0.5) / 100)
    r.teste = true
    print(string.format("[Testeur BPM] %s : drop à %s s", r.nom, arrondi(r.debut)))
end

local function avancer(secondes)
    local fin = if son.TimeLength > 0 then son.TimeLength - 0.1 else math.huge
    son.TimePosition = math.clamp(son.TimePosition + secondes, 0, fin)
end

local function lecturePause()
    if son.IsPlaying then
        son:Pause()
    elseif son.IsPaused then
        son:Resume()
    else
        son:Play()
    end
end

local touches = {
    [Enum.KeyCode.Space] = taper,
    [Enum.KeyCode.D] = marquerDrop,
    [Enum.KeyCode.Left] = function()
        avancer(-5)
    end,
    [Enum.KeyCode.Right] = function()
        avancer(5)
    end,
    [Enum.KeyCode.N] = function()
        charger(index + 1)
    end,
    [Enum.KeyCode.P] = function()
        charger(index - 1)
    end,
    [Enum.KeyCode.R] = function()
        taps = {}
    end,
    [Enum.KeyCode.C] = function()
        metronome = not metronome
    end,
    [Enum.KeyCode.L] = toutAfficher,
}
local listeTouches = {}
for touche in pairs(touches) do
    table.insert(listeTouches, touche)
end

local function action(_, etat, input)
    if etat == Enum.UserInputState.Begin then
        local fonction = touches[input.KeyCode]
        if fonction then
            fonction()
        end
    end
    return Enum.ContextActionResult.Sink -- le perso ne saute pas / ne bouge pas pendant le test
end

boutonPrec.Activated:Connect(function()
    charger(index - 1)
end)
boutonSuiv.Activated:Connect(function()
    charger(index + 1)
end)
boutonLecture.Activated:Connect(lecturePause)
boutonListe.Activated:Connect(toutAfficher)

-- Ouvrir / fermer avec B
local ouvert = false
local premiereOuverture = true
local function basculer()
    ouvert = not ouvert
    gui.Enabled = ouvert
    local musiqueJeu = SoundService:FindFirstChild("MindsetMusique")
    if ouvert then
        if musiqueJeu then
            musiqueJeu.SoundGroup = groupeMuet
        end
        ContextActionService:BindActionAtPriority("TesteurBPM", action, false, 3000, table.unpack(listeTouches))
        if premiereOuverture then
            premiereOuverture = false
            charger(index)
        elseif son.IsPaused then
            son:Resume()
        end
    else
        if musiqueJeu then
            musiqueJeu.SoundGroup = nil
        end
        ContextActionService:UnbindAction("TesteurBPM")
        son:Pause()
        toutAfficher()
    end
end

UserInputService.InputBegan:Connect(function(input, dejaGere)
    if not dejaGere and input.KeyCode == Enum.KeyCode.B then
        basculer()
    end
end)

-- Mise à jour de l'écran + pastille JEU + métronome
RunService.RenderStepped:Connect(function()
    if not ouvert then
        return
    end
    local r = reglages[index]
    nomLabel.Text = string.format("%d/%d  ·  %s", index, #musiques, r.nom)

    local duree = son.TimeLength
    tempsLabel.Text = string.format(
        "%s / %s   %s   ·   métronome %s",
        formatTemps(son.TimePosition), formatTemps(duree),
        if son.IsPlaying then "▶ lecture" else "⏸ pause",
        if metronome then "ON" else "off"
    )

    if r.mesure then
        tapLabel.Text = string.format(
            "Taps : %d   ·   BPM mesuré : %.1f (± %.1f)%s",
            #taps, r.mesure.brut, r.mesure.marge,
            if r.mesure.marge > 0.5 then "  → continue de taper !" else "  ✓ précis"
        )
    else
        tapLabel.Text = string.format("Taps : %d   ·   tape Espace sur chaque temps (au moins 4)", #taps)
    end

    resultatLabel.Text = string.format(
        "À mettre : bpm = %s, debut = %s, decalage = %s%s",
        arrondi(r.bpm), arrondi(r.debut), arrondi(decalageDe(r)),
        if r.teste then "" else "\n(pas encore testée : valeurs actuelles du jeu)"
    )

    if duree == 0 and os.clock() - chargeDepuis > 6 then
        alerteLabel.Text = "⚠ Ce son ne se charge pas (privé, supprimé ou pas autorisé dans ce jeu ?)"
    elseif duree > 0 and r.debut + DUREE_MANCHE > duree then
        alerteLabel.Text = string.format(
            "⚠ La musique s'arrête avant la fin de la manche (%d s) : mets un drop plus tôt",
            DUREE_MANCHE
        )
    else
        alerteLabel.Text = ""
    end

    -- un nouveau temps vient de passer ?
    if son.IsPlaying then
        local numero = math.floor((son.TimePosition - r.ancre) / (60 / r.bpm))
        if dernierTemps and numero ~= dernierTemps then
            flash(pastilleJeu)
            if metronome then
                tic:Play()
            end
        end
        dernierTemps = numero
    else
        dernierTemps = nil
    end
end)

print("[Testeur BPM] Prêt : appuie sur B pour l'ouvrir.")
