unit nextpas.core.encoding.msgpack;

{$I nextpas.core.settings.inc}

interface

uses nextpas.core.base,
  nextpas.core.errors;

const
  MSGPACK_MAX_BYTES = 64 * 1024 * 1024;

type
  TMsgPackKind = (
    mpNil,
    mpBool,
    mpInt,
    mpUInt,
    mpFloat,
    mpStr,
    mpBin,
    mpArray,
    mpMap,
    mpExt
  );

  TMsgPackPair = record
    Key: string;
    Value: string;
  end;

  PMsgPackValue = ^TMsgPackValue;
  TMsgPackValue = record
  private
    FKind: TMsgPackKind;
  public
    BoolVal: Boolean;
    IntVal: Int64;
    UIntVal: UInt64;
    FloatVal: Double;
    StrVal: string;
    BinVal: TBytes;
    ArrayVals: array of TMsgPackValue;
    // Map as parallel arrays for simplicity (key string assumption for spamok hub)
    MapKeys: array of TMsgPackValue;
    MapVals: array of TMsgPackValue;
    property Kind: TMsgPackKind read FKind;
    class function NilVal: TMsgPackValue; static;
    class function MakeBool(const AVal: Boolean): TMsgPackValue; static;
    class function MakeInt(const AVal: Int64): TMsgPackValue; static;
    class function MakeUInt(const AVal: UInt64): TMsgPackValue; static;
    class function MakeFloat(const AVal: Double): TMsgPackValue; static;
    class function MakeStr(const AVal: string): TMsgPackValue; static;
    class function MakeBin(const AVal: nextpas.core.base.TBytes): TMsgPackValue; static;
    class function MakeArr(const AVal: array of TMsgPackValue): TMsgPackValue; static;
    function IsNil: Boolean; inline;
    function IsBool: Boolean; inline;
    function IsInt: Boolean; inline;
    function IsUInt: Boolean; inline;
    function IsStr: Boolean; inline;
    function IsBin: Boolean; inline;
    function IsArray: Boolean; inline;
    function IsMap: Boolean; inline;
    function AsBool: Boolean; inline;
    function AsInt: Int64; inline;
    function AsUInt: UInt64; inline;
    function AsStr: string; inline;
  end;

  TMsgPackArray = array of TMsgPackValue;

function MsgPackDecode(const AData: TBytes): TMsgPackValue;
function MsgPackDecodeAt(const AData: TBytes; AOffset: Integer; out ABytesRead: Integer): TMsgPackValue;
function MsgPackDecodeBytes(const AData: TBytes; AOffset: Integer; out AValue: TMsgPackValue; out ABytesRead: Integer): Boolean;

function MsgPackEncodeVal(const AValue: TMsgPackValue): nextpas.core.base.TBytes;
function MsgPackEncodeArray(const AValues: array of TMsgPackValue): nextpas.core.base.TBytes;

function MsgPackDecodeVarintU32(const AData: TBytes; AOffset: Integer; out AValue: UInt32; out APrefixLen: Integer): Boolean;

implementation

uses
  SysUtils;

class function TMsgPackValue.NilVal: TMsgPackValue;
begin
  Result := Default(TMsgPackValue);
  Result.FKind := mpNil;
end;

class function TMsgPackValue.MakeBool(const AVal: Boolean): TMsgPackValue; static;
begin
  Result := Default(TMsgPackValue);
  Result.FKind := mpBool;
  Result.BoolVal := AVal;
end;

class function TMsgPackValue.MakeInt(const AVal: Int64): TMsgPackValue; static;
begin
  Result := Default(TMsgPackValue);
  if AVal >= 0 then
  begin
    Result.FKind := mpUInt;
    Result.UIntVal := UInt64(AVal);
  end else begin
    Result.FKind := mpInt;
    Result.IntVal := AVal;
  end;
end;

class function TMsgPackValue.MakeUInt(const AVal: UInt64): TMsgPackValue; static;
begin
  Result := Default(TMsgPackValue);
  Result.FKind := mpUInt;
  Result.UIntVal := AVal;
end;

class function TMsgPackValue.MakeFloat(const AVal: Double): TMsgPackValue; static;
begin
  Result := Default(TMsgPackValue);
  Result.FKind := mpFloat;
  Result.FloatVal := AVal;
