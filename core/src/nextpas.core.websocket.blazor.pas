unit nextpas.core.websocket.blazor;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.encoding.msgpack;

const
  BLZR_FRAME_TYPE_ELEMENT = 1;
  BLZR_FRAME_TYPE_TEXT = 2;
  BLZR_FRAME_TYPE_ATTRIBUTE = 3;

  // Hub message types (SignalR)
  HUB_MSG_INVOCATION = 1;
  HUB_MSG_COMPLETION = 3;
  HUB_MSG_PING = 6;
  HUB_MSG_CLOSE = 7;

type
  TBlazorRenderBatch = record
  private
    FData: nextpas.core.base.TBytes;
    FStringTableStart: Integer;
    function GetReferenceFramesOffset: Integer;
    function GetFrameOffset(AIndex: Integer): Integer;
    function ReadI32LE(AOff: Integer): Int32;
    function ReadU64LE(AOff: Integer): UInt64;
    function ReadVarintU32(AOff: Integer; out AVal: UInt32; out APrefix: Integer): Boolean;
  public
    function Init(const AData: nextpas.core.base.TBytes): Boolean;
    function ReferenceFrameCount: Integer;
    function FrameType(AIndex: Integer): Integer;
    function SubtreeLength(AIndex: Integer): Integer;
    function ElementName(AIndex: Integer): string;
    function TextContent(AIndex: Integer): string;
    function AttributeName(AIndex: Integer): string;
    function AttributeHandlerId(AIndex: Integer): UInt64;
    function StringValue(AIndex: Integer): string;
    function StringValueOptional(AIndex: Int32): string;
    property Data: nextpas.core.base.TBytes read FData;
    property StringTableStart: Integer read FStringTableStart;
  end;

  THubIncomingKind = (hikOther, hikCompletion, hikJsBeginInvoke, hikRenderBatch, hikAttachComponent, hikClose, hikPing);

  THubIncoming = record
    Kind: THubIncomingKind;
    InvocationId: string;
    JsAsyncId: Int64;
    JsIdentifier: string;
    JsArgsJson: string;
    BatchId: UInt64;
    BatchData: nextpas.core.base.TBytes;
    CloseMessage: string;
  end;

  THubIncomingArray = array of THubIncoming;

function BlazorEncodeVarintU32(const AVal: UInt32): nextpas.core.base.TBytes;
function BlazorDecodeVarintU32(const AData: nextpas.core.base.TBytes; AOff: Integer; out AVal: UInt32; out APrefix: Integer): Boolean;

function BlazorEncodeHubMessage(const AVal: TMsgPackValue): nextpas.core.base.TBytes;
function BlazorDecodeHubMessages(const AData: nextpas.core.base.TBytes): THubIncomingArray;

function BlazorParseInboxRows(const ABatch: TBlazorRenderBatch; out ARows: nextpas.core.base.TStringArray): Boolean; // simplified

implementation

uses
  nextpas.core.text.conv;

function BlazorEncodeVarintU32(const AVal: UInt32): nextpas.core.base.TBytes;
var
  LVal: UInt32;
  B: Byte;
begin
  Result := nil;
  LVal := AVal;
  repeat
    B := Byte(LVal and $7F);
    LVal := LVal shr 7;
    if LVal <> 0 then B := B or $80;
    SetLength(Result, Length(Result)+1);
    Result[High(Result)] := B;
  until LVal = 0;
end;

function BlazorDecodeVarintU32(const AData: nextpas.core.base.TBytes; AOff: Integer; out AVal: UInt32; out APrefix: Integer): Boolean;
var
  LShift: Integer;
  LByte: Byte;
  LPos: Integer;
