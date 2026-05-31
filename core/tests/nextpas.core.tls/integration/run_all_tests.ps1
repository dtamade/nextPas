# OpenSSL Pascal Bindings - Integration Test Suite
# Run all integration tests and report results

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OpenSSL Pascal Bindings Test Suite" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$binDir = "$PSScriptRoot\bin"
$tests = Get-ChildItem -Path $binDir -Filter "test_*.exe" | Sort-Object Name

$totalTests = 0
$passedTests = 0
$failedTests = 0
$results = @()

foreach ($test in $tests) {
    $testName = $test.BaseName
    Write-Host "Running: $testName" -ForegroundColor Yellow
    Write-Host ("=" * 60)
    
    $startTime = Get-Date
    $result = & $test.FullName
    $exitCode = $LASTEXITCODE
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    $totalTests++
    if ($exitCode -eq 0) {
        $passedTests++
        $status = "PASS"
        $color = "Green"
    } else {
        $failedTests++
        $status = "FAIL"
        $color = "Red"
    }
    
    $results += [PSCustomObject]@{
        Test = $testName
        Status = $status
        Duration = [math]::Round($duration, 2)
        ExitCode = $exitCode
    }
    
    Write-Host ""
    Write-Host "Result: $status" -ForegroundColor $color
    Write-Host "Duration: $duration seconds"
    Write-Host ""
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$results | Format-Table -AutoSize

Write-Host ""
Write-Host "Total Tests:  $totalTests" -ForegroundColor White
Write-Host "Passed:       $passedTests" -ForegroundColor Green
Write-Host "Failed:       $failedTests" -ForegroundColor $(if ($failedTests -gt 0) { "Red" } else { "Green" })
Write-Host "Success Rate: $([math]::Round(($passedTests / $totalTests) * 100, 1))%" -ForegroundColor White

if ($failedTests -eq 0) {
    Write-Host ""
    Write-Host "ALL TESTS PASSED!" -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "SOME TESTS FAILED!" -ForegroundColor Red
    exit 1
}
