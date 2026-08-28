param(
    [string]$Campaign = (Join-Path $PSScriptRoot '..\runs\multitopology_campaign_v90_100000_20260827'),
    [int]$BatchCount = 10,
    [string]$Julia = 'julia'
)

$ErrorActionPreference = 'Stop'
$campaignPath = [System.IO.Path]::GetFullPath($Campaign)
if (-not (Test-Path -LiteralPath (Join-Path $campaignPath 'campaign_v90.json') -PathType Leaf)) {
    throw "Campaign specification not found: $campaignPath"
}

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location -LiteralPath $projectRoot
try {
    for ($batchId = 1; $batchId -le $BatchCount; $batchId++) {
        $summaryPath = Join-Path $campaignPath ("results_batch_{0:D2}.jsonl.summary.json" -f $batchId)
        if (Test-Path -LiteralPath $summaryPath -PathType Leaf) {
            Write-Host "batch $batchId already complete"
            continue
        }
        & $Julia '--startup-file=no' '--project=.' (Join-Path $PSScriptRoot 'run_v90_campaign_worker.jl') "--campaign=$campaignPath" "--batch=$batchId" '--resume=true'
        if ($LASTEXITCODE -ne 0) {
            throw "v90 worker failed for batch $batchId with exit code $LASTEXITCODE"
        }
    }
} finally {
    Pop-Location
}
