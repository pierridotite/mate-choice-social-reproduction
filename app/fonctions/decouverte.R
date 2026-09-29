# Onglet « Découvrir les données » : cinq graphiques interactifs qui résument le jeu de
# données, un par grand bloc de colonnes (protocole, inscription, préférences, fiche de
# notation, qualité). Les tables sont calculées une fois au lancement. Les graphiques 2D
# sont des ggplot convertis par plotly, la surface 3D est faite directement avec plotly.

genres_fr <- c(Femme = "Femmes", Homme = "Hommes")

pct <- function(x, precision = 1) {
  scales::label_percent(accuracy = precision, suffix = " %", decimal.mark = ",")(x)
}
oui_non <- function(x) if_else(x == 1, "oui", "non")

# --- Mise en forme ------------------------------------------------------------------

interactif <- function(p, legende = TRUE) {
  g <- ggplotly(p, tooltip = "text")
  g$x$data <- lapply(g$x$data, \(trace) {
    # ggplotly nomme les séries « (Femmes,1) » quand plusieurs aspects sont liés
    if (!is.null(trace$name)) trace$name <- sub("^\\((.*),[^,()]*\\)$", "\\1", trace$name)
    trace
  })
  g |>
    layout(showlegend = legende, hoverlabel = list(align = "left"),
           legend = list(orientation = "h", x = 0, y = 1.02, yanchor = "bottom",
                         title = list(text = ""))) |>
    config(displaylogo = FALSE, locale = "fr",
           modeBarButtonsToRemove = c("lasso2d", "select2d", "autoScale2d"))
}

# Encadré « À retenir » sous chaque graphique
a_retenir <- function(...) {
  div(class = "a-retenir", strong("À retenir"), tags$ul(lapply(list(...), tags$li)))
}

# Chiffre clé en tête de page
chiffre_cle <- function(valeur, libelle) {
  div(class = "chiffre-cle", div(class = "valeur", valeur), div(class = "libelle", libelle))
}

# --- Préparation --------------------------------------------------------------------

preparer_decouverte <- function(dates, participants, dictionnaire) {
  en_genre <- function(g) factor(genres_fr[as.character(g)], levels = genres_fr)

  participants <- participants |>
    mutate(
      genre = en_genre(gender),
      revenu_classe = cut(zip_median_income_2021, c(0, 50e3, 75e3, 100e3, 125e3, 150e3, 200e3, Inf),
                          right = FALSE,
                          labels = c("Moins de 50 k$", "50 à 75 k$", "75 à 100 k$", "100 à 125 k$",
                                     "125 à 150 k$", "150 à 200 k$", "200 k$ et plus")),
      # Les intérêts sont notés de 1 à 10 : les 8 valeurs au-delà sont des erreurs de saisie
      across(all_of(names(interets)), \(x) if_else(x <= 10, x, NA))
    )

  colonnes_brutes <- dictionnaire |>
    filter(!bloc %in% c("Variables dérivées (préparation)", "Agrégats par participant")) |>
    pull(nom)

  list(dates = mutate(dates, genre = en_genre(gender)),
       participants = participants,
       preferences = parts_preferences(participants),
       manquants = manquants_par_vague(dates, colonnes_brutes))
}

# Préférences déclarées : chaque question demande de répartir 100 points entre les six
# critères. Quelques vagues ont noté chaque critère sur 10 : on ramène toute réponse à une
# part du total, ce qui rend les vagues comparables.
parts_preferences <- function(participants) {
  codes <- expand_grid(question = c("1", "2", "4", "7"), moment = c("1", "s", "2", "3"))
  map(seq_len(nrow(codes)), \(i) {
    suffixe <- paste0(codes$question[i], "_", codes$moment[i])
    colonnes <- paste0(names(lab_notes), suffixe)
    if (!all(colonnes %in% names(participants))) return(NULL)
    participants |>
      select(iid, genre, all_of(colonnes)) |>
      pivot_longer(all_of(colonnes), names_to = "critere", values_to = "points") |>
      mutate(critere = str_remove(critere, fixed(suffixe))) |>
      filter(sum(!is.na(points)) == 6, sum(points, na.rm = TRUE) > 0, .by = iid) |>
      mutate(part = 100 * points / sum(points), .by = iid) |>
      mutate(question = codes$question[i], moment = codes$moment[i])
  }) |>
    list_rbind()
}

