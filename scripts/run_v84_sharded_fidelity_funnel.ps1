param(
    [int]$PhysicalVariants = 10,
    [int]$OperatingVariants = 10,
    [int]$ControlVariants = 10,
    [int]$AnalyticShards = 4,
    [int]$BiotSavartShards = 2,
    [int]$PoincareShards = 2,
    [ValidateRange(1, 100)]
    [int]$MaxBiotSavartCandidates = 100,
    [ValidateRange(1, 20)]
    [int]$MaxPoincareCandidates = 20,
    [int]$PoincareTurns = 32,
    [int]$PoincareStepsPerTurn = 180,
    [int]$PoincareBins = 16,
    [string]$OutputDirectory = "runs/v84_sharded_fidelity_funnel",
    [bool]$Resume = $true
)

$ErrorActionPreference = "Stop"
if ($PhysicalVariants -lt 1 -or $OperatingVariants -lt 1 -or $ControlVariants -lt 1) {
    throw "Variant counts must be positive."
}
if ($AnalyticShards -lt 1 -or $BiotSavartShards -lt 1 -or $PoincareShards -lt 1) {
    throw "Shard counts must be positive."
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Cli = Join-Path $PSScriptRoot "v84_sharded_funnel_cli.jl"
$ResolvedOutput = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $OutputDirectory))
New-Item -ItemType Directory -Force -Path $ResolvedOutput | Out-Null
$ResumeText = $Resume.ToString().ToLowerInvariant()
$TotalCandidates = $PhysicalVariants * $OperatingVariants * $ControlVariants * 2
$AnalyticShards = [Math]::Min($AnalyticShards, $TotalCandidates)

function Start-V84ShardProcesses {
    param([array]$Specs, [string]$Stage)
    $Processes = @()
    foreach ($Spec in $Specs) {
        $Stdout = Join-Path $ResolvedOutput ("{0}_shard_{1:D3}.stdout.log" -f $Stage, $Spec.Shard)
        $Stderr = Join-Path $ResolvedOutput ("{0}_shard_{1:D3}.stderr.log" -f $Stage, $Spec.Shard)
        $Arguments = @("--threads=1", "--project=$ProjectRoot", $Cli) + $Spec.Arguments
        $Process = Start-Process -FilePath "julia" -ArgumentList $Arguments `
            -WorkingDirectory $ProjectRoot -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput $Stdout -RedirectStandardError $Stderr
        $Processes += [pscustomobject]@{ Process = $Process; Shard = $Spec.Shard; Stderr = $Stderr }
    }
    foreach ($Item in $Processes) {
        $Item.Process.WaitForExit()
        if ($Item.Process.ExitCode -ne 0) {
            throw "v84 $Stage shard $($Item.Shard) failed; inspect $($Item.Stderr)"
        }
    }
}

$AnalyticSpecs = @()
for ($Shard = 1; $Shard -le $AnalyticShards; $Shard++) {
    $First = [Math]::Floor(($Shard - 1) * $TotalCandidates / $AnalyticShards) + 1
    $Last = [Math]::Floor($Shard * $TotalCandidates / $AnalyticShards)
    $Arguments = @("analytic-shard", $ResolvedOutput, $Shard, $First, $Last,
        $PhysicalVariants, $OperatingVariants, $ControlVariants, $ResumeText)
    $AnalyticSpecs += [pscustomobject]@{ Shard = $Shard; Arguments = $Arguments }
}
Start-V84ShardProcesses -Specs $AnalyticSpecs -Stage "analytic"

& julia --threads=1 --project=$ProjectRoot $Cli "merge-analytic" $ResolvedOutput `
    $AnalyticShards $PhysicalVariants $OperatingVariants $ControlVariants `
    $MaxBiotSavartCandidates
if ($LASTEXITCODE -ne 0) { throw "v84 analytic merge failed" }

$QueuePath = Join-Path $ResolvedOutput "v84_fast_biot_savart_queue.jsonl"
$QueueCount = @(Get-Content -LiteralPath $QueuePath | Where-Object { $_.Trim().Length -gt 0 }).Count
if ($QueueCount -eq 0) {
    Write-Host "v84 analytic merge produced an empty physical queue."
    exit 0
}
$BiotSavartShards = [Math]::Min($BiotSavartShards, $QueueCount)
$BiotSpecs = @()
for ($Shard = 1; $Shard -le $BiotSavartShards; $Shard++) {
    $First = [Math]::Floor(($Shard - 1) * $QueueCount / $BiotSavartShards) + 1
    $Last = [Math]::Floor($Shard * $QueueCount / $BiotSavartShards)
    $Arguments = @("biot-shard", $ResolvedOutput, $Shard, $First, $Last, $ResumeText)
    $BiotSpecs += [pscustomobject]@{ Shard = $Shard; Arguments = $Arguments }
}
Start-V84ShardProcesses -Specs $BiotSpecs -Stage "biot_savart"

& julia --threads=1 --project=$ProjectRoot $Cli "merge-biot" $ResolvedOutput `
    $BiotSavartShards $MaxPoincareCandidates
if ($LASTEXITCODE -ne 0) { throw "v84 Biot-Savart merge failed" }

$PoincareQueuePath = Join-Path $ResolvedOutput "v84_poincare_queue.jsonl"
$PoincareQueueCount = @(Get-Content -LiteralPath $PoincareQueuePath |
    Where-Object { $_.Trim().Length -gt 0 }).Count
if ($PoincareQueueCount -eq 0) {
    Write-Host "v84 Biot-Savart merge produced an empty Poincare queue."
    exit 0
}
$PoincareShards = [Math]::Min($PoincareShards, $PoincareQueueCount)
$PoincareSpecs = @()
for ($Shard = 1; $Shard -le $PoincareShards; $Shard++) {
    $First = [Math]::Floor(($Shard - 1) * $PoincareQueueCount / $PoincareShards) + 1
    $Last = [Math]::Floor($Shard * $PoincareQueueCount / $PoincareShards)
    $Arguments = @("poincare-shard", $ResolvedOutput, $Shard, $First, $Last,
        $ResumeText, $PoincareTurns, $PoincareStepsPerTurn, $PoincareBins)
    $PoincareSpecs += [pscustomobject]@{ Shard = $Shard; Arguments = $Arguments }
}
Start-V84ShardProcesses -Specs $PoincareSpecs -Stage "poincare"

& julia --threads=1 --project=$ProjectRoot $Cli "merge-poincare" $ResolvedOutput `
    $PoincareShards
if ($LASTEXITCODE -ne 0) { throw "v84 Poincare merge failed" }
Write-Host "v84 sharded fidelity funnel complete: $ResolvedOutput"
