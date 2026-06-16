{**
 * Unit: nextpas.core.tls.freepascal.session
 * Purpose: 纯 FreePascal TLS 1.3 session resumption 对象
 *}

unit nextpas.core.tls.freepascal.session;

{$mode ObjFPC}{$H+}

interface

uses DateUtils, SysUtils, nextpas.core.base, nextpas.core.time, nextpas.core.tls.base;

type
  IFreePascalResumptionSession = interface
    ['{8B299319-9203-4AE2-AB12-A854691AA91E}']
    function GetCipherSuite: Word;
    function GetTicketLifetime: Cardinal;
    function GetTicketAgeAdd: Cardinal;
    function GetMaxEarlyDataSize: Cardinal;
    function GetTicketNonce: TBytes;
    function GetTicket: TBytes;
    function GetResumptionPSK: TBytes;
  end;

  IFreePascalResumptionCache = interface
    ['{E30D1A5A-1F53-4212-A195-C37B7AF694A3}']
    function CanIssueSessionTickets: Boolean;
    function TryGetResumptionSession(const ATicket: TBytes; out ASession: ISSLSession): Boolean;
    procedure StoreResumptionSession(ASession: ISSLSession);
  end;

  IFreePascalEarlyDataReplayLedger = interface
    ['{68B2A2F2-579F-4A04-BE4E-12AA0F1B61EE}']
    function TryAcquireEarlyDataSession(ASession: ISSLSession): Boolean;
  end;

  TFreePascalEarlyDataReplayStoreEntry = record
    Key: string;
    ExpiresAt: TDateTime;
  end;

  TFreePascalEarlyDataReplayStoreEntries = array of TFreePascalEarlyDataReplayStoreEntry;

  IFreePascalEarlyDataReplayStoreGuard = interface
    ['{B1FCE328-2DCA-44B0-B9FA-9CFF4B5954B6}']
  end;

  IFreePascalEarlyDataReplayStore = interface
    ['{CCF25AE5-3E0B-42B3-A0FD-0C7DA4723875}']
    function AcquireUpdateGuard(
      out AGuard: IFreePascalEarlyDataReplayStoreGuard
    ): Boolean;
    function LoadEntries(out AEntries: TFreePascalEarlyDataReplayStoreEntries): Boolean;
    function SaveEntries(const AEntries: TFreePascalEarlyDataReplayStoreEntries): Boolean;
  end;

  IFreePascalEarlyDataReplayProvider = interface
    ['{E9F5664D-A8B9-4B2A-A1B2-74E35C64E0F3}']
    function TryAcquireReplayKey(
      const AKey: string;
      AExpiresAt: TDateTime;
      ANow: TDateTime
    ): Boolean;
  end;

  IFreePascalManagedEarlyDataReplayLedger = interface(IFreePascalEarlyDataReplayLedger)
    ['{88E563C1-BE02-46C6-BF6D-4D0732B27007}']
    procedure Clear;
    procedure SetEnabled(AEnabled: Boolean);
    procedure SetCapacity(ACapacity: Integer);
  end;

  IFreePascalEarlyDataReplayLedgerAccess = interface
    ['{1D11D969-1F1D-411F-B8A6-DDE6B1EF86C1}']
    function GetEarlyDataReplayLedger: IFreePascalEarlyDataReplayLedger;
    procedure SetEarlyDataReplayLedger(ALedger: IFreePascalEarlyDataReplayLedger);
    procedure ResetEarlyDataReplayLedger;
  end;

  IFreePascalTLS12ResumptionSession = interface
    ['{A4C7E912-3B5F-4D8A-9E1C-6F2A8B0D4C7E}']
    function GetTLS12SessionID: TBytes;
    function GetTLS12MasterSecret: TBytes;
    function GetTLS12CipherSuite: Word;
  end;

  TFreePascalSession = class(TInterfacedObject, ISSLSession, IFreePascalResumptionSession,
    IFreePascalTLS12ResumptionSession)
  private
    FSessionID: string;
    FCreationTime: TDateTime;
    FTimeout: Integer;
    FProtocolVersion: TSSLProtocolVersion;
    FCipherName: string;
    FCipherSuite: Word;
    FTicketLifetime: Cardinal;
    FTicketAgeAdd: Cardinal;
    FMaxEarlyDataSize: Cardinal;
    FTicketNonce: TBytes;
    FTicket: TBytes;
    FResumptionPSK: TBytes;
    FBoundServerName: string;
    FTLS12SessionID: TBytes;
    FTLS12MasterSecret: TBytes;

    function ComputeEffectiveTimeout: Integer;
    procedure RefreshSessionID;
  public
    constructor Create;
    destructor Destroy; override;

    procedure ConfigureResumption(
      ACipherSuite: Word;
      const ACipherName: string;
      const ATicketNonce, ATicket, AResumptionPSK: TBytes;
      ATicketLifetime, ATicketAgeAdd: Cardinal;
      ACreationTime: TDateTime;
      ATimeout: Integer;
      AMaxEarlyDataSize: Cardinal = 0
    );

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

    function GetCipherSuite: Word;
    function GetTicketLifetime: Cardinal;
    function GetTicketAgeAdd: Cardinal;
    function GetMaxEarlyDataSize: Cardinal;
    function GetTicketNonce: TBytes;
    function GetTicket: TBytes;
    function GetResumptionPSK: TBytes;

    function GetTLS12SessionID: TBytes;
    function GetTLS12MasterSecret: TBytes;
    function GetTLS12CipherSuite: Word;

    procedure ConfigureTLS12Resumption(
      ACipherSuite: Word;
      const ACipherName: string;
      const ASessionID, AMasterSecret: TBytes;
      ACreationTime: TDateTime;
      ATimeout: Integer
    );

    property BoundServerName: string read FBoundServerName write FBoundServerName;
  end;

