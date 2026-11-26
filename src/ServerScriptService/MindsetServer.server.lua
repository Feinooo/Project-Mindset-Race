--[[
    🎵 STEAL A PHONK — Script SERVEUR
    À mettre dans : ServerScriptService  (type : Script, nom : MindsetServer)

    Le principe :
      - Chaque joueur a SA BASE, avec 10 emplacements.
      - Au milieu de la map, un TAPIS ROULANT fait défiler des « PHONKS » (des persos style phonk),
        chacun avec sa rareté : COMMON → RARE → EPIC → LEGENDARY → MYTHIC → SECRET.
      - Tu ACHÈTES ceux qui passent : ils vont dans ta base et te RAPPORTENT de l'argent chaque seconde.
      - L'argent s'accumule sur chaque emplacement : marche sur le carré « COLLECT » de ta base pour tout récupérer.
      - Tu peux revendre un Phonk (la moitié de son prix) pour faire de la place.
      - (bientôt : VOLER les Phonks des autres, et le BOUCLIER pour protéger ta base)
    Ce script construit la map, gère le tapis, les achats, l'argent, la sauvegarde et les classements.
    (les anciens jeux sont gardés dans les tags git v1-course ... v5-aura-simulator)
]]

-- ===================== RÉGLAGES (tu peux les modifier) =====================
local CONFIG = {
    ARGENT_DEPART = 50,       -- l'argent d'un nouveau joueur
    EMPLACEMENTS = 10,        -- emplacements par base
    VITESSE_TAPIS = 7,        -- vitesse du tapis (studs par seconde)
    INTERVALLE_TAPIS = 2.2,   -- un nouveau Phonk sur le tapis toutes les ... secondes
    REVENTE = 0.5,            -- on revend un Phonk à 50 % de son prix
    VITESSE = 22,             -- vitesse de marche des joueurs
    ARGENT_CADEAU_STUDIO = 0, -- en Studio seulement : de l'argent pour tester (0 = rien)

    -- 🎵 MUSIQUES : jouées en fond (une au hasard, puis la suivante). id = "" : ignorée.
    -- ⚠️ Prends des sons phonk avec licence dans la Toolbox (Audio), pas des MP3 d'artistes (Roblox les refuse).
    MUSIQUES = {
        { id = "rbxassetid://74842327948915", nom = "BUFÓN!" },
        { id = "rbxassetid://134372266822247", nom = "MONTAGE SENNTANA" },
        { id = "rbxassetid://117822777228038", nom = "ME VS ME" },
        { id = "rbxassetid://84227603413943", nom = "NO ERA AMOR" },
        { id = "rbxassetid://80140071567818", nom = "EMPIRE" },
        { id = "rbxassetid://135464211325455", nom = "TIKI TIKI" },
        { id = "rbxassetid://127965945833744", nom = "Your Next Opponent Is You" },
    },
}

-- 💎 LES RARETÉS : poids = chance d'apparaître sur le tapis (plus c'est grand, plus c'est fréquent)
local RARETES = {
    { cle = "Common", nom = "COMMON", couleur = Color3.fromRGB(190, 190, 200), poids = 58 },
    { cle = "Rare", nom = "RARE", couleur = Color3.fromRGB(70, 150, 255), poids = 25 },
    { cle = "Epic", nom = "EPIC", couleur = Color3.fromRGB(175, 80, 255), poids = 11 },
    { cle = "Legendary", nom = "LEGENDARY", couleur = Color3.fromRGB(255, 200, 50), poids = 4.5 },
    { cle = "Mythic", nom = "MYTHIC", couleur = Color3.fromRGB(255, 60, 90), poids = 1.3 },
    { cle = "Secret", nom = "SECRET", couleur = Color3.fromRGB(255, 255, 255), poids = 0.2 },
}

-- 🎵 LES PHONKS : prix = ce qu'il coûte · revenu = argent par seconde dans ta base
--   corps = "bloc" ou "cylindre" · tete = "crane", "masque" ou "cube" · acc = les accessoires
--   (cowbell, casque, cornes, couronne, chaine, halo, flammes, aura) · taille = sa taille (1 = normal)
local PHONKS = {
    { cle = "LilCowbell", nom = "LIL COWBELL", rarete = "Common", prix = 10, revenu = 1, corps = "bloc", tete = "cube", couleur = Color3.fromRGB(200, 170, 60), yeux = Color3.fromRGB(20, 20, 20), acc = { "cowbell" }, taille = 0.9 },
    { cle = "BassBlob", nom = "BASS BLOB", rarete = "Common", prix = 30, revenu = 3, corps = "cylindre", tete = "masque", couleur = Color3.fromRGB(90, 90, 110), yeux = Color3.fromRGB(120, 255, 200), acc = { "casque" }, taille = 0.9 },
    { cle = "DriftPebble", nom = "DRIFT PEBBLE", rarete = "Common", prix = 70, revenu = 6, corps = "bloc", tete = "crane", couleur = Color3.fromRGB(120, 120, 130), yeux = Color3.fromRGB(20, 20, 20), acc = {}, taille = 0.95 },
    { cle = "NeonSkull", nom = "NEON SKULL", rarete = "Rare", prix = 250, revenu = 15, corps = "bloc", tete = "crane", couleur = Color3.fromRGB(40, 40, 60), yeux = Color3.fromRGB(70, 160, 255), acc = { "chaine" }, taille = 1 },
    { cle = "MidnightGoblin", nom = "MIDNIGHT GOBLIN", rarete = "Rare", prix = 600, revenu = 32, corps = "cylindre", tete = "masque", couleur = Color3.fromRGB(40, 90, 60), yeux = Color3.fromRGB(150, 255, 90), acc = { "cornes" }, taille = 1 },
    { cle = "TokyoDrifter", nom = "TOKYO DRIFTER", rarete = "Rare", prix = 1200, revenu = 60, corps = "bloc", tete = "cube", couleur = Color3.fromRGB(220, 60, 80), yeux = Color3.fromRGB(20, 20, 20), acc = { "casque" }, taille = 1 },
    { cle = "CowbellDemon", nom = "COWBELL DEMON", rarete = "Epic", prix = 4000, revenu = 180, corps = "bloc", tete = "masque", couleur = Color3.fromRGB(120, 20, 30), yeux = Color3.fromRGB(255, 60, 60), acc = { "cornes", "cowbell" }, taille = 1.05 },
    { cle = "Bassquake", nom = "BASSQUAKE", rarete = "Epic", prix = 9000, revenu = 380, corps = "cylindre", tete = "cube", couleur = Color3.fromRGB(60, 40, 120), yeux = Color3.fromRGB(20, 20, 20), acc = { "casque", "chaine" }, taille = 1.05 },
    { cle = "GhostRider", nom = "GHOST RIDER", rarete = "Epic", prix = 18000, revenu = 700, corps = "bloc", tete = "crane", couleur = Color3.fromRGB(30, 30, 35), yeux = Color3.fromRGB(255, 120, 30), acc = { "flammes" }, taille = 1.05 },
    { cle = "PhonkReaper", nom = "PHONK REAPER", rarete = "Legendary", prix = 70000, revenu = 2500, corps = "bloc", tete = "crane", couleur = Color3.fromRGB(15, 15, 20), yeux = Color3.fromRGB(255, 200, 50), acc = { "cornes", "aura" }, taille = 1.1 },
    { cle = "DriftKing", nom = "DRIFT KING", rarete = "Legendary", prix = 160000, revenu = 5200, corps = "bloc", tete = "cube", couleur = Color3.fromRGB(230, 180, 40), yeux = Color3.fromRGB(20, 20, 20), acc = { "couronne", "chaine" }, taille = 1.1 },
    { cle = "MurderMask", nom = "MURDER MASK", rarete = "Legendary", prix = 350000, revenu = 10000, corps = "cylindre", tete = "masque", couleur = Color3.fromRGB(200, 200, 210), yeux = Color3.fromRGB(255, 30, 30), acc = { "aura" }, taille = 1.1 },
    { cle = "MidnightPhantom", nom = "MIDNIGHT PHANTOM", rarete = "Mythic", prix = 1500000, revenu = 38000, corps = "bloc", tete = "masque", couleur = Color3.fromRGB(20, 10, 40), yeux = Color3.fromRGB(200, 120, 255), acc = { "halo", "aura", "flammes" }, taille = 1.2 },
    { cle = "InfiniteDrift", nom = "INFINITE DRIFT", rarete = "Mythic", prix = 4000000, revenu = 90000, corps = "cylindre", tete = "cube", couleur = Color3.fromRGB(255, 40, 120), yeux = Color3.fromRGB(20, 20, 20), acc = { "casque", "couronne", "aura" }, taille = 1.2 },
    { cle = "LastCowbell", nom = "THE LAST COWBELL", rarete = "Secret", prix = 30000000, revenu = 600000, corps = "bloc", tete = "crane", couleur = Color3.fromRGB(255, 215, 80), yeux = Color3.fromRGB(20, 20, 20), acc = { "couronne", "cowbell", "aura", "flammes" }, taille = 1.3 },
    { cle = "Phonkzilla", nom = "PHONKZILLA", rarete = "Secret", prix = 120000000, revenu = 2000000, corps = "cylindre", tete = "masque", couleur = Color3.fromRGB(10, 10, 10), yeux = Color3.fromRGB(255, 40, 40), acc = { "cornes", "aura", "flammes" }, taille = 1.5 },
}
-- ===========================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local BLANC = Color3.new(1, 1, 1)
local NOIR = Color3.new(0, 0, 0)
local OR = Color3.fromRGB(255, 220, 80)
local VERT = Color3.fromRGB(110, 230, 160)

