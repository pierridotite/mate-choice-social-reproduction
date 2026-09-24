# Exploration du jeu de données Speed Dating x Census
# Objectif : comprendre la structure, la qualité et les variables clés avant toute modélisation.
# Les figures sont exportées dans outputs/exploration/ et commentées dans exploration.md.
#
# À lancer depuis la racine du dépôt : Rscript R/02_exploration.R

library(tidyverse)
library(patchwork)
source("R/commun.R")

dir_fig <- "outputs/exploration"
dir.create(dir_fig, showWarnings = FALSE, recursive = TRUE)

set.seed(2026)   # dispersion des points (figure 2) et bootstrap (figure 8) reproductibles

# --- 1. Import et recodage ---------------------------------------------------

brut <- read_csv("data/speed_dating_census.csv", show_col_types = FALSE, guess_max = 10000)

glimpse(brut[, 1:20])

dates <- brut |>
  mutate(
    genre = if_else(gender == 0, "Femmes", "Hommes"),
    race_lab = libeller(race, lab_race),
    field_lab = libeller(field_cd, lab_field),
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
dates_par_personne <- dates |> count(iid) |> pull(n)
summary(dates_par_personne)

# Chaque femme rencontre tous les hommes de sa vague : son nombre de dates est égal
# au nombre d'hommes de la vague
dates |>
  summarise(hommes = n_distinct(iid[genre == "Hommes"]),
            dates_femme_min = min(table(iid[genre == "Femmes"])),
            dates_femme_max = max(table(iid[genre == "Femmes"])), .by = wave) |>
  with(stopifnot(all(dates_femme_min == hommes), all(dates_femme_max == hommes)))

fig_vagues <- vagues |>
  ggplot(aes(x = factor(wave), y = participants, fill = genre)) +
  geom_col(position = "dodge", width = 0.75) +
  scale_fill_manual(values = couleurs_genre, name = NULL) +
  scale_y_continuous(expand = expansion(c(0, 0.05))) +
  labs(
    title = "21 soirées de tailles très inégales, à peu près équilibrées entre femmes et hommes",
    subtitle = paste0("Nombre de participants par vague. Chaque femme rencontre tous les hommes de sa vague : de ",
                      min(dates_par_personne), " à ", max(dates_par_personne), " dates par personne"),
    x = "Vague", y = "Participants", caption = source_fisman
  ) +
  theme(panel.grid.major.x = element_blank())

sauver(fig_vagues, file.path(dir_fig, "01_vagues.png"), height = 4.8)

# --- 3. Données manquantes ---------------------------------------------------

# Les 217 colonnes viennent de questionnaires remplis à des moments différents :
# on regroupe les colonnes par moment de collecte pour lire les manquants par bloc
bloc_colonne <- function(nom) {
  case_when(
    str_detect(nom, "census|zip_|zip5|diff_|income_2000") ~ "Census (notre ajout)",
    str_detect(nom, "_3$") | nom %in% c("you_call", "them_cal") ~ "Suivi à 3-4 semaines",
    str_detect(nom, "_2$") | nom == "length" ~ "Suivi le lendemain",
    str_detect(nom, "_s$") ~ "Mi-soirée",
    nom %in% c("dec", "attr", "sinc", "intel", "fun", "amb", "shar", "like", "prob",
               "met", "match_es") ~ "Fiche de notation (après chaque date)",
    str_detect(nom, "_o$|^pf_o_") ~ "Réponses du partenaire (_o)",
    nom %in% c("iid", "id", "gender", "idg", "condtn", "wave", "round", "position", "positin1",
               "order", "partner", "pid", "match", "int_corr", "samerace") ~ "Protocole",
    TRUE ~ "Questionnaire d'inscription"
  )
}

manquants <- tibble(
  colonne = names(brut),
  taux_na = map_dbl(brut, \(x) mean(is.na(x)))
) |>
  mutate(bloc = bloc_colonne(colonne))

manquants_bloc <- manquants |>
  summarise(colonnes = n(), taux_median = median(taux_na), taux_min = min(taux_na),
            taux_max = max(taux_na), .by = bloc) |>
  arrange(taux_median)
print(manquants_bloc)

# Colonnes du questionnaire d'inscription les plus incomplètes
manquants |> filter(bloc == "Questionnaire d'inscription") |> slice_max(taux_na, n = 6)

fig_manquants <- manquants |>
  mutate(bloc = fct_reorder(bloc, taux_na, .fun = median)) |>
  ggplot(aes(x = taux_na, y = bloc)) +
  geom_jitter(height = 0.18, width = 0, alpha = 0.55, size = 1.8, colour = col_accent) +
  scale_x_continuous(labels = pourcent, limits = c(0, 1), expand = expansion(c(0.01, 0.02))) +
  labs(
    title = "Les questionnaires de suivi sont très incomplets, le cœur de l'expérience est presque complet",
    subtitle = paste0("Taux de valeurs manquantes des ", ncol(brut),
                      " colonnes (un point par colonne), regroupées par moment de collecte"),
    x = "Part de valeurs manquantes", y = NULL, caption = source_census
  ) +
  theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(colour = col_dark))

