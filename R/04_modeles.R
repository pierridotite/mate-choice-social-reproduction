# Modèles : l'écart social entre deux personnes change-t-il la probabilité de dire oui ?
# Régressions logistiques mixtes sur `dec`, avec un effet aléatoire pour la personne qui
# juge (iid) et un pour la personne jugée (pid). Modèles emboîtés M1 à M4.
#
# Entrée  : outputs/dates.rds (03_preparation.R)
# Sorties : outputs/modeles.rds (coefficients, variances, prédictions, pour l'application)
#           outputs/modeles/*.png, commentées dans modeles.md
#
# À lancer depuis la racine du dépôt : Rscript R/04_modeles.R (environ 2 minutes)

library(tidyverse)
library(lme4)
library(patchwork)
source("R/commun.R")

dir_fig <- "outputs/modeles"
dir.create(dir_fig, showWarnings = FALSE, recursive = TRUE)

# --- 1. Données du modèle ----------------------------------------------------

dates <- readRDS("outputs/dates.rds")

# Échelle de l'écart social : en doublements du rapport entre les revenus des deux
# quartiers. ecart_doublement = 0 : revenus égaux ; 1 : l'un est deux fois plus élevé que
# l'autre ; 2 : quatre fois plus élevé.
moy_log2_revenu <- mean(log2(dates$revenu[dates$echantillon]))

donnees <- dates |>
  filter(echantillon) |>
  mutate(
    ecart_doublement = ecart_revenu / log(2),
    homme = genre == "Homme",
    # Revenu du quartier de chacun, en doublements autour de la moyenne de l'échantillon
    revenu_juge_c = log2(revenu) - moy_log2_revenu,
    revenu_partenaire_c = log2(revenu_o) - moy_log2_revenu
  )

# Même échantillon pour tous les modèles, sinon les coefficients ne sont pas comparables :
# on garde les dates où toutes les variables de M1 à M4 sont renseignées
variables <- c("dec", "ecart_doublement", "samerace", "ecart_age", "meme_domaine",
               "int_corr", "attr", "fun", "shar")
donnees_completes <- donnees |> drop_na(all_of(variables))

taux_moyen <- mean(donnees_completes$dec)
cat("Échantillon d'analyse :", nrow(donnees), "dates | échantillon commun des modèles :",
    nrow(donnees_completes), "dates,", n_distinct(donnees_completes$iid), "juges",
    "| taux de oui :", round(taux_moyen, 3), "\n")

# --- 2. Modèles --------------------------------------------------------------

controle <- glmerControl(optimizer = "bobyqa")
ajuster <- function(formule, data = donnees_completes) {
  glmer(formule, data = data, family = binomial, control = controle)
}

controles <- "homme + samerace + ecart_age + meme_domaine + int_corr"
aleatoires <- "(1 | iid) + (1 | pid)"

# M1 naïf : régression logistique classique, qui ignore que chaque personne revient
# une quinzaine de fois. Sert uniquement à montrer l'erreur que l'on ferait.
m1_naif <- glm(dec ~ ecart_doublement, family = binomial, data = donnees_completes)

modeles <- list(
  # M1 : effet brut de l'écart social
  M1 = ajuster(as.formula(paste("dec ~ ecart_doublement +", aleatoires))),
  # M2 : + contrôles (genre, même origine, écart d'âge, même domaine, intérêts communs)
  M2 = ajuster(as.formula(paste("dec ~ ecart_doublement +", controles, "+", aleatoires))),
  # M3 : + notes données au partenaire. Si l'effet de l'écart disparaît ici, il passait
  # par la perception du partenaire
  M3 = ajuster(as.formula(paste("dec ~ ecart_doublement +", controles,
                                "+ attr + fun + shar +", aleatoires))),
  # M4 : homophilie ou préférence pour le statut ? On sépare l'écart (ressembler à
  # l'autre) du revenu du quartier du partenaire (préférer un partenaire aisé), et on
  # laisse les deux effets différer entre femmes et hommes
  M4 = ajuster(as.formula(paste("dec ~ homme * (ecart_doublement + revenu_partenaire_c) +",
                                "revenu_juge_c +", controles, "+", aleatoires)))
)