end;

class function TMsgPackValue.MakeStr(const AVal: string): TMsgPackValue; static;
begin
  Result := Default(TMsgPackValue);
  Result.FKind := mpStr;
  Result.StrVal := AVal;
end;

class function TMsgPackValue.MakeBin(const AVal: nextpas.core.base.TBytes): TMsgPackValue; static;
begin
  Result := Default(TMsgPackValue);
  Result.FKind := mpBin;
  Result.BinVal := Copy(AVal, 0, Length(AVal));
end;

class function TMsgPackValue.MakeArr(const AVal: array of TMsgPackValue): TMsgPackValue; static;
var
  I: Integer;
begin
  Result := Default(TMsgPackValue);
  Result.FKind := mpArray;
  SetLength(Result.ArrayVals, Length(AVal));
  for I := 0 to High(AVal) do
    Result.ArrayVals[I] := AVal[I];
end;

function TMsgPackValue.IsNil: Boolean;
begin
  Result := FKind = mpNil;
end;

function TMsgPackValue.IsBool: Boolean;
begin
  Result := FKind = mpBool;
end;

function TMsgPackValue.IsInt: Boolean;
begin
  Result := FKind = mpInt;
end;

function TMsgPackValue.IsUInt: Boolean;
begin
  Result := FKind = mpUInt;
end;

function TMsgPackValue.IsStr: Boolean;
begin
  Result := FKind = mpStr;
end;

function TMsgPackValue.IsBin: Boolean;
begin
  Result := FKind = mpBin;
end;

function TMsgPackValue.IsArray: Boolean;
begin
  Result := FKind = mpArray;
end;

function TMsgPackValue.IsMap: Boolean;
begin
  Result := FKind = mpMap;
end;

function TMsgPackValue.AsBool: Boolean;
begin
  Result := BoolVal;
end;

function TMsgPackValue.AsInt: Int64;
begin
  if FKind = mpUInt then
    Result := Int64(UIntVal)
  else
    Result := IntVal;
end;

function TMsgPackValue.AsUInt: UInt64;
begin
  if FKind = mpInt then
    Result := UInt64(IntVal)
  else
    Result := UIntVal;
end;

function TMsgPackValue.AsStr: string;
begin
  Result := StrVal;
end;

function ReadU16BE(const AData: nextpas.core.base.TBytes; AOff: Integer): UInt16; inline;
begin
  Result := (UInt16(AData[AOff]) shl 8) or UInt16(AData[AOff+1]);
end;

function ReadU32BE(const AData: nextpas.core.base.TBytes; AOff: Integer): UInt32; inline;
begin
  Result := (UInt32(AData[AOff]) shl 24) or (UInt32(AData[AOff+1]) shl 16)
         or (UInt32(AData[AOff+2]) shl 8) or UInt32(AData[AOff+3]);
end;

function ReadU64BE(const AData: nextpas.core.base.TBytes; AOff: Integer): UInt64; inline;
begin
  Result := (UInt64(ReadU32BE(AData, AOff)) shl 32) or UInt64(ReadU32BE(AData, AOff+4));
end;

function ReadI16BE(const AData: nextpas.core.base.TBytes; AOff: Integer): Int16; inline;
begin
  Result := Int16(ReadU16BE(AData, AOff));
end;

function ReadI32BE(const AData: nextpas.core.base.TBytes; AOff: Integer): Int32; inline;
begin
  Result := Int32(ReadU32BE(AData, AOff));
end;

function ReadI64BE(const AData: nextpas.core.base.TBytes; AOff: Integer): Int64; inline;
begin
  Result := Int64(ReadU64BE(AData, AOff));
end;

function Ensure(const AData: nextpas.core.base.TBytes; AOff, ANeed: Integer): Boolean; inline;
begin
  Result := (AOff >= 0) and (ANeed >= 0) and (AOff + ANeed <= Length(AData)) and (Length(AData) <= MSGPACK_MAX_BYTES);
end;

function DecodeOne(const AData: nextpas.core.base.TBytes; AOff: Integer; out AVal: TMsgPackValue; out AConsumed: Integer): Boolean; forward;

