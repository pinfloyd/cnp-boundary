param(
    [string]$AuthorityBase = "https://admit.ai-admissibility.com"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [AllowEmptyString()][Parameter(Mandatory = $true)][string]$Content
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and (-not (Test-Path -LiteralPath $dir))) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

function Invoke-HttpCapture {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$Body,
        [Parameter(Mandatory = $true)][string]$ResponsePath,
        [Parameter(Mandatory = $true)][string]$StatusPath
    )
    $code = ""
    $content = ""
    try {
        $r = Invoke-WebRequest -Uri $Url -Method POST -ContentType "application/json" -Body $Body -UseBasicParsing -Headers @{ "Accept" = "application/json" }
        $code = [string]([int]$r.StatusCode)
        $content = [string]$r.Content
    }
    catch {
        $ex = $_.Exception
        if ($null -ne $ex.Response) {
            $code = [string]([int]$ex.Response.StatusCode)
            try {
                $stream = $ex.Response.GetResponseStream()
                $reader = [System.IO.StreamReader]::new($stream)
                try { $content = $reader.ReadToEnd() } finally { $reader.Dispose(); $stream.Dispose() }
            }
            catch {
                $content = ""
            }
        } else {
            throw
        }
    }
    Write-Utf8NoBom -Path $ResponsePath -Content ($content + [Environment]::NewLine)
    Write-Utf8NoBom -Path $StatusPath -Content ("HTTP_STATUS=$code" + [Environment]::NewLine)
    return [pscustomobject]@{ Code = $code; Content = $content }
}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Out = Join-Path $Here ("out_" + (Get-Date).ToString("yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Force -Path $Out | Out-Null

$PubkeyUrl = "$AuthorityBase/pubkey"
$AdmitUrl = "$AuthorityBase/admit"

$Proof1Intent = Join-Path $Here "proof1_proven_intent.json"
$Proof1Response = Join-Path $Out "proof1_response.json"
$Proof1Status = Join-Path $Out "proof1_status.txt"

$Proof2Request = Join-Path $Out "proof2_deny_request.json"
$Proof2Response = Join-Path $Out "proof2_deny_response.txt"
$Proof2Status = Join-Path $Out "proof2_deny_status.txt"

$Proof3Request = Join-Path $Out "proof3_fail_request.json"
$Proof3Response = Join-Path $Out "proof3_fail_response.txt"
$Proof3Status = Join-Path $Out "proof3_fail_status.txt"

$PubkeyJson = Join-Path $Out "pubkey.json"
$Proof1VerifyStatus = Join-Path $Out "proof1_verify_status.txt"
$Proof1VerifyStdout = Join-Path $Out "proof1_verify_stdout.txt"
$Proof1VerifyStderr = Join-Path $Out "proof1_verify_stderr.txt"

$VerifyExe = $env:AB_VERIFY_EXE

Write-Output "RAW_LOG"
Write-Output "OUT=$Out"
Write-Output "AUTHORITY_BASE=$AuthorityBase"

$pub = Invoke-WebRequest -Uri $PubkeyUrl -Method GET -UseBasicParsing -Headers @{ "Accept" = "application/json" }
Write-Utf8NoBom -Path $PubkeyJson -Content ($pub.Content + [Environment]::NewLine)
Write-Output "PUBKEY_HTTP=$($pub.StatusCode)"

$proof1Body = Get-Content -LiteralPath $Proof1Intent -Raw -Encoding utf8
$r1 = Invoke-WebRequest -Uri $AdmitUrl -Method POST -ContentType "application/json" -Body $proof1Body -UseBasicParsing -Headers @{ "Accept" = "application/json" }
Write-Utf8NoBom -Path $Proof1Response -Content ($r1.Content + [Environment]::NewLine)
Write-Utf8NoBom -Path $Proof1Status -Content ("HTTP_STATUS=" + [string]([int]$r1.StatusCode) + [Environment]::NewLine)
Write-Output "PROOF1_HTTP=$([int]$r1.StatusCode)"

if (-not [string]::IsNullOrWhiteSpace($VerifyExe) -and (Test-Path -LiteralPath $VerifyExe -PathType Leaf)) {
    $stderrTmp = New-TemporaryFile
    try {
        $stdout = (& $VerifyExe 2> $stderrTmp.FullName | Out-String)
        $exitCode = $LASTEXITCODE
        if ($null -eq $stdout) { $stdout = "" }
        Write-Utf8NoBom -Path $Proof1VerifyStdout -Content $stdout

        $stderr = ""
        if (Test-Path -LiteralPath $stderrTmp.FullName) {
            $tmp = Get-Content -LiteralPath $stderrTmp.FullName -Raw -ErrorAction SilentlyContinue
            if ($null -ne $tmp) { $stderr = $tmp }
        }
        Write-Utf8NoBom -Path $Proof1VerifyStderr -Content $stderr
        Write-Utf8NoBom -Path $Proof1VerifyStatus -Content ("VERIFY_EXIT_CODE=$exitCode" + [Environment]::NewLine)

        if ($stdout -match "VERIFICATION_OK") {
            Write-Output "PROOF1_VERIFY=VERIFICATION_OK"
        } else {
            Write-Output "PROOF1_VERIFY=RAN_NO_OK"
        }
    }
    finally {
        if (Test-Path -LiteralPath $stderrTmp.FullName) {
            Remove-Item -LiteralPath $stderrTmp.FullName -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Utf8NoBom -Path $Proof1VerifyStatus -Content ("VERIFY_SKIPPED=TRUE" + [Environment]::NewLine)
    Write-Utf8NoBom -Path $Proof1VerifyStdout -Content ""
    Write-Utf8NoBom -Path $Proof1VerifyStderr -Content ""
    Write-Output "PROOF1_VERIFY=SKIPPED_NO_AB_VERIFY_EXE"
}

$denyLine = "OPENAI_API_KEY=abcd"
$denyHash = [System.BitConverter]::ToString(
    [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($denyLine))
).Replace("-","").ToLowerInvariant()

$proof2Body = @"
{
"repo":"demo",
"ref":"main",
"policy_id":"ai-secrets-v1",
"schema":"intent-v1",
"added_lines":"$denyLine",
"added_lines_sha256":"$denyHash"
}
"@
Write-Utf8NoBom -Path $Proof2Request -Content $proof2Body
$p2 = Invoke-HttpCapture -Url $AdmitUrl -Body $proof2Body -ResponsePath $Proof2Response -StatusPath $Proof2Status
Write-Output "PROOF2_HTTP=$($p2.Code)"

$proof3Body = "{}"
Write-Utf8NoBom -Path $Proof3Request -Content $proof3Body
$p3 = Invoke-HttpCapture -Url $AdmitUrl -Body $proof3Body -ResponsePath $Proof3Response -StatusPath $Proof3Status
Write-Output "PROOF3_HTTP=$($p3.Code)"

Write-Output "DONE"