sauver(fig_manquants, file.path(dir_fig, "02_manquants.png"), height = 4.8)

# `met` (« avez-vous déjà rencontré cette personne ? ») devrait valoir 1 (oui) ou 2 (non)
table(dates$met, useNA = "ifany")

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

# Barres horizontales triées, valeur écrite au bout de la barre (pas besoin d'axe)
barres_triees <- function(data, variable, titre) {
  data |>
    ggplot(aes(x = part, y = {{ variable }})) +
    geom_col(fill = col_neutre, width = 0.7) +
    geom_text(aes(label = pourcent(part)), hjust = -0.15, size = 3.3, colour = col_dark) +
    scale_x_continuous(expand = expansion(c(0, 0.18))) +
    labs(title = titre, x = NULL, y = NULL) +
    theme(panel.grid.major = element_blank(), axis.text.x = element_blank())
}

fig_race <- participants |>
  filter(!is.na(race_lab)) |>
  count(race_lab) |>
  mutate(part = n / sum(n), race_lab = fct_reorder(race_lab, n)) |>
  barres_triees(race_lab, "Origine déclarée")

fig_field <- participants |>
  filter(!is.na(field_lab)) |>
  count(field_lab) |>
  mutate(part = n / sum(n),
         field_lab = fct_lump_n(field_lab, 9, w = n, other_level = "Autres domaines")) |>
  summarise(part = sum(part), .by = field_lab) |>
  mutate(field_lab = fct_reorder(field_lab, part),
         field_lab = fct_relevel(field_lab, "Autres domaines")) |>
  barres_triees(field_lab, "Domaine d'études")

fig_profil <- ((fig_age | (fig_race / fig_field + plot_layout(heights = c(1, 1.9)))) &
                 theme_sous_titre) +
  plot_annotation(
    title = paste0("Des étudiants de Columbia de ", round(mean(participants$age, na.rm = TRUE)),
                   " ans en moyenne, majoritairement blancs ou asiatiques"),
    subtitle = paste0("Profil des ", nrow(participants), " participants"),
    caption = source_fisman,
    theme = theme(plot.title = element_text(size = 14))
  )

sauver(fig_profil, file.path(dir_fig, "03_profil.png"), height = 6)

# --- 5. La variable réponse : dire oui ---------------------------------------

dates |> summarise(taux_oui = mean(dec), taux_match = mean(match))
dates |> summarise(taux_oui = mean(dec), .by = genre)

# Taux de oui par vague
vagues |>
  summarise(taux_oui = weighted.mean(taux_oui, dates), .by = wave) |>
  pull(taux_oui) |>
  range()

# Hétérogénéité entre personnes : sélectivité (oui donnés) et popularité (oui reçus)
par_personne <- dates |>
  summarise(
    `Oui donnés (sélectivité du juge)` = mean(dec),
    `Oui reçus (popularité du partenaire)` = mean(dec_o, na.rm = TRUE),
    n_dates = n(), .by = c(iid, genre)
  ) |>
  pivot_longer(starts_with("Oui"), names_to = "mesure", values_to = "taux")

par_personne |>
  summarise(moyenne = mean(taux), ecart_type = sd(taux),
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
    title = "Les hommes disent plus souvent oui, et les écarts entre personnes sont énormes",
    subtitle = "Distribution, entre participants, du taux de oui donnés et du taux de oui reçus. Trait pointillé : moyenne",
    x = "Taux de oui sur l'ensemble de ses dates", y = "Participants", caption = source_fisman
  )

