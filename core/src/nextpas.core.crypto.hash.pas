unit nextpas.core.crypto.hash;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

{
  Compatibility adapter: one-shot and THashContext APIs for crypto/tls consumers.

  Implementation owner: nextpas.core.hash (SIMD-capable IHasher path).
  Do not reintroduce independent Transform tables here.
}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.hash.intf,
  nextpas.core.hash.base;

type
  { Single source of truth: nextpas.core.hash.base.THashAlgorithm }
  THashAlgorithm = nextpas.core.hash.base.THashAlgorithm;

const
  { Re-export enum values so `uses crypto.hash` still sees ha* without hash.base }
  haMD5 = nextpas.core.hash.base.haMD5;
  haSHA1 = nextpas.core.hash.base.haSHA1;
  haSHA256 = nextpas.core.hash.base.haSHA256;
  haSHA384 = nextpas.core.hash.base.haSHA384;
  haSHA512 = nextpas.core.hash.base.haSHA512;

type
  THashContext = class
  private
    FInner: IHasher;
  protected
    procedure BindInner(AInner: IHasher);
  public
    destructor Destroy; override;

    procedure Update(const AData: TBytes); overload; virtual;
    procedure Update(const AData: string); overload;
    procedure Update(AStream: IStream); overload;
    function Final: TBytes; virtual;
    procedure Reset; virtual;

    class function DigestSize: Integer; virtual; abstract;
    class function BlockSize: Integer; virtual; abstract;
    class function AlgorithmName: string; virtual; abstract;
  end;

  TMD5Context = class(THashContext)
  public
    constructor Create;
    class function DigestSize: Integer; override;
    class function BlockSize: Integer; override;
    class function AlgorithmName: string; override;
  end;

  TSHA1Context = class(THashContext)
  public
    constructor Create;
    class function DigestSize: Integer; override;
    class function BlockSize: Integer; override;
    class function AlgorithmName: string; override;
  end;

  TSHA256Context = class(THashContext)
  public
    constructor Create;
    class function DigestSize: Integer; override;
    class function BlockSize: Integer; override;
    class function AlgorithmName: string; override;
  end;

  TSHA384Context = class(THashContext)
  public
    constructor Create;
    class function DigestSize: Integer; override;
    class function BlockSize: Integer; override;
    class function AlgorithmName: string; override;
  end;

  TSHA512Context = class(THashContext)
  public
    constructor Create;
    class function DigestSize: Integer; override;
    class function BlockSize: Integer; override;
    class function AlgorithmName: string; override;
  end;

function MD5(const AData: TBytes): TBytes; overload;
function MD5(const AData: string): TBytes; overload;
function SHA1(const AData: TBytes): TBytes; overload;
function SHA1(const AData: string): TBytes; overload;
function SHA256(const AData: TBytes): TBytes; overload;
function SHA256(const AData: string): TBytes; overload;
function SHA384(const AData: TBytes): TBytes; overload;
function SHA384(const AData: string): TBytes; overload;
function SHA512(const AData: TBytes): TBytes; overload;
function SHA512(const AData: string): TBytes; overload;

function HashToHex(const AHash: TBytes): string;

function CreateHashContext(AAlgorithm: THashAlgorithm): THashContext;
function GetHashDigestSize(AAlgorithm: THashAlgorithm): Integer;
function GetHashBlockSize(AAlgorithm: THashAlgorithm): Integer;
function GetHashAlgorithmName(AAlgorithm: THashAlgorithm): string;

implementation

uses
  nextpas.core.hash.md5,
  nextpas.core.hash.sha1,
  nextpas.core.hash.sha256,
  nextpas.core.hash.sha512,
  nextpas.core.hash.util;

