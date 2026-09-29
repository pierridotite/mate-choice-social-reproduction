# Données de l'application : toutes les colonnes du jeu enrichi, les variables dérivées de
# 03_preparation.R, une table avec une ligne par participant et un dictionnaire des variables.

# --- Codes du questionnaire (dictionnaire des auteurs) ------------------------

frequences <- c("1" = "Plusieurs fois par semaine", "2" = "Deux fois par semaine",
                "3" = "Une fois par semaine", "4" = "Deux fois par mois",
                "5" = "Une fois par mois", "6" = "Plusieurs fois par an",
                "7" = "Presque jamais")

codes_variables <- list(
  gender = c("0" = "Femme", "1" = "Homme"),
  condtn = c("1" = "Petite soirée", "2" = "Grande soirée"),
  race = lab_race,
  race_o = lab_race,
  field_cd = lab_field,
  goal = c("1" = "Passer une bonne soirée", "2" = "Rencontrer de nouvelles personnes",
           "3" = "Obtenir un rendez-vous", "4" = "Chercher une relation sérieuse",
           "5" = "Pouvoir dire qu'on l'a fait", "6" = "Autre"),
  date = frequences,
  go_out = frequences,
  career_c = c("1" = "Droit", "2" = "Recherche, université", "3" = "Psychologie",
               "4" = "Médecine", "5" = "Ingénierie", "6" = "Arts, spectacle",
               "7" = "Banque, conseil, finance, commerce", "8" = "Immobilier",
               "9" = "Affaires internationales, humanitaire", "10" = "Indécis",
               "11" = "Travail social", "12" = "Orthophonie", "13" = "Politique",
               "14" = "Sport professionnel", "15" = "Autre", "16" = "Journalisme",
               "17" = "Architecture"),
  length = c("1" = "Trop courts", "2" = "Trop longs", "3" = "Juste bien"),
  numdat_2 = c("1" = "Trop peu", "2" = "Trop", "3" = "Juste bien")
)

# Identifiants et textes libres : consultables dans les tables, pas dans les graphiques
identifiants <- c("iid", "id", "idg", "pid", "partner", "zipcode", "zip5", "zip5_o", "income")
textes_libres <- c("field", "from", "career", "undergra")

# --- Libellés des variables ---------------------------------------------------

criteres <- c(attr = "attirance", sinc = "sincérité", intel = "intelligence",
              fun = "humour", amb = "ambition", shar = "intérêts communs")

libelles_directs <- c(
  # Protocole
  iid = "Identifiant du participant", id = "Numéro dans la vague", gender = "Genre",
  idg = "Numéro dans la vague et le genre", condtn = "Taille de la soirée",
  wave = "Vague (soirée)", round = "Nombre de dates dans la soirée",
  position = "Table de départ", positin1 = "Table de départ du partenaire",
  order = "Rang du date dans la soirée", partner = "Numéro du partenaire",
  pid = "Identifiant du partenaire", match = "Match (oui des deux côtés)",
  int_corr = "Corrélation des centres d'intérêt des deux personnes",
  samerace = "Même origine déclarée",
  # Le partenaire
  age_o = "Âge du partenaire", race_o = "Origine déclarée du partenaire",
  dec_o = "Décision du partenaire (oui)", like_o = "Appréciation globale reçue",
  prob_o = "Probabilité estimée par le partenaire que je dise oui",
  met_o = "Le partenaire m'avait déjà rencontré (codage d'origine)",
  # Questionnaire d'inscription
  age = "Âge", field = "Domaine d'études (texte libre)", field_cd = "Domaine d'études",
  undergra = "Université de licence", mn_sat = "Score SAT médian de l'université de licence",
  tuition = "Frais de scolarité de l'université de licence", race = "Origine déclarée",
  imprace = "Importance d'avoir la même origine (1 à 10)",
  imprelig = "Importance d'avoir la même religion (1 à 10)",
  from = "Lieu d'origine (texte libre)", zipcode = "Code postal d'enfance (brut)",
  income = "Revenu du code postal (brut, texte)", goal = "Objectif principal de la soirée",
  date = "Fréquence des rendez-vous amoureux", go_out = "Fréquence des sorties",
  career = "Métier visé (texte libre)", career_c = "Métier visé",
  exphappy = "Satisfaction attendue de la soirée (1 à 10)",
  expnum = "Nombre de oui attendus",
  # Fiche de notation
  dec = "Décision (oui)", like = "Appréciation globale donnée",
  prob = "Probabilité estimée que le partenaire dise oui",
  met = "Avait déjà rencontré le partenaire (codage d'origine)",
  match_es = "Nombre de matchs estimé en fin de soirée",
  # Suivis
  satis_2 = "Satisfaction vis-à-vis des personnes rencontrées (lendemain)",
  length = "Durée des dates de 4 minutes (lendemain)",
  numdat_2 = "Nombre de dates dans la soirée (lendemain)",
  you_call = "Nombre de matchs que j'ai contactés (3-4 semaines)",
  them_cal = "Nombre de matchs qui m'ont contacté (3-4 semaines)",
  # Census
  zip5 = "Code postal d'enfance (nettoyé)",
  census_match = "Code postal trouvé dans le Census",
  income_2000 = "Revenu médian du quartier d'enfance en 2000 ($)",
  zip_median_income_2021 = "Revenu médian du quartier d'enfance en 2021 ($)",
  zip_median_income_2021_moe = "Marge d'erreur du revenu 2021 ($)",
  zip_gini_2021 = "Indice de Gini du quartier d'enfance",
  zip_gini_2021_moe = "Marge d'erreur de l'indice de Gini",
  zip_population_2021 = "Population du quartier d'enfance",
  zip_population_2021_moe = "Marge d'erreur de la population",
  diff_income_2021 = "Écart de revenu 2021, moi moins le partenaire ($)",
  abs_diff_income_2021 = "Écart de revenu 2021, en valeur absolue ($)",
  diff_log_income_2021 = "Écart de log-revenu 2021, moi moins le partenaire",
  diff_gini_2021 = "Écart de Gini, moi moins le partenaire",
  abs_diff_gini_2021 = "Écart de Gini, en valeur absolue",
  # Variables dérivées (03_preparation.R)
  ecart_doublement = "Écart de revenu entre les quartiers (en doublements)",
  ecart_doublement_signe = "Écart de revenu signé, positif si le partenaire est plus aisé (doublements)",
  ecart_doublement_2000 = "Écart de revenu 2000 entre les quartiers (en doublements)",
  ecart_age = "Écart d'âge (années)", meme_domaine = "Même domaine d'études",
  tercile_revenu = "Tercile de revenu du quartier d'enfance",
  tercile_revenu_o = "Tercile de revenu du quartier du partenaire",
  meme_tercile = "Même tercile de revenu",
  echantillon = "Dans l'échantillon d'analyse (revenu connu des deux côtés)",
  # Agrégats par participant
  nb_dates = "Nombre de dates", taux_oui_donnes = "Taux de oui donnés",
  taux_oui_recus = "Taux de oui reçus", taux_match = "Taux de match"
)

