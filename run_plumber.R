# run_plumber.R
library(plumber)
library(jsonlite)

# define diretório de trabalho
setwd("/app")

# carrega as rotas da API
pr <- plumb("api_modelo_plumber.R")

# injeta a spec do OpenAPI/Swagger
spec <- jsonlite::read_json("openapi.json", simplifyVector = FALSE)

pr |> pr_set_api_spec(spec)

# força unboxing de vetores de comprimento 1
pr <- pr |> pr_set_serializer(serializer_unboxed_json())

# Ativa/desativa debug
pr_set_debug(pr, debug = FALSE)

# sobe a API com docs ativos
pr$run(
  host = "0.0.0.0",
  port = 10000,
  docs = TRUE
)