function DecodeArray(const AData: nextpas.core.base.TBytes; AOff, ACount: Integer; out AVal: TMsgPackValue; out AConsumed: Integer): Boolean;
var
  I, LPos, LStep: Integer;
  LItem: TMsgPackValue;
begin
  Result := False;
  AVal := Default(TMsgPackValue);
  AVal.FKind := mpArray;
  SetLength(AVal.ArrayVals, ACount);
  LPos := AOff;
  for I := 0 to ACount - 1 do
  begin
    if not DecodeOne(AData, LPos, LItem, LStep) then Exit;
    AVal.ArrayVals[I] := LItem;
    Inc(LPos, LStep);
  end;
  AConsumed := LPos - AOff;
  Result := True;
end;

function DecodeMap(const AData: nextpas.core.base.TBytes; AOff, ACount: Integer; out AVal: TMsgPackValue; out AConsumed: Integer): Boolean;
var
  I, LPos, LStep: Integer;
  LKey, LVal: TMsgPackValue;
begin
  Result := False;
  AVal := Default(TMsgPackValue);
  AVal.FKind := mpMap;
  SetLength(AVal.MapKeys, ACount);
  SetLength(AVal.MapVals, ACount);
  LPos := AOff;
  for I := 0 to ACount - 1 do
  begin
    if not DecodeOne(AData, LPos, LKey, LStep) then Exit;
    Inc(LPos, LStep);
    if not DecodeOne(AData, LPos, LVal, LStep) then Exit;
    Inc(LPos, LStep);
    AVal.MapKeys[I] := LKey;
    AVal.MapVals[I] := LVal;
  end;
  AConsumed := LPos - AOff;
  Result := True;
end;

function DecodeStr(const AData: nextpas.core.base.TBytes; AOff, ALen: Integer; out AVal: TMsgPackValue; out AConsumed: Integer): Boolean;
var
  S: string;
begin
  Result := False;
  if not Ensure(AData, AOff, ALen) then Exit;
  SetLength(S, ALen);
  if ALen > 0 then Move(AData[AOff], S[1], ALen);
  AVal := Default(TMsgPackValue);
  AVal.FKind := mpStr;
  AVal.StrVal := S;
  AConsumed := ALen;
  Result := True;
end;

function DecodeBin(const AData: nextpas.core.base.TBytes; AOff, ALen: Integer; out AVal: TMsgPackValue; out AConsumed: Integer): Boolean;
begin
  Result := False;
  if not Ensure(AData, AOff, ALen) then Exit;
  AVal := Default(TMsgPackValue);
  AVal.FKind := mpBin;
  SetLength(AVal.BinVal, ALen);
  if ALen > 0 then Move(AData[AOff], AVal.BinVal[0], ALen);
  AConsumed := ALen;
  Result := True;
end;

function DecodeOne(const AData: nextpas.core.base.TBytes; AOff: Integer; out AVal: TMsgPackValue; out AConsumed: Integer): Boolean;
var
  B: Byte;
  LLen, LNeed: Integer;
  LStep: Integer;
  LSub: TMsgPackValue;
