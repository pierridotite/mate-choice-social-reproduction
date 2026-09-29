# Onglet « Prédire un match ». Deux régressions logistiques, une par genre, prédisent la
# décision de chacun à partir de son profil, de celui du partenaire, de l'écart de milieu
# social entre les deux et, après la rencontre, des notes qu'il lui donne. La probabilité
# de match est le produit des deux probabilités : l'exploration n'a montré aucune
# réciprocité entre les deux décisions, on les traite donc comme indépendantes.
#
# Les modèles sont ajustés sur l'échantillon d'analyse du projet (revenu du quartier connu
# des deux côtés). Chacun existe avec et sans l'écart de milieu social, pour mesurer ce que
# cet écart apporte à la prédiction. Les performances sont mesurées par validation croisée
# par soirée : on prédit chaque soirée avec un modèle ajusté sur les vingt autres.

criteres_notes <- names(lab_notes)

formule_profil <- dec ~ age_juge + ecart_age + I(ecart_age^2) + meme_origine + origine + int_corr
formule_complet <- update(formule_profil, ~ . + attr + sinc + intel + fun + amb + shar)
formules_prediction <- list(
  profil = formule_profil,
  complet = formule_complet,
  profil_social = update(formule_profil, ~ . + ecart_revenu),
  complet_social = update(formule_complet, ~ . + ecart_revenu)
)

# Termes du modèle regroupés en facteurs lisibles ; l'écart social est mis en avant
terme_social <- "★ Écart de milieu social"
termes_lisibles <- c(
  ecart_revenu = terme_social,
  age_juge = "Son âge", ecart_age = "Écart d'âge", "I(ecart_age^2)" = "Écart d'âge",
  meme_origine = "Même origine", origine = "Son origine", int_corr = "Intérêts communs",
  attr = "Attirance donnée", sinc = "Sincérité donnée", intel = "Intelligence donnée",
  fun = "Humour donné", amb = "Ambition donnée", shar = "Intérêts communs (note)"
)

# Écart de revenu entre les quartiers, en doublements : 1 = un revenu deux fois plus élevé
ecart_doublements <- function(revenu_a, revenu_b) abs(log2(revenu_b / revenu_a))
en_rapport <- function(doublements) paste0("× ", virgule(2^doublements, 1))

