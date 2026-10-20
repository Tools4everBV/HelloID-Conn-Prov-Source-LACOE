$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

$config = $configuration | convertfrom-json

# ============================================================
# LACOE Data Exchange API
# ============================================================

$BaseUrl = $config.hostname

# Prefer retrieving this securely rather than hard-coding it.
$ApiKey = $config.api_key

# ============================================================
# Functions
# ============================================================

function ConvertTo-NameCase {
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $Name
    }

    # Normalize excess whitespace
    $Name = ($Name.Trim() -replace '\s+', ' ')

    # Suffixes that should retain specific capitalization
    $suffixes = @{
        'jr'   = 'Jr.'
        'jr.'  = 'Jr.'
        'sr'   = 'Sr.'
        'sr.'  = 'Sr.'
        'ii'   = 'II'
        'iii'  = 'III'
        'iv'   = 'IV'
        'v'    = 'V'
        'vi'   = 'VI'
        'vii'  = 'VII'
        'viii' = 'VIII'
        'ix'   = 'IX'
        'x'    = 'X'
    }

    function Format-NamePart {
        param (
            [string]$Part
        )

        if ([string]::IsNullOrEmpty($Part)) {
            return $Part
        }

        $lower = $Part.ToLowerInvariant()

        # Known suffix
        if ($suffixes.ContainsKey($lower)) {
            return $suffixes[$lower]
        }

        # Handle hyphenated names recursively:
        # Smith-Jones -> Smith-Jones
        if ($Part.Contains('-')) {
            return (($Part -split '-') | ForEach-Object {
                Format-NamePart $_
            }) -join '-'
        }

        # Handle apostrophes:
        # O'BRIEN -> O'Brien
        # D'ANGELO -> D'Angelo
        if ($Part.Contains("'")) {
            return (($Part -split "'") | ForEach-Object {
                Format-NamePart $_
            }) -join "'"
        }

        # Normal capitalization first
        $formatted = $lower.Substring(0, 1).ToUpperInvariant()

        if ($lower.Length -gt 1) {
            $formatted += $lower.Substring(1)
        }

        # Mc prefix:
        # mcdonald -> McDonald
        # mccarthy -> McCarthy
        if ($lower.StartsWith('mc') -and $lower.Length -gt 2) {
            return 'Mc' +
                $lower.Substring(2, 1).ToUpperInvariant() +
                $lower.Substring(3)
        }

        # Mac prefix:
        # macdonald -> MacDonald
        #
        # Be aware that not every name beginning with "Mac" conventionally
        # capitalizes the next letter. Remove this block if that distinction
        # matters for your data.
        if ($lower.StartsWith('mac') -and $lower.Length -gt 3) {
            return 'Mac' +
                $lower.Substring(3, 1).ToUpperInvariant() +
                $lower.Substring(4)
        }

        return $formatted
    }

    $parts = $Name -split ' '

    $result = foreach ($part in $parts) {
        Format-NamePart $part
    }

    return $result -join ' '
}

# ============================================================
# Authentication
# ============================================================