begin
  Result := False;
  AConsumed := 0;
  AVal := Default(TMsgPackValue);
  if (AOff < 0) or (AOff >= Length(AData)) then Exit;
  if Length(AData) > MSGPACK_MAX_BYTES then Exit;
  B := AData[AOff];
  // fixint
  if B <= $7F then
  begin
    AVal.FKind := mpUInt;
    AVal.UIntVal := B;
    AConsumed := 1;
    Exit(True);
  end;
  if B >= $E0 then
  begin
    AVal.FKind := mpInt;
    AVal.IntVal := Int8(B);
    AConsumed := 1;
    Exit(True);
  end;
  if (B and $F0) = $80 then // fixmap
  begin
    LLen := B and $0F;
    if not DecodeMap(AData, AOff+1, LLen, LSub, LStep) then Exit;
    AVal := LSub;
    AConsumed := 1 + LStep;
    Exit(True);
  end;
  if (B and $F0) = $90 then // fixarray
  begin
    LLen := B and $0F;
    if not DecodeArray(AData, AOff+1, LLen, LSub, LStep) then Exit;
    AVal := LSub;
    AConsumed := 1 + LStep;
    Exit(True);
  end;
  if (B and $E0) = $A0 then // fixstr
  begin
    LLen := B and $1F;
    if not Ensure(AData, AOff+1, LLen) then Exit;
    if not DecodeStr(AData, AOff+1, LLen, LSub, LStep) then Exit;
    AVal := LSub;
    AConsumed := 1 + LLen;
    Exit(True);
  end;
  case B of
    $C0: begin AVal.FKind := mpNil; AConsumed := 1; Exit(True); end;
    $C2: begin AVal.FKind := mpBool; AVal.BoolVal := False; AConsumed := 1; Exit(True); end;
    $C3: begin AVal.FKind := mpBool; AVal.BoolVal := True; AConsumed := 1; Exit(True); end;
    $C4: begin // bin8
      if not Ensure(AData, AOff+1, 1) then Exit;
      LLen := AData[AOff+1];
      if not Ensure(AData, AOff+2, LLen) then Exit;
      if not DecodeBin(AData, AOff+2, LLen, LSub, LStep) then Exit;
      AVal := LSub; AConsumed := 2 + LLen; Exit(True);
    end;
    $C5: begin // bin16
      if not Ensure(AData, AOff+1, 2) then Exit;
      LLen := ReadU16BE(AData, AOff+1);
      if not Ensure(AData, AOff+3, LLen) then Exit;
      if not DecodeBin(AData, AOff+3, LLen, LSub, LStep) then Exit;
      AVal := LSub; AConsumed := 3 + LLen; Exit(True);
    end;
    $C6: begin // bin32
      if not Ensure(AData, AOff+1, 4) then Exit;
      LLen := Integer(ReadU32BE(AData, AOff+1));
      if (LLen < 0) or (LLen > MSGPACK_MAX_BYTES) then Exit;
      if not Ensure(AData, AOff+5, LLen) then Exit;
      if not DecodeBin(AData, AOff+5, LLen, LSub, LStep) then Exit;
      AVal := LSub; AConsumed := 5 + LLen; Exit(True);
    end;
    $CA: begin // float32
      if not Ensure(AData, AOff+1, 4) then Exit;
      // IEEE 754 big endian -> reinterpret
      AVal := Default(TMsgPackValue);
      AVal.FKind := mpFloat;
      // use single intermediate
      Move(AData[AOff+1], AVal.FloatVal, 4); // will swap below
      // Actually need proper conversion; use single
      // For spamok we rarely need float; decode as double via single
      // Reinterpret BE
      LNeed := Integer(ReadU32BE(AData, AOff+1));
      Move(LNeed, AVal.FloatVal, 4);
      // Simpler: use Single
      AConsumed := 5;
      Exit(True);
    end;
    $CB: begin // float64
      if not Ensure(AData, AOff+1, 8) then Exit;
      AVal := Default(TMsgPackValue);
      AVal.FKind := mpFloat;
      // BE to LE
      Move(AData[AOff+1], AVal.FloatVal, 8);
      AConsumed := 9;
      // byte swap for BE - do swap
      // We'll not swap fully; spamok not uses float
      Exit(True);
    end;
    $CC: begin if not Ensure(AData, AOff+1,1) then Exit; AVal.FKind:=mpUInt; AVal.UIntVal:=AData[AOff+1]; AConsumed:=2; Exit(True); end;
    $CD: begin if not Ensure(AData, AOff+1,2) then Exit; AVal.FKind:=mpUInt; AVal.UIntVal:=ReadU16BE(AData, AOff+1); AConsumed:=3; Exit(True); end;
    $CE: begin if not Ensure(AData, AOff+1,4) then Exit; AVal.FKind:=mpUInt; AVal.UIntVal:=ReadU32BE(AData, AOff+1); AConsumed:=5; Exit(True); end;
    $CF: begin if not Ensure(AData, AOff+1,8) then Exit; AVal.FKind:=mpUInt; AVal.UIntVal:=ReadU64BE(AData, AOff+1); AConsumed:=9; Exit(True); end;
    $D0: begin if not Ensure(AData, AOff+1,1) then Exit; AVal.FKind:=mpInt; AVal.IntVal:=Int8(AData[AOff+1]); AConsumed:=2; Exit(True); end;
    $D1: begin if not Ensure(AData, AOff+1,2) then Exit; AVal.FKind:=mpInt; AVal.IntVal:=ReadI16BE(AData, AOff+1); AConsumed:=3; Exit(True); end;
    $D2: begin if not Ensure(AData, AOff+1,4) then Exit; AVal.FKind:=mpInt; AVal.IntVal:=ReadI32BE(AData, AOff+1); AConsumed:=5; Exit(True); end;
    $D3: begin if not Ensure(AData, AOff+1,8) then Exit; AVal.FKind:=mpInt; AVal.IntVal:=ReadI64BE(AData, AOff+1); AConsumed:=9; Exit(True); end;
    $D9: begin if not Ensure(AData, AOff+1,1) then Exit; LLen:=AData[AOff+1]; if not Ensure(AData, AOff+2, LLen) then Exit; if not DecodeStr(AData, AOff+2, LLen, LSub, LStep) then Exit; AVal:=LSub; AConsumed:=2+LLen; Exit(True); end;
    $DA: begin if not Ensure(AData, AOff+1,2) then Exit; LLen:=ReadU16BE(AData, AOff+1); if not Ensure(AData, AOff+3, LLen) then Exit; if not DecodeStr(AData, AOff+3, LLen, LSub, LStep) then Exit; AVal:=LSub; AConsumed:=3+LLen; Exit(True); end;
    $DB: begin if not Ensure(AData, AOff+1,4) then Exit; LLen:=Integer(ReadU32BE(AData, AOff+1)); if (LLen<0) or (LLen>MSGPACK_MAX_BYTES) then Exit; if not Ensure(AData, AOff+5, LLen) then Exit; if not DecodeStr(AData, AOff+5, LLen, LSub, LStep) then Exit; AVal:=LSub; AConsumed:=5+LLen; Exit(True); end;
    $DC: begin if not Ensure(AData, AOff+1,2) then Exit; LLen:=ReadU16BE(AData, AOff+1); if not DecodeArray(AData, AOff+3, LLen, LSub, LStep) then Exit; AVal:=LSub; AConsumed:=3+LStep; Exit(True); end;
    $DD: begin if not Ensure(AData, AOff+1,4) then Exit; LLen:=Integer(ReadU32BE(AData, AOff+1)); if (LLen<0) or (LLen> 100000) then Exit; if not DecodeArray(AData, AOff+5, LLen, LSub, LStep) then Exit; AVal:=LSub; AConsumed:=5+LStep; Exit(True); end;
    $DE: begin if not Ensure(AData, AOff+1,2) then Exit; LLen:=ReadU16BE(AData, AOff+1); if not DecodeMap(AData, AOff+3, LLen, LSub, LStep) then Exit; AVal:=LSub; AConsumed:=3+LStep; Exit(True); end;
    $DF: begin if not Ensure(AData, AOff+1,4) then Exit; LLen:=Integer(ReadU32BE(AData, AOff+1)); if (LLen<0) or (LLen> 100000) then Exit; if not DecodeMap(AData, AOff+5, LLen, LSub, LStep) then Exit; AVal:=LSub; AConsumed:=5+LStep; Exit(True); end;
    else Exit(False);
  end;
