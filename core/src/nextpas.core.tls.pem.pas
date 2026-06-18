unit nextpas.core.tls.pem;

{$mode objfpc}{$H+}
{$WARN 5093 off} // Suppress false-positive "Function result not initialized" for managed types
{$modeswitch advancedrecords}

{
  PEM 格式处理器 - 纯 Pascal 实现

  PEM (Privacy-Enhanced Mail) 是一种将二进制 DER 数据编码为
  ASCII 文本的格式，使用 Base64 编码。

  格式:
  -----BEGIN <TYPE>-----
  <Base64 encoded DER data>
  -----END <TYPE>-----

  常见类型:
  - CERTIFICATE
  - PRIVATE KEY / RSA PRIVATE KEY / EC PRIVATE KEY
  - PUBLIC KEY
  - CERTIFICATE REQUEST
  - X509 CRL
  - PKCS7 / CMS

  @author fafafa.ssl team
  @version 1.0.0
}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.io.intf,
  nextpas.core.fs;

type
  // ========================================================================
  // 异常类型
  // ========================================================================
  EPEMException = class(Exception);
  EPEMParseException = class(EPEMException);

  // ========================================================================
  // PEM 块类型
  // ========================================================================
  TPEMType = (
    pemUnknown,
    pemCertificate,           // CERTIFICATE
    pemPrivateKey,            // PRIVATE KEY (PKCS#8)
    pemRSAPrivateKey,         // RSA PRIVATE KEY (PKCS#1)
    pemECPrivateKey,          // EC PRIVATE KEY
    pemPublicKey,             // PUBLIC KEY
    pemRSAPublicKey,          // RSA PUBLIC KEY
    pemCertificateRequest,    // CERTIFICATE REQUEST
    pemX509CRL,               // X509 CRL
    pemPKCS7,                 // PKCS7
    pemCMS,                   // CMS
    pemDHParameters,          // DH PARAMETERS
    pemECParameters,          // EC PARAMETERS
    pemEncryptedPrivateKey    // ENCRYPTED PRIVATE KEY
  );

  // ========================================================================
  // PEM 块
  // ========================================================================
  TPEMBlock = record
    BlockType: TPEMType;
    TypeString: string;       // 原始类型字符串 (如 "CERTIFICATE")
    Data: TBytes;             // 解码后的 DER 数据
    Headers: TStringArray;     // 可选的头部字段 (如 Proc-Type, DEK-Info)

    procedure Clear;
    function IsEncrypted: Boolean;
  end;

  TPEMBlockArray = array of TPEMBlock;

  // ========================================================================
  // PEM 解析器
  // ========================================================================
  TPEMReader = class
  private
    FText: string;
    FBlocks: TPEMBlockArray;

    function FindNextBlock(var APos: Integer; out AStartMarker, AEndMarker: string;
      out ATypeStr: string): Boolean;
    function ExtractBlockContent(const AStartMarker, AEndMarker: string;
      var APos: Integer; out AHeaders: TStringArray): string;
    class function DecodeBase64(const AInput: string): TBytes; static;
    class function GetPEMType(const ATypeStr: string): TPEMType; static;
  public
    constructor Create;
    destructor Destroy; override;

    // 加载 PEM 数据
    procedure LoadFromString(const APEMText: string);
    procedure LoadFromFile(const AFileName: string);
    procedure LoadFromStream(AStream: IStream);

    // 块访问
    property Blocks: TPEMBlockArray read FBlocks;
    function BlockCount: Integer;
    function GetBlock(AIndex: Integer): TPEMBlock;
    function GetFirstBlockOfType(AType: TPEMType): TPEMBlock;
    function GetAllBlocksOfType(AType: TPEMType): TPEMBlockArray;

    // 便捷方法
    function GetCertificates: TPEMBlockArray;
    function GetPrivateKeys: TPEMBlockArray;
  end;

  // ========================================================================
  // PEM 写入器
  // ========================================================================
  TPEMWriter = class
  private
    FLineLength: Integer;

    class function EncodeBase64(const AData: TBytes): string; static;
    class function GetTypeString(AType: TPEMType): string; static;
  public
    constructor Create;

    // 写入单个块
    function WriteBlock(AType: TPEMType; const AData: TBytes): string;
    function WriteBlockWithType(const ATypeString: string; const AData: TBytes): string;

    // 写入多个块
    function WriteBlocks(const ABlocks: TPEMBlockArray): string;

    // 便捷方法
    function WriteCertificate(const ADERData: TBytes): string;
    function WritePrivateKey(const ADERData: TBytes): string;
    function WritePublicKey(const ADERData: TBytes): string;

    // 保存到文件
    procedure SaveToFile(const AFileName: string; const APEMText: string);

    // 配置
    property LineLength: Integer read FLineLength write FLineLength;
  end;

