# Exploration du jeu de données Speed Dating x Census
# Objectif : comprendre la structure, la qualité et les variables clés avant toute modélisation.
# Les figures sont exportées dans outputs/exploration/ et commentées dans exploration.md.
#
# À lancer depuis la racine du dépôt : Rscript R/02_exploration.R

library(tidyverse)
library(patchwork)

dir_fig <- "outputs/exploration"
dir.create(dir_fig, showWarnings = FALSE, recursive = TRUE)

# --- 0. Charte graphique -----------------------------------------------------

# Bleu / orange : paire lisible par les daltoniens ; gris pour tout ce qui est secondaire
col_femme <- "#eb6834"
col_homme <- "#2a78d6"
col_accent <- "#2a78d6"
col_alerte <- "#c8352b"
col_neutre <- "#a9a8a2"
col_dark <- "#52514e"
col_muted <- "#898781"
col_grid <- "#e1e0d9"

couleurs_genre <- c("Femmes" = col_femme, "Hommes" = col_homme)

theme_projet <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = col_grid, linewidth = 0.4),
      axis.text = element_text(colour = col_muted),
      axis.title = element_text(colour = col_dark, size = rel(0.9)),
      strip.text = element_text(colour = col_dark, face = "bold", hjust = 0),
      legend.position = "top",
      legend.justification = "left",
      legend.margin = margin(0, 0, 0, 0),
      legend.text = element_text(colour = col_dark),
      plot.title = element_text(face = "bold", size = rel(1.15)),
      plot.subtitle = element_text(colour = col_dark, size = rel(0.9), margin = margin(b = 8)),
      plot.caption = element_text(colour = col_muted, hjust = 0, size = rel(0.75)),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      plot.background = element_rect(fill = "white", colour = NA)
    )
}
theme_set(theme_projet())

source_fisman <- "Source : Fisman et al. (2006), Columbia University, 2002-2004."
source_census <- "Sources : Fisman et al. (2006) ; US Census Bureau, ACS 2017-2021."

pourcent <- scales::label_percent(accuracy = 1, suffix = " %")
dollars <- scales::label_dollar(scale = 1e-3, accuracy = 1, suffix = " k$", prefix = "")
virgule <- function(x, digits = 2) format(round(x, digits), nsmall = digits, decimal.mark = ",")

# Titres des sous-graphiques d'une figure composée : plus petits que le titre général
theme_sous_titre <- theme(plot.title = element_text(size = 11.5))

sauver <- function(nom, plot, width = 9, height = 5.5) {
  ggsave(file.path(dir_fig, paste0(nom, ".png")), plot = plot,
         width = width, height = height, dpi = 300)
}

# --- 1. Import et recodage ---------------------------------------------------

dates <- read_csv("data/speed_dating_census.csv", show_col_types = FALSE, guess_max = 10000)

glimpse(dates[, 1:20])

# Libellés du questionnaire d'origine (Speed Dating Data Key)
lab_race <- c("1" = "Noir", "2" = "Blanc", "3" = "Latino", "4" = "Asiatique", "6" = "Autre")
lab_field <- c(
  "1" = "Droit", "2" = "Mathématiques", "3" = "Sciences sociales, psychologie",
  "4" = "Médecine, pharmacie, biotech", "5" = "Ingénierie", "6" = "Lettres, journalisme",
  "7" = "Histoire, religion, philosophie", "8" = "Commerce, économie, finance",
  "9" = "Éducation", "10" = "Biologie, chimie, physique", "11" = "Travail social",
  "12" = "Indécis", "13" = "Science politique, relations internationales", "14" = "Cinéma",
  "15" = "Beaux-arts", "16" = "Langues", "17" = "Architecture", "18" = "Autre"
)
lab_notes <- c(
  attr = "Attirance physique", sinc = "Sincérité", intel = "Intelligence",
  fun = "Humour", amb = "Ambition", shar = "Intérêts communs"
)

dates <- dates |>
  mutate(
    genre = if_else(gender == 0, "Femmes", "Hommes"),
    race_lab = recode(as.character(race), !!!lab_race),
    field_lab = recode(as.character(field_cd), !!!lab_field),
    census = !is.na(zip_median_income_2021),
    abs_diff_log_income = abs(diff_log_income_2021)
  )

# Une ligne par participant : les attributs individuels sont répétés sur chaque date
participants <- dates |> distinct(iid, .keep_all = TRUE)

