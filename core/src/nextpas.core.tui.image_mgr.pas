unit nextpas.core.tui.image_mgr;

{$I nextpas.core.settings.inc}


interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.image_cap,
  nextpas.core.tui.buffer,
  nextpas.core.text.builder,
  nextpas.core.tui.sixel,
  nextpas.core.tui.backend.ansi;

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
    Chunks: array of Byte;
    ChunkLen: Integer;
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
    function FindSlot(Hash: QWord; PixelWidth, PixelHeight, DataLen: Integer): Integer;
    procedure EncodeTransmitChunks(var Slot: TImageSlot;
      DataPtr: Pointer; DataLen: Integer; PixelWidth, PixelHeight: Integer);
    procedure AppendPlace(Backend: TAnsiBackend; Id: LongWord; const Area: TRect);
    procedure AppendDelete(Backend: TAnsiBackend; Id: LongWord);
  public
    constructor Create(AProtocol: TImageProtocol);
    procedure InvalidateAll;
    procedure Resolve(var Buf: TBuffer; FrameStamp: Cardinal;
      Backend: TAnsiBackend; CellW, CellH: Word;
      const Patches: TDiffEntries; PatchCount: Integer);
  end;

implementation

uses
  SysUtils;

const
  MaxRawChunkBytes = 3072;
  MaxSlots = 256;
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
    FSlots[I].SixelCacheLen := 0;
    SetLength(FSlots[I].SixelCache, 0);
  end;
end;

procedure TImageManager.EncodeTransmitChunks(var Slot: TImageSlot;
  DataPtr: Pointer; DataLen: Integer; PixelWidth, PixelHeight: Integer);
var
  Tmp: nextpas.core.text.builder.TStringBuilder;
  Offset, ThisChunk: Integer;
  Header: AnsiString;
begin
  Tmp.Init(1024);

  if DataLen <= MaxRawChunkBytes then
  begin
    Header := Format(#27'_Ga=t,q=2,i=%d,f=32,s=%d,v=%d,m=0;',
      [Slot.Id, PixelWidth, PixelHeight]);
    Tmp.AppendStr(Header);
    Base64EncodeToBuilder(Tmp, PByte(DataPtr), DataLen);
    Tmp.AppendByte(Ord(#27));
    Tmp.AppendByte(Ord('\'));
  end
  else
  begin
    Offset := 0;
    while Offset < DataLen do
    begin
      ThisChunk := DataLen - Offset;
      if ThisChunk > MaxRawChunkBytes then ThisChunk := MaxRawChunkBytes;

      if Offset = 0 then
      begin
        if ThisChunk < DataLen then
          Header := Format(#27'_Ga=t,q=2,i=%d,f=32,s=%d,v=%d,m=1;',
            [Slot.Id, PixelWidth, PixelHeight])
        else
          Header := Format(#27'_Ga=t,q=2,i=%d,f=32,s=%d,v=%d,m=0;',
            [Slot.Id, PixelWidth, PixelHeight]);
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
      Inc(Offset, ThisChunk);
    end;
  end;

  Slot.ChunkLen := Tmp.Len;
  SetLength(Slot.Chunks, Slot.ChunkLen);
  if Slot.ChunkLen > 0 then
    Move(PByte(Tmp.AsView.Data)^, Slot.Chunks[0], Slot.ChunkLen);
end;

procedure TImageManager.AppendPlace(Backend: TAnsiBackend; Id: LongWord; const Area: TRect);
var
  Cmd: nextpas.core.text.builder.TStringBuilder;
  S: AnsiString;
begin
  Cmd.Init(256);
  Cmd.AppendByte(Ord(#27));
  Cmd.AppendByte(Ord('_'));
  Cmd.AppendByte(Ord('G'));
  S := Format('a=p,q=2,z=-1,i=%d,c=%d,r=%d,C=1', [Id, Area.Width, Area.Height]);
  Cmd.AppendStr(S);
  Cmd.AppendByte(Ord(#27));
  Cmd.AppendByte(Ord('\'));
  Backend.AppendRawBytes(PByte(Cmd.AsView.Data)^, Cmd.Len);
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
  S := Format('a=d,d=i,q=2,i=%d', [Id]);
  Cmd.AppendStr(S);
  Cmd.AppendByte(Ord(#27));
  Cmd.AppendByte(Ord('\'));
  Backend.AppendRawBytes(PByte(Cmd.AsView.Data)^, Cmd.Len);
end;

procedure TImageManager.Resolve(var Buf: TBuffer; FrameStamp: Cardinal;
  Backend: TAnsiBackend; CellW, CellH: Word;
  const Patches: TDiffEntries; PatchCount: Integer);

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
  I, SlotIdx, PlacementCount: Integer;
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
  PlacementCount := Buf.ImagePlacementCount;

  for I := 0 to PlacementCount - 1 do
  begin
    P := Buf.ImagePlacementAt(I);
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
      FSlots[SlotIdx].SixelCacheLen := 0;
    end;

    FSlots[SlotIdx].FrameStamp := FCurrentFrame;
    FSlots[SlotIdx].Area := P.Area;

    TargetW := P.PixelWidth;
    TargetH := P.PixelHeight;
    ScaledPtr := P.DataPtr;
    ScaledLen := P.DataLen;

    if (CellW > 0) and (CellH > 0) then
    begin
      TargetW := P.Area.Width * Integer(CellW);
      TargetH := P.Area.Height * Integer(CellH);
      if TargetW < 1 then TargetW := 1;
      if TargetH < 1 then TargetH := 1;
    end;

    if (TargetW < P.PixelWidth) or (TargetH < P.PixelHeight) then
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
        if not FSlots[SlotIdx].Transmitted then
        begin
          EncodeTransmitChunks(FSlots[SlotIdx], ScaledPtr, ScaledLen,
            TargetW, TargetH);
          Backend.AppendRawBytes(FSlots[SlotIdx].Chunks[0], FSlots[SlotIdx].ChunkLen);
          FSlots[SlotIdx].Transmitted := True;
          SetLength(FSlots[SlotIdx].Chunks, 0);
          FSlots[SlotIdx].ChunkLen := 0;
          FSlots[SlotIdx].Placed := False;
        end;

        if (not FSlots[SlotIdx].Placed) or
           (FSlots[SlotIdx].PlacedArea.X <> P.Area.X) or
           (FSlots[SlotIdx].PlacedArea.Y <> P.Area.Y) or
           (FSlots[SlotIdx].PlacedArea.Width <> P.Area.Width) or
           (FSlots[SlotIdx].PlacedArea.Height <> P.Area.Height) then
        begin
          Backend.MoveTo(P.Area.X, P.Area.Y);
          AppendPlace(Backend, FSlots[SlotIdx].Id, P.Area);
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
          Move(PByte(SixelBuf.AsView.Data)^, FSlots[SlotIdx].SixelCache[0], SixelBuf.Len);
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