// ========================================================================
// 辅助函数
// ========================================================================

// 检测数据格式
function IsPEMFormat(const AData: TBytes): Boolean;
function IsDERFormat(const AData: TBytes): Boolean;

// PEM 类型名称
function PEMTypeToString(AType: TPEMType): string;
function StringToPEMType(const ATypeStr: string): TPEMType;

implementation

uses
  nextpas.core.text.strings;

// ========================================================================
// TPEMBlock
// ========================================================================

procedure TPEMBlock.Clear;
begin
  BlockType := pemUnknown;
  TypeString := '';
  SetLength(Data, 0);
  if Headers <> nil then
  Headers := nil;
end;

function TPEMBlock.IsEncrypted: Boolean;
var
  I: Integer;
begin
  Result := False;
  if Headers = nil then
    Exit;

  // 检查是否有 Proc-Type 头部
  for I := 0 to Length(Headers) - 1 do
  begin
    if Pos('Proc-Type:', Headers[I]) = 1 then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

// ========================================================================
// TPEMReader
// ========================================================================

constructor TPEMReader.Create;
begin
  inherited Create;
  FText := '';
  SetLength(FBlocks, 0);
end;

destructor TPEMReader.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FBlocks) do
    if FBlocks[I].Headers <> nil then
      FBlocks[I].Headers := nil;
  inherited Destroy;
end;

function TPEMReader.FindNextBlock(var APos: Integer; out AStartMarker, AEndMarker: string;
  out ATypeStr: string): Boolean;
var
  StartPos, EndPos, TypeStart, TypeEnd: Integer;
begin
  Result := False;

  // 查找 "-----BEGIN "
  StartPos := Pos('-----BEGIN ', Copy(FText, APos, Length(FText)));
  if StartPos = 0 then
    Exit;
  StartPos := StartPos + APos - 1;

  // 查找类型结束 "-----"
  TypeStart := StartPos + Length('-----BEGIN ');
  TypeEnd := Pos('-----', Copy(FText, TypeStart, Length(FText)));
  if TypeEnd = 0 then
    Exit;
  TypeEnd := TypeStart + TypeEnd - 1;

  ATypeStr := Trim(Copy(FText, TypeStart, TypeEnd - TypeStart));
  AStartMarker := '-----BEGIN ' + ATypeStr + '-----';
  AEndMarker := '-----END ' + ATypeStr + '-----';

  // 验证结束标记存在
  EndPos := Pos(AEndMarker, Copy(FText, TypeEnd, Length(FText)));
  if EndPos = 0 then
    Exit;

  APos := StartPos;
  Result := True;
end;

function TPEMReader.ExtractBlockContent(const AStartMarker, AEndMarker: string;
  var APos: Integer; out AHeaders: nextpas.core.base.TStringArray): string;
var
  ContentStart, ContentEnd: Integer;
  Lines: TStringArray;
  I: Integer;
  Line: string;
  InHeaders: Boolean;
  HeaderEnded: Boolean;
begin
  Result := '';

  // 找到内容开始位置 (紧跟在 BEGIN 标记之后)
  ContentStart := Pos(AStartMarker, Copy(FText, APos, Length(FText)));
  if ContentStart = 0 then
    Exit;
  ContentStart := APos + ContentStart - 1 + Length(AStartMarker);

  // 找到内容结束位置 (END 标记之前)
  ContentEnd := Pos(AEndMarker, Copy(FText, ContentStart, Length(FText)));
  if ContentEnd = 0 then
    Exit;
  ContentEnd := ContentStart + ContentEnd - 1;

  // 提取并处理内容
  try
    Lines := nextpas.core.text.strings.StringsParseLines(Copy(FText, ContentStart, ContentEnd - ContentStart));
    InHeaders := True;
    HeaderEnded := False;

    for I := 0 to Length(Lines) - 1 do
    begin
      Line := Trim(Lines[I]);

      if Line = '' then
      begin
        // 空行分隔头部和内容
        if InHeaders and (Length(AHeaders) > 0) then
        begin
          InHeaders := False;
          HeaderEnded := True;
        end;
        Continue;
      end;

      // 检查是否是头部行 (格式: "Name: Value")
      // 头部只在内容开始之前，且必须包含冒号
      if InHeaders and (not HeaderEnded) and (Pos(': ', Line) > 0) and
        (Pos(': ', Line) < 20) then  // 头部名称通常较短
      begin
        // 这是一个头部字段
        SetLength(AHeaders, Length(AHeaders) + 1);
        AHeaders[High(AHeaders)] := Line;
      end
      else
      begin
        // 这是 Base64 内容
        InHeaders := False;
        Result := Result + Line;
      end;
    end;
  finally
  end;

  // 更新位置到 END 标记之后
  APos := ContentEnd + Length(AEndMarker);
