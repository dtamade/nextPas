program test_tui_image_mgr;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.buffer,
  nextpas.core.tui.backend.ansi,
  nextpas.core.tui.image_cap,
  nextpas.core.tui.image_mgr,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestImageManagerCreate;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipKitty);
  Check(LMgr <> nil, 'Should create image manager');
  LMgr.Free;
end;

procedure TestImageManagerCreateSixel;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipSixel);
  Check(LMgr <> nil, 'Should create sixel image manager');
  LMgr.Free;
end;

procedure TestImageManagerInvalidateAll;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipKitty);
  LMgr.InvalidateAll;
  Check(True, 'InvalidateAll should not crash');
  LMgr.Free;
end;

procedure TestImageManagerCreateHalfBlock;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipHalfBlock);
  Check(LMgr <> nil, 'Should create half-block image manager');
  LMgr.Free;
end;

procedure TestImageManagerInvalidateAllTwice;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipKitty);
  LMgr.InvalidateAll;
  LMgr.InvalidateAll;
  Check(True, 'InvalidateAll twice should not crash');
  LMgr.Free;
end;

procedure TestImageManagerInvalidateAllEmpty;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipSixel);
  LMgr.InvalidateAll;
  Check(True, 'InvalidateAll on empty manager should not crash');
  LMgr.Free;
end;

procedure TestImageManagerCreateMultiple;
var
  LMgr1, LMgr2: TImageManager;
begin
  LMgr1 := TImageManager.Create(ipKitty);
  LMgr2 := TImageManager.Create(ipSixel);
  Check(LMgr1 <> nil, 'First manager created');
  Check(LMgr2 <> nil, 'Second manager created');
  LMgr1.Free;
  LMgr2.Free;
end;

procedure TestImageManagerCreateAuto;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipAuto);
  try
    Check(LMgr <> nil, 'auto protocol manager');
  finally
    LMgr.Free;
  end;
end;

procedure TestImageManagerInvalidateAllAllProtocols;
var
  P: TImageProtocol;
  LMgr: TImageManager;
begin
  for P := Low(TImageProtocol) to High(TImageProtocol) do
  begin
    LMgr := TImageManager.Create(P);
    try
      LMgr.InvalidateAll;
      Check(True, 'invalidate protocol');
    finally
      LMgr.Free;
    end;
  end;
end;

procedure TestImageManagerCreateFreeCycle;
var
  I: Integer;
  LMgr: TImageManager;
begin
  for I := 1 to 5 do
  begin
    LMgr := TImageManager.Create(ipKitty);
    LMgr.Free;
  end;
  Check(True, 'create/free cycle');
end;

procedure TestImageManagerSixelInvalidateEmpty;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipSixel);
  try
    LMgr.InvalidateAll;
    LMgr.InvalidateAll;
    Check(True, 'sixel empty invalidate');
  finally
    LMgr.Free;
  end;
end;

procedure TestImageManagerHalfBlockThenKitty;
var
  LMgr: TImageManager;
begin
  LMgr := TImageManager.Create(ipHalfBlock);
  LMgr.Free;
  LMgr := TImageManager.Create(ipKitty);
  try
    Check(LMgr <> nil, 'recreate kitty after halfblock');
  finally
    LMgr.Free;
  end;
end;

{ 回归：区域被布局撑大（封面区吸收残差、高 DPI）时，重传必须"仅缩小"，
  不得放大——传输字节有上界（原图 base64 ≈480KB），否则 resize 归位
  重传会膨胀到 1MB+，拖拽放大窗口后封面归位明显变慢。 }
procedure TestResolveLargeAreaTransmitBounded;
var
  LMgr: TImageManager;
  LBackend: TAnsiBackend;
  LBuf: TBuffer;
  Pixels: array[0..300*300*4-1] of Byte;
  EmptyDiffs: TDiffEntries;
