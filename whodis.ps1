function whodis {
    param(
        [Parameter(Mandatory = $true)]
        [array]$targets
    )

    # Regex patterns for IP detection 
    $ipv6 = '^((?:[0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4}|' +
            '([0-9A-Fa-f]{1,4}:){1,7}:|' +
            '([0-9A-Fa-f]{1,4}:){1,6}:[0-9A-Fa-f]{1,4}|' +
            '([0-9A-Fa-f]{1,4}:){1,5}(:[0-9A-Fa-f]{1,4}){1,2}|' +
            '([0-9A-Fa-f]{1,4}:){1,4}(:[0-9A-Fa-f]{1,4}){1,3}|' +
            '([0-9A-Fa-f]{1,4}:){1,3}(:[0-9A-Fa-f]{1,4}){1,4}|' +
            '([0-9A-Fa-f]{1,4}:){1,2}(:[0-9A-Fa-f]{1,4}){1,5}|' +
            '[0-9A-Fa-f]{1,4}:((:[0-9A-Fa-f]{1,4}){1,6})|' +
            ':((:[0-9A-Fa-f]{1,4}){1,7}|:))$'

    $ipv4 = '^(?:(?:25[0-4]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}' +
            '(?:25[0-4]|2[0-4]\d|1\d{2}|[1-9]?\d)$'

    # Resolve hostnames to IPs
    $expandedTargets = foreach ($t in $targets) {
        $t = "$t".Trim()
        $isIP = ($t -match $ipv4) -or ($t -match $ipv6)

        if ($isIP) {
            $t
            continue
        }

        try {
            $resolved = [System.Net.Dns]::GetHostAddresses($t) |
                ForEach-Object { $_.IPAddressToString }

            Write-Host "  ℹ Resolved " -ForegroundColor DarkGray -NoNewline
            Write-Host "$t" -ForegroundColor White -NoNewline
            Write-Host " → $($resolved -join ', ')" -ForegroundColor DarkGray

            $resolved
        }
        catch {
            Write-Host "  ✖ Couldn't resolve DNS for: $t" -ForegroundColor Red
        }
    }

    # De-duplicate resolved targets
    $targets = $expandedTargets |
        Where-Object { $_ } |
        Select-Object -Unique

    # Query ARIN for each IP
    $cooldownCt = 0
    $maxRetries  = 3
    $fails       = @()

    foreach ($ip in $targets) {
        $success        = $false
        $failedAttempts = 0

        while (-not $success -and ($failedAttempts -lt $maxRetries)) {
            try {
                $arin = Invoke-RestMethod "https://whois.arin.net/rest/ip/$ip.json"
                $net  = $arin.net
                $org  = $net.orgRef

                $orgDetails = Invoke-RestMethod "https://whois.arin.net/rest/org/$($org.'@handle').json"
                $orgData    = $orgDetails.org

                # streetAddress.line can be a single object OR an array
                $rawLine = $orgData.streetAddress.line
                if ($rawLine -is [array]) {
                    $addr = ($rawLine | ForEach-Object { $_.'$' }) -join ", "
                }
                else {
                    $addr = $rawLine.'$'
                }

                $city    = $orgData.city.'$'
                $state   = $orgData.'iso3166-2'.'$'
                $postal  = $orgData.postalCode.'$'
                $country = $orgData.'iso3166-1'.code2.'$'

                # Filter out blanks to avoid ugly trailing commas
                $fullAddr = @($addr, $city, $state, $postal) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
                $fullAddr = $fullAddr -join ", "

                # Build display values
                $start = $net.netBlocks.netBlock.startAddress.'$'
                $end   = $net.netBlocks.netBlock.endAddress.'$'
                $cidr  = $net.netBlocks.netBlock.cidrLength.'$'

                $header = "WHOIS $ip"
                $rows = @(
                    @{ Label = "Subnet";  Value = "$start/$cidr ($start - $end)" }
                    @{ Label = "Name";    Value = "$($net.name.'$')" }
                    @{ Label = "Handle";  Value = "$($net.handle.'$')" }
                    @{ Label = "Org";     Value = "$($org.'@name')" }
                    @{ Label = "Address"; Value = "$fullAddr" }
                    @{ Label = "Country"; Value = "$country" }
                )

                # Calculate dynamic box width
                $labelWidth  = 8
                $contentLens = @($header.Length)
                foreach ($row in $rows) {
                    $contentLens += $row.Label.Length + ($labelWidth - $row.Label.Length) + $row.Value.Length
                }
                $innerWidth = ($contentLens | Measure-Object -Maximum).Maximum + 2
                if ($innerWidth -lt 20) { $innerWidth = 20 }

                # Draw the box
                $hBar = '─' * ($innerWidth + 2)

                Write-Host ""
                Write-Host "  ┌$hBar┐" -ForegroundColor DarkCyan

                $headerPad = $innerWidth - $header.Length
                Write-Host "  │ " -ForegroundColor DarkCyan -NoNewline
                Write-Host " $header" -ForegroundColor Cyan -NoNewline
                Write-Host "$(' ' * $headerPad)│" -ForegroundColor DarkCyan

                Write-Host "  ├$hBar┤" -ForegroundColor DarkCyan

                foreach ($row in $rows) {
                    $label    = $row.Label
                    $value    = $row.Value
                    $padLabel = ' ' * ($labelWidth - $label.Length)
                    $lineLen  = $labelWidth + $value.Length
                    $padRight = ' ' * ($innerWidth - $lineLen)

                    Write-Host "  │ " -ForegroundColor DarkCyan -NoNewline
                    Write-Host " $label$padLabel" -ForegroundColor Yellow -NoNewline
                    Write-Host "$value" -ForegroundColor White -NoNewline
                    Write-Host "$padRight│" -ForegroundColor DarkCyan
                }

                Write-Host "  └$hBar┘" -ForegroundColor DarkCyan
                Write-Host ""

                $success = $true
            }
            catch {
                $failedAttempts++
                if ($failedAttempts -ge 3) {
                    Write-Host "Looking up $ip failed... ARIN doesnt have it?" -ForegroundColor Red
                    $fails += $ip
                }
                Start-Sleep 3
            }

            if ($cooldownCt -gt 9) { $time = 1200 } else { $time = 250 }
            Start-Sleep -Milliseconds $time
            $cooldownCt++
        }
    }

    if ($fails) {
        Write-Host ""
        Write-Host "  ✖ whois failed to lookup: $($fails -join ', ') " -ForegroundColor Red
    }
}
