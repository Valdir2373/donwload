# Projeto Donwload & Troll Security Suite

Este repositório contém uma suíte experimental de ferramentas de segurança, simulação de malware e controle de sistemas, desenvolvida para fins de estudo de cibersegurança, testes de intrusão (pentest) e demonstração de conceitos de criptografia e persistência no sistema operacional Windows. 

A arquitetura do projeto é dividida em três pilares principais:
1. **Servidor de Controle (Node.js)**: Painel e backend para recebimento e download de dados exfiltrados.
2. **Troll Terror & Discord Collector**: Malware simulador composto por scripts de travamento de tela (Melt Glitch), flood de popups, persistência avançada no Windows e um coletor de tokens Discord descriptografados via DPAPI com injeção automática.
3. **Crip Locker (Simulador de Ransomware)**: Mecanismo de criptografia multi-threaded local utilizando a API de Criptografia nativa do Windows (BCrypt/CryptoAPI) com criptografia AES-256 e suporte a chaves RSA.

---

## 📁 Estrutura do Repositório

```text
donw/
├── a/                            # Script simples de automação de navegador
│   ├── main.cpp                  # Código C++ para controle do Edge e injeção simples de teclas
│   ├── edge_control.exe          # Executável compilado do controlador do Edge
│   └── navegador_control.exe     # Executável compilado do navegador
│
├── collector_discord/            # Suíte principal de Simulação & Coleta (C++)
│   ├── main.cpp                  # Orquestração do executável Troll (terror.exe)
│   ├── globals.cpp / .h          # Variáveis globais, mensagens e configurações da suíte
│   ├── helper.cpp / .h            # Funções utilitárias (criação de processos ocultos, RNG)
│   ├── registry.cpp / .h          # Helpers para leitura e escrita no Registro do Windows
│   ├── persistence.cpp / .h      # Métodos de persistência (HKCU Run & HKCU Winlogon Shell)
│   ├── input_lock.cpp / .h        # Ganchos de teclado/mouse (Hooks) e bloqueio completo de entrada
│   ├── wallpaper.cpp / .h        # Troca de papel de parede (fallback em BMP e download dinâmico em JPG)
│   ├── beep.cpp / .h              # Geração de áudio senoidal e loop de som irritante
│   ├── popup.cpp / .h            # Spawner contínuo de popups flutuantes de alerta
│   ├── qr_popup.cpp / .h          # Janela GDI+ que busca e exibe um QR Code via WinHTTP
│   ├── melt.cpp / .h              # Efeito visual de derretimento de tela com glitches horizontais
│   ├── build.bat                 # Script de compilação da suíte Troll (terror.exe)
│   ├── compilerSmart.bat         # Empacotador ZIP com senha (AES-256) para evasão de SmartScreen
│   │
│   ├── collector/                # Subprojeto: Coletor de Tokens e Informações (C++)
│   │   ├── main.cpp              # Entry point do coletor e lógica de upload multipart via WinHTTP
│   │   ├── discord.cpp / .h      # Decriptografia de Master Key (DPAPI) e scan de LevelDB (.ldb/.log)
│   │   ├── sysinfo.cpp / .h      # Coleta de metadados do sistema (Hostname, SO, GeoIP)
│   │   ├── zip_writer.cpp / .h   # Compactação em memória e gravação do arquivo ZIP
│   │   ├── launcher.cpp          # Injetor automático interativo de tokens Discord (discord_launcher.exe)
│   │   ├── resources.rc          # Arquivo de recurso para embutir o launcher no coletor
│   │   ├── build.bat             # Compilação do coletor com o launcher embutido
│   │   └── build_launcher.bat    # Compilação standalone do launcher
│   │
│   ├── compiller/                # Script de automação de compilação
│   │   └── build.ps1             # PowerShell script para compilar múltiplos binários de uma vez
│   │
│   └── crip/                     # Subprojeto: Lock/Unlock Multi-threaded (Ransomware Sim)
│       ├── main.cpp              # Entrada do motor de criptografia / descriptografia
│       ├── config.h              # Configurações de senha fixa e escopo de atuação
│       ├── crypto_service.cpp/.h # Wrappers da API BCrypt do Windows (SHA-256, RSA, AES-256)
│       ├── disk_service.cpp/.h   # Iteradores de diretório e identificadores de unidades (Drives)
│       ├── file_service.cpp/.h   # Algoritmo de criptografia de arquivos e estrutura do cabeçalho
│       ├── worker_pool.cpp/.h    # Pool de threads trabalhadoras concorrentes
│       └── build.ps1             # PowerShell script para compilar o locker ou unlocker
│
├── public/                       # Frontend web estático do servidor de upload
│   └── index.html                # Painel de upload e download de arquivos exfiltrados
│
├── uploads/                      # Pasta onde os ZIPs enviados pelos alvos são salvos
├── .env                          # Variáveis de ambiente (Chaves Pix, porta do servidor, etc.)
├── .gitignore                    # Regras de exclusão do Git
├── package.json                  # Dependências e scripts do servidor Node.js
└── server.js                     # Servidor Express.js (Recebe arquivos e gera imagens Pix)
```

