# api_modelo_plumber.R
# API de Previsão Iris com Plumber

library(plumber)
library(DBI)
library(RSQLite)
library(jsonlite)
library(jose)
library(nnet)

# Configurações
JWT_SECRET            <- Sys.getenv("JWT_SECRET", "MEUSEGREDOAQUI")
JWT_ALGORITHM         <- "HS256"
JWT_EXP_DELTA_SECONDS <- 3600
DB_URL                <- Sys.getenv("DB_URL", "/app/predictions.db")
TEST_USERNAME         <- Sys.getenv("TEST_USERNAME", "admin")
TEST_PASSWORD         <- Sys.getenv("TEST_PASSWORD", "secret")

# Conexão com SQLite
db_conn <- dbConnect(RSQLite::SQLite(), DB_URL)
if (!dbExistsTable(db_conn, "predictions")) {
  dbExecute(db_conn, "
    CREATE TABLE IF NOT EXISTS predictions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sepal_length REAL,
      sepal_width REAL,
      petal_length REAL,
      petal_width REAL,
      predicted_class INTEGER,
      created_at TEXT
    )
  ")
}

# Carregar modelo
model <- readRDS("modelo_iris_LR.rds")

# Cache de predições
predictions_cache <- new.env(hash = TRUE)

# Funções JWT
create_token <- function(username) {
  claim <- jwt_claim(
    username = username,
    exp      = as.integer(Sys.time()) + JWT_EXP_DELTA_SECONDS
  )
  jwt_encode_hmac(claim, secret = JWT_SECRET)
}

verify_token <- function(token) {
  decoded <- jwt_decode_hmac(token, secret = JWT_SECRET)
  payload <- decoded$payload
  if (!is.null(payload$exp) && as.integer(Sys.time()) > payload$exp) {
    stop("Token expirado")
  }
  payload
}

# Filtro CORS
#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Headers", "Authorization, Content-Type")
  plumber::forward()
}

# Preflight CORS
#* @options /*
function(req, res) {
  res$status <- 200
  res$body   <- ""
  res
}

# Login
#* @post /login
#* @param username:string Nome de usuário (default admin)
#* @param password:string Senha (default secret)
#* @response 200 JWT válido
#* @response 401 Credenciais inválidas
function(username = "admin", password = "secret", res) {
  if (identical(username, TEST_USERNAME) && identical(password, TEST_PASSWORD)) {
    token <- create_token(username)
    list(token = token)
  } else {
    res$status <- 401
    list(error = "Credenciais inválidas")
  }
}

# Predição
#* @post /predict
#* @param sepal_length:numeric  Comprimento da sépala
#* @param sepal_width:numeric   Largura da sépala
#* @param petal_length:numeric  Comprimento da pétala
#* @param petal_width:numeric   Largura da pétala
#* @response 200 Classe prevista
#* @response 401 Não autorizado
function(req, res,
         sepal_length = 6,
         sepal_width  = 3,
         petal_length = 4,
         petal_width  = 1) {
  # Validação do token JWT
  auth_header <- req$HTTP_AUTHORIZATION
  if (is.null(auth_header) || !grepl("^Bearer\\s+", auth_header)) {
    res$status <- 401
    return(list(error = "Token ausente ou mal formatado"))
  }
  token <- sub("^Bearer\\s+", "", auth_header)
  payload <- tryCatch(
    verify_token(token),
    error = function(e) {
      res$status <- 401
      list(error = e$message)
    }
  )
  if (is.list(payload) && !is.null(payload$error)) {
    return(payload)
  }
  
  # Lógica de predição
  key <- paste(sepal_length, sepal_width, petal_length, petal_width, sep = "-")
  if (exists(key, envir = predictions_cache)) {
    predicted_class <- predictions_cache[[key]]
  } else {
    input_df <- data.frame(
      sepal_length = as.numeric(sepal_length),
      sepal_width  = as.numeric(sepal_width),
      petal_length = as.numeric(petal_length),
      petal_width  = as.numeric(petal_width)
    )
    predicted_class <- as.integer(
      predict(model, newdata = input_df, type = "class")
    )
    predictions_cache[[key]] <- predicted_class
    dbExecute(
      db_conn,
      "INSERT INTO predictions (sepal_length, sepal_width, petal_length, petal_width, predicted_class, created_at) VALUES (?, ?, ?, ?, ?, ?)",
      params = list(
        as.numeric(sepal_length),
        as.numeric(sepal_width),
        as.numeric(petal_length),
        as.numeric(petal_width),
        predicted_class,
        as.character(Sys.time())
      )
    )
  }
  list(predicted_class = predicted_class)
}

# Listagem
#* Retorna previsões cadastradas
#* @get /predictions
#* @param limit:int   Número máximo de registros (default 10)
#* @param offset:int  Deslocamento (default 0)
#* @response 200 Lista de predições
#* @response 401 Não autorizado
function(req, res,
         limit  = 10,
         offset = 0) {
  # Validação do token JWT
  auth_header <- req$HTTP_AUTHORIZATION
  if (is.null(auth_header) || !grepl("^Bearer\\s+", auth_header)) {
    res$status <- 401
    return(list(error = "Token ausente ou mal formatado"))
  }
  token <- sub("^Bearer\\s+", "", auth_header)
  payload <- tryCatch(
    verify_token(token),
    error = function(e) {
      res$status <- 401
      list(error = e$message)
    }
  )
  if (is.list(payload) && !is.null(payload$error)) {
    return(payload)
  }
  
  # Lógica de listagem
  preds <- dbGetQuery(
    db_conn,
    "SELECT * FROM predictions ORDER BY id DESC LIMIT ? OFFSET ?",
    params = list(as.integer(limit), as.integer(offset))
  )
  preds
}

#* Rota de Health Check
#* Retorna status da API
#* @get /health
#* @response 200 API funcionando
function(){
  list(status = "OK")
}

#* @get /
#* @serializer html
function(req) {
  # Extrair host e protocolo (http/https)
  host  <- req$HTTP_HOST
  proto <- if (!is.null(req$HTTPS) && req$HTTPS == "on") "https" else "http"
  
  # Montar URL base da documentação
  docs_url <- paste0(proto, "://", host, "/__docs__/#/")
  
  # HTML personalizado como string
  html <- sprintf(
    '<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title>API Iris Prediction</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; background-color: #f7f9fc; color: #333; }
    h1 { color: #2c3e50; }
    ul { list-style-type: square; padding-left: 20px; }
    a { color: #3498db; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .footer { margin-top: 40px; font-size: 0.9em; color: #777; }
  </style>
</head>
<body>
  <h1>🌼 Bem-vindo à API de Previsão Iris com Plumber!</h1>
  <p>Esta é uma API REST simples para prever espécies de flores Iris com base em medidas das pétalas e sépalas.</p>

  <h2>🔗 Endpoints Disponíveis:</h2>
  <ul>
    <li><code>POST /login</code>          - Autenticação e geração de token JWT</li>
    <li><code>POST /predict</code>        - Realizar nova predição</li>
    <li><code>GET  /predictions</code>    - Listar predições salvas</li>
    <li><code>GET  /health</code>         - Verificar status da API</li>
  </ul>

  <h2>📄 Documentação Interativa:</h2>
  <p><a href="%s" target="_blank">Acesse a documentação Swagger UI</a></p>

  <div class="footer">
    &copy; %d API Iris – Desenvolvido com R + Plumber
  </div>
</body>
</html>',
    docs_url,
    as.integer(format(Sys.Date(), "%Y"))
  )
  
  # Retorna a string HTML
  html
}
