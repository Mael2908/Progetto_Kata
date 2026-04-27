# Shortcut per lanciare l'applicazione Shiny
# Esegui con: source("run_app.R")

if (!nchar(Sys.getenv("ANTHROPIC_API_KEY"))) {
  stop(
    "API key Anthropic non trovata.\n",
    "Crea un file .Renviron nella root del progetto con:\n",
    "  ANTHROPIC_API_KEY=sk-ant-...\n",
    "Poi riavvia R e riprova."
  )
}

shiny::runApp(".", launch.browser = TRUE)