interets <- c(sports = "sport pratiqué", tvsports = "sport à la télévision",
              exercise = "exercice physique", dining = "restaurants", museums = "musées",
              art = "art", hiking = "randonnée", gaming = "jeux", clubbing = "boîtes de nuit",
              reading = "lecture", tv = "télévision", theater = "théâtre", movies = "cinéma",
              concerts = "concerts", music = "musique", shopping = "shopping", yoga = "yoga")

questions_preferences <- c("1" = "importance pour moi",
                           "2" = "ce que l'autre sexe recherche, selon moi",
                           "3" = "ma note pour moi-même",
                           "4" = "ce que mon sexe recherche, selon moi",
                           "5" = "comment les autres me voient, selon moi",
                           "7" = "importance réelle dans mes choix")
moments <- c("1" = "inscription", "s" = "mi-soirée", "2" = "lendemain", "3" = "3-4 semaines")
abreviations_pf <- c(att = "attr", sin = "sinc", int = "intel", fun = "fun", amb = "amb",
                     sha = "shar")

libelle_une_variable <- function(nom) {
  if (nom %in% names(libelles_directs)) return(unname(libelles_directs[nom]))
  if (nom %in% names(criteres)) return(paste("Note donnée :", criteres[[nom]]))
  if (nom %in% names(interets)) return(paste0("Intérêt : ", interets[[nom]], " (1 à 10)"))
  # Notes reçues du partenaire (attr_o…) et leur moyenne par participant (moy_attr_o…)
  recue <- stringr::str_match(nom, "^(moy_)?(attr|sinc|intel|fun|amb|shar)_o$")
  if (!is.na(recue[1])) {
    return(paste0("Note reçue : ", criteres[[recue[3]]],
                  if (!is.na(recue[2])) " (moyenne)" else ""))
  }
  if (nom == "moy_like_o") return("Appréciation globale reçue (moyenne)")
  # Préférences : attr1_1 = importance de l'attirance pour moi, à l'inscription
  pref <- stringr::str_match(nom, "^(attr|sinc|intel|fun|amb|shar)([1-7])_([123s])$")
  if (!is.na(pref[1])) {
    return(paste0(stringr::str_to_sentence(criteres[[pref[2]]]), " : ",
                  questions_preferences[[pref[3]]], " (", moments[[pref[4]]], ")"))
  }
  pf <- stringr::str_match(nom, "^pf_o_(att|sin|int|fun|amb|sha)$")
  if (!is.na(pf[1])) {
    return(paste0("Préférence du partenaire : ", criteres[[abreviations_pf[[pf[2]]]]],
                  " (points sur 100)"))
  }
  # Variables Census du partenaire
  base <- stringr::str_remove(nom, "_o$")
  if (base != nom && base %in% names(libelles_directs)) {
    return(paste(libelles_directs[[base]], "(partenaire)"))
  }
  paste0(nom, " (", tolower(bloc_colonne(nom)), ")")
}

libelle_variable <- function(noms) vapply(noms, libelle_une_variable, character(1), USE.NAMES = FALSE)

