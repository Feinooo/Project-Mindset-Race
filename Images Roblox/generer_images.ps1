param([string]$Dossier)
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force $Dossier | Out-Null

function Couleur($a, $r, $g, $b) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
$ORANGE = @(255, 150, 30); $VIOLET = @(170, 80, 255); $BLEU = @(60, 140, 255); $ROUGE = @(230, 40, 60); $OR = @(255, 215, 80)

function Pinceau($c, $a) { New-Object System.Drawing.SolidBrush (Couleur $a $c[0] $c[1] $c[2]) }

# ---- un halo flou : plein de cercles transparents empilés ----
function Halo($g, $cx, $cy, $rayon, $c, $force) {
    for ($i = 24; $i -ge 1; $i--) {
        $r = $rayon * $i / 24
        $a = [int]([Math]::Min(255, $force * (1 - $i / 25) * 0.9))
        $b = Pinceau $c ([Math]::Max(1, [int]($a / 3.5)))
        $g.FillEllipse($b, $cx - $r, $cy - $r, 2 * $r, 2 * $r)
        $b.Dispose()
    }
}

# ---- texte avec contour + dégradé + lueur ----
function TitreNeon($g, $texte, $police, $taille, $x, $y, $largeur, $couleurs, $epaisseurContour, $lueur) {
    $chemin = New-Object System.Drawing.Drawing2D.GraphicsPath
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $famille = New-Object System.Drawing.FontFamily $police
    $chemin.AddString($texte, $famille, [int][System.Drawing.FontStyle]::Bold, $taille, ([System.Drawing.RectangleF]::new($x, $y, $largeur, $taille * 1.4)), $format)
    # lueur
    for ($i = 6; $i -ge 1; $i--) {
        $p = [System.Drawing.Pen]::new((Couleur ([int](18 * $lueur)) 200 120 255), ($epaisseurContour + $i * 7))
        $p.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $g.DrawPath($p, $chemin); $p.Dispose()
    }
    # contour sombre épais
    $p = [System.Drawing.Pen]::new((Couleur 255 12 8 24), $epaisseurContour)
    $p.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawPath($p, $chemin); $p.Dispose()
    # remplissage en dégradé (les 4 couleurs des états d'esprit)
    $boite = $chemin.GetBounds()
    $deg = [System.Drawing.Drawing2D.LinearGradientBrush]::new($boite, (Couleur 255 255 255 255), (Couleur 255 0 0 0), 0.0)
    $blend = New-Object System.Drawing.Drawing2D.ColorBlend($couleurs.Count)
    $cols = @(); $pos = @()
    for ($i = 0; $i -lt $couleurs.Count; $i++) {
        $c = $couleurs[$i]; $cols += (Couleur 255 $c[0] $c[1] $c[2]); $pos += [single]($i / ($couleurs.Count - 1))
    }
    $blend.Colors = $cols; $blend.Positions = $pos
    $deg.InterpolationColors = $blend
    $g.FillPath($deg, $chemin)
    # reflet blanc sur le haut des lettres
    $g.SetClip($chemin)
    $reflet = [System.Drawing.Drawing2D.LinearGradientBrush]::new(([System.Drawing.RectangleF]::new($boite.X, $boite.Y, $boite.Width, $boite.Height / 2)), (Couleur 110 255 255 255), (Couleur 0 255 255 255), 90.0)
    $g.FillRectangle($reflet, $boite.X, $boite.Y, $boite.Width, $boite.Height / 2)
    $g.ResetClip()
    $deg.Dispose(); $reflet.Dispose(); $chemin.Dispose()
}

# ---- un cercle de rythme néon ----
function CercleRythme($g, $cx, $cy, $r, $c) {
    Halo $g $cx $cy ($r * 2.2) $c 200
    $b = Pinceau @([int]($c[0] * 0.2), [int]($c[1] * 0.2), [int]($c[2] * 0.2)) 235
    $g.FillEllipse($b, $cx - $r, $cy - $r, 2 * $r, 2 * $r); $b.Dispose()
    $p = [System.Drawing.Pen]::new((Couleur 255 ([Math]::Min(255, $c[0] + 40)) ([Math]::Min(255, $c[1] + 40)) ([Math]::Min(255, $c[2] + 40))), ($r * 0.16))
    $g.DrawEllipse($p, $cx - $r, $cy - $r, 2 * $r, 2 * $r); $p.Dispose()
    $p = [System.Drawing.Pen]::new((Couleur 150 $c[0] $c[1] $c[2]), ($r * 0.05))
    $g.DrawEllipse($p, $cx - $r * 1.7, $cy - $r * 1.7, 3.4 * $r, 3.4 * $r); $p.Dispose()
    $b = Pinceau @(255, 245, 230) 255
    $g.FillEllipse($b, $cx - $r * 0.25, $cy - $r * 0.25, $r * 0.5, $r * 0.5); $b.Dispose()
}

