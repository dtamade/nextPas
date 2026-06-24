program test_font_atlas;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  Math,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.font.base,
  nextpas.core.font.ttface,
  nextpas.core.font.rasterizer,
  nextpas.core.font.atlas;

var
  GTestsPassed: Int32 = 0;
  GTestsFailed: Int32 = 0;
  GFace: TTFontFace;
  GRasterizer: TFontRasterizer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  FAIL: ', AName);
  end;
end;

{ ---- Key helpers ---- }

procedure TestKeyMake;
var
  LKey: TFontAtlasKey;
begin
  LKey := FontAtlasKeyMake(42, 16);
  Check(LKey.GlyphIndex = 42, 'key make: glyph index');
  Check(LKey.SizePx = 16, 'key make: size px');
end;

procedure TestKeyEquals;
var
  LA, LB: TFontAtlasKey;
begin
  LA := FontAtlasKeyMake(42, 16);
  LB := FontAtlasKeyMake(42, 16);
  Check(FontAtlasKeyEquals(LA, LB), 'key equals: same keys');

  LB := FontAtlasKeyMake(43, 16);
  Check(not FontAtlasKeyEquals(LA, LB), 'key equals: different glyph');

  LB := FontAtlasKeyMake(42, 24);
  Check(not FontAtlasKeyEquals(LA, LB), 'key equals: different size');
end;

{ ---- Create/Destroy ---- }

procedure TestCreateDefault;
var
  LAtlas: TFontAtlas;
begin
  LAtlas := TFontAtlas.Create(ATLAS_DEFAULT_WIDTH, ATLAS_DEFAULT_HEIGHT);
  Check(LAtlas.Width = ATLAS_DEFAULT_WIDTH, 'create: width');
  Check(LAtlas.Height = ATLAS_DEFAULT_HEIGHT, 'create: height');
  Check(LAtlas.SlotCount = 0, 'create: slot count zero');
  Check(LAtlas.FrameCounter = 0, 'create: frame counter zero');
  Check(LAtlas.PixelPtr <> nil, 'create: pixel ptr not nil');
  LAtlas.Free;
end;

procedure TestCreateSmall;
var
  LAtlas: TFontAtlas;
begin
  LAtlas := TFontAtlas.Create(64, 64);
  Check(LAtlas.Width = 64, 'create small: width');
  Check(LAtlas.Height = 64, 'create small: height');
  LAtlas.Free;
end;

procedure TestCreateInvalidSize;
var
  LAtlas: TFontAtlas;
begin
  LAtlas := TFontAtlas.Create(0, -1);
  Check(LAtlas.Width = ATLAS_DEFAULT_WIDTH, 'create invalid: falls back to default width');
  Check(LAtlas.Height = ATLAS_DEFAULT_HEIGHT, 'create invalid: falls back to default height');
  LAtlas.Free;
end;

procedure TestCreateOversize;
var
  LAtlas: TFontAtlas;
begin
  LAtlas := TFontAtlas.Create(ATLAS_MAX_WIDTH + 1, ATLAS_MAX_HEIGHT + 1);
  Check(LAtlas.Width = ATLAS_DEFAULT_WIDTH, 'create oversize: falls back to default width');
  Check(LAtlas.Height = ATLAS_DEFAULT_HEIGHT, 'create oversize: falls back to default height');
  LAtlas.Free;
end;

{ ---- Clear ---- }

procedure TestClear;
var
  LAtlas: TFontAtlas;
  LRaster: TFontRasterResult;
  LKey: TFontAtlasKey;
begin
  LAtlas := TFontAtlas.Create(128, 128);
  LRaster.WidthPx := 8;
  LRaster.HeightPx := 8;
  LRaster.PitchBytes := 8;
  LRaster.BearingXPx := 0;
  LRaster.BearingYPx := 8;
  LRaster.AdvancePx := 8;
  SetLength(LRaster.Pixels, 64);
  FillChar(LRaster.Pixels[0], 64, $FF);
  LKey := FontAtlasKeyMake(1, 16);
  LAtlas.Pack(LKey, LRaster);
  Check(LAtlas.SlotCount = 1, 'clear: has slot before clear');
  LAtlas.Clear;
  Check(LAtlas.SlotCount = 0, 'clear: slot count zero after clear');
  LAtlas.Free;
end;

{ ---- Pack/Lookup ---- }

procedure TestPackAndLookup;
var
  LAtlas: TFontAtlas;
  LRaster: TFontRasterResult;
  LKey: TFontAtlasKey;
  LSlotIdx: Int32;
  LSlot: TFontAtlasSlot;
