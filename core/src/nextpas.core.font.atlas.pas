unit nextpas.core.font.atlas;
{**
 * @desc 纯 Pascal 字形 atlas 打包器。
 *       Shelf-packing + LRU 淘汰。接受 Alpha8 光栅化结果，
 *       管理像素缓冲区和 slot 元数据，输出 blit 坐标。
 *       零外部依赖（只依赖 nextpas.core.base/font.base）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.font.base;

const
  {** Atlas 最大尺寸（像素） }
  ATLAS_MAX_WIDTH  = 4096;
  ATLAS_MAX_HEIGHT = 4096;

  {** 默认 atlas 尺寸 }
  ATLAS_DEFAULT_WIDTH  = 1024;
  ATLAS_DEFAULT_HEIGHT = 1024;

type
  {** Atlas 查找键：glyph 索引 + 目标字号（像素）。
      同一 glyph 在不同字号下有不同位图，需要独立 slot。 }
  TFontAtlasKey = record
    GlyphIndex: UInt32;
    SizePx: Int32;
  end;

  {** Atlas slot 元数据 }
  TFontAtlasSlot = record
    Key: TFontAtlasKey;
    X, Y: Int32;           // atlas 像素坐标
    W, H: Int32;           // 字形位图尺寸
    BearingXPx: Int32;     // 水平偏移（像素）
    BearingYPx: Int32;     // 垂直偏移（像素）
    AdvancePx: Int32;      // 步进宽度（像素）
    LastUsedFrame: UInt64; // LRU 帧号
    Occupied: Boolean;
  end;

  {** 字形 atlas：shelf-packing + LRU 淘汰。
      线程不安全，调用方负责同步。 }
  TFontAtlas = class
  private
    FWidth, FHeight: Int32;
    FPixels: array of Byte;
    FSlots: array of TFontAtlasSlot;
    FSlotCount: Int32;
    FShelfY: Int32;
    FShelfH: Int32;
    FCurX: Int32;
    FFrameCounter: UInt64;
    FRepacking: Boolean;
    function FindSlot(const AKey: TFontAtlasKey): Int32;
    function AllocateSlot(AW, AH: Int32): Int32;
    procedure RepackKeep(AKeepCount: Int32);
    procedure WritePixels(ASlot: Int32; const ARaster: TFontRasterResult);
  public
    constructor Create(AWidth, AHeight: Int32);
    destructor Destroy; override;

    {** 打包一个字形位图到 atlas，返回 slot 索引。
        如果 key 已存在，更新位图并返回已有索引。
        返回 -1 表示分配失败（极少见，仅当 atlas 完全满且淘汰后仍不够）。 }
    function Pack(const AKey: TFontAtlasKey;
      const ARaster: TFontRasterResult): Int32;

    {** 查找已有 slot，返回索引或 -1。
        命中时更新 LRU 帧号。 }
    function Lookup(const AKey: TFontAtlasKey): Int32;

    {** 获取 slot 信息。越界返回默认值。 }
    function SlotAt(AIndex: Int32): TFontAtlasSlot;

    {** 推进帧号（每帧调用一次，驱动 LRU）。 }
    procedure AdvanceFrame;

    {** 清空 atlas：释放所有 slot，重置 shelf 状态。 }
    procedure Clear;

    {** 当前已占用 slot 数量 }
    function SlotCount: Int32;

    {** 像素缓冲区指针（可能为 nil，如果 atlas 为空）。 }
    function PixelPtr: PByte;

    property Width: Int32 read FWidth;
    property Height: Int32 read FHeight;
    property FrameCounter: UInt64 read FFrameCounter;
  end;

{** 创建 atlas key }
function FontAtlasKeyMake(AGlyphIndex: UInt32; ASizePx: Int32): TFontAtlasKey;

{** 比较两个 atlas key 是否相等 }
function FontAtlasKeyEquals(const A, B: TFontAtlasKey): Boolean;

implementation

uses
  SysUtils, Math;

function FontAtlasKeyMake(AGlyphIndex: UInt32; ASizePx: Int32): TFontAtlasKey;
begin
  Result.GlyphIndex := AGlyphIndex;
  Result.SizePx := ASizePx;
end;

function FontAtlasKeyEquals(const A, B: TFontAtlasKey): Boolean;
begin
  Result := (A.GlyphIndex = B.GlyphIndex) and (A.SizePx = B.SizePx);
end;

{ TFontAtlas }

constructor TFontAtlas.Create(AWidth, AHeight: Int32);
begin
  inherited Create;
  if (AWidth <= 0) or (AWidth > ATLAS_MAX_WIDTH) then
    AWidth := ATLAS_DEFAULT_WIDTH;
  if (AHeight <= 0) or (AHeight > ATLAS_MAX_HEIGHT) then
    AHeight := ATLAS_DEFAULT_HEIGHT;
  FWidth := AWidth;
  FHeight := AHeight;
  SetLength(FPixels, AWidth * AHeight);
  if Length(FPixels) > 0 then
    FillChar(FPixels[0], Length(FPixels), 0);
  SetLength(FSlots, 0);
  FSlotCount := 0;
  FShelfY := 0;
  FShelfH := 0;
  FCurX := 0;
  FFrameCounter := 0;
  FRepacking := False;
end;

destructor TFontAtlas.Destroy;
begin
  SetLength(FPixels, 0);
  SetLength(FSlots, 0);
  inherited Destroy;
end;

function TFontAtlas.FindSlot(const AKey: TFontAtlasKey): Int32;
var
  LIndex: Int32;
begin
  for LIndex := 0 to FSlotCount - 1 do
    if FSlots[LIndex].Occupied and
      FontAtlasKeyEquals(FSlots[LIndex].Key, AKey) then
      Exit(LIndex);
  Result := -1;
end;

function TFontAtlas.AllocateSlot(AW, AH: Int32): Int32;
var
  LIdx, LTotal, LEvict: Int32;

  procedure PlaceSlot(AIdx, AX, AY: Int32);
  begin
    FSlots[AIdx].X := AX;
    FSlots[AIdx].Y := AY;
    FSlots[AIdx].W := AW;
    FSlots[AIdx].H := AH;
    FSlots[AIdx].Occupied := True;
    FSlots[AIdx].LastUsedFrame := FFrameCounter;
  end;

begin
  // 1) Try current shelf.
  if (FCurX + AW <= FWidth) and (FShelfY + AH <= FHeight) then
  begin
    if AH > FShelfH then
      FShelfH := AH;
    LIdx := FSlotCount;
    Inc(FSlotCount);
    if FSlotCount > Length(FSlots) then
      SetLength(FSlots, FSlotCount);
    PlaceSlot(LIdx, FCurX, FShelfY);
    FCurX := FCurX + AW;
    Exit(LIdx);
  end;

  // 2) Start new shelf.
  if (FShelfH > 0) and (AW <= FWidth) and
    (FShelfY + FShelfH + AH <= FHeight) then
  begin
    FShelfY := FShelfY + FShelfH;
    FShelfH := AH;
    FCurX := 0;
    LIdx := FSlotCount;
    Inc(FSlotCount);
    if FSlotCount > Length(FSlots) then
      SetLength(FSlots, FSlotCount);
    PlaceSlot(LIdx, 0, FShelfY);
    FCurX := AW;
    Exit(LIdx);
  end;

  // 3) Atlas full — LRU eviction with shelf rebuild.
  if not FRepacking then
  begin
    LTotal := 0;
    for LIdx := 0 to FSlotCount - 1 do
      if FSlots[LIdx].Occupied then
        Inc(LTotal);
    if LTotal > 0 then
    begin
      // Evict oldest 25% (at least 1).
      LEvict := LTotal div 4;
      if LEvict < 1 then
        LEvict := 1;
      RepackKeep(LTotal - LEvict);
    end
    else
      Clear;
  end
  else
    // Already repacking — don't recurse, just fall through to clear.
    Clear;

  // 3b) Retry after LRU eviction.
  if (FCurX + AW <= FWidth) and (FShelfY + AH <= FHeight) then
  begin
    if AH > FShelfH then
      FShelfH := AH;
    LIdx := FSlotCount;
    Inc(FSlotCount);
    if FSlotCount > Length(FSlots) then
      SetLength(FSlots, FSlotCount);
    PlaceSlot(LIdx, FCurX, FShelfY);
    FCurX := FCurX + AW;
    Exit(LIdx);
  end;
  if (FShelfH > 0) and (AW <= FWidth) and
    (FShelfY + FShelfH + AH <= FHeight) then
  begin
    FShelfY := FShelfY + FShelfH;
    FShelfH := AH;
    FCurX := 0;
    LIdx := FSlotCount;
    Inc(FSlotCount);
    if FSlotCount > Length(FSlots) then
      SetLength(FSlots, FSlotCount);
    PlaceSlot(LIdx, 0, FShelfY);
    FCurX := AW;
    Exit(LIdx);
  end;

  // 3c) LRU eviction wasn't enough — full clear as last resort.
  Clear;
  PlaceSlot(0, 0, 0);
  FSlotCount := 1;
  FShelfH := AH;
  FCurX := AW;
  Result := 0;
end;

procedure TFontAtlas.RepackKeep(AKeepCount: Int32);
type
  TSlotSort = record
    LastUsedFrame: UInt64;
    OrigIndex: Int32;
    Keep: Boolean;
  end;
var
  LTotal, LI, LJ: Int32;
  LMeta: array of TSlotSort;
  LSwap: TSlotSort;
  LSwapSlot: TFontAtlasSlot;
  LTempPixels: array of Byte;
  LTempSlots: array of TFontAtlasSlot;
  LX, LY, LSrcIdx, LDstIdx: Int32;
begin
  // Collect occupied slots with original indices.
  LTotal := 0;
  for LI := 0 to FSlotCount - 1 do
    if FSlots[LI].Occupied then
      Inc(LTotal);
  if LTotal <= 0 then
  begin
    Clear;
    Exit;
  end;
  if AKeepCount > LTotal then
    AKeepCount := LTotal;
  if AKeepCount <= 0 then
  begin
    Clear;
    Exit;
  end;

  SetLength(LMeta, LTotal);
  LJ := 0;
  for LI := 0 to FSlotCount - 1 do
    if FSlots[LI].Occupied then
    begin
      LMeta[LJ].LastUsedFrame := FSlots[LI].LastUsedFrame;
      LMeta[LJ].OrigIndex := LJ;
      LMeta[LJ].Keep := True;
      Inc(LJ);
    end;

  // Sort by LastUsedFrame descending (most recent first).
  for LI := 1 to LTotal - 1 do
  begin
    LSwap := LMeta[LI];
    LJ := LI;
    while (LJ > 0) and (LMeta[LJ - 1].LastUsedFrame < LSwap.LastUsedFrame) do
    begin
      LMeta[LJ] := LMeta[LJ - 1];
      Dec(LJ);
    end;
    if LJ <> LI then
      LMeta[LJ] := LSwap;
  end;

  // Mark oldest items for eviction.
  for LI := AKeepCount to LTotal - 1 do
    LMeta[LI].Keep := False;

  // Re-sort by original index to preserve packing order.
  for LI := 1 to LTotal - 1 do
  begin
    LSwap := LMeta[LI];
    LJ := LI;
    while (LJ > 0) and (LMeta[LJ - 1].OrigIndex > LSwap.OrigIndex) do
    begin
      LMeta[LJ] := LMeta[LJ - 1];
      Dec(LJ);
    end;
    if LJ <> LI then
      LMeta[LJ] := LSwap;
  end;

  // Save pixel and slot data (Clear will zero both).
  LTempPixels := Copy(FPixels);
  LTempSlots := Copy(FSlots);

  // Clear the atlas (resets shelf state).
  Clear;

  // Re-pack kept slots in original order.
  FRepacking := True;
  for LI := 0 to LTotal - 1 do
  begin
    if not LMeta[LI].Keep then
      Continue;
    LSwapSlot := LTempSlots[LMeta[LI].OrigIndex];
    AllocateSlot(LSwapSlot.W, LSwapSlot.H);
    // Fill slot metadata from saved slot (AllocateSlot only sets geometry).
    FSlots[FSlotCount - 1].Key := LSwapSlot.Key;
    FSlots[FSlotCount - 1].BearingXPx := LSwapSlot.BearingXPx;
    FSlots[FSlotCount - 1].BearingYPx := LSwapSlot.BearingYPx;
    FSlots[FSlotCount - 1].AdvancePx := LSwapSlot.AdvancePx;
    FSlots[FSlotCount - 1].LastUsedFrame := LSwapSlot.LastUsedFrame;
    // Copy pixel data from old position to new position.
    for LY := 0 to LSwapSlot.H - 1 do
      for LX := 0 to LSwapSlot.W - 1 do
      begin
        LSrcIdx := (LSwapSlot.Y + LY) * FWidth + (LSwapSlot.X + LX);
        LDstIdx := (FSlots[FSlotCount - 1].Y + LY) * FWidth +
          (FSlots[FSlotCount - 1].X + LX);
        if (LSrcIdx >= 0) and (LSrcIdx < Length(LTempPixels)) and
           (LDstIdx >= 0) and (LDstIdx < Length(FPixels)) then
          FPixels[LDstIdx] := LTempPixels[LSrcIdx];
      end;
  end;
  FRepacking := False;
end;

procedure TFontAtlas.WritePixels(ASlot: Int32; const ARaster: TFontRasterResult);
var
  LSlot: TFontAtlasSlot;
  LX, LY, LSrcIdx, LDstIdx: Int32;
begin
  LSlot := FSlots[ASlot];
  for LY := 0 to Min(LSlot.H, ARaster.HeightPx) - 1 do
    for LX := 0 to Min(LSlot.W, ARaster.WidthPx) - 1 do
    begin
      LSrcIdx := LY * ARaster.PitchBytes + LX;
      LDstIdx := (LSlot.Y + LY) * FWidth + (LSlot.X + LX);
      if (LSrcIdx >= 0) and (LSrcIdx < Length(ARaster.Pixels)) and
         (LDstIdx >= 0) and (LDstIdx < Length(FPixels)) then
        FPixels[LDstIdx] := ARaster.Pixels[LSrcIdx];
    end;
end;

function TFontAtlas.Pack(const AKey: TFontAtlasKey;
  const ARaster: TFontRasterResult): Int32;
var
  LIndex: Int32;
begin
  // Check if already present — update in place.
  LIndex := FindSlot(AKey);
  if LIndex >= 0 then
  begin
    FSlots[LIndex].LastUsedFrame := FFrameCounter;
    FSlots[LIndex].W := ARaster.WidthPx;
    FSlots[LIndex].H := ARaster.HeightPx;
    FSlots[LIndex].BearingXPx := ARaster.BearingXPx;
    FSlots[LIndex].BearingYPx := ARaster.BearingYPx;
    FSlots[LIndex].AdvancePx := ARaster.AdvancePx;
    WritePixels(LIndex, ARaster);
    Exit(LIndex);
  end;

  // Allocate new slot.
  LIndex := AllocateSlot(ARaster.WidthPx, ARaster.HeightPx);
  if LIndex < 0 then
    Exit(-1);
  FSlots[LIndex].Key := AKey;
  FSlots[LIndex].BearingXPx := ARaster.BearingXPx;
  FSlots[LIndex].BearingYPx := ARaster.BearingYPx;
  FSlots[LIndex].AdvancePx := ARaster.AdvancePx;
  WritePixels(LIndex, ARaster);
  Result := LIndex;
end;

function TFontAtlas.Lookup(const AKey: TFontAtlasKey): Int32;
var
  LIndex: Int32;
begin
  LIndex := FindSlot(AKey);
  if LIndex >= 0 then
    FSlots[LIndex].LastUsedFrame := FFrameCounter;
  Result := LIndex;
end;

function TFontAtlas.SlotAt(AIndex: Int32): TFontAtlasSlot;
begin
  if (AIndex >= 0) and (AIndex < FSlotCount) then
    Result := FSlots[AIndex]
  else
    Result := Default(TFontAtlasSlot);
end;

procedure TFontAtlas.AdvanceFrame;
begin
  Inc(FFrameCounter);
end;

procedure TFontAtlas.Clear;
begin
  if Length(FPixels) > 0 then
    FillChar(FPixels[0], Length(FPixels), 0);
  if FSlotCount > 0 then
    FillChar(FSlots[0], FSlotCount * SizeOf(TFontAtlasSlot), 0);
  FSlotCount := 0;
  FShelfY := 0;
  FShelfH := 0;
  FCurX := 0;
end;

function TFontAtlas.SlotCount: Int32;
begin
  Result := FSlotCount;
end;

function TFontAtlas.PixelPtr: PByte;
begin
  if Length(FPixels) > 0 then
    Result := @FPixels[0]
  else
    Result := nil;
end;

end.
