# Manual owner handoff only. Codex's cleanup command was rejected before execution.
# Do not run while this run's development/review processes are active.
$ErrorActionPreference = 'Stop'
$cleanupRun = 'C:\Users\DELL\AppData\Local\ai-dev-workflow\runs\20261015-operator-company-ux'
$cleanupRepo = Join-Path $cleanupRun 'worktree'
$cleanupAllowed = @('worktree\.next','worktree\node_modules','worktree\tsconfig.tsbuildinfo','company-review-input\source','company-review-input\route-text','company-review-input\source.tar','operator-review-input\source','operator-fix-review-input\source')
$cleanupStatus = git -C $cleanupRepo status --porcelain
if ($LASTEXITCODE -ne 0 -or $cleanupStatus) { throw 'Repository is dirty or unavailable; nothing may be removed.' }
$cleanupBranch = git -C $cleanupRepo branch --show-current
if ($LASTEXITCODE -ne 0 -or $cleanupBranch -ne 'codex/operator-company-ux') { throw 'Unexpected branch.' }
$cleanupTracked = git -C $cleanupRepo ls-files -- .next node_modules tsconfig.tsbuildinfo
if ($LASTEXITCODE -ne 0 -or $cleanupTracked) { throw 'A candidate is tracked by Git.' }
$cleanupConsumers = @(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like '*20261015-operator-company-ux*' -and $_.Name -match '^(node|claude|python|npm)(\.exe)?$' })
if ($cleanupConsumers.Count) { throw 'An owned development/review consumer is active.' }
if (Get-NetTCPConnection -LocalPort 61190 -State Listen -ErrorAction SilentlyContinue) { throw 'The preview is still running.' }
$cleanupInventory = Get-Content -LiteralPath (Join-Path $cleanupRun 'qa\final-cleanup-inventory.json') -Raw | ConvertFrom-Json
$cleanupDiskBefore = [System.IO.DriveInfo]::new('C:\').AvailableFreeSpace
$cleanupRemoved = @()
foreach ($relative in $cleanupAllowed) {
  $target = [System.IO.Path]::GetFullPath((Join-Path $cleanupRun $relative))
  if (-not $target.StartsWith($cleanupRun + '\',[System.StringComparison]::OrdinalIgnoreCase)) { throw 'Target escaped the owned run.' }
  if (-not (Test-Path -LiteralPath $target)) { continue }
  $snapshot = @($cleanupInventory | Where-Object { $_.Relative -eq $relative -and $_.Path -eq $target -and $_.Status -eq 'candidate' })
  if ($snapshot.Count -ne 1) { throw 'No reviewed inventory entry exists.' }
  $item = Get-Item -LiteralPath $target -Force
  $ancestor = $item
  while ($null -ne $ancestor) {
    if (($ancestor.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Reparse ancestor; stop.' }
    $ancestor = if ($ancestor.PSIsContainer) { $ancestor.Parent } else { $ancestor.Directory }
  }
  $entries = if ($item.PSIsContainer) { @(Get-ChildItem -LiteralPath $target -Recurse -Force) } else { @($item) }
  if (@($entries | Where-Object { ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0 }).Count) { throw 'Reparse child; stop.' }
  $files = @($entries | Where-Object { -not $_.PSIsContainer })
  $bytes = [long](($files | Measure-Object Length -Sum).Sum)
  $expectedBytes = [long]($snapshot[0].Bytes)
  $expectedFiles = [long]($snapshot[0].Files)
  if (($bytes -ne $expectedBytes) -or ($files.Count -ne $expectedFiles)) { throw 'Candidate changed since review; stop and refresh the inventory.' }
  Remove-Item -LiteralPath $target -Recurse -Force
  if (Test-Path -LiteralPath $target) { throw 'Removal incomplete.' }
  $cleanupRemoved += [PSCustomObject]@{Relative=$relative;RemovedBytes=$bytes;Files=$files.Count;VerifiedAbsent=$true}
}
$cleanupAfterStatus = git -C $cleanupRepo status --porcelain
if ($LASTEXITCODE -ne 0 -or $cleanupAfterStatus) { throw 'Git state changed during cleanup.' }
$cleanupReceipt = [PSCustomObject]@{
  Status='complete-by-owner'; Removed=$cleanupRemoved
  RemovedFileBytes=[long](($cleanupRemoved | Measure-Object RemovedBytes -Sum).Sum)
  DiskFreeBefore=$cleanupDiskBefore
  DiskFreeAfter=[System.IO.DriveInfo]::new('C:\').AvailableFreeSpace
  GitClean=$true; CloudQuotaFreedClaim=$false
  Preserved=@('source/history','QA credentials/databases/journals','original and Git-tracked acceptance evidence','global caches/unrelated projects','previously rejected logs/validation-deps','Docker recovery evidence')
}
$cleanupReceipt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $cleanupRun 'qa\final-cleanup-receipt.json') -Encoding utf8
$cleanupReceipt | Format-List Status,RemovedFileBytes,DiskFreeBefore,DiskFreeAfter,GitClean