# Vérifications de structure
stopifnot(
  !any(duplicated(dates[, c("iid", "pid")])),   # un couple orienté = une ligne
  all(dates$match == dates$dec * dates$dec_o)   # match = oui des deux côtés
)
cat("Dates :", nrow(dates), "| participants :", nrow(participants),
    "| vagues :", n_distinct(dates$wave), "\n")

# --- 2. Structure de l'expérience : les vagues -------------------------------

vagues <- dates |>
  summarise(
    participants = n_distinct(iid), dates = n(), taux_oui = mean(dec),
    .by = c(wave, genre)
  )

# Nombre de partenaires rencontrés par personne : dépend de la taille de la vague
dates |> count(iid) |> pull(n) |> summary()

fig_vagues <- vagues |>
  ggplot(aes(x = factor(wave), y = participants, fill = genre)) +
  geom_col(position = "dodge", width = 0.75) +
  scale_fill_manual(values = couleurs_genre, name = NULL) +
  scale_y_continuous(expand = expansion(c(0, 0.05))) +
  labs(
    title = "21 soirées de tailles très inégales, mais toujours équilibrées entre femmes et hommes",
    subtitle = "Nombre de participants par vague. Chaque femme rencontre tous les hommes de sa vague : de 5 à 22 dates par personne",
    x = "Vague", y = "Participants", caption = source_fisman
  ) +
  theme(panel.grid.major.x = element_blank())

sauver("01_vagues", fig_vagues, height = 4.8)

# --- 3. Données manquantes ---------------------------------------------------

# Les 217 colonnes viennent de questionnaires remplis à des moments différents :
# on regroupe les colonnes par moment de collecte pour lire les manquants par bloc
bloc_colonne <- function(nom) {
  case_when(
    str_detect(nom, "census|zip_|zip5|diff_|income_2000") ~ "Census (notre ajout)",
    str_detect(nom, "_3$") ~ "Suivi à 3-4 semaines",
    str_detect(nom, "_2$|^satis_2|^length|^numdat_2") ~ "Suivi le lendemain",
    str_detect(nom, "_s$") ~ "Mi-soirée",
    nom %in% c("dec", "attr", "sinc", "intel", "fun", "amb", "shar", "like", "prob", "met", "match_es") ~
      "Fiche de notation (après chaque date)",
    str_detect(nom, "_o$") ~ "Partenaire (suffixe _o)",
    nom %in% c("iid", "id", "gender", "idg", "condtn", "wave", "round", "position", "positin1",
               "order", "partner", "pid", "match", "int_corr", "samerace") ~ "Protocole",
    TRUE ~ "Questionnaire d'inscription"
  )
}

manquants <- tibble(
  colonne = names(dates)[1:217],
  taux_na = map_dbl(dates[1:217], \(x) mean(is.na(x)))
) |>
  mutate(bloc = bloc_colonne(colonne))

manquants_bloc <- manquants |>
  summarise(colonnes = n(), taux_median = median(taux_na), taux_min = min(taux_na),
            taux_max = max(taux_na), .by = bloc) |>
  arrange(taux_median)
print(manquants_bloc)

fig_manquants <- manquants |>
  mutate(bloc = fct_reorder(bloc, taux_na, .fun = median)) |>
  ggplot(aes(x = taux_na, y = bloc)) +
  geom_jitter(height = 0.18, width = 0, alpha = 0.55, size = 1.8, colour = col_accent) +
  scale_x_continuous(labels = pourcent, limits = c(0, 1), expand = expansion(c(0.01, 0.02))) +
  labs(
    title = "Les questionnaires de suivi sont très incomplets, le cœur de l'expérience est presque complet",
    subtitle = "Taux de valeurs manquantes des 217 colonnes (un point par colonne), regroupées par moment de collecte",
    x = "Part de valeurs manquantes", y = NULL, caption = source_census
  ) +
  theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(colour = col_dark))

sauver("02_manquants", fig_manquants, height = 4.8)

# --- 4. Profil des participants ----------------------------------------------

participants |> count(genre)
summary(participants$age)

fig_age <- participants |>
  filter(!is.na(age)) |>
  ggplot(aes(x = age, fill = genre)) +
  geom_histogram(binwidth = 1, colour = "white", linewidth = 0.2) +
  facet_wrap(~genre, ncol = 1) +
  scale_fill_manual(values = couleurs_genre, guide = "none") +
  scale_y_continuous(expand = expansion(c(0, 0.05))) +
  labs(title = "Âge", x = "Âge (années)", y = "Participants")

