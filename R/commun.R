# Éléments communs aux scripts du projet : charte graphique, formats et libellés.
# Ce fichier n'est pas lancé seul : les scripts 02 à 05 et l'application le chargent avec source().

library(ggplot2)

# --- Charte graphique --------------------------------------------------------

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

# Palette catégorielle : ordre fixe, validé pour les daltoniens (les deux premières couleurs
# sont celles des genres). Au-delà de 8 modalités, on regroupe dans « Autres », en gris.
palette_categorielle <- c("#2a78d6", "#eb6834", "#1baf7a", "#eda100",
                          "#e87ba4", "#008300", "#4a3aa7", "#e34948")

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

# Titres des sous-graphiques d'une figure composée : plus petits que le titre général
theme_sous_titre <- theme(plot.title = element_text(size = 11.5))

source_fisman <- "Source : Fisman et al. (2006), Columbia University, 2002-2004."
source_census <- "Sources : Fisman et al. (2006) ; US Census Bureau, ACS 2017-2021."

sauver <- function(plot, fichier, width = 9, height = 5.5) {
  ggsave(fichier, plot = plot, width = width, height = height, dpi = 300)
}

# Valeur d'un rapport de cotes (« × 0,94 ») écrite au-dessus du point, sur fond blanc pour
# rester lisible quand elle croise la ligne verticale de référence
etiquette_rc <- function(nudge_y = 0.3) {
  geom_label(aes(label = paste0("× ", virgule(rc))), nudge_y = nudge_y, size = 3.3,
             colour = col_dark, fill = "white", border.colour = NA,
             label.padding = unit(0.1, "lines"))
}

# --- Formats à la française --------------------------------------------------

pourcent <- scales::label_percent(accuracy = 1, suffix = " %")
dollars <- scales::label_dollar(scale = 1e-3, accuracy = 1, suffix = " k$", prefix = "")
# Rapport entre deux revenus : « × 1,5 », « × 2 »
fois <- scales::label_number(accuracy = 0.1, decimal.mark = ",", drop0trailing = TRUE,
                             prefix = "× ")
virgule <- function(x, digits = 2) format(round(x, digits), nsmall = digits, decimal.mark = ",")
milliers <- function(x) format(x, big.mark = " ")

# --- Libellés du questionnaire (dictionnaire des auteurs) --------------------

lab_race <- c("1" = "Noir", "2" = "Blanc", "3" = "Latino", "4" = "Asiatique",
              "5" = "Amérindien", "6" = "Autre")
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

# Remplace des codes numériques par leur libellé (NA si le code est absent)
libeller <- function(code, libelles) unname(libelles[as.character(code)])

# Moment de collecte d'une colonne du jeu de données : les 217 colonnes viennent de
# questionnaires remplis à des moments différents
bloc_colonne <- function(nom) {
  dplyr::case_when(
    stringr::str_detect(nom, "census|zip_|zip5|diff_|income_2000") ~ "Census (notre ajout)",
    stringr::str_detect(nom, "_3$") | nom %in% c("you_call", "them_cal") ~ "Suivi à 3-4 semaines",
    stringr::str_detect(nom, "_2$") | nom == "length" ~ "Suivi le lendemain",
    stringr::str_detect(nom, "_s$") ~ "Mi-soirée",
    nom %in% c("dec", "attr", "sinc", "intel", "fun", "amb", "shar", "like", "prob",
               "met", "match_es") ~ "Fiche de notation (après chaque date)",
    stringr::str_detect(nom, "_o$|^pf_o_") ~ "Réponses du partenaire (_o)",
    nom %in% c("iid", "id", "gender", "idg", "condtn", "wave", "round", "position", "positin1",
               "order", "partner", "pid", "match", "int_corr", "samerace") ~ "Protocole",
    TRUE ~ "Questionnaire d'inscription"
  )
}
