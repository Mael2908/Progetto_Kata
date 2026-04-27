# Generatore di verifiche di matematica

App R Shiny locale per generare verifiche scritte di matematica per il liceo.
L'insegnante compila un form, l'app chiama l'API Anthropic Claude per generare gli
esercizi, mostra una preview interattiva e produce due PDF: il compito per gli studenti
e la griglia di correzione con soluzioni.

## Requisiti

- R >= 4.1 (per la pipe nativa `|>`)
- [Quarto](https://quarto.org/docs/get-started/) installato sul sistema
- TinyTeX (installato tramite R, vedi sotto)
- Una API key Anthropic Claude

## Installazione

### 1. Installa i pacchetti R

```r
install.packages(c(
  "shiny", "bslib", "ellmer", "jsonlite",
  "quarto", "tinytex", "fs", "glue", "withr",
  "zip", "stringr", "purrr", "readr"
))
```

### 2. Installa TinyTeX (se non hai LaTeX sul sistema)

```r
tinytex::install_tinytex()
```

Se hai già una distribuzione LaTeX completa (MiKTeX, TeX Live), puoi saltare questo passo.

### 3. Configura la API key

Copia il file `.Renviron.example` in `.Renviron` nella root del progetto:

```
ANTHROPIC_API_KEY=sk-ant-api03-...la-tua-chiave...
```

Poi riavvia R per caricare la variabile d'ambiente.

## Avvio dell'app

```r
source("run_app.R")
```

## Test della pipeline core (Step 1)

Prima di usare l'app completa, verifica che la pipeline funzioni:

```r
source("scripts/test_pipeline.R")
```

Questo script chiama l'API con parametri fissi e genera due PDF nella cartella
`output/test_pipeline/`. Controlla che:

- La matematica LaTeX sia renderizzata correttamente
- Il compito abbia righe vuote per Nome/Cognome/Classe/Voto
- La griglia di correzione mostri soluzioni e passaggi

## Struttura del progetto

```
Progetto_Kata/
├── app.R                  # Entry point Shiny (Step 2)
├── run_app.R              # Shortcut per lanciare l'app
├── R/
│   ├── api_client.R       # Chiamate API Anthropic con retry
│   ├── prompt_builder.R   # Costruzione prompt
│   ├── json_validator.R   # Parsing e validazione schema JSON
│   ├── pdf_renderer.R     # Wrapper quarto_render()
│   └── utils.R            # Funzioni helper
├── templates/
│   ├── test.qmd           # Template compito studenti
│   └── soluzioni.qmd      # Template griglia correzione
├── prompts/
│   └── sistema.md         # System prompt per Claude
├── scripts/
│   └── test_pipeline.R    # Smoke test Step 1
└── output/                # PDF generati (non committato)
```

## Argomenti supportati

Algebra, Geometria analitica, Trigonometria, Limiti, Derivate, Integrali,
Probabilità, Statistica, Numeri complessi, Geometria euclidea, Successioni,
Logaritmi ed esponenziali — più campo libero per argomenti personalizzati.

## Note sulla sicurezza

- Il file `.Renviron` con la API key non viene committato (incluso nel `.gitignore`)
- I PDF generati in `output/` non vengono committati
