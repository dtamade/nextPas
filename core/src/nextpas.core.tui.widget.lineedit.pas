unit nextpas.core.tui.widget.lineedit;

{ 单行输入缓冲组件:表单之外所有单行输入(搜索框 / 重命名 /
  过滤查找等)的统一编辑内核,自 agentman888 反哺。
  编辑语义 = core TInputState(←→/Home/End/Ctrl+←→ 跳词/
  Ctrl+Backspace·Delete 删词/Backspace/Delete),应用侧约束:
  字素数上限(MaxChars,0=不限)。
  鼠标文本选区 = 统一特性:HandleMouse 单击锚定/拖选/双击词/三击全选,
  Shift+方向键扩展走内核;Ctrl+C 有选区拷选区(出参语义不变,调用方
  用 HasSelection/SelectedText 取内容);DrawSelection 在已渲染提示行上
  叠加高亮。渲染热路径零分配(SelVisibleCols 单遍扫描)。
  剪贴板动作以出参上报(WantPaste/WantCopy),由调用方执行——调用方
  持有剪贴板通道与 toast 反馈,本组件保持纯净可测。
  多行/追加式输入(Chat 类)保持宿主定制,不经此组件 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.event,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.input;

type
  TLineEdit = record
  private
    FState: TInputState;
    FMaxChars: Integer;
    FClickCount: Integer;   { 多击计数(同列 ≤500ms 累加;1 单击/2 双击/3 三击) }
    FClickMs: Integer;      { 上次按下时刻(宿主单调毫秒时钟) }
    FClickCol: Integer;     { 上次按下相对文本起点列 }
    FDragging: Boolean;     { mkDown 在本输入内按下后才接受拖选 }
    FAutoDir: Integer;      { 边缘自动扩展方向(-1 左/0 无/+1 右) }
    FAutoMs: Integer;       { 上次自动推进时刻 }
    FAutoStart: Integer;    { 自动扩展起始时刻(加速档锚点) }
    function Total: Integer;              { 缓冲内字素数 }
    function FitPrefix(const S: string): string; { 按剩余容量截前缀(字素计) }
  public
    { MaxChars=0 不限长 }
    procedure Init(const AText: string = ''; AMaxChars: Integer = 0);
    procedure Clear;
    function Text: string;
    procedure SetText(const S: string);   { 全文替换,光标置尾 }
    function Empty: Boolean;
    { 编辑键路由:消费返回 True(含满员吞键)。AWantPaste=Ctrl+V、
      AWantCopy=Ctrl+C 请求出参;未消费键(↑↓/Enter/Esc/j/k 等)
      返回 False 交还调用方做列表导航 }
    function HandleKey(const K: TKeyEvent;
      out AWantPaste, AWantCopy: Boolean): Boolean;
    { 鼠标选区:ARelX 相对文本首列(可负/超尾),AWidth 可见宽,
      ANowMs 宿主毫秒时钟。mkDown 落锚(双击词/三击全选)、mkDrag 扩展
      (拖出左右缘按事件逐图素外推)、mkUp 收尾。滚轮不消费(留给宿主
      列表滚动)。返回是否消费 }
    function HandleMouse(ARelX, AWidth, ANowMs: Integer;
      AKind: TMouseEventKind): Boolean;
    { 边缘自动扩展:拖选顶住视口缘后由宿主每帧调用 TickExtend 推进
      (终端只报单元格变化事件,按住不动时靠时钟续推,grok 加速滚动
      同思路)。AutoActive=有挂起的自动方向;AutoStop 在失焦/关闭时清 }
    function AutoActive: Boolean;
    procedure AutoStop;
    function TickExtend(ANowMs: Integer): Boolean;
    { 选区在文本内的可见列段 [AFrom..ATo)(与 [0..AMaxWidth) 求交),
      无选区或不可见返回 False。单遍扫描零分配,渲染热路径安全 }
    function SelVisibleCols(AMaxWidth: Integer;
      out AFrom, ATo: Integer): Boolean;
    { 已渲染提示行上的选区高亮叠加:AXText 为文本首列屏幕 X。
      只盖实际字形列(提示行非封闭输入框,不做文尾补满) }
    procedure DrawSelection(ABuffer: TBuffer; AXText, AY, AMaxWidth: Integer;
      const AStyle: TStyle);
    { Ctrl+C 语义:有选区拷选区,否则拷全文(调用方取文本用) }
    function HasSelection: Boolean;
    function SelectedText: string;
    procedure ClearSelection;
    { 粘贴落缓冲:去换行(InsertStr 同规则),按剩余容量截断,插在光标处 }
    procedure ApplyPaste(const S: string);
  end;

implementation

uses
  nextpas.core.text.grapheme;

function TLineEdit.Total: Integer;
var
  P, N: Integer;
  LGR: TGraphemeResult;
begin
  Result := 0;
  N := Length(FState.Text);
  P := 0;
  while P < N do
  begin
    LGR := GraphemeNext(@FState.Text[P + 1], N - P);
    if LGR.ByteLen <= 0 then Break;
    Inc(P, LGR.ByteLen);
    Inc(Result);
  end;
end;

function TLineEdit.FitPrefix(const S: string): string;
var
  P, N, Cnt, Room: Integer;
  LGR: TGraphemeResult;
begin
  Result := '';
  if S = '' then Exit;
  if FMaxChars > 0 then
  begin
    Room := FMaxChars - Total;
    if Room <= 0 then Exit;
  end
  else
    Room := MaxInt;
  N := Length(S);
  P := 0;
  Cnt := 0;
  while (P < N) and (Cnt < Room) do
  begin
    LGR := GraphemeNext(@S[P + 1], N - P);
    if LGR.ByteLen <= 0 then Break;
    Inc(P, LGR.ByteLen);
    Inc(Cnt);
  end;
  if P > 0 then
    Result := Copy(S, 1, P);
end;

procedure TLineEdit.Init(const AText: string; AMaxChars: Integer);
begin
  FMaxChars := AMaxChars;
  FAutoDir := 0;
  SetText(AText);
end;

procedure TLineEdit.Clear;
begin
  FAutoDir := 0;
  FState := TInputState.Empty;
end;

function TLineEdit.Text: string;
begin
  Result := FState.Text;
end;

procedure TLineEdit.SetText(const S: string);
begin
  FState := TInputState.WithText(S);
end;

function TLineEdit.Empty: Boolean;
begin
  Result := FState.Text = '';
end;

function TLineEdit.HandleKey(const K: TKeyEvent;
  out AWantPaste, AWantCopy: Boolean): Boolean;
begin
  AWantPaste := False;
  AWantCopy := False;
  Result := True;
  if (K.Code = kcChar) and (kmCtrl in K.Modifiers) then
  begin
    if K.Ch = Ord('v') then
      AWantPaste := True
    else if K.Ch = Ord('c') then
      AWantCopy := True
    else
      Exit(False);
    Exit(True);
  end;
  case K.Code of
    kcChar:
      begin
        { 控制字符拒绝、满员吞键:均视为已消费(不变更缓冲)。
          有选区时放行:输入替换选区净字素数不增 }
        if K.Ch < 32 then Exit;
        if (FMaxChars > 0) and (Total >= FMaxChars) and
           (not FState.HasSelection) then Exit;
        FState.InsertChar(K.Ch);
      end;
  else
    if not FState.HandleKey(K) then
      Exit(False);
  end;
end;

procedure TLineEdit.ApplyPaste(const S: string);
begin
  FState.InsertStr(FitPrefix(S));
end;

function TLineEdit.HandleMouse(ARelX, AWidth, ANowMs: Integer;
  AKind: TMouseEventKind): Boolean;
var
  BP: Integer;
begin
  Result := True;
  case AKind of
    mkDown:
      begin
        { 多击判定:同列且 500ms 内累加,否则重起单击 }
        if (ANowMs - FClickMs <= 500) and (ARelX = FClickCol) then
          Inc(FClickCount)
        else
          FClickCount := 1;
        FClickMs := ANowMs;
        FClickCol := ARelX;
        if ARelX < 0 then BP := FState.ColToBytePos(0)
        else if ARelX < AWidth then BP := FState.ColToBytePos(ARelX)
        else BP := FState.ColToBytePos(AWidth - 1);
        case FClickCount of
          2:
            { 双击选词;点空白退化为落点定位 }
            if not FState.SelectWordAt(BP) then
            begin
              FState.ClearSelection;
              FState.BeginSelect(BP);
              FState.Cursor := BP;
            end;
          3:
            begin
              FState.SelectAll;   { 单行 = 整行全选 }
              FClickCount := 0;
            end;
        else
        begin
          FState.BeginSelect(BP);
          FState.Cursor := BP;   { 光标随点击(边缘外推自落点起算) }
        end;
        end;
        FDragging := True;
        FAutoDir := 0;
      end;
    mkDrag:
      begin
        if not FDragging then Exit(False);
        if ARelX < 0 then
        begin
          { 左侧与右侧不对称:单行输入恒从头显示,首字符左边没有
            隐藏内容——越过首字符 = 头钉在首字符即可,**不启动**
            自动扩展(无可推进空间,启动只会把选区拽到行首显乱) }
          FAutoDir := 0;
          FState.UpdateSelect(FState.ColToBytePos(0));
        end
        else if (ARelX >= AWidth - 1) and (FState.TextWidth > AWidth) and
                (FState.Cursor < Length(FState.Text)) then
        begin
          { 最右可见列即「顶边」(终端把 X 钳到视口宽,更右侧的事件
            不存在):文本宽超视口且还有图素在更右 = 推进一格并启动
            自动扩展 }
          FAutoDir := 1;
          FAutoMs := ANowMs;
          FAutoStart := ANowMs;
          FState.MoveRight;
          FState.UpdateSelect(FState.Cursor);
        end
        else
        begin
          FAutoDir := 0;   { 回到行内:停自动扩展,正常映射 }
          FState.UpdateSelect(FState.ColToBytePos(ARelX));
        end;
      end;
    mkUp:
      begin
        if not FDragging then Exit(False);
        FDragging := False;
        FAutoDir := 0;
      end;
  else
    Exit(False);   { 滚轮/mkMoved 不消费:列表滚动与悬停照常 }
  end;
end;

function TLineEdit.AutoActive: Boolean;
begin
  Result := FAutoDir <> 0;
end;

procedure TLineEdit.AutoStop;
begin
  FAutoDir := 0;
end;

function TLineEdit.TickExtend(ANowMs: Integer): Boolean;
var
  LInterval: Integer;
begin
  { 顶边按时钟续推:前 600ms 慢档(80ms/图素,可精停),之后快档
    (35ms,长文本快速到尾);到头/尾自停。返回 True = 状态已变,
    宿主应续渲染帧 }
  Result := False;
  if (FAutoDir = 0) or (not FDragging) then Exit;   { 非拖拽态兜底停 }
  if ANowMs - FAutoStart < 600 then LInterval := 80
  else LInterval := 35;
  if ANowMs - FAutoMs < LInterval then Exit;
  FAutoMs := ANowMs;
  if FAutoDir < 0 then
  begin
    if FState.Cursor > 0 then
    begin
      FState.MoveLeft;
      FState.UpdateSelect(FState.Cursor);
      Result := True;
    end
    else
      FAutoDir := 0;
  end
  else
  begin
    if FState.Cursor < Length(FState.Text) then
    begin
      FState.MoveRight;
      FState.UpdateSelect(FState.Cursor);
      Result := True;
    end
    else
      FAutoDir := 0;
  end;
end;

function TLineEdit.SelVisibleCols(AMaxWidth: Integer;
  out AFrom, ATo: Integer): Boolean;
var
  XF, XW: Integer;
begin
  Result := False;
  AFrom := 0;
  ATo := 0;
  if (not FState.HasSelection) or (AMaxWidth <= 0) then Exit;
  if not InputSelColsInWindow(FState.Text, 0, Length(FState.Text),
    FState.SelFrom(), FState.SelTo(), XF, XW) then Exit;
  { 列段钳到视口宽 }
  if XF >= AMaxWidth then Exit;
  if XF + XW > AMaxWidth then XW := AMaxWidth - XF;
  AFrom := XF;
  ATo := XF + XW;
  Result := True;
end;

procedure TLineEdit.DrawSelection(ABuffer: TBuffer; AXText, AY, AMaxWidth: Integer;
  const AStyle: TStyle);
var
  XF, XT: Integer;
begin
  if not SelVisibleCols(AMaxWidth, XF, XT) then Exit;
  ABuffer.SetStyle(TRect.Make(Word(AXText + XF), Word(AY), Word(XT - XF), 1),
    AStyle);
end;

function TLineEdit.HasSelection: Boolean;
begin
  Result := FState.HasSelection;
end;

function TLineEdit.SelectedText: string;
begin
  Result := FState.SelectedText;
end;

procedure TLineEdit.ClearSelection;
begin
  FState.ClearSelection;
end;

end.
