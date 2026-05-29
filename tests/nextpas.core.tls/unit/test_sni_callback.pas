program test_sni_callback;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, nextpas.core.tls.sni.callback, nextpas.core.tls.x509;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Halt(1);
  end;
end;

function MakeDummyCert(AByte: Byte): TBytes;
begin
  SetLength(Result, 4);
  Result[0] := AByte; Result[1] := AByte;
  Result[2] := AByte; Result[3] := AByte;
end;

procedure TestCreateDestroy;
var
  LSel: TSNICertificateSelector;
begin
  WriteLn('TestCreateDestroy');
  LSel := TSNICertificateSelector.Create;
  try
    Check(LSel.Count = 0, 'Empty selector count = 0');
  finally
    LSel.Free;
  end;
end;

procedure TestAddAndSelect;
var
  LSel: TSNICertificateSelector;
  LIdx: Integer;
  LEntry: TSNICertificateEntry;
begin
  WriteLn('TestAddAndSelect');
  LSel := TSNICertificateSelector.Create;
  try
    LSel.AddCertificate('example.com', MakeDummyCert($AA), MakeDummyCert($BB));
    LSel.AddCertificate('other.com', MakeDummyCert($CC), MakeDummyCert($DD));
    Check(LSel.Count = 2, 'Count = 2');

    LIdx := LSel.SelectForHostname('example.com');
    Check(LIdx = 0, 'Select example.com = index 0');

    LIdx := LSel.SelectForHostname('other.com');
    Check(LIdx = 1, 'Select other.com = index 1');

    LEntry := LSel.GetEntry(0);
    Check(LEntry.Hostname = 'example.com', 'Entry hostname');
    Check(LEntry.CertificateDER[0] = $AA, 'Entry cert data');
    Check(LEntry.PrivateKeyDER[0] = $BB, 'Entry key data');
  finally
    LSel.Free;
  end;
end;

procedure TestWildcard;
var
  LSel: TSNICertificateSelector;
  LIdx: Integer;
begin
  WriteLn('TestWildcard');
  LSel := TSNICertificateSelector.Create;
  try
    LSel.AddCertificate('specific.example.com', MakeDummyCert($33), MakeDummyCert($44));
    LSel.AddCertificate('*.example.com', MakeDummyCert($11), MakeDummyCert($22));

    LIdx := LSel.SelectForHostname('www.example.com');
    Check(LIdx = 1, 'Wildcard matches www.example.com');

    LIdx := LSel.SelectForHostname('specific.example.com');
    Check(LIdx = 0, 'Exact match takes priority over wildcard');
  finally
    LSel.Free;
  end;
end;

procedure TestDefaultFallback;
var
  LSel: TSNICertificateSelector;
  LIdx: Integer;
begin
  WriteLn('TestDefaultFallback');
  LSel := TSNICertificateSelector.Create;
  try
    LSel.AddCertificate('first.com', MakeDummyCert($01), MakeDummyCert($02));
    LSel.AddCertificate('second.com', MakeDummyCert($03), MakeDummyCert($04));

    LIdx := LSel.SelectForHostname('unknown.com');
    Check(LIdx = 0, 'Default is first added (index 0)');

    LSel.SetDefault('second.com');
    LIdx := LSel.SelectForHostname('unknown.com');
    Check(LIdx = 1, 'After SetDefault, fallback is index 1');
  finally
    LSel.Free;
  end;
end;

procedure TestCaseInsensitive;
var
  LSel: TSNICertificateSelector;
  LIdx: Integer;
begin
  WriteLn('TestCaseInsensitive');
  LSel := TSNICertificateSelector.Create;
  try
    LSel.AddCertificate('Example.COM', MakeDummyCert($55), MakeDummyCert($66));
    LIdx := LSel.SelectForHostname('EXAMPLE.com');
    Check(LIdx = 0, 'Case-insensitive match');
  finally
    LSel.Free;
  end;
end;

begin
  
  LTotal := 0;
  LPassed := 0;

  TestCreateDestroy;
  TestAddAndSelect;
  TestWildcard;
  TestDefaultFallback;
  TestCaseInsensitive;

  WriteLn;
  WriteLn('SNI Callback tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