sauver(fig_decision, file.path(dir_fig, "04_decision.png"), height = 5.8)

# --- 6. Les notes données au partenaire --------------------------------------

# Quelques notes sont des demi-points : arrondi classique à l'entier (6,5 -> 7)
notes <- dates |>
  select(iid, pid, genre, dec, all_of(names(lab_notes))) |>
  pivot_longer(all_of(names(lab_notes)), names_to = "critere", values_to = "note") |>
  filter(!is.na(note)) |>
  mutate(note = floor(note + 0.5), critere = factor(lab_notes[critere], levels = lab_notes))

# Écart de taux de oui entre une note de 8+ et une note de 4 ou moins
notes |>
  summarise(bas = mean(dec[note <= 4]), haut = mean(dec[note >= 8]), .by = critere) |>
  mutate(ecart = haut - bas) |>
  arrange(desc(ecart))

taux_par_note <- notes |>
  summarise(taux_oui = mean(dec), n = n(), juges = n_distinct(iid), .by = c(critere, genre, note))

# Le point le plus isolé : intérêts communs notés 0 par les hommes
taux_par_note |> filter(critere == "Intérêts communs", genre == "Hommes", note == 0)

fig_notes <- taux_par_note |>
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

sauver(fig_notes, file.path(dir_fig, "05_notes.png"), height = 6)

# Les notes sont corrélées entre elles : effet de halo
cor_notes <- dates |>
  select(all_of(names(lab_notes)), like) |>
  cor(use = "pairwise.complete.obs")
round(cor_notes, 2)
range(cor_notes[names(lab_notes), names(lab_notes)][lower.tri(diag(6))])

# Part des dates où les six notes sont renseignées
mean(complete.cases(dates[names(lab_notes)]))

# --- 7. Les variables Census -------------------------------------------------

participants |> count(a_un_zip = !is.na(zip5), census_match, census)
summary(participants$zip_median_income_2021)
summary(participants$zip_gini_2021)
sum(participants$zip_median_income_2021 >= 250000, na.rm = TRUE)   # plafond du Census

# Référence : la population des États-Unis, chaque code postal pesant selon son nombre
# d'habitants (sans pondération, les petits codes postaux ruraux compteraient autant
# que les grands codes postaux urbains)
census_us <- read_csv("data/census_acs2021_zcta.csv", show_col_types = FALSE) |>
  filter(!is.na(zip_median_income_2021), !is.na(zip_population_2021))

mediane_ponderee <- with(census_us, {
  ordre <- order(zip_median_income_2021)
  cumul <- cumsum(zip_population_2021[ordre]) / sum(zip_population_2021)
  zip_median_income_2021[ordre][which(cumul >= 0.5)[1]]
})
mediane_participants <- median(participants$zip_median_income_2021, na.rm = TRUE)
# Part des Américains qui vivent dans un code postal plus aisé que le quartier
# d'enfance médian des participants
part_plus_aises <- with(census_us, {
  sum(zip_population_2021[zip_median_income_2021 > mediane_participants]) / sum(zip_population_2021)
})
cat("Médiane pondérée US :", mediane_ponderee,
    "| médiane des participants :", mediane_participants,
    "| part des Américains dans un code postal plus aisé :", round(part_plus_aises, 3), "\n")

densites <- bind_rows(
  census_us |> transmute(groupe = "Population des États-Unis, selon son code postal",
                         revenu = zip_median_income_2021, poids = zip_population_2021),
  participants |> filter(census) |>
    transmute(groupe = "Participants, selon leur code postal d'enfance",
              revenu = zip_median_income_2021, poids = 1)
) |>
  mutate(poids = poids / sum(poids), .by = groupe)

fig_revenu <- densites |>
  ggplot(aes(x = revenu, fill = groupe, colour = groupe, weight = poids)) +
  geom_density(alpha = 0.35, linewidth = 0.7) +
  scale_x_log10(labels = dollars, breaks = c(25e3, 50e3, 100e3, 200e3)) +
  # Quelques codes postaux très pauvres étirent l'axe vers la gauche : on cadre sur
  # l'essentiel de la distribution sans modifier les densités
  coord_cartesian(xlim = c(18e3, 260e3)) +
  scale_fill_manual(values = c(col_accent, col_neutre), name = NULL) +
  scale_colour_manual(values = c(col_accent, col_muted), name = NULL) +
  scale_y_continuous(expand = expansion(c(0, 0.05))) +
  guides(fill = guide_legend(nrow = 2)) +
  labs(title = "Des quartiers d'enfance bien plus aisés que la moyenne",
       x = "Revenu médian des ménages du code postal (échelle log)", y = "Densité") +
  theme(axis.text.y = element_blank(), panel.grid.major.y = element_blank())

