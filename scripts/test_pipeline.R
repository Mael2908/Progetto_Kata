# Script di smoke test per la pipeline core (Step 1)
# Eseguire dalla root del progetto: source("scripts/test_pipeline.R")
# Oppure in RStudio con Ctrl+Shift+Enter

# --- Verifica pacchetti e dipendenze esterne ---
pacchetti_richiesti <- c("stringr", "glue", "jsonlite", "fs", "withr", "purrr", "readr", "quarto")
mancanti <- pacchetti_richiesti[!sapply(pacchetti_richiesti, requireNamespace, quietly = TRUE)]
if (length(mancanti) > 0) {
  stop(
    "Pacchetti R mancanti: ", paste(mancanti, collapse = ", "), "\n",
    "Installa con: install.packages(c(", paste0('"', mancanti, '"', collapse = ", "), "))"
  )
}

if (!nzchar(Sys.which("quarto"))) {
  stop(
    "Il CLI Quarto non e' installato o non e' nel PATH.\n",
    "Scaricalo da: https://quarto.org/docs/get-started/"
  )
}

if (!nzchar(Sys.which("claude"))) {
  stop("Il CLI claude non e' nel PATH. Assicurati che Claude Code Desktop sia installato.")
}

# --- Carica moduli ---
source("R/utils.R")
source("R/prompt_builder.R")
source("R/api_client.R")
source("R/json_validator.R")
source("R/pdf_renderer.R")

# Pacchetti necessari
library(stringr)
library(glue)
library(jsonlite)
library(fs)
library(withr)
library(purrr)
library(readr)

# --- Parametri hard-coded per il test ---
params_test <- list(
  argomento         = "Integrali",
  n_esercizi        = 3,
  difficolta        = "Medio",
  durata_minuti     = 60,
  punteggio_totale  = 15,
  classe            = "5A Liceo Scientifico",
  descrizione_libera = "Integrazione per parti e sostituzione trigonometrica"
)

cat("=== Step 1: Costruzione prompt ===\n")
user_prompt <- costruisci_prompt(params_test)
cat("Prompt costruito (primi 300 caratteri):\n")
cat(stringr::str_sub(user_prompt, 1, 300), "\n\n")

cat("=== Step 2: Chiamata API Anthropic ===\n")
cat("Invio richiesta a claude-sonnet-4-5...\n")
json_raw <- chiama_api(user_prompt)
cat("Risposta ricevuta (primi 500 caratteri):\n")
cat(stringr::str_sub(json_raw, 1, 500), "\n\n")

cat("=== Step 3: Validazione JSON ===\n")
dati <- valida_json(json_raw)
cat(glue::glue("JSON valido. Argomento: {dati$metadata$argomento}\n"))
cat(glue::glue("Esercizi ricevuti: {length(dati$esercizi)}\n"))
punti <- purrr::map_dbl(dati$esercizi, "punti")
cat(glue::glue("Punti: {paste(punti, collapse = ' + ')} = {sum(punti)}\n"))

avv <- attr(dati, "avvertimenti")
if (length(avv) > 0) {
  cat("Avvertimenti:\n")
  for (a in avv) cat("  -", a, "\n")
}
cat("\n")

cat("=== Step 4: Rendering PDF ===\n")
output_dir <- fs::path("output", "test_pipeline")
fs::dir_create(output_dir, recurse = TRUE)

cat("Rendering compito studenti...\n")
pdf_test <- renderizza_pdf(dati, output_dir, "test")

cat("Rendering griglia correzione...\n")
pdf_soluzioni <- renderizza_pdf(dati, output_dir, "soluzioni")

cat("\n=== PIPELINE COMPLETATA ===\n")
cat(glue::glue("Compito:    {pdf_test}\n"))
cat(glue::glue("Soluzioni:  {pdf_soluzioni}\n"))
cat("\nVerifica manuale:\n")
cat("1. Apri i PDF e controlla che la matematica sia renderizzata correttamente.\n")
cat("2. Verifica che i campi Nome/Cognome/Classe/Voto siano righe vuote nel compito.\n")
cat("3. Verifica che le soluzioni compaiano nella griglia ma non nel compito.\n")