begin
  Result := False;
  if (AOff < 0) or (AOff >= Length(AData)) then Exit;
  AVal := 0;
  LShift := 0;
  LPos := AOff;
  while LPos < Length(AData) do
  begin
    LByte := AData[LPos];
    AVal := AVal or (UInt32(LByte and $7F) shl LShift);
    Inc(LPos);
    if (LByte and $80) = 0 then
    begin
      APrefix := LPos - AOff;
      Exit(True);
    end;
    Inc(LShift, 7);
    if LShift > 28 then Exit;
  end;
end;

function TBlazorRenderBatch.ReadI32LE(AOff: Integer): Int32;
var
  B: array[0..3] of Byte;
begin
  if (AOff < 0) or (AOff + 4 > Length(FData)) then
    raise EConvertError.Create('Blazor i32 out of range');
  B[0] := FData[AOff];
  B[1] := FData[AOff+1];
  B[2] := FData[AOff+2];
  B[3] := FData[AOff+3];
  Result := Int32(B[0]) or (Int32(B[1]) shl 8) or (Int32(B[2]) shl 16) or (Int32(B[3]) shl 24);
end;

function TBlazorRenderBatch.ReadU64LE(AOff: Integer): UInt64;
var
  LLo, LHi: UInt32;
begin
  LLo := UInt32(ReadI32LE(AOff));
  LHi := UInt32(ReadI32LE(AOff+4));
  Result := (UInt64(LHi) shl 32) or UInt64(LLo);
end;

function TBlazorRenderBatch.ReadVarintU32(AOff: Integer; out AVal: UInt32; out APrefix: Integer): Boolean;
begin
  Result := BlazorDecodeVarintU32(FData, AOff, AVal, APrefix);
end;

function TBlazorRenderBatch.GetReferenceFramesOffset: Integer;
begin
  if Length(FData) < 16 then
    raise EConvertError.Create('Blazor batch too short for ref offset');
  Result := ReadI32LE(Length(FData) - 16);
end;

function TBlazorRenderBatch.Init(const AData: nextpas.core.base.TBytes): Boolean;
var
  LStart: Int32;
begin
  Result := False;
  if Length(AData) < 24 then Exit;
  FData := AData;
  LStart := ReadI32LE(Length(FData) - 4);
  if (LStart < 0) or (LStart >= Length(FData)) then
  begin
    FData := nil;
    Exit;
  end;
  FStringTableStart := LStart;
  try
    GetReferenceFramesOffset;
    ReferenceFrameCount;
  except
    FData := nil;
    Exit;
  end;
  Result := True;
end;

function TBlazorRenderBatch.ReferenceFrameCount: Integer;
var
  LOff: Integer;
begin
  LOff := GetReferenceFramesOffset;
  Result := ReadI32LE(LOff);
  if Result < 0 then Result := 0;
end;

function TBlazorRenderBatch.GetFrameOffset(AIndex: Integer): Integer;
var
  LBase: Integer;
begin
  LBase := GetReferenceFramesOffset + 4 + AIndex * 20;
  if (LBase < 0) or (LBase + 20 > Length(FData)) then
    raise EConvertError.Create('Blazor frame offset out of range');
  Result := LBase;
end;

function TBlazorRenderBatch.FrameType(AIndex: Integer): Integer;
begin
  Result := ReadI32LE(GetFrameOffset(AIndex));
end;

function TBlazorRenderBatch.SubtreeLength(AIndex: Integer): Integer;
begin
  Result := ReadI32LE(GetFrameOffset(AIndex) + 4);
end;

function TBlazorRenderBatch.StringValue(AIndex: Integer): string;
var
  LEntryOff, LStrOff: Integer;
  LVal: UInt32;
  LPrefix: Integer;
  LLen: Integer;
