library(shiny)
library(bslib)
library(glue)
library(fs)
library(jsonlite)

source("R/utils.R")
source("R/prompt_builder.R")
source("R/api_client.R")
source("R/json_validator.R")
source("R/pdf_renderer.R")

MAX_ESERCIZI <- 15
OUTPUT_DIR   <- file.path("output", "verifiche")

# ── Pannelli UI ───────────────────────────────────────────────────────────────

ui_input <- function() {
  card(
    card_header(class = "bg-primary text-white fw-bold",
      "Parametri della verifica"),
    card_body(
      fluidRow(
        column(6, textInput("argomento", "Argomento *",
          placeholder = "es. Integrali, Trigonometria, Limiti...")),
        column(6, textInput("classe", "Classe *",
          placeholder = "es. 5A Liceo Scientifico"))
      ),
      fluidRow(
        column(3, numericInput("n_esercizi",      "N. esercizi",   value = 4,  min = 1,  max = 15)),
        column(3, selectInput( "difficolta",      "Difficoltà",
          choices = c("Facile", "Medio", "Difficile", "Misto"), selected = "Medio")),
        column(3, numericInput("durata_minuti",   "Durata (min)",  value = 60, min = 15, max = 180)),
        column(3, numericInput("punteggio_totale","Punteggio tot.",value = 20, min = 5,  max = 100))
      ),
      textAreaInput("descrizione_libera",
        "Note aggiuntive (opzionale)",
        placeholder = "Es. Focus sull’integrazione per parti, evitare le funzioni iperboliche…",
        rows = 2),
      div(class = "text-end mt-3",
        actionButton("btn_genera", "Genera verifica",
          class = "btn btn-primary btn-lg",
          icon  = icon("wand-magic-sparkles")))
    )
  )
}

ui_loading <- function(messaggio = "Operazione in corso…") {
  card(
    card_body(class = "text-center py-5",
      div(class = "spinner-border text-primary mb-3", role = "status",
        span(class = "visually-hidden", "Caricamento…")),
      h5(messaggio),
      p(class = "text-muted small", "Attendere, potrebbe richiedere qualche secondo.")
    )
  )
}

card_esercizio <- function(i, ez, stato) {
  is_accettato    <- stato == "accepted"
  is_editing      <- stato == "editing"
  is_regenerating <- stato == "regenerating"

  header_class <- if (is_accettato)    "bg-success text-white"
                  else if (is_editing) "bg-info text-white"
                  else                 "bg-light"

  badge_stato <- if (is_accettato)
    tags$span(class = "badge bg-white text-success ms-2", "✓ Accettato")
  else if (is_editing)
    tags$span(class = "badge bg-white text-info ms-2", "In modifica")
  else
    NULL

  corpo <- if (is_regenerating) {
    div(class = "text-center py-3",
      div(class = "spinner-border spinner-border-sm text-warning me-2"),
      "Rigenerazione in corso…")

  } else if (is_editing) {
    tagList(
      div(class = "mb-2",
        tags$label(class = "form-label fw-semibold small", "Titolo"),
        textInput(glue("edit_titolo_{i}"), NULL, value = ez$titolo_breve,
          width = "100%")),
      div(class = "mb-2",
        tags$label(class = "form-label fw-semibold small", "Testo (supporta LaTeX)"),
        textAreaInput(glue("edit_testo_{i}"), NULL, value = ez$testo,
          rows = 4, width = "100%")),
      fluidRow(
        column(4, numericInput(glue("edit_punti_{i}"), "Punti",
          value = ez$punti, min = 1, max = 30)),
        column(8, selectInput(glue("edit_diff_{i}"), "Difficoltà",
          choices  = c("Facile", "Medio", "Difficile"),
          selected = ez$difficolta_stimata))
      ),
      div(class = "d-flex gap-2 mt-2",
        actionButton(glue("btn_salva_{i}"), "Salva",
          class = "btn btn-info btn-sm", icon = icon("check")),
        actionButton(glue("btn_annulla_{i}"), "Annulla",
          class = "btn btn-outline-secondary btn-sm"))
    )

  } else {
    tagList(
      div(class = "math-text mb-3", HTML(ez$testo)),
      div(class = "d-flex flex-wrap gap-2",
        if (!is_accettato)
          actionButton(glue("btn_accetta_{i}"), "Accetta",
            class = "btn btn-success btn-sm", icon = icon("check")),
        actionButton(glue("btn_modifica_{i}"), "Modifica",
          class = "btn btn-outline-secondary btn-sm", icon = icon("pen")),
        if (!is_accettato)
          actionButton(glue("btn_rigenera_{i}"), "Rigenera",
            class = "btn btn-outline-warning btn-sm", icon = icon("rotate"))
      )
    )
  }

  card(class = "mb-3",
    card_header(class = header_class,
      div(class = "d-flex justify-content-between align-items-center",
        span(glue("Esercizio {i} — {ez$titolo_breve}"), badge_stato),
        tags$span(class = "badge bg-primary", glue("{ez$punti} pt"),
          title = glue("Difficoltà: {ez$difficolta_stimata}"))
      )
    ),
    card_body(corpo)
  )
}

