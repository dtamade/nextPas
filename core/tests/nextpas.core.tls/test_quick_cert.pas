{
  test_quick_cert - 测试 TSSLQuick.GetCertificateInfo 方法
}

program test_quick_cert;

{$mode objfpc}{$H+}

uses
  nextpas.core.tls.quick,
  nextpas.core.tls.factory,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.backed, nextpas.core.exception, nextpas.core.time, nextpas.core.text.conv;
var
  Info: TSSLCertificateInfo;
  Host: string;
begin
  WriteLn('╔═══════════════════════════════════════════╗');
  WriteLn('║  TSSLQuick.GetCertificateInfo Test        ║');
  WriteLn('╚═══════════════════════════════════════════╝');
  WriteLn;

  Host := '/etc/ssl/certs/ca-certificates.crt';
  WriteLn('正在获取证书信息: ', Host);
  WriteLn;

  try
    Info := TSSLHelper.GetCertificateInfo(Host);

    WriteLn('证书信息:');
    WriteLn('  主题: ', Info.Subject);
    WriteLn('  颁发者: ', Info.Issuer);
    WriteLn('  有效期开始: ', DateTimeToStr(Info.NotBefore));
    WriteLn('  有效期结束: ', DateTimeToStr(Info.NotAfter));
    WriteLn('  是否有效: ', BoolToStr((DateTimeNow >= Info.NotBefore) and (DateTimeNow <= Info.NotAfter)));
    WriteLn('  是否过期: ', BoolToStr(DateTimeNow > Info.NotAfter));
    WriteLn('  距离过期: ', Trunc(Info.NotAfter - DateTimeNow), ' 天');
    WriteLn('  SHA256指纹: ', Info.FingerprintSHA256);

    WriteLn;
    if (DateTimeNow >= Info.NotBefore) and (DateTimeNow <= Info.NotAfter) then
    begin
      WriteLn('✅ 证书验证通过！');
      Halt(0);
    end
    else
    begin
      WriteLn('❌ 证书无效！');
      Halt(1);
    end;
  except
    on E: Exception do
    begin
      WriteLn('❌ 发生错误: ', E.Message);
      Halt(1);
    end;
  end;
end.