# ---- un avatar façon Roblox (blocs), en train de monter une marche ----
function Avatar($g, $x, $y, $echelle, $couleurTorse, $angleJambe) {
    $etat = $g.Save()
    $g.TranslateTransform($x, $y)
    $g.ScaleTransform($echelle, $echelle)
    $peau = Pinceau @(255, 205, 150) 255
    $torse = Pinceau $couleurTorse 255
    $pantalon = Pinceau @(30, 34, 60) 255
    $contour = [System.Drawing.Pen]::new((Couleur 255 10 8 20), 4)
    function Bloc($pinceau, $bx, $by, $bw, $bh, $angle, $ox, $oy) {
        $e = $g.Save()
        $g.TranslateTransform($ox, $oy); $g.RotateTransform($angle); $g.TranslateTransform(-$ox, -$oy)
        $g.FillRectangle($pinceau, $bx, $by, $bw, $bh); $g.DrawRectangle($contour, $bx, $by, $bw, $bh)
        $g.Restore($e)
    }
    # jambe arrière, bras arrière
    Bloc $pantalon -18 40 26 70 (-15) -5 40
    Bloc $torse -48 -40 22 70 (30) -37 -35
    # torse
    Bloc $torse -30 -45 60 88 0 0 0
    # jambe avant (levée sur la marche)
    Bloc $pantalon 2 40 26 70 $angleJambe 15 40
    # bras avant (vers le haut : il gagne !)
    Bloc $torse 26 -40 22 70 (-150) 37 -35
    # tête
    $g.FillRectangle($peau, -24, -95, 48, 48); $g.DrawRectangle($contour, -24, -95, 48, 48)
    $yeux = Pinceau @(20, 20, 30) 255
    $g.FillRectangle($yeux, 4, -78, 7, 9); $g.FillRectangle($yeux, 15, -78, 7, 9)
    $p = [System.Drawing.Pen]::new((Couleur 255 20 20 30), 3)
    $g.DrawArc($p, 4, -72, 18, 12, 10, 160); $p.Dispose()
    $peau.Dispose(); $torse.Dispose(); $pantalon.Dispose(); $yeux.Dispose(); $contour.Dispose()
    $g.Restore($etat)
}