walk2(names(modeles), modeles, \(nom, m) {
  cat("\n=====", nom, "=====\n")
  print(round(summary(m)$coefficients, 3))
  print(VarCorr(m))
})

# --- 3. Coefficients en rapports de cotes ------------------------------------

coefficients_modele <- function(m, nom) {
  co <- summary(m)$coefficients
  tibble(
    modele = nom,
    terme = rownames(co),
    estimation = unname(co[, "Estimate"]),
    erreur_type = unname(co[, "Std. Error"]),
    p_valeur = unname(co[, ncol(co)])
  ) |>
    mutate(
      # Intervalles de Wald à 95 %, puis passage à l'échelle des rapports de cotes
      rc = exp(estimation),
      rc_bas = exp(estimation - 1.96 * erreur_type),
      rc_haut = exp(estimation + 1.96 * erreur_type)
    )
}

coefs <- bind_rows(
  coefficients_modele(m1_naif, "M1 naïf"),
  list_rbind(imap(modeles, coefficients_modele))
)

# Dans M4, l'effet chez les hommes = effet principal + interaction
effet_hommes_m4 <- function(m, terme) {
  b <- fixef(m)
  v <- vcov(m)
  inter <- paste0("hommeTRUE:", terme)
  est <- unname(b[terme] + b[inter])
  se <- sqrt(v[terme, terme] + v[inter, inter] + 2 * v[terme, inter])
  tibble(modele = "M4", terme = paste0(terme, " (hommes)"), estimation = est, erreur_type = se,
         p_valeur = 2 * pnorm(-abs(est / se)),
         rc = exp(est), rc_bas = exp(est - 1.96 * se), rc_haut = exp(est + 1.96 * se))
}
coefs <- bind_rows(
  coefs,
  effet_hommes_m4(modeles$M4, "ecart_doublement"),
  effet_hommes_m4(modeles$M4, "revenu_partenaire_c")
)

coefs |>
  filter(str_detect(terme, "ecart_doublement|revenu_partenaire")) |>
  mutate(across(where(is.numeric), \(x) round(x, 3))) |>
  print(n = Inf)

# Ce que l'on peut exclure : l'intervalle de M2 traduit en points de pourcentage autour
# du taux de oui moyen (ordre de grandeur, pour un doublement du rapport des revenus)
ecart_m2 <- coefs |> filter(modele == "M2", terme == "ecart_doublement")
effet_points <- 100 * (plogis(qlogis(taux_moyen) + log(c(estimation = ecart_m2$rc,
                                                         bas = ecart_m2$rc_bas,
                                                         haut = ecart_m2$rc_haut))) - taux_moyen)
print(round(effet_points, 1))

# Écarts-types des effets aléatoires : l'hétérogénéité entre personnes
variances <- imap(modeles, \(m, nom) {
  as.data.frame(VarCorr(m)) |> transmute(modele = nom, groupe = grp, ecart_type = sdcor)
}) |> list_rbind()
print(variances)

# --- 4. Figure 1 : la trajectoire de l'effet de l'écart social ---------------

etiquettes_modeles <- c(
  "M1 naïf" = "M1 naïf\nsans effets aléatoires",
  "M1" = "M1\nécart seul",
  "M2" = "M2\n+ contrôles",
  "M3" = "M3\n+ notes données",
  "M4, femmes" = "M4\nfemmes qui jugent",
  "M4, hommes" = "M4\nhommes qui jugent"
)

trajectoire <- coefs |>
  filter(terme %in% c("ecart_doublement", "ecart_doublement (hommes)")) |>
  mutate(
    groupe = case_when(
      modele == "M4" & terme == "ecart_doublement" ~ "M4, femmes",
      modele == "M4" ~ "M4, hommes",
      TRUE ~ modele
    ),
    etiquette = fct_rev(fct_inorder(etiquettes_modeles[groupe])),
    naif = modele == "M1 naïf"
  )

