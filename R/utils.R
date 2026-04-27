#' Converte una stringa in slug sicuro per filename
#'
#' @title Slugify
#' @description Rimuove accenti, sostituisce spazi con underscore e
#'   rimuove caratteri non alfanumerici per ottenere un nome file sicuro.
#' @param testo character(1) Stringa da convertire.
#' @return character(1) Slug in minuscolo con soli caratteri [a-z0-9_].
#' @examples
#' slugify("Integrali ed esponenziali")  # "integrali_ed_esponenziali"
#' slugify("Geometria analitica (2D)")   # "geometria_analitica_2d"
#' @export
slugify <- function(testo) {
  testo |>
    stringr::str_to_lower() |>
    stringr::str_replace_all(
      c(
        "[àáâãä]" = "a",
        "[èéêë]" = "e",
        "[ìíîï]" = "i",
        "[òóôõö]" = "o",
        "[ùúûü]" = "u"
      )
    ) |>
    stringr::str_replace_all("[^a-z0-9]+", "_") |>
    stringr::str_replace_all("^_|_$", "")
}

#' Formatta una data in italiano
#'
#' @title Formatta data italiana
#' @description Converte un oggetto Date nel formato esteso italiano,
#'   es. "27 aprile 2026".
#' @param data Date oggetto Date da formattare. Se NULL usa Sys.Date().
#' @return character(1) Data formattata in italiano.
#' @examples
#' formatta_data_italiana(as.Date("2026-04-27"))  # "27 aprile 2026"
#' @export
formatta_data_italiana <- function(data = NULL) {
  if (is.null(data)) data <- Sys.Date()
  mesi <- c(
    "gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno",
    "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre"
  )
  giorno <- as.integer(format(data, "%d"))
  mese   <- mesi[as.integer(format(data, "%m"))]
  anno   <- format(data, "%Y")
  glue::glue("{giorno} {mese} {anno}")
}

#' Calcola spazio verticale per uno svolgimento
#'
#' @title Calcola spazio vspace
#' @description Restituisce lo spazio verticale LaTeX (\vspace) da inserire
#'   nel compito in proporzione ai punti assegnati all'esercizio.
#' @param punti integer Punti assegnati all'esercizio.
#' @param cm_per_punto numeric Centimetri per ogni punto (default 1.5).
#' @return character(1) Stringa LaTeX, es. "\\vspace{7.5cm}".
#' @examples
#' calcola_spazio_vspace(5)   # "\\vspace{7.5cm}"
#' calcola_spazio_vspace(3, cm_per_punto = 2)  # "\\vspace{6cm}"
#' @export
calcola_spazio_vspace <- function(punti, cm_per_punto = 1.5) {
  cm <- punti * cm_per_punto
  # minimo 2cm, massimo 12cm per evitare pagine vuote
  cm <- max(2, min(12, cm))
  glue::glue("\\vspace{{{cm}cm}}")
}

#' Genera un timestamp per il nome file archivio
#'
#' @title Timestamp archivio
#' @description Restituisce un timestamp compatto da usare nei nomi file.
#' @return character(1) Timestamp nel formato "YYYYMMDD_HHMMSS".
#' @examples
#' timestamp_archivio()  # es. "20260427_143022"
#' @export
timestamp_archivio <- function() {
  format(Sys.time(), "%Y%m%d_%H%M%S")
}