begin
  LMgr := TImageManager.Create(ipKitty);
  LBackend := TAnsiBackend.Create(-1, nil);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 50));
  try
    FillChar(Pixels, SizeOf(Pixels), 128);
    SetLength(EmptyDiffs, 0);
    { 300x300 封面、CellW=8 CellH=20；区域高 44 行 → Target 224x880（高远超原图） }
    LBuf.PlaceImage($1234, TRect.Make(1, 5, 28, 44), @Pixels[0],
      300*300*4, 300, 300);
    LMgr.Resolve(LBuf, 1, LBackend, 8, 20, EmptyDiffs, 0, False);
    Check(LBackend.PendingLength <= 500000,
      '大区域重传应 ≤ 原图量级（约480KB），不得放大传输');
  finally
    LBuf.Free;
    LBackend.Free;
    LMgr.Free;
  end;
end;

function BackendHasFrom(const B: TAnsiBackend; AFrom: Integer;
  const Needle: AnsiString): Boolean;
var
  I, J, L, N: Integer;
  P: PByte;
begin
  Result := False;
  L := Length(Needle);
  if L = 0 then Exit(True);
  if AFrom < 0 then AFrom := 0;
  N := B.PendingLength;
  if N - AFrom < L then Exit;
  P := B.PendingBytes;
  for I := AFrom to N - L do
  begin
    J := 0;
    while (J < L) and (P[I + J] = Byte(Needle[J + 1])) do Inc(J);
    if J = L then Exit(True);
  end;
end;

{ 回归：整图 base64（300x300 封面 ≈480KB）同步写入 PTY 会被终端消费
  背压阻塞 UI 线程（resize 归位"延迟"）。分帧传输后单帧写入 ≤32KB
  预算，跨帧渐进完成，最后放置。 }
procedure TestResolveThrottledAcrossFrames;
var
  LMgr: TImageManager;
  LBackend: TAnsiBackend;
  LBuf: TBuffer;
  Pixels: array[0..300*300*4-1] of Byte;
  EmptyDiffs: TDiffEntries;
  Frame: Cardinal;
  LPrev: Integer;
begin
  LMgr := TImageManager.Create(ipKitty);
  LBackend := TAnsiBackend.Create(-1, nil);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 50));
  try
    FillChar(Pixels, SizeOf(Pixels), 128);
    SetLength(EmptyDiffs, 0);
    { 区域 28x44（目标 224x880，高远超原图）→ 仅缩小规则 → 传原图 300x300 }
    LBuf.PlaceImage($1234, TRect.Make(1, 5, 28, 44), @Pixels[0],
      300*300*4, 300, 300);
    LMgr.Resolve(LBuf, 1, LBackend, 8, 20, EmptyDiffs, 0, False);
    { 首帧只写约 32KB（全局预算），不得一次性写完整 480KB }
    Check(LBackend.PendingLength <= 32 * 1024 + 512,
      '首帧传输应受 32KB 预算限制');
    Frame := 2;
    while Frame <= 30 do
    begin
      LPrev := LBackend.PendingLength;
      LMgr.Resolve(LBuf, Frame, LBackend, 8, 20, EmptyDiffs, 0, False);
      Check(LBackend.PendingLength - LPrev <= 32 * 1024 + 512,
        '每帧传输增量应 ≤ 32KB');
      if LBackend.PendingLength = LPrev then Break;
      Inc(Frame);
    end;
    { 全图最终传完并放置 }
    Check(LBackend.PendingLength > 400000,
      '分帧传输应最终完成整图（>400KB）');
    Check(Frame <= 20, '480KB 应在 ≤20 帧内完成');
    Check(not LMgr.HasPendingTransmit, '传输完成后无 pending');
  finally
    LBuf.Free;
    LBackend.Free;
    LMgr.Free;
  end;
end;

{ 回归：resize 后图片区域变化。扩大且已传数据分辨率足够 → 只重放
  不重传（避免 480KB 重传导致的归位延迟）；缩小/位移 → 按 id 删除
  后重传（清除旧单元格残影）。 }
