unit nextpas.core.tui.image_mgr;

{$I nextpas.core.settings.inc}


interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.image_cap,
  nextpas.core.tui.buffer,
  nextpas.core.text.builder,
  nextpas.core.tui.sixel,
  nextpas.core.tui.backend.ansi,
  nextpas.core.text.format;

type
  TImageSlot = record
    Id: LongWord;
    Hash: QWord;
    PixelWidth: Integer;
    PixelHeight: Integer;
    DataLen: Integer;
    Area: TRect;
    PlacedArea: TRect;
    FrameStamp: Cardinal;
    Transmitted: Boolean;
    Placed: Boolean;
    { 已传输数据的目标像素尺寸（kitty 数据按该尺寸编码，终端按放置
      矩形拉伸显示）；复用比较分辨率用 }
    DataW: Integer;
    DataH: Integer;
    Chunks: array of Byte;
    ChunkLen: Integer;
    { 各 kitty 分块在传输序列中的结束偏移。帧预算切分发送量时必须
      停在分块边界上，否则残缺 APC 会被终端拒绝并把负载当文本回显 }
    ChunkEnds: array of Integer;
    Pending: array of Byte;
    PendingLen: Integer;
    PendingSent: Integer;
    LastSentFrame: Cardinal;
    SixelCache: array of Byte;
    SixelCacheLen: Integer;
  end;

  TImageManager = class
  private
    FSlots: array of TImageSlot;
    FSlotCount: Integer;
    FNextId: LongWord;
    FCurrentFrame: Cardinal;
    FProtocol: TImageProtocol;
    { 本帧剩余可发送字节（全局预算，多个 slot 共享）；
      每次 Resolve 进入时重置为 MaxTransmitBytesPerFrame }
    FPendingBudget: Integer;
    function FindSlot(Hash: QWord; PixelWidth, PixelHeight, DataLen: Integer): Integer;
    procedure EncodeTransmitChunks(var Slot: TImageSlot;
      DataPtr: Pointer; DataLen: Integer; PixelWidth, PixelHeight: Integer;
      AEncoded: Boolean);
    procedure AppendPlace(Backend: TAnsiBackend; Id: LongWord;
      const P: TImagePlacement);
    procedure AppendDelete(Backend: TAnsiBackend; Id: LongWord);
  public
    constructor Create(AProtocol: TImageProtocol);
    procedure InvalidateAll;
    { 是否有图片处于分帧传输中（未传完）。调用方可据此加快帧循环，
      避免空闲帧率把渐进传输拖慢。 }
    function HasPendingTransmit: Boolean;
    { ABoosted=True 表示本帧为 resize 归位帧：待传数据一次发完（仍保持
      kitty 分块边界对齐），让松手后的封面重建立即完成而不是渐进 8ms/帧。
      普通帧（切歌等）继续 32KB/帧限流，避免慢终端/PTY 背压冻结。 }
    procedure Resolve(var Buf: TBuffer; FrameStamp: Cardinal;
      Backend: TAnsiBackend; CellW, CellH: Word;
      const Patches: TDiffEntries; PatchCount: Integer;
      ABoosted: Boolean);
  end;

implementation

uses
  nextpas.core.text.conv;

const
  MaxRawChunkBytes = 3072;
  MaxSlots = 256;
  { 每帧最多向终端发送的图像传输字节。整图 base64（300x300 封面
    ≈480KB）一次性同步写入 PTY 会被终端消费背压阻塞（UI 线程冻结，
    用户感知 resize 归位"延迟"）；拆帧限流后每帧写量有界，配合
    SynchronizedUpdate 不阻塞帧循环，图片跨数帧渐进重建。 }
  MaxTransmitBytesPerFrame = 32 * 1024;
  Base64Table: array[0..63] of Byte = (
    65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,
    97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,
    48,49,50,51,52,53,54,55,56,57,43,47);

procedure Base64EncodeToBuilder(var Out_: nextpas.core.text.builder.TStringBuilder; Src: PByte; Len: Integer);
var
  I: Integer;
  B0, B1, B2: Byte;
