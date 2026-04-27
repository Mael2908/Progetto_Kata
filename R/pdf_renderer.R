#' Renderizza uno dei due PDF (compito o soluzioni)
#'
#' @title Renderizza PDF
#' @description Usa rmarkdown::render() per compilare il template .Rmd appropriato
#'   e salvare il PDF nella directory di output con nome strutturato.
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

  radice_progetto <- .trova_radice()
  template_file   <- fs::path(radice_progetto, "templates", glue::glue("{tipo}.Rmd"))

  if (!fs::file_exists(template_file)) {
    stop(glue::glue("Template non trovato: {template_file}"))
  }

  fs::dir_create(output_dir, recurse = TRUE)

  slug     <- slugify(dati_test$metadata$argomento)
  data_s   <- format(data_verifica, "%Y%m%d")
  prefisso <- if (tipo == "test") "verifica" else "soluzioni"
  nome_pdf <- glue::glue("{prefisso}_{slug}_{data_s}.pdf")

  params_render <- list(
    classe           = dati_test$metadata$argomento,
    data             = formatta_data_italiana(data_verifica),
    argomento        = dati_test$metadata$argomento,
    durata_minuti    = dati_test$metadata$durata_minuti,
    punteggio_totale = dati_test$metadata$punteggio_totale,
    esercizi_json    = as.character(jsonlite::toJSON(dati_test$esercizi, auto_unbox = TRUE))
  )

  esito <- tryCatch({
    rmarkdown::render(
      input       = as.character(template_file),
      params      = params_render,
      output_file = nome_pdf,
      output_dir  = as.character(fs::path_abs(output_dir)),
      quiet       = TRUE,
      clean       = TRUE
    )
    TRUE
  }, error = function(e) {
    righe <- utils::head(stringr::str_split(conditionMessage(e), "\n")[[1]], 20)
    stop(glue::glue(
      "Errore LaTeX durante il rendering rmarkdown ({tipo}).\n",
      "Prime 20 righe dell'errore:\n{paste(righe, collapse = '\n')}"
    ))
  })

  percorso_finale <- fs::path_abs(fs::path(output_dir, nome_pdf))
  message(glue::glue("[PDF] Generato: {percorso_finale}"))
  as.character(percorso_finale)
}

#' Renderizza entrambi i PDF e li salva nella stessa directory
#'
#' @title Renderizza entrambi i PDF
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

#' Trova la radice del progetto risalendo dalla working directory
#'
#' @return character(1) Percorso assoluto della directory radice.
#' @keywords internal
.trova_radice <- function() {
  wd <- fs::path_abs(fs::path_wd())
  candidati <- c(wd, fs::path_dir(wd), fs::path_dir(fs::path_dir(wd)))
  for (candidato in candidati) {
    if (fs::file_exists(fs::path(candidato, "DESCRIPTION"))) {
      return(as.character(candidato))
    }
  }
  as.character(wd)
}
