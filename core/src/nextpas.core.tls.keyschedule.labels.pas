unit nextpas.core.tls.keyschedule.labels;

{$mode objfpc}{$H+}

{ TLS 1.3 HKDF-Expand-Label (RFC 8446 §7.1)

  HkdfLabel = struct {
    uint16 length;
    opaque label<7..255> = "tls13 " + Label;
    opaque context<0..255> = Context;
  };
}

interface


function TLS13_HKDF_Expand_Label_SHA256(
  const ASecret: TBytes;
  const ALabel: string;
  const AContext: TBytes;
  ALength: Integer
): TBytes;

function TLS13_HKDF_Expand_Label_SHA384(
  const ASecret: TBytes;
  const ALabel: string;
  const AContext: TBytes;
  ALength: Integer
): TBytes;

function BuildTLS13HKDFLabel(const ALabel: string; const AContext: TBytes; ALength: Integer): TBytes;

implementation

uses nextpas.core.crypto.hkdf, nextpas.core.hash.base, nextpas.core.tls.tls13.wire;

function BuildTLS13HKDFLabel(const ALabel: string; const AContext: TBytes; ALength: Integer): TBytes;
var
  LFullLabel: AnsiString;
  LLabelLen, LContextLen: Integer;
  I: Integer;
begin
  LFullLabel := AnsiString('tls13 ' + ALabel);
  LLabelLen := Length(LFullLabel);
  LContextLen := Length(AContext);

  Result := nil;
  AppendUInt16(Result, Word(ALength));
  AppendByte(Result, Byte(LLabelLen));
  SetLength(Result, Length(Result) + LLabelLen);
  for I := 1 to LLabelLen do
    Result[Length(Result) - LLabelLen + I - 1] := Byte(LFullLabel[I]);
  AppendByte(Result, Byte(LContextLen));
  if LContextLen > 0 then
    AppendBytes(Result, AContext);
end;

function TLS13_HKDF_Expand_Label_SHA256(
  const ASecret: TBytes;
  const ALabel: string;
  const AContext: TBytes;
  ALength: Integer
): TBytes;
var
  LHkdfLabel: TBytes;
begin
  LHkdfLabel := BuildTLS13HKDFLabel(ALabel, AContext, ALength);
  Result := HKDF_Expand_SHA256(ASecret, LHkdfLabel, ALength);
end;

function TLS13_HKDF_Expand_Label_SHA384(
  const ASecret: TBytes;
  const ALabel: string;
  const AContext: TBytes;
  ALength: Integer
): TBytes;
var
  LHkdfLabel: TBytes;
begin
  LHkdfLabel := BuildTLS13HKDFLabel(ALabel, AContext, ALength);
  Result := HKDF_Expand_SHA384(ASecret, LHkdfLabel, ALength);
end;

end.
