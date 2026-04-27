#' Costruisce il user prompt per la generazione degli esercizi
#'
#' @title Costruisci prompt
#' @description Genera il messaggio utente da inviare all'API Anthropic
#'   per la creazione di una verifica completa. Inietta tutti i parametri
#'   nel template tramite glue.
#' @param params list Lista con i seguenti campi obbligatori:
#'   \describe{
#'     \item{argomento}{character(1) Argomento matematico (es. "Integrali").}
#'     \item{n_esercizi}{integer Numero di esercizi (1-15).}
#'     \item{difficolta}{character(1) "Facile", "Medio", "Difficile" o "Misto".}
#'     \item{durata_minuti}{integer Durata prevista in minuti.}
#'     \item{punteggio_totale}{integer Punteggio totale della verifica.}
#'     \item{classe}{character(1) Nome della classe (es. "5A Liceo Scientifico").}
#'     \item{descrizione_libera}{character(1) Descrizione opzionale (può essere "").}
#'   }
#' @return character(1) Stringa del user message pronta per l'API.
#' @examples
#' params <- list(
#'   argomento = "Integrali",
#'   n_esercizi = 3,
#'   difficolta = "Medio",
#'   durata_minuti = 60,
#'   punteggio_totale = 15,
#'   classe = "5A Liceo Scientifico",
#'   descrizione_libera = "Integrazione per parti e sostituzione"
#' )
#' costruisci_prompt(params)
#' @export
costruisci_prompt <- function(params) {
  argomento         <- params$argomento
  n_esercizi        <- params$n_esercizi
  difficolta        <- params$difficolta
  durata_minuti     <- params$durata_minuti
  punteggio_totale  <- params$punteggio_totale
  classe            <- params$classe
  descrizione_libera <- params$descrizione_libera %||% ""

  nota_descrizione <- if (nchar(stringr::str_trim(descrizione_libera)) > 0) {
    glue::glue("Nota aggiuntiva dell'insegnante: {descrizione_libera}")
  } else {
    ""
  }

  glue::glue(
    "Crea una verifica di matematica con le seguenti specifiche:\n\n",
    "- Argomento: {argomento}\n",
    "- Classe: {classe}\n",
    "- Numero di esercizi: {n_esercizi}\n",
    "- Difficolta complessiva: {difficolta}\n",
    "- Durata prevista: {durata_minuti} minuti\n",
    "- Punteggio totale: {punteggio_totale} punti\n",
    "{nota_descrizione}\n\n",
    "Ricorda:\n",
    "1. La somma dei punti degli esercizi deve essere esattamente {punteggio_totale}.\n",
    "2. Ogni esercizio deve avere un titolo_breve, testo, punti, difficolta_stimata, ",
    "soluzione_finale, passaggi e suggerimento.\n",
    "3. Usa LaTeX con doppia backslash nelle stringhe JSON.\n",
    "4. Restituisci solo JSON valido, nessun testo fuori dall'oggetto JSON.",
    .sep = ""
  )
}

#' Costruisce il prompt per rigenerare un singolo esercizio
#'
#' @title Costruisci prompt rigenera
#' @description Genera il messaggio per chiedere all'API di sostituire
#'   un singolo esercizio mantenendo il contesto della verifica.
#' @param id_esercizio integer ID dell'esercizio da rigenerare (1-based).
#' @param context list Lista con gli stessi campi di \code{costruisci_prompt},
#'   più \code{esercizi_esistenti} (lista degli esercizi già approvati).
#' @return character(1) Stringa del user message.
#' @examples
#' context <- list(
#'   argomento = "Integrali",
#'   n_esercizi = 3,
#'   difficolta = "Medio",
#'   durata_minuti = 60,
#'   punteggio_totale = 15,
#'   classe = "5A",
#'   descrizione_libera = "",
#'   esercizi_esistenti = list()
#' )
#' costruisci_prompt_rigenera(id_esercizio = 2, context = context)
#' @export
costruisci_prompt_rigenera <- function(id_esercizio, context) {
  argomento        <- context$argomento
  difficolta       <- context$difficolta
  punteggio_totale <- context$punteggio_totale
  n_esercizi       <- context$n_esercizi

  # Punti rimasti da assegnare all'esercizio da rigenerare
  altri_esercizi <- context$esercizi_esistenti[
    purrr::map_int(context$esercizi_esistenti, "id") != id_esercizio
  ]
  punti_usati <- sum(purrr::map_int(altri_esercizi, "punti"))
  punti_da_assegnare <- punteggio_totale - punti_usati

  glue::glue(
    "Rigenera solo l'esercizio numero {id_esercizio} di una verifica su {argomento}.\n\n",
    "La verifica ha {n_esercizi} esercizi totali con difficolta {difficolta}.\n",
    "Agli altri esercizi sono stati assegnati {punti_usati} punti, quindi ",
    "questo esercizio deve valere esattamente {punti_da_assegnare} punti.\n\n",
    "Restituisci un oggetto JSON con un solo esercizio nel campo 'esercizi' ",
    "e metadata coerente con i dati sopra.\n",
    "Solo JSON valido, nessun testo fuori.",
    .sep = ""
  )
}

# Operatore %||% per valori di default (se non gia' caricato)
`%||%` <- function(x, y) if (is.null(x) || (is.character(x) && !nzchar(x))) y else x