# Aire sous la courbe ROC : probabilité qu'un cas positif reçoive un score plus élevé
# qu'un cas négatif (0,5 = hasard, 1 = parfait)
aire_roc <- function(p, y) {
  r <- rank(p)
  n1 <- sum(y == 1)
  n0 <- sum(y == 0)
  (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

preparer_prediction <- function(dates) {
  # Une ligne par décision, avec toutes les informations connues, revenu compris
  d <- dates |>
    transmute(iid, pid, wave, id, partner, genre = gender, dec, dec_o, match,
              age_juge = age, age_partenaire = age_o, ecart_age = age_o - age,
              meme_origine = samerace, origine = relevel(race, "Blanc"), origine_partenaire = race_o,
              int_corr, attr, sinc, intel, fun, amb, shar,
              revenu_juge = zip_median_income_2021, revenu_partenaire = zip_median_income_2021_o,
              ecart_revenu = ecart_doublements(revenu_juge, revenu_partenaire)) |>
    drop_na()

  ajuster <- function(donnees) {
    map(set_names(c("Femme", "Homme")), \(g) {
      map(formules_prediction, \(f) glm(f, family = binomial, data = filter(donnees, genre == g)))
    })
  }

  # Validation croisée par soirée
  validation <- map(levels(droplevels(d$wave)), \(w) {
    modeles <- ajuster(filter(d, wave != w))
    test <- filter(d, wave == w)
    map(c("Femme", "Homme"), \(g) {
      t <- filter(test, genre == g)
      if (nrow(t) == 0) return(NULL)
      for (m in names(formules_prediction)) {
        t[[paste0("p_", m)]] <- predict(modeles[[g]][[m]], t, type = "response")
      }
      t
    }) |>
      list_rbind()
  }) |>
    list_rbind()

  # Couples dont les deux décisions sont connues : ligne de la femme + ligne de l'homme
  couples <- validation |>
    filter(genre == "Femme") |>
    select(femme = iid, homme = pid, match, starts_with("p_")) |>
    inner_join(validation |>
                 filter(genre == "Homme") |>
                 select(homme = iid, femme = pid, starts_with("p_")),
               by = c("femme", "homme"), suffix = c("_f", "_h"))
  for (m in names(formules_prediction)) {
    couples[[paste0("m_", m)]] <- couples[[paste0("p_", m, "_f")]] * couples[[paste0("p_", m, "_h")]]
  }

  performance <- tibble(
    modele = names(formules_prediction),
    auc_decision = map_dbl(modele, \(m) aire_roc(validation[[paste0("p_", m)]], validation$dec)),
    auc_match = map_dbl(modele, \(m) aire_roc(couples[[paste0("m_", m)]], couples$match))
  )

  calibration <- couples |>
    select(match, m_profil_social, m_complet_social) |>
    pivot_longer(-match, names_to = "modele", values_to = "prediction", names_prefix = "m_") |>
    mutate(modele = str_remove(modele, "_social"), decile = ntile(prediction, 10), .by = modele) |>
    summarise(predit = mean(prediction), observe = mean(match), n = n(), .by = c(modele, decile))

  modeles <- ajuster(d)
  # Effet de l'écart social (un doublement) sur la cote du oui de chacun, avec son IC
  effet_social <- map(c("profil", "complet"), \(type) {
    map(c("Femme", "Homme"), \(g) {
      s <- summary(modeles[[g]][[paste0(type, "_social")]])$coefficients["ecart_revenu", ]
      tibble(modele = type, genre = g, rc = exp(s[[1]]), bas = exp(s[[1]] - 1.96 * s[[2]]),
             haut = exp(s[[1]] + 1.96 * s[[2]]), p = s[[4]])
    }) |>
      list_rbind()
  }) |>
    list_rbind()

  list(donnees = d, modeles = modeles, performance = performance, calibration = calibration,
       effet_social = effet_social, n_couples = nrow(couples), taux_match = mean(couples$match))
}

# Couples de l'expérience que l'on peut charger dans le formulaire
table_couples <- function(d) {
  d |>
    filter(genre == "Femme") |>
    select(wave, femme = iid, homme = pid, num_f = id, num_h = partner, dec_f = dec, dec_h = dec_o,
           match, age_f = age_juge, age_h = age_partenaire, origine_f = origine,
           origine_h = origine_partenaire, revenu_f = revenu_juge, revenu_h = revenu_partenaire,
           int_corr, all_of(criteres_notes)) |>
    rename_with(\(n) paste0("f_", n), all_of(criteres_notes)) |>
    inner_join(d |>
                 filter(genre == "Homme") |>
                 select(homme = iid, femme = pid, all_of(criteres_notes)) |>
                 rename_with(\(n) paste0("h_", n), all_of(criteres_notes)),
               by = c("femme", "homme"))
}

# --- Prédiction pour deux personnes ----------------------------------------------------

# elle et lui : listes avec age, origine, revenu du quartier et notes (vecteur nommé des six
# notes données)
ligne_juge <- function(juge, partenaire, int_corr) {
  tibble(age_juge = juge$age, ecart_age = partenaire$age - juge$age,
         meme_origine = as.integer(juge$origine == partenaire$origine),
         origine = factor(juge$origine, levels = origines_pred),
         int_corr = int_corr,
         ecart_revenu = ecart_doublements(juge$revenu, partenaire$revenu),
         !!!as.list(juge$notes))
}

# Le modèle utilisé pour prédire comprend toujours l'écart social : c'est la question du projet
predire_match <- function(prediction, type, elle, lui, int_corr) {
  modele <- paste0(type, "_social")
  lignes <- list(Femme = ligne_juge(elle, lui, int_corr), Homme = ligne_juge(lui, elle, int_corr))
  res <- map(set_names(names(lignes)), \(g) {
    m <- prediction$modeles[[g]][[modele]]
    termes <- predict(m, lignes[[g]], type = "terms")
    list(proba = predict(m, lignes[[g]], type = "response"),
         contributions = tibble(terme = colnames(termes), valeur = termes[1, ]))
  })
  list(elle = res$Femme$proba, lui = res$Homme$proba, match = res$Femme$proba * res$Homme$proba,
       ecart_revenu = ecart_doublements(elle$revenu, lui$revenu),
       contributions = bind_rows(
         mutate(res$Femme$contributions, personne = "Sa décision à elle"),
         mutate(res$Homme$contributions, personne = "Sa décision à lui")
       ))
}

# Contribution de chaque facteur à la cote du oui, par rapport à une rencontre moyenne
graphique_contributions <- function(resultat) {
  d <- resultat$contributions |>
    mutate(facteur = termes_lisibles[terme]) |>
    summarise(valeur = sum(valeur), .by = c(personne, facteur)) |>
    mutate(facteur = factor(facteur, levels = rev(unique(termes_lisibles))),
           personne = factor(personne, levels = c("Sa décision à elle", "Sa décision à lui")),
           sens = if_else(valeur >= 0, "pousse vers le oui", "pousse vers le non"),
           texte = paste0(personne, "\n", facteur, " : cote du oui × ", virgule(exp(valeur), 2),
                          " (", sens, ")"))
  bornes <- max(1, ceiling(max(abs(d$valeur)) / log(2)))
  graduations <- log(2) * seq(-bornes, bornes)
  p <- ggplot(d, aes(x = facteur, y = valeur, fill = personne, text = texte)) +
    geom_hline(yintercept = 0, colour = col_muted) +
    geom_col(width = 0.7) +
    facet_wrap(vars(personne)) +
    scale_fill_manual(values = c("Sa décision à elle" = col_femme, "Sa décision à lui" = col_homme),
                      guide = "none") +
    scale_y_continuous(breaks = graduations, limits = log(2) * c(-bornes, bornes),
                       labels = \(x) paste0("× ", format(signif(exp(x), 2), decimal.mark = ",",
                                                         trim = TRUE))) +
    coord_flip() +
    labs(x = NULL, y = "Effet sur la cote du oui, par rapport à une rencontre moyenne")
  interactif(p, legende = FALSE)
}

graphique_calibration <- function(calibration, modele_choisi) {
  d <- calibration |>
    filter(modele == modele_choisi) |>
    mutate(texte = paste0(decile, "e dixième des couples\nProbabilité prédite : ", pct(predit),
                          "\nTaux de match observé : ", pct(observe), " (", n, " couples)"))
  limite <- max(c(d$predit, d$observe)) * 1.05
  p <- ggplot(d, aes(x = predit, y = observe, text = texte)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = col_muted) +
    geom_line(aes(group = 1), colour = col_accent, linewidth = 0.8) +
    geom_point(colour = col_accent, size = 3) +
    scale_x_continuous(labels = pourcent, limits = c(0, limite)) +
    scale_y_continuous(labels = pourcent, limits = c(0, limite)) +
    labs(x = "Probabilité de match prédite", y = "Taux de match observé")
  interactif(p, legende = FALSE)
}
