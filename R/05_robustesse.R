# Robustesse : l'absence d'effet de l'écart social tient-elle à un choix de mesure,
# d'échantillon ou de modèle ?
# 1. Le modèle M2 de 04_modeles.R est réajusté avec d'autres mesures de l'écart et sur
#    d'autres échantillons.
# 2. Le résultat de Fisman et al. (2006), selon lequel les femmes préfèrent les hommes qui
#    ont grandi dans des quartiers aisés, est testé avec leur mesure (revenu 2000).
#
# Entrées : outputs/dates.rds (03_preparation.R), outputs/modeles.rds (04_modeles.R)
# Sorties : outputs/robustesse.rds, outputs/robustesse/*.png, commentées dans robustesse.md
#
# À lancer depuis la racine du dépôt : Rscript R/05_robustesse.R (environ 2 minutes)

library(tidyverse)
library(lme4)
source("R/commun.R")

dir_fig <- "outputs/robustesse"
dir.create(dir_fig, showWarnings = FALSE, recursive = TRUE)

# --- 1. Données --------------------------------------------------------------

dates <- readRDS("outputs/dates.rds") |>
  mutate(
    homme = genre == "Homme",
    # Écarts de revenu en doublements, comme dans 04_modeles.R
    ecart_2021 = ecart_revenu / log(2),
    ecart_2000 = ecart_revenu_2000 / log(2),
    # Écart d'indice de Gini, par tranche de 0,1 (un écart de 0,1 est proche du troisième
    # quartile des écarts entre partenaires)
    ecart_gini_01 = ecart_gini / 0.1,
    # Codé pour que l'homophilie donne, comme les écarts, un rapport de cotes inférieur à 1
    tercile_different = !meme_tercile
  )

reference <- readRDS("outputs/modeles.rds")

controles <- "homme + samerace + ecart_age + meme_domaine + int_corr"
variables_controle <- c("dec", "homme", "samerace", "ecart_age", "meme_domaine", "int_corr")
controle_glmer <- glmerControl(optimizer = "bobyqa")

intervalle <- function(resultats) {
  resultats |>
    mutate(rc = exp(estimation),
           rc_bas = exp(estimation - 1.96 * erreur_type),
           rc_haut = exp(estimation + 1.96 * erreur_type))
}

# --- 2. L'écart social mesuré autrement --------------------------------------

# Réajuste M2 (écart + contrôles, effets juge et partenaire) avec la mesure d'écart
# `variable`, sur les lignes de `donnees` où toutes les variables sont renseignées
ajuster_ecart <- function(variable, donnees) {
  donnees <- donnees |> drop_na(all_of(c(variables_controle, variable)))
  m <- glmer(as.formula(paste("dec ~", variable, "+", controles, "+ (1 | iid) + (1 | pid)")),
             data = donnees, family = binomial, control = controle_glmer)
  terme <- if (is.logical(donnees[[variable]])) paste0(variable, "TRUE") else variable
  co <- summary(m)$coefficients[terme, ]
  tibble(estimation = co[["Estimate"]], erreur_type = co[["Std. Error"]],
         p_valeur = co[["Pr(>|z|)"]], dates = nrow(donnees), juges = n_distinct(donnees$iid))
}

# Chaque variante change une seule chose par rapport au modèle de référence
variantes <- tibble(
  groupe = c(rep("Revenu 2021, autre échantillon", 3), "Autre mesure du revenu",
             "Autre forme d'écart", "Autre forme d'écart"),
  variante = c(
    "Sans exiger les notes données",
    "Sans quartiers plafonnés ni marges d'erreur > 30 %",
    "Seulement les dates où le revenu 2000 est connu",
    "Revenu 2000 fourni par les auteurs",
    "Écart d'indice de Gini de 0,1",
    "Tercile de revenu différent plutôt que le même"
  ),
  variable = c("ecart_2021", "ecart_2021", "ecart_2021", "ecart_2000", "ecart_gini_01",
               "tercile_different"),
  donnees = list(
    filter(dates, echantillon),
    filter(dates, echantillon_fiable),
    filter(dates, !is.na(ecart_2000)),
    filter(dates, !is.na(ecart_2000)),
    filter(dates, !is.na(ecart_gini)),
    filter(dates, echantillon)
  )
)