begin
  I := 0;
  while I + 2 < Len do
  begin
    B0 := Src[I]; B1 := Src[I+1]; B2 := Src[I+2];
    Out_.AppendByte(Base64Table[B0 shr 2]);
    Out_.AppendByte(Base64Table[((B0 and 3) shl 4) or (B1 shr 4)]);
    Out_.AppendByte(Base64Table[((B1 and $0F) shl 2) or (B2 shr 6)]);
    Out_.AppendByte(Base64Table[B2 and $3F]);
    Inc(I, 3);
  end;
  case Len - I of
    1: begin
      B0 := Src[I];
      Out_.AppendByte(Base64Table[B0 shr 2]);
      Out_.AppendByte(Base64Table[(B0 and 3) shl 4]);
      Out_.AppendByte(Ord('='));
      Out_.AppendByte(Ord('='));
    end;
    2: begin
      B0 := Src[I]; B1 := Src[I+1];
      Out_.AppendByte(Base64Table[B0 shr 2]);
      Out_.AppendByte(Base64Table[((B0 and 3) shl 4) or (B1 shr 4)]);
      Out_.AppendByte(Base64Table[(B1 and $0F) shl 2]);
      Out_.AppendByte(Ord('='));
    end;
  end;
end;

constructor TImageManager.Create(AProtocol: TImageProtocol);
begin
  inherited Create;
  FSlotCount := 0;
  FNextId := 1;
  FCurrentFrame := 0;
  FProtocol := AProtocol;
end;

function TImageManager.FindSlot(Hash: QWord; PixelWidth, PixelHeight, DataLen: Integer): Integer;
var I: Integer;
begin
  for I := 0 to FSlotCount - 1 do
    if (FSlots[I].Hash = Hash) and (FSlots[I].PixelWidth = PixelWidth) and
       (FSlots[I].PixelHeight = PixelHeight) and (FSlots[I].DataLen = DataLen) then
      Exit(I);
  Result := -1;
end;

procedure TImageManager.InvalidateAll;
var I: Integer;
begin
  for I := 0 to FSlotCount - 1 do
  begin
    FSlots[I].Transmitted := False;
    FSlots[I].Placed := False;
    FSlots[I].PendingLen := 0;
    FSlots[I].PendingSent := 0;
    SetLength(FSlots[I].Pending, 0);
    SetLength(FSlots[I].ChunkEnds, 0);
    FSlots[I].SixelCacheLen := 0;
    SetLength(FSlots[I].SixelCache, 0);
  end;
end;

function TImageManager.HasPendingTransmit: Boolean;
var I: Integer;
begin
  for I := 0 to FSlotCount - 1 do
    if (not FSlots[I].Transmitted) and
       (FSlots[I].PendingSent < FSlots[I].PendingLen) then
      Exit(True);
  Result := False;
end;

procedure TImageManager.EncodeTransmitChunks(var Slot: TImageSlot;
  DataPtr: Pointer; DataLen: Integer; PixelWidth, PixelHeight: Integer;
  AEncoded: Boolean);
var
  Tmp: nextpas.core.text.builder.TStringBuilder;
  Offset, ThisChunk, ChunkIdx: Integer;
  Header: AnsiString;
  Fmt: Integer;