---

## ⚙️ Componentes em Detalhes

### 1. Servidor de Exfiltração (Node.js)
O servidor atua como painel central para o atacante/administrador.
*   **Upload de Arquivos**: Rotas `POST /profile` (upload único), `POST /photos/upload` (múltiplos) e `POST /cool-profile` que salvam os arquivos diretamente no diretório `uploads/` através do middleware `multer`.
*   **Listagem e Download**: Endpoints `GET /files` e `GET /download/:filename` facilitam o resgate de ZIPs exfiltrados de computadores alvo.
*   **Gerador Pix (EMV Co)**: Rota `GET /qrCode` que lê variáveis do `.env` (`PIX_KEY`, `PIX_NAME`, `PIX_CITY`) para estruturar uma string de pagamento Pix padronizada, calcular o CRC16 CCITT e gerar um QR Code em formato PNG bufferizado.

### 2. Troll Terror (`terror.exe`)
Software simulador de trollagem e intimidação visual. Ao ser executado:
1.  **Bloqueio Total de Entrada**: Instala ganchos de sistema em baixo nível (`WH_KEYBOARD_LL`, `WH_MOUSE_LL`), trava o input de teclado com `BlockInput(TRUE)` e confina o mouse em um espaço de 1x1 pixel com `ClipCursor`.
    *   *Mecanismo de Fuga*: Ao pressionar a tecla `INSERT`, o programa interrompe as threads de loop, remove os ganchos de entrada, cancela o desligamento do sistema e limpa as configurações temporárias.
2.  **Persistência Agressiva**:
    *   Substitui/injeta o executável no registro em `HKCU\Software\Microsoft\Windows NT\CurrentVersion\Winlogon` sob a chave `Shell` (inicializando instantaneamente junto com a interface do usuário).
    *   Cria um atalho com nome randômico na chave `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` e define `StartupDelayInMSec` em `0` para anular o atraso de inicialização do Windows.
3.  **Trollagem Visual e Sonora**:
    *   Minimiza todas as janelas do Desktop.
    *   Altera o papel de parede para uma imagem sólida vermelha instantaneamente e, em segundo plano, utiliza um script PowerShell oculto para baixar uma imagem externa.
    *   Sintetiza um sinal senoidal de $1000\text{ Hz}$ na memória RAM e inicia um loop sonoro infinito de beeps com `PlaySoundW`.
    *   Gera um spawner contínuo de janelas flutuantes aleatórias na tela com mensagens de ameaça em vermelho.
    *   Cria uma tela sobreposta contendo um efeito de "derretimento" (dripping columns) de pixels misturado com ondas e blocos horizontais simulando glitches severos na placa de vídeo.
4.  **Integração Web (QR Code)**:
    *   Inicia uma conexão em segundo plano via `WinHTTP` apontando para o servidor configurado. Baixa o QR Code gerado pelo backend e desenha um card com GDI+ no topo da tela, solicitando que a vítima leia o código.
5.  **Desligamento Forçado**: Agenda um reinício forçado no Windows em 120 segundos utilizando a chamada silenciosa `shutdown.exe /r /t 120 /f`.

### 3. Coletor de Tokens Discord (`collector.exe` & `discord_launcher.exe`)
Lógica silenciosa de exfiltração de credenciais focada em aplicativos Discord.
*   **Descriptografia DPAPI**: Localiza a chave mestra criptografada no arquivo JSON `Local State` de múltiplos clientes Discord (Discord clássico, Canary, PTB, Development) e a descriptografa usando a API de Proteção de Dados do Windows (`CryptUnprotectData`).
*   **Varredura em Bancos LevelDB**: Inicializa sessões AES-256-GCM nativas com a chave mestra para descriptografar os tokens salvos nos arquivos `.ldb` e `.log` do diretório `leveldb`. Também suporta a varredura de tokens legados em formato texto claro ou strings codificadas em UTF-16LE.
*   **Exfiltração de Metadados**: Adquire dados locais do usuário, nome do host, versão do sistema operacional e faz um request HTTP para resgatar o endereço de IP público e geolocalização aproximada do alvo.
*   **Geração de ZIP Multipart**: Compacta todos os resultados em um arquivo ZIP gerado em memória, adiciona o executável auxiliar `discord_launcher.exe` extraído de seus recursos binários embutidos e envia tudo via requisição multipart WinHTTP para o backend. O arquivo temporário local é apagado após o upload bem-sucedido.
*   **Injeção Automatizada de Tokens (`discord_launcher.exe`)**:
    *   Utilitário utilizado pelo atacante para carregar os tokens extraídos de `discord.txt`.
    *   Abre uma sessão limpa do Microsoft Edge navegando até `discord.com`, aguarda carregar, envia um comando `F12` virtual para abrir a ferramenta de desenvolvedor (DevTools) e digita via simulação de teclado (`SendInput` caractere por caractere) um script JavaScript que injeta o token selecionado diretamente no `localStorage` da página através de um iframe aninhado, atualizando a página em seguida para logar na conta da vítima.

