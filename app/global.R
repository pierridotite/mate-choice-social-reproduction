# Application Shiny : découverte interactive du jeu de données Speed Dating x Census.
# Lancement depuis la racine du dépôt : shiny::runApp("app")
# Le dossier de travail de l'application est app/ : les chemins remontent d'un niveau.
# Prérequis : avoir lancé R/03_preparation.R (outputs/dates.rds).

library(shiny)
library(bslib)
library(tidyverse)
library(plotly)
library(DT)

# Chargement des fonctions
source("../R/commun.R")            # charte graphique, formats, libellés du questionnaire
source("fonctions/donnees.R")      # tables et dictionnaire des variables
source("fonctions/decouverte.R")   # onglet « Découvrir les données » : cinq graphiques
source("fonctions/prediction.R")   # onglet « Prédire un match » : modèles de décision

# Chargement des données globales
donnees_app <- preparer_donnees("../data/speed_dating_census.csv", "../outputs/dates.rds")
dates_app <- donnees_app$dates
participants_app <- donnees_app$participants
dictionnaire <- donnees_app$dictionnaire

# Tables de l'onglet « Découvrir les données » (préférences, valeurs manquantes par vague)
decouverte <- preparer_decouverte(dates_app, participants_app, dictionnaire)

# Modèles de l'onglet « Prédire un match », ajustés au lancement (validation croisée comprise)
prediction <- preparer_prediction(dates_app)
couples_pred <- table_couples(prediction$donnees)
origines_pred <- levels(prediction$donnees$origine)
# Valeurs de départ du formulaire : la médiane de chaque variable
depart <- prediction$donnees |>
  summarise(age = median(age_juge), int_corr = median(int_corr),
            across(all_of(criteres_notes), median))

# Milieu social : tranches de revenu médian du quartier d'enfance. Chaque tranche est
# représentée dans le modèle par le revenu médian des participants qui en font partie.
milieux <- tibble(
  classe = c("Moins de 50 k$ (quartier modeste)", "50 à 75 k$", "75 à 100 k$", "100 à 150 k$",
             "150 k$ et plus (quartier très aisé)"),
  borne = c(0, 50e3, 75e3, 100e3, 150e3)
)
milieux$revenu <- prediction$donnees |>
  distinct(iid, revenu_juge) |>
  mutate(tranche = findInterval(revenu_juge, milieux$borne)) |>
  summarise(revenu = median(revenu_juge), .by = tranche) |>
  arrange(tranche) |>
  pull(revenu)
milieu_de <- function(revenu) milieux$classe[findInterval(revenu, milieux$borne)]

# Moments de collecte, dans l'ordre de l'expérience (liste du graphique 5)
ordre_blocs <- c("Protocole", "Questionnaire d'inscription",
                 "Fiche de notation (après chaque date)", "Réponses du partenaire (_o)",
                 "Mi-soirée", "Suivi le lendemain", "Suivi à 3-4 semaines",
                 "Census (notre ajout)")

# Textes des tableaux en français, intégrés pour que l'application marche sans internet
langue_dt <- list(
  search = "Rechercher :", lengthMenu = "Afficher _MENU_ lignes",
  info = "Lignes _START_ à _END_ sur _TOTAL_", infoEmpty = "Aucune ligne",
  infoFiltered = "(filtrées sur _MAX_)", zeroRecords = "Aucune ligne ne correspond",
  thousands = " ", decimal = ",",
  paginate = list(previous = "Précédent", `next` = "Suivant")
)
