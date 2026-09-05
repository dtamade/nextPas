{**
 * nextpas.core.tui.canvas.flatten - 字符画布视口裁剪与可见层合并
 *
 * 纯像素操作（无终端 I/O、无应用策略）：
 * CanvasFlattenViewport 按矩形裁剪（ALayer < 0 合并可见层，否则单层），
 * 越界部分裁剪，合成规则为可见层自底向上按 Ch <> 0 覆盖。
 * 调用方负责尺寸预算（超大矩形直接分配，调用前请自行守卫）。
 *}

unit nextpas.core.tui.canvas.flatten;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.canvas.base;

{** @desc 可见性格：有字形格参与上层覆盖（空格/透明格 Ch = 0 不覆盖） *}
function CanvasCellVisible(const ACell: TCanvasCell): Boolean; inline;

{** @desc 单入口视口裁剪：ALayer < 0 合并可见层，否则裁剪单层；
    ADoc = nil / 空矩形 / 单层越界返回 nil *}
function CanvasFlattenViewport(ADoc: TCanvasDoc; const R: TRect;
  ALayer: Integer): TCanvasDoc;

{** @desc 整文档合并可见层（尺寸同源）；ADoc = nil 返回 nil *}
function CanvasFlattenVisible(ADoc: TCanvasDoc): TCanvasDoc;

implementation

function CanvasCellVisible(const ACell: TCanvasCell): Boolean; inline;
begin
  Result := ACell.Ch <> 0;
end;

function CanvasFlattenViewport(ADoc: TCanvasDoc; const R: TRect;
  ALayer: Integer): TCanvasDoc;
var
  W, H, X, Y, SX, SY, L: Integer;
  Src, Dst: PCanvasCell;
  SrcX0, DstX0, CopyW, RunStart, RunLen: Integer;
  IsFirst: Boolean;
begin
  Result := nil;
  if (ADoc = nil) or R.IsEmpty then
    Exit;
  W := Integer(R.Width);
  H := Integer(R.Height);
  if (W <= 0) or (H <= 0) then
    Exit;
  if ALayer >= 0 then
  begin
    if ALayer >= ADoc.LayerCount then
      Exit;
    Result := TCanvasDoc.Create(W, H);
    for Y := 0 to H - 1 do
    begin
      SY := Integer(R.Y) + Y;
      Src := ADoc.RowPtr(ALayer, SY);
      Dst := Result.RowPtr(0, Y);
      if (Src = nil) or (Dst = nil) then
        Continue;
      SX := Integer(R.X);
      if (SX < 0) or (SX + W > ADoc.Width) then
      begin
        for X := 0 to W - 1 do
        begin
          SX := Integer(R.X) + X;
          if (SX >= 0) and (SX < ADoc.Width) then
            Dst[X] := Src[SX];
        end;
        Continue;
      end;
      Move(Src[SX], Dst[0], W * SizeOf(TCanvasCell));
    end;
    Exit;
  end;
  Result := TCanvasDoc.Create(W, H);
  IsFirst := True;
  try
    for L := 0 to ADoc.LayerCount - 1 do
    begin
      if not ADoc.LayerVisible(L) then
        Continue;
      for Y := 0 to H - 1 do
      begin
        SY := Integer(R.Y) + Y;
        Src := ADoc.RowPtr(L, SY);
        Dst := Result.RowPtr(0, Y);
        if (Src = nil) or (Dst = nil) then
          Continue;
        SrcX0 := Integer(R.X);
        DstX0 := 0;
        CopyW := W;
        if SrcX0 < 0 then
        begin
          DstX0 := -SrcX0;
          CopyW := CopyW - DstX0;
          SrcX0 := 0;
        end;
        if SrcX0 + CopyW > ADoc.Width then
          CopyW := ADoc.Width - SrcX0;
        if CopyW <= 0 then
          Continue;
        if IsFirst then
          Move(Src[SrcX0], Dst[DstX0], CopyW * SizeOf(TCanvasCell))
        else
        begin
          X := 0;
          while X < CopyW do
          begin
            while (X < CopyW) and not CanvasCellVisible(Src[SrcX0 + X]) do
              Inc(X);
            if X >= CopyW then
              Break;
            RunStart := X;
            Inc(X);
            while (X < CopyW) and CanvasCellVisible(Src[SrcX0 + X]) do
              Inc(X);
            RunLen := X - RunStart;
            Move(Src[SrcX0 + RunStart], Dst[DstX0 + RunStart],
              RunLen * SizeOf(TCanvasCell));
          end;
        end;
      end;
      if IsFirst then
        IsFirst := False;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function CanvasFlattenVisible(ADoc: TCanvasDoc): TCanvasDoc;
begin
  if ADoc = nil then
    Exit(nil);
  Result := CanvasFlattenViewport(ADoc,
    TRect.Make(0, 0, Word(ADoc.Width), Word(ADoc.Height)), -1);
end;

end.
