{
  nextpas.core.tls.utils - SSL/TLS 辅助工具单元

  版本: 2.0 (Phase 2.3.4 重构)
  作者: fafafa.ssl 开发团队
  创建: 2025-09-28
  更新: 2025-01-18

  描述:
    提供 SSL/TLS 特定的工具函数：
    - PEM/DER 证书格式转换
    - 证书信息格式化
    - 网络地址解析和验证
    - SSL 错误信息格式化

  注意:
    - 编码工具已迁移至 nextpas.core.tls.encoding
    - 加密工具已迁移至 nextpas.core.crypto.utils
    - 调试工具已迁移至 nextpas.core.tls.debug.utils
}

unit nextpas.core.tls.utils;

{$mode ObjFPC}{$H+}
{$WARN 5093 off} // Suppress false-positive "Function result not initialized" for managed types
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.base64,
  nextpas.core.tls.debug.utils;

type
  { TSSLUtils - SSL 工具类 }
  TSSLUtils = class
  public
    // 证书工具
    class function IsPEMFormat(const AData: string): Boolean;
    class function IsDERFormat(const AData: TBytes): Boolean;
    class function PEMToDER(const APEM: string): TBytes;
    class function DERToPEM(const ADER: TBytes; const AType: string = 'CERTIFICATE'): string;
    class function ExtractPEMBlock(const APEM: string; const AType: string = 'CERTIFICATE'): string;
    class function FormatCertificateSubject(const ASubject: string): string;
    class function ParseDistinguishedName(const ADN: string): TSSLStringArray;

    // 网络工具
    class function IsIPAddress(const AStr: string): Boolean;
    class function IsIPv4Address(const AStr: string): Boolean;
    class function IsIPv6Address(const AStr: string): Boolean;
    class function IsValidHostname(const AHost: string): Boolean;
    class function ParseURL(const AURL: string; out AProtocol, AHost: string; 
                          out APort: Integer; out APath: string): Boolean;
    class function NormalizeHostname(const AHost: string): string;
    
    // 错误处理
    class function FormatSSLError(AError: TSSLErrorCode; const AContext: string = ''): string;
    class function GetErrorDetails(AException: ESSLException): string;
  end;

const
  // PEM 块标记
  PEM_BEGIN_MARKER = '-----BEGIN ';
  PEM_END_MARKER = '-----END ';
  PEM_CERTIFICATE = 'CERTIFICATE';
  PEM_RSA_PRIVATE_KEY = 'RSA PRIVATE KEY';
  PEM_PRIVATE_KEY = 'PRIVATE KEY';
  PEM_PUBLIC_KEY = 'PUBLIC KEY';
  PEM_CERTIFICATE_REQUEST = 'CERTIFICATE REQUEST';

implementation

uses
  nextpas.core.text.strings,
  Math,
  nextpas.core.tls.errors;


{ TSSLUtils }


class function TSSLUtils.IsPEMFormat(const AData: string): Boolean;
begin
  Result := (Pos(PEM_BEGIN_MARKER, AData) > 0) and 
            (Pos(PEM_END_MARKER, AData) > 0);
end;

class function TSSLUtils.IsDERFormat(const AData: TBytes): Boolean;
begin
  // DER 格式通常以 0x30 (SEQUENCE) 开始
  Result := (Length(AData) > 0) and (AData[0] = $30);
end;

class function TSSLUtils.PEMToDER(const APEM: string): TBytes;
var
  LLines: TStringArray;
  I: Integer;
  LInBlock: Boolean;
  LBase64: string;
begin
  Result := nil;
  LLines := StringsParseLines(APEM);
  LInBlock := False;
  LBase64 := '';

  for I := 0 to Length(LLines) - 1 do
  begin
    if Pos(PEM_BEGIN_MARKER, LLines[I]) > 0 then
    begin
      LInBlock := True;
      Continue;
    end;

    if Pos(PEM_END_MARKER, LLines[I]) > 0 then
      Break;

    if LInBlock then
      LBase64 := LBase64 + Trim(LLines[I]);
  end;

  if LBase64 <> '' then
    Result := TBase64Utils.Decode(LBase64);
end;

class function TSSLUtils.DERToPEM(const ADER: TBytes; const AType: string): string;
var
  LBase64: string;
  LLines: TStringArray;
  I: Integer;
begin
  Result := '';
  if Length(ADER) = 0 then
    Exit;

  LBase64 := TBase64Utils.Encode(ADER);
  SetLength(LLines, 0);
  LLines.Add(PEM_BEGIN_MARKER + AType + '-----');

  I := 1;
  while I <= Length(LBase64) do
  begin
    LLines.Add(Copy(LBase64, I, 64));
    Inc(I, 64);
  end;

  LLines.Add(PEM_END_MARKER + AType + '-----');
  Result := StringsJoin(LLines, LineEnding) + LineEnding;
end;

class function TSSLUtils.ExtractPEMBlock(const APEM: string; const AType: string): string;
var
  LBeginMarker, LEndMarker: string;
  LBeginPos, LEndPos: Integer;
begin
  Result := '';
  
  LBeginMarker := PEM_BEGIN_MARKER + AType + '-----';
  LEndMarker := PEM_END_MARKER + AType + '-----';
  
  LBeginPos := Pos(LBeginMarker, APEM);
  if LBeginPos = 0 then
    Exit;
  
  // 从LBeginPos之后查找LEndMarker
  LEndPos := Pos(LEndMarker, Copy(APEM, LBeginPos, Length(APEM)));
  if LEndPos = 0 then
    Exit;
  LEndPos := LEndPos + LBeginPos - 1;
  
  Result := Copy(APEM, LBeginPos, LEndPos - LBeginPos + Length(LEndMarker));