procedure TestResolveGeometryReuse;
var
  LMgr: TImageManager;
  LBackend: TAnsiBackend;
  LBufBig, LBufBigger, LBufSmall: TBuffer;
  Pixels: array[0..300*300*4-1] of Byte;
  EmptyDiffs: TDiffEntries;
  Frame: Cardinal;
  LPrev: Integer;
begin
  LMgr := TImageManager.Create(ipKitty);
  LBackend := TAnsiBackend.Create(-1, nil);
  FillChar(Pixels, SizeOf(Pixels), 128);
  LBufBig := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 50));
  LBufBig.PlaceImage($1234, TRect.Make(1, 5, 28, 44), @Pixels[0],
    300*300*4, 300, 300);
  LBufBigger := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 50));
  LBufBigger.PlaceImage($1234, TRect.Make(1, 5, 30, 46), @Pixels[0],
    300*300*4, 300, 300);
  LBufSmall := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 50));
  LBufSmall.PlaceImage($1234, TRect.Make(1, 5, 10, 10), @Pixels[0],
    300*300*4, 300, 300);
  try
    SetLength(EmptyDiffs, 0);
    { 阶段 A：28x44 传完（数据 300x300，已放置） }
    Frame := 1;
    while Frame <= 30 do
    begin
      LPrev := LBackend.PendingLength;
      LMgr.Resolve(LBufBig, Frame, LBackend, 8, 20, EmptyDiffs, 0, True);
      if LBackend.PendingLength = LPrev then Break;
      Inc(Frame);
    end;
    Check(Frame <= 20, '大区域应在 20 帧内传完');
    LPrev := LBackend.PendingLength;
    { 阶段 B：扩大到 30x46（目标仍封顶 300x300，包含旧区域）→ 免重传 }
    LMgr.Resolve(LBufBigger, 100, LBackend, 8, 20, EmptyDiffs, 0, False);
    Check(not BackendHasFrom(LBackend, LPrev, 'a=t'),
      '扩大且分辨率足够时不应重传');
    Check(BackendHasFrom(LBackend, LPrev, 'a=p'),
      '扩大应重放（place 新区域）');
    Check(LBackend.PendingLength - LPrev <= 256,
      '扩大重放增量应只有 place 命令');
    LPrev := LBackend.PendingLength;
    { 阶段 C：缩小到 10x10（不包含旧区域）→ 按 id 删除并重传 }
    LMgr.Resolve(LBufSmall, 200, LBackend, 8, 20, EmptyDiffs, 0, False);
    Check(BackendHasFrom(LBackend, LPrev, 'a=d,d=i'),
      '缩小应删除旧显示（d,i 清显示保留终端数据）');
    Check(not BackendHasFrom(LBackend, LPrev, 'a=t'),
      '缩小复用已传数据，不应重传');
    Check(BackendHasFrom(LBackend, LPrev, 'a=p'),
      '缩小应 place 新区域');
  finally
    LBufBig.Free;
    LBufBigger.Free;
    LBufSmall.Free;
    LBackend.Free;
    LMgr.Free;
  end;
end;

{ 编码图流（kitty f=100 直传）：终端自解码，不做 RGBA 缩放——
  f=100 头 s/v 必须是真实像素尺寸，数据原样 base64 传输 }
procedure TestResolveEncodedPngKitty;
var
  LMgr: TImageManager;
  LBackend: TAnsiBackend;
  LBuf: TBuffer;
  Png: array[0..31] of Byte;
  EmptyDiffs: TDiffEntries;
  Frame: Cardinal;
  LPrev: Integer;
