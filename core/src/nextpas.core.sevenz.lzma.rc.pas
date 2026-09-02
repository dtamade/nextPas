unit nextpas.core.sevenz.lzma.rc;

{**
 * nextpas.core.sevenz.lzma.rc - LZMA 自适应二进制区间编码器/解码器
 *
 * 纯 Pascal 实现，供 LZMA1/LZMA2 编解码共用。
 * 解码器从内存缓冲读取，越过末尾按规范补零；编码器写入自动扩容缓冲。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type
  {** @desc 区间解码器：从固定缓冲顺序消费字节，越界补零（规范允许） *}
  TSevenZRcDecoder = class
  private
    FBuf: PByte;
    FLimit: SizeUInt;
    FPos: SizeUInt;
    FRange: UInt32;
    FCode: UInt32;
    FSavedLimit: SizeUInt;

    function NextByte: Byte; inline;
    procedure Normalize; inline;
  public
    constructor Create(const ABuf; ASize: SizeUInt);
    { 解一个概率位：返回 0/1 并更新 AProb }
    function DecodeBit(var AProb: Word): UInt32; inline;
    { 直接解 ANumBits 个高位在前的位（不经概率模型） }
    function DecodeDirectBits(ANumBits: UInt32): UInt32;
    procedure Init;
    { 绕过区间算术的原始字节读（LZMA2 块头与未压缩块载荷）；越界补零 }
    function RawReadByte: Byte; inline;
    procedure RawRead(var ADst; ACount: SizeUInt);
    { 临时收紧读取上限（LZMA2 单块算术区隔离）；RestoreLimit 恢复 }
    procedure ClipTo(ALimit: SizeUInt);
    procedure RestoreLimit;
    property Position: SizeUInt read FPos;
  end;

  {** @desc 自动扩容输出缓冲：编码器字节池 *}
  TSevenZOutBuffer = class
  private
    FData: PByte;
    FLen: SizeUInt;
    FCap: SizeUInt;
    procedure Grow(ANeed: SizeUInt);
  public
    destructor Destroy; override;
    procedure Put(AVal: Byte); inline;
    procedure Write(const ABuf; ACount: SizeUInt);
    function Steal: TBytes;
    property Length: SizeUInt read FLen;
  end;

  {** @desc 区间编码器：输出到共享的扩容字节池 *}
  TSevenZRcEncoder = class
  private
    FOut: TSevenZOutBuffer;
    FLow: UInt64;
    FRange: UInt32;
    FCache: Byte;
    FCacheSize: UInt64;

    procedure ShiftLow; inline;
    procedure Normalize; inline;
  public
    constructor Create(const AOut: TSevenZOutBuffer);
    procedure EncodeBit(var AProb: Word; ABit: UInt32); inline;
    procedure EncodeDirectBits(AVal: UInt32; ANumBits: UInt32);
    procedure Init;
    { 冲刷 carry 与缓存尾流；调用后编码器不可复用 }
    procedure Flush;
  end;

const
  C_RC_TOP_VALUE = 1 shl 24;
  C_RC_NUM_BIT_MODEL_TOTAL_BITS = 11;
  C_RC_BIT_MODEL_TOTAL = 1 shl C_RC_NUM_BIT_MODEL_TOTAL_BITS;  { 2048 }
  C_RC_MOVE_BITS = 5;
  C_RC_INIT_PROB = Word(C_RC_BIT_MODEL_TOTAL div 2);

implementation

{ TSevenZRcDecoder }

constructor TSevenZRcDecoder.Create(const ABuf; ASize: SizeUInt);
begin
  inherited Create;
  FBuf := @ABuf;
  FLimit := ASize;
  FPos := 0;
  FRange := 0;
  FCode := 0;
end;

function TSevenZRcDecoder.NextByte: Byte; inline;
begin
  if FPos < FLimit then
  begin
    Result := FBuf[FPos];
    Inc(FPos);
  end
  else
    Result := 0;
end;

procedure TSevenZRcDecoder.Init;
var
  LI: Integer;
begin
  { 首字节恒为 0，随后 4 字节大端构成初始 Code }
  NextByte;
  FCode := 0;
  {$PUSH}{$Q-}{$R-}
  for LI := 0 to 3 do
    FCode := (FCode shl 8) or NextByte;
  {$POP}
  FRange := $FFFFFFFF;
end;

procedure TSevenZRcDecoder.Normalize; inline;
begin
  {$PUSH}{$Q-}{$R-}
  if FRange < C_RC_TOP_VALUE then
  begin
    FRange := FRange shl 8;
    FCode := (FCode shl 8) or NextByte;
  end;
  {$POP}
end;

function TSevenZRcDecoder.DecodeBit(var AProb: Word): UInt32; inline;
var
  LBound: UInt32;
begin
  {$PUSH}{$Q-}{$R-}
  LBound := (FRange shr C_RC_NUM_BIT_MODEL_TOTAL_BITS) * AProb;
  if FCode < LBound then
  begin
    FRange := LBound;
    AProb := AProb + ((C_RC_BIT_MODEL_TOTAL - AProb) shr C_RC_MOVE_BITS);
    Result := 0;
  end
  else
  begin
    FRange := FRange - LBound;
    FCode := FCode - LBound;
    AProb := AProb - (AProb shr C_RC_MOVE_BITS);
    Result := 1;
  end;
  Normalize;
  {$POP}
end;

function TSevenZRcDecoder.DecodeDirectBits(ANumBits: UInt32): UInt32;
var
  LResult: UInt32;
  LI: UInt32;
begin
  {$PUSH}{$Q-}{$R-}
  LResult := 0;
  LI := 0;
  while LI < ANumBits do
  begin
    FRange := FRange shr 1;
    Inc(LI);
    LResult := LResult shl 1;
    if FCode >= FRange then
    begin
      FCode := FCode - FRange;
      LResult := LResult or 1;
    end;
    Normalize;
  end;
  Result := LResult;
  {$POP}
end;

function TSevenZRcDecoder.RawReadByte: Byte; inline;
begin
  if FPos < FLimit then
  begin
    Result := FBuf[FPos];
    Inc(FPos);
  end
  else
    Result := 0;
end;

procedure TSevenZRcDecoder.RawRead(var ADst; ACount: SizeUInt);
var
  LI: SizeUInt;
  LP: PByte;
begin
  LP := @ADst;
  LI := 0;
  while LI < ACount do
  begin
    LP[LI] := RawReadByte;
    Inc(LI);
  end;
end;

procedure TSevenZRcDecoder.ClipTo(ALimit: SizeUInt);
begin
  FSavedLimit := FLimit;
  if ALimit < FLimit then
    FLimit := ALimit;
end;

procedure TSevenZRcDecoder.RestoreLimit;
begin
  FLimit := FSavedLimit;
end;

{ TSevenZOutBuffer }

destructor TSevenZOutBuffer.Destroy;
begin
  if FData <> nil then
    FreeMem(FData);
  inherited Destroy;
end;

procedure TSevenZOutBuffer.Grow(ANeed: SizeUInt);
var
  LNewCap: SizeUInt;
  LP: PByte;
begin
  if ANeed <= FCap then
    Exit;
  LNewCap := FCap * 2 + 256;
  if LNewCap < ANeed then
    LNewCap := ANeed;
  GetMem(LP, LNewCap);
  if FData <> nil then
  begin
    Move(FData^, LP^, FLen);
    FreeMem(FData);
  end;
  FData := LP;
  FCap := LNewCap;
end;

procedure TSevenZOutBuffer.Put(AVal: Byte); inline;
begin
  Grow(FLen + 1);
  FData[FLen] := AVal;
  Inc(FLen);
end;

procedure TSevenZOutBuffer.Write(const ABuf; ACount: SizeUInt);
begin
  if ACount = 0 then
    Exit;
  Grow(FLen + ACount);
  Move(ABuf, (FData + FLen)^, ACount);
  Inc(FLen, ACount);
end;

function TSevenZOutBuffer.Steal: TBytes;
begin
  Result := nil;
  SetLength(Result, FLen);
  if FLen > 0 then
    Move(FData^, Result[0], FLen);
  FreeMem(FData);
  FData := nil;
  FLen := 0;
  FCap := 0;
end;

{ TSevenZRcEncoder }

constructor TSevenZRcEncoder.Create(const AOut: TSevenZOutBuffer);
begin
  inherited Create;
  FOut := AOut;
  FLow := 0;
  FRange := $FFFFFFFF;
  FCache := 0;
  FCacheSize := 1;
end;

procedure TSevenZRcEncoder.Init;
begin
  FLow := 0;
  FRange := $FFFFFFFF;
  FCache := 0;
  FCacheSize := 1;
end;

procedure TSevenZRcEncoder.ShiftLow; inline;
var
  LCarry: Boolean;
  LTemp: Byte;
begin
  {$PUSH}{$Q-}{$R-}
  LCarry := FLow >= UInt64($100000000);
  if (UInt32(FLow) < UInt32($FF000000)) or LCarry then
  begin
    LTemp := FCache;
    repeat
      FOut.Put(Byte(LTemp + Byte(FLow shr 32)));
      LTemp := $FF;
      Dec(FCacheSize);
    until FCacheSize = 0;
    FCache := Byte(FLow shr 24);
  end;
  Inc(FCacheSize);
  FLow := (FLow shl 8) and UInt64($FFFFFFFF);
  {$POP}
end;

procedure TSevenZRcEncoder.Normalize; inline;
begin
  if FRange < C_RC_TOP_VALUE then
  begin
    FRange := FRange shl 8;
    ShiftLow;
  end;
end;

procedure TSevenZRcEncoder.EncodeBit(var AProb: Word; ABit: UInt32); inline;
var
  LBound: UInt32;
begin
  {$PUSH}{$Q-}{$R-}
  LBound := (FRange shr C_RC_NUM_BIT_MODEL_TOTAL_BITS) * AProb;
  if ABit = 0 then
  begin
    FRange := LBound;
    AProb := AProb + ((C_RC_BIT_MODEL_TOTAL - AProb) shr C_RC_MOVE_BITS);
  end
  else
  begin
    FLow := FLow + LBound;
    FRange := FRange - LBound;
    AProb := AProb - (AProb shr C_RC_MOVE_BITS);
  end;
  Normalize;
  {$POP}
end;

procedure TSevenZRcEncoder.EncodeDirectBits(AVal: UInt32; ANumBits: UInt32);
var
  LI: UInt32;
begin
  {$PUSH}{$Q-}{$R-}
  LI := 0;
  while LI < ANumBits do
  begin
    FRange := FRange shr 1;
    Inc(LI);
    if ((AVal shr (ANumBits - LI)) and 1) <> 0 then
      FLow := FLow + FRange;
    Normalize;
  end;
  {$POP}
end;

procedure TSevenZRcEncoder.Flush;
var
  LI: Integer;
begin
  for LI := 0 to 4 do
    ShiftLow;
end;

end.
