#' Renderizza uno dei due PDF (compito o soluzioni)
#'
#' @title Renderizza PDF
#' @description Copia il template Quarto appropriato in una directory temporanea,
#'   serializza i dati degli esercizi come parametri e chiama quarto_render().
#'   Il PDF finale viene copiato nella \code{output_dir} con nome strutturato.
#' @param dati_test list Lista validata da \code{valida_json} con metadata ed esercizi.
#' @param output_dir character(1) Directory di destinazione per il PDF generato.
#'   Viene creata se non esiste.
#' @param tipo character(1) "test" per il compito studenti, "soluzioni" per la
#'   griglia di correzione.
#' @param data_verifica Date Data della verifica (default: oggi).
#' @return character(1) Percorso assoluto del PDF generato.
#' @examples
#' \dontrun{
#'   pdf_path <- renderizza_pdf(
#'     dati_test  = dati,
#'     output_dir = "output/test_pipeline",
#'     tipo       = "test"
#'   )
#' }
#' @export
renderizza_pdf <- function(
    dati_test,
    output_dir,
    tipo = c("test", "soluzioni"),
    data_verifica = Sys.Date()
) {
  tipo <- match.arg(tipo)

  # Percorso template
  radice_progetto <- .trova_radice()
  template_file   <- fs::path(radice_progetto, "templates", glue::glue("{tipo}.qmd"))

  if (!fs::file_exists(template_file)) {
    stop(glue::glue("Template non trovato: {template_file}"))
  }

  # Crea output_dir se non esiste
  fs::dir_create(output_dir, recurse = TRUE)

  # Nome file output
  slug   <- slugify(dati_test$metadata$argomento)
  data_s <- format(data_verifica, "%Y%m%d")
  prefisso <- if (tipo == "test") "verifica" else "soluzioni"
  nome_pdf <- glue::glue("{prefisso}_{slug}_{data_s}.pdf")
  percorso_finale <- fs::path(fs::path_abs(output_dir), nome_pdf)

  # Serializza esercizi come JSON per passarli come parametro Quarto
  esercizi_json <- jsonlite::toJSON(dati_test$esercizi, auto_unbox = TRUE)

  params_quarto <- list(
    classe          = dati_test$metadata$argomento,   # usato nell'header fancyhdr
    data            = formatta_data_italiana(data_verifica),
    argomento       = dati_test$metadata$argomento,
    durata_minuti   = dati_test$metadata$durata_minuti,
    punteggio_totale = dati_test$metadata$punteggio_totale,
    esercizi_json   = as.character(esercizi_json)
  )

  # Rendering in directory temporanea con withr per pulizia automatica
  withr::with_tempdir({
    # Copia template nella tmpdir
    qmd_locale <- fs::path(fs::path_wd(), glue::glue("{tipo}.qmd"))
    fs::file_copy(template_file, qmd_locale)

    # Esegue quarto render
    stderr_output <- character(0)
    esito <- tryCatch({
      quarto::quarto_render(
        input           = as.character(qmd_locale),
        execute_params  = params_quarto,
        quiet           = TRUE
      )
      TRUE
    }, error = function(e) {
      stderr_output <<- conditionMessage(e)
      FALSE
    })

    if (!esito) {
      righe_errore <- paste(
        utils::head(stringr::str_split(stderr_output, "\n")[[1]], 20),
        collapse = "\n"
      )
      stop(glue::glue(
        "Errore LaTeX durante il rendering Quarto ({tipo}).\n",
        "Prime 20 righe dell'errore:\n{righe_errore}"
      ))
    }

    # Trova il PDF generato (stesso nome del .qmd ma con .pdf)
    pdf_tmp <- fs::path_ext_set(qmd_locale, "pdf")
    if (!fs::file_exists(pdf_tmp)) {
      stop(glue::glue("PDF non trovato dopo rendering: {pdf_tmp}"))
    }

    # Copia nella destinazione finale
    fs::file_copy(pdf_tmp, percorso_finale, overwrite = TRUE)
  })

  message(glue::glue("[PDF] Generato: {percorso_finale}"))
  as.character(percorso_finale)
}

#' Renderizza entrambi i PDF e li salva nella stessa directory
#'
#' @title Renderizza entrambi i PDF
#' @description Wrapper che chiama \code{renderizza_pdf} due volte (test + soluzioni)
#'   e restituisce i percorsi di entrambi.
#' @param dati_test list Lista validata.
#' @param output_dir character(1) Directory di destinazione.
#' @param data_verifica Date Data della verifica.
#' @return list con elementi \code{test} e \code{soluzioni} (percorsi dei PDF).
#' @export
renderizza_entrambi <- function(dati_test, output_dir, data_verifica = Sys.Date()) {
  list(
    test      = renderizza_pdf(dati_test, output_dir, "test",      data_verifica),
    soluzioni = renderizza_pdf(dati_test, output_dir, "soluzioni", data_verifica)
  )
}

#' Trova la radice del progetto
#'
#' @return character(1) Percorso assoluto della directory radice del progetto.
#' @keywords internal
.trova_radice <- function() {
  # Cerca il file DESCRIPTION risalendo dalla working directory
  wd <- fs::path_abs(fs::path_wd())
  candidati <- c(wd, fs::path_dir(wd), fs::path_dir(fs::path_dir(wd)))
  for (candidato in candidati) {
    if (fs::file_exists(fs::path(candidato, "DESCRIPTION"))) {
      return(as.character(candidato))
    }
  }
  # Fallback: working directory corrente
  as.character(wd)
}
