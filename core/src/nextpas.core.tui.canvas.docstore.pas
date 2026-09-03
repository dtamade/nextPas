{**
 * nextpas.core.tui.canvas.docstore - 画布文档持久化(JSON)
 *
 * CanvasDocSaveToJson: TCanvasDoc → JSON(version/width/height/palette/layers)。
 *   行 RLE: 分号分隔 run "cnt:ch:fg:bg"(十六进制; cnt 2 位, ch 6 位码点,
 *   fg/bg 2 位调色板索引)。Ch=0 的 run 是空白占位(只推进 x, fg/bg 恒为 00);
 *   连续同值 >255 拆多 run; ckIndexed 色按 16 色表归一为 rgb; ckReset/ckUnset → #000000。
 * CanvasDocLoadFromJson: 反序列化成新 TCanvasDoc, 失败返回 nil。
 * 颜色↔hex 编解码为格式自包含实现(不依赖调用方工具), 解析大小写不敏感。
 * 不直接依赖 FPC RTL(SysUtils/Classes 等)。
 *}

unit nextpas.core.tui.canvas.docstore;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui.color,
  nextpas.core.tui.canvas.base;

{** @desc 序列化整个文档。False = 文档为空/尺寸非法。 *}
function CanvasDocSaveToJson(ADoc: TCanvasDoc; out AJson: AnsiString): Boolean;
{** @desc 反序列化成新 TCanvasDoc; 失败返回 nil(调用方负责 Free)。 *}
function CanvasDocLoadFromJson(const AJson: AnsiString): TCanvasDoc;

implementation

uses
  nextpas.core.json,
  nextpas.core.json.value,
  nextpas.core.json.builder;

const
  MAX_PALETTE = 256;
  HEXDIGITS: array[0..15] of Char = '0123456789abcdef';

function HexVal(C: Char): Integer;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
    'A'..'F': Result := Ord(C) - Ord('A') + 10;
  else
    Result := -1;
  end;
end;

function HexToInt(const S: AnsiString): Integer;
var
  I, V: Integer;
begin
  Result := 0;
  for I := 1 to Length(S) do
  begin
    V := HexVal(S[I]);
    if V < 0 then
      Exit(-1);
    Result := (Result shl 4) or V;
  end;
end;