begin
  LAtlas := TFontAtlas.Create(128, 128);

  // Build a simple raster result.
  LRaster.WidthPx := 10;
  LRaster.HeightPx := 12;
  LRaster.PitchBytes := 10;
  LRaster.BearingXPx := 1;
  LRaster.BearingYPx := 10;
  LRaster.AdvancePx := 12;
  SetLength(LRaster.Pixels, 120);
  FillChar(LRaster.Pixels[0], 120, $AA);

  LKey := FontAtlasKeyMake(65, 16);  // 'A' at 16px
  LSlotIdx := LAtlas.Pack(LKey, LRaster);
  Check(LSlotIdx >= 0, 'pack: returns valid slot');
  Check(LAtlas.SlotCount = 1, 'pack: slot count is 1');

  // Lookup the same key.
  Check(LAtlas.Lookup(LKey) = LSlotIdx, 'lookup: finds packed slot');

  // Verify slot metadata.
  LSlot := LAtlas.SlotAt(LSlotIdx);
  Check(LSlot.W = 10, 'slot: width matches');
  Check(LSlot.H = 12, 'slot: height matches');
  Check(LSlot.BearingXPx = 1, 'slot: bearing X matches');
  Check(LSlot.BearingYPx = 10, 'slot: bearing Y matches');
  Check(LSlot.AdvancePx = 12, 'slot: advance matches');
  Check(LSlot.Occupied, 'slot: occupied');

  LAtlas.Free;
end;

procedure TestLookupMiss;
var
  LAtlas: TFontAtlas;
  LKey: TFontAtlasKey;
begin
  LAtlas := TFontAtlas.Create(128, 128);
  LKey := FontAtlasKeyMake(999, 16);
  Check(LAtlas.Lookup(LKey) = -1, 'lookup miss: returns -1');
  LAtlas.Free;
end;

procedure TestPackMultiple;
var
  LAtlas: TFontAtlas;
  LRaster: TFontRasterResult;
  LKeyA, LKeyB, LKeyC: TFontAtlasKey;
  LSlotA, LSlotB, LSlotC: Int32;
begin
  LAtlas := TFontAtlas.Create(128, 128);

  LRaster.WidthPx := 8;
  LRaster.HeightPx := 8;
  LRaster.PitchBytes := 8;
  LRaster.BearingXPx := 0;
  LRaster.BearingYPx := 8;
  LRaster.AdvancePx := 8;
  SetLength(LRaster.Pixels, 64);
  FillChar(LRaster.Pixels[0], 64, $AA);

  LKeyA := FontAtlasKeyMake(65, 16);
  LKeyB := FontAtlasKeyMake(66, 16);
  LKeyC := FontAtlasKeyMake(67, 16);

  LSlotA := LAtlas.Pack(LKeyA, LRaster);
  LSlotB := LAtlas.Pack(LKeyB, LRaster);
  LSlotC := LAtlas.Pack(LKeyC, LRaster);

  Check(LSlotA >= 0, 'pack multiple: slot A valid');
  Check(LSlotB >= 0, 'pack multiple: slot B valid');
  Check(LSlotC >= 0, 'pack multiple: slot C valid');
  Check(LSlotA <> LSlotB, 'pack multiple: A != B');
  Check(LSlotB <> LSlotC, 'pack multiple: B != C');
  Check(LAtlas.SlotCount = 3, 'pack multiple: count is 3');

  LAtlas.Free;
end;

procedure TestPackSameKeyUpdate;
var
  LAtlas: TFontAtlas;
  LRaster1, LRaster2: TFontRasterResult;
  LKey: TFontAtlasKey;
  LSlot1, LSlot2: Int32;
