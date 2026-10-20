$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

$config = $configuration | ConvertFrom-Json

# ============================================================
# LACOE Data Exchange API
# ============================================================

$BaseUrl = $config.hostname
$ApiKey  = $config.api_key

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
# Retrieve Prime Job Attributes
# ============================================================

$EmployeePrimeJobAttributes = Invoke-LacoeGet `
    -Endpoint "/api/v1/EmployeePrimeJobAttributes" `
    -AccessToken $AccessToken

Write-Information "Prime job records: $($EmployeePrimeJobAttributes.Count)"

# ============================================================
# Return Unique Work Locations
# ============================================================

$UniqueWorkLocations = $EmployeePrimeJobAttributes |
    Select-Object `
        @{Name="ExternalID"; Expression={$_.wrkLctnCd}},
        @{Name="DisplayName"; Expression={$_.wrkLctnLongDd}} `
    -Unique

foreach ($location in $UniqueWorkLocations) {
    Write-Output ($location | ConvertTo-Json -Compress)
}