begin
  if (AIndex < 0) then
    raise EConvertError.Create('Blazor string index out of range');
  LEntryOff := FStringTableStart + AIndex * 4;
  if (LEntryOff < 0) or (LEntryOff + 4 > Length(FData)) then
    raise EConvertError.Create('Blazor string table entry out of range');
  LStrOff := ReadI32LE(LEntryOff);
  if (LStrOff < 0) or (LStrOff >= Length(FData)) then
    raise EConvertError.Create('Blazor string offset out of range');
  if not ReadVarintU32(LStrOff, LVal, LPrefix) then
    raise EConvertError.Create('Blazor varint decode failed');
  LLen := Integer(LVal);
  if (LStrOff + LPrefix + LLen > Length(FData)) then
    raise EConvertError.Create('Blazor string truncated');
  SetLength(Result, LLen);
  if LLen > 0 then Move(FData[LStrOff + LPrefix], Result[1], LLen);
end;

function TBlazorRenderBatch.StringValueOptional(AIndex: Int32): string;
begin
  if AIndex = -1 then Exit('');
  Result := StringValue(AIndex);
end;

function TBlazorRenderBatch.ElementName(AIndex: Integer): string;
var
  LIdx: Int32;
begin
  LIdx := ReadI32LE(GetFrameOffset(AIndex) + 8);
  Result := StringValueOptional(LIdx);
end;

function TBlazorRenderBatch.TextContent(AIndex: Integer): string;
var
  LIdx: Int32;
begin
  LIdx := ReadI32LE(GetFrameOffset(AIndex) + 4);
  Result := StringValueOptional(LIdx);
end;

function TBlazorRenderBatch.AttributeName(AIndex: Integer): string;
var
  LIdx: Int32;
begin
  LIdx := ReadI32LE(GetFrameOffset(AIndex) + 4);
  Result := StringValueOptional(LIdx);
end;

function TBlazorRenderBatch.AttributeHandlerId(AIndex: Integer): UInt64;
begin
  Result := ReadU64LE(GetFrameOffset(AIndex) + 12);
end;

function BlazorEncodeHubMessage(const AVal: TMsgPackValue): nextpas.core.base.TBytes;
var
  LBody: nextpas.core.base.TBytes;
  LPrefix: nextpas.core.base.TBytes;
  I: Integer;
begin
  LBody := MsgPackEncodeVal(AVal);
  LPrefix := BlazorEncodeVarintU32(Length(LBody));
  SetLength(Result, Length(LPrefix) + Length(LBody));
  for I := 0 to High(LPrefix) do Result[I] := LPrefix[I];
  for I := 0 to High(LBody) do Result[Length(LPrefix)+I] := LBody[I];
end;

function ValueAsInt64(const AVal: TMsgPackValue; out AOut: Int64): Boolean;
begin
  Result := False;
  if AVal.Kind = mpInt then begin AOut := AVal.IntVal; Exit(True); end;
  if AVal.Kind = mpUInt then begin AOut := Int64(AVal.UIntVal); Exit(True); end;
end;

function ValueAsString(const AVal: TMsgPackValue): string;
begin
  case AVal.Kind of
    mpStr: Result := AVal.StrVal;
    mpInt: Result := IntToStr(AVal.IntVal);
    mpUInt: Result := IntToStr(Int64(AVal.UIntVal));
    mpNil: Result := '';
    else Result := '';
  end;
end;

function ValueAsBytes(const AVal: TMsgPackValue; out AOut: nextpas.core.base.TBytes): Boolean;
begin
  Result := False;
  if AVal.Kind = mpBin then begin AOut := Copy(AVal.BinVal, 0, Length(AVal.BinVal)); Exit(True); end;
  if AVal.Kind = mpStr then
  begin
    SetLength(AOut, Length(AVal.StrVal));
    if Length(AVal.StrVal) > 0 then Move(AVal.StrVal[1], AOut[0], Length(AVal.StrVal));
    Exit(True);
  end;
end;

function BlazorDecodeHubMessages(const AData: nextpas.core.base.TBytes): THubIncomingArray;
var
  LOff, LPrefixLen: Integer;
  LMsgLen: UInt32;
  LBodyStart, LBodyEnd: Integer;
  LVal: TMsgPackValue;
  LConsumed: Integer;
  LIncoming: THubIncoming;
  LArr: array of THubIncoming;
  LValues: TMsgPackArray;
  LMsgType: Int64;
  LMethod: string;
  LArgs: TMsgPackArray;
  LBatchId: Int64;
  LBatchBytes: nextpas.core.base.TBytes;