begin
  LAtlas := TFontAtlas.Create(128, 128);

  LRaster1.WidthPx := 8;
  LRaster1.HeightPx := 8;
  LRaster1.PitchBytes := 8;
  LRaster1.BearingXPx := 0;
  LRaster1.BearingYPx := 8;
  LRaster1.AdvancePx := 8;
  SetLength(LRaster1.Pixels, 64);
  FillChar(LRaster1.Pixels[0], 64, $AA);

  LKey := FontAtlasKeyMake(65, 16);
  LSlot1 := LAtlas.Pack(LKey, LRaster1);
  Check(LAtlas.SlotCount = 1, 'pack update: count is 1 after first pack');

  // Pack same key with different data.
  FillChar(LRaster2, SizeOf(LRaster2), 0);
  LRaster2.WidthPx := 12;
  LRaster2.HeightPx := 14;
  LRaster2.PitchBytes := 12;
  LRaster2.BearingXPx := 2;
  LRaster2.BearingYPx := 12;
  LRaster2.AdvancePx := 14;
  SetLength(LRaster2.Pixels, 168);
  FillChar(LRaster2.Pixels[0], 168, $BB);

  LSlot2 := LAtlas.Pack(LKey, LRaster2);
  Check(LSlot2 = LSlot1, 'pack update: same slot index');
  Check(LAtlas.SlotCount = 1, 'pack update: count still 1');
  Check(LAtlas.SlotAt(LSlot2).W = 12, 'pack update: width updated');
  Check(LAtlas.SlotAt(LSlot2).AdvancePx = 14, 'pack update: advance updated');

  LAtlas.Free;
end;

procedure TestSlotAtOutOfBounds;
var
  LAtlas: TFontAtlas;
  LSlot: TFontAtlasSlot;
begin
  LAtlas := TFontAtlas.Create(128, 128);
  LSlot := LAtlas.SlotAt(-1);
  Check(not LSlot.Occupied, 'slot at out of bounds: not occupied (-1)');
  LSlot := LAtlas.SlotAt(0);
  Check(not LSlot.Occupied, 'slot at out of bounds: not occupied (0 on empty)');
  LSlot := LAtlas.SlotAt(999);
  Check(not LSlot.Occupied, 'slot at out of bounds: not occupied (999)');
  LAtlas.Free;
end;

{ ---- Shelf packing ---- }

procedure TestShelfPacking;
var
  LAtlas: TFontAtlas;
  LRaster: TFontRasterResult;
  LKey: TFontAtlasKey;
  I: Int32;
  LSlot: TFontAtlasSlot;
begin
  LAtlas := TFontAtlas.Create(64, 64);

  // Pack several 8x8 glyphs into one shelf.
  LRaster.WidthPx := 8;
  LRaster.HeightPx := 8;
  LRaster.PitchBytes := 8;
  LRaster.BearingXPx := 0;
  LRaster.BearingYPx := 8;
  LRaster.AdvancePx := 8;
  SetLength(LRaster.Pixels, 64);
  FillChar(LRaster.Pixels[0], 64, $CC);

  for I := 0 to 7 do
  begin
    LKey := FontAtlasKeyMake(I, 16);
    LAtlas.Pack(LKey, LRaster);
  end;
  Check(LAtlas.SlotCount = 8, 'shelf: 8 glyphs in one row (64px / 8px)');

  // All should be on the same shelf (Y=0).
  for I := 0 to 7 do
  begin
    LSlot := LAtlas.SlotAt(I);
    Check(LSlot.Y = 0, Format('shelf: glyph %d Y=0', [I]));
    Check(LSlot.X = I * 8, Format('shelf: glyph %d X=%d', [I, I * 8]));
  end;

  LAtlas.Free;
end;

procedure TestNewShelf;
var
  LAtlas: TFontAtlas;
  LRaster: TFontRasterResult;
  LKey: TFontAtlasKey;
  LSlot: TFontAtlasSlot;
begin
  LAtlas := TFontAtlas.Create(32, 32);

  // Fill first shelf: 4 x 8px wide = 32px.
  LRaster.WidthPx := 8;
  LRaster.HeightPx := 8;
  LRaster.PitchBytes := 8;
  LRaster.BearingXPx := 0;
  LRaster.BearingYPx := 8;
  LRaster.AdvancePx := 8;
  SetLength(LRaster.Pixels, 64);
  FillChar(LRaster.Pixels[0], 64, $CC);

  LKey := FontAtlasKeyMake(1, 16);
  LAtlas.Pack(LKey, LRaster);
  LKey := FontAtlasKeyMake(2, 16);
  LAtlas.Pack(LKey, LRaster);
  LKey := FontAtlasKeyMake(3, 16);
  LAtlas.Pack(LKey, LRaster);
  LKey := FontAtlasKeyMake(4, 16);
  LAtlas.Pack(LKey, LRaster);
  Check(LAtlas.SlotCount = 4, 'new shelf: first shelf full');

  // 5th glyph should go to new shelf.
  LKey := FontAtlasKeyMake(5, 16);
  LAtlas.Pack(LKey, LRaster);
  Check(LAtlas.SlotCount = 5, 'new shelf: 5th glyph packed');

  LSlot := LAtlas.SlotAt(4);
  Check(LSlot.Y = 8, 'new shelf: 5th glyph on shelf Y=8');
  Check(LSlot.X = 0, 'new shelf: 5th glyph X=0');

  LAtlas.Free;