### 4. Crip Locker (`crip.exe` / Ransomware Simulator)
Motor multi-threaded demonstrativo para criptografia em lote de arquivos locais.
*   **Algoritmo Híbrido**: 
    *   Cria um cabeçalho customizado (`UnencryptedHeader`) estruturado com assinatura mágica `"LOCKgm2373"`, modo de criptografia (Rápido - encripta apenas 1 KB, ou Completo), vetor de inicialização (IV), hash SHA-256 para verificação da chave, tamanho do container RSA e campo para a chave AES criptografada por RSA-2048 de forma assimétrica.
    *   Criptografa o arquivo utilizando AES-256 no modo CBC.
    *   Modo alternativo baseado em senha simétrica onde o hash SHA-256 da senha é derivado com a função de derivação de chaves da API BCrypt.
*   **Thread Pool Concorrente**: Instancia threads com base na concorrência de hardware (`std::thread::hardware_concurrency`) para ler, processar e reescrever arquivos concorrentemente com fila sincronizada por variáveis de condição, otimizando o throughput em discos SSD e HDDs.
*   **Filtro e Segurança**: Possui lista de exclusão integrada para caminhos contendo pastas essenciais do sistema (ex: `Windows`, `Program Files`, `System Volume Information`, `AppData`) e extensões críticas de executáveis/bibliotecas (ex: `.exe`, `.dll`, `.sys`, `.ini`, `.lnk`) a fim de evitar corromper o funcionamento básico do Windows.
*   **Modos de Alvo**: 
    1.  *Todas as unidades*: Criptografa todas as partições disponíveis no PC.
    2.  *Diretório Local*: Afeta apenas a pasta de execução e subpastas.
    3.  *Partição de Origem*: Criptografa a unidade lógica onde o executável se encontra.
    4.  *Apenas Unidades Externas*: Limita-se a dispositivos USB e HDDs removíveis (`DRIVE_REMOVABLE`).

---

## 🛠️ Como Compilar e Executar

### Compilação dos Binários C++

**Pré-requisitos**:
*   Visual Studio 2022+ com C++ Desktop Development Toolset.
*   Compilador MSVC (`cl.exe`) e MSBuild/vcvars64 no PATH.

#### Método 1: Via scripts individuais (.bat)
Abra o console de ferramentas nativas do Visual Studio (x64 Native Tools Command Prompt) e execute:

*   **Para compilar a suíte Troll (terror.exe)**:
    ```cmd
    cd collector_discord
    build.bat
    ```
*   **Para compilar o Coletor com Launcher Embutido**:
    ```cmd
    cd collector_discord/collector
    build.bat https://seu-servidor-url.com/profile
    ```

#### Método 2: Automação via PowerShell
Execute o script agregador na pasta `compiller` ou `crip`:
```powershell
# Compilar collector, launcher e terror
cd collector_discord/compiller
powershell -ExecutionPolicy Bypass -File build.ps1

# Compilar motor de criptografia (crip)
cd ../crip
powershell -ExecutionPolicy Bypass -File build.ps1
```

---

## 🖥️ Inicialização do Servidor (Backend/Frontend)

1.  Acesse o diretório raiz do projeto.
2.  Instale as dependências listadas no `package.json`:
    ```bash
    npm install
    ```
3.  Configure o arquivo `.env` com os dados Pix e a porta de rede:
    ```env
    PORT=3000
    PIX_KEY=seu-email-ou-telefone@pix.com
    PIX_NAME=Seu Nome
    PIX_CITY=Sua Cidade
    PIX_PAYLOAD=
    ```
4.  Inicie o servidor local:
    ```bash
    node server.js
    ```
5.  Acesse `http://localhost:3000` no seu navegador para verificar o painel visual e obter o histórico de exfiltrações.

---

## ⚠️ Isenção de Responsabilidade (Disclaimer)

> **ATENÇÃO**: Este projeto foi desenvolvido estritamente para **Fins Educacionais e de Pesquisa**. 
> O uso destas ferramentas para infectar, coletar dados ou causar danos a sistemas sem o consentimento prévio e formal por escrito do proprietário é **estritamente proibido e constitui crime cibernético** sob as leis brasileiras (Lei Carolina Dieckmann, Código Penal) e internacionais.
> O autor e os contribuidores não assumem qualquer responsabilidade pelo uso indevido, danos causados ou vazamento de dados decorrentes da execução deste código. Use sob seu próprio risco em ambientes de laboratório isolados.