validation <- participants |> filter(!is.na(income_2000), !is.na(zip_median_income_2021))
# Corrélation de rang : c'est le classement des quartiers qui compte pour mesurer un écart
rho_validation <- cor(validation$income_2000, validation$zip_median_income_2021,
                      method = "spearman")

fig_validation <- validation |>
  ggplot(aes(x = income_2000, y = zip_median_income_2021)) +
  geom_point(alpha = 0.5, colour = col_accent, size = 1.8) +
  geom_smooth(method = "lm", formula = y ~ x, se = FALSE, colour = col_dark, linewidth = 0.6) +
  scale_x_log10(labels = dollars) +
  scale_y_log10(labels = dollars) +
  annotate("text", x = 9e3, y = 210e3, hjust = 0, colour = col_dark, size = 3.6,
           label = paste0("Corrélation de rang : ", virgule(rho_validation), "\nn = ",
                          nrow(validation), " participants")) +
  labs(title = "Le revenu 2021 conserve le classement de 2000",
       x = "Revenu médian 2000, fourni par les auteurs (log)",
       y = "Revenu médian 2021, Census (log)")

fig_census <- ((fig_revenu | fig_validation) & theme_sous_titre) +
  plot_annotation(
    title = "Le quartier d'enfance, notre mesure du milieu social",
    subtitle = paste0(sum(participants$census), " participants sur ", nrow(participants),
                      " ont un revenu Census. Leur quartier d'enfance médian est plus aisé que celui de ",
                      pourcent(1 - part_plus_aises), " des Américains.\nÀ droite, un point = un participant"),
    caption = source_census,
    theme = theme(plot.title = element_text(size = 14))
  )

sauver(fig_census, file.path(dir_fig, "06_census.png"), width = 11, height = 5.2)

# --- 8. Qui perd-on faute de code postal ? -----------------------------------

participants |> count(census)

# Lieu d'origine déclaré par les participants sans Census : beaucoup de pays étrangers
participants |> filter(!census) |> count(from, sort = TRUE) |> head(10)

popularite <- dates |>
  summarise(oui_donnes = mean(dec), oui_recus = mean(dec_o, na.rm = TRUE), .by = iid)
participants <- participants |> left_join(popularite, by = "iid")

# Les écarts sont-ils plus grands que ce que le hasard produirait ?
chisq.test(table(participants$census, participants$gender))$p.value
chisq.test(table(participants$census, participants$race == 2))$p.value
chisq.test(table(participants$census, participants$race == 4))$p.value
t.test(oui_donnes ~ census, participants)$p.value
t.test(oui_recus ~ census, participants)$p.value
# L'écart de oui reçus persiste-t-il à genre égal ?
participants |> summarise(oui_recus = mean(oui_recus), n = n(), .by = c(genre, census))

effectifs_census <- participants |> count(census)
libelle_groupe <- function(avec) {
  paste0(if_else(avec, "Avec", "Sans"), " données Census (n = ",
         effectifs_census$n[match(avec, effectifs_census$census)], ")")
}

biais <- participants |>
  summarise(
    `Femmes` = mean(gender == 0),
    `Blancs` = mean(race == 2, na.rm = TRUE),
    `Asiatiques` = mean(race == 4, na.rm = TRUE),
    `Taux de oui donnés` = mean(oui_donnes),
    `Taux de oui reçus` = mean(oui_recus),
    .by = census
  ) |>
  pivot_longer(-census, names_to = "indicateur", values_to = "valeur") |>
  mutate(groupe = libelle_groupe(census))
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
    subtitle = paste0("La plupart n'ont pas de code postal américain (",
                      sum(!participants$census & is.na(participants$zip5)),
                      " sur ", sum(!participants$census), ").\nPlus d'hommes, moins de Blancs, ",
                      "plus de oui donnés et moins de oui reçus que les autres participants"),
    x = NULL, y = NULL, caption = source_census
  ) +
  theme(panel.grid.major.y = element_blank(),
        axis.text.y = element_text(colour = col_dark, size = 11))