fig_race <- participants |>
  filter(!is.na(race_lab)) |>
  count(race_lab) |>
  mutate(part = n / sum(n), race_lab = fct_reorder(race_lab, n)) |>
  ggplot(aes(x = part, y = race_lab)) +
  geom_col(fill = col_neutre, width = 0.7) +
  geom_text(aes(label = pourcent(part)), hjust = -0.15, size = 3.3, colour = col_dark) +
  scale_x_continuous(labels = pourcent, expand = expansion(c(0, 0.18))) +
  labs(title = "Origine déclarée", x = NULL, y = NULL) +
  theme(panel.grid.major.y = element_blank(), axis.text.x = element_blank(),
        panel.grid.major.x = element_blank())

fig_field <- participants |>
  filter(!is.na(field_lab)) |>
  count(field_lab) |>
  mutate(part = n / sum(n), field_lab = fct_lump_n(field_lab, 9, w = n, other_level = "Autres domaines")) |>
  summarise(part = sum(part), .by = field_lab) |>
  mutate(field_lab = fct_reorder(field_lab, part),
         field_lab = fct_relevel(field_lab, "Autres domaines")) |>
  ggplot(aes(x = part, y = field_lab)) +
  geom_col(fill = col_neutre, width = 0.7) +
  geom_text(aes(label = pourcent(part)), hjust = -0.15, size = 3.3, colour = col_dark) +
  scale_x_continuous(labels = pourcent, expand = expansion(c(0, 0.18))) +
  labs(title = "Domaine d'études", x = NULL, y = NULL) +
  theme(panel.grid.major.y = element_blank(), axis.text.x = element_blank(),
        panel.grid.major.x = element_blank())

fig_profil <- ((fig_age | (fig_race / fig_field + plot_layout(heights = c(1, 1.9)))) & theme_sous_titre) +
  plot_annotation(
    title = "Des étudiants de Columbia de 26 ans en moyenne, majoritairement blancs ou asiatiques",
    subtitle = "Profil des 551 participants",
    caption = source_fisman,
    theme = theme(plot.title = element_text(size = 14))
  )

sauver("03_profil", fig_profil, height = 6)

# --- 5. La variable réponse : dire oui ---------------------------------------

dates |> summarise(taux_oui = mean(dec), taux_match = mean(match))
dates |> summarise(taux_oui = mean(dec), .by = genre)

# Hétérogénéité entre personnes : sélectivité (oui donnés) et popularité (oui reçus)
par_personne <- dates |>
  summarise(
    `Oui donnés (sélectivité du juge)` = mean(dec),
    `Oui reçus (popularité du partenaire)` = mean(dec_o, na.rm = TRUE),
    n_dates = n(), .by = c(iid, genre)
  ) |>
  pivot_longer(starts_with("Oui"), names_to = "mesure", values_to = "taux")

par_personne |> summarise(moyenne = mean(taux), ecart_type = sd(taux),
                          jamais = mean(taux == 0), toujours = mean(taux == 1), .by = c(mesure, genre))

fig_decision <- par_personne |>
  ggplot(aes(x = taux, fill = genre)) +
  geom_histogram(binwidth = 0.1, boundary = 0, colour = "white", linewidth = 0.2) +
  geom_vline(data = \(d) summarise(d, taux = mean(taux), .by = c(mesure, genre)),
             aes(xintercept = taux), linetype = "dashed", colour = col_dark) +
  facet_grid(genre ~ mesure) +
  scale_fill_manual(values = couleurs_genre, guide = "none") +
  scale_x_continuous(labels = pourcent, breaks = seq(0, 1, 0.25)) +
  scale_y_continuous(expand = expansion(c(0, 0.05))) +
  labs(
    title = "Les hommes disent plus souvent oui, et tout le monde n'est pas logé à la même enseigne",
    subtitle = "Distribution, entre participants, du taux de oui donnés et du taux de oui reçus. Trait pointillé : moyenne",
    x = "Taux de oui sur l'ensemble de ses dates", y = "Participants", caption = source_fisman
  )

sauver("04_decision", fig_decision, height = 5.8)

# --- 6. Les notes données au partenaire --------------------------------------

notes <- dates |>
  select(iid, pid, genre, dec, all_of(names(lab_notes))) |>
  pivot_longer(all_of(names(lab_notes)), names_to = "critere", values_to = "note") |>
  filter(!is.na(note)) |>
  mutate(note = round(note), critere = factor(lab_notes[critere], levels = lab_notes))

# Écart de taux de oui entre une note de 8+ et une note de 4 ou moins
notes |>
  summarise(bas = mean(dec[note <= 4]), haut = mean(dec[note >= 8]), .by = critere) |>
  mutate(ecart = haut - bas) |>
  arrange(desc(ecart))

