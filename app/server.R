function(input, output, session) {

  # ==================================================================================
  # Découvrir les données : cinq graphiques
  # ==================================================================================

  dd <- decouverte$dates
  dp <- decouverte$participants

  # 1. La structure
  output$p_grille <- renderPlotly(graphique_grille(dd, input$d_vague, input$d_tri_grille))
  output$t_grille <- renderText(resume_grille(dd, input$d_vague))

  # 2. Les participants
  # Une variable : sa répartition par genre ; deux variables : leur croisement
  output$p_profil <- renderPlotly({
    if (input$d_carac2 == "aucune") {
      graphique_repartition(dp, input$d_carac, input$d_mesure_profil,
                            libelle_caracteristique(input$d_carac))
    } else {
      graphique_croisement(dp, input$d_carac, input$d_carac2)
    }
  })
  output$t_profil <- renderText({
    if (input$d_carac2 == "aucune") {
      resume_repartition(dp, input$d_carac)
    } else {
      resume_croisement(dp, input$d_carac, input$d_carac2)
    }
  })

  # 3. Ce qu'ils recherchent
  output$p_preferences <- renderPlotly({
    graphique_preferences(decouverte$preferences, input$d_question, input$d_moment)
  })

  # 4. Ce qui fait dire oui : une note (courbe) ou deux notes (surface 3D)
  output$p_taux_note <- renderPlotly(graphique_taux_note(dd, input$d_note_x))
  output$p_surface <- renderPlotly({
    graphique_surface(dd, input$d_note_x, input$d_note_y, input$d_surface_genre)
  })

  # 5. Ce qui est fiable
  output$p_manquants <- renderPlotly(graphique_manquants(decouverte$manquants))
  output$t_colonnes <- renderDT({
    dictionnaire |>
      filter(bloc == input$d_bloc) |>
      arrange(desc(manquants)) |>
      transmute(Variable = nom, `Libellé` = libelle, Manquants = manquants, `Aperçu` = apercu) |>
      datatable(rownames = FALSE, options = list(pageLength = 10, dom = "tip", language = langue_dt)) |>
      formatPercentage("Manquants", digits = 1, dec.mark = ",")
  })

  # ==================================================================================
  # Prédire un match
  # ==================================================================================

  # Listes de couples : les femmes de la soirée, puis les hommes qu'elle a rencontrés
  observeEvent(input$p_vague, {
    femmes <- couples_pred |> filter(wave == input$p_vague) |> distinct(femme, num_f) |> arrange(num_f)
    updateSelectInput(session, "p_femme", choices = setNames(femmes$femme, paste0("F", femmes$num_f)))
  })
  observeEvent(input$p_femme, {
    req(input$p_femme)
    hommes <- couples_pred |> filter(femme == input$p_femme) |> arrange(num_h)
    updateSelectInput(session, "p_homme", choices = setNames(hommes$homme, paste0("H", hommes$num_h)))
  })

  # Chargement d'un couple réel dans le formulaire
  couple_charge <- reactiveVal(NULL)
  observeEvent(input$p_charger, {
    req(input$p_femme, input$p_homme)
    cp <- couples_pred |> filter(femme == input$p_femme, homme == input$p_homme)
    req(nrow(cp) == 1)
    updateSliderInput(session, "p_age_f", value = cp$age_f)
    updateSliderInput(session, "p_age_h", value = cp$age_h)
    updateSelectInput(session, "p_origine_f", selected = as.character(cp$origine_f))
    updateSelectInput(session, "p_origine_h", selected = as.character(cp$origine_h))
    updateSliderInput(session, "p_int_corr", value = cp$int_corr)
    updateSelectInput(session, "p_milieu_f", selected = milieu_de(cp$revenu_f))
    updateSelectInput(session, "p_milieu_h", selected = milieu_de(cp$revenu_h))
    for (n in criteres_notes) {
      updateSliderInput(session, paste0("p_f_", n), value = cp[[paste0("f_", n)]])
      updateSliderInput(session, paste0("p_h_", n), value = cp[[paste0("h_", n)]])
    }
    couple_charge(cp)
  })

  # Critères saisis dans le formulaire
  saisie <- reactive({
    notes <- \(prefixe) setNames(map_dbl(criteres_notes, \(n) input[[paste0(prefixe, n)]]), criteres_notes)
    # Chaque tranche de milieu social est représentée par son revenu médian
    revenu <- \(classe) milieux$revenu[match(classe, milieux$classe)]
    list(elle = list(age = input$p_age_f, origine = input$p_origine_f, revenu = revenu(input$p_milieu_f),
                     notes = notes("p_f_")),
         lui = list(age = input$p_age_h, origine = input$p_origine_h, revenu = revenu(input$p_milieu_h),
                    notes = notes("p_h_")),
         int_corr = input$p_int_corr)
  })

  resultat <- reactive({
    s <- saisie()
    req(s$elle$origine, s$lui$origine, s$elle$revenu, s$lui$revenu)
    predire_match(prediction, input$p_modele, s$elle, s$lui, s$int_corr)
  })

  output$p_resultat <- renderUI({
    r <- resultat()
    rapport <- r$match / prediction$taux_match
    tagList(
      fluidRow(
        column(4, chiffre_cle(pct(r$match), "de chances de match")),
        column(4, chiffre_cle(pct(r$elle), "de chances qu'elle dise oui")),
        column(4, chiffre_cle(pct(r$lui), "de chances qu'il dise oui"))
      ),
      p(class = "resume", paste0(
        "Soit ", virgule(rapport, 1), " fois le taux de match moyen des couples de l'expérience (",
        pct(prediction$taux_match), ")."
      ))
    )
  })

  # Si un couple réel a été chargé : ce qui s'est vraiment passé
  output$p_reel <- renderUI({
    cp <- couple_charge()
    req(cp)
    s <- saisie()
    identique <- s$elle$age == cp$age_f && s$lui$age == cp$age_h &&
      s$elle$origine == cp$origine_f && s$lui$origine == cp$origine_h &&
      input$p_milieu_f == milieu_de(cp$revenu_f) && input$p_milieu_h == milieu_de(cp$revenu_h) &&
      abs(s$int_corr - cp$int_corr) < 0.03 &&
      all(abs(s$elle$notes - unlist(cp[paste0("f_", criteres_notes)])) < 0.01) &&
      all(abs(s$lui$notes - unlist(cp[paste0("h_", criteres_notes)])) < 0.01)
    div(class = "a-retenir",
        strong(paste0("Couple chargé : F", cp$num_f, " et H", cp$num_h, " (soirée ", cp$wave, ")")),
        p(paste0("Dans la réalité : elle a dit ", oui_non(cp$dec_f), ", il a dit ", oui_non(cp$dec_h),
                 if (cp$match == 1) ". C'est un match." else ". Pas de match.")),
        if (!identique) {
          p(class = "lecture", "Tu as modifié des critères : la prédiction ne correspond plus à ce couple.")
        })
  })

  output$t_ecart_revenu <- renderText({
    s <- saisie()
    e <- ecart_doublements(s$elle$revenu, s$lui$revenu)
    paste0("Écart de milieu social : le quartier le plus aisé a un revenu ", en_rapport(e),
           " celui de l'autre (", virgule(e, 1), " doublement", if (e >= 2) "s" else "", ").")
  })

  # La question du projet : explication de la barre ★ du graphique des contributions
  output$t_etoile <- renderUI({
    effet <- filter(prediction$effet_social, modele == input$p_modele)
    perf <- prediction$performance
    auc <- \(m) virgule(perf$auc_match[perf$modele == m], 3)
    multiplicateur <- function(g) {
      e <- filter(effet, genre == g)
      paste0("× ", virgule(e$rc, 2), " (IC ", virgule(e$bas, 2), " à ", virgule(e$haut, 2), ")")
    }
    tagList(
      strong("★ Écart de milieu social : la question du projet."),
      paste0(" S'il y avait reproduction sociale, un grand écart entre les deux quartiers d'enfance ",
             "ferait nettement baisser la cote du oui, et cette barre serait longue et à gauche. ",
             "Elle reste presque nulle : un doublement de l'écart de revenu multiplie la cote de ",
             "son oui à elle par ", multiplicateur("Femme"), " et de son oui à lui par ",
             multiplicateur("Homme"), ". L'ajouter au modèle ne change pas sa performance (AUC du ",
             "match : ", auc(input$p_modele), " sans, ", auc(paste0(input$p_modele, "_social")), " avec).")
    )
  })

  output$p_contributions <- renderPlotly(graphique_contributions(resultat()))

  output$p_performance <- renderUI({
    perf <- filter(prediction$performance, modele == paste0(input$p_modele, "_social"))
    fluidRow(
      column(6, chiffre_cle(virgule(perf$auc_match, 2),
                            "AUC du match sur des soirées non vues (0,5 = hasard, 1 = parfait)")),
      column(6, chiffre_cle(virgule(perf$auc_decision, 2),
                            "AUC de la décision de chacun sur des soirées non vues"))
    )
  })

  output$p_calibration <- renderPlotly(graphique_calibration(prediction$calibration, input$p_modele))
}
