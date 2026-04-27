#' Chiama Claude tramite il CLI di Claude Code (account esistente)
#'
#' @title Chiama API
#' @description Invia il prompt a Claude tramite il CLI `claude -p`, usando
#'   l'autenticazione dell'account Claude Code già attivo sul PC. Non richiede
#'   API key separata. Implementa retry logic con backoff esponenziale e
#'   reprompt automatico in caso di JSON malformato.
#' @param user_prompt character(1) Messaggio utente costruito da prompt_builder.R.
#' @param system_prompt character(1) System prompt (caricato da prompts/sistema.md).
#'   Se NULL lo carica automaticamente dal file.
#' @param max_tentativi integer Numero massimo di tentativi totali (default 3).
#' @return character(1) Stringa JSON grezza restituita da Claude.
#' @examples
#' \dontrun{
#'   json_raw <- chiama_api(
#'     user_prompt = costruisci_prompt(params)
#'   )
#' }
#' @export
chiama_api <- function(
    user_prompt,
    system_prompt = NULL,
    max_tentativi = 3
) {
  .verifica_claude_cli()

  if (is.null(system_prompt)) {
    percorso_sistema <- fs::path("prompts", "sistema.md")
    if (!fs::file_exists(percorso_sistema)) {
      stop("File prompts/sistema.md non trovato. Esegui dall'interno della directory del progetto.")
    }
    system_prompt <- readr::read_file(percorso_sistema)
  }

  ritardi <- c(2, 5, 10)

  json_raw        <- NULL
  ultimo_errore   <- NULL
  prompt_corrente <- user_prompt

  for (tentativo in seq_len(max_tentativi)) {
    esito <- .chiama_claude_cli(prompt_corrente, system_prompt)

    if (!esito$ok) {
      ultimo_errore <- esito$errore
      message(glue::glue("[CLI] Tentativo {tentativo}/{max_tentativi} fallito: {ultimo_errore}"))
      if (tentativo < max_tentativi) Sys.sleep(ritardi[min(tentativo, length(ritardi))])
      next
    }

    testo_pulito <- .estrai_json(esito$testo)
    errore_json  <- tryCatch({
      jsonlite::fromJSON(testo_pulito, simplifyDataFrame = FALSE)
      NULL
    }, error = function(e) conditionMessage(e))

    if (is.null(errore_json)) {
      json_raw <- testo_pulito
      break
    }

    ultimo_errore <- errore_json
    message(glue::glue("[CLI] JSON malformato al tentativo {tentativo}: {errore_json}"))

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
      "Claude CLI non ha restituito JSON valido dopo {max_tentativi} tentativi.\n",
      "Ultimo errore: {ultimo_errore}"
    ))
  }

  json_raw
}

# --- Funzioni interne ---

#' Esegue una singola chiamata al CLI claude --print
#'
#' @description Combina system prompt e user prompt in un unico messaggio e
#'   lo passa via stdin a `claude --print`. Il CLI non ha un flag
#'   --system-prompt, quindi le istruzioni vengono iniettate nel testo.
#' @param prompt character(1) User prompt.
#' @param system_prompt character(1) System prompt (istruzioni di ruolo).
#' @return list con campi \code{ok} (logical) e \code{testo} o \code{errore}.
#' @keywords internal
.chiama_claude_cli <- function(prompt, system_prompt) {
  # Combina system prompt e user prompt in un unico testo da passare via stdin.
  # Il CLI legge da stdin quando non riceve argomenti di testo.
  testo_completo <- paste0(
    "=== ISTRUZIONI DI SISTEMA (segui scrupolosamente) ===\n",
    system_prompt,
    "\n\n=== RICHIESTA ===\n",
    prompt
  )

  output <- tryCatch({
    system2(
      command = "claude",
      args    = c("--print", "--output-format", "text"),
      input   = testo_completo,   # passato via stdin, evita limiti riga di comando
      stdout  = TRUE,
      stderr  = FALSE,
      wait    = TRUE
    )
  }, error = function(e) {
    structure(character(0), status = 1L, errmsg = conditionMessage(e))
  })

  status <- attr(output, "status") %||% 0L

  if (!is.null(attr(output, "errmsg"))) {
    return(list(ok = FALSE, errore = attr(output, "errmsg")))
  }

  if (!is.null(status) && status != 0L) {
    return(list(ok = FALSE, errore = glue::glue("claude CLI uscito con codice {status}")))
  }

  if (length(output) == 0) {
    return(list(ok = FALSE, errore = "claude CLI ha restituito output vuoto"))
  }

  list(ok = TRUE, testo = paste(output, collapse = "\n"))
}

#' Controlla che il CLI claude sia disponibile nel PATH
#'
#' @return invisible(TRUE) o lancia un errore con istruzioni.
#' @keywords internal
.verifica_claude_cli <- function() {
  trovato <- tryCatch({
    out <- system2("claude", args = "--version", stdout = TRUE, stderr = FALSE)
    length(out) > 0
  }, error = function(e) FALSE)

  if (!trovato) {
    stop(
      "Il CLI 'claude' non e' stato trovato nel PATH di sistema.\n",
      "Assicurati che Claude Code Desktop sia installato e che il CLI sia accessibile.\n",
      "Su Windows puoi verificare aprendo un terminale e digitando: claude --version\n",
      "Se il comando non viene riconosciuto, aggiungi la cartella di Claude Code al PATH."
    )
  }

  invisible(TRUE)
}

#' Estrae il blocco JSON da una risposta che potrebbe contenere markdown
#'
#' @param testo character(1) Risposta grezza del CLI.
#' @return character(1) Stringa JSON pulita.
#' @keywords internal
.estrai_json <- function(testo) {
  testo <- stringr::str_trim(testo)

  if (stringr::str_detect(testo, "```")) {
    testo <- stringr::str_extract(testo, "(?s)\\{.*\\}")
    if (is.na(testo)) stop("Impossibile estrarre JSON dalla risposta.")
  }

  inizio <- stringr::str_locate(testo, "\\{")[1, "start"]
  fine   <- stringr::str_locate_all(testo, "\\}")[[1]]
  fine   <- fine[nrow(fine), "end"]

  if (is.na(inizio) || is.na(fine)) return(testo)

  stringr::str_sub(testo, inizio, fine)
}

# Operatore %||% per valori di default
`%||%` <- function(x, y) if (is.null(x)) y else x