begin
  LMgr := TImageManager.Create(ipKitty);
  LBackend := TAnsiBackend.Create(-1, nil);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 50));
  try
    FillChar(Png, SizeOf(Png), 0);
    { PNG 签名 + IHDR:宽 20 高 10 }
    Png[0] := $89; Png[1] := $50; Png[2] := $4E; Png[3] := $47;
    Png[4] := $0D; Png[5] := $0A; Png[6] := $1A; Png[7] := $0A;
    Png[12] := $49; Png[13] := $48; Png[14] := $44; Png[15] := $52;
    Png[16] := 0; Png[17] := 0; Png[18] := 0; Png[19] := 20;  { width }
    Png[20] := 0; Png[21] := 0; Png[22] := 0; Png[23] := 10;  { height }
    SetLength(EmptyDiffs, 0);
    LBuf.PlaceImageEncoded($5678, TRect.Make(1, 5, 12, 6), @Png[0],
      SizeOf(Png), 20, 10);
    LMgr.Resolve(LBuf, 1, LBackend, 8, 20, EmptyDiffs, 0, False);
    { 首帧传输头必须用 f=100，s/v = 像素尺寸；数据量小(32B)一帧传完 }
    Check(BackendHasFrom(LBackend, 0, 'f=100'), 'encoded 传输头应 f=100');
    Check(BackendHasFrom(LBackend, 0, 's=20,v=10'),
      'encoded 传输 s/v 应为真实像素尺寸（不缩放不换算 cell）');
    Check(not BackendHasFrom(LBackend, 0, 'f=32'),
      'encoded 传输不得用 f=32 RGBA 格式');
    Frame := 2;
    while Frame <= 10 do
    begin
      LPrev := LBackend.PendingLength;
      LMgr.Resolve(LBuf, Frame, LBackend, 8, 20, EmptyDiffs, 0, False);
      if LBackend.PendingLength = LPrev then Break;
      Inc(Frame);
    end;
    Check(BackendHasFrom(LBackend, 0, 'a=p'),
      '传输完成后应放置图片');
    Check(not LMgr.HasPendingTransmit, '传输完成后无 pending');
  finally
    LBuf.Free;
    LBackend.Free;
    LMgr.Free;
  end;
end;

{ 刀 60 source-crop：SrcW/SrcH > 0 → 放置命令携带 kitty 源矩形键
  x/y/w/h（像素坐标）；全 0 → 不发射裁剪键（零回归） }
procedure TestResolveEncodedCropKitty;
var
  LMgr: TImageManager;
  LBackend: TAnsiBackend;
  LBuf: TBuffer;
  Png: array[0..31] of Byte;
  EmptyDiffs: TDiffEntries;
begin
  LMgr := TImageManager.Create(ipKitty);
  LBackend := TAnsiBackend.Create(-1, nil);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 50));
  try
    FillChar(Png, SizeOf(Png), 0);
    { PNG 签名 + IHDR:宽 20 高 10 }
    Png[0] := $89; Png[1] := $50; Png[2] := $4E; Png[3] := $47;
    Png[4] := $0D; Png[5] := $0A; Png[6] := $1A; Png[7] := $0A;
    Png[12] := $49; Png[13] := $48; Png[14] := $44; Png[15] := $52;
    Png[16] := 0; Png[17] := 0; Png[18] := 0; Png[19] := 20;  { width }
    Png[20] := 0; Png[21] := 0; Png[22] := 0; Png[23] := 10;  { height }
    SetLength(EmptyDiffs, 0);
    { 源带 y=4..8（h=5）：部分可见块只显示可见像素带 }
    LBuf.PlaceImageEncoded($9ABC, TRect.Make(2, 6, 12, 3), @Png[0],
      SizeOf(Png), 20, 10, 0, 4, 20, 5);
    LMgr.Resolve(LBuf, 1, LBackend, 8, 20, EmptyDiffs, 0, False);
    Check(BackendHasFrom(LBackend, 0, 'x=0,y=4,w=20,h=5'),
      'crop 放置应发射源矩形键 x/y/w/h');
    Check(BackendHasFrom(LBackend, 0, 'c=12,r=3'),
      'crop 放置仍携带目标格 c/r');
  finally
    LBuf.Free;
    LBackend.Free;
    LMgr.Free;
  end;

  LMgr := TImageManager.Create(ipKitty);
  LBackend := TAnsiBackend.Create(-1, nil);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 50));
  try
    SetLength(EmptyDiffs, 0);
    { 全 0 裁剪 = 整图：不得出现 x= 键（零回归锚） }
    LBuf.PlaceImageEncoded($9ABD, TRect.Make(2, 6, 12, 3), @Png[0],
      SizeOf(Png), 20, 10);
    LMgr.Resolve(LBuf, 1, LBackend, 8, 20, EmptyDiffs, 0, False);
    Check(BackendHasFrom(LBackend, 0, 'a=p'), '整图放置应有 a=p');
    Check(not BackendHasFrom(LBackend, 0, ',x='),
      '整图放置不应发射源矩形键');
  finally
    LBuf.Free;
    LBackend.Free;
    LMgr.Free;
  end;