end;

{ ---- LRU eviction ---- }

procedure TestLRUEviction;
var
  LAtlas: TFontAtlas;
  LRaster: TFontRasterResult;
  LKey: TFontAtlasKey;
  I: Int32;
begin
  // Tiny atlas: 32x16. Can hold 4 glyphs of 8x8 on one shelf.
  LAtlas := TFontAtlas.Create(32, 16);

  LRaster.WidthPx := 8;
  LRaster.HeightPx := 8;
  LRaster.PitchBytes := 8;
  LRaster.BearingXPx := 0;
  LRaster.BearingYPx := 8;
  LRaster.AdvancePx := 8;
  SetLength(LRaster.Pixels, 64);
  FillChar(LRaster.Pixels[0], 64, $CC);

  // Fill the atlas completely.
  for I := 0 to 3 do
  begin
    LKey := FontAtlasKeyMake(I, 16);
    LAtlas.Pack(LKey, LRaster);
  end;
  Check(LAtlas.SlotCount = 4, 'eviction: atlas full');

  // Advance frame and access glyph 0 to keep it alive.
  LAtlas.AdvanceFrame;
  LAtlas.AdvanceFrame;
  LKey := FontAtlasKeyMake(0, 16);
  LAtlas.Lookup(LKey);

  // Pack a new glyph — should trigger LRU eviction of old entries.
  LKey := FontAtlasKeyMake(100, 16);
  LAtlas.Pack(LKey, LRaster);

  // The new glyph should be packed.
  Check(LAtlas.Lookup(LKey) >= 0, 'eviction: new glyph packed');

  // Glyph 0 (most recently accessed) should survive.
  LKey := FontAtlasKeyMake(0, 16);
  Check(LAtlas.Lookup(LKey) >= 0, 'eviction: recently accessed glyph survives');

  LAtlas.Free;
end;

procedure TestLRUFrameAdvance;
var
  LAtlas: TFontAtlas;
begin
  LAtlas := TFontAtlas.Create(64, 64);
  Check(LAtlas.FrameCounter = 0, 'frame advance: initial counter is 0');
  LAtlas.AdvanceFrame;
  Check(LAtlas.FrameCounter = 1, 'frame advance: counter is 1');
  LAtlas.AdvanceFrame;
  LAtlas.AdvanceFrame;
  Check(LAtlas.FrameCounter = 3, 'frame advance: counter is 3');
  LAtlas.Free;
end;

{ ---- Pixel data ---- }

procedure TestPixelData;
var
  LAtlas: TFontAtlas;
  LRaster: TFontRasterResult;
  LKey: TFontAtlasKey;
  LSlotIdx: Int32;
  LSlot: TFontAtlasSlot;
  LPtr: PByte;
  LX, LY, LIdx: Int32;
begin
  LAtlas := TFontAtlas.Create(64, 64);

  // Create a 4x4 glyph with known pixel values.
  LRaster.WidthPx := 4;
  LRaster.HeightPx := 4;
  LRaster.PitchBytes := 4;
  LRaster.BearingXPx := 0;
  LRaster.BearingYPx := 4;
  LRaster.AdvancePx := 4;
  SetLength(LRaster.Pixels, 16);
  // Fill with pattern: each pixel = index.
  for LY := 0 to 3 do
    for LX := 0 to 3 do
      LRaster.Pixels[LY * 4 + LX] := (LY * 4 + LX + 1) * 10;

  LKey := FontAtlasKeyMake(65, 16);
  LSlotIdx := LAtlas.Pack(LKey, LRaster);
  LSlot := LAtlas.SlotAt(LSlotIdx);

  // Verify pixel data in atlas.
  LPtr := LAtlas.PixelPtr;
  for LY := 0 to 3 do
    for LX := 0 to 3 do
    begin
      LIdx := (LSlot.Y + LY) * LAtlas.Width + (LSlot.X + LX);
      Check(LPtr[LIdx] = (LY * 4 + LX + 1) * 10,
        Format('pixel data: [%d,%d] = %d', [LX, LY, (LY * 4 + LX + 1) * 10]));
    end;

  LAtlas.Free;
end;

