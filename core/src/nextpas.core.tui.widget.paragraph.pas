unit nextpas.core.tui.widget.paragraph;

{**
 * @desc TParagraph — 文本段落 widget（wrap + alignment + scroll + optional block）。
 *
 * 实现 IWidget。支持 Wrap(trim) + 对齐 Left/Center/Right + 垂直滚动 +
 * 可选 IBlock 外框。Word-wrapper 算法简化版对齐 ratatui WordWrapper。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.text,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block;

type
  TWrap = packed record
    Trim: Boolean;
  end;

  IParagraph = interface(IWidget)
    ['{D1E2F3A4-B5C6-7D8E-9F0A-1B2C3D4E5F6A}']
    function WithStyle(const AStyle: TStyle): IParagraph;
    function WithBlock(ABlock: IBlock): IParagraph;
    function WithWrap(const AWrap: TWrap): IParagraph;
    function WithAlignment(AAlignment: TAlignment): IParagraph;
    function WithScrollY(AY: Word): IParagraph;
  end;

  TParagraph = class(TInterfacedObject, IWidget, IParagraph)
  private
    FText: TText;
    FStyle: TStyle;
    FBlock: IBlock;
    FHasWrap: Boolean;
    FWrap: TWrap;
    FHasAlignment: Boolean;
    FAlignment: TAlignment;
    FScrollY: Word;
  public
    class function New(const AText: TText): IParagraph; static;
    class function FromString(const AStr: AnsiString): IParagraph; static;
    { 快捷：带 wrap+trim 的文本段落（最常用模式） }
    class function Wrapped(const AStr: AnsiString): IParagraph; static;

    function WithStyle(const AStyle: TStyle): IParagraph;
    function WithBlock(ABlock: IBlock): IParagraph;
    function WithWrap(const AWrap: TWrap): IParagraph;
    function WithAlignment(AAlignment: TAlignment): IParagraph;
    function WithScrollY(AY: Word): IParagraph;

    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

const
  WRAP_TRIM: TWrap = (Trim: True);

implementation

uses
  nextpas.core.text.utf8,
  nextpas.core.text.width;

type
  TGraphemeAdv = record
    ByteLen: Integer;
    Width: Integer;
  end;

function GraphemeAt(const ABuf: AnsiString; ALen, AOffset: Integer): TGraphemeAdv; inline;
var
  LDec: TUTF8DecodeResult;
begin
  LDec := UTF8Decode(@PByte(Pointer(ABuf))[AOffset], ALen - AOffset);
  if LDec.ByteLen = 0 then
  begin
    Result.ByteLen := 1;
    Result.Width := 1;
  end
  else
  begin
    Result.ByteLen := LDec.ByteLen;
    Result.Width := CodepointWidth(LDec.CodePoint);
  end;
end;

function GraphemeWidthRange(const AStr: AnsiString; AByteStart, AByteEnd: Integer): Integer;
var
  LP: Integer;
  LAdv: TGraphemeAdv;
begin
  Result := 0;
  LP := AByteStart;
  while LP < AByteEnd do
  begin
    LAdv := GraphemeAt(AStr, System.Length(AStr), LP);
    Inc(Result, LAdv.Width);
    Inc(LP, LAdv.ByteLen);
  end;
end;

function GetLineOffset(AItemW, AWidth: Integer; AAlign: TAlignment): Integer; inline;
begin
  case AAlign of
    caCenter: Result := (AWidth div 2) - (AItemW div 2);
    caRight:  Result := AWidth - AItemW;
  else
    Result := 0;
  end;
  if Result < 0 then Result := 0;
end;

type
  TByteSpanIdx = array of Integer;

  TWrappedLine = record
    SrcLine: Integer;
    ByteStart, ByteEnd: Integer;
    Alignment: TAlignment;
  end;
  TWrappedLines = array of TWrappedLine;

procedure FlattenLine(const ALine: TLine;
  out ABuf: AnsiString; var ASpanByByte: TByteSpanIdx);
var
  LI, LJ, LTotal, LPos: Integer;
begin
  LTotal := 0;
  for LI := 0 to System.High(ALine.Spans) do
    Inc(LTotal, System.Length(ALine.Spans[LI].Content));
  SetLength(ABuf, LTotal);
  SetLength(ASpanByByte, LTotal);
  LPos := 1;
  for LI := 0 to System.High(ALine.Spans) do
  begin
    if System.Length(ALine.Spans[LI].Content) > 0 then
    begin
      Move(ALine.Spans[LI].Content[1], ABuf[LPos], System.Length(ALine.Spans[LI].Content));
      for LJ := 0 to System.Length(ALine.Spans[LI].Content) - 1 do
        ASpanByByte[LPos - 1 + LJ] := LI;
      Inc(LPos, System.Length(ALine.Spans[LI].Content));
    end;
  end;
end;

procedure WrapOneLine(ASrcIdx: Integer; const AFlatBuf: AnsiString;
  AWidth: Integer; ATrim: Boolean; ALineAlign: TAlignment;
  var AOut: TWrappedLines; var AOutCount: Integer);
var
  LP, LTotal, LLineStart, LLineEnd: Integer;
  LLastSpace: Integer;
  LColAcc: Integer;
  LAdv: TGraphemeAdv;
begin
  LTotal := System.Length(AFlatBuf);
  if LTotal = 0 then
  begin
    if AOutCount < System.Length(AOut) then
    begin
      AOut[AOutCount].SrcLine := ASrcIdx;
      AOut[AOutCount].ByteStart := 0;
      AOut[AOutCount].ByteEnd := 0;
      AOut[AOutCount].Alignment := ALineAlign;
      Inc(AOutCount);
    end;
    Exit;
  end;
  if AWidth <= 0 then Exit;

  LP := 0;
  while LP < LTotal do
  begin
    if ATrim then
      while (LP < LTotal) and (AFlatBuf[LP + 1] = ' ') do Inc(LP);
    if LP >= LTotal then Break;

    LLineStart := LP;
    LLastSpace := -1;
    LColAcc := 0;
    while LP < LTotal do
    begin
      LAdv := GraphemeAt(AFlatBuf, LTotal, LP);
      if LColAcc + LAdv.Width > AWidth then Break;
      if Byte(AFlatBuf[LP + 1]) = Ord(' ') then LLastSpace := LP;
      Inc(LColAcc, LAdv.Width);
      Inc(LP, LAdv.ByteLen);
    end;

    if LP >= LTotal then
      LLineEnd := LP
    else if LLastSpace > LLineStart then
    begin
      LLineEnd := LLastSpace;
      LP := LLastSpace + 1;
    end
    else
    begin
      LLineEnd := LP;
      if LLineEnd = LLineStart then
      begin
        LAdv := GraphemeAt(AFlatBuf, LTotal, LP);
        Inc(LP, LAdv.ByteLen);
        LLineEnd := LP;
      end;
    end;

    if AOutCount < System.Length(AOut) then
    begin
      AOut[AOutCount].SrcLine := ASrcIdx;
      AOut[AOutCount].ByteStart := LLineStart;
      AOut[AOutCount].ByteEnd := LLineEnd;
      AOut[AOutCount].Alignment := ALineAlign;
      Inc(AOutCount);
    end;
  end;
end;

{ TParagraph }

class function TParagraph.New(const AText: TText): IParagraph;
var
  LP: TParagraph;
begin
  LP := TParagraph.Create;
  LP.FText := AText;
  LP.FStyle := TStyle.Default;
  LP.FBlock := nil;
  LP.FHasWrap := False;
  LP.FWrap.Trim := False;
  LP.FHasAlignment := False;
  LP.FAlignment := caLeft;
  LP.FScrollY := 0;
  Result := LP;
end;

class function TParagraph.FromString(const AStr: AnsiString): IParagraph;
begin
  Result := New(TText.FromString(AStr));
end;

class function TParagraph.Wrapped(const AStr: AnsiString): IParagraph;
begin
  Result := FromString(AStr).WithWrap(WRAP_TRIM);
end;

function TParagraph.WithStyle(const AStyle: TStyle): IParagraph;
begin FStyle := AStyle; Result := Self; end;

function TParagraph.WithBlock(ABlock: IBlock): IParagraph;
begin FBlock := ABlock; Result := Self; end;

function TParagraph.WithWrap(const AWrap: TWrap): IParagraph;
begin FHasWrap := True; FWrap := AWrap; Result := Self; end;

function TParagraph.WithAlignment(AAlignment: TAlignment): IParagraph;
begin FHasAlignment := True; FAlignment := AAlignment; Result := Self; end;

function TParagraph.WithScrollY(AY: Word): IParagraph;
begin FScrollY := AY; Result := Self; end;

procedure TParagraph.Render(const AArea: TRect; ABuffer: TBuffer);
var
  LClip, LInner: TRect;
  LI, LJ, LY, LOutCount, LMaxLines, LCap: Integer;
  LEffAlign: TAlignment;
  LWrapped: TWrappedLines;
  LFlatBufs: array of AnsiString;
  LSpanIdxArrays: array of TByteSpanIdx;
  LLineW, LOffsetX, LX, LByteIdx, LSpanIdx, LNewSpanIdx: Integer;
  LRowY: Integer;
  LS: TStyle;
  LSrcLine: Integer;
  LWL: TWrappedLine;
  LAdv: TGraphemeAdv;
  LCP: PCell;
begin
  LClip := ABuffer.Area.Intersection(AArea);
  if LClip.IsEmpty then Exit;

  ABuffer.SetStyle(LClip, FStyle);

  if FBlock <> nil then
  begin
    FBlock.Render(LClip, ABuffer);
    LInner := FBlock.Inner(LClip);
  end
  else
    LInner := LClip;

  if LInner.IsEmpty or (LInner.Width = 0) then Exit;
  ABuffer.SetStyle(LInner, FStyle);

  if FHasAlignment then LEffAlign := FAlignment else LEffAlign := caLeft;

  LCap := 0;
  for LI := 0 to System.High(FText.Lines) do
    Inc(LCap, (FText.Lines[LI].Width div LInner.Width) + 2);
  if LCap < 1 then LCap := 1;

  SetLength(LFlatBufs, System.Length(FText.Lines));
  SetLength(LSpanIdxArrays, System.Length(FText.Lines));
  SetLength(LWrapped, LCap);
  LOutCount := 0;

  for LI := 0 to System.High(FText.Lines) do
  begin
    FlattenLine(FText.Lines[LI], LFlatBufs[LI], LSpanIdxArrays[LI]);
    if FText.Lines[LI].HasAlignment then LEffAlign := FText.Lines[LI].Alignment
    else if FHasAlignment then LEffAlign := FAlignment
    else LEffAlign := caLeft;

    if FHasWrap and FWrap.Trim then
      WrapOneLine(LI, LFlatBufs[LI], LInner.Width, True, LEffAlign, LWrapped, LOutCount)
    else
    begin
      if LOutCount < System.Length(LWrapped) then
      begin
        LWrapped[LOutCount].SrcLine := LI;
        LWrapped[LOutCount].ByteStart := 0;
        LWrapped[LOutCount].ByteEnd := System.Length(LFlatBufs[LI]);
        LWrapped[LOutCount].Alignment := LEffAlign;
        Inc(LOutCount);
      end;
    end;
  end;

  LMaxLines := LInner.Height;
  LY := 0;
  for LI := 0 to LOutCount - 1 do
  begin
    if LY < FScrollY then begin Inc(LY); Continue; end;
    if (LY - FScrollY) >= LMaxLines then Break;
    LRowY := LInner.Y + (LY - FScrollY);

    LWL := LWrapped[LI];
    LSrcLine := LWL.SrcLine;

    LLineW := GraphemeWidthRange(LFlatBufs[LSrcLine], LWL.ByteStart, LWL.ByteEnd);
    if LLineW > LInner.Width then LLineW := LInner.Width;
    LOffsetX := GetLineOffset(LLineW, LInner.Width, LWL.Alignment);

    LX := LInner.X + LOffsetX;
    LJ := LWL.ByteStart;
    LSpanIdx := -1;
    LS := TStyle.Default;
    while LJ < LWL.ByteEnd do
    begin
      if LX >= LInner.X + LInner.Width then Break;
      LAdv := GraphemeAt(LFlatBufs[LSrcLine], System.Length(LFlatBufs[LSrcLine]), LJ);
      if LX + LAdv.Width > LInner.X + LInner.Width then Break;

      LByteIdx := LJ;
      if (LByteIdx >= 0) and (LByteIdx < System.Length(LSpanIdxArrays[LSrcLine])) then
        LNewSpanIdx := LSpanIdxArrays[LSrcLine][LByteIdx]
      else
        LNewSpanIdx := 0;
      if LNewSpanIdx <> LSpanIdx then
      begin
        LSpanIdx := LNewSpanIdx;
        LS := FStyle.Patch(FText.Style);
        if LSrcLine < System.Length(FText.Lines) then
          LS := LS.Patch(FText.Lines[LSrcLine].Style);
        if (LSpanIdx >= 0) and (LSpanIdx < System.Length(FText.Lines[LSrcLine].Spans)) then
          LS := LS.Patch(FText.Lines[LSrcLine].Spans[LSpanIdx].Style);
      end;

      LCP := ABuffer.CellAt(LX, LRowY);
      if LCP <> nil then
      begin
        CellSetSymbolBytes(LCP^, PByte(Pointer(LFlatBufs[LSrcLine]))[LJ], LAdv.ByteLen, LAdv.Width);
        CellApplyStyle(LCP^, LS);
      end;

      Inc(LX, LAdv.Width);
      Inc(LJ, LAdv.ByteLen);
    end;

    Inc(LY);
  end;
end;

end.