function StringToBytes(const S: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(S[1], Result[0], Length(S));
end;

function HashOf(AInner: IHasher; const AData: TBytes): TBytes;
begin
  if Length(AData) > 0 then
    AInner.Write(AData[0], Length(AData));
  Result := AInner.SumBytes;
end;

{ THashContext }

destructor THashContext.Destroy;
begin
  FInner := nil;
  inherited Destroy;
end;

procedure THashContext.BindInner(AInner: IHasher);
begin
  FInner := AInner;
end;

procedure THashContext.Update(const AData: TBytes);
begin
  if (FInner <> nil) and (Length(AData) > 0) then
    FInner.Write(AData[0], Length(AData));
end;

procedure THashContext.Update(const AData: string);
begin
  Update(StringToBytes(AData));
end;

procedure THashContext.Update(AStream: IStream);
const
  CHUNK = 8192;
var
  LBuf: array[0..CHUNK - 1] of Byte;
  LN: SizeUInt;
begin
  if (FInner = nil) or (AStream = nil) then
    Exit;
  repeat
    LN := AStream.Read(LBuf[0], CHUNK);
    if LN > 0 then
      FInner.Write(LBuf[0], LN);
  until LN = 0;
end;

function THashContext.Final: TBytes;
begin
  if FInner = nil then
  begin
    Result := nil;
    SetLength(Result, 0);
    Exit;
  end;
  Result := FInner.SumBytes;
end;

procedure THashContext.Reset;
begin
  if FInner <> nil then
    FInner.Reset;
end;

{ TMD5Context }

constructor TMD5Context.Create;
begin
  inherited Create;
  BindInner(nextpas.core.hash.md5.NewMD5);
end;

class function TMD5Context.DigestSize: Integer;
begin
  Result := 16;
end;

class function TMD5Context.BlockSize: Integer;
begin
  Result := 64;
end;

class function TMD5Context.AlgorithmName: string;
begin
  Result := 'MD5';
end;

{ TSHA1Context }

constructor TSHA1Context.Create;
begin
  inherited Create;
  BindInner(nextpas.core.hash.sha1.NewSHA1);
end;

class function TSHA1Context.DigestSize: Integer;
begin
  Result := 20;
end;

class function TSHA1Context.BlockSize: Integer;
begin
  Result := 64;
end;

class function TSHA1Context.AlgorithmName: string;
begin
  Result := 'SHA-1';
end;

{ TSHA256Context }

constructor TSHA256Context.Create;
begin
  inherited Create;
  BindInner(nextpas.core.hash.sha256.NewSHA256);
end;

class function TSHA256Context.DigestSize: Integer;
begin
  Result := 32;
end;

class function TSHA256Context.BlockSize: Integer;
begin
  Result := 64;
end;

class function TSHA256Context.AlgorithmName: string;
begin
  Result := 'SHA-256';
end;

{ TSHA384Context }

constructor TSHA384Context.Create;
begin
  inherited Create;
  BindInner(nextpas.core.hash.sha512.NewSHA384);
end;

class function TSHA384Context.DigestSize: Integer;
begin
  Result := 48;
end;

class function TSHA384Context.BlockSize: Integer;
begin
  Result := 128;
end;

class function TSHA384Context.AlgorithmName: string;
begin
  Result := 'SHA-384';
end;

{ TSHA512Context }

constructor TSHA512Context.Create;
begin
  inherited Create;
  BindInner(nextpas.core.hash.sha512.NewSHA512);
end;

class function TSHA512Context.DigestSize: Integer;
begin
  Result := 64;
end;

class function TSHA512Context.BlockSize: Integer;
begin
  Result := 128;
end;

class function TSHA512Context.AlgorithmName: string;
begin
  Result := 'SHA-512';
end;

function MD5(const AData: TBytes): TBytes;
begin
  Result := HashOf(nextpas.core.hash.md5.NewMD5, AData);
end;

function MD5(const AData: string): TBytes;
begin
  Result := MD5(StringToBytes(AData));
end;

function SHA1(const AData: TBytes): TBytes;
begin
  Result := HashOf(nextpas.core.hash.sha1.NewSHA1, AData);
end;

function SHA1(const AData: string): TBytes;
begin
  Result := SHA1(StringToBytes(AData));
end;

function SHA256(const AData: TBytes): TBytes;
begin
  Result := HashOf(nextpas.core.hash.sha256.NewSHA256, AData);
end;

function SHA256(const AData: string): TBytes;
begin
  Result := SHA256(StringToBytes(AData));
end;

function SHA384(const AData: TBytes): TBytes;
begin
  Result := HashOf(nextpas.core.hash.sha512.NewSHA384, AData);
end;

function SHA384(const AData: string): TBytes;
begin
  Result := SHA384(StringToBytes(AData));
end;

function SHA512(const AData: TBytes): TBytes;
begin
  Result := HashOf(nextpas.core.hash.sha512.NewSHA512, AData);
end;

function SHA512(const AData: string): TBytes;
begin
  Result := SHA512(StringToBytes(AData));
end;

function HashToHex(const AHash: TBytes): string;
begin
  if Length(AHash) = 0 then
  begin
    Result := '';
    Exit;
  end;
  Result := DigestToHex(AHash[0], Length(AHash));
end;

function CreateHashContext(AAlgorithm: THashAlgorithm): THashContext;
begin
  case AAlgorithm of
    haMD5: Result := TMD5Context.Create;
    haSHA1: Result := TSHA1Context.Create;
    haSHA256: Result := TSHA256Context.Create;
    haSHA384: Result := TSHA384Context.Create;
    haSHA512: Result := TSHA512Context.Create;
  else
    Result := nil;
  end;
end;

function GetHashDigestSize(AAlgorithm: THashAlgorithm): Integer;
begin
  case AAlgorithm of
    haMD5: Result := 16;
    haSHA1: Result := 20;
    haSHA256: Result := 32;
    haSHA384: Result := 48;
    haSHA512: Result := 64;
  else
    Result := 0;
  end;
end;

function GetHashBlockSize(AAlgorithm: THashAlgorithm): Integer;
begin
  case AAlgorithm of
    haMD5, haSHA1, haSHA256: Result := 64;
    haSHA384, haSHA512: Result := 128;
  else
    Result := 0;
  end;
end;

function GetHashAlgorithmName(AAlgorithm: THashAlgorithm): string;
begin
  case AAlgorithm of
    haMD5: Result := 'MD5';
    haSHA1: Result := 'SHA-1';
    haSHA256: Result := 'SHA-256';
    haSHA384: Result := 'SHA-384';
    haSHA512: Result := 'SHA-512';  else
    Result := '';
  end;
end;

end.
