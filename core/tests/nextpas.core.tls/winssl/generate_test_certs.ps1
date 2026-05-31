# generate_test_certs.ps1 - 生成 WinSSL 服务端测试证书
# 
# 版本: 1.0
# 作者: fafafa.ssl 开发团队
# 创建: 2025-01-17
#
# 描述:
#   为 WinSSL 服务端测试生成自签名证书和密钥

$ErrorActionPreference = "Stop"

# 设置证书目录
$CertDir = Join-Path $PSScriptRoot "test_certs"
if (-not (Test-Path $CertDir)) {
    New-Item -ItemType Directory -Path $CertDir | Out-Null
}

Write-Host "生成测试证书到: $CertDir" -ForegroundColor Green

# 生成服务器证书
$ServerCertPath = Join-Path $CertDir "server.pfx"
$ServerCertPassword = "test123"

# 创建自签名证书
$Cert = New-SelfSignedCertificate `
    -Subject "CN=localhost" `
    -DnsName "localhost", "127.0.0.1", "::1" `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -NotBefore (Get-Date) `
    -NotAfter (Get-Date).AddYears(1) `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -FriendlyName "WinSSL Test Server Certificate" `
    -KeyUsage DigitalSignature, KeyEncipherment `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1") # Server Authentication

Write-Host "服务器证书已创建: $($Cert.Thumbprint)" -ForegroundColor Cyan

# 导出为 PFX 文件
$SecurePassword = ConvertTo-SecureString -String $ServerCertPassword -Force -AsPlainText
Export-PfxCertificate -Cert $Cert -FilePath $ServerCertPath -Password $SecurePassword | Out-Null

Write-Host "服务器证书已导出到: $ServerCertPath" -ForegroundColor Green

# 生成客户端证书（用于双向 TLS 测试）
$ClientCertPath = Join-Path $CertDir "client.pfx"
$ClientCertPassword = "test123"

$ClientCert = New-SelfSignedCertificate `
    -Subject "CN=testclient" `
    -DnsName "testclient" `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -NotBefore (Get-Date) `
    -NotAfter (Get-Date).AddYears(1) `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -FriendlyName "WinSSL Test Client Certificate" `
    -KeyUsage DigitalSignature, KeyEncipherment `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2") # Client Authentication

Write-Host "客户端证书已创建: $($ClientCert.Thumbprint)" -ForegroundColor Cyan

Export-PfxCertificate -Cert $ClientCert -FilePath $ClientCertPath -Password $SecurePassword | Out-Null

Write-Host "客户端证书已导出到: $ClientCertPath" -ForegroundColor Green

# 创建证书信息文件
$InfoPath = Join-Path $CertDir "cert_info.txt"
@"
WinSSL 测试证书信息
==================

服务器证书:
  文件: server.pfx
  密码: $ServerCertPassword
  指纹: $($Cert.Thumbprint)
  主题: $($Cert.Subject)
  有效期: $($Cert.NotBefore) - $($Cert.NotAfter)

客户端证书:
  文件: client.pfx
  密码: $ClientCertPassword
  指纹: $($ClientCert.Thumbprint)
  主题: $($ClientCert.Subject)
  有效期: $($ClientCert.NotBefore) - $($ClientCert.NotAfter)

注意: 这些证书仅用于测试目的,不应在生产环境中使用。
"@ | Out-File -FilePath $InfoPath -Encoding UTF8

Write-Host "`n证书生成完成!" -ForegroundColor Green
Write-Host "证书信息已保存到: $InfoPath" -ForegroundColor Cyan

# 清理证书存储中的测试证书（可选）
Write-Host "`n提示: 测试证书已添加到当前用户的证书存储中" -ForegroundColor Yellow
Write-Host "如需清理,请运行: Remove-Item -Path Cert:\CurrentUser\My\$($Cert.Thumbprint)" -ForegroundColor Yellow
Write-Host "              Remove-Item -Path Cert:\CurrentUser\My\$($ClientCert.Thumbprint)" -ForegroundColor Yellow