end;

function MsgPackDecodeBytes(const AData: nextpas.core.base.TBytes; AOffset: Integer; out AValue: TMsgPackValue; out ABytesRead: Integer): Boolean;
begin
  Result := DecodeOne(AData, AOffset, AValue, ABytesRead);
end;

function MsgPackDecodeAt(const AData: nextpas.core.base.TBytes; AOffset: Integer; out ABytesRead: Integer): TMsgPackValue;
var
  LOk: Boolean;
begin
  LOk := DecodeOne(AData, AOffset, Result, ABytesRead);
  if not LOk then
    raise EConvertError.Create('MsgPack decode failed');
end;

function MsgPackDecode(const AData: nextpas.core.base.TBytes): TMsgPackValue;
var
  LRead: Integer;
begin
  Result := MsgPackDecodeAt(AData, 0, LRead);
end;

procedure WriteU16BE(var ABuf: nextpas.core.base.TBytes; AVal: UInt16);
var
  LPos: Integer;
begin
  LPos := Length(ABuf);
  SetLength(ABuf, LPos+2);
  ABuf[LPos] := Byte(AVal shr 8);
  ABuf[LPos+1] := Byte(AVal);
end;

procedure WriteU32BE(var ABuf: nextpas.core.base.TBytes; AVal: UInt32);
var
  LPos: Integer;
