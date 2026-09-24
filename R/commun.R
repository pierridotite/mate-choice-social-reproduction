# Éléments communs aux scripts du projet : charte graphique, formats et libellés.
# Ce fichier n'est pas lancé seul : les scripts 02 à 04 le chargent avec source("R/commun.R").

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