begin
  Tmp.Init(1024);
  SetLength(Slot.ChunkEnds,
    (DataLen + MaxRawChunkBytes - 1) div MaxRawChunkBytes);

  { AEncoded：原始编码图流（PNG 等）走 f=100 直传，终端自解码；
    调用方需在 PixelWidth/Height 传入真实像素尺寸（f=100 的 s/v
    终端用于布局，非 RGBA 禁用 f=32 的 4 字节/像素假设）。 }
  if AEncoded then
    Fmt := 100
  else
    Fmt := 32;

  ChunkIdx := 0;
  Offset := 0;
  while Offset < DataLen do
  begin
    ThisChunk := DataLen - Offset;
    if ThisChunk > MaxRawChunkBytes then ThisChunk := MaxRawChunkBytes;

    if Offset = 0 then
    begin
      if ThisChunk < DataLen then
        Header := TextFormat(#27'_Ga=t,q=2,i=%d,f=%d,s=%d,v=%d,m=1;',
          [Slot.Id, Fmt, PixelWidth, PixelHeight])
      else
        Header := TextFormat(#27'_Ga=t,q=2,i=%d,f=%d,s=%d,v=%d,m=0;',
          [Slot.Id, Fmt, PixelWidth, PixelHeight]);
    end
    else
    begin
      if Offset + ThisChunk < DataLen then
        Header := #27'_Gm=1;'
      else
        Header := #27'_Gm=0;';
    end;

    Tmp.AppendStr(Header);
    Base64EncodeToBuilder(Tmp, PByte(DataPtr) + Offset, ThisChunk);
    Tmp.AppendByte(Ord(#27));
    Tmp.AppendByte(Ord('\'));
    Slot.ChunkEnds[ChunkIdx] := Tmp.Len;
    Inc(ChunkIdx);
    Inc(Offset, ThisChunk);
  end;

  Slot.ChunkLen := Tmp.Len;
  SetLength(Slot.Chunks, Slot.ChunkLen);
  if Slot.ChunkLen > 0 then
    Move(PByte(Tmp.AsView.Data)^, Slot.Chunks[0], Slot.ChunkLen);
  Tmp.Done;
end;

procedure TImageManager.AppendPlace(Backend: TAnsiBackend; Id: LongWord;
  const P: TImagePlacement);
var
  Cmd: nextpas.core.text.builder.TStringBuilder;
  S: AnsiString;
begin
  Cmd.Init(256);
  Cmd.AppendByte(Ord(#27));
  Cmd.AppendByte(Ord('_'));
  Cmd.AppendByte(Ord('G'));
  { 刀 60 source-crop：SrcW/SrcH > 0 → 发射 kitty 源矩形键 x/y/w/h
    （像素坐标），终端只显示该带——部分可见块局部放置 }
  if (P.SrcW > 0) and (P.SrcH > 0) then
    S := TextFormat('a=p,q=2,z=-1,i=%d,x=%d,y=%d,w=%d,h=%d,c=%d,r=%d,C=1',
      [Id, P.SrcX, P.SrcY, P.SrcW, P.SrcH, P.Area.Width, P.Area.Height])
  else
    S := TextFormat('a=p,q=2,z=-1,i=%d,c=%d,r=%d,C=1',
      [Id, P.Area.Width, P.Area.Height]);
  Cmd.AppendStr(S);
  Cmd.AppendByte(Ord(#27));
  Cmd.AppendByte(Ord('\'));
  Backend.AppendRawBytes(PByte(Cmd.AsView.Data)^, Cmd.Len);
  Cmd.Done;
end;

procedure TImageManager.AppendDelete(Backend: TAnsiBackend; Id: LongWord);
var
  Cmd: nextpas.core.text.builder.TStringBuilder;
  S: AnsiString;
begin
  Cmd.Init(256);
  Cmd.AppendByte(Ord(#27));
  Cmd.AppendByte(Ord('_'));
  Cmd.AppendByte(Ord('G'));
  S := TextFormat('a=d,d=i,q=2,i=%d', [Id]);
  Cmd.AppendStr(S);
  Cmd.AppendByte(Ord(#27));
  Cmd.AppendByte(Ord('\'));
  Backend.AppendRawBytes(PByte(Cmd.AsView.Data)^, Cmd.Len);
  Cmd.Done;
end;

procedure TImageManager.Resolve(var Buf: TBuffer; FrameStamp: Cardinal;
  Backend: TAnsiBackend; CellW, CellH: Word;
  const Patches: TDiffEntries; PatchCount: Integer;
  ABoosted: Boolean);

  function AreaIsDirty(const A: TRect): Boolean;
  var J: Integer;
  begin
    for J := 0 to PatchCount - 1 do
      if (Patches[J].X >= A.X) and (Patches[J].X < A.X + A.Width) and
         (Patches[J].Y >= A.Y) and (Patches[J].Y < A.Y + A.Height) then
        Exit(True);
    Result := False;
  end;

var
  I, J, SlotIdx, PlacementCount: Integer;
  LSend, Target: Integer;
  P: TImagePlacement;
  Cap: Integer;
  TargetW, TargetH: Integer;
  ScaledPtr: PByte;
  ScaledLen: Integer;
  ScaledPixels: TScaledPixelBuf;
  SixelBuf: nextpas.core.text.builder.TStringBuilder;
  NeedEmit: Boolean;
begin
  FCurrentFrame := FrameStamp;
  FPendingBudget := MaxTransmitBytesPerFrame;
  if ABoosted then
    FPendingBudget := MaxInt;   { 归位帧：一次传完，不牺牲分块边界 }
  PlacementCount := Buf.ImagePlacementCount;

  for I := 0 to PlacementCount - 1 do
  begin
    P := Buf.ImagePlacementAt(I);
    { encoded 图流只走 kitty（终端自解码）；sixel/half-block 无解码
      能力，skip——调用方负责降级渲染 }
    if P.Encoded and (FProtocol <> ipKitty) then
      Continue;
    SlotIdx := FindSlot(P.Hash, P.PixelWidth, P.PixelHeight, P.DataLen);

    if SlotIdx < 0 then
    begin
      if FSlotCount >= MaxSlots then
      begin
        if FProtocol = ipKitty then
          AppendDelete(Backend, FSlots[0].Id);
        FSlots[0] := FSlots[FSlotCount - 1];
        Dec(FSlotCount);
      end;
      Cap := System.Length(FSlots);
      if FSlotCount >= Cap then
      begin
        if Cap = 0 then Cap := 4 else Cap := Cap * 2;
        if Cap > MaxSlots then Cap := MaxSlots;
        SetLength(FSlots, Cap);
      end;
      SlotIdx := FSlotCount;
      Inc(FSlotCount);
      FSlots[SlotIdx].Id := FNextId;
      Inc(FNextId);
      if FNextId = 0 then FNextId := 1;
      FSlots[SlotIdx].Hash := P.Hash;
      FSlots[SlotIdx].PixelWidth := P.PixelWidth;
      FSlots[SlotIdx].PixelHeight := P.PixelHeight;
      FSlots[SlotIdx].DataLen := P.DataLen;
      FSlots[SlotIdx].Transmitted := False;
      FSlots[SlotIdx].Placed := False;
      FSlots[SlotIdx].DataW := 0;
      FSlots[SlotIdx].DataH := 0;
      FSlots[SlotIdx].PendingLen := 0;
      FSlots[SlotIdx].PendingSent := 0;
      SetLength(FSlots[SlotIdx].ChunkEnds, 0);
      FSlots[SlotIdx].LastSentFrame := 0;
      FSlots[SlotIdx].SixelCacheLen := 0;
    end;

    FSlots[SlotIdx].FrameStamp := FCurrentFrame;

    TargetW := P.PixelWidth;
    TargetH := P.PixelHeight;
    ScaledPtr := P.DataPtr;
    ScaledLen := P.DataLen;

    if P.Encoded then
    begin
      { 编码图流：终端按占位矩形拉伸，传输头 s/v = 真实像素尺寸；
        编码数据无法重编码缩放，直接传原图 }
    end
    else if (CellW > 0) and (CellH > 0) then
    begin
      TargetW := P.Area.Width * Integer(CellW);
      TargetH := P.Area.Height * Integer(CellH);
      if TargetW < 1 then TargetW := 1;
      if TargetH < 1 then TargetH := 1;
    end;

    { 仅两维都小于原图才降采样（省带宽）；任一维达到/超过原图像素就
      传原图——区域被拉伸得很大时（如封面区吸收布局残差、高 DPI）若
      仍"缩放"会把图像放大传输，字节甚至超过原图，resize 归位变慢。 }
    if (TargetW < P.PixelWidth) and (TargetH < P.PixelHeight) then
    begin
      ScaleRgbaPixels(P.DataPtr, P.PixelWidth, P.PixelHeight,
        TargetW, TargetH, ScaledPixels);
      ScaledPtr := @ScaledPixels[0];
      ScaledLen := TargetW * TargetH * 4;
    end
    else
    begin
      TargetW := P.PixelWidth;
      TargetH := P.PixelHeight;
    end;

    case FProtocol of
      ipKitty:
      begin
        { 区域变化协调：已传数据分辨率足够（>= 新目标尺寸）时，无论新区域
          是扩大、平移还是缩小，都要先按 id 删除旧显示再重放——同 id 的
          place 是叠加语义，不清掉旧显示会残留拖影。delete 用小写 d=i
          （只清显示、保留终端存储的数据），重放无需重传整图。只有新目标
          分辨率超过已传数据（复用会模糊）才删除并整图重传。 }
        if FSlots[SlotIdx].Transmitted and
           ((FSlots[SlotIdx].PlacedArea.X <> P.Area.X) or
            (FSlots[SlotIdx].PlacedArea.Y <> P.Area.Y) or
            (FSlots[SlotIdx].PlacedArea.Width <> P.Area.Width) or
            (FSlots[SlotIdx].PlacedArea.Height <> P.Area.Height)) then
        begin
          if not ((FSlots[SlotIdx].DataW >= TargetW) and
                  (FSlots[SlotIdx].DataH >= TargetH)) then
          begin
            AppendDelete(Backend, FSlots[SlotIdx].Id);
            FSlots[SlotIdx].Transmitted := False;
            FSlots[SlotIdx].Placed := False;
            FSlots[SlotIdx].PendingLen := 0;
            FSlots[SlotIdx].PendingSent := 0;
            SetLength(FSlots[SlotIdx].Pending, 0);
            SetLength(FSlots[SlotIdx].ChunkEnds, 0);
            FSlots[SlotIdx].PlacedArea := TRect.Make(0, 0, 0, 0);
          end
          else
          begin
            { 数据仍在终端：清旧显示并按新区域重放，不重传 }
            AppendDelete(Backend, FSlots[SlotIdx].Id);
            FSlots[SlotIdx].Placed := False;
          end;
        end;

        if not FSlots[SlotIdx].Transmitted then
        begin
          if FSlots[SlotIdx].PendingLen = 0 then
          begin
            { 整段传输序列构建一次并缓存，随后逐帧限流发送 }
            EncodeTransmitChunks(FSlots[SlotIdx], ScaledPtr, ScaledLen,
              TargetW, TargetH, P.Encoded);
            FSlots[SlotIdx].DataW := TargetW;
            FSlots[SlotIdx].DataH := TargetH;
            FSlots[SlotIdx].Pending := FSlots[SlotIdx].Chunks;
            FSlots[SlotIdx].PendingLen := FSlots[SlotIdx].ChunkLen;
            FSlots[SlotIdx].PendingSent := 0;
            SetLength(FSlots[SlotIdx].Chunks, 0);
            FSlots[SlotIdx].ChunkLen := 0;
            FSlots[SlotIdx].Area := P.Area;
          end;
          { 传输中区域又变（新一轮 resize）：pending 按旧几何编码，
            作废，下一帧按新几何重编 }
          if (FSlots[SlotIdx].PendingSent < FSlots[SlotIdx].PendingLen) and
             ((FSlots[SlotIdx].Area.X <> P.Area.X) or
              (FSlots[SlotIdx].Area.Y <> P.Area.Y) or
              (FSlots[SlotIdx].Area.Width <> P.Area.Width) or
              (FSlots[SlotIdx].Area.Height <> P.Area.Height)) then
          begin
            FSlots[SlotIdx].PendingLen := 0;
            FSlots[SlotIdx].PendingSent := 0;
            SetLength(FSlots[SlotIdx].Pending, 0);
            SetLength(FSlots[SlotIdx].ChunkEnds, 0);
          end;

          { 每帧同一 slot 只发送一次（同帧多 placement 共享进度）；
            全局预算 FPendingBudget 由多个待传 slot 共享 }
          if (FSlots[SlotIdx].LastSentFrame <> FCurrentFrame) and
             (FSlots[SlotIdx].PendingSent < FSlots[SlotIdx].PendingLen) and
             (FPendingBudget > 0) then
          begin
            LSend := FSlots[SlotIdx].PendingLen - FSlots[SlotIdx].PendingSent;
            if LSend > FPendingBudget then
            begin
              { 帧预算不能把 kitty 分块（APC）从中间切开：残缺 APC 会被
                终端拒绝并把负载当文本回显。预算落在分块内部时发完整块，
                最多超预算一个分块（约 4KB），不影响限流目的。 }
              Target := FSlots[SlotIdx].PendingSent + FPendingBudget;
              Cap := -1;
              for J := 0 to System.Length(FSlots[SlotIdx].ChunkEnds) - 1 do
                if FSlots[SlotIdx].ChunkEnds[J] >= Target then
                begin
                  Cap := FSlots[SlotIdx].ChunkEnds[J];
                  Break;
                end;
              if Cap < 0 then
                Cap := FSlots[SlotIdx].PendingLen;
              LSend := Cap - FSlots[SlotIdx].PendingSent;
            end;
            Backend.AppendRawBytes(
              FSlots[SlotIdx].Pending[FSlots[SlotIdx].PendingSent], LSend);
            Inc(FSlots[SlotIdx].PendingSent, LSend);
            Dec(FPendingBudget, LSend);
            FSlots[SlotIdx].LastSentFrame := FCurrentFrame;
          end;
          if FSlots[SlotIdx].PendingSent >= FSlots[SlotIdx].PendingLen then
          begin
            FSlots[SlotIdx].Transmitted := True;
            SetLength(FSlots[SlotIdx].Pending, 0);
            FSlots[SlotIdx].PendingLen := 0;
            FSlots[SlotIdx].PendingSent := 0;
            FSlots[SlotIdx].Placed := False;
          end;
          { 未传完不发 place：数据不全时 place 会显示残缺 }
        end;

        if FSlots[SlotIdx].Transmitted and
           ((not FSlots[SlotIdx].Placed) or
            (FSlots[SlotIdx].PlacedArea.X <> P.Area.X) or
            (FSlots[SlotIdx].PlacedArea.Y <> P.Area.Y) or
            (FSlots[SlotIdx].PlacedArea.Width <> P.Area.Width) or
            (FSlots[SlotIdx].PlacedArea.Height <> P.Area.Height)) then
        begin
          Backend.MoveTo(P.Area.X, P.Area.Y);
          AppendPlace(Backend, FSlots[SlotIdx].Id, P);
          FSlots[SlotIdx].Placed := True;
          FSlots[SlotIdx].PlacedArea := P.Area;
        end;
      end;

      ipSixel:
      begin
        NeedEmit := (FSlots[SlotIdx].SixelCacheLen = 0) or
                    AreaIsDirty(P.Area) or
                    (FSlots[SlotIdx].PlacedArea.X <> P.Area.X) or
                    (FSlots[SlotIdx].PlacedArea.Y <> P.Area.Y) or
                    (FSlots[SlotIdx].PlacedArea.Width <> P.Area.Width) or
                    (FSlots[SlotIdx].PlacedArea.Height <> P.Area.Height);

        if FSlots[SlotIdx].SixelCacheLen = 0 then
        begin
          SixelBuf.Init(4096);
          EncodeSixelDCS(SixelBuf, ScaledPtr, TargetW, TargetH);
          FSlots[SlotIdx].SixelCacheLen := SixelBuf.Len;
          SetLength(FSlots[SlotIdx].SixelCache, SixelBuf.Len);
          Move(PByte(SixelBuf.AsView.Data)^, FSlots[SlotIdx].SixelCache[0],
            SixelBuf.Len);
          SixelBuf.Done;
        end;

        if NeedEmit then
        begin
          Backend.MoveTo(P.Area.X, P.Area.Y);
          Backend.AppendRawBytes(FSlots[SlotIdx].SixelCache[0],
            FSlots[SlotIdx].SixelCacheLen);
          FSlots[SlotIdx].Placed := True;
          FSlots[SlotIdx].PlacedArea := P.Area;
        end;
      end;
    else
      { ipAuto / ipHalfBlock: no image protocol output }
    end;
  end;

  I := 0;
  while I < FSlotCount do
  begin
    if FSlots[I].FrameStamp < FCurrentFrame then
    begin
      if FProtocol = ipKitty then
        AppendDelete(Backend, FSlots[I].Id);
      FSlots[I] := FSlots[FSlotCount - 1];
      Dec(FSlotCount);
    end
    else
      Inc(I);
  end;
end;

end.