implementation

uses nextpas.core.tls.tls13.wire;

const
  FREEPASCAL_SESSION_MAGIC: array[0..3] of Byte = ($46, $50, $53, $31); // FPS1
  FREEPASCAL_SESSION_VERSION = 3;
  FREEPASCAL_SESSION_VERSION_V1 = 1;
  FREEPASCAL_SESSION_VERSION_V2 = 2;
  FREEPASCAL_SESSION_VERSION_V3 = 3;
  HEX_DIGITS: array[0..15] of Char = '0123456789abcdef';

procedure AppendUInt32(var ADest: TBytes; AValue: Cardinal);
begin
  AppendByte(ADest, Byte((AValue shr 24) and $FF));
  AppendByte(ADest, Byte((AValue shr 16) and $FF));
  AppendByte(ADest, Byte((AValue shr 8) and $FF));
  AppendByte(ADest, Byte(AValue and $FF));
end;

procedure AppendUInt64(var ADest: TBytes; AValue: QWord);
var
  I: Integer;
begin
  for I := 7 downto 0 do
    AppendByte(ADest, Byte((AValue shr (I * 8)) and $FF));
end;

function ReadUInt32(const AData: TBytes; AOffset: Integer): Cardinal;
begin
  if (AOffset < 0) or (AOffset + 3 >= Length(AData)) then
    raise Exception.Create('Invalid uint32 offset');

  Result :=
    (Cardinal(AData[AOffset]) shl 24) or
    (Cardinal(AData[AOffset + 1]) shl 16) or
    (Cardinal(AData[AOffset + 2]) shl 8) or
    Cardinal(AData[AOffset + 3]);
end;

function ReadUInt64(const AData: TBytes; AOffset: Integer): QWord;
var
  I: Integer;
begin
  if (AOffset < 0) or (AOffset + 7 >= Length(AData)) then
    raise Exception.Create('Invalid uint64 offset');

  Result := 0;
  for I := 0 to 7 do
    Result := (Result shl 8) or QWord(AData[AOffset + I]);
end;

procedure AppendVector16(var ADest: TBytes; const AValue: TBytes);
begin
  AppendUInt16(ADest, Word(Length(AValue)));
  AppendBytes(ADest, AValue);
end;

function ReadVector16(const AData: TBytes; var AOffset: Integer): TBytes;
var
  LLen: Integer;
begin
  if AOffset + 2 > Length(AData) then
    raise Exception.Create('Missing vector16 length');

  LLen := ReadUInt16(AData, AOffset);
  Inc(AOffset, 2);
  if AOffset + LLen > Length(AData) then
    raise Exception.Create('vector16 exceeds payload');

  Result := nil;
  SetLength(Result, LLen);
  if LLen > 0 then
    Move(AData[AOffset], Result[0], LLen);
  Inc(AOffset, LLen);
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  SetLength(Result, Length(AData) * 2);
  for I := 0 to High(AData) do
  begin
    Result[I * 2 + 1] := HEX_DIGITS[(AData[I] shr 4) and $0F];
    Result[I * 2 + 2] := HEX_DIGITS[AData[I] and $0F];
  end;