sauver(fig_biais, file.path(dir_fig, "07_biais_selection.png"), height = 4.8)

# --- 9. L'écart social entre les deux partenaires ----------------------------

dates_census <- dates |> filter(!is.na(abs_diff_log_income))
# Chaque rencontre apparaît deux fois (une ligne par personne) avec le même écart :
# pour décrire les écarts, on ne garde qu'une ligne par rencontre
rencontres <- dates_census |> filter(iid < pid)
stopifnot(nrow(rencontres) * 2 == nrow(dates_census))
summary(exp(rencontres$abs_diff_log_income))   # rapport entre le revenu le plus haut et le plus bas

# Premier regard, sans contrôle : taux de oui par quintile d'écart de revenu
dates_census <- dates_census |> mutate(quintile = ntile(abs_diff_log_income, 5))

quintiles <- dates_census |>
  summarise(
    taux_oui = mean(dec), n = n(),
    rapport_min = exp(min(abs_diff_log_income)), rapport_max = exp(max(abs_diff_log_income)),
    .by = quintile
  ) |>
  arrange(quintile)

# Intervalles de confiance par bootstrap sur les juges : on tire des personnes avec remise
# et on garde toutes leurs décisions, ce qui respecte la répétition des décisions d'un même
# juge (un intervalle binomial classique serait trop étroit)
par_juge <- dates_census |> summarise(oui = sum(dec), n = n(), .by = c(iid, quintile))
juges <- unique(par_juge$iid)
bootstrap <- map(1:1000, \(b) {
  tibble(iid = sample(juges, replace = TRUE)) |>
    inner_join(par_juge, by = "iid", relationship = "many-to-many") |>
    summarise(taux_oui = sum(oui) / sum(n), .by = quintile)
}) |>
  list_rbind()

intervalles <- bootstrap |>
  summarise(bas = quantile(taux_oui, 0.025), haut = quantile(taux_oui, 0.975), .by = quintile)

quintiles <- quintiles |>
  left_join(intervalles, by = "quintile") |>
  mutate(etiquette = paste0("Q", quintile, "\n× ", virgule(rapport_min),
                            " à ", virgule(rapport_max)))
print(quintiles)

fig_ecart_distribution <- rencontres |>
  ggplot(aes(x = exp(abs_diff_log_income))) +
  geom_histogram(bins = 40, fill = col_neutre, colour = "white", linewidth = 0.2) +
  scale_x_log10(breaks = c(1, 1.5, 2, 3, 5, 8), labels = fois) +
  scale_y_continuous(expand = expansion(c(0, 0.05))) +
  labs(title = "Écart de revenu entre les deux quartiers",
       x = "Rapport entre le revenu le plus élevé et le plus faible (échelle log)",
       y = "Rencontres")

fig_ecart_oui <- quintiles |>
  ggplot(aes(x = etiquette, y = taux_oui)) +
  geom_hline(yintercept = mean(dates_census$dec), linetype = "dashed", colour = col_muted) +
  geom_pointrange(aes(ymin = bas, ymax = haut), colour = col_accent, size = 0.7, linewidth = 0.9) +
  scale_y_continuous(labels = pourcent, limits = c(0, 0.6)) +
  labs(title = "Taux de oui selon l'écart",
       x = "Quintile d'écart de revenu (du plus proche au plus éloigné)", y = "Taux de oui")

fig_ecart <- ((fig_ecart_distribution | fig_ecart_oui) & theme_sous_titre) +
  plot_annotation(
    title = "À l'état brut, l'écart social ne fait presque pas bouger le taux de oui",
    subtitle = paste0(milliers(nrow(rencontres)), " rencontres (", milliers(nrow(dates_census)),
                      " décisions) où le revenu du quartier est connu des deux côtés. ",
                      "Pointillé : taux de oui moyen.\nBarres : intervalle de confiance à 95 % par bootstrap sur les juges"),
    caption = source_census,
    theme = theme(plot.title = element_text(size = 14))
  )

sauver(fig_ecart, file.path(dir_fig, "08_ecart_social.png"), width = 11, height = 5.2)
