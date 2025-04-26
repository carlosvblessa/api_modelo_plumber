FROM rocker/r-ver:4.5.0

ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=${DEBIAN_FRONTEND}

RUN apt-get -y update && apt-get -y upgrade && \
    apt-get install -y tzdata && \
    ln -fs /usr/share/zoneinfo/America/Maceio /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    mkdir /app && \
    R -e "install.packages(c('plumber', 'dplyr', 'DBI', 'RSQLite', 'jsonlite', 'jose', 'nnet'), Ncpus = 16, repos='https://cloud.r-project.org/')" ; \
    R -e "if(!require(plumber)) install.packages('plumber'); if(!require(dplyr)) install.packages('dplyr'); if(!require(DBI)) install.packages('DBI'); if(!require(jsonlite)) install.packages('jsonlite'); if(!require(jose)) install.packages('jose'); if(!require(nnet)) install.packages('nnet')" && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

    # Definir o diretório de trabalho
WORKDIR /app

# Copiar o script da API do plumber e o modelo para a imagem Docker
COPY modelo_iris_LR.rds openapi.json api_modelo_plumber.R run_plumber.R predictions.db /app/

# Permite que o SQLite crie e modifique arquivos dentro de /app
RUN chmod -R a+rwx /app

# Expor a porta onde o plumber será executado
EXPOSE 10000

# Healthcheck para verificar se a rota /health está respondendo OK
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:10000/health || exit 1
  
# Comando para executar a API
ENTRYPOINT ["R", "-f", "/app/run_plumber.R"]