end;

constructor TFreePascalSession.Create;
begin
  inherited Create;
  FSessionID := '';
  FCreationTime := DateTimeNow;
  FTimeout := SSL_DEFAULT_SESSION_TIMEOUT;
  FProtocolVersion := sslProtocolTLS13;
  FCipherName := '';
  FCipherSuite := 0;
  FTicketLifetime := 0;
  FTicketAgeAdd := 0;
  FMaxEarlyDataSize := 0;
  SetLength(FTicketNonce, 0);
  SetLength(FTicket, 0);
  SetLength(FResumptionPSK, 0);
  FBoundServerName := '';
end;

destructor TFreePascalSession.Destroy;
begin
  if Length(FResumptionPSK) > 0 then
    FillChar(FResumptionPSK[0], Length(FResumptionPSK), 0);
  if Length(FTLS12MasterSecret) > 0 then
    FillChar(FTLS12MasterSecret[0], Length(FTLS12MasterSecret), 0);
  if Length(FTicketNonce) > 0 then
    FillChar(FTicketNonce[0], Length(FTicketNonce), 0);
  if Length(FTicket) > 0 then
    FillChar(FTicket[0], Length(FTicket), 0);
  if Length(FTLS12SessionID) > 0 then
    FillChar(FTLS12SessionID[0], Length(FTLS12SessionID), 0);
  inherited Destroy;
end;

procedure TFreePascalSession.ConfigureResumption(
  ACipherSuite: Word;
  const ACipherName: string;
  const ATicketNonce, ATicket, AResumptionPSK: TBytes;
  ATicketLifetime, ATicketAgeAdd: Cardinal;
  ACreationTime: TDateTime;
  ATimeout: Integer;
  AMaxEarlyDataSize: Cardinal
);
begin
  FCipherSuite := ACipherSuite;
  FCipherName := ACipherName;
  FTicketLifetime := ATicketLifetime;
  FTicketAgeAdd := ATicketAgeAdd;
  FMaxEarlyDataSize := AMaxEarlyDataSize;
  FTicketNonce := Copy(ATicketNonce);
  FTicket := Copy(ATicket);
  FResumptionPSK := Copy(AResumptionPSK);
  FCreationTime := ACreationTime;
  FTimeout := ATimeout;
  FProtocolVersion := sslProtocolTLS13;
  RefreshSessionID;
end;

procedure TFreePascalSession.ConfigureTLS12Resumption(
  ACipherSuite: Word;
  const ACipherName: string;
  const ASessionID, AMasterSecret: TBytes;
  ACreationTime: TDateTime;
  ATimeout: Integer
);
begin
  FCipherSuite := ACipherSuite;
  FCipherName := ACipherName;
  FTLS12SessionID := Copy(ASessionID);
  FTLS12MasterSecret := Copy(AMasterSecret);
  FCreationTime := ACreationTime;
  FTimeout := ATimeout;
  FProtocolVersion := sslProtocolTLS12;
  FSessionID := BytesToHex(Copy(ASessionID, 0, 8));
end;

function TFreePascalSession.ComputeEffectiveTimeout: Integer;
begin
  Result := FTimeout;
  if (FTicketLifetime > 0) and ((Result <= 0) or (Integer(FTicketLifetime) < Result)) then
    Result := Integer(FTicketLifetime);
end;

procedure TFreePascalSession.RefreshSessionID;
var
  LPrefix: TBytes;
begin
  if Length(FTicket) = 0 then
  begin
    FSessionID := '';
    Exit;
  end;

  LPrefix := Copy(FTicket, 0, 8);
  FSessionID := BytesToHex(LPrefix);
end;

function TFreePascalSession.GetID: string;
begin
  Result := FSessionID;
end;

function TFreePascalSession.GetCreationTime: TDateTime;
begin
  Result := FCreationTime;
end;

function TFreePascalSession.GetTimeout: Integer;
begin
  Result := FTimeout;
end;

procedure TFreePascalSession.SetTimeout(ATimeout: Integer);
begin
  FTimeout := ATimeout;
end;

function TFreePascalSession.IsValid: Boolean;
var
  LElapsedSeconds: Int64;
  LTimeout: Integer;