procedure TestClearResetsPixels;
var
  LAtlas: TFontAtlas;
  LRaster: TFontRasterResult;
  LKey: TFontAtlasKey;
  LPtr: PByte;
  LI: Int32;
  LAllZero: Boolean;
begin
  LAtlas := TFontAtlas.Create(64, 64);

  LRaster.WidthPx := 4;
  LRaster.HeightPx := 4;
  LRaster.PitchBytes := 4;
  LRaster.BearingXPx := 0;
  LRaster.BearingYPx := 4;
  LRaster.AdvancePx := 4;
  SetLength(LRaster.Pixels, 16);
  FillChar(LRaster.Pixels[0], 16, $FF);

  LKey := FontAtlasKeyMake(65, 16);
  LAtlas.Pack(LKey, LRaster);
  LAtlas.Clear;

  // All pixels should be zero after clear.
  LPtr := LAtlas.PixelPtr;
  LAllZero := True;
  for LI := 0 to 64 * 64 - 1 do
    if LPtr[LI] <> 0 then
    begin
      LAllZero := False;
      Break;
    end;
  Check(LAllZero, 'clear pixels: all zero after clear');

  LAtlas.Free;
end;

{ ---- Real font integration ---- }

procedure TestPackRealGlyph;
var
  LRasterizer: TFontRasterizer;
  LAtlas: TFontAtlas;
  LRaster: TFontRasterResult;
  LOutline: TFontGlyphOutline;
  LGlyphIdx: UInt16;
  LKey: TFontAtlasKey;
  LSlotIdx: Int32;
  LSlot: TFontAtlasSlot;
begin
  LRasterizer := TFontRasterizer.Create;
  LAtlas := TFontAtlas.Create(256, 256);

  LGlyphIdx := GFace.LookupCodepoint(65);
  LOutline := GFace.GlyphOutline(LGlyphIdx);
  LRaster := LRasterizer.Rasterize(LOutline, 16, GFace.Metrics.UnitsPerEm);
  Check((LRaster.WidthPx > 0) and (LRaster.HeightPx > 0),
    'real glyph: rasterizer produces non-empty result');

  LKey := FontAtlasKeyMake(65, 16);
  LSlotIdx := LAtlas.Pack(LKey, LRaster);
  Check(LSlotIdx >= 0, 'real glyph: packed into atlas');

  LSlot := LAtlas.SlotAt(LSlotIdx);
  Check(LSlot.W = LRaster.WidthPx, 'real glyph: slot width matches raster');
  Check(LSlot.H = LRaster.HeightPx, 'real glyph: slot height matches raster');
  Check(LSlot.BearingXPx = LRaster.BearingXPx, 'real glyph: bearing X matches');
  Check(LSlot.AdvancePx = LRaster.AdvancePx, 'real glyph: advance matches');

  // Lookup should find it.
  Check(LAtlas.Lookup(LKey) = LSlotIdx, 'real glyph: lookup finds packed glyph');

  LRasterizer.Free;
  LAtlas.Free;
end;

procedure TestPackMultipleRealGlyphs;
var
  LRasterizer: TFontRasterizer;
  LAtlas: TFontAtlas;
  LRaster: TFontRasterResult;
  LOutline: TFontGlyphOutline;
  LGlyphIdx: UInt16;
  LKey: TFontAtlasKey;
  I, LSlotIdx: Int32;
  LCodepoints: array[0..4] of UInt32 = (65, 66, 67, 48, 103); // A B C 0 g
begin
  LRasterizer := TFontRasterizer.Create;
  LAtlas := TFontAtlas.Create(512, 512);

  for I := 0 to 4 do
  begin
    LGlyphIdx := GFace.LookupCodepoint(LCodepoints[I]);
    LOutline := GFace.GlyphOutline(LGlyphIdx);
    LRaster := LRasterizer.Rasterize(LOutline, 24, GFace.Metrics.UnitsPerEm);
    if (LRaster.WidthPx > 0) and (LRaster.HeightPx > 0) then
    begin
      LKey := FontAtlasKeyMake(LCodepoints[I], 24);
      LSlotIdx := LAtlas.Pack(LKey, LRaster);
      Check(LSlotIdx >= 0,
        Format('multiple real: glyph %d packed', [LCodepoints[I]]));
    end;
  end;

  Check(LAtlas.SlotCount = 5, 'multiple real: 5 glyphs in atlas');

  // All should be lookable.
  for I := 0 to 4 do
  begin
    LKey := FontAtlasKeyMake(LCodepoints[I], 24);
    Check(LAtlas.Lookup(LKey) >= 0,
      Format('multiple real: glyph %d found', [LCodepoints[I]]));
  end;

  LRasterizer.Free;
  LAtlas.Free;
