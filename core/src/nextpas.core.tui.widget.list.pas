unit nextpas.core.tui.widget.list;

{**
 * @desc TTuiList — 垂直滚动列表 widget（stateful）。
 *
 * 实现 IWidget + ITuiList。ITuiList 扩展 IWidget 加 builder 链 +
 * RenderStateful（带 var TTuiListState）。
 *
 * 第一个 stateful widget，验证 interface 上声明 var state 参数的模式。
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
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block;

type
  TTuiListItem = record
    Content: AnsiString;
    Style: TStyle;
    class function FromString(const AStr: AnsiString): TTuiListItem; static;
    function WithStyle(const AStyle: TStyle): TTuiListItem;
  end;
  TTuiListItems = array of TTuiListItem;

  TTuiListState = record
    Offset: Integer;
    HasSelection: Boolean;
    Selected: Integer;
    class function Empty: TTuiListState; static;
    procedure Select(AIndex: Integer);
    procedure ClearSelection;
  end;

  ITuiList = interface(IWidget)
    ['{E2F3A4B5-C6D7-8E9F-0A1B-2C3D4E5F6A7B}']
    function WithBlock(ABlock: IBlock): ITuiList;
    function WithStyle(const AStyle: TStyle): ITuiList;
    function WithHighlightStyle(const AStyle: TStyle): ITuiList;
    function WithHighlightSymbol(const ASym: AnsiString): ITuiList;
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer;
      var AState: TTuiListState);
  end;

  TTuiList = class(TInterfacedObject, IWidget, ITuiList)
  private
    FItems: TTuiListItems;
    FStyle: TStyle;
    FHighlightStyle: TStyle;
    FHighlightSymbol: AnsiString;
    FHasHighlightSymbol: Boolean;
    FBlock: IBlock;
  public
    class function New(const AItems: array of TTuiListItem): ITuiList; static;
    class function FromStrings(const AItems: array of AnsiString): ITuiList; static;

    function WithBlock(ABlock: IBlock): ITuiList;
    function WithStyle(const AStyle: TStyle): ITuiList;
    function WithHighlightStyle(const AStyle: TStyle): ITuiList;
    function WithHighlightSymbol(const ASym: AnsiString): ITuiList;

    { IWidget — 无状态渲染（无高亮） }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);

    { ITuiList — 有状态渲染 }
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer;
      var AState: TTuiListState);
  end;

implementation

uses
  nextpas.core.text.width;

{ TTuiListItem }

class function TTuiListItem.FromString(const AStr: AnsiString): TTuiListItem;
begin
  Result.Content := AStr;
  Result.Style := TStyle.Default;
end;

function TTuiListItem.WithStyle(const AStyle: TStyle): TTuiListItem;
begin
  Result := Self;
  Result.Style := AStyle;
end;

{ TTuiListState }

class function TTuiListState.Empty: TTuiListState;
begin
  Result.Offset := 0;
  Result.HasSelection := False;
  Result.Selected := 0;
end;

procedure TTuiListState.Select(AIndex: Integer);
begin
  HasSelection := True;
  Selected := AIndex;
end;

procedure TTuiListState.ClearSelection;
begin
  HasSelection := False;
end;

{ TTuiList }

class function TTuiList.New(const AItems: array of TTuiListItem): ITuiList;
var
  LL: TTuiList;
  LI: Integer;
begin
  LL := TTuiList.Create;
  SetLength(LL.FItems, System.Length(AItems));
  for LI := 0 to System.High(AItems) do
    LL.FItems[LI] := AItems[LI];
  LL.FStyle := TStyle.Default;
  LL.FHighlightStyle := TStyle.Default;
  LL.FHighlightSymbol := '';
  LL.FHasHighlightSymbol := False;
  LL.FBlock := nil;
  Result := LL;
end;

class function TTuiList.FromStrings(const AItems: array of AnsiString): ITuiList;
var
  LBuilt: array of TTuiListItem;
  LI: Integer;
begin
  SetLength(LBuilt, System.Length(AItems));
  for LI := 0 to System.High(AItems) do
    LBuilt[LI] := TTuiListItem.FromString(AItems[LI]);
  Result := TTuiList.New(LBuilt);
end;

function TTuiList.WithBlock(ABlock: IBlock): ITuiList;
begin FBlock := ABlock; Result := Self; end;

