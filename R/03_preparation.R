# Préparation du jeu d'analyse
# Objectif : figer une fois pour toutes les variables et l'échantillon utilisés par les
# modèles (04_modeles.R) et par l'application Shiny, à partir des constats de l'exploration.
#
# Entrée  : data/speed_dating_census.csv (jamais modifié)
# Sorties : outputs/dates.rds         une ligne par date orienté, 8 378 lignes
#           outputs/participants.rds  une ligne par participant, 551 lignes
# L'échantillon d'analyse est repéré par la colonne `echantillon` de dates.rds.
#
# À lancer depuis la racine du dépôt : Rscript R/03_preparation.R

library(tidyverse)

dir.create("outputs", showWarnings = FALSE)

# --- 1. Import ---------------------------------------------------------------

brut <- read_csv("data/speed_dating_census.csv", show_col_types = FALSE, guess_max = 10000)

# --- 2. Libellés (dictionnaire des auteurs) ----------------------------------

lab_race <- c("1" = "Noir", "2" = "Blanc", "3" = "Latino", "4" = "Asiatique", "6" = "Autre")
lab_field <- c(
  "1" = "Droit", "2" = "Mathématiques", "3" = "Sciences sociales, psychologie",
  "4" = "Médecine, pharmacie, biotech", "5" = "Ingénierie", "6" = "Lettres, journalisme",
  "7" = "Histoire, religion, philosophie", "8" = "Commerce, économie, finance",
  "9" = "Éducation", "10" = "Biologie, chimie, physique", "11" = "Travail social",
  "12" = "Indécis", "13" = "Science politique, relations internationales", "14" = "Cinéma",
  "15" = "Beaux-arts", "16" = "Langues", "17" = "Architecture", "18" = "Autre"
)

# --- 3. Table des participants -----------------------------------------------

# Les attributs individuels sont répétés sur chaque date : on en garde une ligne par iid
participants <- brut |>
  distinct(iid, .keep_all = TRUE) |>
  transmute(
    iid, wave,
    genre = factor(if_else(gender == 0, "Femme", "Homme")),
    age,
    race = factor(recode(as.character(race), !!!lab_race)),
    field_cd,
    domaine = factor(recode(as.character(field_cd), !!!lab_field)),
    zip5,
    revenu_2000 = income_2000,
    revenu = zip_median_income_2021,
    revenu_moe = zip_median_income_2021_moe,
    gini = zip_gini_2021,
    # Le Census plafonne le revenu médian à 250 001 $ : valeur censurée
    revenu_plafonne = !is.na(revenu) & revenu >= 250000,
    # Marge d'erreur relative (IC à 90 %) : repère les petits quartiers peu fiables
    revenu_moe_rel = revenu_moe / revenu,
    census = !is.na(revenu)
  )

# Terciles de revenu calculés sur les participants (et non sur les dates, où les
# personnes des grandes vagues compteraient davantage)
bornes_terciles <- quantile(participants$revenu, c(1 / 3, 2 / 3), na.rm = TRUE)
participants <- participants |>
  mutate(tercile_revenu = cut(revenu, c(-Inf, bornes_terciles, Inf),
                              labels = c("Modeste", "Intermédiaire", "Aisé")))

# --- 4. Table des dates ------------------------------------------------------

# Variables du partenaire absentes de la table d'origine (domaine, revenu 2000,
# tercile) : on les récupère par jointure sur pid
partenaires <- participants |>
  select(pid = iid, field_cd_o = field_cd, revenu_2000_o = revenu_2000,
         tercile_revenu_o = tercile_revenu, revenu_plafonne_o = revenu_plafonne,
         revenu_moe_rel_o = revenu_moe_rel)

