$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$runRoot = Join-Path $projectRoot 'runs\physical_closure_v92_formal_417_20260828'
$logRoot = Join-Path $runRoot 'logs'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$logPath = Join-Path $logRoot 'full_regression_v92.log'
$recordPath = Join-Path $logRoot 'full_regression_v92.json'
if ((Test-Path -LiteralPath $logPath) -or (Test-Path -LiteralPath $recordPath)) {
    throw 'immutable v92 full-regression artifacts already exist'
}
$started = (Get-Date).ToUniversalTime()
$stopwatch = [Diagnostics.Stopwatch]::StartNew()
& julia --project=$projectRoot (Join-Path $projectRoot 'test\runtests.jl') 2>&1 |
    Tee-Object -FilePath $logPath
$exitCode = $LASTEXITCODE
$stopwatch.Stop()
$ended = (Get-Date).ToUniversalTime()
$record = [ordered]@{
    schema_version = '1.0.0'
    protocol_id = 'fusionconceptai-v92-hifi-closure-20260828'
    command = 'julia --project=. test/runtests.jl'
    started_at_utc = $started.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    ended_at_utc = $ended.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    wall_seconds = $stopwatch.Elapsed.TotalSeconds
    exit_code = $exitCode
    status = if ($exitCode -eq 0) { 'pass' } else { 'fail' }
    log_path = 'runs/physical_closure_v92_formal_417_20260828/logs/full_regression_v92.log'
    log_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $logPath).Hash.ToLowerInvariant()
    log_bytes = (Get-Item -LiteralPath $logPath).Length
}
$temporary = "$recordPath.tmp"
$record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temporary -Encoding utf8
Move-Item -LiteralPath $temporary -Destination $recordPath
exit $exitCode