local function creer(classe, proprietes)
    local objet = Instance.new(classe)
    for nom, valeur in pairs(proprietes) do
        if nom ~= "Parent" then
            objet[nom] = valeur
        end
    end
    objet.Parent = proprietes.Parent
    return objet
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
local function enCouleur(mot, couleur)
    return string.format('<font color="#%02X%02X%02X">%s</font>', math.floor(couleur.R * 255), math.floor(couleur.G * 255), math.floor(couleur.B * 255), mot)
end

local RARETE_PAR_CLE, PHONK_PAR_CLE, PHONKS_PAR_RARETE = {}, {}, {}
for i, r in ipairs(RARETES) do
    r.rang = i
    RARETE_PAR_CLE[r.cle] = r
    PHONKS_PAR_RARETE[r.cle] = {}
end
for _, p in ipairs(PHONKS) do
    PHONK_PAR_CLE[p.cle] = p
    table.insert(PHONKS_PAR_RARETE[p.rarete], p)
end

-- ========================== COMMUNICATION ==========================
for _, nom in ipairs({ "MindsetRemotes", "MindsetPhonks", "MindsetTapis" }) do
    local vieux = ReplicatedStorage:FindFirstChild(nom)
    if vieux then
        vieux:Destroy()
    end
end
local dossierRemotes = creer("Folder", { Name = "MindsetRemotes", Parent = ReplicatedStorage })
local function remote(nom, estFonction)
    return creer(if estFonction then "RemoteFunction" else "RemoteEvent", { Name = nom, Parent = dossierRemotes })
end
local EvenementEvent = remote("Evenement")    -- serveur → clients : achat rare, collecte, Phonk rare sur le tapis...
local MessageEvent = remote("Message")        -- serveur → client : petit message en haut
local ReglagesEvent = remote("Reglages")      -- client → serveur : les paramètres du joueur
local ActionFonction = remote("Action", true) -- client → serveur : acheter sur le tapis, revendre

-- ce que le client doit savoir (raretés, Phonks) est publié ici en JSON
do
    local function rgb(c)
        return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
    end
    local raretes, phonks = {}, {}
    for i, r in ipairs(RARETES) do
        raretes[i] = { cle = r.cle, nom = r.nom, couleur = rgb(r.couleur) }
    end
    for _, p in ipairs(PHONKS) do
        phonks[p.cle] = { nom = p.nom, rarete = p.rarete, prix = p.prix, revenu = p.revenu }
    end
    ReplicatedStorage:SetAttribute("Config", HttpService:JSONEncode({
        raretes = raretes,
        phonks = phonks,
        vitesseTapis = CONFIG.VITESSE_TAPIS,
        revente = CONFIG.REVENTE,
    }))
    local musiques = {}
    for _, m in ipairs(CONFIG.MUSIQUES) do
        if m.id ~= "" then
            table.insert(musiques, { id = m.id, nom = m.nom })
        end
    end
    ReplicatedStorage:SetAttribute("Musiques", HttpService:JSONEncode(musiques))
end

-- ========================== LUMIÈRE : la nuit phonk ==========================
Lighting.ClockTime = 0.5
Lighting.Brightness = 1.5
Lighting.Ambient = Color3.fromRGB(90, 80, 110)
Lighting.OutdoorAmbient = Color3.fromRGB(110, 95, 135)
Lighting.EnvironmentDiffuseScale = 0.4
Lighting.EnvironmentSpecularScale = 0.8
for _, nom in ipairs({ "MindsetBloom", "MindsetStyle", "MindsetAtmo" }) do
    local vieux = Lighting:FindFirstChild(nom)
    if vieux then
        vieux:Destroy()
    end
end
creer("BloomEffect", { Name = "MindsetBloom", Intensity = 1, Size = 28, Threshold = 0.9, Parent = Lighting })
creer("ColorCorrectionEffect", { Name = "MindsetStyle", Saturation = -0.05, Contrast = 0.18, TintColor = Color3.fromRGB(235, 225, 255), Parent = Lighting })
creer("Atmosphere", { Name = "MindsetAtmo", Density = 0.35, Offset = 0.1, Color = Color3.fromRGB(120, 70, 170), Decay = Color3.fromRGB(40, 20, 70), Glare = 0.2, Haze = 2, Parent = Lighting })

-- ========================== LES MODÈLES DES PHONKS ==========================
-- Un modèle par Phonk, rangé dans ReplicatedStorage.MindsetPhonks : le serveur les copie dans les bases,
-- le client les copie sur le tapis. Ils regardent vers -Z, les pieds sur la « Racine ».
local dossierModeles = creer("Folder", { Name = "MindsetPhonks", Parent = ReplicatedStorage })