manquants_par_vague <- function(dates, colonnes) {
  dates |>
    summarise(across(all_of(setdiff(colonnes, "wave")), \(x) mean(is.na(x))), .by = wave) |>
    pivot_longer(-wave, names_to = "colonne", values_to = "manquants") |>
    mutate(bloc = bloc_colonne(colonne))
}

# --- 1. La structure : une soirée vue d'en haut ----------------------------------------

statuts_rencontre <- c("Match" = "#1baf7a", "Oui de la femme seulement" = col_femme,
                       "Oui de l'homme seulement" = col_homme, "Aucun oui" = "#e1e0d9")

# Une ligne par femme, une colonne par homme : chaque case est une rencontre
table_grille <- function(dates, vague) {
  dates |>
    filter(wave == vague, gender == "Femme") |>
    transmute(femme = id, homme = partner, dec_f = dec, dec_h = dec_o, attr_f = attr,
              attr_h = attr_o, rang = order)
}

graphique_grille <- function(dates, vague, tri) {
  g <- table_grille(dates, vague)
  # Ordre des lignes et des colonnes : numéro, oui reçus ou oui donnés
  ordonner <- function(num, recus, donnes) {
    ordre <- switch(tri, numero = order(num), recus = order(-recus, num),
                    donnes = order(-donnes, num))
    unique(num[ordre])
  }
  femmes <- g |> summarise(recus = sum(dec_h), donnes = sum(dec_f), .by = femme)
  hommes <- g |> summarise(recus = sum(dec_f), donnes = sum(dec_h), .by = homme)
  ordre_f <- ordonner(femmes$femme, femmes$recus, femmes$donnes)
  ordre_h <- ordonner(hommes$homme, hommes$recus, hommes$donnes)
  note <- \(x) if_else(is.na(x), "non renseignée", paste0(virgule(x, 0), "/10"))
  g <- g |>
    mutate(
      statut = factor(case_when(dec_f == 1 & dec_h == 1 ~ "Match", dec_f == 1 ~ "Oui de la femme seulement",
                                dec_h == 1 ~ "Oui de l'homme seulement", TRUE ~ "Aucun oui"),
                      levels = names(statuts_rencontre)),
      y = factor(paste0("F", femme), levels = rev(paste0("F", ordre_f))),
      x = factor(paste0("H", homme), levels = paste0("H", ordre_h)),
      texte = paste0("Femme F", femme, " et homme H", homme, " : ", tolower(statut),
                     "\nElle : ", oui_non(dec_f), " (attirance donnée : ", note(attr_f), ")",
                     "\nLui : ", oui_non(dec_h), " (attirance donnée : ", note(attr_h), ")",
                     "\n", rang, "e date de la soirée pour elle")
    )
  p <- ggplot(g, aes(x = x, y = y, fill = statut, text = texte)) +
    geom_tile(colour = "white", linewidth = 0.8) +
    scale_fill_manual(values = statuts_rencontre, name = NULL, drop = FALSE) +
    labs(x = "Hommes", y = "Femmes") +
    theme(panel.grid = element_blank())
  interactif(p)
}

resume_grille <- function(dates, vague) {
  g <- table_grille(dates, vague)
  paste0(
    "Vague ", vague, " : ", n_distinct(g$femme), " femmes et ", n_distinct(g$homme),
    " hommes, soit ", nrow(g), " rencontres et ", 2 * nrow(g), " lignes du tableau. Les femmes",
    " ont dit oui dans ", pct(mean(g$dec_f)), " des cas, les hommes dans ", pct(mean(g$dec_h)),
    ". ", sum(g$dec_f * g$dec_h), " matchs (", pct(mean(g$dec_f * g$dec_h)), " des rencontres)."
  )
}

# --- 2. Les participants ---------------------------------------------------------------

caracteristiques <- list(
  "Profil" = c(
    "Âge" = "age", "Origine déclarée" = "race", "Domaine d'études" = "field_cd",
    "Métier visé" = "career_c", "Objectif principal de la soirée" = "goal",
    "Fréquence des rendez-vous amoureux" = "date", "Fréquence des sorties" = "go_out",
    "Revenu médian du quartier d'enfance (Census)" = "revenu_classe"
  ),
  "Attitudes (de 1 à 10)" = c(
    "Importance d'avoir la même origine" = "imprace",
    "Importance d'avoir la même religion" = "imprelig",
    "Satisfaction attendue de la soirée" = "exphappy"
  ),
  "Centres d'intérêt (de 1 à 10)" = setNames(names(interets), str_to_sentence(interets))
)
libelle_caracteristique <- function(v) {
  tous <- unlist(unname(caracteristiques))
  names(tous)[tous == v]
}
# Modalités sans ordre naturel : triées par effectif
caracteristiques_a_trier <- c("race", "field_cd", "career_c", "goal")