function Get-LacoeAccessToken {

    param (
        [Parameter(Mandatory)]
        [string]$ApiKey
    )

    $TokenUri = "$BaseUrl/api/v1/token"

    $Body = @{
        keyGuid = $ApiKey
    } | ConvertTo-Json

    try {

        $Response = Invoke-RestMethod `
            -Uri $TokenUri `
            -Method Post `
            -ContentType "application/json" `
            -Body $Body `
            -ErrorAction Stop

        if (-not $Response.token) {
            throw "Authentication succeeded, but no token was returned."
        }

        return $Response.token

    }
    catch {

        Write-Error "Unable to authenticate to the LACOE Data Exchange API: $($_.Exception.Message)"
        throw

    }
}

# ============================================================
# Generic GET Function
# ============================================================

function Invoke-LacoeGet {

    param (
        [Parameter(Mandatory)]
        [string]$Endpoint,

        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $Uri = "$BaseUrl$Endpoint"

    $Headers = @{
        Authorization = "Bearer $AccessToken"
        Accept        = "application/json"
    }

    try {

        Invoke-RestMethod `
            -Uri $Uri `
            -Method Get `
            -Headers $Headers `
            -ErrorAction Stop

    }
    catch {

        Write-Error "GET request failed for '$Endpoint': $($_.Exception.Message)"
        throw

    }
}

# ============================================================
# Connect
# ============================================================

$AccessToken = Get-LacoeAccessToken -ApiKey $ApiKey

# ============================================================
# Retrieve Employee Data
# ============================================================

$EmployeeDemographics = Invoke-LacoeGet `
    -Endpoint "/api/v2/EmployeeDemographics" `
    -AccessToken $AccessToken 

$ActiveEmployees = $EmployeeDemographics.where({$_.employmentStatus -ne "Q"}) 

$EmployeeActivePositions = Invoke-LacoeGet `
    -Endpoint "/api/v1/EmployeeActivePositions" `
    -AccessToken $AccessToken 

$EmployeePrimeJobAttributes = Invoke-LacoeGet `
    -Endpoint "/api/v1/EmployeePrimeJobAttributes" `
    -AccessToken $AccessToken

# ============================================================
# Example Output
# ============================================================

Write-Information "Demographic records: $($EmployeeDemographics.Count)"
Write-Information "Active employees: $($ActiveEmployees.Count)"
Write-Information "Active position records: $($EmployeeActivePositions.Count)"
Write-Information "Prime job records: $($EmployeePrimeJobAttributes.Count)"

foreach ($employee in $ActiveEmployees) {
    # Create the person object and set specific properties
    $person = @{}
    $person.ExternalId = $employee.employeeId
    $person.DisplayName = ConvertTo-NameCase "$($employee.emplFirstNm) $($employee.emplLastNm) ($($employee.employeeId))"
    $person.FirstName = ConvertTo-NameCase "$($employee.emplFirstNm)"
    $person.LastName = ConvertTo-NameCase "$($employee.emplLastNm)"
    $person.PreferredFirstName = ConvertTo-NameCase "$($employee.preferedFirstName)"
    $person.PreferredLastName = ConvertTo-NameCase "$($employee.preferedLastName)"

    # Load the rest of the properties from the employee object
    foreach($prop in $employee.PSObject.properties)
    {
        if(@("RowError","RowState","Table","HasErrors","ItemArray") -contains $prop.Name) { continue; }
        $person[$prop.Name] = "$($prop.Value)";
    }
    
    # Find the employee's job attributes record and load it into their person object. First record only.
    $person_jobAttributes = @(
        $EmployeePrimeJobAttributes.Where({
            $_.employeeId -eq $employee.employeeId
        })
    )[0]

    $person_primePosition = @(
        $EmployeeActivePositions.Where({
            $_.posnId -eq $person_jobAttributes.positionNo -and
            $_.employeeId -eq $employee.employeeId
        })
    )[0]
    
    # Create the contract collection
    $person["Contracts"] = [System.Collections.ArrayList]@();

    # Create the contract object and set specific properties
    $contract = @{};
    $contract.ExternalId = $person_jobAttributes.employeeId+"_"+$person_jobAttributes.positionNo

    foreach($prop in $person_jobAttributes.PSObject.properties)
    {
        if(@("RowError","RowState","Table","HasErrors","ItemArray") -contains $prop.Name) { continue; }
        $contract[$prop.Name] = "$($prop.Value)";
    }
    foreach($prop in $person_primePosition.PSObject.properties)
    {
        if(@("RowError","RowState","Table","HasErrors","ItemArray") -contains $prop.Name) { continue; }
        $contract[$prop.Name] = "$($prop.Value)";
    }

    # Add the contract to the person
    [void]$person.Contracts.Add($contract);

    Write-Output ($person | ConvertTo-Json -Depth 50);
}

Write-Information "Finished Processing Persons"