ui_revisione <- function(dati, stati) {
  n           <- length(dati$esercizi)
  n_ok        <- sum(stati == "accepted")
  pct         <- round(n_ok / n * 100)
  tutti_ok    <- n_ok == n

  tagList(
    card(class = "mb-3",
      card_body(
        div(class = "d-flex justify-content-between align-items-center mb-2",
          span(class = "fw-bold",
            glue("{n_ok}/{n} esercizi accettati")),
          if (tutti_ok)
            actionButton("btn_genera_pdf", "Genera PDF",
              class = "btn btn-success",
              icon  = icon("file-pdf"))
          else
            span(class = "text-muted small",
              "Accetta tutti gli esercizi per procedere")
        ),
        div(class = "progress", style = "height:8px",
          div(class = "progress-bar bg-success",
            role  = "progressbar",
            style = glue("width:{pct}%"),
            `aria-valuenow` = pct, `aria-valuemin` = 0, `aria-valuemax` = 100)
        )
      )
    ),
    lapply(seq_len(n), function(i) {
      card_esercizio(i, dati$esercizi[[i]], stati[[i]])
    })
  )
}

ui_download <- function(paths, dati) {
  meta <- dati$metadata
  card(
    card_header(class = "bg-success text-white",
      div(class = "d-flex align-items-center gap-2",
        icon("circle-check"), span("Verifica generata!"))),
    card_body(
      p(class = "text-muted mb-3",
        glue("{meta$argomento} · {length(dati$esercizi)} esercizi · {meta$punteggio_totale} pt · {meta$durata_minuti} min")),
      div(class = "d-flex gap-3 flex-wrap mb-4",
        downloadButton("dl_test", "Scarica compito",
          class = "btn btn-primary btn-lg"),
        downloadButton("dl_soluzioni", "Scarica soluzioni",
          class = "btn btn-danger btn-lg")
      ),
      hr(),
      actionButton("btn_nuova", "Nuova verifica",
        class = "btn btn-outline-primary",
        icon  = icon("plus"))
    )
  )
}

# ── UI principale ─────────────────────────────────────────────────────────────

ui <- fluidPage(
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  withMathJax(),
  tags$head(
    tags$link(rel = "stylesheet", href = "custom.css"),
    tags$script(HTML(
      "$(document).on('shiny:idle', function() {
         if (typeof MathJax !== 'undefined') MathJax.typesetPromise();
       });"
    ))
  ),
  div(class = "container py-4",
    div(class = "row justify-content-center",
      div(class = "col-lg-8",
        div(class = "mb-4",
          h2(class = "text-primary mb-1", "Generatore di verifiche"),
          p(class = "text-muted mb-0",
            "Matematica per il liceo — powered by Claude")),
        uiOutput("main_content")
      )
    )
  )
)

# ── Server ────────────────────────────────────────────────────────────────────