# Répartition d'une variable par genre : barres horizontales pour une variable qualitative,
# verticales pour une note ou un âge
graphique_repartition <- function(d, variable, mesure, libelle) {
  x <- d[[variable]]
  vertical <- is.numeric(x)
  if (vertical) x <- factor(round(x))
  t <- tibble(genre = d$genre, modalite = x) |>
    filter(!is.na(modalite), !is.na(genre)) |>
    count(genre, modalite) |>
    complete(genre, modalite, fill = list(n = 0)) |>
    mutate(part = n / sum(n), .by = genre)
  if (variable %in% caracteristiques_a_trier) {
    t <- mutate(t, modalite = fct_reorder(modalite, n, .fun = sum, .desc = TRUE))
  }
  t <- t |>
    mutate(valeur = if (mesure == "part") part else n,
           texte = paste0(modalite, "\n", genre, " : ", n, " (", pct(part), " du groupe)"))
  if (!vertical) t <- mutate(t, modalite = fct_rev(modalite))
  p <- ggplot(t, aes(x = modalite, y = valeur, fill = genre, text = texte)) +
    geom_col(position = position_dodge(width = 0.85), width = 0.8) +
    scale_fill_manual(values = couleurs_genre, name = NULL) +
    scale_x_discrete(labels = \(v) str_wrap(v, 30)) +
    scale_y_continuous(labels = if (mesure == "part") pourcent else scales::label_number()) +
    labs(x = NULL, y = if (mesure == "part") "Part au sein de chaque genre" else "Effectif")
  p <- if (vertical) p + labs(x = libelle) else p + coord_flip()
  interactif(p)
}

resume_repartition <- function(d, variable) {
  x <- d[[variable]]
  absents <- sum(is.na(x))
  texte <- if (is.numeric(x)) {
    s <- tibble(genre = d$genre, x = x) |> drop_na() |>
      summarise(moyenne = mean(x), mediane = median(x), .by = genre) |> arrange(genre)
    paste0(s$genre, " : moyenne ", virgule(s$moyenne, 1), ", médiane ", virgule(s$mediane, 0),
           collapse = " ; ")
  } else {
    s <- tibble(genre = d$genre, x = as.character(x)) |> drop_na() |>
      count(genre, x) |> mutate(part = n / sum(n), .by = genre) |>
      slice_max(n, n = 1, by = genre, with_ties = FALSE) |> arrange(genre)
    paste0("Réponse la plus fréquente chez les ", tolower(s$genre), " : « ", s$x, " » (",
           pct(s$part), ")", collapse = " ; ")
  }
  paste0(texte, ". ", if (absents > 0) paste0(absents, " participants sans réponse ne sont pas représentés."))
}

# Croisement de deux variables : le graphique dépend de leur type
#   deux variables numériques   -> nuage de points, une droite de tendance par genre
#   numérique et qualitative    -> moyenne de la numérique pour chaque modalité, par genre
#   deux variables qualitatives -> carte de chaleur des répartitions, un panneau par genre
modalites_ordonnees <- function(x, variable) {
  if (variable %in% caracteristiques_a_trier) fct_infreq(x) else x
}

