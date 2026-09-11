<#
.SYNOPSIS
    Importiert AD-Benutzer aus einer CSV-Datei.
.NOTES
    Voraussetzung: RSAT-AD-Tools müssen installiert sein und das Skript muss mit 
    Domänen-Admin-Rechten ausgeführt werden.
#>

# Pfad zur CSV-Datei definieren
$csvPath = ".\users.csv"

# Prüfen, ob die CSV-Datei existiert
if (-not (Test-Path -Path $csvPath)) {
    Write-Error "Die CSV-Datei '$csvPath' wurde nicht gefunden!" -ErrorAction Stop
}

# Standard-Domain-Suffix dynamisch ermitteln (z. B. company.local)
$domainName = (Get-ADDomain).DNSRoot

# CSV-Datei importieren (Semikolon als Trennzeichen)
$users = Import-Csv -Path $csvPath -Delimiter ";"

foreach ($user in $users) {
    $samName = $user.SamAccountName
    $upn = "$samName@$domainName"
    $ou = $user.OU

    # Prüfen, ob der Benutzer bereits im Active Directory existiert
    if (Get-ADUser -Filter "SamAccountName -eq '$samName'") {
        Write-Warning "Der Benutzer '$samName' existiert bereits im AD. Übersprungen."
    }
    else {
        # Prüfen, ob die Ziel-OU existiert
        if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ou'")) {
            Write-Warning "Die OU '$ou' für Benutzer '$samName' existiert nicht! Übersprungen."
            continue
        }

        # Passwort in Sicheren String umwandeln
        $securePassword = ConvertTo-SecureString $user.Password -AsPlainText -Force

        # Parameter-Hashtable für den Befehl zusammenstellen
        $splatting = @{
            SamAccountName        = $samName
            UserPrincipalName     = $upn
            GivenName             = $user.FirstName
            Surname               = $user.LastName
            Name                  = "$($user.FirstName) $($user.LastName)"
            DisplayName           = "$($user.LastName), $($user.FirstName)"
            Department            = $user.Department
            Title                 = $user.Title
            Path                  = $ou
            AccountPassword       = $securePassword
            Enabled               = $true
            ChangePasswordAtLogon = $true  # Erzwingt Passwortwechsel bei erster Anmeldung
        }

        try {
            # AD-Benutzer anlegen
            New-ADUser @splatting
            Write-Host "Erfolgreich angelegt: $samName ($($user.FirstName) $($user.LastName))" -ForegroundColor Green
        }
        catch {
            Write-Error "Fehler beim Anlegen von '$samName': $_"
        }
    }
}