server <- function(input, output, session) {

  stato <- reactiveValues(
    fase           = "input",
    params         = NULL,
    dati           = NULL,
    esercizi_stato = NULL,
    pdf_paths      = NULL
  )

  output$main_content <- renderUI({
    switch(stato$fase,
      input       = ui_input(),
      generazione = ui_loading("Generazione in corso…"),
      revisione   = ui_revisione(stato$dati, stato$esercizi_stato),
      pdf         = ui_loading("Compilazione PDF in corso…"),
      download    = ui_download(stato$pdf_paths, stato$dati)
    )
  })

  # ── Genera verifica ──────────────────────────────────────────────────────────

  observeEvent(input$btn_genera, {
    arg    <- trimws(input$argomento %||% "")
    classe <- trimws(input$classe    %||% "")

    if (!nzchar(arg)) {
      showNotification("Inserisci l’argomento della verifica.", type = "warning")
      return()
    }
    if (!nzchar(classe)) {
      showNotification("Inserisci la classe.", type = "warning")
      return()
    }

    stato$params <- list(
      argomento          = arg,
      n_esercizi         = input$n_esercizi,
      difficolta         = input$difficolta,
      durata_minuti      = input$durata_minuti,
      punteggio_totale   = input$punteggio_totale,
      classe             = classe,
      descrizione_libera = input$descrizione_libera %||% ""
    )
    stato$fase <- "generazione"

    # Aspetta che lo spinner sia mostrato nel browser prima di bloccare R
    session$onFlushed(function() {
      params <- isolate(stato$params)
      tryCatch({
        json_raw <- chiama_api(costruisci_prompt(params))
        dati     <- valida_json(json_raw)
        stato$dati           <- dati
        stato$esercizi_stato <- rep("pending", length(dati$esercizi))
        stato$fase           <- "revisione"
      }, error = function(e) {
        stato$fase <- "input"
        showNotification(conditionMessage(e), type = "error", duration = 15)
      })
    }, once = TRUE)
  })

  # ── Osservatori esercizi (pre-creati per tutti i possibili indici) ────────────

  lapply(seq_len(MAX_ESERCIZI), function(i) {

    observeEvent(input[[glue("btn_accetta_{i}")]], {
      req(stato$dati)
      if (i > length(isolate(stato$dati$esercizi))) return()
      stato$esercizi_stato[i] <- "accepted"
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    observeEvent(input[[glue("btn_modifica_{i}")]], {
      req(stato$dati)
      if (i > length(isolate(stato$dati$esercizi))) return()
      stato$esercizi_stato[i] <- "editing"
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    observeEvent(input[[glue("btn_annulla_{i}")]], {
      req(stato$dati)
      if (i > length(isolate(stato$dati$esercizi))) return()
      stato$esercizi_stato[i] <- "pending"
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    observeEvent(input[[glue("btn_salva_{i}")]], {
      req(stato$dati)
      if (i > length(isolate(stato$dati$esercizi))) return()

      ez     <- isolate(stato$dati$esercizi[[i]])
      titolo <- isolate(input[[glue("edit_titolo_{i}")]]) %||% ez$titolo_breve
      testo  <- isolate(input[[glue("edit_testo_{i}")]]) %||% ez$testo
      punti  <- isolate(input[[glue("edit_punti_{i}")]]) %||% ez$punti
      diff   <- isolate(input[[glue("edit_diff_{i}")]]) %||% ez$difficolta_stimata

      stato$dati$esercizi[[i]]$titolo_breve       <- trimws(titolo)
      stato$dati$esercizi[[i]]$testo              <- trimws(testo)
      stato$dati$esercizi[[i]]$punti              <- as.integer(punti)
      stato$dati$esercizi[[i]]$difficolta_stimata <- diff

      stato$esercizi_stato[i] <- "accepted"
    }, ignoreNULL = TRUE, ignoreInit = TRUE)

    observeEvent(input[[glue("btn_rigenera_{i}")]], {
      req(stato$dati)
      if (i > length(isolate(stato$dati$esercizi))) return()

      stato$esercizi_stato[i] <- "regenerating"

      session$onFlushed(function() {
        params  <- isolate(stato$params)
        dati_c  <- isolate(stato$dati)
        tryCatch({
          ctx      <- c(params, list(esercizi_esistenti = dati_c$esercizi))
          json_raw <- chiama_api(costruisci_prompt_rigenera(i, ctx))
          nuovo    <- valida_json(json_raw)$esercizi[[1]]
          stato$dati$esercizi[[i]] <- nuovo
          stato$esercizi_stato[i]  <- "pending"
        }, error = function(e) {
          stato$esercizi_stato[i] <- "pending"
          showNotification(
            glue("Errore esercizio {i}: {conditionMessage(e)}"),
            type = "error", duration = 10)
        })
      }, once = TRUE)
    }, ignoreNULL = TRUE, ignoreInit = TRUE)
  })

  # ── Genera PDF ───────────────────────────────────────────────────────────────

  observeEvent(input$btn_genera_pdf, {
    req(stato$dati)
    if (!all(isolate(stato$esercizi_stato) == "accepted")) return()

    stato$fase <- "pdf"

    session$onFlushed(function() {
      dati_c <- isolate(stato$dati)
      tryCatch({
        fs::dir_create(OUTPUT_DIR, recurse = TRUE)
        paths          <- renderizza_entrambi(dati_c, OUTPUT_DIR)
        stato$pdf_paths <- paths
        stato$fase      <- "download"
      }, error = function(e) {
        stato$fase <- "revisione"
        showNotification(conditionMessage(e), type = "error", duration = 15)
      })
    }, once = TRUE)
  })

  # ── Download ─────────────────────────────────────────────────────────────────

  output$dl_test <- downloadHandler(
    filename = function() basename(isolate(stato$pdf_paths$test)),
    content  = function(file) file.copy(isolate(stato$pdf_paths$test), file)
  )

  output$dl_soluzioni <- downloadHandler(
    filename = function() basename(isolate(stato$pdf_paths$soluzioni)),
    content  = function(file) file.copy(isolate(stato$pdf_paths$soluzioni), file)
  )

  # ── Nuova verifica ────────────────────────────────────────────────────────────

  observeEvent(input$btn_nuova, {
    stato$fase           <- "input"
    stato$params         <- NULL
    stato$dati           <- NULL
    stato$esercizi_stato <- NULL
    stato$pdf_paths      <- NULL
  })
}

shinyApp(ui, server)
