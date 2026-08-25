param(
    [string]$OutputDirectory = "",
    [int]$WorkerCount = 4,
    [int]$NumericalPerShard = 100
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $ProjectRoot "runs\stage3_v70_100000_20260825"
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
if ($WorkerCount -ne 4) { throw "This accepted run requires exactly 4 workers." }
if ($NumericalPerShard -lt 0) { throw "NumericalPerShard must be non-negative." }
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null

$ShardScript = Join-Path $PSScriptRoot "run_stage3_streaming_v70_shard.jl"
$MergeScript = Join-Path $PSScriptRoot "merge_stage3_streaming_v70.jl"
$active = [System.Collections.Generic.List[object]]::new()
$all = [System.Collections.Generic.List[object]]::new()

function Wait-ForSlot {
    param([int]$Limit)
    while ($active.Count -ge $Limit) {
        for ($i = $active.Count - 1; $i -ge 0; $i--) {
            $item = $active[$i]
            if ($item.Process.HasExited) {
                $item.Process.WaitForExit()
                if ($item.Process.ExitCode -ne 0) {
                    throw "Shard $($item.ShardId) failed with exit code $($item.Process.ExitCode). See $($item.ErrorLog)"
                }
                Write-Host "Shard $($item.ShardId) complete."
                $active.RemoveAt($i)
            }
        }
        if ($active.Count -ge $Limit) { Start-Sleep -Seconds 1 }
    }
}

for ($shardId = 1; $shardId -le 10; $shardId++) {
    Wait-ForSlot -Limit $WorkerCount
    $firstSeed = (($shardId - 1) * 10000) + 1
    $lastSeed = $shardId * 10000
    $stdout = Join-Path $OutputDirectory ("worker_{0:D2}.stdout.log" -f $shardId)
    $stderr = Join-Path $OutputDirectory ("worker_{0:D2}.stderr.log" -f $shardId)
    $arguments = @(
        "--startup-file=no", "--project=$ProjectRoot", $ShardScript,
        "--shard-id", "$shardId", "--first-seed", "$firstSeed",
        "--last-seed", "$lastSeed", "--output-directory", $OutputDirectory,
        "--numerical-per-shard", "$NumericalPerShard"
    )
    $process = Start-Process -FilePath "julia" -ArgumentList $arguments -PassThru `
        -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $item = [pscustomobject]@{ Process = $process; ShardId = $shardId; ErrorLog = $stderr }
    $active.Add($item); $all.Add($item)
    Write-Host "Started shard $shardId ($firstSeed..$lastSeed), PID $($process.Id)."
}

while ($active.Count -gt 0) { Wait-ForSlot -Limit 1 }
Write-Host "All 10 shards complete; merging by structure hash and evidence hash."
& julia --startup-file=no --project=$ProjectRoot $MergeScript `
    --output-directory $OutputDirectory --expected-raw-count 100000
if ($LASTEXITCODE -ne 0) { throw "Merged acceptance failed with exit code $LASTEXITCODE." }