{ 从 AFrom 起找子串, 找不到返回 0 }
function FindSub(const S, Sub: AnsiString; AFrom: Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  if (Sub = '') or (AFrom < 1) or (AFrom > Length(S)) then
    Exit;
  for I := AFrom to Length(S) - Length(Sub) + 1 do
    if Copy(S, I, Length(Sub)) = Sub then
      Exit(I);
end;

procedure AppendHex2(var S: AnsiString; V: Integer);
begin
  S := S + HEXDIGITS[(V shr 4) and $F] + HEXDIGITS[V and $F];
end;

procedure AppendHex6(var S: AnsiString; V: Integer);
begin
  S := S + HEXDIGITS[(V shr 20) and $F] + HEXDIGITS[(V shr 16) and $F]
    + HEXDIGITS[(V shr 12) and $F] + HEXDIGITS[(V shr 8) and $F]
    + HEXDIGITS[(V shr 4) and $F] + HEXDIGITS[V and $F];
end;

{ 颜色并入调色板(前 ACount 项有效)。返回索引 }
procedure PaletteAdd(const AHex: AnsiString; var Palette: array of AnsiString;
  var ACount: Integer; out AIndex: Integer);
var
  Hex: AnsiString;
  I: Integer;
begin
  if AHex = '' then
    Hex := '#000000'
  else
    Hex := AHex;
  for I := 0 to ACount - 1 do
    if Palette[I] = Hex then
    begin
      AIndex := I;
      Exit;
    end;
  AIndex := ACount;
  if ACount < High(Palette) then
  begin
    Palette[ACount] := Hex;
    Inc(ACount);
  end;
end;

{ 调色板查找(必须已加入) }
function PaletteFind(const AHex: AnsiString; const Palette: array of AnsiString;
  ACount: Integer; out AIndex: Integer): Boolean;
var
  Hex: AnsiString;
  I: Integer;
begin
  if AHex = '' then
    Hex := '#000000'
  else
    Hex := AHex;
  for I := 0 to ACount - 1 do
    if Palette[I] = Hex then
    begin
      AIndex := I;
      Exit(True);
    end;
  Result := False;
  AIndex := 0;
end;

{ 追加一个 run 到行文本 }
procedure RunAppend(var S: AnsiString; ACnt: Integer; ACh: LongWord;
  AFgIdx, ABgIdx: Integer);
begin
  if S <> '' then
    S := S + ';';
  AppendHex2(S, ACnt);
  S := S + ':';
  AppendHex6(S, ACh);
  S := S + ':';
  AppendHex2(S, AFgIdx);
  S := S + ':';
  AppendHex2(S, ABgIdx);
end;

{ 冲刷一个 run: 空 run(Ch=0)索引固定 00:00, 其余按调色板 }
procedure FlushRun(var S: AnsiString; ARunLen: Integer; ARunCh: LongWord;
  ARunFg, ARunBg: TColor; const Palette: array of AnsiString; PCount: Integer);
var
  FgIdx, BgIdx: Integer;
begin
  if ARunCh = 0 then
  begin
    FgIdx := 0;
    BgIdx := 0;
  end
  else
  begin
    PaletteFind(ColorToHex(ARunFg), Palette, PCount, FgIdx);
    PaletteFind(ColorToHex(ARunBg), Palette, PCount, BgIdx);
  end;
  RunAppend(S, ARunLen, ARunCh, FgIdx, BgIdx);
end;

{ 整行 RLE 文本。空格(Ch=0)也编码, 以保留起点偏移 }
function RowToRle(ADoc: TCanvasDoc; ALayer, AY: Integer;
  const Palette: array of AnsiString; PCount: Integer): AnsiString;
var
  X, W: Integer;
  TheCell: TCanvasCell;
  RunCh: LongWord;
  RunFg, RunBg: TColor;
  RunLen: Integer;
begin
  Result := '';
  W := ADoc.Width;
  RunLen := 0;
  RunCh := 0;
  RunFg := UnsetColor;
  RunBg := UnsetColor;
  for X := 0 to W - 1 do
  begin
    TheCell := ADoc.GetCell(ALayer, X, AY);
    if RunLen = 0 then
    begin
      RunCh := TheCell.Ch;
      RunFg := TheCell.Fg;
      RunBg := TheCell.Bg;
      RunLen := 1;
    end
    else if (TheCell.Ch = RunCh) and (RunLen < 255) and
      ((RunCh = 0) or (ColorEquals(TheCell.Fg, RunFg)
        and ColorEquals(TheCell.Bg, RunBg))) then
      Inc(RunLen)
    else
    begin
      FlushRun(Result, RunLen, RunCh, RunFg, RunBg, Palette, PCount);
      RunCh := TheCell.Ch;
      RunFg := TheCell.Fg;
      RunBg := TheCell.Bg;
      RunLen := 1;
    end;
  end;
  if RunLen > 0 then
    FlushRun(Result, RunLen, RunCh, RunFg, RunBg, Palette, PCount);
end;

function CanvasDocSaveToJson(ADoc: TCanvasDoc; out AJson: AnsiString): Boolean;
var
  Palette: array[0..MAX_PALETTE - 1] of AnsiString;
  PCount: Integer;
  W, H, L, X, Y: Integer;
  TheCell: TCanvasCell;
  Dummy: Integer;
  Build: IJsonBuilder;
  Rows: array of AnsiString;
begin
  Result := False;
  if (ADoc = nil) or (ADoc.Width < 1) or (ADoc.Height < 1) then
    Exit;
  W := ADoc.Width;
  H := ADoc.Height;
  PCount := 0;

  { 收集调色板(仅 Ch<>0 的格) }
  for L := 0 to ADoc.LayerCount - 1 do
    for Y := 0 to H - 1 do
      for X := 0 to W - 1 do
      begin
        TheCell := ADoc.GetCell(L, X, Y);
        if TheCell.Ch = 0 then
          Continue;
        PaletteAdd(ColorToHex(TheCell.Fg), Palette, PCount, Dummy);
        PaletteAdd(ColorToHex(TheCell.Bg), Palette, PCount, Dummy);
      end;

  Build := JsonBuilder;
  Build.BeginObject;
  Build.Key('version');
  Build.Int(1);
  Build.Key('width');
  Build.Int(W);
  Build.Key('height');
  Build.Int(H);
  Build.Key('palette');
  Build.BeginArray;
  for X := 0 to PCount - 1 do
    Build.Str(Palette[X]);
  Build.EndArray;
  Build.Key('layers');
  Build.BeginArray;
  SetLength(Rows, H);
  for L := 0 to ADoc.LayerCount - 1 do
  begin
    for Y := 0 to H - 1 do
      Rows[Y] := RowToRle(ADoc, L, Y, Palette, PCount);
    Build.BeginObject;
    Build.Key('name');
    Build.Str(ADoc.LayerName(L));
    Build.Key('visible');
    Build.Bool(ADoc.LayerVisible(L));
    Build.Key('rows');
    Build.BeginArray;
    for Y := 0 to H - 1 do
      Build.Str(Rows[Y]);
    Build.EndArray;
    Build.EndObject;
  end;
  Build.EndArray;
  Build.EndObject;
  AJson := Build.ToString;
  Result := True;
end;

{ 解析 run 字段 "cnt:ch:fg:bg"(hex)。False = 字段坏 }
function ParseRunFields(const S: AnsiString; out ACnt, ACh, AFgIdx, ABgIdx: Integer): Boolean;
var
  P1, P2, P3: Integer;
begin
  Result := False;
  P1 := Pos(':', S);
  if P1 <= 0 then
    Exit;
  P2 := FindSub(S, ':', P1 + 1);
  if P2 <= 0 then
    Exit;
  P3 := FindSub(S, ':', P2 + 1);
  if P3 <= 0 then
    Exit;
  ACnt := HexToInt(Copy(S, 1, P1 - 1));
  ACh := HexToInt(Copy(S, P1 + 1, P2 - P1 - 1));
  AFgIdx := HexToInt(Copy(S, P2 + 1, P3 - P2 - 1));
  ABgIdx := HexToInt(Copy(S, P3 + 1, 2));
  Result := (ACnt >= 0) and (ACh >= 0) and (AFgIdx >= 0) and (ABgIdx >= 0);
end;

{ 解析一行 RLE 到层。越界/坏字段 → 停 }
procedure RowFromRle(ADoc: TCanvasDoc; ALayer, AY: Integer; const ARle: AnsiString;
  const Palette: array of TColor; PCount: Integer);
var
  X, I, RunStart: Integer;
  Cnt, Ch, FgIdx, BgIdx: Integer;
begin
  X := 0;
  RunStart := 1;
  I := 1;
  while I <= Length(ARle) + 1 do
  begin
    if (I > Length(ARle)) or (ARle[I] = ';') then
    begin
      if I > RunStart then
      begin
        if not ParseRunFields(Copy(ARle, RunStart, I - RunStart),
          Cnt, Ch, FgIdx, BgIdx) then
          Exit;
        if Cnt <= 0 then
          Exit;
        if Ch = 0 then
        begin
          { 空白 run: 只推进 x }
          Inc(X, Cnt);
          if X >= ADoc.Width then
            Exit;
        end
        else
        begin
          if (FgIdx >= PCount) or (BgIdx >= PCount) then
            Exit;
          while (Cnt > 0) and (X < ADoc.Width) do
          begin
            ADoc.SetCell(ALayer, X, AY,
              CanvasMakeCell(LongWord(Ch), Palette[FgIdx], Palette[BgIdx]));
            Inc(X);
            Dec(Cnt);
          end;
          if X >= ADoc.Width then
            Exit;
        end;
      end;
      RunStart := I + 1;
    end;
    Inc(I);
  end;
end;

function CanvasDocLoadFromJson(const AJson: AnsiString): TCanvasDoc;
var
  JDoc: IJsonDocument;
  Root, LayersVal, PaletteVal, LayerVal, RowsVal: TJsonValue;
  Palette: array[0..MAX_PALETTE - 1] of TColor;
  PCount: Integer;
  W, H, L, Y, I: Integer;
  Name, RowText: AnsiString;
  Visible: Boolean;
  C: TColor;
begin
  FillChar(Palette, SizeOf(Palette), 0);
  Result := nil;
  if not TryJsonParse(AJson, JDoc) then
    Exit;
  Root := JDoc.Root;
  if Root.ObjectGet('version').AsInt <> 1 then
    Exit;
  W := Integer(Root.ObjectGet('width').AsInt);
  H := Integer(Root.ObjectGet('height').AsInt);
  if (W < 1) or (H < 1) or (W > 4096) or (H > 4096) then
    Exit;

  { 调色板 }
  PCount := 0;
  PaletteVal := Root.ObjectGet('palette');
  for I := 0 to Integer(PaletteVal.ArrayLen) - 1 do
  begin
    if PCount >= MAX_PALETTE then
      Break;
    if not TryParseHexColor(PaletteVal.ArrayGet(I).AsStr.ToString, C) then
      Exit;
    Palette[PCount] := C;
    Inc(PCount);
  end;

  { 层 }
  LayersVal := Root.ObjectGet('layers');
  if LayersVal.ArrayLen < 1 then
    Exit;
  Result := TCanvasDoc.Create(W, H);
  for L := 0 to Integer(LayersVal.ArrayLen) - 1 do
  begin
    LayerVal := LayersVal.ArrayGet(L);
    Name := LayerVal.ObjectGet('name').AsStr.ToString;
    Visible := LayerVal.ObjectGet('visible').AsBool;
    if L = 0 then
      Result.SetLayerName(0, Name)
    else
      Result.NewLayer(Name);
    Result.SetLayerVisible(L, Visible);
    RowsVal := LayerVal.ObjectGet('rows');
    for Y := 0 to H - 1 do
    begin
      if Integer(RowsVal.ArrayLen) <= Y then
        Break;
      RowText := RowsVal.ArrayGet(Y).AsStr.ToString;
      RowFromRle(Result, L, Y, RowText, Palette, PCount);
    end;
  end;
end;

end.