resultats_ecart <- variantes |>
  mutate(res = map2(variable, donnees, ajuster_ecart)) |>
  select(-donnees) |>
  unnest(res)

# Le modèle de référence : M2 de 04_modeles.R, sur l'échantillon commun des modèles
m2 <- reference$coefficients |> filter(modele == "M2", terme == "ecart_doublement")
resultats_ecart <- bind_rows(
  tibble(groupe = "Référence", variante = "M2 de modeles.md", variable = "ecart_2021",
         estimation = m2$estimation, erreur_type = m2$erreur_type, p_valeur = m2$p_valeur,
         dates = reference$effectifs[["dates"]], juges = reference$effectifs[["juges"]]),
  resultats_ecart
) |>
  intervalle()

resultats_ecart |>
  select(variante, dates, juges, rc, rc_bas, rc_haut, p_valeur) |>
  mutate(across(where(is.double), \(x) round(x, 3))) |>
  print(width = Inf)

# --- 3. Préférence pour les partenaires issus de quartiers aisés -------------

# Effet du revenu du quartier du partenaire (par doublement), séparément pour les femmes
# et les hommes qui jugent. Seul le revenu du partenaire est nécessaire, ce qui garde aussi
# les juges sans données Census.
ajuster_statut <- function(variable, donnees) {
  donnees <- donnees |>
    drop_na(all_of(c(variables_controle, variable))) |>
    mutate(revenu_partenaire_c = log2(.data[[variable]]) - mean(log2(.data[[variable]])))
  m <- glmer(dec ~ homme * revenu_partenaire_c + samerace + ecart_age + meme_domaine + int_corr +
               (1 | iid) + (1 | pid),
             data = donnees, family = binomial, control = controle_glmer)
  b <- fixef(m)
  v <- vcov(m)
  t <- "revenu_partenaire_c"
  i <- "hommeTRUE:revenu_partenaire_c"
  tibble(
    genre = c("Femmes", "Hommes"),
    estimation = unname(c(b[t], b[t] + b[i])),
    erreur_type = c(sqrt(v[t, t]), sqrt(v[t, t] + v[i, i] + 2 * v[t, i])),
    dates = nrow(donnees), juges = n_distinct(donnees$iid)
  ) |>
    mutate(p_valeur = 2 * pnorm(-abs(estimation / erreur_type)))
}

# Même question avec une régression logistique simple : un effet fixe par juge, pas
# d'effet partenaire. Ses intervalles sont un peu trop étroits (elle ignore que chaque
# partenaire revient plusieurs fois), ce qui la rend plutôt plus prompte à trouver un effet.
ajuster_statut_simple <- function(variable, donnees) {
  donnees <- donnees |>
    drop_na(all_of(c(variables_controle, variable))) |>
    mutate(revenu_partenaire_c = log2(.data[[variable]]) - mean(log2(.data[[variable]])))
  map(c(Femmes = FALSE, Hommes = TRUE), \(h) {
    sous <- filter(donnees, homme == h)
    m <- glm(dec ~ revenu_partenaire_c + samerace + ecart_age + meme_domaine + int_corr + factor(iid),
             family = binomial, data = sous)
    co <- summary(m)$coefficients["revenu_partenaire_c", ]
    tibble(estimation = co[["Estimate"]], erreur_type = co[["Std. Error"]],
           p_valeur = co[["Pr(>|z|)"]], dates = nrow(sous), juges = n_distinct(sous$iid))
  }) |>
    list_rbind(names_to = "genre")
}

partenaire_2000_connu <- filter(dates, !is.na(revenu_2000_o))

resultats_statut <- bind_rows(
  ajuster_statut("revenu_o", dates) |>
    mutate(variante = "Revenu 2021, tous les partenaires ayant un revenu Census"),
  ajuster_statut("revenu_o", partenaire_2000_connu) |>
    mutate(variante = "Revenu 2021, partenaires dont le revenu 2000 est connu"),
  ajuster_statut("revenu_2000_o", partenaire_2000_connu) |>
    mutate(variante = "Revenu 2000 fourni par les auteurs"),
  ajuster_statut_simple("revenu_2000_o", partenaire_2000_connu) |>
    mutate(variante = "Revenu 2000, régression simple (effet fixe juge, sans effet partenaire)")
) |>
  intervalle()