fig_trajectoire <- trajectoire |>
  ggplot(aes(x = rc, y = etiquette)) +
  geom_vline(xintercept = 1, colour = col_dark, linewidth = 0.5) +
  geom_pointrange(aes(xmin = rc_bas, xmax = rc_haut, colour = naif),
                  size = 0.6, linewidth = 1) +
  geom_text(aes(label = paste0("× ", virgule(rc))), nudge_y = 0.3, size = 3.3, colour = col_dark) +
  scale_colour_manual(values = c("FALSE" = col_accent, "TRUE" = col_neutre), guide = "none") +
  scale_x_log10(breaks = c(0.6, 0.8, 1, 1.25, 1.5), labels = \(x) virgule(x, 2),
                limits = c(0.55, 1.6)) +
  labs(
    title = "Quel que soit le modèle, aucun effet détectable de l'écart social sur le oui",
    subtitle = paste0("Rapport de cotes quand le revenu d'un quartier est deux fois celui de l'autre ",
                      "plutôt qu'égal, avec son intervalle de confiance à 95 %.\n",
                      milliers(nrow(donnees_completes)), " dates, ",
                      n_distinct(donnees_completes$iid),
                      " juges. Le modèle naïf, en gris, a un intervalle trop étroit"),
    x = "Rapport de cotes (échelle log). En dessous de 1 : moins de oui quand l'écart grandit",
    y = NULL, caption = source_census
  ) +
  theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(colour = col_dark))

sauver(fig_trajectoire, file.path(dir_fig, "01_trajectoire_ecart.png"), height = 5.2)

# --- 5. Figure 2 : l'écart social face aux autres ressemblances (M2) ---------

# Pour comparer des variables d'unités différentes, chaque effet est calculé pour un
# contraste concret (delta) plutôt que « par unité »
contrastes_m2 <- tribble(
  ~terme,             ~delta, ~libelle,
  "ecart_doublement", 1,      "Revenus des quartiers dans un rapport de 2\n(plutôt qu'égaux)",
  "sameraceTRUE",     1,      "Même origine déclarée\n(plutôt que différente)",
  "meme_domaineTRUE", 1,      "Même domaine d'études\n(plutôt que différent)",
  "ecart_age",        5,      "Cinq ans d'écart d'âge\n(plutôt que le même âge)",
  "int_corr",         0.5,    "Centres d'intérêt corrélés à 0,5\n(plutôt que 0)"
)

effets_m2 <- coefs |>
  filter(modele == "M2") |>
  inner_join(contrastes_m2, by = "terme") |>
  mutate(
    rc = exp(estimation * delta),
    rc_bas = exp((estimation - 1.96 * erreur_type) * delta),
    rc_haut = exp((estimation + 1.96 * erreur_type) * delta),
    libelle = fct_reorder(libelle, rc),
    social = terme == "ecart_doublement"
  )
effets_m2 |> select(terme, delta, rc, rc_bas, rc_haut, p_valeur) |> print()
rc_homme_m2 <- coefs |> filter(modele == "M2", terme == "hommeTRUE")

fig_effets <- effets_m2 |>
  ggplot(aes(x = rc, y = libelle)) +
  geom_vline(xintercept = 1, colour = col_dark, linewidth = 0.5) +
  geom_pointrange(aes(xmin = rc_bas, xmax = rc_haut, colour = social), size = 0.6, linewidth = 1) +
  geom_text(aes(label = paste0("× ", virgule(rc))), nudge_y = 0.3, size = 3.3, colour = col_dark) +
  scale_colour_manual(values = c("TRUE" = col_femme, "FALSE" = col_accent), guide = "none") +
  scale_x_log10(breaks = c(0.5, 0.75, 1, 1.5, 2, 3), labels = \(x) virgule(x, 2)) +
  labs(
    title = "On se choisit entre semblables, mais pas selon le revenu du quartier d'origine",
    subtitle = paste0("Rapports de cotes du modèle M2, avec intervalle de confiance à 95 %. Le modèle tient aussi compte ",
                      "du genre du juge\n(les hommes disent plus souvent oui : × ", virgule(rc_homme_m2$rc),
                      "), non représenté ici"),
    x = "Rapport de cotes (échelle log). 1 = aucun effet", y = NULL, caption = source_census
  ) +
  theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(colour = col_dark))