end;

{ ---- Edge cases ---- }

procedure TestPackZeroSizeGlyph;
var
  LAtlas: TFontAtlas;
  LRaster: TFontRasterResult;
  LKey: TFontAtlasKey;
  LSlotIdx: Int32;
begin
  LAtlas := TFontAtlas.Create(128, 128);

  // Space glyph: 0x0 bitmap.
  LRaster.WidthPx := 0;
  LRaster.HeightPx := 0;
  LRaster.PitchBytes := 0;
  LRaster.BearingXPx := 0;
  LRaster.BearingYPx := 0;
  LRaster.AdvancePx := 8;
  SetLength(LRaster.Pixels, 0);

  LKey := FontAtlasKeyMake(32, 16); // space
  LSlotIdx := LAtlas.Pack(LKey, LRaster);
  // Zero-size should still succeed (0x0 slot allocated at shelf position).
  Check(LSlotIdx >= 0, 'zero size: pack succeeds');
  Check(LAtlas.SlotAt(LSlotIdx).W = 0, 'zero size: slot W=0');
  Check(LAtlas.SlotAt(LSlotIdx).H = 0, 'zero size: slot H=0');

  LAtlas.Free;
end;

procedure TestLargeAtlas;
var
  LAtlas: TFontAtlas;
  LRaster: TFontRasterResult;
  LKey: TFontAtlasKey;
  I: Int32;
begin
  LAtlas := TFontAtlas.Create(ATLAS_MAX_WIDTH, ATLAS_MAX_HEIGHT);
  Check(LAtlas.Width = ATLAS_MAX_WIDTH, 'large atlas: width is max');
  Check(LAtlas.Height = ATLAS_MAX_HEIGHT, 'large atlas: height is max');

  // Pack many small glyphs.
  LRaster.WidthPx := 12;
  LRaster.HeightPx := 16;
  LRaster.PitchBytes := 12;
  LRaster.BearingXPx := 0;
  LRaster.BearingYPx := 14;
  LRaster.AdvancePx := 12;
  SetLength(LRaster.Pixels, 192);
  FillChar(LRaster.Pixels[0], 192, $DD);

  for I := 0 to 99 do
  begin
    LKey := FontAtlasKeyMake(I, 16);
    LAtlas.Pack(LKey, LRaster);
  end;
  Check(LAtlas.SlotCount = 100, 'large atlas: 100 glyphs packed');

  LAtlas.Free;
end;

begin
  WriteLn('test_font_atlas: starting');
  WriteLn;

  // Load test font.
  GFace := TTFontFace.Create('/usr/share/fonts/truetype/freefont/FreeMono.ttf');
  if not GFace.IsValid then
  begin
    WriteLn('FATAL: Cannot load FreeMono.ttf');
    Halt(1);
  end;
  GRasterizer := TFontRasterizer.Create;

  WriteLn('--- Key helpers ---');
  TestKeyMake;
  TestKeyEquals;

  WriteLn;
  WriteLn('--- Create/Destroy ---');
  TestCreateDefault;
  TestCreateSmall;
  TestCreateInvalidSize;
  TestCreateOversize;

  WriteLn;
  WriteLn('--- Clear ---');
  TestClear;

  WriteLn;
  WriteLn('--- Pack/Lookup ---');
  TestPackAndLookup;
  TestLookupMiss;
  TestPackMultiple;
  TestPackSameKeyUpdate;
  TestSlotAtOutOfBounds;

  WriteLn;
  WriteLn('--- Shelf packing ---');
  TestShelfPacking;
  TestNewShelf;

  WriteLn;
  WriteLn('--- LRU eviction ---');
  TestLRUEviction;
  TestLRUFrameAdvance;

  WriteLn;
  WriteLn('--- Pixel data ---');
  TestPixelData;
  TestClearResetsPixels;

  WriteLn;
  WriteLn('--- Real font integration ---');
  TestPackRealGlyph;
  TestPackMultipleRealGlyphs;

  WriteLn;
  WriteLn('--- Edge cases ---');
  TestPackZeroSizeGlyph;
  TestLargeAtlas;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GTestsPassed, GTestsFailed]));

  GRasterizer.Free;
  GFace.Free;

  if GTestsFailed > 0 then
    Halt(1);
end.
