unit nextpas.core.git.native.advertise;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.git.native.base,
  nextpas.core.git.native.pktline,
  nextpas.core.git.native.util;

{ Advertise refs parser (transport/smart_protocol.c, protocol-common.txt).

  Server advertises refs as a pkt-line stream:
    <oid 40Hex> SP <refname> [ NUL <caps SP-separated> ] LF
  The first ref line may carry capabilities after NUL; subsequent lines
  carry only oid+name. Stream terminates with a flush-pkt (0000).
  Delim-pkts (0001) are ignored if present. Peeled refs (name^{}) are
  treated as ordinary refs. }

type
  TGitAdvertisedRef = record
    Oid: TGitOid;
    Name: string;
  end;
  TGitAdvertisedRefArray = array of TGitAdvertisedRef;
  TGitAdvertised = record
    Refs: TGitAdvertisedRefArray;
    Capabilities: TStringArray;
  end;

function GitParseAdvertise(const AStream: TBytes): TGitAdvertised;
function GitParseAdvertisedRefs(const AStream: TBytes): TGitAdvertisedRefArray; inline;
function GitAdvertiseFind(const AAdv: TGitAdvertised; const AName: string; out ARef: TGitAdvertisedRef): Boolean;
function GitHasCapability(const AAdv: TGitAdvertised; const ACap: string): Boolean;

implementation

function SplitBySpace(const S: string): TStringArray; inline;
var
  I, Start: Integer;
  Tok: string;
  LCount, LCap: SizeUInt;
begin
  // perf: inline + amortized doubling via bytes.ops GrowArrayCapacity (BYTES_BUILDER_MIN_GROW + *2), single SetLength per growth, avoids O(n²) SetLength(...+1) churn; final shrink once
  // stability: SetLength is exception-safe; managed strings refcounted, no manual free, no leak on exception
  Result := nil;
  LCount := 0;
  LCap := 0;
  Start := 1;
  for I := 1 to Length(S) + 1 do
  begin
    if (I > Length(S)) or (S[I] = ' ') then
    begin
      if I > Start then
      begin
        Tok := Copy(S, Start, I - Start);
        if Tok <> '' then
        begin
          if LCount >= LCap then
          begin
            LCap := GrowArrayCapacity(LCap, LCount + 1);
            SetLength(Result, LCap);
          end;
          Result[LCount] := Tok;
          Inc(LCount);
        end;
      end;
      Start := I + 1;
    end;
  end;
  if SizeUInt(Length(Result)) <> LCount then
    SetLength(Result, LCount);
end;

function GitParseAdvertise(const AStream: TBytes): TGitAdvertised;
var
  Pkts: TGitPktArray;
  I: Integer;
  Line, OidHex, Rest, CapsStr: string;
  SpPos, NulPos: Integer;
  Ref: TGitAdvertisedRef;
  First: Boolean;
  LCount, LCap: SizeUInt;
begin
  // perf: Refs doubling via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), amortized O(1) per append, final single shrink; SplitBySpace already doubling
  // stability: SetLength exception-safe, managed array releases on exception, no manual header poke, no leak
  Result.Refs := nil;
  Result.Capabilities := nil;
  if Length(AStream) = 0 then
    Exit;
  Pkts := GitPktScan(AStream);
  First := True;
  LCount := 0;
  LCap := 0;
  for I := 0 to High(Pkts) do
  begin
    if Pkts[I].Kind = gpkFlush then
      Break;
    if Pkts[I].Kind = gpkDelim then
      Continue;
    // gpkData
    Line := GitBytesToString(Pkts[I].Data);
    // Git pkt payloads for advertise end with LF; allow missing LF for robustness but strip if present
    if (Length(Line) > 0) and (Line[Length(Line)] = #10) then
      SetLength(Line, Length(Line) - 1);
    if Line = '' then
      Continue;
    SpPos := Pos(' ', Line);
    if SpPos = 0 then
      raise EGitError.CreateFmt('advertise malformed line "%s"', [Line]);
    OidHex := Copy(Line, 1, SpPos - 1);
    if not GitOidIsValidHex(OidHex) then
      raise EGitError.CreateFmt('advertise bad oid "%s"', [OidHex]);
    Rest := Copy(Line, SpPos + 1, MaxInt);
    NulPos := Pos(#0, Rest);
    if NulPos > 0 then
    begin
      Ref.Name := Copy(Rest, 1, NulPos - 1);
      CapsStr := Copy(Rest, NulPos + 1, MaxInt);
      if First then
        Result.Capabilities := SplitBySpace(CapsStr);
      First := False;
    end
    else
    begin
      Ref.Name := Rest;
      First := False;
    end;
    if Ref.Name = '' then
      raise EGitError.Create('advertise empty ref name');
    Ref.Oid := GitOidFromHex(OidHex);
    if LCount >= LCap then
    begin
      LCap := GrowArrayCapacity(LCap, LCount + 1);
      SetLength(Result.Refs, LCap);
    end;
    Result.Refs[LCount] := Ref;
    Inc(LCount);
  end;
  if SizeUInt(Length(Result.Refs)) <> LCount then
    SetLength(Result.Refs, LCount);
end;

function GitParseAdvertisedRefs(const AStream: TBytes): TGitAdvertisedRefArray;
begin
  Result := GitParseAdvertise(AStream).Refs;
end;

function GitAdvertiseFind(const AAdv: TGitAdvertised; const AName: string; out ARef: TGitAdvertisedRef): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(AAdv.Refs) do
    if AAdv.Refs[I].Name = AName then
    begin
      ARef := AAdv.Refs[I];
      Exit(True);
    end;
  Result := False;
  ARef.Oid := Default(TGitOid);
  ARef.Name := '';
end;

function GitHasCapability(const AAdv: TGitAdvertised; const ACap: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(AAdv.Capabilities) do
    if AAdv.Capabilities[I] = ACap then
      Exit(True);
  Result := False;
end;

end.