local function construirePhonk(def)
    local t = def.taille or 1
    local modele = creer("Model", { Name = def.cle })
    local rarete = RARETE_PAR_CLE[def.rarete]
    local function piece(nom, taille, cf, proprietes)
        proprietes = proprietes or {}
        proprietes.Name = nom
        proprietes.Size = taille * t
        proprietes.CFrame = CFrame.new(cf.Position * t) * cf.Rotation
        proprietes.Anchored = true
        proprietes.CanCollide = false
        proprietes.CanQuery = false
        proprietes.CanTouch = false
        proprietes.TopSurface = Enum.SurfaceType.Smooth
        proprietes.BottomSurface = Enum.SurfaceType.Smooth
        proprietes.Material = proprietes.Material or Enum.Material.SmoothPlastic
        proprietes.Parent = modele
        return creer("Part", proprietes)
    end
    local racine = piece("Racine", Vector3.new(2, 0.2, 2), CFrame.new(0, 0.1, 0), { Transparency = 1 })
    modele.PrimaryPart = racine
    local fonce = def.couleur:Lerp(NOIR, 0.35)
    -- le corps, les bras, les jambes
    local corps
    if def.corps == "cylindre" then
        corps = piece("Corps", Vector3.new(2.2, 1.7, 1.7), CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.pi / 2), { Shape = Enum.PartType.Cylinder, Color = def.couleur })
    else
        corps = piece("Corps", Vector3.new(1.7, 2.2, 1.1), CFrame.new(0, 1.3, 0), { Color = def.couleur })
    end
    for _, s in ipairs({ -1, 1 }) do
        piece("Bras", Vector3.new(0.45, 1.5, 0.45), CFrame.new(s * 1.12, 1.35, 0) * CFrame.Angles(0, 0, s * 0.12), { Color = fonce })
        piece("Jambe", Vector3.new(0.55, 0.5, 0.55), CFrame.new(s * 0.45, 0.25, 0), { Color = fonce })
    end
    -- la tête
    local tete
    if def.tete == "crane" then
        tete = piece("Tete", Vector3.new(1.8, 1.8, 1.8), CFrame.new(0, 3.25, 0), { Shape = Enum.PartType.Ball, Color = Color3.fromRGB(235, 232, 222) })
        local brillants = def.yeux.R + def.yeux.G + def.yeux.B > 0.3
        for _, s in ipairs({ -1, 1 }) do
            piece("Oeil", Vector3.new(0.55, 0.55, 0.55), CFrame.new(s * 0.38, 3.35, -0.62), { Shape = Enum.PartType.Ball, Color = def.yeux, Material = if brillants then Enum.Material.Neon else Enum.Material.SmoothPlastic })
        end
        piece("Nez", Vector3.new(0.2, 0.25, 0.2), CFrame.new(0, 3.0, -0.85), { Color = NOIR })
        piece("Machoire", Vector3.new(1.05, 0.45, 0.9), CFrame.new(0, 2.55, -0.3), { Color = Color3.fromRGB(225, 222, 212) })
        for k = -2, 2 do
            piece("Dent", Vector3.new(0.06, 0.3, 0.05), CFrame.new(k * 0.18, 2.6, -0.76), { Color = NOIR })
        end
    elseif def.tete == "masque" then
        tete = piece("Tete", Vector3.new(1.8, 1.8, 1.8), CFrame.new(0, 3.25, 0), { Shape = Enum.PartType.Ball, Color = fonce:Lerp(NOIR, 0.4) })
        for _, s in ipairs({ -1, 1 }) do
            piece("Oeil", Vector3.new(0.5, 0.16, 0.12), CFrame.new(s * 0.38, 3.4, -0.84) * CFrame.Angles(0, 0, s * -0.3), { Color = def.yeux, Material = Enum.Material.Neon })
        end
        piece("Bouche", Vector3.new(0.7, 0.08, 0.1), CFrame.new(0, 2.9, -0.86), { Color = def.yeux, Material = Enum.Material.Neon })
    else
        tete = piece("Tete", Vector3.new(1.6, 1.5, 1.5), CFrame.new(0, 3.15, 0), { Color = def.couleur:Lerp(BLANC, 0.15) })
        piece("Lunettes", Vector3.new(1.7, 0.36, 0.2), CFrame.new(0, 3.3, -0.78), { Color = NOIR, Reflectance = 0.4 })
        piece("Bouche", Vector3.new(0.5, 0.1, 0.1), CFrame.new(0, 2.8, -0.78), { Color = NOIR })
    end
    -- les accessoires
    for _, acc in ipairs(def.acc or {}) do
        if acc == "cowbell" then
            piece("Cowbell", Vector3.new(0.8, 0.95, 0.55), CFrame.new(0, 1.45, -0.75), { Color = Color3.fromRGB(230, 185, 60), Material = Enum.Material.Foil, Reflectance = 0.2 })
            piece("Battant", Vector3.new(0.25, 0.25, 0.25), CFrame.new(0, 0.95, -0.75), { Shape = Enum.PartType.Ball, Color = Color3.fromRGB(90, 70, 30) })
        elseif acc == "casque" then
            piece("Arceau", Vector3.new(2.05, 0.25, 0.4), CFrame.new(0, 4.15, 0), { Color = NOIR })
            for _, s in ipairs({ -1, 1 }) do
                piece("Ecouteur", Vector3.new(0.45, 0.95, 0.95), CFrame.new(s * 0.98, 3.3, 0), { Shape = Enum.PartType.Cylinder, Color = NOIR })
                piece("Lumiere", Vector3.new(0.1, 0.7, 0.7), CFrame.new(s * 1.22, 3.3, 0), { Shape = Enum.PartType.Cylinder, Color = def.yeux:Lerp(rarete.couleur, 0.5), Material = Enum.Material.Neon })
            end
        elseif acc == "cornes" then
            for _, s in ipairs({ -1, 1 }) do
                piece("Corne", Vector3.new(0.3, 0.9, 0.3), CFrame.new(s * 0.55, 4.2, 0) * CFrame.Angles(0, 0, s * -0.45), { Color = Color3.fromRGB(200, 30, 40), Material = Enum.Material.Neon })
            end
        elseif acc == "couronne" then
            piece("Couronne", Vector3.new(0.45, 1.3, 1.3), CFrame.new(0, 4.25, 0) * CFrame.Angles(0, 0, math.pi / 2), { Shape = Enum.PartType.Cylinder, Color = OR, Material = Enum.Material.Neon })
            for k = 0, 3 do
                local a = k * math.pi / 2
                piece("Pointe", Vector3.new(0.22, 0.45, 0.22), CFrame.new(math.cos(a) * 0.55, 4.6, math.sin(a) * 0.55), { Color = OR, Material = Enum.Material.Neon })
            end
        elseif acc == "chaine" then
            piece("Chaine", Vector3.new(1.3, 0.14, 0.1), CFrame.new(0, 2.05, -0.6) * CFrame.Angles(0, 0, 0.05), { Color = OR, Material = Enum.Material.Neon })
            piece("Pendentif", Vector3.new(0.35, 0.35, 0.1), CFrame.new(0, 1.8, -0.62) * CFrame.Angles(0, 0, math.rad(45)), { Color = OR, Material = Enum.Material.Neon })
        elseif acc == "halo" then
            piece("Halo", Vector3.new(0.12, 1.6, 1.6), CFrame.new(0, 4.55, 0) * CFrame.Angles(0, 0, math.pi / 2), { Shape = Enum.PartType.Cylinder, Color = BLANC, Material = Enum.Material.Neon, Transparency = 0.2 })
        elseif acc == "flammes" then
            creer("Fire", { Size = 4 * t, Heat = 6, Color = def.yeux, SecondaryColor = rarete.couleur, Parent = tete })
        elseif acc == "aura" then
            creer("ParticleEmitter", {
                Rate = 12,
                Lifetime = NumberRange.new(0.8, 1.4),
                Speed = NumberRange.new(1, 3),
                SpreadAngle = Vector2.new(180, 180),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * t), NumberSequenceKeypoint.new(1, 0) }),
                Color = ColorSequence.new(rarete.couleur, def.yeux),
                LightEmission = 1,
                Parent = corps,
            })
        end
    end
    if rarete.rang >= 4 then
        creer("PointLight", { Range = 10 * t, Brightness = 2, Color = rarete.couleur, Parent = corps })
    end
    modele:SetAttribute("Rarete", def.rarete)
    modele:SetAttribute("Hauteur", 4.8 * t)
    modele.Parent = dossierModeles
    return modele