end;

class function TPEMReader.DecodeBase64(const AInput: string): TBytes;
const
  Base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var
  I, J, Value: Integer;
  C: Char;
  Pad: Integer;
  DecodeTable: array[0..127] of Integer;
  CleanInput: string;
begin
  // 移除所有空白字符
  CleanInput := '';
  for I := 1 to Length(AInput) do
  begin
    C := AInput[I];
    if not (C in [#9, #10, #13, ' ']) then
      CleanInput := CleanInput + C;
  end;

  if CleanInput = '' then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // 初始化解码表
  for I := 0 to 127 do
    DecodeTable[I] := -1;
  for I := 1 to Length(Base64Chars) do
    DecodeTable[Ord(Base64Chars[I])] := I - 1;

  // 计算输出长度
  Pad := 0;
  if (Length(CleanInput) > 0) and (CleanInput[Length(CleanInput)] = '=') then
    Inc(Pad);
  if (Length(CleanInput) > 1) and (CleanInput[Length(CleanInput) - 1] = '=') then
    Inc(Pad);

  SetLength(Result, (Length(CleanInput) * 3) div 4 - Pad);

  J := 0;
  I := 1;
  while I <= Length(CleanInput) - 3 do
  begin
    Value := 0;

    C := CleanInput[I];
    if (Ord(C) <= 127) and (DecodeTable[Ord(C)] >= 0) then
      Value := DecodeTable[Ord(C)] shl 18;
    Inc(I);

    C := CleanInput[I];
    if (Ord(C) <= 127) and (DecodeTable[Ord(C)] >= 0) then
      Value := Value or (DecodeTable[Ord(C)] shl 12);
    Inc(I);

    C := CleanInput[I];
    if C <> '=' then
    begin
      if (Ord(C) <= 127) and (DecodeTable[Ord(C)] >= 0) then
        Value := Value or (DecodeTable[Ord(C)] shl 6);
    end;
    Inc(I);

    C := CleanInput[I];
    if C <> '=' then
    begin
      if (Ord(C) <= 127) and (DecodeTable[Ord(C)] >= 0) then
        Value := Value or DecodeTable[Ord(C)];
    end;
    Inc(I);

    if J < Length(Result) then
    begin
      Result[J] := Byte((Value shr 16) and $FF);
      Inc(J);
    end;
    if J < Length(Result) then
    begin
      Result[J] := Byte((Value shr 8) and $FF);
      Inc(J);
    end;
    if J < Length(Result) then
    begin
      Result[J] := Byte(Value and $FF);
      Inc(J);
    end;
  end;
end;

class function TPEMReader.GetPEMType(const ATypeStr: string): TPEMType;
var
  Upper: string;
begin
  Upper := UpperCase(ATypeStr);

  if Upper = 'CERTIFICATE' then
    Result := pemCertificate
  else if Upper = 'PRIVATE KEY' then
    Result := pemPrivateKey
  else if Upper = 'RSA PRIVATE KEY' then
    Result := pemRSAPrivateKey
  else if Upper = 'EC PRIVATE KEY' then
    Result := pemECPrivateKey
  else if Upper = 'PUBLIC KEY' then
    Result := pemPublicKey
  else if Upper = 'RSA PUBLIC KEY' then
    Result := pemRSAPublicKey
  else if (Upper = 'CERTIFICATE REQUEST') or (Upper = 'NEW CERTIFICATE REQUEST') then
    Result := pemCertificateRequest
  else if Upper = 'X509 CRL' then
    Result := pemX509CRL
  else if Upper = 'PKCS7' then
    Result := pemPKCS7
  else if Upper = 'CMS' then
    Result := pemCMS
  else if Upper = 'DH PARAMETERS' then
    Result := pemDHParameters
  else if Upper = 'EC PARAMETERS' then
    Result := pemECParameters
  else if Upper = 'ENCRYPTED PRIVATE KEY' then
    Result := pemEncryptedPrivateKey
  else
    Result := pemUnknown;
end;

procedure TPEMReader.LoadFromString(const APEMText: string);
var
  Pos: Integer;
  StartMarker, EndMarker, TypeStr: string;
  Content: string;
  Headers: TStringArray;
  Block: TPEMBlock;
  I: Integer;
begin
  // 清除旧数据
  for I := 0 to High(FBlocks) do
    if FBlocks[I].Headers <> nil then
      FBlocks[I].Headers := nil;
  SetLength(FBlocks, 0);

  FText := APEMText;
  Pos := 1;

  while FindNextBlock(Pos, StartMarker, EndMarker, TypeStr) do
  begin
    Content := ExtractBlockContent(StartMarker, EndMarker, Pos, Headers);

    Block.TypeString := TypeStr;
    Block.BlockType := GetPEMType(TypeStr);
    Block.Data := DecodeBase64(Content);
    Block.Headers := Headers;

    SetLength(FBlocks, Length(FBlocks) + 1);
    FBlocks[High(FBlocks)] := Block;
  end;
end;

procedure TPEMReader.LoadFromFile(const AFileName: string);
var
  LFile: IFile;
begin
  LFile := nextpas.core.fs.Open(AFileName, [fmRead]);
  LoadFromStream(LFile);
end;

procedure TPEMReader.LoadFromStream(AStream: IStream);
var
  Data: TBytes;
  LSize: SizeInt;
begin
  LSize := AStream.GetSize;
  SetLength(Data, LSize);
  if LSize > 0 then
  begin
    AStream.Read(Data[0], SizeUInt(LSize));
    LoadFromString(AnsiString(nextpas.core.text.conv.UTF8BytesToString(Data)));
  end;
end;

function TPEMReader.BlockCount: Integer;
begin
  Result := Length(FBlocks);
end;

function TPEMReader.GetBlock(AIndex: Integer): TPEMBlock;
begin
  if (AIndex < 0) or (AIndex >= Length(FBlocks)) then
    raise EPEMException.CreateFmt('Block index out of range: %d', [AIndex]);
  Result := FBlocks[AIndex];
end;

function TPEMReader.GetFirstBlockOfType(AType: TPEMType): TPEMBlock;
var
  I: Integer;
begin
  for I := 0 to High(FBlocks) do
  begin
    if FBlocks[I].BlockType = AType then
    begin
      Result := FBlocks[I];
      Exit;
    end;
  end;

  // 未找到，返回空块
  Result.Clear;
end;

function TPEMReader.GetAllBlocksOfType(AType: TPEMType): TPEMBlockArray;
var
  I, Count: Integer;
begin
  Count := 0;
  for I := 0 to High(FBlocks) do
    if FBlocks[I].BlockType = AType then
      Inc(Count);

  SetLength(Result, Count);
  Count := 0;
  for I := 0 to High(FBlocks) do
  begin
    if FBlocks[I].BlockType = AType then
    begin
      Result[Count] := FBlocks[I];
      Inc(Count);
    end;
  end;
end;

function TPEMReader.GetCertificates: TPEMBlockArray;
begin
  Result := GetAllBlocksOfType(pemCertificate);
end;

function TPEMReader.GetPrivateKeys: TPEMBlockArray;
var
  I, Count: Integer;
begin
  Count := 0;
  for I := 0 to High(FBlocks) do
    if FBlocks[I].BlockType in [pemPrivateKey, pemRSAPrivateKey, pemECPrivateKey, pemEncryptedPrivateKey] then
      Inc(Count);

  SetLength(Result, Count);
  Count := 0;
  for I := 0 to High(FBlocks) do
  begin
    if FBlocks[I].BlockType in [pemPrivateKey, pemRSAPrivateKey, pemECPrivateKey, pemEncryptedPrivateKey] then
    begin
      Result[Count] := FBlocks[I];
      Inc(Count);
    end;
  end;
end;

// ========================================================================
// TPEMWriter
// ========================================================================

constructor TPEMWriter.Create;
begin
  inherited Create;
  FLineLength := 64;  // 标准 PEM 行长
end;

class function TPEMWriter.EncodeBase64(const AData: TBytes): string;
const
  Base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var
  I, Len: Integer;
  B1, B2, B3: Byte;
begin
  Result := '';
  if Length(AData) = 0 then
    Exit;

  Len := Length(AData);
  I := 0;
  while I < Len do
  begin
    B1 := AData[I];
    Inc(I);

    if I < Len then
      B2 := AData[I]
    else
      B2 := 0;
    Inc(I);

    if I < Len then
      B3 := AData[I]
    else
      B3 := 0;
    Inc(I);

    // 编码 4 个字符
    Result := Result + Base64Chars[1 + (B1 shr 2)];
    Result := Result + Base64Chars[1 + (((B1 and $03) shl 4) or (B2 shr 4))];

    if I - 2 < Len then
      Result := Result + Base64Chars[1 + (((B2 and $0F) shl 2) or (B3 shr 6))]
    else
      Result := Result + '=';

    if I - 1 < Len then
      Result := Result + Base64Chars[1 + (B3 and $3F)]
    else
      Result := Result + '=';
  end;
end;

class function TPEMWriter.GetTypeString(AType: TPEMType): string;
begin
  case AType of
    pemCertificate:         Result := 'CERTIFICATE';
    pemPrivateKey:          Result := 'PRIVATE KEY';
    pemRSAPrivateKey:       Result := 'RSA PRIVATE KEY';
    pemECPrivateKey:        Result := 'EC PRIVATE KEY';
    pemPublicKey:           Result := 'PUBLIC KEY';
    pemRSAPublicKey:        Result := 'RSA PUBLIC KEY';
    pemCertificateRequest:  Result := 'CERTIFICATE REQUEST';
    pemX509CRL:             Result := 'X509 CRL';
    pemPKCS7:               Result := 'PKCS7';
    pemCMS:                 Result := 'CMS';
    pemDHParameters:        Result := 'DH PARAMETERS';
    pemECParameters:        Result := 'EC PARAMETERS';
    pemEncryptedPrivateKey: Result := 'ENCRYPTED PRIVATE KEY';
  else
    Result := 'DATA';
  end;
end;

function TPEMWriter.WriteBlock(AType: TPEMType; const AData: TBytes): string;
begin
  Result := WriteBlockWithType(GetTypeString(AType), AData);
end;

function TPEMWriter.WriteBlockWithType(const ATypeString: string; const AData: TBytes): string;
var
  Base64: string;
  LineStart: Integer;
begin
  Base64 := EncodeBase64(AData);

  Result := '-----BEGIN ' + ATypeString + '-----' + LineEnding;

  // 分行
  LineStart := 1;
  while LineStart <= Length(Base64) do
  begin
    if LineStart + FLineLength - 1 <= Length(Base64) then
      Result := Result + Copy(Base64, LineStart, FLineLength) + LineEnding
    else
      Result := Result + Copy(Base64, LineStart, Length(Base64) - LineStart + 1) + LineEnding;
    Inc(LineStart, FLineLength);
  end;

  Result := Result + '-----END ' + ATypeString + '-----' + LineEnding;
end;

function TPEMWriter.WriteBlocks(const ABlocks: TPEMBlockArray): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(ABlocks) do
  begin
    if I > 0 then
      Result := Result + LineEnding;
    Result := Result + WriteBlockWithType(ABlocks[I].TypeString, ABlocks[I].Data);
  end;
end;

function TPEMWriter.WriteCertificate(const ADERData: TBytes): string;
begin
  Result := WriteBlock(pemCertificate, ADERData);
end;

function TPEMWriter.WritePrivateKey(const ADERData: TBytes): string;
begin
  Result := WriteBlock(pemPrivateKey, ADERData);
end;

function TPEMWriter.WritePublicKey(const ADERData: TBytes): string;
begin
  Result := WriteBlock(pemPublicKey, ADERData);
end;

procedure TPEMWriter.SaveToFile(const AFileName: string; const APEMText: string);
var
  LFile: IFile;
  Data: TBytes;
begin
  Data := nextpas.core.text.conv.StringToUTF8Bytes(APEMText);
  LFile := nextpas.core.fs.Create(AFileName);
  if Length(Data) > 0 then
    LFile.Write(Data[0], SizeUInt(Length(Data)));
end;

// ========================================================================
// 辅助函数实现
// ========================================================================

function IsPEMFormat(const AData: TBytes): Boolean;
var
  S: string;
begin
  if Length(AData) < 11 then
  begin
    Result := False;
    Exit;
  end;

  // 检查是否以 "-----BEGIN" 开头
  S := AnsiString(nextpas.core.text.conv.ASCIIBytesToString(Copy(AData, 0, 11)));
  Result := (S = '-----BEGIN ');
end;

function IsDERFormat(const AData: TBytes): Boolean;
begin
  // DER 格式的 SEQUENCE 以 0x30 开头
  Result := (Length(AData) > 0) and (AData[0] = $30);
end;

function PEMTypeToString(AType: TPEMType): string;
begin
  Result := TPEMWriter.GetTypeString(AType);
end;

function StringToPEMType(const ATypeStr: string): TPEMType;
begin
  Result := TPEMReader.GetPEMType(ATypeStr);
end;

end.
