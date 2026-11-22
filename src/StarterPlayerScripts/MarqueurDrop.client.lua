--[[
    🎵 MARQUEUR DE DROP — Script CLIENT (marche UNIQUEMENT dans Studio, les vrais joueurs ne le voient pas)
    À mettre dans : StarterPlayer > StarterPlayerScripts  (type : LocalScript, nom : MarqueurDrop)
    (il remplace l'ancien « TesteurBPM » : supprime celui-là dans Studio)

    Lance le jeu dans Studio (Play) et appuie sur B pour ouvrir l'outil.
    Tu écoutes la musique, et quand le DROP arrive tu appuies sur D : à ce moment-là du jeu, il y aura
    plein de cercles à cliquer (le moment dur).

      Espace   = lecture / pause
      D        = « le drop est ICI » = le moment DUR (plein de cercles à cliquer)
      M        = « la manche commence ICI » (sinon c'est réglé tout seul pour que le drop soit dedans)
      T        = tester : réécouter 3 secondes avant le drop
      A        = analyser la musique (elle passe en accéléré) → l'outil propose où est le drop
      S        = aller au drop proposé par l'analyse
      ← / →    = reculer / avancer de 5 secondes      ↑ / ↓ = avancer / reculer d'1 seconde
      N / P    = musique suivante / précédente
      L        = écrire toute la liste dans l'Output → copie-la et envoie-la à Claude
    Tu peux aussi cliquer n'importe où sur la barre de temps pour y aller.

    La barre montre le volume de la musique (plus c'est haut, plus c'est fort) : un drop,
    c'est souvent là où ça devient fort d'un coup. La zone dorée = ce qui sera joué pendant la manche.
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

local dossier = ReplicatedStorage:WaitForChild("TesteurMusiques", 30)
if not dossier then
    warn("[Marqueur de drop] Liste des musiques introuvable : recolle aussi le script MindsetServer.")
    return
end
local DUREE_MANCHE = dossier:GetAttribute("DureeManche") or 60

local musiques = dossier:GetChildren()
table.sort(musiques, function(a, b)
    return a.Name < b.Name
end)
if #musiques == 0 then
    warn("[Marqueur de drop] Aucune musique dans CONFIG.MUSIQUES.")
    return
end

local PAS = 0.25 -- précision de la courbe de volume (secondes)
local reglages = {}
for i, valeur in ipairs(musiques) do
    reglages[i] = {
        id = valeur.Value,
        nom = valeur:GetAttribute("Nom") or ("Musique " .. i),
        bpm = valeur:GetAttribute("Bpm") or 130,
        debut = valeur:GetAttribute("Debut") or 0,
        decalage = valeur:GetAttribute("Decalage") or 0,
        drop = valeur:GetAttribute("Drop"), -- le moment dur (seconde du son), ou nil
        marque = valeur:GetAttribute("Drop") ~= nil,
        volumes = {},      -- [case] = volume (0 à 1000)
        suggestion = nil,  -- seconde proposée par l'analyse
    }
end

local function arrondi(x)
    x = math.floor(x * 100 + 0.5) / 100
    if x == math.floor(x) then
        return tostring(math.floor(x))
    end
    local texte = string.format("%.2f", x):gsub("0$", "")
    return texte
end

local function formatTemps(t)
    return string.format("%d:%05.2f", math.floor(t / 60), t % 60)
end

local function ligne(i)
    local r = reglages[i]
    return string.format(
        '        { id = "%s", nom = "%s", bpm = %s, debut = %s, %sdecalage = %s },%s',
        r.id, r.nom, arrondi(r.bpm), arrondi(r.debut),
        if r.drop then "drop = " .. arrondi(r.drop) .. ", " else "",
        arrondi(r.decalage),
        if r.marque then "" else " -- drop pas encore marqué"
    )
end

local function toutAfficher()
    print("\n===== 🎵 MARQUEUR DE DROP : copie tout ce bloc et envoie-le à Claude =====")
    for i = 1, #reglages do
        print(ligne(i))
    end
    print("=========================================================================")
end

-- ========================== LE SON ==========================
local son = Instance.new("Sound")
son.Name = "MarqueurDrop_Musique"
son.Volume = 0.8
son.Parent = SoundService

local groupeMuet = Instance.new("SoundGroup") -- pour couper la musique du jeu pendant qu'on écoute
groupeMuet.Name = "MarqueurDrop_Muet"
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

local OR = Color3.fromRGB(255, 210, 70)
local CYAN = Color3.fromRGB(90, 210, 255)
local LARGEUR = 640

local gui = nouveau("ScreenGui", {
    Name = "MarqueurDrop",
    ResetOnSpawn = false,
    DisplayOrder = 100,
    Enabled = false,
    Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
})
local panneau = nouveau("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 20),
    Size = UDim2.fromOffset(LARGEUR, 418),
    BackgroundColor3 = Color3.fromRGB(14, 14, 20),
    BackgroundTransparency = 0.05,
    Parent = gui,
})
nouveau("UICorner", { CornerRadius = UDim.new(0, 14), Parent = panneau })
nouveau("UIStroke", { Color = OR, Transparency = 0.4, Thickness = 1.5, Parent = panneau })

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

texte(10, 18, 13, Color3.fromRGB(150, 150, 165), Enum.Font.GothamBold).Text =
    "MARQUEUR DE DROP  ·  Studio uniquement  ·  B pour fermer"
local nomLabel = texte(30, 26, 20, Color3.new(1, 1, 1), Enum.Font.GothamBlack)
local tempsLabel = texte(58, 20, 15, Color3.fromRGB(200, 200, 215), Enum.Font.GothamBold)

-- La barre de temps : courbe de volume, zone de la manche, drop, tête de lecture
local LARGEUR_BARRE = LARGEUR - 32
local barre = nouveau("TextButton", {
    Position = UDim2.new(0, 16, 0, 86),
    Size = UDim2.fromOffset(LARGEUR_BARRE, 96),
    BackgroundColor3 = Color3.fromRGB(26, 26, 36),
    AutoButtonColor = false,
    Text = "",
    ClipsDescendants = true,
    Parent = panneau,
})
nouveau("UICorner", { CornerRadius = UDim.new(0, 8), Parent = barre })
local zoneManche = nouveau("Frame", {
    Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = OR,
    BackgroundTransparency = 0.82,
    BorderSizePixel = 0,
    ZIndex = 2,
    Parent = barre,
})
local dossierBarres = nouveau("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = barre })
local function trait(couleur, epaisseur, zIndex)
    return nouveau("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.new(0, epaisseur, 1, 0),
        BackgroundColor3 = couleur,
        BorderSizePixel = 0,
        ZIndex = zIndex,
        Parent = barre,
    })
end
local traitSuggestion = trait(CYAN, 2, 4)
local traitDrop = trait(OR, 3, 5)
nouveau("TextLabel", {
    Position = UDim2.new(0, 4, 0, 2),
    Size = UDim2.fromOffset(60, 14),
    BackgroundTransparency = 1,
    Text = "DROP",
    TextColor3 = OR,
    TextSize = 12,
    Font = Enum.Font.GothamBlack,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 5,
    Parent = traitDrop,
})
local teteLecture = trait(Color3.new(1, 1, 1), 2, 6)

local dropLabel = texte(190, 20, 16, OR, Enum.Font.GothamBold)
local suggestionLabel = texte(212, 20, 14, CYAN, Enum.Font.GothamBold)
local alerteLabel = texte(234, 20, 14, Color3.fromRGB(255, 150, 70), Enum.Font.GothamBold)

local function bouton(x, y, largeur, etiquette, couleur)
    local b = nouveau("TextButton", {
        Position = UDim2.new(0, x, 0, y),
        Size = UDim2.fromOffset(largeur, 34),
        BackgroundColor3 = couleur or Color3.fromRGB(45, 45, 58),
        TextColor3 = if couleur then Color3.new(0, 0, 0) else Color3.new(1, 1, 1),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        Text = etiquette,
        AutoButtonColor = true,
        Parent = panneau,
    })
    nouveau("UICorner", { CornerRadius = UDim.new(0, 8), Parent = b })
    return b
end
local boutonPrec = bouton(16, 262, 44, "◀")
local boutonLecture = bouton(66, 262, 70, "⏯")
local boutonSuiv = bouton(142, 262, 44, "▶")
local boutonDrop = bouton(196, 262, 190, "LE DROP EST ICI (D)", OR)
local boutonTest = bouton(392, 262, 110, "TESTER (T)")
local boutonAnalyse = bouton(508, 262, 116, "ANALYSER (A)", CYAN)
local boutonDebut = bouton(16, 302, 200, "LA MANCHE COMMENCE ICI (M)")
local boutonListe = bouton(222, 302, 402, "ÉCRIRE LA LISTE DANS L'OUTPUT (L)  →  à envoyer à Claude")

local aide = texte(344, 64, 13, Color3.fromRGB(150, 150, 165))
aide.Text = "Espace = lecture / pause   ·   D = le drop (moment dur) est ici   ·   M = la manche commence ici   ·   T = réécouter le drop\n"
    .. "← / → = -5 s / +5 s   ·   ↑ / ↓ = +1 s / -1 s   ·   N / P = musique suivante / précédente\n"
    .. "A = analyse (accéléré) puis S = aller au drop proposé   ·   clique sur la barre pour te déplacer"

-- ========================== LOGIQUE ==========================
local index = 1
local chargeDepuis = os.clock()
local analyse = nil -- { index } pendant une analyse
local barresAffichees = {} -- [case] = Frame
local derniereDuree = 0

local function viderBarres()
    for _, b in pairs(barresAffichees) do
        b:Destroy()
    end
    barresAffichees = {}
end

local function charger(i)
    index = (i - 1) % #musiques + 1
    analyse = nil
    son.PlaybackSpeed = 1
    son:Stop()
    son.SoundId = reglages[index].id
    son.TimePosition = 0
    chargeDepuis = os.clock()
    viderBarres()
    derniereDuree = 0
    son:Play()
end

local function aller(t)
    local fin = if son.TimeLength > 0 then son.TimeLength - 0.05 else math.huge
    son.TimePosition = math.clamp(t, 0, fin)
end

local function lecturePause()
    if analyse then
        return
    end
    if son.IsPlaying then
        son:Pause()
    elseif son.IsPaused then
        son:Resume()
    else
        son:Play()
    end
end

local function marquerDrop()
    if analyse then
        return
    end
    local r = reglages[index]
    r.drop = math.max(0, math.floor(son.TimePosition * 100 + 0.5) / 100)
    r.marque = true
    print(string.format("[Marqueur de drop] %s : drop (moment dur) à %s s", r.nom, arrondi(r.drop)))
    -- le drop doit tomber PENDANT la manche (avec le temps de jouer le moment dur) : sinon on décale le début
    if r.drop < r.debut + 3 or r.drop > r.debut + DUREE_MANCHE - 18 then
        r.debut = math.max(0, math.floor(r.drop - 20 + 0.5))
        print(string.format("[Marqueur de drop] %s : la manche commencera à %s s pour que le drop soit dedans", r.nom, arrondi(r.debut)))
    end
end

-- la manche commence ici (si tu veux choisir toi-même)
local function marquerDebut()
    if analyse then
        return
    end
    local r = reglages[index]
    r.debut = math.max(0, math.floor(son.TimePosition * 100 + 0.5) / 100)
    print(string.format("[Marqueur de drop] %s : la manche commence à %s s", r.nom, arrondi(r.debut)))
end

local function tester()
    if analyse then
        return
    end
    local r = reglages[index]
    aller((r.drop or r.debut) - 3)
    if not son.IsPlaying then
        if son.IsPaused then
            son:Resume()
        else
            son:Play()
        end
    end
end

-- Le drop probable = l'endroit où le volume monte le plus fort d'un coup
local function calculerSuggestion(r)
    local n = 0
    for case in pairs(r.volumes) do
        n = math.max(n, case)
    end
    if n < 40 then
        return
    end
    local lisse = {}
    for case = 0, n do
        local somme, nb = 0, 0
        for j = case - 2, case + 1 do -- moyenne sur 1 seconde
            if r.volumes[j] then
                somme += r.volumes[j]
                nb += 1
            end
        end
        lisse[case] = if nb > 0 then somme / nb else 0
    end
    local FENETRE = math.floor(3 / PAS) -- on compare 3 s avant / 3 s après
    local meilleur, meilleureCase = -math.huge, nil
    for case = FENETRE, n - FENETRE do
        local avant, apres = 0, 0
        for j = 1, FENETRE do
            avant += lisse[case - j]
            apres += lisse[case + j - 1]
        end
        local score = (apres - avant) / FENETRE
        if case * PAS + DUREE_MANCHE > (n + 1) * PAS then
            score *= 0.7 -- un drop trop tard ne laisse pas une manche entière : moins probable
        end
        if score > meilleur then
            meilleur, meilleureCase = score, case
        end
    end
    if meilleureCase then
        r.suggestion = meilleureCase * PAS
    end
end

local function lancerAnalyse()
    if analyse then
        return
    end
    if son.TimeLength <= 0 then
        warn("[Marqueur de drop] La musique n'est pas encore chargée.")
        return
    end
    analyse = { index = index }
    reglages[index].volumes = {}
    viderBarres()
    son.PlaybackSpeed = 4
    son.TimePosition = 0
    if son.IsPaused then
        son:Resume()
    else
        son:Play()
    end
end

local function finirAnalyse()
    local r = reglages[index]
    analyse = nil
    son.PlaybackSpeed = 1
    calculerSuggestion(r)
    if r.suggestion then
        print(string.format("[Marqueur de drop] %s : drop probable vers %s s (S pour y aller, puis D pour valider)", r.nom, arrondi(r.suggestion)))
        aller(math.max(0, r.suggestion - 3))
        son:Play()
    else
        son:Pause()
    end
end

son.Ended:Connect(function()
    if analyse then
        finirAnalyse()
    end
end)

local touches = {
    [Enum.KeyCode.Space] = lecturePause,
    [Enum.KeyCode.D] = marquerDrop,
    [Enum.KeyCode.M] = marquerDebut,
    [Enum.KeyCode.T] = tester,
    [Enum.KeyCode.A] = lancerAnalyse,
    [Enum.KeyCode.S] = function()
        local r = reglages[index]
        if r.suggestion and not analyse then
            aller(r.suggestion)
        end
    end,
    [Enum.KeyCode.Left] = function()
        aller(son.TimePosition - 5)
    end,
    [Enum.KeyCode.Right] = function()
        aller(son.TimePosition + 5)
    end,
    [Enum.KeyCode.Up] = function()
        aller(son.TimePosition + 1)
    end,
    [Enum.KeyCode.Down] = function()
        aller(son.TimePosition - 1)
    end,
    [Enum.KeyCode.N] = function()
        charger(index + 1)
    end,
    [Enum.KeyCode.P] = function()
        charger(index - 1)
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
    return Enum.ContextActionResult.Sink -- le perso ne bouge pas pendant qu'on écoute
end

boutonPrec.Activated:Connect(function()
    charger(index - 1)
end)
boutonSuiv.Activated:Connect(function()
    charger(index + 1)
end)
boutonLecture.Activated:Connect(lecturePause)
boutonDrop.Activated:Connect(marquerDrop)
boutonDebut.Activated:Connect(marquerDebut)
boutonTest.Activated:Connect(tester)
boutonAnalyse.Activated:Connect(lancerAnalyse)
boutonListe.Activated:Connect(toutAfficher)

-- cliquer sur la barre = aller à cet endroit
barre.InputBegan:Connect(function(input)
    if analyse or son.TimeLength <= 0 then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local x = (input.Position.X - barre.AbsolutePosition.X) / barre.AbsoluteSize.X
        aller(math.clamp(x, 0, 1) * son.TimeLength)
    end
end)

-- Ouvrir / fermer avec B
local ouvert = false
local premiereOuverture = true
local groupeAvant = nil
local function basculer()
    ouvert = not ouvert
    gui.Enabled = ouvert
    local musiqueJeu = SoundService:FindFirstChild("MindsetMusique")
    if ouvert then
        if musiqueJeu then
            groupeAvant = musiqueJeu.SoundGroup
            musiqueJeu.SoundGroup = groupeMuet
        end
        ContextActionService:BindActionAtPriority("MarqueurDrop", action, false, 3000, table.unpack(listeTouches))
        if premiereOuverture then
            premiereOuverture = false
            charger(index)
        elseif son.IsPaused then
            son:Resume()
        end
    else
        if musiqueJeu then
            musiqueJeu.SoundGroup = groupeAvant -- on remet le groupe du jeu (volume des paramètres)
        end
        ContextActionService:UnbindAction("MarqueurDrop")
        if analyse then
            analyse = nil
            son.PlaybackSpeed = 1
        end
        son:Pause()
        toutAfficher()
    end
end

UserInputService.InputBegan:Connect(function(input, dejaGere)
    if not dejaGere and input.KeyCode == Enum.KeyCode.B then
        basculer()
    end
end)

-- ========================== MISE À JOUR DE L'ÉCRAN ==========================
local function position(t, duree)
    return UDim2.new(math.clamp(t / duree, 0, 1), 0, 0, 0)
end

RunService.RenderStepped:Connect(function()
    if not ouvert then
        return
    end
    local r = reglages[index]
    local duree = son.TimeLength
    nomLabel.Text = string.format("%d/%d  ·  %s", index, #musiques, r.nom)

    if analyse then
        tempsLabel.Text = string.format("ANALYSE EN COURS (en accéléré)...  %d %%", if duree > 0 then math.floor(son.TimePosition / duree * 100) else 0)
    else
        tempsLabel.Text = string.format("%s / %s   ·   %s", formatTemps(son.TimePosition), formatTemps(duree), if son.IsPlaying then "▶ lecture" else "⏸ pause")
    end

    -- on enregistre le volume pendant que ça joue (c'est ce qui dessine la courbe)
    if son.IsPlaying and duree > 0 then
        local case = math.floor(son.TimePosition / PAS)
        local volume = son.PlaybackLoudness
        if volume > (r.volumes[case] or 0) then
            r.volumes[case] = volume
        end
    end

    if duree > 0 then
        if duree ~= derniereDuree then
            derniereDuree = duree
            viderBarres()
        end
        local largeurCase = math.max(1, LARGEUR_BARRE * PAS / duree)
        for case, volume in pairs(r.volumes) do
            local b = barresAffichees[case]
            if not b then
                b = nouveau("Frame", {
                    AnchorPoint = Vector2.new(0, 1),
                    Position = UDim2.new(case * PAS / duree, 0, 1, 0),
                    BackgroundColor3 = Color3.fromRGB(150, 150, 190),
                    BorderSizePixel = 0,
                    ZIndex = 3,
                    Parent = dossierBarres,
                })
                barresAffichees[case] = b
            end
            b.Size = UDim2.new(0, largeurCase, math.clamp(volume / 600, 0.02, 1), 0)
        end
        teteLecture.Position = position(son.TimePosition, duree)
        traitDrop.Visible = r.drop ~= nil
        if r.drop then
            traitDrop.Position = position(r.drop, duree)
        end
        zoneManche.Position = position(r.debut, duree)
        zoneManche.Size = UDim2.fromScale(math.clamp(DUREE_MANCHE / duree, 0, 1 - math.clamp(r.debut / duree, 0, 1)), 1)
        traitSuggestion.Visible = r.suggestion ~= nil
        if r.suggestion then
            traitSuggestion.Position = position(r.suggestion, duree)
        end
    end

    dropLabel.Text = string.format(
        "Drop : %s   ·   la manche (zone dorée) jouera de %s à %s",
        if r.drop then formatTemps(r.drop) else "pas encore marqué",
        formatTemps(r.debut), formatTemps(r.debut + DUREE_MANCHE)
    )
    suggestionLabel.Text = if r.suggestion
        then "Drop probable d'après l'analyse : " .. formatTemps(r.suggestion) .. "   →   S pour y aller, D pour valider"
        else "Pas encore d'analyse : appuie sur A (la musique passe en accéléré quelques secondes)"

    if duree == 0 and os.clock() - chargeDepuis > 6 then
        alerteLabel.Text = "⚠ Ce son ne se charge pas (privé, supprimé ou pas autorisé dans ce jeu ?)"
    elseif duree > 0 and r.debut + DUREE_MANCHE > duree then
        alerteLabel.Text = string.format("⚠ La musique s'arrête avant la fin de la manche (%d s) : appuie sur M plus tôt", DUREE_MANCHE)
    elseif r.drop and (r.drop < r.debut or r.drop > r.debut + DUREE_MANCHE - 2) then
        alerteLabel.Text = "⚠ Le drop est en dehors de la zone dorée : il ne sera pas joué"
    else
        alerteLabel.Text = ""
    end
end)

print("[Marqueur de drop] Prêt : appuie sur B pour l'ouvrir.")