graphique_croisement <- function(d, v1, v2) {
  validate(need(v1 != v2, "Choisis deux variables différentes."))
  l1 <- libelle_caracteristique(v1)
  l2 <- libelle_caracteristique(v2)
  num1 <- is.numeric(d[[v1]])
  num2 <- is.numeric(d[[v2]])

  if (num1 && num2) {
    t <- d |>
      transmute(iid, genre, x = .data[[v1]], y = .data[[v2]]) |>
      drop_na() |>
      mutate(texte = paste0("Participant ", iid, " (", genre, ")\n", l1, " : ", nombre(x),
                            "\n", l2, " : ", nombre(y)))
    p <- ggplot(t, aes(x = x, y = y, colour = genre, text = texte)) +
      geom_point(position = position_jitter(width = 0.25, height = 0.25, seed = 1),
                 alpha = 0.6, size = 2) +
      geom_smooth(aes(group = genre, text = NULL), method = "lm", formula = y ~ x, se = FALSE,
                  linewidth = 1) +
      scale_colour_manual(values = couleurs_genre, name = NULL) +
      labs(x = l1, y = l2)
    return(interactif(p))
  }

  if (num1 != num2) {
    # La variable qualitative donne les groupes, la numérique la valeur moyenne
    quali <- if (num1) v2 else v1
    num <- if (num1) v1 else v2
    t <- d |>
      transmute(genre, groupe = modalites_ordonnees(.data[[quali]], quali), y = .data[[num]]) |>
      drop_na() |>
      summarise(moyenne = mean(y), et = sd(y), n = n(), .by = c(genre, groupe)) |>
      filter(n >= 5) |>
      mutate(bas = moyenne - qt(0.975, n - 1) * et / sqrt(n),
             haut = moyenne + qt(0.975, n - 1) * et / sqrt(n),
             groupe = fct_rev(fct_drop(groupe)),
             texte = paste0(groupe, "\n", genre, " : moyenne ", virgule(moyenne, 1), " (IC ",
                            virgule(bas, 1), " à ", virgule(haut, 1), ")\n", n, " participants"))
    p <- ggplot(t, aes(x = groupe, y = moyenne, colour = genre, text = texte)) +
      geom_errorbar(aes(ymin = bas, ymax = haut), width = 0, linewidth = 0.8,
                    position = position_dodge(width = 0.6)) +
      geom_point(size = 2.8, position = position_dodge(width = 0.6)) +
      scale_colour_manual(values = couleurs_genre, name = NULL) +
      scale_x_discrete(labels = \(v) str_wrap(v, 30)) +
      coord_flip() +
      labs(x = NULL, y = paste("Moyenne :", tolower(libelle_caracteristique(num))))
    return(interactif(p))
  }

  # Deux variables qualitatives : part de chaque réponse en colonne, pour chaque ligne
  t <- d |>
    transmute(genre, a = modalites_ordonnees(.data[[v1]], v1),
              b = modalites_ordonnees(.data[[v2]], v2)) |>
    drop_na() |>
    count(genre, a, b) |>
    complete(genre, a, b, fill = list(n = 0)) |>
    mutate(total = sum(n), part = if_else(total > 0, n / total, NA), .by = c(genre, a)) |>
    mutate(a = fct_rev(a),
           etiquette = if_else(is.na(part) | n == 0, "", str_remove(pct(part), " %")),
           encre = if_else(!is.na(part) & part > 0.5, "white", col_dark),
           texte = paste0(genre, " — ", a, "\n", b, " : ", n, " sur ", total, " (",
                          if_else(is.na(part), "–", pct(part)), ")"))
  p <- ggplot(t, aes(x = b, y = a, fill = part, text = texte)) +
    geom_tile(colour = "white", linewidth = 0.6) +
    geom_text(aes(label = etiquette, colour = encre), size = 2.6) +
    scale_colour_identity() +
    scale_fill_gradient(low = "#cde2fb", high = "#104281", labels = pourcent, limits = c(0, 1),
                        na.value = "white", name = "Part de la ligne") +
    scale_x_discrete(labels = \(v) str_wrap(v, 16)) +
    scale_y_discrete(labels = \(v) str_wrap(v, 30)) +
    facet_wrap(vars(genre)) +
    # Libellés inclinés : le titre de l'axe horizontal est donné sous le graphique
    labs(x = NULL, y = l1) +
    theme(panel.grid = element_blank(), axis.text.x = element_text(angle = 40, hjust = 1))
  interactif(p)
}

resume_croisement <- function(d, v1, v2) {
  if (v1 == v2) return("")
  num1 <- is.numeric(d[[v1]])
  num2 <- is.numeric(d[[v2]])
  if (num1 && num2) {
    r <- d |>
      transmute(genre, x = .data[[v1]], y = .data[[v2]]) |>
      drop_na() |>
      summarise(r = cor(x, y), n = n(), .by = genre) |>
      arrange(genre)
    return(paste0("Corrélation entre les deux variables : ",
                  paste0(tolower(r$genre), " ", virgule(r$r, 2), " (", r$n, " participants)",
                         collapse = ", "),
                  ". Les points sont légèrement décalés pour ne pas se superposer."))
  }
  if (num1 != num2) {
    return(paste("Chaque point est une moyenne, avec son intervalle de confiance à 95 %. Les",
                 "groupes de moins de 5 participants ne sont pas affichés."))
  }
  paste0("En ligne : ", tolower(libelle_caracteristique(v1)), " ; en colonne : ",
         tolower(libelle_caracteristique(v2)), ". Chaque ligne se lit séparément : parmi les ",
         "participants d'une modalité en ligne, part de chaque modalité en colonne. Survole une ",
         "case pour lire les effectifs.")
}

