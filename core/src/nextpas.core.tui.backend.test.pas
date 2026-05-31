unit nextpas.core.tui.backend.test;

{**
 * @desc 内存测试后端——与 TAnsiBackend 同形接口，但把 patches 应用到内部
 *       TBuffer 而非发 ANSI 字节。
 *
 * 用途：
 *   - Widget 测试断言渲染后的 buffer 内容（而非 ANSI 字节流），避免后端
 *     优化（SGR cache、cursor merge）破坏断言。
 *   - Terminal 循环测试无需真实 fd。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer;

type
  TTestBackend = class
  private
    FBuffer: TBuffer;
    FCursorVisible: Boolean;
    FCursorX, FCursorY: Word;
    FOnAlternate: Boolean;
  public
    constructor Create(const AArea: TRect);
    destructor Destroy; override;

    { 测试检查的"结果"表面。由 backend 拥有。 }
    property Buffer: TBuffer read FBuffer;
    property CursorVisible: Boolean read FCursorVisible;
    property CursorX: Word read FCursorX;
    property CursorY: Word read FCursorY;
    property OnAlternate: Boolean read FOnAlternate;

    { 把 patches 应用到内部 buffer（等价 TAnsiBackend.DrawPatches 但无 ANSI）。 }
    procedure DrawPatches(const APatches: TDiffEntries);

    { 与 TAnsiBackend 同形的屏幕/光标接口。 }
    procedure HideCursor; inline;
    procedure ShowCursor; inline;
    procedure ClearScreen;
    procedure EnterAlternate; inline;
    procedure LeaveAlternate; inline;
    procedure MoveTo(AX, AY: Word); inline;

    { No-op：无需 flush。返回 True 使调用方无需特判。 }
    function Flush: Boolean; inline;

    { 测试便利：清空 buffer + 重置光标/alt 状态。 }
    procedure ResetState;
  end;

implementation

{ TTestBackend }

constructor TTestBackend.Create(const AArea: TRect);
begin
  inherited Create;
  FBuffer := TBuffer.CreateEmpty(AArea);
  FCursorVisible := True;
  FCursorX := 0;
  FCursorY := 0;
  FOnAlternate := False;
end;

destructor TTestBackend.Destroy;
begin
  FBuffer.Free;
  inherited;
end;

procedure TTestBackend.DrawPatches(const APatches: TDiffEntries);
var
  LI: Integer;
  LCP: PCell;
begin
  for LI := 0 to System.High(APatches) do
  begin
    LCP := FBuffer.CellAt(APatches[LI].X, APatches[LI].Y);
    if LCP <> nil then
      LCP^ := APatches[LI].Cell;
  end;
  if System.Length(APatches) > 0 then
  begin
    FCursorX := APatches[System.High(APatches)].X + 1;
    FCursorY := APatches[System.High(APatches)].Y;
  end;
end;

procedure TTestBackend.HideCursor;     begin FCursorVisible := False; end;
procedure TTestBackend.ShowCursor;     begin FCursorVisible := True;  end;
procedure TTestBackend.EnterAlternate; begin FOnAlternate := True;    end;
procedure TTestBackend.LeaveAlternate; begin FOnAlternate := False;   end;
procedure TTestBackend.MoveTo(AX, AY: Word);
begin
  FCursorX := AX;
  FCursorY := AY;
end;

procedure TTestBackend.ClearScreen;
begin
  FBuffer.Reset;
end;

function TTestBackend.Flush: Boolean;
begin
  Result := True;
end;

procedure TTestBackend.ResetState;
begin
  FBuffer.Reset;
  FCursorVisible := True;
  FCursorX := 0;
  FCursorY := 0;
  FOnAlternate := False;
end;

end.