end;

class function TSSLUtils.FormatCertificateSubject(const ASubject: string): string;
var
  LParts: TStringArray;
  I: Integer;
begin
  LParts := ParseDistinguishedName(ASubject);
  Result := '';
  for I := 0 to Length(LParts) - 1 do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + LParts[I];
  end;
end;

class function TSSLUtils.ParseDistinguishedName(const ADN: string): TSSLStringArray;
var
  LParts: TStringArray;
  I, LCount: Integer;
begin
  SetLength(Result, 0);
  LParts := ADN.Split([',', '/']);
  LCount := 0;
  for I := 0 to High(LParts) do
  begin
    if Trim(LParts[I]) <> '' then
    begin
      SetLength(Result, LCount + 1);
      Result[LCount] := Trim(LParts[I]);
      Inc(LCount);
    end;
  end;
end;


class function TSSLUtils.IsIPAddress(const AStr: string): Boolean;
begin
  Result := IsIPv4Address(AStr) or IsIPv6Address(AStr);
end;

class function TSSLUtils.IsIPv4Address(const AStr: string): Boolean;
var
  LParts: TStringArray;
  I, LNum: Integer;
begin
  Result := False;
  
  LParts := AStr.Split(['.']);
  if Length(LParts) <> 4 then
    Exit;
  
  for I := 0 to 3 do
  begin
    if not TryStrToInt(LParts[I], LNum) then
      Exit;
    if (LNum < 0) or (LNum > 255) then
      Exit;
  end;
  
  Result := True;
end;

class function TSSLUtils.IsIPv6Address(const AStr: string): Boolean;
var
  I, Count: Integer;
begin
  // 简单的 IPv6 检查
  Count := 0;
  for I := 1 to Length(AStr) do
    if AStr[I] = ':' then
      Inc(Count);
  
  Result := (Pos(':', AStr) > 0) and 
            ((Count >= 2) or (Pos('::', AStr) > 0));
end;

class function TSSLUtils.IsValidHostname(const AHost: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  
  if (AHost = '') or (Length(AHost) > 253) then
    Exit;
  
  // 简单验证
  for I := 1 to Length(AHost) do
  begin
    if not (AHost[I] in ['a'..'z', 'A'..'Z', '0'..'9', '.', '-']) then
      Exit;
  end;
  
  Result := True;
end;

class function TSSLUtils.ParseURL(const AURL: string; out AProtocol, AHost: string;
  out APort: Integer; out APath: string): Boolean;
var
  LPos, LSlashPos, LColonPos: Integer;
  LHostPort: string;
begin
  Result := False;
  AProtocol := '';
  AHost := '';
  APort := 0;
  APath := '/';
  
  // 提取协议
  LPos := Pos('://', AURL);
  if LPos > 0 then
  begin
    AProtocol := LowerCase(Copy(AURL, 1, LPos - 1));
    LHostPort := Copy(AURL, LPos + 3, MaxInt);
  end
  else
  begin
    AProtocol := 'https';
    LHostPort := AURL;
  end;
  
  // 提取路径
  LSlashPos := Pos('/', LHostPort);
  if LSlashPos > 0 then
  begin
    APath := Copy(LHostPort, LSlashPos, MaxInt);
    LHostPort := Copy(LHostPort, 1, LSlashPos - 1);
  end;
  
  // 提取主机和端口
  LColonPos := Pos(':', LHostPort);
  if LColonPos > 0 then
  begin
    AHost := Copy(LHostPort, 1, LColonPos - 1);
    if not TryStrToInt(Copy(LHostPort, LColonPos + 1, MaxInt), APort) then
      Exit;
  end
  else
  begin
    AHost := LHostPort;
    if AProtocol = 'https' then
      APort := 443
    else if AProtocol = 'http' then
      APort := 80;
  end;
  
  Result := (AHost <> '') and (APort > 0);
end;

class function TSSLUtils.NormalizeHostname(const AHost: string): string;
begin
  Result := LowerCase(Trim(AHost));
end;

class function TSSLUtils.FormatSSLError(AError: TSSLErrorCode; const AContext: string): string;
var
  LContext: string;
begin
  if AContext <> '' then
    LContext := ' - ' + AContext
  else
    LContext := '';
  Result := Format('[%s]%s', [SSL_ERROR_MESSAGES[AError], LContext]);
end;

class function TSSLUtils.GetErrorDetails(AException: ESSLException): string;
var
  LSB: TSSLStringBuilder;
begin
  LSB := TSSLStringBuilder.Create;
  try
    LSB.AppendLine('SSL 错误详情:');
    LSB.Indent;
    LSB.AppendFormat('错误代码: %s', [SSL_ERROR_MESSAGES[AException.ErrorCode]]);
    LSB.AppendFormat('库类型: %s', [SSL_LIBRARY_NAMES[AException.LibraryType]]);
    
    if AException.NativeError <> 0 then
      LSB.AppendFormat('原生错误码: 0x%x', [AException.NativeError]);
    
    if AException.Context <> '' then
      LSB.AppendFormat('上下文: %s', [AException.Context]);
    
    LSB.AppendFormat('异常消息: %s', [AException.Message]);
    
    Result := LSB.ToString;
  finally
  end;
end;


end.
