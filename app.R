# Entry point principale dell'applicazione Shiny
# Da implementare nello Step 2 — per ora placeholder

library(shiny)
library(bslib)

# Placeholder UI
ui <- page_fluid(
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  h1("Generatore di verifiche — in costruzione"),
  p("Esegui scripts/test_pipeline.R per testare la pipeline core.")
)

server <- function(input, output, session) {}

shinyApp(ui, server)