begin
  Result := False;
  if FCipherSuite = 0 then
    Exit;

  if FProtocolVersion = sslProtocolTLS12 then
  begin
    if (Length(FTLS12SessionID) = 0) or (Length(FTLS12MasterSecret) = 0) then
      Exit;
  end
  else
  begin
    if (Length(FTicket) = 0) or (Length(FResumptionPSK) = 0) then
      Exit;
  end;

  LTimeout := ComputeEffectiveTimeout;
  if LTimeout <= 0 then
    Exit(True);

  LElapsedSeconds := DateTimeSecondsBetween(DateTimeNow, FCreationTime);
  Result := LElapsedSeconds < LTimeout;
end;

function TFreePascalSession.IsResumable: Boolean;
begin
  Result := IsValid and (FProtocolVersion in [sslProtocolTLS13, sslProtocolTLS12]);
end;

function TFreePascalSession.GetProtocolVersion: TSSLProtocolVersion;
begin
  Result := FProtocolVersion;
end;

function TFreePascalSession.GetCipherName: string;
begin
  Result := FCipherName;
end;

function TFreePascalSession.GetPeerCertificate: ISSLCertificate;
begin
  Result := nil;
end;

function TFreePascalSession.Serialize: TBytes;
var
  LUnixTime: QWord;
  LCipherBytes: TBytes;
begin
  Result := nil;

  AppendByte(Result, FREEPASCAL_SESSION_MAGIC[0]);
  AppendByte(Result, FREEPASCAL_SESSION_MAGIC[1]);
  AppendByte(Result, FREEPASCAL_SESSION_MAGIC[2]);
  AppendByte(Result, FREEPASCAL_SESSION_MAGIC[3]);
  AppendByte(Result, FREEPASCAL_SESSION_VERSION);
  AppendByte(Result, Byte(FProtocolVersion));
  AppendUInt16(Result, FCipherSuite);
  AppendUInt32(Result, Cardinal(FTimeout));
  AppendUInt32(Result, FTicketLifetime);
  AppendUInt32(Result, FTicketAgeAdd);
  AppendUInt32(Result, FMaxEarlyDataSize);

  if FCreationTime > 0 then
    LUnixTime := QWord(DateTimeToUnix(FCreationTime))
  else
    LUnixTime := 0;
  AppendUInt64(Result, LUnixTime);

  AppendVector16(Result, FTicketNonce);
  AppendVector16(Result, FTicket);
  AppendVector16(Result, FResumptionPSK);
  LCipherBytes := BytesOf(FCipherName);
  AppendVector16(Result, LCipherBytes);
  AppendVector16(Result, BytesOf(FBoundServerName));
  AppendVector16(Result, FTLS12SessionID);
  AppendVector16(Result, FTLS12MasterSecret);
end;

function TFreePascalSession.Deserialize(const AData: TBytes): Boolean;
var
  LOffset: Integer;
  LVersion: Byte;
  LUnixTime: QWord;
  LCipherBytes: TBytes;