# --- 3. Ce qu'ils disent rechercher ----------------------------------------------------

questions_pref <- c("Ce qui compte pour moi" = "1",
                    "Ce que l'autre sexe recherche, selon moi" = "2",
                    "Ce que recherchent les gens de mon sexe, selon moi" = "4",
                    "Ce qui a vraiment compté dans mes choix, selon moi" = "7")
moments_pref <- c("À l'inscription" = "1", "À mi-soirée" = "s", "Le lendemain" = "2",
                  "3 à 4 semaines après" = "3")

criteres_facteur <- function(x) factor(lab_notes[x], levels = rev(lab_notes))

graphique_preferences <- function(pref, q, m) {
  d <- filter(pref, question == q, moment == m)
  validate(need(nrow(d) > 0, paste(
    "Cette question n'a pas été posée à ce moment-là. Toutes les questions sont posées à",
    "l'inscription, sauf « ce qui a vraiment compté », posée le lendemain et 3 à 4 semaines après."
  )))
  s <- d |>
    summarise(moyenne = mean(part), et = sd(part), n = n(), .by = c(critere, genre)) |>
    mutate(bas = moyenne - qt(0.975, n - 1) * et / sqrt(n),
           haut = moyenne + qt(0.975, n - 1) * et / sqrt(n),
           critere = criteres_facteur(critere),
           texte = paste0(critere, "\n", genre, " : ", virgule(moyenne, 1), " points sur 100",
                          "\nIC à 95 % : ", virgule(bas, 1), " à ", virgule(haut, 1),
                          "\n", n, " répondants"))
  p <- ggplot(s, aes(x = critere, y = moyenne, fill = genre, text = texte)) +
    geom_col(position = position_dodge(width = 0.85), width = 0.8) +
    geom_errorbar(aes(ymin = bas, ymax = haut, group = genre), position = position_dodge(width = 0.85),
                  width = 0, colour = col_dark, linewidth = 0.5) +
    scale_fill_manual(values = couleurs_genre, name = NULL) +
    coord_flip() +
    labs(x = NULL, y = "Points attribués sur 100 (moyenne)")
  interactif(p)
}

# --- 4. Ce qui les fait dire oui -------------------------------------------------------

notes_fiche <- c(setNames(names(lab_notes), lab_notes),
                 "Appréciation globale" = "like",
                 "Probabilité estimée que l'autre dise oui" = "prob")

# Une demi-note (6,5) est rattachée à la note entière supérieure
arrondir_note <- function(x) floor(x + 0.5)

graphique_taux_note <- function(dates, note, n_min = 20) {
  d <- dates |>
    filter(!is.na(.data[[note]])) |>
    mutate(valeur = arrondir_note(.data[[note]])) |>
    summarise(taux = mean(dec), n = n(), .by = c(genre, valeur)) |>
    filter(n >= n_min) |>
    arrange(valeur) |>
    mutate(texte = paste0(genre, ", note ", valeur, " : ", pct(taux), " de oui (", n, " décisions)"))
  p <- ggplot(d, aes(x = valeur, y = taux, colour = genre, text = texte)) +
    geom_hline(yintercept = mean(dates$dec), linetype = "dashed", colour = col_muted) +
    geom_line(aes(group = genre), linewidth = 0.9) +
    geom_point(aes(size = n)) +
    scale_size_area(max_size = 6, guide = "none") +
    scale_colour_manual(values = couleurs_genre, name = NULL) +
    scale_x_continuous(breaks = 0:10) +
    scale_y_continuous(labels = pourcent, limits = c(0, 1)) +
    labs(x = paste("Note donnée au partenaire :", tolower(names(notes_fiche)[notes_fiche == note])),
         y = "Taux de oui")
  interactif(p)
}

