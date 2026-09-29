navbarPage(
  header = tags$head(tags$link(rel = "stylesheet", href = "style.css")),
  title = "Speed dating et milieu social",
  id = "navigation",
  theme = bs_theme(version = 5, primary = col_accent, "font-size-base" = "0.95rem"),

  # --- Découvrir les données : cinq graphiques --------------------------------------------
  tabPanel(
    "Découvrir les données",
    div(
      class = "parcours",
      navlistPanel(
        id = "parcours", widths = c(2, 10), well = FALSE,

        "Cinq graphiques",

        # 1. La structure ---------------------------------------------------------------------
        tabPanel(
          "1. La structure", value = "structure",
          h3("Une soirée vue d'en haut : chaque case est une rencontre"),
          p(class = "intro",
            "21 soirées de speed dating à l'université Columbia (2002-2004). Dans une soirée,",
            "chaque femme rencontre chaque homme pendant quatre minutes. Après chaque date, chacun",
            "note son partenaire et dit oui ou non, sans connaître la décision de l'autre. Deux",
            "oui font un match."),
          fluidRow(
            column(2, chiffre_cle("21", "soirées (vagues), de 10 à 44 participants")),
            column(2, chiffre_cle("551", "participants : 274 femmes, 277 hommes")),
            column(2, chiffre_cle(milliers(nrow(dates_app)), "lignes : une par décision")),
            column(2, chiffre_cle("217", "colonnes : protocole, questionnaires, notes, Census")),
            column(2, chiffre_cle(pct(mean(dates_app$dec)), "de oui")),
            column(2, chiffre_cle(pct(mean(dates_app$match)), "des rencontres finissent en match"))
          ),
          fluidRow(
            column(3, selectInput("d_vague", "Soirée", choices = levels(dates_app$wave),
                                  selected = "7")),
            column(9, radioButtons("d_tri_grille", "Trier les lignes et les colonnes par",
                                   inline = TRUE,
                                   choices = c("Numéro du participant" = "numero",
                                               "Oui reçus (les plus demandés d'abord)" = "recus",
                                               "Oui donnés (les moins sélectifs d'abord)" = "donnes")))
          ),
          p(class = "lecture", "Une ligne par femme, une colonne par homme. Survole une case",
            "pour lire les deux décisions et les notes d'attirance échangées."),
          plotlyOutput("p_grille", height = "560px"),
          p(class = "resume", textOutput("t_grille", inline = TRUE)),
          a_retenir(
            "Une ligne du tableau est une décision : 8 378 décisions, soit 4 189 rencontres vues des deux côtés. Les colonnes terminées par _o donnent la réponse du partenaire.",
            "Personne ne choisit qui il rencontre : dans une soirée, chaque femme voit chaque homme. On peut donc comparer les choix d'une même personne entre des partenaires qu'elle n'a pas sélectionnés.",
            "Les hommes disent plus souvent oui (47 %) que les femmes (37 %). Surtout, la décision dépend beaucoup de la personne qui juge : un homme qui dit oui à toutes les femmes donne une colonne entièrement bleue ou verte (H1 dans la vague 7).",
            "Les grandes soirées pèsent beaucoup plus : la vague 21 fournit 968 lignes, la vague 6 seulement 50."
          )
        ),

        # 2. Les participants ------------------------------------------------------------------
        tabPanel(
          "2. Les participants", value = "participants",
          h3("Qui sont les participants ?"),
          p(class = "intro",
            "Des étudiants de master, de doctorat et d'écoles professionnelles de Columbia. Ces",
            "variables viennent du questionnaire d'inscription, rempli avant la soirée, et de",
            "notre enrichissement Census."),
          fluidRow(
            column(4, selectInput("d_carac", "Variable", choices = caracteristiques, width = "100%")),
            column(4, selectInput("d_carac2", "Croiser avec une deuxième variable (facultatif)",
                                  choices = c(list("Aucune" = "aucune"), caracteristiques),
                                  width = "100%")),
            column(4, conditionalPanel(
              "input.d_carac2 == 'aucune'",
              radioButtons("d_mesure_profil", "Afficher",
                           choices = c("La part au sein de chaque genre" = "part",
                                       "Les effectifs" = "effectif"))
            ))
          ),
          p(class = "lecture", "Avec deux variables, le graphique s'adapte à leur type : nuage de",
            "points pour deux variables numériques, moyennes par groupe pour une numérique et une",
            "qualitative, carte de chaleur pour deux qualitatives."),
          plotlyOutput("p_profil", height = "520px"),
          p(class = "resume", textOutput("t_profil", inline = TRUE)),
          a_retenir(
            "26 ans en moyenne, de 18 à 55 ans. 56 % se déclarent blancs, 25 % asiatiques.",
            "Des parcours très genrés : 36 % des hommes étudient le commerce, l'économie ou la finance, contre 11 % des femmes.",
            "Ils viennent surtout pour s'amuser : 42 % pour passer une bonne soirée, 35 % pour rencontrer de nouvelles personnes, 4 % seulement pour une relation sérieuse.",
            "Ils ont grandi dans des quartiers aisés : revenu médian de 103 000 $, contre 68 000 $ pour la population américaine.",
            "Centres d'intérêt : cinéma, musique, restaurants et lecture en tête. Les femmes déclarent plus d'intérêt pour 14 activités sur 17 (surtout shopping, théâtre, yoga, art), les hommes pour le sport, les jeux et le sport à la télévision.",
            "En croisant deux variables : les participants blancs accordent le plus d'importance à avoir un partenaire de même origine (4,2 sur 10 en moyenne), les latinos le moins (2,7)."
          )
        ),

        # 3. Ce qu'ils disent rechercher ----------------------------------------------------
        tabPanel(
          "3. Ce qu'ils recherchent", value = "preferences",
          h3("Ce qu'ils disent rechercher chez un partenaire"),
          p(class = "intro",
            "À plusieurs moments, chaque participant répartit 100 points entre six critères. Ces",
            "questions occupent 72 colonnes : suffixe _1 pour l'inscription,",
            "_s pour la mi-soirée, _2 pour le lendemain, _3 pour trois à quatre semaines après."),
          fluidRow(
            column(6, radioButtons("d_question", "Question", choices = questions_pref)),
            column(6, radioButtons("d_moment", "Moment", choices = moments_pref))
          ),
          plotlyOutput("p_preferences", height = "440px"),
          p(class = "lecture", "Barres fines : intervalle de confiance à 95 % de la moyenne."),
          a_retenir(
            "À l'inscription, les hommes mettent l'attirance physique en tête (27 points sur 100). Les femmes répartissent leurs points plus également et mettent l'intelligence en tête (21 points), l'attirance à 18.",
            "Chaque sexe surestime l'importance du physique pour l'autre (question « ce que l'autre sexe recherche ») : les femmes pensent que les hommes lui donnent 36 points, les hommes pensent que les femmes lui en donnent 25.",
            "Après la soirée, l'attirance gagne des points chez les deux genres : de 27 à 30 chez les hommes et de 18 à 22 chez les femmes le lendemain.",
            "Dans quelques vagues, les participants ont noté chaque critère sur 10 au lieu de répartir 100 points : leurs réponses sont ramenées à une part du total pour rester comparables."
          )
        ),

        # 4. Ce qui les fait dire oui ---------------------------------------------------------
        tabPanel(
          "4. Ce qui fait dire oui", value = "oui",
          h3("Ce qui les fait vraiment dire oui"),
          p(class = "intro",
            "Après chaque date, la fiche de notation demande six notes de 0 à 10, une",
            "appréciation globale et la chance estimée que le partenaire dise oui. On compare",
            "ici ces notes à la décision prise."),
          fluidRow(
            column(4, radioButtons("d_vue_oui", "Vue", inline = TRUE,
                                   choices = c("Une note" = "courbe",
                                               "Deux notes à la fois (3D)" = "surface"))),
            column(4, selectInput("d_note_x", "Note", choices = notes_fiche, selected = "attr")),
            column(4, conditionalPanel(
              "input.d_vue_oui == 'surface'",
              selectInput("d_note_y", "Deuxième note", choices = notes_fiche, selected = "fun")
            ))
          ),
          conditionalPanel(
            "input.d_vue_oui == 'courbe'",
            plotlyOutput("p_taux_note", height = "460px"),
            p(class = "lecture", "Taille des points : nombre de décisions. Les notes données moins",
              "de 20 fois ne sont pas affichées. Pointillé : taux de oui moyen.")
          ),
          conditionalPanel(
            "input.d_vue_oui == 'surface'",
            radioButtons("d_surface_genre", "Décisions des", choices = unname(genres_fr), inline = TRUE),
            p(class = "lecture", "La surface donne la probabilité de oui estimée pour chaque",
              "combinaison des deux notes (régression logistique). Les points gris sont les taux",
              "observés, pour les combinaisons données au moins 15 fois. Pas de surface là où il",
              "n'y a presque pas de données. Fais tourner la surface : la pente est plus forte",
              "dans la direction de la note qui compte le plus."),
            plotlyOutput("p_surface", height = "620px")
          ),
          a_retenir(
            "L'attirance physique est la note qui fait le plus varier la décision : le taux de oui passe de 8 % pour une note de 4 ou moins à 76 % pour une note de 8 ou plus. Viennent ensuite l'humour et les intérêts communs.",
            "Sincérité, intelligence et ambition comptent beaucoup moins : leurs courbes plafonnent autour de 50 %. Les femmes disent pourtant chercher d'abord l'intelligence (graphique 3) : ce qu'on dit chercher n'est pas ce qui décide.",
            "À note égale, les hommes disent plus souvent oui que les femmes.",
            "Les notes vont ensemble (effet de halo, corrélations de 0,36 à 0,66 entre les six critères) : dans la vue 3D, les combinaisons très opposées sont rares, d'où les zones sans surface."
          )
        ),

        # 5. Ce qui est fiable -------------------------------------------------------------
        tabPanel(
          "5. Ce qui est fiable", value = "qualite",
          h3("Ce qui est fiable, ce qui ne l'est pas"),
          p(class = "intro",
            "Les 217 colonnes viennent de questionnaires remplis à des moments différents. Part",
            "de valeurs manquantes par soirée et par moment de collecte : plus la case est",
            "foncée, plus il manque de données."),
          plotlyOutput("p_manquants", height = "440px"),
          h5("Le détail des colonnes d'un moment de collecte"),
          selectInput("d_bloc", NULL, choices = ordre_blocs, width = "400px"),
          DTOutput("t_colonnes"),
          a_retenir(
            "Le cœur de l'expérience est presque complet : la décision n'a aucune valeur manquante, les notes données en ont moins de 5 % (sauf l'ambition, 9 %, et les intérêts communs, 13 %).",
            "Le questionnaire de mi-soirée n'a été distribué que dans 12 vagues : les cases à 100 % de sa ligne sont des questions jamais posées. Plus on s'éloigne de la soirée, moins les participants répondent : les suivis manquent pour un tiers (lendemain) et deux tiers (3-4 semaines) des lignes.",
            "Quelques codages sont incohérents : « avait déjà rencontré le partenaire » (met) prend des valeurs de 0 à 8 au lieu de 1 ou 2 ; 8 notes d'intérêt dépassent 10 ; certaines vagues ont noté les préférences sur 10 au lieu de 100.",
            "Le revenu fourni par les auteurs manque dans 49 % des lignes. Notre enrichissement Census couvre 394 participants sur 551 ; il manque surtout pour ceux qui ont grandi hors des États-Unis."
          )
        ),

        # En résumé -----------------------------------------------------------------------
        tabPanel(
          "En résumé", value = "resume",
          h3("Ce que l'on retient du jeu de données"),
          p(class = "intro", "Une conclusion par graphique, indépendamment de la question du",
            "milieu social."),
          div(class = "conclusion", h6("1. Une expérience presque contrôlée"),
              p("Dans une soirée, chacun rencontre tout le monde : les partenaires ne sont pas",
                "choisis. La décision dépend beaucoup de la personne qui juge : les décisions",
                "d'une même personne ne sont pas indépendantes, il faudra en tenir compte dans",
                "les modèles.")),
          div(class = "conclusion", h6("2. Une population très particulière"),
              p("Des étudiants d'une université d'élite, de 26 ans en moyenne, issus de quartiers",
                "aisés, avec des parcours très genrés. Les résultats ne se généralisent pas à",
                "toute la population.")),
          div(class = "conclusion", h6("3. Des préférences déclarées différentes selon le genre"),
              p("Les hommes disent chercher d'abord l'attirance, les femmes l'intelligence, et",
                "chaque sexe surestime l'importance du physique pour l'autre.")),
          div(class = "conclusion", h6("4. Mais le physique décide, pour tout le monde"),
              p("Dans les décisions, l'attirance domine chez les deux genres, suivie de l'humour",
                "et des intérêts communs. Les six notes sont fortement corrélées : une note est",
                "surtout une impression générale.")),
          div(class = "conclusion", h6("5. Rester au plus près de la soirée"),
              p("La fiche de notation est complète ; les suivis sont très incomplets et sans",
                "doute biaisés. Les analyses doivent reposer sur les décisions prises pendant la",
                "soirée."))
        )
      )
    )
  ),

  # --- Prédire un match -------------------------------------------------------------------
  tabPanel(
    "Prédire un match",
    div(
      class = "parcours",
      h3("Ces deux personnes vont-elles matcher ?"),
      p(class = "intro",
        "Choisis le profil d'une femme et d'un homme, le milieu social où chacun a grandi et, si",
        "tu te places après la rencontre, les notes que chacun donne à l'autre. Le modèle estime",
        "la probabilité que chacun dise oui, puis la probabilité de match (les deux oui). Tu peux",
        "aussi partir d'un vrai couple de l'expérience et modifier ses critères. Les modèles sont",
        "ajustés sur l'échantillon d'analyse du projet : les rencontres où le revenu du quartier",
        "d'enfance est connu des deux côtés."),
      fluidRow(

        # Formulaire ----------------------------------------------------------------------
        column(
          5,
          wellPanel(
            radioButtons("p_modele", "Ce que l'on sait",
                         choices = c("Après la rencontre : profils et notes échangées" = "complet",
                                     "Avant la rencontre : profils seulement" = "profil")),
            hr(),
            h6("Partir d'un couple de l'expérience (facultatif)"),
            fluidRow(
              column(4, selectInput("p_vague", "Soirée", choices = levels(dates_app$wave),
                                    selected = "7")),
              column(4, selectInput("p_femme", "Femme", choices = NULL)),
              column(4, selectInput("p_homme", "Homme", choices = NULL))
            ),
            actionButton("p_charger", "Remplir avec ce couple", class = "btn-outline-primary btn-sm"),
            hr(),
            fluidRow(
              column(6,
                     h6("Elle"),
                     sliderInput("p_age_f", "Âge", min = 18, max = 55, value = depart$age,
                                 step = 1, ticks = FALSE),
                     selectInput("p_origine_f", "Origine déclarée", choices = origines_pred),
                     selectInput("p_milieu_f", "Milieu social : revenu médian de son quartier d'enfance",
                                 choices = milieux$classe, selected = milieu_de(median(milieux$revenu)))),
              column(6,
                     h6("Lui"),
                     sliderInput("p_age_h", "Âge", min = 18, max = 55, value = depart$age,
                                 step = 1, ticks = FALSE),
                     selectInput("p_origine_h", "Origine déclarée", choices = origines_pred),
                     selectInput("p_milieu_h", "Milieu social : revenu médian de son quartier d'enfance",
                                 choices = milieux$classe, selected = milieu_de(median(milieux$revenu))))
            ),
            p(class = "resume", strong(textOutput("t_ecart_revenu", inline = TRUE))),
            sliderInput("p_int_corr", "Ressemblance de leurs centres d'intérêt (corrélation, de -1 à 1)",
                        min = -1, max = 1, value = round(depart$int_corr, 2), step = 0.05,
                        ticks = FALSE, width = "100%"),
            conditionalPanel(
              "input.p_modele == 'complet'",
              hr(),
              fluidRow(
                column(6,
                       h6("Les notes qu'elle lui donne"),
                       lapply(criteres_notes, \(n) {
                         sliderInput(paste0("p_f_", n), lab_notes[[n]], min = 0, max = 10,
                                     value = depart[[n]], step = 0.5, ticks = FALSE)
                       })),
                column(6,
                       h6("Les notes qu'il lui donne"),
                       lapply(criteres_notes, \(n) {
                         sliderInput(paste0("p_h_", n), lab_notes[[n]], min = 0, max = 10,
                                     value = depart[[n]], step = 0.5, ticks = FALSE)
                       }))
              )
            )
          )
        ),

        # Résultat ---------------------------------------------------------------------------
        column(
          7,
          uiOutput("p_resultat"),
          uiOutput("p_reel"),
          h5("Ce qui pèse dans la prédiction"),
          p(class = "lecture",
            "Pour chaque décision, effet de chaque facteur par rapport à une rencontre moyenne :",
            "× 2 veut dire que ce facteur double la cote du oui, × 0,5 qu'il la divise par deux."),
          p(class = "lecture", uiOutput("t_etoile", inline = TRUE)),
          plotlyOutput("p_contributions", height = "440px"),
          h5("Le modèle est-il fiable ?"),
          uiOutput("p_performance"),
          p(class = "lecture",
            "Chaque soirée est prédite par un modèle ajusté sur les vingt autres, puis les couples",
            "sont rangés en dix groupes selon la probabilité prédite. Sur la diagonale, la",
            "probabilité annoncée correspond au taux de match réellement observé."),
          plotlyOutput("p_calibration", height = "360px"),
          a_retenir(
            "La réponse du projet se lit sur la barre ★ : le milieu social ne change presque rien. Un doublement de l'écart de revenu entre les quartiers multiplie la cote du oui par 0,94 chez les femmes et 0,99 chez les hommes, et les deux intervalles contiennent 1. Change le milieu social de l'un des deux : la probabilité de match bouge à peine.",
            "Ajouter le milieu social au modèle n'améliore pas la prédiction : l'AUC du match reste de 0,846 avec ou sans lui.",
            "Avant la rencontre, on ne sait presque rien : avec l'âge, l'origine, les centres d'intérêt et le milieu social, le modèle fait à peine mieux que le hasard (AUC de 0,54 pour le match, 0,5 étant le hasard).",
            "Après la rencontre, les notes échangées suffisent à bien prédire : AUC de 0,85. Parmi les 10 % de couples jugés les plus probables, 66 % ont réellement matché, contre moins de 1 % parmi les 10 % les moins probables. L'attirance donnée est le facteur qui pèse le plus.",
            "Limites : les notes sont données après le date, ce n'est donc pas une prédiction avant la rencontre ; les deux décisions sont supposées indépendantes ; les modèles portent sur les 3 693 décisions où le revenu est connu des deux côtés, surtout des participants qui ont grandi aux États-Unis ; les résultats valent pour des étudiants de Columbia au début des années 2000."
          )
        )
      )
    )
  ),

  # --- À propos ---------------------------------------------------------------------
  tabPanel(
    "À propos",
    fluidRow(
      column(
        width = 8, offset = 2,
        h3("Le choix du partenaire reproduit-il le milieu social ?"),
        p("Les données viennent de 21 soirées de speed dating organisées à l'université",
          "Columbia entre 2002 et 2004 (Fisman et al., 2006) : 551 étudiants, 8 378 dates de",
          "quatre minutes, après chacun desquels chaque personne dit oui ou non. Nous les",
          "avons enrichies avec le revenu médian et l'indice de Gini du quartier d'enfance de",
          "chaque participant (US Census, ACS 2017-2021)."),
        h4("Découvrir les données"),
        p("Cinq graphiques interactifs qui résument le jeu de données, un par grand bloc de",
          "colonnes : la structure de l'expérience, les participants, leurs préférences",
          "déclarées, ce qui les fait dire oui (avec une vue en 3D) et la fiabilité des",
          "données. Chacun se termine par un encadré « À retenir »."),
        h4("Prédire un match"),
        p("Deux régressions logistiques, une par genre, estiment la probabilité que chacun dise",
          "oui à partir des profils, de l'écart de milieu social et, après la rencontre, des notes",
          "échangées. Un encadré montre ce que change l'écart de milieu social. La probabilité",
          "de match est le produit des deux. Les performances sont mesurées par validation",
          "croisée : chaque soirée est prédite par un modèle ajusté sur les vingt autres."),
        h4("Pour aller plus loin"),
        tags$ul(
          tags$li(a("Analyse exploratoire",
                    href = "https://github.com/pierridotite/mate-choice-social-reproduction/blob/main/exploration.md",
                    target = "_blank")),
          tags$li(a("Modèles", target = "_blank",
                    href = "https://github.com/pierridotite/mate-choice-social-reproduction/blob/main/modeles.md")),
          tags$li(a("Robustesse", target = "_blank",
                    href = "https://github.com/pierridotite/mate-choice-social-reproduction/blob/main/robustesse.md"))
        ),
        h4("Sources"),
        p("Fisman, R., Iyengar, S. S., Kamenica, E. et Simonson, I. (2006). Gender Differences",
          "in Mate Selection: Evidence From a Speed Dating Experiment. Quarterly Journal of",
          "Economics, 121(2), 673-697. US Census Bureau, American Community Survey 2017-2021,",
          "tables B19013, B19083 et B01003.")
      )
    )
  )
)
