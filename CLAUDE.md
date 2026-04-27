# Progetto_Kata — Generatore di verifiche di matematica

## Contesto
App R Shiny locale per un'insegnante di matematica del liceo. Genera verifiche
personalizzate tramite il CLI `claude --print` (nessuna API key richiesta) e
produce due PDF: compito studenti + griglia di correzione.

## Stack
- `shiny` + `bslib` per la UI
- CLI `claude --print` per la generazione esercizi (via `system2()`)
- `quarto` + `tinytex` per il rendering PDF
- `jsonlite` per parsing/validazione della risposta JSON

## Struttura
```
R/               # moduli della pipeline
templates/       # template Quarto per i PDF
prompts/         # system prompt per Claude
scripts/         # script di test standalone
data/            # dati locali (non committati)
output/          # PDF generati (non committati)
```

## Moduli R
| File | Responsabilità |
|------|----------------|
| `R/prompt_builder.R` | Costruisce il user prompt con glue |
| `R/api_client.R` | Chiama `claude --print` via system2, retry + reprompt |
| `R/json_validator.R` | Parsing + validazione schema JSON |
| `R/pdf_renderer.R` | Wrapper `quarto::quarto_render()` |
| `R/utils.R` | slugify, formatta_data_italiana, calcola_spazio_vspace |

## Schema JSON atteso dall'LLM
Vedere `prompts/sistema.md` per lo schema completo e gli esempi.

## Note operative
- Eseguire sempre dalla root del progetto (dove si trova `DESCRIPTION`)
- Test pipeline core: `source("scripts/test_pipeline.R")`
- Il CLI `claude` deve essere nel PATH di sistema