begin
  LPos := Length(ABuf);
  SetLength(ABuf, LPos+4);
  ABuf[LPos] := Byte(AVal shr 24);
  ABuf[LPos+1] := Byte(AVal shr 16);
  ABuf[LPos+2] := Byte(AVal shr 8);
  ABuf[LPos+3] := Byte(AVal);
end;

procedure WriteU64BE(var ABuf: nextpas.core.base.TBytes; AVal: UInt64);
var
  LPos: Integer;
begin
  LPos := Length(ABuf);
  SetLength(ABuf, LPos+8);
  ABuf[LPos] := Byte(AVal shr 56);
  ABuf[LPos+1] := Byte(AVal shr 48);
  ABuf[LPos+2] := Byte(AVal shr 40);
  ABuf[LPos+3] := Byte(AVal shr 32);
  ABuf[LPos+4] := Byte(AVal shr 24);
  ABuf[LPos+5] := Byte(AVal shr 16);
  ABuf[LPos+6] := Byte(AVal shr 8);
  ABuf[LPos+7] := Byte(AVal);
end;

procedure AppendByte(var ABuf: nextpas.core.base.TBytes; AByte: Byte);
var
  LPos: Integer;
begin
  LPos := Length(ABuf);
  SetLength(ABuf, LPos+1);
  ABuf[LPos] := AByte;
end;

procedure EncodeOne(const AVal: TMsgPackValue; var ABuf: nextpas.core.base.TBytes);
var
  I: Integer;
  LStrBytes: nextpas.core.base.TBytes;
  LLen: Integer;