resultats_statut |>
  select(variante, genre, dates, juges, rc, rc_bas, rc_haut, p_valeur) |>
  mutate(across(where(is.double), \(x) round(x, 3))) |>
  print(width = Inf)

# --- 4. Figure 1 : l'écart social, variante par variante ---------------------

fig_ecart <- resultats_ecart |>
  mutate(
    etiquette = paste0(variante, "\n", milliers(dates), " dates, ", juges, " juges"),
    etiquette = fct_rev(fct_inorder(etiquette)),
    reference = groupe == "Référence"
  ) |>
  ggplot(aes(x = rc, y = etiquette)) +
  geom_vline(xintercept = 1, colour = col_dark, linewidth = 0.5) +
  geom_pointrange(aes(xmin = rc_bas, xmax = rc_haut, colour = reference), size = 0.6, linewidth = 1) +
  etiquette_rc(nudge_y = 0.32) +
  scale_colour_manual(values = c("TRUE" = col_neutre, "FALSE" = col_accent), guide = "none") +
  scale_x_log10(breaks = c(0.7, 0.85, 1, 1.2, 1.4), labels = \(x) virgule(x, 2),
                limits = c(0.65, 1.45)) +
  labs(
    title = "Aucune variante ne fait apparaître d'effet de l'écart social",
    subtitle = paste0("Rapport de cotes de l'écart dans le modèle M2, avec intervalle de confiance à 95 %. ",
                      "En gris, le modèle de référence.\nÉcart de revenu : revenus dans un rapport de 2 ",
                      "plutôt qu'égaux. Gini et tercile : voir le libellé"),
    x = "Rapport de cotes (échelle log). En dessous de 1 : moins de oui quand l'écart grandit",
    y = NULL, caption = source_census
  ) +
  theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(colour = col_dark))

sauver(fig_ecart, file.path(dir_fig, "01_variantes_ecart.png"), height = 6)

# --- 5. Figure 2 : la préférence pour les partenaires aisés ------------------

fig_statut <- resultats_statut |>
  mutate(
    etiquette = fct_rev(fct_inorder(variante)),
    genre = factor(genre, levels = c("Hommes", "Femmes"))
  ) |>
  ggplot(aes(x = rc, y = etiquette, colour = genre)) +
  geom_vline(xintercept = 1, colour = col_dark, linewidth = 0.5) +
  geom_pointrange(aes(xmin = rc_bas, xmax = rc_haut), size = 0.55, linewidth = 1,
                  position = position_dodge(width = 0.5, orientation = "y")) +
  scale_colour_manual(values = couleurs_genre, name = "Qui juge :", breaks = c("Femmes", "Hommes")) +
  scale_y_discrete(labels = \(x) str_wrap(x, 34)) +
  scale_x_log10(breaks = c(0.6, 0.8, 1, 1.25, 1.6), labels = \(x) virgule(x, 2)) +
  labs(
    title = "Pas de préférence pour les partenaires issus de quartiers aisés, même avec le revenu 2000",
    subtitle = paste0("Rapport de cotes quand le revenu du quartier du partenaire est deux fois plus élevé, ",
                      "avec intervalle de confiance à 95 %.\nFisman et al. (2006) trouvaient une préférence ",
                      "des femmes pour les hommes issus de quartiers aisés"),
    x = "Rapport de cotes (échelle log). Au-dessus de 1 : plus de oui aux partenaires issus de quartiers aisés",
    y = NULL, caption = source_census
  ) +
  theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(colour = col_dark))

sauver(fig_statut, file.path(dir_fig, "02_preference_statut.png"), height = 5.5)

# --- 6. Export ---------------------------------------------------------------

saveRDS(list(ecart = resultats_ecart, statut = resultats_statut), "outputs/robustesse.rds")
