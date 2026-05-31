program test_session_cache_persistence_contract;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.session.cache;

type
  TMockSession = class(TInterfacedObject, ISSLSession)
  private
    FID: string;
    FValid: Boolean;
    FTimeout: Integer;
    FCreationTime: TDateTime;
  public
    constructor Create(const AID: string; AValid: Boolean);

    function GetID: string;
    function GetCreationTime: TDateTime;
    function GetTimeout: Integer;
    procedure SetTimeout(ATimeout: Integer);
    function IsValid: Boolean;
    function IsResumable: Boolean;
    function GetProtocolVersion: TSSLProtocolVersion;
    function GetCipherName: string;
    function GetPeerCertificate: ISSLCertificate;
    function Serialize: TBytes;
    function Deserialize(const AData: TBytes): Boolean;
    function Clone: ISSLSession;
  end;

constructor TMockSession.Create(const AID: string; AValid: Boolean);
begin
  inherited Create;
  FID := AID;
  FValid := AValid;
  FTimeout := 300;
  FCreationTime := Now;
end;

function TMockSession.GetID: string;
begin
  Result := FID;
end;

function TMockSession.GetCreationTime: TDateTime;
begin
  Result := FCreationTime;
end;

function TMockSession.GetTimeout: Integer;
begin
  Result := FTimeout;
end;

procedure TMockSession.SetTimeout(ATimeout: Integer);
begin
  FTimeout := ATimeout;
end;

function TMockSession.IsValid: Boolean;
begin
  Result := FValid;
end;

function TMockSession.IsResumable: Boolean;
begin
  Result := FValid;
end;

function TMockSession.GetProtocolVersion: TSSLProtocolVersion;
begin
  Result := sslProtocolTLS13;
end;

function TMockSession.GetCipherName: string;
begin
  Result := 'TLS_AES_128_GCM_SHA256';
end;

function TMockSession.GetPeerCertificate: ISSLCertificate;
begin
  Result := nil;
end;

function TMockSession.Serialize: TBytes;
var
  LUtf8: UTF8String;
begin
  LUtf8 := UTF8String(FID);
  Result := BytesOf(LUtf8);
end;

function TMockSession.Deserialize(const AData: TBytes): Boolean;
var
  LUtf8: UTF8String;
begin
  Result := Length(AData) > 0;
  if not Result then
    Exit;

  SetString(LUtf8, PAnsiChar(@AData[0]), Length(AData));
  FID := string(LUtf8);
  FValid := True;
end;

function TMockSession.Clone: ISSLSession;
begin
  Result := TMockSession.Create(FID, FValid);
end;

procedure Require(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('[FAIL] ', AMessage);
    Halt(1);
  end;
  WriteLn('[PASS] ', AMessage);
end;

function CreateSessionFromBytes(const AData: TBytes): ISSLSession;
var
  LSession: TMockSession;
begin
  Result := nil;
  LSession := TMockSession.Create('', False);
  if LSession.Deserialize(AData) then
    Result := LSession
  else
    LSession.Free;
end;

procedure TestSaveLoadSkipsInvalidEntriesWithoutCorruptingCount;
var
  LSourceCache: TSSLSessionCache;
  LLoadedCache: TSSLSessionCache;
  LValidSession: ISSLSession;
  LInvalidSession: ISSLSession;
  LLoadedSession: ISSLSession;
  LTempFile: string;
  LSharedKey: TBytes;
begin
  WriteLn('=== Session Cache Persistence Count Contract ===');

  LTempFile := 'tmp/test_session_cache_persistence_contract.dat';
  SetLength(LSharedKey, 32);
  FillChar(LSharedKey[0], 32, $AA);
  ForceDirectories(ExtractFileDir(LTempFile));
  DeleteFile(LTempFile);

  LSourceCache := TSSLSessionCache.Create;
  try
    LSourceCache.SetPersistenceKey(LSharedKey);
    LValidSession := TMockSession.Create('valid-session', True);
    LInvalidSession := TMockSession.Create('invalid-session', False);

    LSourceCache.Put('valid.example', 443, LValidSession);
    LSourceCache.Put('invalid.example', 443, LInvalidSession);

    Require(LSourceCache.SaveToFile(LTempFile),
      'SaveToFile succeeds when cache contains invalid entries');
  finally
    LSourceCache.Free;
  end;

  LLoadedCache := TSSLSessionCache.Create;
  try
    LLoadedCache.SetPersistenceKey(LSharedKey);
    LLoadedCache.SetSessionCreateFunc(@CreateSessionFromBytes);
    Require(LLoadedCache.LoadFromFile(LTempFile),
      'LoadFromFile succeeds after SaveToFile skipped invalid entries');
    Require(LLoadedCache.GetCount = 1,
      'Only persistable valid session is restored');

    LLoadedSession := LLoadedCache.Get('valid.example', 443);
    Require(LLoadedSession <> nil,
      'Valid persisted session can be loaded back');
    Require(LLoadedSession.GetID = 'valid-session',
      'Loaded session keeps serialized identifier');
    Require(not LLoadedCache.Contains('invalid.example', 443),
      'Invalid skipped session is not materialized on load');
  finally
    LLoadedCache.Free;
    DeleteFile(LTempFile);
  end;
end;

begin
  TestSaveLoadSkipsInvalidEntriesWithoutCorruptingCount;
end.