dates <- brut |>
  transmute(
    # Protocole
    iid, pid, wave,
    grande_vague = condtn == 2,
    # Réponses
    dec, dec_o, match,
    # Qui juge
    genre = factor(if_else(gender == 0, "Femme", "Homme")),
    age, age_o,
    race = factor(recode(as.character(race), !!!lab_race)),
    race_o = factor(recode(as.character(race_o), !!!lab_race)),
    samerace = samerace == 1,
    field_cd,
    int_corr,
    # Notes données au partenaire (0 à 10)
    attr, sinc, intel, fun, amb, shar, like, prob,
    # Milieu d'origine des deux personnes
    revenu = zip_median_income_2021, revenu_o = zip_median_income_2021_o,
    gini = zip_gini_2021, gini_o = zip_gini_2021_o,
    revenu_2000 = income_2000
  ) |>
  left_join(partenaires, by = "pid") |>
  left_join(participants |> select(iid, tercile_revenu, revenu_plafonne, revenu_moe_rel),
            by = "iid") |>
  mutate(
    # Écart social, en log : un écart de 1 correspond à un rapport de revenus de e ≈ 2,7
    ecart_revenu_signe = log(revenu_o) - log(revenu),   # > 0 : partenaire plus aisé
    ecart_revenu = abs(ecart_revenu_signe),
    ecart_revenu_2000_signe = log(revenu_2000_o) - log(revenu_2000),
    ecart_revenu_2000 = abs(ecart_revenu_2000_signe),
    ecart_gini_signe = gini_o - gini,
    ecart_gini = abs(ecart_gini_signe),
    meme_tercile = tercile_revenu == tercile_revenu_o,
    # Contrôles
    ecart_age = abs(age_o - age),
    meme_domaine = field_cd == field_cd_o,
    # Revenu du quartier de chacun, en log, pour tester une préférence de statut
    log_revenu = log(revenu),
    log_revenu_o = log(revenu_o),
    # Échantillon d'analyse : revenu connu des deux côtés
    echantillon = !is.na(ecart_revenu),
    # Échantillon de robustesse : sans quartier plafonné ni quartier à marge d'erreur
    # relative supérieure à 30 %
    echantillon_fiable = echantillon & !revenu_plafonne & !revenu_plafonne_o &
      revenu_moe_rel <= 0.3 & revenu_moe_rel_o <= 0.3
  ) |>
  select(-revenu_plafonne_o, -revenu_moe_rel, -revenu_moe_rel_o)

# --- 5. Vérifications --------------------------------------------------------

stopifnot(
  nrow(dates) == 8378,
  nrow(participants) == 551,
  !any(duplicated(dates[, c("iid", "pid")])),
  all(dates$match == dates$dec * dates$dec_o),
  # Notre écart signé est l'opposé de celui calculé à la jointure Census
  isTRUE(all.equal(dates$ecart_revenu_signe, -brut$diff_log_income_2021)),
  isTRUE(all.equal(dates$ecart_gini_signe, -brut$diff_gini_2021)),
  # Une date et sa réciproque ont le même écart absolu
  dates |>
    inner_join(dates |> select(iid, pid, ecart_revenu), by = c("iid" = "pid", "pid" = "iid")) |>
    with(isTRUE(all.equal(ecart_revenu.x, ecart_revenu.y)))
)

# --- 6. Bilan de l'échantillon -----------------------------------------------

cat("Dates :", nrow(dates), "| échantillon d'analyse :", sum(dates$echantillon),
    "| échantillon fiable :", sum(dates$echantillon_fiable), "\n")

ech <- filter(dates, echantillon)
cat("Participants (juges) dans l'échantillon :", n_distinct(ech$iid), "\n")

# Taux de manquants des variables du modèle dans l'échantillon
ech |>
  summarise(across(c(dec, ecart_revenu, samerace, ecart_age, meme_domaine, int_corr,
                     attr, fun, shar, intel, sinc, amb),
                   \(x) mean(is.na(x)))) |>
  pivot_longer(everything(), names_to = "variable", values_to = "taux_na") |>
  print()

cat("Lignes complètes pour le modèle avec contrôles et notes :",
    sum(complete.cases(ech[, c("dec", "ecart_revenu", "samerace", "ecart_age",
                               "meme_domaine", "int_corr", "attr", "fun", "shar")])), "\n")

participants |> count(tercile_revenu)
print(bornes_terciles)

# --- 7. Export ---------------------------------------------------------------

saveRDS(dates, "outputs/dates.rds")
saveRDS(participants, "outputs/participants.rds")