begin
  Result := nil;
  LOff := 0;
  SetLength(LArr, 0);
  while LOff < Length(AData) do
  begin
    if not BlazorDecodeVarintU32(AData, LOff, LMsgLen, LPrefixLen) then Break;
    LBodyStart := LOff + LPrefixLen;
    LBodyEnd := LBodyStart + Integer(LMsgLen);
    if (LBodyEnd > Length(AData)) or (LBodyEnd < LBodyStart) then Break;
    // decode msgpack body
    if not MsgPackDecodeBytes(Copy(AData, LBodyStart, Integer(LMsgLen)), 0, LVal, LConsumed) then Break;
    // parse hub value
    LIncoming := Default(THubIncoming);
    LIncoming.Kind := hikOther;
    if LVal.Kind = mpArray then
    begin
      LValues := LVal.ArrayVals;
      if (Length(LValues) >= 1) and ValueAsInt64(LValues[0], LMsgType) then
      begin
        case LMsgType of
          HUB_MSG_COMPLETION:
            begin
              LIncoming.Kind := hikCompletion;
              if Length(LValues) >= 3 then
                LIncoming.InvocationId := ValueAsString(LValues[2]);
            end;
          HUB_MSG_INVOCATION:
            begin
              if Length(LValues) >= 4 then
                LMethod := ValueAsString(LValues[3])
              else LMethod := '';
              if LMethod = 'JS.BeginInvokeJS' then
              begin
                LIncoming.Kind := hikJsBeginInvoke;
                if Length(LValues) >= 5 then
                begin
                  if LValues[4].Kind = mpArray then
                  begin
                    LArgs := LValues[4].ArrayVals;
                    if Length(LArgs) >= 1 then ValueAsInt64(LArgs[0], LIncoming.JsAsyncId);
                    if Length(LArgs) >= 2 then LIncoming.JsIdentifier := ValueAsString(LArgs[1]);
                    if Length(LArgs) >= 3 then LIncoming.JsArgsJson := ValueAsString(LArgs[2]);
                  end;
                end;
              end else if LMethod = 'JS.RenderBatch' then
              begin
                LIncoming.Kind := hikRenderBatch;
                if Length(LValues) >= 5 then
                begin
                  if LValues[4].Kind = mpArray then
                  begin
                    LArgs := LValues[4].ArrayVals;
                    if Length(LArgs) >= 1 then
                    begin
                      ValueAsInt64(LArgs[0], LBatchId);
                      LIncoming.BatchId := UInt64(LBatchId);
                    end;
                    if Length(LArgs) >= 2 then
                    begin
                      if ValueAsBytes(LArgs[1], LBatchBytes) then
                        LIncoming.BatchData := LBatchBytes;
                    end;
                  end;
                end;
              end else if LMethod = 'JS.AttachComponent' then
                LIncoming.Kind := hikAttachComponent
              else
                LIncoming.Kind := hikOther;
            end;
          HUB_MSG_PING: LIncoming.Kind := hikPing;
          HUB_MSG_CLOSE:
            begin
              LIncoming.Kind := hikClose;
              if Length(LValues) >= 2 then LIncoming.CloseMessage := ValueAsString(LValues[1]);
            end;
        end;
      end;
    end;
    SetLength(LArr, Length(LArr)+1);
    LArr[High(LArr)] := LIncoming;
    LOff := LBodyEnd;
  end;
  Result := LArr;
end;

function BlazorParseInboxRows(const ABatch: TBlazorRenderBatch; out ARows: nextpas.core.base.TStringArray): Boolean;
begin
  // Placeholder for future provider use - not needed for core lane
  Result := False;
  SetLength(ARows, 0);
end;

end.