fig_notes <- notes |>
  summarise(taux_oui = mean(dec), n = n(), .by = c(critere, genre, note)) |>
  filter(n >= 20) |>
  ggplot(aes(x = note, y = taux_oui, colour = genre)) +
  geom_line(linewidth = 0.9) +
  geom_point(aes(size = n), alpha = 0.8) +
  facet_wrap(~critere, nrow = 2) +
  scale_colour_manual(values = couleurs_genre, name = NULL) +
  scale_size_area(max_size = 3.5, guide = "none") +
  scale_x_continuous(breaks = seq(0, 10, 2)) +
  scale_y_continuous(labels = pourcent, limits = c(0, 1)) +
  labs(
    title = "L'attirance physique est le critère qui fait le plus varier le oui",
    subtitle = "Taux de oui selon la note (0 à 10) donnée au partenaire. Taille du point : nombre de dates ; notes avec moins de 20 dates masquées",
    x = "Note donnée au partenaire", y = "Taux de oui", caption = source_fisman
  )

sauver("05_notes", fig_notes, height = 6)

# Les notes sont corrélées entre elles : effet de halo
cor_notes <- dates |>
  select(all_of(names(lab_notes)), like) |>
  cor(use = "pairwise.complete.obs")
round(cor_notes, 2)

# --- 7. Les variables Census -------------------------------------------------

participants |> count(a_un_zip = !is.na(zip5), census_match, census)
summary(participants$zip_median_income_2021)
summary(participants$zip_gini_2021)
sum(participants$zip_median_income_2021 >= 250000, na.rm = TRUE)   # plafond du Census

# Repères nationaux : revenu médian des ménages 60 k$ et Gini ~0,48 (ACS 2017-2021)
census_us <- read_csv("data/census_acs2021_zcta.csv", show_col_types = FALSE)
median(census_us$zip_median_income_2021, na.rm = TRUE)

fig_revenu <- bind_rows(
  census_us |> transmute(groupe = "Tous les codes postaux des États-Unis", revenu = zip_median_income_2021),
  participants |> transmute(groupe = "Codes postaux d'enfance des participants", revenu = zip_median_income_2021)
) |>
  filter(!is.na(revenu)) |>
  ggplot(aes(x = revenu, fill = groupe, colour = groupe)) +
  geom_density(alpha = 0.35, linewidth = 0.7) +
  scale_x_log10(labels = dollars, breaks = c(25e3, 50e3, 100e3, 200e3)) +
  scale_fill_manual(values = c(col_accent, col_neutre), name = NULL) +
  scale_colour_manual(values = c(col_accent, col_muted), name = NULL) +
  scale_y_continuous(expand = expansion(c(0, 0.05))) +
  guides(fill = guide_legend(nrow = 2)) +
  labs(title = "Des quartiers plus aisés que la moyenne américaine",
       x = "Revenu médian des ménages du code postal (échelle log)", y = "Densité") +
  theme(axis.text.y = element_blank(), panel.grid.major.y = element_blank())

validation <- participants |> filter(!is.na(income_2000), !is.na(zip_median_income_2021))
r_validation <- cor(log(validation$income_2000), log(validation$zip_median_income_2021))

fig_validation <- validation |>
  ggplot(aes(x = income_2000, y = zip_median_income_2021)) +
  geom_point(alpha = 0.5, colour = col_accent, size = 1.8) +
  geom_smooth(method = "lm", formula = y ~ x, se = FALSE, colour = col_dark, linewidth = 0.6) +
  scale_x_log10(labels = dollars) +
  scale_y_log10(labels = dollars) +
  annotate("text", x = 9e3, y = 210e3, hjust = 0, colour = col_dark, size = 3.6,
           label = paste0("r = ", virgule(r_validation), " (log-log)\nn = ", nrow(validation), " participants")) +
  labs(title = "Le revenu 2021 conserve le classement de 2000",
       x = "Revenu médian 2000 (fourni par les auteurs)", y = "Revenu médian 2021 (Census)")

fig_census <- ((fig_revenu | fig_validation) & theme_sous_titre) +
  plot_annotation(
    title = "Le quartier d'enfance, notre mesure du milieu social",
    subtitle = "394 participants sur 551 ont un revenu Census. Un point = un participant",
    caption = source_census,
    theme = theme(plot.title = element_text(size = 14))
  )

sauver("06_census", fig_census, width = 11, height = 5.2)

# --- 8. Qui perd-on faute de code postal ? -----------------------------------

participants |> count(census)

# Lieu d'origine déclaré par les participants sans Census : beaucoup de pays étrangers
participants |> filter(!census) |> count(from, sort = TRUE) |> head(10)