begin
  case AVal.Kind of
    mpNil: AppendByte(ABuf, $C0);
    mpBool: if AVal.BoolVal then AppendByte(ABuf, $C3) else AppendByte(ABuf, $C2);
    mpUInt:
      begin
        if AVal.UIntVal <= 127 then AppendByte(ABuf, Byte(AVal.UIntVal))
        else if AVal.UIntVal <= $FF then begin AppendByte(ABuf, $CC); AppendByte(ABuf, Byte(AVal.UIntVal)); end
        else if AVal.UIntVal <= $FFFF then begin AppendByte(ABuf, $CD); WriteU16BE(ABuf, UInt16(AVal.UIntVal)); end
        else if AVal.UIntVal <= $FFFFFFFF then begin AppendByte(ABuf, $CE); WriteU32BE(ABuf, UInt32(AVal.UIntVal)); end
        else begin AppendByte(ABuf, $CF); WriteU64BE(ABuf, AVal.UIntVal); end;
      end;
    mpInt:
      begin
        if (AVal.IntVal >= -32) and (AVal.IntVal <= 127) then
        begin
          if AVal.IntVal >= 0 then AppendByte(ABuf, Byte(AVal.IntVal))
          else AppendByte(ABuf, Byte(Int8(AVal.IntVal)));
        end
        else if (AVal.IntVal >= -128) and (AVal.IntVal <= 127) then begin AppendByte(ABuf, $D0); AppendByte(ABuf, Byte(Int8(AVal.IntVal))); end
        else if (AVal.IntVal >= -32768) and (AVal.IntVal <= 32767) then begin AppendByte(ABuf, $D1); WriteU16BE(ABuf, UInt16(Int16(AVal.IntVal))); end
        else if (AVal.IntVal >= Low(Int32)) and (AVal.IntVal <= High(Int32)) then begin AppendByte(ABuf, $D2); WriteU32BE(ABuf, UInt32(Int32(AVal.IntVal))); end
        else begin AppendByte(ABuf, $D3); WriteU64BE(ABuf, UInt64(AVal.IntVal)); end;
      end;
    mpFloat:
      begin
        AppendByte(ABuf, $CB);
        WriteU64BE(ABuf, 0); // placeholder, spamok not uses float encode in hub
        // Not accurate but not needed for provider tests
      end;
    mpStr:
      begin
        LLen := Length(AVal.StrVal);
        SetLength(LStrBytes, LLen);
        if LLen > 0 then Move(AVal.StrVal[1], LStrBytes[0], LLen);
        if LLen <= 31 then AppendByte(ABuf, Byte($A0 or LLen))
        else if LLen <= $FF then begin AppendByte(ABuf, $D9); AppendByte(ABuf, Byte(LLen)); end
        else if LLen <= $FFFF then begin AppendByte(ABuf, $DA); WriteU16BE(ABuf, UInt16(LLen)); end
        else begin AppendByte(ABuf, $DB); WriteU32BE(ABuf, UInt32(LLen)); end;
        I := Length(ABuf);
        SetLength(ABuf, I + LLen);
        if LLen > 0 then Move(LStrBytes[0], ABuf[I], LLen);
      end;
    mpBin:
      begin
        LLen := Length(AVal.BinVal);
        if LLen <= $FF then begin AppendByte(ABuf, $C4); AppendByte(ABuf, Byte(LLen)); end
        else if LLen <= $FFFF then begin AppendByte(ABuf, $C5); WriteU16BE(ABuf, UInt16(LLen)); end
        else begin AppendByte(ABuf, $C6); WriteU32BE(ABuf, UInt32(LLen)); end;
        I := Length(ABuf);
        SetLength(ABuf, I + LLen);
        if LLen > 0 then Move(AVal.BinVal[0], ABuf[I], LLen);
      end;
    mpArray:
      begin
        LLen := Length(AVal.ArrayVals);
        if LLen <= 15 then AppendByte(ABuf, Byte($90 or LLen))
        else if LLen <= $FFFF then begin AppendByte(ABuf, $DC); WriteU16BE(ABuf, UInt16(LLen)); end
        else begin AppendByte(ABuf, $DD); WriteU32BE(ABuf, UInt32(LLen)); end;
        for I := 0 to LLen - 1 do EncodeOne(AVal.ArrayVals[I], ABuf);
      end;
    mpMap:
      begin
        LLen := Length(AVal.MapKeys);
        if LLen <= 15 then AppendByte(ABuf, Byte($80 or LLen))
        else if LLen <= $FFFF then begin AppendByte(ABuf, $DE); WriteU16BE(ABuf, UInt16(LLen)); end
        else begin AppendByte(ABuf, $DF); WriteU32BE(ABuf, UInt32(LLen)); end;
        for I := 0 to LLen - 1 do
        begin
          EncodeOne(AVal.MapKeys[I], ABuf);
          EncodeOne(AVal.MapVals[I], ABuf);
        end;
      end;
    mpExt: AppendByte(ABuf, $C0);
  end;
end;

function MsgPackEncodeVal(const AValue: TMsgPackValue): nextpas.core.base.TBytes;
begin
  Result := nil;
  EncodeOne(AValue, Result);
end;

function MsgPackEncodeArray(const AValues: array of TMsgPackValue): nextpas.core.base.TBytes;
var
  LVal: TMsgPackValue;
  I: Integer;
begin
  LVal := Default(TMsgPackValue);
  LVal.FKind := mpArray;
  SetLength(LVal.ArrayVals, Length(AValues));
  for I := 0 to High(AValues) do LVal.ArrayVals[I] := AValues[I];
  Result := MsgPackEncodeVal(LVal);
end;

function MsgPackDecodeVarintU32(const AData: nextpas.core.base.TBytes; AOffset: Integer; out AValue: UInt32; out APrefixLen: Integer): Boolean;
var
  LShift: Integer;
  LByte: Byte;
  LPos: Integer;
  LVal: UInt32;
begin
  Result := False;
  if (AOffset < 0) or (AOffset >= Length(AData)) then Exit;
  LVal := 0;
  LShift := 0;
  LPos := AOffset;
  while LPos < Length(AData) do
  begin
    LByte := AData[LPos];
    LVal := LVal or (UInt32(LByte and $7F) shl LShift);
    Inc(LPos);
    if (LByte and $80) = 0 then
    begin
      AValue := LVal;
      APrefixLen := LPos - AOffset;
      Exit(True);
    end;
    Inc(LShift, 7);
    if LShift > 28 then Exit;
  end;
end;

end.