begin
  Result := False;
  if Length(AData) < 4 + 1 then
    Exit;

  if not CompareMem(@AData[0], @FREEPASCAL_SESSION_MAGIC[0], Length(FREEPASCAL_SESSION_MAGIC)) then
    Exit;
  LVersion := AData[4];
  if (LVersion <> FREEPASCAL_SESSION_VERSION_V1) and
    (LVersion <> FREEPASCAL_SESSION_VERSION_V2) and
    (LVersion <> FREEPASCAL_SESSION_VERSION_V3) then
    Exit;
  if (LVersion = FREEPASCAL_SESSION_VERSION_V1) and
    (Length(AData) < 4 + 1 + 1 + 2 + 4 + 4 + 4 + 8) then
    Exit;
  if (LVersion = FREEPASCAL_SESSION_VERSION_V2) and
    (Length(AData) < 4 + 1 + 1 + 2 + 4 + 4 + 4 + 4 + 8) then
    Exit;

  LOffset := 5;
  FProtocolVersion := TSSLProtocolVersion(AData[LOffset]);
  Inc(LOffset);
  FCipherSuite := ReadUInt16(AData, LOffset);
  Inc(LOffset, 2);
  FTimeout := Integer(ReadUInt32(AData, LOffset));
  Inc(LOffset, 4);
  FTicketLifetime := ReadUInt32(AData, LOffset);
  Inc(LOffset, 4);
  FTicketAgeAdd := ReadUInt32(AData, LOffset);
  Inc(LOffset, 4);
  if LVersion >= FREEPASCAL_SESSION_VERSION_V2 then
  begin
    FMaxEarlyDataSize := ReadUInt32(AData, LOffset);
    Inc(LOffset, 4);
  end
  else
    FMaxEarlyDataSize := 0;
  LUnixTime := ReadUInt64(AData, LOffset);
  Inc(LOffset, 8);

  if LUnixTime > 0 then
    FCreationTime := UnixToDateTime(Int64(LUnixTime))
  else
    FCreationTime := 0;

  FTicketNonce := ReadVector16(AData, LOffset);
  FTicket := ReadVector16(AData, LOffset);
  FResumptionPSK := ReadVector16(AData, LOffset);
  LCipherBytes := ReadVector16(AData, LOffset);
  if Length(LCipherBytes) > 0 then
    SetString(FCipherName, PAnsiChar(@LCipherBytes[0]), Length(LCipherBytes))
  else
    FCipherName := '';

  { BoundServerName: optional trailing field for backward compatibility }
  if LOffset < Length(AData) then
  begin
    LCipherBytes := ReadVector16(AData, LOffset);
    if Length(LCipherBytes) > 0 then
      SetString(FBoundServerName, PAnsiChar(@LCipherBytes[0]), Length(LCipherBytes))
    else
      FBoundServerName := '';
  end
  else
    FBoundServerName := '';

  SetLength(FTLS12SessionID, 0);
  SetLength(FTLS12MasterSecret, 0);
  if LOffset < Length(AData) then
  begin
    FTLS12SessionID := ReadVector16(AData, LOffset);
    if LOffset < Length(AData) then
      FTLS12MasterSecret := ReadVector16(AData, LOffset);
  end;

  if (FProtocolVersion = sslProtocolTLS12) and (Length(FTLS12SessionID) > 0) then
    FSessionID := BytesToHex(Copy(FTLS12SessionID, 0, 8))
  else
    RefreshSessionID;
  Result := True;
end;

function TFreePascalSession.Clone: ISSLSession;
var
  LClone: TFreePascalSession;
begin
  LClone := TFreePascalSession.Create;
  LClone.FSessionID := FSessionID;
  LClone.FCreationTime := FCreationTime;
  LClone.FTimeout := FTimeout;
  LClone.FProtocolVersion := FProtocolVersion;
  LClone.FCipherName := FCipherName;
  LClone.FCipherSuite := FCipherSuite;
  LClone.FTicketLifetime := FTicketLifetime;
  LClone.FTicketAgeAdd := FTicketAgeAdd;
  LClone.FMaxEarlyDataSize := FMaxEarlyDataSize;
  LClone.FTicketNonce := Copy(FTicketNonce);
  LClone.FTicket := Copy(FTicket);
  LClone.FResumptionPSK := Copy(FResumptionPSK);
  LClone.FBoundServerName := FBoundServerName;
  LClone.FTLS12SessionID := Copy(FTLS12SessionID);
  LClone.FTLS12MasterSecret := Copy(FTLS12MasterSecret);
  Result := LClone;
end;

function TFreePascalSession.GetCipherSuite: Word;
begin
  Result := FCipherSuite;
end;

function TFreePascalSession.GetTicketLifetime: Cardinal;
begin
  Result := FTicketLifetime;
end;

function TFreePascalSession.GetTicketAgeAdd: Cardinal;
begin
  Result := FTicketAgeAdd;
end;

function TFreePascalSession.GetMaxEarlyDataSize: Cardinal;
begin
  Result := FMaxEarlyDataSize;
end;

function TFreePascalSession.GetTicketNonce: TBytes;
begin
  Result := Copy(FTicketNonce);
end;

function TFreePascalSession.GetTicket: TBytes;
begin
  Result := Copy(FTicket);
end;

function TFreePascalSession.GetResumptionPSK: TBytes;
begin
  Result := Copy(FResumptionPSK);
end;

function TFreePascalSession.GetTLS12SessionID: TBytes;
begin
  Result := Copy(FTLS12SessionID);
end;

function TFreePascalSession.GetTLS12MasterSecret: TBytes;
begin
  Result := Copy(FTLS12MasterSecret);
end;

function TFreePascalSession.GetTLS12CipherSuite: Word;
begin
  Result := FCipherSuite;
end;

end.