# --- Types et aperçus ---------------------------------------------------------

type_variable <- function(nom, x) {
  if (nom %in% identifiants) return("identifiant")
  if (nom %in% textes_libres) return("texte")
  if (is.factor(x) || is.character(x)) return("qualitative")
  valeurs <- unique(x[!is.na(x)])
  if (length(valeurs) > 0 && all(valeurs %in% c(0, 1))) return("binaire")
  "quantitative"
}

# Nombre à 4 chiffres significatifs, à la française ; chaque valeur est mise en forme
# séparément (format() alignerait sinon toutes les valeurs sur la plus longue)
nombre <- function(v) {
  vapply(signif(v, 4), \(z) format(z, big.mark = " ", decimal.mark = ",", scientific = FALSE,
                                   trim = TRUE), character(1))
}

apercu_variable <- function(x, type) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return("(vide)")
  if (type == "quantitative") {
    return(paste0(nombre(min(x)), " à ", nombre(max(x)), " (médiane ", nombre(median(x)), ")"))
  }
  if (type == "binaire") return(paste0("oui : ", pourcent(mean(x))))
  effectifs <- sort(table(as.character(x)), decreasing = TRUE)
  paste0(length(effectifs), " modalités : ", paste(head(names(effectifs), 3), collapse = ", "),
         if (length(effectifs) > 3) "…" else "")
}

# --- Préparation --------------------------------------------------------------

preparer_donnees <- function(chemin_csv, chemin_rds) {
  brut <- readr::read_csv(chemin_csv, show_col_types = FALSE, guess_max = 10000)

  derivees <- readRDS(chemin_rds) |>
    transmute(
      iid, pid,
      ecart_doublement = ecart_revenu / log(2),
      ecart_doublement_signe = ecart_revenu_signe / log(2),
      ecart_doublement_2000 = ecart_revenu_2000 / log(2),
      ecart_age, meme_domaine, tercile_revenu, tercile_revenu_o, meme_tercile, echantillon
    )

  dates <- brut |>
    # Deux montants stockés en texte, avec séparateurs de milliers
    mutate(across(any_of(c("mn_sat", "tuition")),
                  \(x) if (is.character(x)) readr::parse_number(x) else x)) |>
    left_join(derivees, by = c("iid", "pid")) |>
    mutate(
      across(where(is.logical), as.integer),
      wave = factor(wave, levels = sort(unique(wave))),
      across(any_of(c("met", "met_o", "date_3")), \(x) factor(x, levels = sort(unique(x))))
    )
  stopifnot(nrow(dates) == nrow(brut))

  for (v in names(codes_variables)) {
    dates[[v]] <- factor(libeller(dates[[v]], codes_variables[[v]]),
                         levels = unique(unname(codes_variables[[v]])))
  }
  dates <- dates |> mutate(across(where(is.factor), droplevels))

  # Variables propres au participant : une seule valeur par personne
  constantes <- dates |>
    summarise(across(everything(), \(x) n_distinct(x, na.rm = TRUE) <= 1), .by = iid) |>
    select(-iid) |>
    summarise(across(everything(), all))
  vars_participant <- names(constantes)[unlist(constantes[1, ])]

  premiere_valeur <- function(x) if (all(is.na(x))) x[1] else x[!is.na(x)][1]
  recues <- c("attr_o", "sinc_o", "intel_o", "fun_o", "amb_o", "shar_o", "like_o")
  participants <- dates |>
    summarise(
      across(all_of(vars_participant), premiere_valeur),
      nb_dates = n(),
      taux_oui_donnes = mean(dec),
      taux_oui_recus = mean(dec_o, na.rm = TRUE),
      taux_match = mean(match),
      across(all_of(recues), \(x) mean(x, na.rm = TRUE), .names = "moy_{.col}"),
      .by = iid
    ) |>
    mutate(across(where(is.double), \(x) if_else(is.nan(x), NA_real_, x)))

  agregats <- c("nb_dates", "taux_oui_donnes", "taux_oui_recus", "taux_match",
                paste0("moy_", recues))
  derivees_noms <- setdiff(names(derivees), c("iid", "pid"))
  colonne <- function(nom) if (nom %in% agregats) participants[[nom]] else dates[[nom]]

  dictionnaire <- tibble(nom = c(names(dates), agregats)) |>
    mutate(
      libelle = libelle_variable(nom),
      bloc = case_when(
        nom %in% agregats ~ "Agrégats par participant",
        nom %in% derivees_noms ~ "Variables dérivées (préparation)",
        TRUE ~ bloc_colonne(nom)
      ),
      niveau = case_when(
        nom %in% agregats ~ "Participant (agrégat)",
        nom %in% c("iid", vars_participant) ~ "Participant",
        TRUE ~ "Date"
      ),
      type = map_chr(nom, \(n) type_variable(n, colonne(n))),
      manquants = map_dbl(nom, \(n) mean(is.na(colonne(n)))),
      apercu = map2_chr(nom, type, \(n, t) apercu_variable(colonne(n), t))
    )

  list(dates = dates, participants = participants, dictionnaire = dictionnaire)
}