popularite <- dates |> summarise(oui_donnes = mean(dec), oui_recus = mean(dec_o, na.rm = TRUE), .by = iid)

biais <- participants |>
  left_join(popularite, by = "iid") |>
  summarise(
    `Femmes` = mean(gender == 0),
    `Blancs` = mean(race == 2, na.rm = TRUE),
    `Asiatiques` = mean(race == 4, na.rm = TRUE),
    `Taux de oui donnés` = mean(oui_donnes),
    `Taux de oui reçus` = mean(oui_recus),
    n = n(), .by = census
  ) |>
  pivot_longer(-c(census, n), names_to = "indicateur", values_to = "valeur") |>
  mutate(groupe = if_else(census, "Avec données Census (n = 394)", "Sans données Census (n = 157)"))
print(biais)

fig_biais <- biais |>
  mutate(indicateur = fct_rev(fct_inorder(indicateur))) |>
  ggplot(aes(x = valeur, y = indicateur)) +
  geom_line(aes(group = indicateur), colour = col_neutre, linewidth = 1.2) +
  geom_point(aes(colour = groupe), size = 3.5) +
  scale_colour_manual(values = c(col_accent, col_alerte), name = NULL) +
  scale_x_continuous(labels = pourcent, limits = c(0, 0.7)) +
  labs(
    title = "Les participants sans données Census ne sont pas un échantillon au hasard",
    subtitle = "125 sur 157 n'ont pas donné de code postal américain : plus d'hommes, plus d'Asiatiques, moins de oui reçus",
    x = NULL, y = NULL, caption = source_census
  ) +
  theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(colour = col_dark, size = 11))

sauver("07_biais_selection", fig_biais, height = 4.5)

# --- 9. L'écart social entre les deux partenaires ----------------------------

dates_census <- dates |> filter(!is.na(abs_diff_log_income))
nrow(dates_census)
summary(exp(dates_census$abs_diff_log_income))   # rapport entre le revenu le plus haut et le plus bas

# Premier regard, sans contrôle : taux de oui par quintile d'écart de revenu
quintiles <- dates_census |>
  mutate(quintile = ntile(abs_diff_log_income, 5)) |>
  summarise(
    taux_oui = mean(dec), n = n(),
    rapport_min = exp(min(abs_diff_log_income)), rapport_max = exp(max(abs_diff_log_income)),
    .by = quintile
  ) |>
  arrange(quintile) |>
  mutate(
    # Intervalle de confiance naïf : ignore la répétition des personnes, donc trop étroit
    se = sqrt(taux_oui * (1 - taux_oui) / n),
    etiquette = paste0("Q", quintile, "\n× ", virgule(rapport_min), " à ", virgule(rapport_max))
  )
print(quintiles)

fig_ecart_distribution <- dates_census |>
  ggplot(aes(x = exp(abs_diff_log_income))) +
  geom_histogram(bins = 40, fill = col_neutre, colour = "white", linewidth = 0.2) +
  scale_x_log10(breaks = c(1, 1.5, 2, 3, 5, 8), labels = \(x) paste0("× ", virgule(x, 1))) +
  scale_y_continuous(expand = expansion(c(0, 0.05))) +
  labs(title = "Écart de revenu entre les deux quartiers",
       x = "Rapport entre le revenu le plus élevé et le plus faible (échelle log)", y = "Dates")

fig_ecart_oui <- quintiles |>
  ggplot(aes(x = etiquette, y = taux_oui)) +
  geom_hline(yintercept = mean(dates_census$dec), linetype = "dashed", colour = col_muted) +
  geom_pointrange(aes(ymin = taux_oui - 1.96 * se, ymax = taux_oui + 1.96 * se),
                  colour = col_accent, size = 0.7, linewidth = 0.9) +
  scale_y_continuous(labels = pourcent, limits = c(0, 0.6)) +
  labs(title = "Taux de oui selon l'écart",
       x = "Quintile d'écart de revenu (du plus proche au plus éloigné)", y = "Taux de oui")

fig_ecart <- ((fig_ecart_distribution | fig_ecart_oui) & theme_sous_titre) +
  plot_annotation(
    title = "À l'état brut, l'écart social ne fait presque pas bouger le taux de oui",
    subtitle = "4 424 dates où le revenu du quartier est connu pour les deux personnes. Pointillé : taux de oui moyen. Barres : IC à 95 % naïf",
    caption = source_census,
    theme = theme(plot.title = element_text(size = 14))
  )

sauver("08_ecart_social", fig_ecart, width = 11, height = 5)