function TTuiList.WithStyle(const AStyle: TStyle): ITuiList;
begin FStyle := AStyle; Result := Self; end;

function TTuiList.WithHighlightStyle(const AStyle: TStyle): ITuiList;
begin FHighlightStyle := AStyle; Result := Self; end;

function TTuiList.WithHighlightSymbol(const ASym: AnsiString): ITuiList;
begin
  FHighlightSymbol := ASym;
  FHasHighlightSymbol := System.Length(ASym) > 0;
  Result := Self;
end;

procedure TTuiList.Render(const AArea: TRect; ABuffer: TBuffer);
var
  LDummy: TTuiListState;
begin
  LDummy := TTuiListState.Empty;
  RenderStateful(AArea, ABuffer, LDummy);
end;

procedure TTuiList.RenderStateful(const AArea: TRect; ABuffer: TBuffer;
  var AState: TTuiListState);
var
  LClip, LInner: TRect;
  LN, LGutterW, LMaxRows, LVisible: Integer;
  LFirstVis, LLastVis: Integer;
  LRowY, LRowIdx, LX, LItemMaxW: Integer;
  LSty: TStyle;
  LSel: Integer;
  LSym, LBlank: AnsiString;
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

  if LInner.IsEmpty then Exit;
  ABuffer.SetStyle(LInner, FStyle);

  LN := System.Length(FItems);
  if LN = 0 then
  begin
    AState.ClearSelection;
    Exit;
  end;

  LGutterW := 0;
  if FHasHighlightSymbol and AState.HasSelection then
    LGutterW := Integer(StringDisplayWidth(FHighlightSymbol));

  LItemMaxW := LInner.Width - LGutterW;
  if LItemMaxW < 0 then LItemMaxW := 0;

  if AState.HasSelection then
  begin
    if AState.Selected < 0 then AState.Selected := 0;
    if AState.Selected >= LN then AState.Selected := LN - 1;
  end;

  LMaxRows := LInner.Height;
  LVisible := LMaxRows;
  if LVisible > LN then LVisible := LN;

  LFirstVis := AState.Offset;
  if LFirstVis < 0 then LFirstVis := 0;
  if LFirstVis > LN - 1 then LFirstVis := LN - 1;
  LLastVis := LFirstVis + LVisible;
  if LLastVis > LN then
  begin
    LLastVis := LN;
    LFirstVis := LN - LVisible;
    if LFirstVis < 0 then LFirstVis := 0;
  end;

  if AState.HasSelection then
  begin
    LSel := AState.Selected;
    while LSel >= LLastVis do
    begin
      Inc(LLastVis);
      if LLastVis - LFirstVis > LVisible then Inc(LFirstVis);
    end;
    while LSel < LFirstVis do
    begin
      Dec(LFirstVis);
      if LLastVis - LFirstVis > LVisible then Dec(LLastVis);
    end;
  end;

  AState.Offset := LFirstVis;

  if LGutterW > 0 then
  begin
    SetLength(LBlank, LGutterW);
    FillChar(LBlank[1], LGutterW, Ord(' '));
  end
  else
    LBlank := '';

  LRowIdx := LFirstVis;
  LRowY := LInner.Y;
  while (LRowIdx < LLastVis) and (LRowY >= LInner.Y) and (LRowY < LInner.Y + LInner.Height) do
  begin
    LSty := FStyle.Patch(FItems[LRowIdx].Style);
    ABuffer.SetStyle(TRect.Make(LInner.X, LRowY, LInner.Width, 1), LSty);

    if LGutterW > 0 then
    begin
      if AState.HasSelection and (LRowIdx = AState.Selected) then
        LSym := FHighlightSymbol
      else
        LSym := LBlank;
      ABuffer.SetStringN(LInner.X, LRowY, LSym, LGutterW, LSty);
    end;

    LX := LInner.X + LGutterW;
    if LItemMaxW > 0 then
      ABuffer.SetStringN(LX, LRowY, FItems[LRowIdx].Content, LItemMaxW, LSty);

    if AState.HasSelection and (LRowIdx = AState.Selected) then
      ABuffer.SetStyle(TRect.Make(LInner.X, LRowY, LInner.Width, 1), FHighlightStyle);

    Inc(LRowIdx);
    Inc(LRowY);
  end;
end;

end.
