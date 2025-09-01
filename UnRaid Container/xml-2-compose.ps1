param(
    [Parameter(Mandatory = $true)]
    [string]$InputFolder
)

# Get all XML-Files from the Base directory
$xmlFiles = Get-ChildItem -Path $InputFolder -Filter *.xml

foreach ($file in $xmlFiles) {
    Write-Host "Verarbeite $($file.Name)..."

    [xml]$xml = Get-Content $file.FullName

    # Basic-Infos
    $serviceName  = $xml.Container.Name
    $image        = $xml.Container.Repository
    $network      = $xml.Container.Network
    $privileged   = $xml.Container.Privileged
    $extraParams  = $xml.Container.ExtraParams

    # Compose basic framework
    $compose = @"
version: "3.9"
services:
  ${serviceName}:
    image: $image
    container_name: $serviceName
    networks:
      - $network
"@

    # add Ports
    $ports = @()
    foreach ($cfg in $xml.Container.Config) {
        if ($cfg.Type -eq "Port") {
            $portHost = $cfg.'#text'
            $portContainer = $cfg.Target
            $ports += "      - `"$portHost`:$portContainer`""
        }
    }
    if ($ports.Count -gt 0) {
        $compose += "`n    ports:`n" + ($ports -join "`n")
    }

    # add Volumes
    $volumes = @()
    foreach ($cfg in $xml.Container.Config) {
        if ($cfg.Type -eq "Path") {
            $hostPath = $cfg.'#text'
            $containerPath = $cfg.Target
            $volumes += "      - ${hostPath}:${containerPath}"
        }
    }
    if ($volumes.Count -gt 0) {
        $compose += "`n    volumes:`n" + ($volumes -join "`n")
    }

    # ExtraParams -> DNS convert (simple Approache)
    if ($extraParams -match "--dns=(\S+)") {
        $dns = $matches[1]
        $compose += "`n    dns:`n      - $dns"
    }

    # Add Restart Policy
    $compose += "`n    restart: unless-stopped"

    # Define Networks
    $compose += @"

networks:
  ${network}:
    external: true
"@

    # Output-Datei: docker-compose-{ContainerName}.yml
    $outputFile = Join-Path $InputFolder "docker-compose-$serviceName.yml"
    Set-Content -Path $outputFile -Value $compose -Encoding UTF8

    Write-Host "-> docker-compose for '$serviceName' created: $outputFile"
}

Write-Host "Ready! All XML-Files got converted."
