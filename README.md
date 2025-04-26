# API de Previsão Iris com Plumber

## Descrição
Este projeto implementa uma API REST em **R** usando o **Plumber** para autenticação via JWT e predição de espécies do conjunto de dados Iris. A API é empacotada em contêiner Docker e orquestrada via Docker Compose.

## Tecnologias
- Linguagem: R (>= 4.5.0)
- Framework: Plumber (REST)
- Banco leve: SQLite (arquivo `predictions.db`)
- Autenticação: JSON Web Tokens (package `jose`)
- Containerização: Docker / Docker Compose

## Endpoints

### 1. Health Check (`/health`)
- **Método:** `GET`
- **Descrição:** Verifica se a API está no ar.
- **Resposta 200:**
  ```json
  { "status": "OK" }
  ```

### 2. Login (`/login`)
- **Método:** `POST`
- **Parâmetros (form-data ou query):**
  - `username` (string, default `admin`)
  - `password` (string, default `secret`)
- **Resposta 200:**
  ```json
  { "token": "<JWT>" }
  ```
- **Resposta 401:**
  ```json
  { "error": "Credenciais inválidas" }
  ```

### 3. Predição (`/predict`)
- **Método:** `POST`
- **Cabeçalho:**
  - `Authorization: Bearer <token>`
- **Parâmetros (form-data ou query):**
  - `sepal_length` (numeric)
  - `sepal_width` (numeric)
  - `petal_length` (numeric)
  - `petal_width` (numeric)
- **Resposta 200:**
  ```json
  { "predicted_class": 0 }
  ```
- **Resposta 401:**
  ```json
  { "error": "Token inválido ou ausente" }
  ```

### 4. Lista de Predições (`/predictions`)
- **Método:** `GET`
- **Cabeçalho:**
  - `Authorization: Bearer <token>`
- **Query params:**
  - `limit` (integer, default 10)
  - `offset` (integer, default 0)
- **Resposta 200:**
  ```json
  [
    {
      "id": 1,
      "sepal_length": 5.1,
      "sepal_width": 3.5,
      "petal_length": 1.4,
      "petal_width": 0.2,
      "predicted_class": 0,
      "created_at": "2025-04-21 19:42:48.788796"
    },
    ...
  ]
  ```

## Pré-requisitos
- Docker
- Docker Compose

## Como Rodar
1. Clone este repositório:
   ```bash
   git clone https://github.com/carlosvblessa/api_modelo_plumber.git
   cd api_modelo_plumber
   ```

2. Defina variáveis de ambiente (opcional):
   - `JWT_SECRET` (segredo do token JWT)
   - `DB_URL` (local do arquivo SQLite, ex.: `/app/predictions.db`)

3. Inicie com Docker Compose:
   ```bash
   docker-compose up --build -d
   ```

4. Verifique o status:
   ```bash
   docker ps  # container deve estar UP (healthy)
   curl http://localhost:10000/health
   ```

5. Acesse a documentação OpenAPI/Swagger:
   
```