end
for _, def in ipairs(PHONKS) do
    construirePhonk(def)
end

-- ========================== SAUVEGARDE (DataStore) ==========================
-- ⚠️ Pour tester dans Studio : publie le jeu, puis
--    Paramètres du jeu > Sécurité > « Activer l'accès Studio aux services API ».
local sauvegarde = nil
do
    local ok, resultat = pcall(function()
        return DataStoreService:GetDataStore("StealAPhonk_Joueurs_v1")
    end)
    if ok then
        sauvegarde = resultat
    else
        warn("💾 Sauvegarde désactivée (publie le jeu et active l'accès Studio aux services API) :", resultat)
    end
end

local function essayer(fonction)
    for essai = 1, 3 do
        local ok, resultat = pcall(fonction)
        if ok then
            return true, resultat
        end
        warn("💾 Sauvegarde : essai " .. essai .. " raté :", resultat)
        if essai < 3 then
            task.wait(2)
        end
    end
    return false, nil
end

-- l'état de chaque joueur
--   emplacements[k] = { cle = "NeonSkull", stock = argent en attente } (ou nil si l'emplacement est vide)
local etats = {} -- [joueur] = état

local function stat(joueur, nom)
    for _, dossier in ipairs({ "leaderstats", "StatsCachees" }) do
        local d = joueur:FindFirstChild(dossier)
        local v = d and d:FindFirstChild(nom)
        if v then
            return v
        end
    end
    return nil
end

local function ajouterArgent(joueur, n)
    local cash, total = stat(joueur, "Cash"), stat(joueur, "Total")
    if cash and total then
        cash.Value += n
        if n > 0 then
            total.Value += n
        end
    end
end

-- ========================== LA MAP ==========================
-- Le sol à y = 100. Le tapis au milieu (le long de X), 4 bases au nord, 4 bases au sud, face au tapis.
local C = Vector3.new(0, 100, 0)
local LONGUEUR_TAPIS = 340
local DEBUT_TAPIS = C + Vector3.new(-LONGUEUR_TAPIS / 2, 1.2, 0) -- là où les Phonks montent sur le tapis (sur le dessus)
local COULEURS_BASES = {
    Color3.fromRGB(255, 60, 120), Color3.fromRGB(80, 200, 255), Color3.fromRGB(255, 180, 40), Color3.fromRGB(150, 90, 255),
    Color3.fromRGB(80, 255, 150), Color3.fromRGB(255, 90, 50), Color3.fromRGB(60, 120, 255), Color3.fromRGB(255, 120, 230),
}

for _, nom in ipairs({ "MindsetMap", "MindsetMonstres", "MindsetCristaux" }) do
    local vieux = workspace:FindFirstChild(nom)
    if vieux then
        vieux:Destroy()
    end
end
local dossierCarte = creer("Folder", { Name = "MindsetMap", Parent = workspace })
local dossierBases = creer("Folder", { Name = "Bases", Parent = dossierCarte })

local function bloc(proprietes)
    proprietes.Anchored = true
    proprietes.TopSurface = Enum.SurfaceType.Smooth
    proprietes.BottomSurface = Enum.SurfaceType.Smooth
    proprietes.Material = proprietes.Material or Enum.Material.SmoothPlastic
    proprietes.Parent = proprietes.Parent or dossierCarte
    return creer("Part", proprietes)
end
local function neon(proprietes)
    proprietes.Material = Enum.Material.Neon
    proprietes.CanCollide = proprietes.CanCollide or false
    proprietes.CastShadow = false
    return bloc(proprietes)
end
local function invisible(proprietes)
    proprietes.Transparency = 1
    proprietes.CastShadow = false
    proprietes.CanQuery = false
    return bloc(proprietes)
end
local function panneau(part, message, couleur, face)
    local surface = creer("SurfaceGui", { Face = face or Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 30, LightInfluence = 0, Parent = part })
    local label = creer("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, RichText = true, Text = message, TextColor3 = couleur, Parent = surface })
    return surface, label
end

-- ---------- le sol, les bords, le titre, les lampadaires ----------
do
    bloc({ Name = "Sol", Size = Vector3.new(460, 4, 280), CFrame = CFrame.new(C - Vector3.new(0, 2, 0)), Material = Enum.Material.Asphalt, Color = Color3.fromRGB(32, 30, 38) })
    -- les lignes de route (le côté « drift »)
    for _, z in ipairs({ -22, 22 }) do
        for x = -210, 210, 16 do
            neon({ Name = "Ligne", Size = Vector3.new(8, 0.1, 0.5), CFrame = CFrame.new(C + Vector3.new(x, 0.05, z)), Color = Color3.fromRGB(240, 240, 255), Transparency = 0.3 })
        end
    end
    -- les murs invisibles autour de la map
    for _, m in ipairs({
        { Vector3.new(460, 40, 2), Vector3.new(0, 20, -140) },
        { Vector3.new(460, 40, 2), Vector3.new(0, 20, 140) },
        { Vector3.new(2, 40, 280), Vector3.new(-230, 20, 0) },
        { Vector3.new(2, 40, 280), Vector3.new(230, 20, 0) },
    }) do
        invisible({ Name = "Mur", Size = m[1], CFrame = CFrame.new(C + m[2]) })
    end
    for _, z in ipairs({ -139, 139 }) do
        neon({ Name = "Bord", Size = Vector3.new(460, 0.6, 0.6), CFrame = CFrame.new(C + Vector3.new(0, 0.3, z)), Color = Color3.fromRGB(170, 80, 255) })
    end
    -- l'arche du titre au-dessus du tapis
    for _, z in ipairs({ -12, 12 }) do
        bloc({ Name = "Pilier", Size = Vector3.new(3, 26, 3), CFrame = CFrame.new(C + Vector3.new(0, 13, z)), Color = Color3.fromRGB(20, 18, 26), Material = Enum.Material.Metal })
    end
    local titre = bloc({ Name = "Titre", Size = Vector3.new(4, 8, 26), CFrame = CFrame.new(C + Vector3.new(0, 28, 0)), Color = Color3.fromRGB(14, 12, 20) })
    for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
        panneau(titre, 'STEAL A <font color="#FF3C78">PHONK</font>', BLANC, face)
    end
    neon({ Name = "Neon", Size = Vector3.new(4.2, 0.4, 26.2), CFrame = CFrame.new(C + Vector3.new(0, 23.8, 0)), Color = Color3.fromRGB(255, 60, 120) })
    for x = -200, 200, 50 do
        for _, z in ipairs({ -28, 28 }) do
            bloc({ Name = "Lampadaire", Size = Vector3.new(0.7, 14, 0.7), CFrame = CFrame.new(C + Vector3.new(x, 7, z)), Color = Color3.fromRGB(25, 25, 30), Material = Enum.Material.Metal })
            local lampe = neon({ Name = "Lampe", Size = Vector3.new(3, 0.6, 1.2), CFrame = CFrame.new(C + Vector3.new(x, 14, z)), Color = Color3.fromRGB(200, 120, 255) })
            creer("PointLight", { Range = 26, Brightness = 1.6, Color = Color3.fromRGB(200, 120, 255), Parent = lampe })
        end
    end
end

-- ---------- le tapis roulant ----------
do
    bloc({ Name = "Tapis", Size = Vector3.new(LONGUEUR_TAPIS, 1.2, 12), CFrame = CFrame.new(C + Vector3.new(0, 0.6, 0)), Color = Color3.fromRGB(22, 22, 28), Material = Enum.Material.Rubber })
    for _, z in ipairs({ -6.4, 6.4 }) do
        bloc({ Name = "Rebord", Size = Vector3.new(LONGUEUR_TAPIS, 2, 0.8), CFrame = CFrame.new(C + Vector3.new(0, 1, z)), Color = Color3.fromRGB(40, 40, 48), Material = Enum.Material.Metal })
        neon({ Name = "RebordNeon", Size = Vector3.new(LONGUEUR_TAPIS, 0.25, 0.85), CFrame = CFrame.new(C + Vector3.new(0, 2.05, z)), Color = Color3.fromRGB(255, 60, 120) })
    end
    -- les deux portes : d'où sortent les Phonks, et où ils disparaissent
    for _, x in ipairs({ -LONGUEUR_TAPIS / 2, LONGUEUR_TAPIS / 2 }) do
        bloc({ Name = "PorteTapis", Size = Vector3.new(4, 12, 16), CFrame = CFrame.new(C + Vector3.new(x, 6, 0)), Color = Color3.fromRGB(16, 14, 22) })
        neon({ Name = "Ouverture", Size = Vector3.new(4.1, 8, 11), CFrame = CFrame.new(C + Vector3.new(x, 5, 0)), Color = Color3.fromRGB(10, 6, 16) })
    end
end

-- ---------- LES BASES ----------
-- base.cf = son centre au sol ; son -Z regarde vers le tapis (c'est l'entrée)
local bases = {}
local function local3(base, x, y, z)
    return base.cf * CFrame.new(x, y, z)
end
for i = 1, 8 do
    local nord = i <= 4
    local x = -150 + ((i - 1) % 4) * 100
    local z = if nord then -62 else 62
    local centre = C + Vector3.new(x, 0, z)
    local cf = CFrame.lookAt(centre, centre + Vector3.new(0, 0, if nord then 1 else -1))
    local couleur = COULEURS_BASES[i]
    local dossier = creer("Folder", { Name = "Base" .. i, Parent = dossierBases })
    local base = { index = i, cf = cf, couleur = couleur, dossier = dossier, emplacements = {}, proprietaire = nil }
    bases[i] = base

    bloc({ Name = "Sol", Size = Vector3.new(48, 0.6, 44), CFrame = local3(base, 0, 0.3, 0), Color = Color3.fromRGB(26, 24, 32), Material = Enum.Material.Concrete, Parent = dossier })
    -- les murs (côtés et fond), l'avant est ouvert
    for _, m in ipairs({ { Vector3.new(1, 7, 44), -24, 0 }, { Vector3.new(1, 7, 44), 24, 0 }, { Vector3.new(48, 7, 1), 0, 22 } }) do
        bloc({ Name = "Mur", Size = m[1], CFrame = local3(base, m[2], 3.5, m[3]), Color = Color3.fromRGB(34, 32, 42), Material = Enum.Material.Metal, Parent = dossier })
        neon({ Name = "MurNeon", Size = m[1] * Vector3.new(1, 0, 1) + Vector3.new(0.1, 0.3, 0.1), CFrame = local3(base, m[2], 7.1, m[3]), Color = couleur, Parent = dossier })
    end
    neon({ Name = "LigneAvant", Size = Vector3.new(48, 0.12, 0.5), CFrame = local3(base, 0, 0.66, -21.8), Color = couleur, Parent = dossier })
    -- l'enseigne (le nom du propriétaire), au-dessus de l'entrée
    for _, s in ipairs({ -1, 1 }) do
        bloc({ Name = "Poteau", Size = Vector3.new(1.2, 16, 1.2), CFrame = local3(base, s * 23, 8, -22), Color = Color3.fromRGB(20, 18, 26), Material = Enum.Material.Metal, Parent = dossier })
    end
    local enseigne = bloc({ Name = "Enseigne", Size = Vector3.new(30, 4, 0.6), CFrame = local3(base, 0, 15, -22), Color = Color3.fromRGB(14, 12, 20), Parent = dossier })
    local _, labelEnseigne = panneau(enseigne, "EMPTY BASE", couleur)
    neon({ Name = "EnseigneNeon", Size = Vector3.new(30.2, 0.3, 0.7), CFrame = local3(base, 0, 12.85, -22), Color = couleur, Parent = dossier })
    base.labelEnseigne = labelEnseigne

    -- les 10 emplacements (2 rangées de 5)
    for k = 1, CONFIG.EMPLACEMENTS do
        local rangee = if k <= 5 then 0 else 1
        local colonne = (k - 1) % 5
        local px, pz = -18 + colonne * 9, -6 + rangee * 12
        local podium = bloc({ Name = "Podium" .. k, Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 6, 6), CFrame = local3(base, px, 0.7, pz) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(40, 38, 50), Material = Enum.Material.Metal, Parent = dossier })
        neon({ Name = "PodiumNeon", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 6.2, 6.2), CFrame = local3(base, px, 1.35, pz) * CFrame.Angles(0, 0, math.pi / 2), Color = couleur, Transparency = 0.4, Parent = dossier })
        -- le nom du Phonk et l'argent qui attend sur cet emplacement
        local billboard = creer("BillboardGui", { Name = "Infos", Size = UDim2.fromOffset(150, 44), StudsOffsetWorldSpace = Vector3.new(0, 7.5, 0), MaxDistance = 70, LightInfluence = 0, Enabled = false, Parent = podium })
        local labelNom = creer("TextLabel", { Size = UDim2.new(1, 0, 0.5, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextStrokeTransparency = 0.2, TextColor3 = BLANC, Parent = billboard })
        local labelStock = creer("TextLabel", { Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0.5, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextStrokeTransparency = 0.2, TextColor3 = VERT, Parent = billboard })
        local prompt = creer("ProximityPrompt", { ActionText = "Sell", ObjectText = "", HoldDuration = 0.8, MaxActivationDistance = 7, RequiresLineOfSight = false, KeyboardKeyCode = Enum.KeyCode.E, Enabled = false, Parent = podium })
        prompt:SetAttribute("Action", "Vendre")
        prompt:SetAttribute("Base", i)
        prompt:SetAttribute("Emplacement", k)
        base.emplacements[k] = { podium = podium, dessus = local3(base, px, 1.4, pz), billboard = billboard, labelNom = labelNom, labelStock = labelStock, prompt = prompt, modele = nil }
    end

    -- le carré COLLECT (au fond de la base)
    local collect = neon({ Name = "Collect", Size = Vector3.new(10, 0.3, 6), CFrame = local3(base, 0, 0.75, 15.5), Color = VERT, Transparency = 0.25, CanCollide = false, Parent = dossier })
    collect.CanTouch = true
    local billboardC = creer("BillboardGui", { Name = "Infos", Size = UDim2.fromOffset(180, 50), StudsOffsetWorldSpace = Vector3.new(0, 4, 0), MaxDistance = 80, LightInfluence = 0, Parent = collect })
    creer("TextLabel", { Size = UDim2.new(1, 0, 0.45, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = "COLLECT", TextStrokeTransparency = 0.2, TextColor3 = VERT, Parent = billboardC })
    base.labelCollect = creer("TextLabel", { Position = UDim2.fromScale(0, 0.45), Size = UDim2.new(1, 0, 0.55, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = "$0", TextStrokeTransparency = 0.2, TextColor3 = BLANC, Parent = billboardC })
    base.collect = collect
    base.apparition = local3(base, 0, 4, 11) -- dans la base, face à l'entrée
end

-- ---------- les deux tableaux TOP 10 (entre les bases) ----------
local tableaux = {}
for _, info in ipairs({ { cle = "T", z = -62, regard = 1, titre = "TOP 10 · MOST CASH EARNED", couleur = OR }, { cle = "R", z = 62, regard = -1, titre = "TOP 10 · BEST INCOME", couleur = VERT } }) do
    local p = C + Vector3.new(0, 0, info.z)
    local cf = CFrame.lookAt(p, p + Vector3.new(0, 0, info.regard))
    bloc({ Name = "Pied", Size = Vector3.new(1.2, 8, 1.2), CFrame = cf * CFrame.new(0, 4, 0), Color = Color3.fromRGB(30, 30, 36) })
    local tableau = bloc({ Name = "Tableau" .. info.cle, Size = Vector3.new(22, 24, 0.6), CFrame = cf * CFrame.new(0, 18, 0), Color = Color3.fromRGB(14, 14, 18) })
    neon({ Name = "Cadre", Size = Vector3.new(22.6, 24.6, 0.4), CFrame = cf * CFrame.new(0, 18, 0.2), Color = info.couleur })
    local surface = creer("SurfaceGui", { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Vector2.new(500, 550), LightInfluence = 0, Parent = tableau })
    creer("TextLabel", { Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 12), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = info.titre, TextColor3 = info.couleur, Parent = surface })
    for rang = 1, 10 do
        creer("TextLabel", { Name = "Ligne" .. rang, Size = UDim2.new(1, -40, 0, 40), Position = UDim2.fromOffset(20, 80 + (rang - 1) * 46), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
            Text = if rang == 1 then "Loading..." else "", TextColor3 = Color3.fromRGB(230, 230, 240), Parent = surface })
    end
    tableaux[info.cle] = surface
end

-- ========================== LES BASES DES JOUEURS ==========================
local function revenuDe(e)
    local total = 0
    for _, emp in pairs(e.emplacements) do
        local def = PHONK_PAR_CLE[emp.cle]
        if def then
            total += def.revenu
        end
    end
    return total
end

-- les clients lisent ça dans les attributs du joueur
local function publier(joueur)
    local e = etats[joueur]
    if not e then
        return
    end
    local revenu = revenuDe(e)
    joueur:SetAttribute("Revenu", revenu)
    joueur:SetAttribute("Base", if e.base then e.base.index else 0)
    local libres = 0
    for k = 1, CONFIG.EMPLACEMENTS do
        if not e.emplacements[k] then
            libres += 1
        end
    end
    joueur:SetAttribute("Libres", libres)
    local r = stat(joueur, "Income")
    if r then
        r.Value = revenu
    end
    if revenu > (e.meilleurRevenu or 0) then
        e.meilleurRevenu = revenu
    end
end

-- poser (ou enlever) le modèle d'un Phonk sur un emplacement
local function afficherEmplacement(base, k, emp)
    local place = base.emplacements[k]
    if place.modele then
        place.modele:Destroy()
        place.modele = nil
    end
    if not emp then
        place.billboard.Enabled = false
        place.prompt.Enabled = false
        return
    end
    local def = PHONK_PAR_CLE[emp.cle]
    local modeleBase = dossierModeles:FindFirstChild(emp.cle)
    if not def or not modeleBase then
        return
    end
    local modele = modeleBase:Clone()
    modele:PivotTo(place.dessus) -- face à l'entrée de la base
    modele:SetAttribute("Base", place.dessus) -- (le client le fait danser à partir de là)
    modele.Parent = base.dossier
    place.modele = modele
    local rarete = RARETE_PAR_CLE[def.rarete]
    place.labelNom.Text = def.nom
    place.labelNom.TextColor3 = rarete.couleur
    place.labelStock.Text = "$" .. court(emp.stock or 0)
    place.billboard.StudsOffsetWorldSpace = Vector3.new(0, (modele:GetAttribute("Hauteur") or 5) + 2.2, 0)
    place.billboard.Enabled = true
    place.prompt.Enabled = true
    place.prompt.ObjectText = def.nom .. " · $" .. court(def.prix * CONFIG.REVENTE)
end

local function attribuerBase(joueur)
    local e = etats[joueur]
    for _, base in ipairs(bases) do
        if not base.proprietaire then
            base.proprietaire = joueur
            e.base = base
            base.labelEnseigne.Text = string.upper(joueur.DisplayName) .. "'S BASE"
            base.dossier:SetAttribute("Proprietaire", joueur.UserId)
            for k = 1, CONFIG.EMPLACEMENTS do
                afficherEmplacement(base, k, e.emplacements[k])
            end
            publier(joueur)
            return base
        end
    end
    return nil
end

local function libererBase(joueur)
    local e = etats[joueur]
    local base = e and e.base
    if not base then
        return
    end
    for k = 1, CONFIG.EMPLACEMENTS do
        afficherEmplacement(base, k, nil)
    end
    base.proprietaire = nil
    base.labelEnseigne.Text = "EMPTY BASE"
    base.labelCollect.Text = "$0"
    base.dossier:SetAttribute("Proprietaire", nil)
    e.base = nil
end

local function premierLibre(e)
    for k = 1, CONFIG.EMPLACEMENTS do
        if not e.emplacements[k] then
            return k
        end
    end
    return nil
end

-- 💰 COLLECT : marcher sur le carré vert de SA base = récupérer tout l'argent qui attend
local function collecter(joueur)
    local e = etats[joueur]
    if not e or not e.base or os.clock() - (e.derniereCollecte or 0) < 0.6 then
        return
    end
    e.derniereCollecte = os.clock()
    local total = 0
    for k, emp in pairs(e.emplacements) do
        total += emp.stock or 0
        emp.stock = 0
        e.base.emplacements[k].labelStock.Text = "$0"
    end
    total = math.floor(total)
    if total > 0 then
        ajouterArgent(joueur, total)
        e.base.labelCollect.Text = "$0"
        EvenementEvent:FireClient(joueur, "Collecte", total)
    end
end
for _, base in ipairs(bases) do
    base.collect.Touched:Connect(function(partie)
        local joueur = Players:GetPlayerFromCharacter(partie.Parent)
        if joueur and base.proprietaire == joueur then
            collecter(joueur)
        end
    end)
end

-- chaque seconde : chaque Phonk rapporte son revenu sur son emplacement
task.spawn(function()
    while true do
        task.wait(1)
        for _, e in pairs(etats) do
            if e.base and e.charge then
                local attente = 0
                for k, emp in pairs(e.emplacements) do
                    local def = PHONK_PAR_CLE[emp.cle]
                    if def then
                        emp.stock = (emp.stock or 0) + def.revenu
                        attente += emp.stock
                        e.base.emplacements[k].labelStock.Text = "$" .. court(emp.stock)
                    end
                end
                e.base.labelCollect.Text = "$" .. court(attente)
            end
        end
    end
end)

-- ========================== LE TAPIS ROULANT ==========================
-- Les Phonks du tapis sont des « fiches » dans ReplicatedStorage.MindsetTapis (attributs Phonk + Debut = heure de départ) :
-- chaque client les dessine et les fait avancer tout seul (c'est fluide). Le serveur calcule où ils sont.
local dossierTapis = creer("Folder", { Name = "MindsetTapis", Parent = ReplicatedStorage })
dossierTapis:SetAttribute("Depart", DEBUT_TAPIS)
dossierTapis:SetAttribute("Longueur", LONGUEUR_TAPIS)
local surTapis = {} -- [id] = { fiche, cle, debut, id }
local prochainId = 0
local DUREE_TAPIS = LONGUEUR_TAPIS / CONFIG.VITESSE_TAPIS

local function positionSurTapis(item, heure)
    return DEBUT_TAPIS + Vector3.new((heure - item.debut) * CONFIG.VITESSE_TAPIS, 0, 0)
end

local function tirerPhonk()
    local total = 0
    for _, r in ipairs(RARETES) do
        if #PHONKS_PAR_RARETE[r.cle] > 0 then
            total += r.poids
        end
    end
    local tirage = math.random() * total
    for _, r in ipairs(RARETES) do
        local liste = PHONKS_PAR_RARETE[r.cle]
        if #liste > 0 then
            tirage -= r.poids
            if tirage <= 0 then
                return liste[math.random(1, #liste)]
            end
        end
    end
    return PHONKS[1]
end

local function ajouterSurTapis(def, avance)
    prochainId += 1
    local debut = workspace:GetServerTimeNow() - (avance or 0)
    local fiche = creer("Configuration", { Name = tostring(prochainId) })
    fiche:SetAttribute("Phonk", def.cle)
    fiche:SetAttribute("Debut", debut)
    fiche.Parent = dossierTapis
    surTapis[prochainId] = { fiche = fiche, cle = def.cle, debut = debut, id = prochainId }
    if not avance and RARETE_PAR_CLE[def.rarete].rang >= 4 then
        EvenementEvent:FireAllClients("RareTapis", def.cle)
    end
end

-- au démarrage, le tapis est déjà rempli
for avance = DUREE_TAPIS - 5, 1, -CONFIG.INTERVALLE_TAPIS do
    ajouterSurTapis(tirerPhonk(), avance)
end
task.spawn(function()
    while true do
        ajouterSurTapis(tirerPhonk())
        task.wait(CONFIG.INTERVALLE_TAPIS)
        local maintenant = workspace:GetServerTimeNow()
        for id, item in pairs(surTapis) do
            if maintenant - item.debut > DUREE_TAPIS then
                item.fiche:Destroy()
                surTapis[id] = nil
            end
        end
    end
end)

-- ========================== LES ACTIONS (acheter, revendre) ==========================
local function action(joueur, e, quoi, a, b)
    local cash = stat(joueur, "Cash")
    if quoi == "Acheter" then
        local item = surTapis[tonumber(a) or -1]
        if not item then
            return false, "Too late!"
        end
        local def = PHONK_PAR_CLE[item.cle]
        local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
        if not racine then
            return false, "?"
        end
        -- (on accepte un petit retard : le client voit le tapis un poil en retard)
        local maintenant = workspace:GetServerTimeNow()
        local d1 = (racine.Position - positionSurTapis(item, maintenant)).Magnitude
        local d2 = (racine.Position - positionSurTapis(item, maintenant - 0.6)).Magnitude
        if math.min(d1, d2) > 18 then
            return false, "Get closer!"
        end
        if not e.base then
            return false, "You don't have a base yet"
        end
        local k = premierLibre(e)
        if not k then
            return false, "Your base is full! Sell a Phonk first."
        end
        if cash.Value < def.prix then
            return false, "Not enough cash"
        end
        cash.Value -= def.prix
        item.fiche:Destroy()
        surTapis[item.id] = nil
        e.emplacements[k] = { cle = def.cle, stock = 0 }
        afficherEmplacement(e.base, k, e.emplacements[k])
        publier(joueur)
        if RARETE_PAR_CLE[def.rarete].rang >= 4 then
            EvenementEvent:FireAllClients("AchatRare", joueur.DisplayName, def.cle)
        end
        return true, def.cle
    elseif quoi == "Vendre" then
        local k = tonumber(b)
        if not e.base or tonumber(a) ~= e.base.index or not k or not e.emplacements[k] then
            return false, "That's not yours!"
        end
        local emp = e.emplacements[k]
        local def = PHONK_PAR_CLE[emp.cle]
        local gain = math.floor((if def then def.prix * CONFIG.REVENTE else 0) + (emp.stock or 0))
        e.emplacements[k] = nil
        afficherEmplacement(e.base, k, nil)
        ajouterArgent(joueur, gain)
        publier(joueur)
        return true, gain
    end
    return false, "?"
end

ActionFonction.OnServerInvoke = function(joueur, quoi, a, b)
    local e = etats[joueur]
    if not e or not e.charge then
        return false, "Still loading your data..."
    end
    if type(quoi) ~= "string" then
        return false, "?"
    end
    if e.occupe then
        return false, "Wait a second..."
    end
    e.occupe = true
    local ok, resultat, detail = pcall(action, joueur, e, quoi, a, b)
    e.occupe = false
    if not ok then
        warn("🎵 Action ratée :", resultat)
        return false, "Try again in a second..."
    end
    return resultat, detail
end

-- ========================== CHARGER / SAUVER ==========================
local publierClassements -- (défini plus bas)

local function chargerJoueur(joueur)
    local e = etats[joueur]
    local donnees = nil
    if sauvegarde then
        local ok, resultat = essayer(function()
            return sauvegarde:GetAsync("joueur_" .. joueur.UserId)
        end)
        if ok then
            donnees = resultat
            e.chargeOk = true
        else
            warn("💾 Impossible de charger les données de " .. joueur.Name .. " : pas de sauvegarde pour cette partie.")
        end
    end
    if not joueur.Parent then
        return
    end
    local function nombre(x)
        return if type(x) == "number" and x == x and x >= 0 then math.floor(x) else 0
    end
    if type(donnees) == "table" then
        stat(joueur, "Cash").Value = nombre(donnees.cash)
        stat(joueur, "Total").Value = nombre(donnees.total)
        e.meilleurRevenu = nombre(donnees.meilleurRevenu)
        if type(donnees.phonks) == "table" then
            for k = 1, CONFIG.EMPLACEMENTS do
                local cle = donnees.phonks[tostring(k)]
                if type(cle) == "string" and PHONK_PAR_CLE[cle] then
                    e.emplacements[k] = { cle = cle, stock = 0 }
                end
            end
        end
        if type(donnees.reglages) == "table" then
            e.reglages = donnees.reglages
            joueur:SetAttribute("Reglages", HttpService:JSONEncode(donnees.reglages))
        end
    else
        stat(joueur, "Cash").Value = CONFIG.ARGENT_DEPART
    end
    if RunService:IsStudio() and CONFIG.ARGENT_CADEAU_STUDIO > 0 and stat(joueur, "Cash").Value < CONFIG.ARGENT_CADEAU_STUDIO then
        stat(joueur, "Cash").Value = CONFIG.ARGENT_CADEAU_STUDIO
    end
    e.charge = true
    if e.base then
        for k = 1, CONFIG.EMPLACEMENTS do
            afficherEmplacement(e.base, k, e.emplacements[k])
        end
    end
    publier(joueur)
end

local function sauverJoueur(joueur)
    local e = etats[joueur]
    if not sauvegarde or not e or not e.chargeOk or not stat(joueur, "Cash") then
        return
    end
    local phonks = {}
    local attente = 0
    for k, emp in pairs(e.emplacements) do
        phonks[tostring(k)] = emp.cle
        attente += emp.stock or 0
    end
    -- l'argent qui attend sur les emplacements est ajouté (pour ne rien perdre en partant)
    local copie = {
        cash = stat(joueur, "Cash").Value + math.floor(attente),
        total = stat(joueur, "Total").Value,
        meilleurRevenu = e.meilleurRevenu or 0,
        phonks = phonks,
        reglages = e.reglages,
    }
    essayer(function()
        sauvegarde:UpdateAsync("joueur_" .. joueur.UserId, function(anciennes)
            local donnees = anciennes or {}
            for cle, valeur in pairs(copie) do
                donnees[cle] = valeur
            end
            return donnees
        end)
    end)
    if publierClassements then
        publierClassements(joueur, copie.total, copie.meilleurRevenu)
    end
end

game:BindToClose(function()
    local restants = 0
    for _, joueur in ipairs(Players:GetPlayers()) do
        restants += 1
        task.spawn(function()
            sauverJoueur(joueur)
            restants -= 1
        end)
    end
    local limite = os.clock() + 25
    while restants > 0 and os.clock() < limite do
        task.wait(0.1)
    end
end)

task.spawn(function()
    while true do
        task.wait(120)
        for _, joueur in ipairs(Players:GetPlayers()) do
            task.spawn(sauverJoueur, joueur)
        end
    end
end)

ReglagesEvent.OnServerEvent:Connect(function(joueur, reglages)
    local e = etats[joueur]
    if not e or type(reglages) ~= "table" then
        return
    end
    local function nombre(x)
        return if type(x) == "number" and x == x then math.clamp(x, 0, 1) else 1
    end
    e.reglages = {
        musique = nombre(reglages.musique),
        bruitages = nombre(reglages.bruitages),
        secousses = reglages.secousses ~= false,
        flashs = reglages.flashs ~= false,
        langue = if reglages.langue == "en" or reglages.langue == "fr" then reglages.langue else "auto",
    }
end)

-- ========================== CLASSEMENTS (TOP 10) ==========================
-- T = le plus d'argent gagné en tout · R = le meilleur revenu par seconde
local CLASSEMENTS = {
    T = { store = "SAP_Total_v1", stat = "Total" },
    R = { store = "SAP_Revenu_v1", stat = "Income" },
}
local alerteClassement = false
for _, c in pairs(CLASSEMENTS) do
    local ok, store = pcall(function()
        return DataStoreService:GetOrderedDataStore(c.store)
    end)
    if ok then
        c.ordre = store
    end
end
local function alerte(erreur)
    if not alerteClassement then
        alerteClassement = true
        warn("🏆 Classements : sauvegarde indisponible (publie le jeu + accès Studio aux services API). On montre les joueurs du serveur. ", erreur)
    end
end
publierClassements = function(joueur, total, revenu)
    for cle, valeur in pairs({ T = total, R = revenu }) do
        local c = CLASSEMENTS[cle]
        if c.ordre and valeur > 0 then
            local ok, erreur = pcall(function()
                c.ordre:SetAsync(tostring(joueur.UserId), math.floor(valeur))
            end)
            if not ok then
                alerte(erreur)
            end
        end
    end
end
local nomsCache = {}
local function nomDe(userId)
    local present = Players:GetPlayerByUserId(userId)
    if present then
        nomsCache[userId] = present.DisplayName
    end
    if not nomsCache[userId] then
        local ok, nom = pcall(function()
            return Players:GetNameFromUserIdAsync(userId)
        end)
        nomsCache[userId] = if ok and nom then nom else ("Player " .. userId)
    end
    return nomsCache[userId]
end
local function majTableau(cle)
    local c = CLASSEMENTS[cle]
    local scores = {}
    if c.ordre then
        local ok, page = pcall(function()
            return c.ordre:GetSortedAsync(false, 10):GetCurrentPage()
        end)
        if ok then
            for _, ligne in ipairs(page) do
                local id = tonumber(ligne.key)
                if id then
                    scores[id] = ligne.value
                end
            end
        else
            alerte(page)
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        local v = stat(p, c.stat)
        local e = etats[p]
        local score = v and v.Value or 0
        if cle == "R" and e then
            score = math.max(score, e.meilleurRevenu or 0)
        end
        if score > (scores[p.UserId] or 0) then
            scores[p.UserId] = score
        end
    end
    local liste = {}
    for id, score in pairs(scores) do
        if score > 0 then
            table.insert(liste, { id = id, score = score })
        end
    end
    table.sort(liste, function(x, y)
        return x.score > y.score
    end)
    local surface = tableaux[cle]
    local COULEURS_RANG = { OR, Color3.fromRGB(210, 210, 225), Color3.fromRGB(215, 140, 80) }
    for rang = 1, 10 do
        local ligne = surface:FindFirstChild("Ligne" .. rang)
        local l = liste[rang]
        if l then
            local couleur = COULEURS_RANG[rang] or Color3.fromRGB(200, 200, 215)
            ligne.Text = enCouleur("#" .. rang, couleur) .. "  " .. nomDe(l.id) .. "   " .. enCouleur("$" .. court(l.score) .. (if cle == "R" then "/s" else ""), couleur)
        else
            ligne.Text = if rang == 1 then "No record yet: be the first!" else ""
        end
    end
end
task.spawn(function()
    task.wait(5)
    while true do
        for cle in pairs(CLASSEMENTS) do
            pcall(majTableau, cle)
        end
        task.wait(60)
    end
end)

-- ========================== LES JOUEURS ==========================
local function joueurArrive(joueur)
    etats[joueur] = { emplacements = {}, charge = false, chargeOk = false }
    local stats = creer("Folder", { Name = "leaderstats" })
    creer("IntValue", { Name = "Cash", Parent = stats })
    creer("IntValue", { Name = "Income", Parent = stats })
    stats.Parent = joueur
    local cachees = creer("Folder", { Name = "StatsCachees", Parent = joueur })
    creer("IntValue", { Name = "Total", Parent = cachees })
    if not attribuerBase(joueur) then
        MessageEvent:FireClient(joueur, "The server is full: no free base.")
    end
    task.spawn(chargerJoueur, joueur)

    local function surPersonnage(personnage)
        local humanoid = personnage:WaitForChild("Humanoid", 10)
        if not humanoid then
            return
        end
        task.wait()
        humanoid.WalkSpeed = CONFIG.VITESSE
        local e = etats[joueur]
        if e and e.base then
            personnage:PivotTo(e.base.apparition)
        else
            personnage:PivotTo(CFrame.new(C + Vector3.new(0, 4, 20)))
        end
    end
    joueur.CharacterAdded:Connect(surPersonnage)
    if joueur.Character then
        task.spawn(surPersonnage, joueur.Character)
    end
end
Players.PlayerAdded:Connect(joueurArrive)
for _, joueur in ipairs(Players:GetPlayers()) do
    task.spawn(joueurArrive, joueur)
end
Players.PlayerRemoving:Connect(function(joueur)
    sauverJoueur(joueur)
    libererBase(joueur)
    etats[joueur] = nil
end)

-- tombé sous la map : retour à la base
task.spawn(function()
    while true do
        task.wait(1)
        for _, joueur in ipairs(Players:GetPlayers()) do
            local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
            local e = etats[joueur]
            if racine and e and racine.Position.Y < C.Y - 40 then
                joueur.Character:PivotTo(if e.base then e.base.apparition else CFrame.new(C + Vector3.new(0, 4, 20)))
            end
        end
    end
end)

print("🎵 Steal a Phonk : map construite, " .. #PHONKS .. " Phonks, " .. #bases .. " bases, prêt !")