function Dessiner($largeur, $hauteur, $fichier, $estIcone) {
    $bmp = [System.Drawing.Bitmap]::new($largeur, $hauteur)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $W = $largeur; $H = $hauteur
    $k = $W / 1920.0 # échelle (l'icône est plus petite)
    if ($estIcone) { $k = $W / 900.0 }

    # fond : nuit violette, plus claire derrière le titre
    $fond = [System.Drawing.Drawing2D.LinearGradientBrush]::new(([System.Drawing.Rectangle]::new(0, 0, $W, $H)), (Couleur 255 40 12 70), (Couleur 255 6 4 14), 90.0)
    $g.FillRectangle($fond, 0, 0, $W, $H); $fond.Dispose()
    Halo $g ($W * 0.62) ($H * 0.42) ($W * 0.55) $VIOLET 160
    Halo $g ($W * 0.15) ($H * 0.9) ($W * 0.35) $ORANGE 110
    Halo $g ($W * 0.95) ($H * 0.15) ($W * 0.3) $BLEU 110

    # rayons de lumière derrière le personnage
    $centreX = $W * 0.58; $centreY = $H * 0.5
    if ($estIcone) { $centreX = $W * 0.5; $centreY = $H * 0.55 }
    for ($i = 0; $i -lt 16; $i++) {
        $angle = $i * [Math]::PI * 2 / 16
        $pts = @(
            ([System.Drawing.PointF]::new($centreX, $centreY)),
            ([System.Drawing.PointF]::new(($centreX + [Math]::Cos($angle - 0.07) * $W * 1.2), ($centreY + [Math]::Sin($angle - 0.07) * $W * 1.2))),
            ([System.Drawing.PointF]::new(($centreX + [Math]::Cos($angle + 0.07) * $W * 1.2), ($centreY + [Math]::Sin($angle + 0.07) * $W * 1.2)))
        )
        $b = Pinceau @(255, 220, 150) 14
        $g.FillPolygon($b, $pts); $b.Dispose()
    }

    # poussière d'aura
    $rnd = New-Object System.Random 7
    for ($i = 0; $i -lt 160; $i++) {
        $px = $rnd.NextDouble() * $W; $py = $rnd.NextDouble() * $H; $pr = (1 + $rnd.NextDouble() * 3) * $k * 1.5
        $b = Pinceau @(220, 210, 255) ([int](60 + $rnd.NextDouble() * 160))
        $g.FillEllipse($b, $px, $py, $pr, $pr); $b.Dispose()
    }

    # 🪜 le grand escalier néon qui monte vers la droite (et sort de l'image : il est infini)
    $marche = 120 * $k; $haut = 64 * $k
    $x0 = -60 * $k; $y0 = $H + 300 * $k
    if ($estIcone) { $x0 = -60 * $k; $y0 = $H + 40 * $k }
    $couleursLignes = @($ORANGE, $VIOLET, $BLEU, $ROUGE)
    for ($i = 0; $i -lt 26; $i++) {
        $sx = $x0 + $i * $marche; $sy = $y0 - $i * $haut
        if ($sx -gt $W + 200) { break }
        # face avant de la marche (dégradé blanc → gris)
        $rect = [System.Drawing.RectangleF]::new($sx, $sy, $marche + 1, ($H - $sy + 200 * $k))
        $deg = [System.Drawing.Drawing2D.LinearGradientBrush]::new($rect, (Couleur 255 236 236 248), (Couleur 255 120 110 160), 90.0)
        $g.FillRectangle($deg, $rect); $deg.Dispose()
        # dessus de la marche (plus clair)
        $b = Pinceau @(255, 255, 255) 255
        $g.FillRectangle($b, $sx, $sy, $marche + 1, 10 * $k); $b.Dispose()
        # tous les 10 : une marche dorée
        if ($i % 10 -eq 0 -and $i -gt 0) {
            $b = Pinceau $OR 255; $g.FillRectangle($b, $sx, $sy, $marche + 1, 18 * $k); $b.Dispose()
        }
    }
    # ligne néon le long du bord
    $p = [System.Drawing.Pen]::new((Couleur 255 255 215 80), (7 * $k))
    $g.DrawLine($p, [single]$x0, [single]$y0, [single]($x0 + 26 * $marche), [single]($y0 - 26 * $haut)); $p.Dispose()
    for ($j = 1; $j -le 3; $j++) {
        $p = [System.Drawing.Pen]::new((Couleur 40 255 215 80), (7 * $k + $j * 12 * $k))
        $g.DrawLine($p, [single]$x0, [single]$y0, [single]($x0 + 26 * $marche), [single]($y0 - 26 * $haut)); $p.Dispose()
    }

    # dalles de lumière sous les pas
    foreach ($n in $(if ($estIcone) { @(1, 2, 3) } else { @(7, 8, 9) })) {
        $c = $couleursLignes[$n % 4]
        $sx = $x0 + $n * $marche; $sy = $y0 - $n * $haut
        Halo $g ($sx + $marche / 2) $sy ($marche * 0.9) $c 170
    }

    # 🧍 le grimpeur avec son aura (sur la marche 9 environ)
    $n = 9; $echelle = 1.9 * $k
    if ($estIcone) { $n = 3; $echelle = 1.5 * $k }
    # les pieds posés sur la marche n (les jambes descendent à 110 sous le centre du torse)
    $ax = $x0 + ($n + 0.5) * $marche; $ay = $y0 - $n * $haut - 108 * $echelle
    Halo $g $ax ($ay - 20 * $echelle) (190 * $echelle) $OR 255
    Halo $g $ax ($ay - 20 * $echelle) (120 * $echelle) $VIOLET 255
    Avatar $g $ax $ay $echelle $VIOLET (-60)

    # un 2e grimpeur derrière (plus petit), pour montrer que c'est une course
    if (-not $estIcone) {
        $n2 = 6; $e2 = 1.35 * $k
        $bx = $x0 + ($n2 + 0.5) * $marche; $by = $y0 - $n2 * $haut - 108 * $e2
        Halo $g $bx ($by - 20 * $e2) (150 * $e2) $ORANGE 230
        Avatar $g $bx $by $e2 $ORANGE (-35)
    }

    # 🎯 les cercles de rythme qui flottent
    if ($estIcone) {
        CercleRythme $g ($W * 0.8) ($H * 0.2) (48 * $k) $BLEU
        CercleRythme $g ($W * 0.17) ($H * 0.36) (36 * $k) $ORANGE
    } else {
        CercleRythme $g ($W * 0.86) ($H * 0.58) (62 * $k) $BLEU
        CercleRythme $g ($W * 0.74) ($H * 0.82) (44 * $k) $ROUGE
        CercleRythme $g ($W * 0.92) ($H * 0.86) (34 * $k) $ORANGE
        # « PERFECT! »
        TitreNeon $g "PERFECT!" "Arial Black" (54 * $k) ($W * 0.68) ($H * 0.39) ($W * 0.36) @($OR, @(255, 255, 200)) (9 * $k) 0.6
    }

    # 🏷️ le titre
    $couleursTitre = @($ORANGE, $VIOLET, $BLEU, $ROUGE)
    if ($estIcone) {
        TitreNeon $g "MINDSET" "Arial Black" (128 * $k) 0 (18 * $k) $W $couleursTitre (22 * $k) 1
        TitreNeon $g "STAIRS" "Arial Black" (128 * $k) 0 (160 * $k) $W $couleursTitre (22 * $k) 1
    } else {
        TitreNeon $g "MINDSET STAIRS" "Arial Black" (150 * $k) ($W * 0.02) ($H * 0.04) ($W * 0.96) $couleursTitre (24 * $k) 1
        # sous-titre dans un bandeau
        $bandeau = New-Object System.Drawing.Drawing2D.GraphicsPath
        $bx = $W * 0.2; $by = $H * 0.27; $bw = $W * 0.6; $bh = 78 * $k
        $bandeau.AddArc($bx, $by, $bh, $bh, 90, 180); $bandeau.AddArc($bx + $bw - $bh, $by, $bh, $bh, 270, 180); $bandeau.CloseFigure()
        $b = Pinceau @(10, 8, 22) 225; $g.FillPath($b, $bandeau); $b.Dispose()
        $p = [System.Drawing.Pen]::new((Couleur 255 255 215 80), (4 * $k)); $g.DrawPath($p, $bandeau); $p.Dispose()
        $police = [System.Drawing.Font]::new("Arial Black", [single](30 * $k))
        $format = New-Object System.Drawing.StringFormat
        $format.Alignment = [System.Drawing.StringAlignment]::Center; $format.LineAlignment = [System.Drawing.StringAlignment]::Center
        $mots = @(@("EGO", $VIOLET), @("vs", @(200, 200, 215)), @("DISCIPLINE", $BLEU), @("vs", @(200, 200, 215)), @("MOTIVATION", $ORANGE), @("vs", @(200, 200, 215)), @("OBSESSION", $ROUGE))
        # on mesure pour centrer la ligne de mots colorés
        $total = 0; $tailles = @()
        foreach ($m in $mots) { $t = $g.MeasureString($m[0] + " ", $police).Width; $tailles += $t; $total += $t }
        $cx = $W / 2 - $total / 2
        for ($i = 0; $i -lt $mots.Count; $i++) {
            $b = Pinceau $mots[$i][1] 255
            $g.DrawString($mots[$i][0], $police, $b, [single]$cx, [single]($by + $bh / 2 - 26 * $k)); $b.Dispose()
            $cx += $tailles[$i]
        }
        # badge « CLIMB FOREVER »
        $badge = New-Object System.Drawing.Drawing2D.GraphicsPath
        $gx = $W * 0.035; $gy = $H * 0.78; $gw = 600 * $k; $gh = 110 * $k
        $badge.AddArc($gx, $gy, 40 * $k, 40 * $k, 180, 90); $badge.AddArc($gx + $gw - 40 * $k, $gy, 40 * $k, 40 * $k, 270, 90)
        $badge.AddArc($gx + $gw - 40 * $k, $gy + $gh - 40 * $k, 40 * $k, 40 * $k, 0, 90); $badge.AddArc($gx, $gy + $gh - 40 * $k, 40 * $k, 40 * $k, 90, 90); $badge.CloseFigure()
        $b = Pinceau $OR 255; $g.FillPath($b, $badge); $b.Dispose()
        $p = [System.Drawing.Pen]::new((Couleur 255 12 8 24), (6 * $k)); $g.DrawPath($p, $badge); $p.Dispose()
        $police2 = [System.Drawing.Font]::new("Arial Black", [single](40 * $k))
        $b = Pinceau @(20, 12, 30) 255
        $g.DrawString("CLIMB FOREVER", $police2, $b, ([System.Drawing.RectangleF]::new($gx, $gy, $gw, $gh)), $format); $b.Dispose()
    }

    # vignette sombre sur les bords
    $chemin = New-Object System.Drawing.Drawing2D.GraphicsPath
    $chemin.AddEllipse(-$W * 0.25, -$H * 0.3, $W * 1.5, $H * 1.6)
    $vignette = [System.Drawing.Drawing2D.PathGradientBrush]::new($chemin)
    $vignette.CenterColor = (Couleur 0 0 0 0)
    $vignette.SurroundColors = @((Couleur 170 0 0 0))
    $g.FillRectangle($vignette, 0, 0, $W, $H)

    $bmp.Save($fichier, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Output "OK $fichier"
}

Dessiner 1920 1080 (Join-Path $Dossier "Miniature_1920x1080.png") $false
Dessiner 512 512 (Join-Path $Dossier "Icone_512x512.png") $true