sauver(fig_effets, file.path(dir_fig, "02_effets_m2.png"), height = 5)

# --- 6. Figure 3 : probabilités prédites --------------------------------------

# Probabilité de oui pour une personne « typique » (effets aléatoires nuls), avec un
# intervalle de confiance par la méthode delta sur l'échelle logit
predire <- function(m, grille) {
  X <- model.matrix(delete.response(terms(m)), grille)
  X <- X[, names(fixef(m)), drop = FALSE]   # même ordre de colonnes que les coefficients
  eta <- as.vector(X %*% fixef(m))
  se <- sqrt(rowSums((X %*% as.matrix(vcov(m))) * X))
  grille |>
    mutate(prob = plogis(eta), bas = plogis(eta - 1.96 * se), haut = plogis(eta + 1.96 * se))
}

profil_type <- donnees_completes |>
  summarise(ecart_age = median(ecart_age), int_corr = median(int_corr),
            attr = median(attr), fun = median(fun), shar = median(shar),
            ecart_doublement = median(ecart_doublement))

grille_ecart <- expand_grid(
  # Jusqu'à × 4 : 97,5 % des dates. Au-delà, on extrapolerait sur quelques points
  ecart_doublement = seq(0, 2, by = 0.05),
  homme = c(FALSE, TRUE), samerace = FALSE, meme_domaine = FALSE
) |>
  mutate(ecart_age = profil_type$ecart_age, int_corr = profil_type$int_corr)
pred_ecart <- predire(modeles$M2, grille_ecart)

grille_attr <- expand_grid(
  attr = 1:10, homme = c(FALSE, TRUE), samerace = FALSE, meme_domaine = FALSE
) |>
  mutate(ecart_doublement = profil_type$ecart_doublement, ecart_age = profil_type$ecart_age,
         int_corr = profil_type$int_corr, fun = profil_type$fun, shar = profil_type$shar)
pred_attr <- predire(modeles$M3, grille_attr)

pred_ecart |>
  filter(ecart_doublement %in% c(0, 1, 2)) |>
  select(ecart_doublement, homme, prob) |>
  print()
pred_attr |>
  filter(attr %in% c(2, 5, 8)) |>
  select(attr, homme, prob) |>
  print()

graphique_prediction <- function(pred, x, titre, x_lab, breaks) {
  pred |>
    mutate(genre = if_else(homme, "Hommes", "Femmes")) |>
    ggplot(aes(x = {{ x }}, y = prob, colour = genre, fill = genre)) +
    geom_ribbon(aes(ymin = bas, ymax = haut), alpha = 0.15, colour = NA) +
    geom_line(linewidth = 1) +
    scale_colour_manual(values = couleurs_genre, name = "Qui juge :") +
    scale_fill_manual(values = couleurs_genre, name = "Qui juge :") +
    scale_x_continuous(breaks = breaks, labels = names(breaks)) +
    scale_y_continuous(labels = pourcent, limits = c(0, 1)) +
    labs(title = titre, x = x_lab, y = "Probabilité de dire oui")
}

fig_ecart_pred <- graphique_prediction(
  pred_ecart, ecart_doublement, "Selon l'écart de revenu (modèle M2)",
  "Rapport entre les revenus des deux quartiers",
  c("× 1" = 0, "× 1,5" = log2(1.5), "× 2" = 1, "× 3" = log2(3), "× 4" = 2)
)
fig_attr_pred <- graphique_prediction(
  pred_attr, attr, "Selon la note d'attirance donnée (modèle M3)",
  "Note d'attirance physique (sur 10)", c(`2` = 2, `4` = 4, `6` = 6, `8` = 8, `10` = 10)
)

