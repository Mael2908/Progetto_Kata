#' Parsing e validazione del JSON restituito dall'API
#'
#' @title Valida JSON
#' @description Parsa la stringa JSON grezza e verifica la presenza di tutti i
#'   campi obbligatori secondo lo schema atteso. Restituisce una lista R
#'   strutturata o lancia un errore con messaggio diagnostico.
#' @param json_raw character(1) Stringa JSON grezza restituita dall'API.
#' @return list Lista R con campi \code{metadata} e \code{esercizi}.
#'   Attributo \code{avvertimenti} contiene eventuali warning non bloccanti.
#' @examples
#' \dontrun{
#'   dati <- valida_json(json_raw)
#'   dati$metadata$argomento
#'   dati$esercizi[[1]]$testo
#' }
#' @export
valida_json <- function(json_raw) {
  # Parsing base
  parsed <- tryCatch(
    jsonlite::fromJSON(json_raw, simplifyDataFrame = FALSE),
    error = function(e) {
      stop(glue::glue(
        "JSON non parsabile.\nErrore jsonlite: {conditionMessage(e)}\n",
        "Prime 200 caratteri della risposta:\n",
        "{stringr::str_sub(json_raw, 1, 200)}"
      ))
    }
  )

  avvertimenti <- character(0)

  # --- Verifica metadata ---
  if (is.null(parsed$metadata)) {
    stop("Campo 'metadata' mancante nel JSON.")
  }

  campi_metadata <- c(
    "argomento", "difficolta", "n_esercizi",
    "punteggio_totale", "durata_minuti"
  )
  mancanti_meta <- setdiff(campi_metadata, names(parsed$metadata))
  if (length(mancanti_meta) > 0) {
    stop(glue::glue(
      "Campi mancanti in metadata: {paste(mancanti_meta, collapse = ', ')}"
    ))
  }

  # --- Verifica array esercizi ---
  if (is.null(parsed$esercizi) || length(parsed$esercizi) == 0) {
    stop("Campo 'esercizi' mancante o vuoto nel JSON.")
  }

  campi_esercizio <- c(
    "id", "titolo_breve", "testo", "punti",
    "difficolta_stimata", "soluzione_finale", "passaggi"
  )

  for (i in seq_along(parsed$esercizi)) {
    ez <- parsed$esercizi[[i]]
    mancanti_ez <- setdiff(campi_esercizio, names(ez))
    if (length(mancanti_ez) > 0) {
      stop(glue::glue(
        "Esercizio {i}: campi mancanti: {paste(mancanti_ez, collapse = ', ')}"
      ))
    }

    if (!is.numeric(ez$punti) || ez$punti <= 0) {
      stop(glue::glue("Esercizio {i}: campo 'punti' non valido ({ez$punti})."))
    }

    if (!is.list(ez$passaggi) && !is.character(ez$passaggi)) {
      stop(glue::glue("Esercizio {i}: 'passaggi' deve essere un array di stringhe."))
    }
  }

  # --- Verifica coerenza punteggi (warning non bloccante) ---
  punti_totali <- sum(purrr::map_dbl(parsed$esercizi, "punti"))
  punteggio_atteso <- parsed$metadata$punteggio_totale

  if (!isTRUE(all.equal(punti_totali, punteggio_atteso))) {
    msg <- glue::glue(
      "Somma punti esercizi ({punti_totali}) != punteggio_totale ({punteggio_atteso})."
    )
    avvertimenti <- c(avvertimenti, msg)
    warning(msg)
  }

  # --- Verifica coerenza n_esercizi (warning non bloccante) ---
  n_eff <- length(parsed$esercizi)
  n_att <- parsed$metadata$n_esercizi
  if (n_eff != n_att) {
    msg <- glue::glue(
      "Numero esercizi effettivi ({n_eff}) != n_esercizi nei metadata ({n_att})."
    )
    avvertimenti <- c(avvertimenti, msg)
    warning(msg)
  }

  attr(parsed, "avvertimenti") <- avvertimenti
  parsed
}

#' Ribilancia i punti degli esercizi in modo che sommino al totale atteso
#'
#' @title Ribilancia punti
#' @description Distribuisce il punteggio totale proporzionalmente tra gli
#'   esercizi, arrotondando per garantire la somma esatta.
#' @param dati list Lista validata da \code{valida_json}.
#' @return list Stessa struttura con \code{esercizi[[i]]$punti} corretti.
#' @export
ribilancia_punti <- function(dati) {
  totale  <- dati$metadata$punteggio_totale
  n       <- length(dati$esercizi)
  punti_orig <- purrr::map_dbl(dati$esercizi, "punti")

  # Distribuzione proporzionale
  proporzioni <- punti_orig / sum(punti_orig)
  punti_nuovi <- round(proporzioni * totale)

  # Corregge arrotondamento per garantire la somma esatta
  diff <- totale - sum(punti_nuovi)
  if (diff != 0) {
    # Aggiunge/toglie il residuo all'esercizio con il punteggio piu' alto
    idx_max <- which.max(punti_nuovi)
    punti_nuovi[idx_max] <- punti_nuovi[idx_max] + diff
  }

  for (i in seq_len(n)) {
    dati$esercizi[[i]]$punti <- punti_nuovi[i]
  }

  dati
}
