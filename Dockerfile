FROM mcr.microsoft.com/powershell:latest

# Instala mingw-w64, 7-zip e ferramentas básicas de build
RUN apt-get update && apt-get install -y \
    mingw-w64 \
    p7zip-full \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Configura o diretório de trabalho padrão
WORKDIR /workspace

# O container executará o script de build principal ao ser iniciado
ENTRYPOINT ["pwsh", "./builder/build.ps1"]