# Surface 3D : probabilité de oui selon deux notes données au même partenaire. Les taux
# observés case par case sont trop bruités et trop lacunaires (les deux notes vont
# ensemble, beaucoup de combinaisons n'existent pas) : la surface est lissée par une
# régression logistique quadratique, et les taux observés sont affichés en points.
graphique_surface <- function(dates, note_x, note_y, genre_choisi, n_min = 15) {
  validate(need(note_x != note_y, "Choisis deux notes différentes."))
  d <- dates |>
    filter(genre == genre_choisi, !is.na(.data[[note_x]]), !is.na(.data[[note_y]])) |>
    transmute(dec, x = .data[[note_x]], y = .data[[note_y]])
  modele <- glm(dec ~ x + y + I(x^2) + I(y^2) + x:y, family = binomial, data = d)
  observes <- d |>
    mutate(x = arrondir_note(x), y = arrondir_note(y)) |>
    summarise(taux = mean(dec), n = n(), .by = c(x, y))
  # Grille tous les demi-points ; pas de surface là où il n'y a presque pas de décisions
  pas <- seq(0, 10, 0.5)
  grille <- expand_grid(y = pas, x = pas)
  voisins <- map2_dbl(grille$x, grille$y, \(gx, gy) {
    sum(observes$n[abs(observes$x - gx) <= 1 & abs(observes$y - gy) <= 1])
  })
  grille$proba <- predict(modele, newdata = grille, type = "response")
  grille$proba[voisins < 30] <- NA
  noms <- setNames(names(notes_fiche), notes_fiche)
  z <- matrix(grille$proba, nrow = length(pas), byrow = TRUE)
  texte <- matrix(paste0(noms[[note_x]], " : ", virgule(grille$x, 1), "\n", noms[[note_y]], " : ",
                         virgule(grille$y, 1), "\nProbabilité de oui estimée : ", pct(grille$proba)),
                  nrow = length(pas), byrow = TRUE)
  points <- observes |>
    filter(n >= n_min) |>
    mutate(texte = paste0(noms[[note_x]], " : ", x, "\n", noms[[note_y]], " : ", y,
                          "\nTaux de oui observé : ", pct(taux), " (", n, " décisions)"))
  couleur <- if (genre_choisi == "Femmes") col_femme else col_homme
  plot_ly() |>
    add_surface(x = pas, y = pas, z = z, text = texte, hoverinfo = "text", opacity = 0.85,
                colorscale = list(c(0, "#f0efec"), c(1, couleur)), cmin = 0, cmax = 1,
                colorbar = list(title = "Probabilité<br>de oui", tickformat = ".0%", len = 0.6),
                name = "Surface lissée") |>
    add_trace(data = points, x = ~x, y = ~y, z = ~taux, text = ~texte, hoverinfo = "text",
              type = "scatter3d", mode = "markers", name = "Taux observés",
              marker = list(size = ~pmin(3 + sqrt(n) / 3, 10), color = col_dark, opacity = 0.8)) |>
    layout(showlegend = FALSE, margin = list(l = 0, r = 0, b = 0, t = 10),
           scene = list(xaxis = list(title = noms[[note_x]], range = c(0, 10)),
                        yaxis = list(title = noms[[note_y]], range = c(0, 10)),
                        zaxis = list(title = "Oui", tickformat = ".0%", range = c(0, 1)),
                        camera = list(eye = list(x = -1.5, y = -1.7, z = 0.8)))) |>
    config(displaylogo = FALSE, locale = "fr")
}

# --- 5. Ce qui est fiable --------------------------------------------------------------

graphique_manquants <- function(manquants) {
  d <- manquants |>
    summarise(manquants = mean(manquants), colonnes = n(), .by = c(wave, bloc)) |>
    mutate(bloc = fct_reorder(bloc, manquants, .desc = TRUE),
           texte = paste0("Vague ", wave, "\n", bloc, "\n", pct(manquants),
                          " de valeurs manquantes en moyenne (", colonnes, " colonnes)"),
           etiquette = pct(manquants), encre = if_else(manquants > 0.55, "white", col_dark))
  p <- ggplot(d, aes(x = wave, y = bloc, fill = manquants, text = texte)) +
    geom_tile(colour = "white", linewidth = 0.8) +
    geom_text(aes(label = str_remove(etiquette, " %"), colour = encre), size = 2.6) +
    scale_colour_identity() +
    scale_fill_gradient(low = "#cde2fb", high = "#104281", labels = pourcent, limits = c(0, 1),
                        name = "Manquants") +
    scale_y_discrete(labels = \(v) str_wrap(v, 28)) +
    labs(x = "Vague (soirée)", y = NULL) +
    theme(panel.grid = element_blank())
  interactif(p)
}
