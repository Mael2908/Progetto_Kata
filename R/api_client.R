#' Chiama l'API Anthropic per generare gli esercizi
#'
#' @title Chiama API
#' @description Invia il prompt all'API Anthropic tramite ellmer e restituisce
#'   la stringa JSON grezza. Implementa retry logic con backoff esponenziale
#'   e reprompt automatico in caso di JSON malformato.
#' @param user_prompt character(1) Messaggio utente costruito da prompt_builder.R.
#' @param system_prompt character(1) System prompt (caricato da prompts/sistema.md).
#'   Se NULL lo carica automaticamente dal file.
#' @param max_tentativi integer Numero massimo di tentativi totali (default 3).
#' @param modello character(1) Modello Anthropic da usare (default "claude-sonnet-4-5").
#' @param temperatura numeric Temperatura per la generazione (default 0.5).
#' @return character(1) Stringa JSON grezza restituita dall'API.
#' @examples
#' \dontrun{
#'   json_raw <- chiama_api(
#'     user_prompt = costruisci_prompt(params),
#'     system_prompt = readr::read_file("prompts/sistema.md")
#'   )
#' }
#' @export
chiama_api <- function(
    user_prompt,
    system_prompt = NULL,
    max_tentativi = 3,
    modello       = "claude-sonnet-4-5",
    temperatura   = 0.5
) {
  if (is.null(system_prompt)) {
    percorso_sistema <- fs::path("prompts", "sistema.md")
    if (!fs::file_exists(percorso_sistema)) {
      stop("File prompts/sistema.md non trovato. Esegui dall'interno della directory del progetto.")
    }
    system_prompt <- readr::read_file(percorso_sistema)
  }

  # Ritardi backoff: 2s, 5s, 10s
  ritardi <- c(2, 5, 10)

  json_raw <- NULL
  ultimo_errore <- NULL
  prompt_corrente <- user_prompt

  for (tentativo in seq_len(max_tentativi)) {
    esito <- tryCatch({
      chat <- ellmer::chat_anthropic(
        system  = system_prompt,
        model   = modello,
        echo    = "none",
        api_args = list(temperature = temperatura)
      )
      risposta <- chat$chat(prompt_corrente)
      list(ok = TRUE, testo = risposta)
    }, error = function(e) {
      list(ok = FALSE, errore = conditionMessage(e))
    })

    if (!esito$ok) {
      ultimo_errore <- esito$errore
      message(glue::glue("[API] Tentativo {tentativo}/{max_tentativi} fallito: {ultimo_errore}"))
      if (tentativo < max_tentativi) {
        Sys.sleep(ritardi[min(tentativo, length(ritardi))])
      }
      next
    }

    # Verifica che la risposta sia JSON parsabile
    testo_pulito <- .estrai_json(esito$testo)
    errore_json <- tryCatch({
      jsonlite::fromJSON(testo_pulito, simplifyDataFrame = FALSE)
      NULL
    }, error = function(e) conditionMessage(e))

    if (is.null(errore_json)) {
      json_raw <- testo_pulito
      break
    }

    # JSON malformato: prepara reprompt
    ultimo_errore <- errore_json
    message(glue::glue("[API] JSON malformato al tentativo {tentativo}: {errore_json}"))

    if (tentativo < max_tentativi) {
      prompt_corrente <- glue::glue(
        "La risposta precedente non era JSON valido. ",
        "Correggi e restituisci solo JSON valido secondo lo schema. ",
        "Errore: {errore_json}\n\n",
        "Richiesta originale:\n{user_prompt}"
      )
      Sys.sleep(ritardi[min(tentativo, length(ritardi))])
    }
  }

  if (is.null(json_raw)) {
    stop(glue::glue(
      "API non ha restituito JSON valido dopo {max_tentativi} tentativi.\n",
      "Ultimo errore: {ultimo_errore}"
    ))
  }

  json_raw
}

#' Estrae il blocco JSON da una risposta che potrebbe contenere markdown
#'
#' @param testo character(1) Risposta grezza dell'API.
#' @return character(1) Stringa JSON pulita.
#' @keywords internal
.estrai_json <- function(testo) {
  testo <- stringr::str_trim(testo)

  # Rimuove eventuali backtick markdown (```json ... ```)
  if (stringr::str_detect(testo, "```")) {
    testo <- stringr::str_extract(testo, "(?s)\\{.*\\}")
    if (is.na(testo)) stop("Impossibile estrarre JSON dalla risposta.")
  }

  # Prende solo il contenuto dall'apertura { alla chiusura }
  inizio <- stringr::str_locate(testo, "\\{")[1, "start"]
  fine   <- stringr::str_locate_all(testo, "\\}")[[1]]
  fine   <- fine[nrow(fine), "end"]

  if (is.na(inizio) || is.na(fine)) {
    return(testo)
  }

  stringr::str_sub(testo, inizio, fine)
}
