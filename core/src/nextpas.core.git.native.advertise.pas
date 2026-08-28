unit nextpas.core.git.native.advertise;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.pktline;

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

function BytesToStr(const B: TBytes): string;
begin
  SetLength(Result, Length(B));
  if Length(B) > 0 then
    Move(B[0], Result[1], Length(B));
end;

function SplitBySpace(const S: string): TStringArray;
var
  I, Start: Integer;
  Tok: string;
begin
  Result := nil;
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
          SetLength(Result, Length(Result) + 1);
          Result[High(Result)] := Tok;
        end;
      end;
      Start := I + 1;
    end;
  end;
end;

function IsHex40(const S: string): Boolean;
var
  I: Integer;
  C: Char;
begin
  if Length(S) <> 40 then Exit(False);
  for I := 1 to 40 do
  begin
    C := S[I];
    if not (((C >= '0') and (C <= '9')) or ((C >= 'a') and (C <= 'f')) or ((C >= 'A') and (C <= 'F'))) then
      Exit(False);
  end;
  Result := True;
end;

function GitParseAdvertise(const AStream: TBytes): TGitAdvertised;
var
  Pkts: TGitPktArray;
  I: Integer;
  Line, OidHex, Rest, CapsStr: string;
  SpPos, NulPos: Integer;
  Ref: TGitAdvertisedRef;
  First: Boolean;
begin
  Result.Refs := nil;
  Result.Capabilities := nil;
  if Length(AStream) = 0 then
    Exit;
  Pkts := GitPktScan(AStream);
  First := True;
  for I := 0 to High(Pkts) do
  begin
    if Pkts[I].Kind = gpkFlush then
      Break;
    if Pkts[I].Kind = gpkDelim then
      Continue;
    // gpkData
    Line := BytesToStr(Pkts[I].Data);
    // Git pkt payloads for advertise end with LF; allow missing LF for robustness but strip if present
    if (Length(Line) > 0) and (Line[Length(Line)] = #10) then
      SetLength(Line, Length(Line) - 1);
    if Line = '' then
      Continue;
    SpPos := Pos(' ', Line);
    if SpPos = 0 then
      raise EGitError.CreateFmt('advertise malformed line "%s"', [Line]);
    OidHex := Copy(Line, 1, SpPos - 1);
    if not IsHex40(OidHex) then
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
    SetLength(Result.Refs, Length(Result.Refs) + 1);
    Result.Refs[High(Result.Refs)] := Ref;
  end;
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