fig_predictions <- ((fig_ecart_pred | fig_attr_pred) + plot_layout(guides = "collect") &
                      theme_sous_titre & theme(legend.position = "top")) +
  plot_annotation(
    title = "L'attirance fait passer le oui de presque 0 à presque 100 %, l'écart social ne le fait pas bouger",
    subtitle = paste0("Probabilité prédite pour une personne typique, d'une autre origine et d'un autre domaine ",
                      "que son partenaire,\nles autres variables à leur médiane. Bande : intervalle de confiance à 95 %"),
    caption = source_census,
    theme = theme(plot.title = element_text(size = 14))
  )

sauver(fig_predictions, file.path(dir_fig, "03_probabilites.png"), width = 11, height = 5.5)

# --- 7. Figure 4 : ce qui varie entre personnes -------------------------------

# Écart-type des effets aléatoires de M2 comparé aux effets de la paire. Passer d'un juge
# moyen à un juge plus enclin à dire oui (un écart-type au-dessus) multiplie les cotes par
# exp(écart-type) : on le compare aux effets de ressemblance de la figure 2.
rc_m2 <- \(t) effets_m2$rc[effets_m2$terme == t]
comparaison <- tibble(
  source = c("Un juge plus enclin que la moyenne à dire oui\n(+ 1 écart-type de l'effet juge)",
             "Un partenaire plus populaire que la moyenne\n(+ 1 écart-type de l'effet partenaire)",
             "Même domaine d'études",
             "Même origine déclarée",
             "Revenus des quartiers dans un rapport de 2"),
  rc = c(exp(variances$ecart_type[variances$modele == "M2" & variances$groupe == "iid"]),
         exp(variances$ecart_type[variances$modele == "M2" & variances$groupe == "pid"]),
         rc_m2("meme_domaineTRUE"), rc_m2("sameraceTRUE"), rc_m2("ecart_doublement")),
  social = c(FALSE, FALSE, FALSE, FALSE, TRUE)   # l'écart social, mis en évidence
) |>
  mutate(
    # Effet « éloigné de 1 », quel que soit le sens, pour comparer des ampleurs
    ampleur = abs(log(rc)),
    source = fct_reorder(source, ampleur)
  )

fig_personnes <- comparaison |>
  ggplot(aes(x = rc, y = source)) +
  geom_vline(xintercept = 1, colour = col_dark, linewidth = 0.5) +
  geom_segment(aes(x = 1, xend = rc, yend = source, colour = social), linewidth = 3) +
  geom_text(aes(label = paste0("× ", virgule(rc)), hjust = if_else(rc < 1, 1.2, -0.25)),
            size = 3.4, colour = col_dark) +
  scale_colour_manual(values = c("TRUE" = col_femme, "FALSE" = col_accent), guide = "none") +
  scale_x_log10(limits = c(0.75, 6), breaks = c(1, 2, 4), labels = \(x) virgule(x, 0)) +
  labs(
    title = "Qui juge et qui est jugé comptent bien plus que la ressemblance entre les deux",
    subtitle = "Facteur multiplicatif sur les cotes de dire oui, modèle M2",
    x = "Rapport de cotes (échelle log)", y = NULL, caption = source_census
  ) +
  theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(colour = col_dark))

sauver(fig_personnes, file.path(dir_fig, "04_personnes_vs_paire.png"), height = 4.6)

# --- 8. Export pour l'application ---------------------------------------------

saveRDS(
  list(
    coefficients = coefs,
    effets_m2 = effets_m2,
    variances = variances,
    effets_fixes = map(modeles, fixef),
    vcov = map(modeles, \(m) as.matrix(vcov(m))),
    predictions = list(ecart = pred_ecart, attirance = pred_attr),
    profil_type = profil_type,
    moy_log2_revenu = moy_log2_revenu,
    taux_moyen = taux_moyen,
    effet_points_m2 = effet_points,
    effectifs = c(dates = nrow(donnees_completes), juges = n_distinct(donnees_completes$iid))
  ),
  "outputs/modeles.rds"
)