end;

{ 编码图流在 sixel 协议下无输出：终端无解码能力，调用方自行降级 }
procedure TestResolveEncodedSixelSkipped;
var
  LMgr: TImageManager;
  LBackend: TAnsiBackend;
  LBuf: TBuffer;
  Png: array[0..31] of Byte;
  EmptyDiffs: TDiffEntries;
begin
  LMgr := TImageManager.Create(ipSixel);
  LBackend := TAnsiBackend.Create(-1, nil);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 50));
  try
    FillChar(Png, SizeOf(Png), 7);
    SetLength(EmptyDiffs, 0);
    LBuf.PlaceImageEncoded($5678, TRect.Make(1, 5, 12, 6), @Png[0],
      SizeOf(Png), 20, 10);
    LMgr.Resolve(LBuf, 1, LBackend, 8, 20, EmptyDiffs, 0, False);
    Check(LBackend.PendingLength = 0,
      'sixel 下 encoded 图流应跳过（无解码能力）');
  finally
    LBuf.Free;
    LBackend.Free;
    LMgr.Free;
  end;
end;

begin
  T := TTestSuite.Create('tui_image_mgr');
  T.Test('TImageManager.Create kitty', @TestImageManagerCreate);
  T.Test('TImageManager.Create sixel', @TestImageManagerCreateSixel);
  T.Test('TImageManager.InvalidateAll', @TestImageManagerInvalidateAll);
  T.Test('TImageManager.Create half-block', @TestImageManagerCreateHalfBlock);
  T.Test('TImageManager.InvalidateAll twice', @TestImageManagerInvalidateAllTwice);
  T.Test('TImageManager.InvalidateAll empty', @TestImageManagerInvalidateAllEmpty);
  T.Test('TImageManager.Create multiple', @TestImageManagerCreateMultiple);
  T.Test('Create auto', @TestImageManagerCreateAuto);
  T.Test('InvalidateAll all protocols', @TestImageManagerInvalidateAllAllProtocols);
  T.Test('Create free cycle', @TestImageManagerCreateFreeCycle);
  T.Test('Sixel invalidate empty', @TestImageManagerSixelInvalidateEmpty);
  T.Test('HalfBlock then Kitty', @TestImageManagerHalfBlockThenKitty);
  T.Test('Resolve large-area transmit bounded', @TestResolveLargeAreaTransmitBounded);
  T.Test('Resolve throttled across frames', @TestResolveThrottledAcrossFrames);
  T.Test('Resolve geometry reuse on expand', @TestResolveGeometryReuse);
  T.Test('Resolve encoded PNG kitty', @TestResolveEncodedPngKitty);
  T.Test('Resolve encoded skipped on sixel', @TestResolveEncodedSixelSkipped);
  T.Test('Resolve encoded crop keys (K60)', @TestResolveEncodedCropKitty);
  if not T.Run then Halt(1);
end.
