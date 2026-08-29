unit nextpas.core.audio.bank;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.audio.base;

type
  TAudioBankEntry = record
    Id: string;
    Buffer: TAudioBuffer;
    Tags: TAudioTags;
  end;

  TAudioBank = class
  private
    FEntries: array of TAudioBankEntry;
    FLock: TRTLCriticalSection;
    function FindIndex(const AId: string): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const AId: string; const ABuffer: TAudioBuffer; const ATags: TAudioTags);
    function TryGet(const AId: string; out AEntry: TAudioBankEntry): Boolean;
    function Count: Integer;
    procedure Clear;
    function PackToBytes: TBytes;
    procedure LoadFromBytes(const AData: TBytes);
  end;

function CreateAudioBank: TAudioBank;

implementation

uses
  nextpas.core.audio.errors;

function CreateAudioBank: TAudioBank;
begin
  Result := TAudioBank.Create;
end;

constructor TAudioBank.Create;
begin
  inherited Create;
  InitCriticalSection(FLock);
end;

destructor TAudioBank.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited;
end;

function TAudioBank.FindIndex(const AId: string): Integer;
var I: Integer;
begin
  for I := 0 to High(FEntries) do
    if FEntries[I].Id = AId then Exit(I);
  Result := -1;
end;

procedure TAudioBank.Add(const AId: string; const ABuffer: TAudioBuffer; const ATags: TAudioTags);
var L: Integer;
begin
  if AId = '' then Exit;
  EnterCriticalSection(FLock);
  try
    if FindIndex(AId) >= 0 then Exit;
    L := Length(FEntries);
    SetLength(FEntries, L + 1);
    FEntries[L].Id := AId;
    FEntries[L].Buffer := ABuffer;
    FEntries[L].Tags := ATags;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TAudioBank.TryGet(const AId: string; out AEntry: TAudioBankEntry): Boolean;
var I: Integer;
begin
  Result := False;
  EnterCriticalSection(FLock);
  try
    I := FindIndex(AId);
    if I < 0 then Exit;
    AEntry := FEntries[I];
    Result := True;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TAudioBank.Count: Integer;
begin
  EnterCriticalSection(FLock);
  try Result := Length(FEntries);
  finally LeaveCriticalSection(FLock); end;
end;

procedure TAudioBank.Clear;
begin
  EnterCriticalSection(FLock);
  try SetLength(FEntries, 0);
  finally LeaveCriticalSection(FLock); end;
end;

function TAudioBank.PackToBytes: TBytes;
var I, P, K: Integer; LIdBytes: TBytes; LId: string; LNeed: Integer;
begin
  Result := nil;
  EnterCriticalSection(FLock);
  try
    // single grow calc avoids per-entry realloc churn; still O(n) but predictable
    LNeed := 4;
    for I := 0 to High(FEntries) do
      LNeed := LNeed + 4 + Length(FEntries[I].Id) + 4;
    if LNeed > 16*1024*1024 then
      raise EAudioError.Create('PackToBytes: too large');
    SetLength(Result, LNeed);
    Result[0] := Byte(Length(FEntries) and $FF);
    Result[1] := Byte((Length(FEntries) shr 8) and $FF);
    Result[2] := Byte((Length(FEntries) shr 16) and $FF);
    Result[3] := Byte((Length(FEntries) shr 24) and $FF);
    P := 4;
    for I := 0 to High(FEntries) do
    begin
      LId := FEntries[I].Id;
      SetLength(LIdBytes, Length(LId));
      for K := 1 to Length(LId) do
        LIdBytes[K-1] := Byte(Ord(LId[K]) and $FF);
      Result[P] := Byte(Length(LIdBytes) and $FF);
      Result[P+1] := Byte((Length(LIdBytes) shr 8) and $FF);
      Result[P+2] := Byte((Length(LIdBytes) shr 16) and $FF);
      Result[P+3] := Byte((Length(LIdBytes) shr 24) and $FF);
      if Length(LIdBytes) > 0 then
        Move(LIdBytes[0], Result[P+4], Length(LIdBytes));
      P := P + 4 + Length(LIdBytes);
      Result[P] := Byte(FEntries[I].Buffer.FrameCount and $FF);
      Result[P+1] := Byte((FEntries[I].Buffer.FrameCount shr 8) and $FF);
      Result[P+2] := Byte((FEntries[I].Buffer.FrameCount shr 16) and $FF);
      Result[P+3] := Byte((FEntries[I].Buffer.FrameCount shr 24) and $FF);
      Inc(P, 4);
    end;
    // trim to actual P (LNeed already exact, but keep for safety)
    if P <> Length(Result) then SetLength(Result, P);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TAudioBank.LoadFromBytes(const AData: TBytes);
var Cnt, I, P, LIdLen, LFrames, K: Integer; LId: string;
  function LE32(AP: Integer): Integer; inline;
  begin Result := Integer(AData[AP]) or (Integer(AData[AP+1]) shl 8) or (Integer(AData[AP+2]) shl 16) or (Integer(AData[AP+3]) shl 24); end;
begin
  EnterCriticalSection(FLock);
  try
    SetLength(FEntries, 0);
    if Length(AData) < 4 then Exit;
    Cnt := LE32(0);
    if Cnt < 0 then Cnt := 0;
    if Cnt > 10000 then Cnt := 10000;
    P := 4;
    for I := 0 to Cnt - 1 do
    begin
      if P + 4 > Length(AData) then Break;
      LIdLen := LE32(P);
      Inc(P, 4);
      if (LIdLen < 0) or (P + LIdLen > Length(AData)) then Break;
      if LIdLen > 0 then
      begin
        SetLength(LId, LIdLen);
        for K := 0 to LIdLen - 1 do
          LId[K+1] := Chr(AData[P + K]);
      end
      else
        LId := '';
      Inc(P, LIdLen);
      if P + 4 > Length(AData) then Break;
      LFrames := LE32(P);
      Inc(P, 4);
      SetLength(FEntries, Length(FEntries) + 1);
      FEntries[High(FEntries)].Id := LId;
      FEntries[High(FEntries)].Buffer.FrameCount := LFrames;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

end.
