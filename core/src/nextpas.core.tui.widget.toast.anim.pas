unit nextpas.core.tui.widget.toast.anim;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

{*
  动画级 Toast 通知层（与简单静态 toast 并存的高级组件）。

  行为契约：
  - 动画帧率由宿主驱动：每帧 Tick(NowMs)（绝对单调毫秒，见 NowMs），
    Render 前推进状态；
  - 入场 240ms 自下 8 行线性滑入 + 淡入（位移线性保证每帧 ~0.5 行位移；
    颜色 easeOutCubic）；
  - 种类切换（|→+/x/!）：160ms 边框色从旧种类缓动渐变到新种类；
  - 退场：最后 260ms 下滑 5 行 + 淡出（位移线性，颜色 easeInCubic）；
  - spinner：Braille 10 帧 50ms/帧（20fps，60fps 屏上每 3 帧一跳）；
  - 同一个操作原地更新同一条（key），不新增；
  - 多条栈式显示：最新在最下，最多 3 条，满则挤最旧。

  宿主用法：
    FToasts := TToastAnim.New;                工厂创建
    FToasts.Show('已保存', tkOk);              入栈
    FToasts.Show('保存中..', tkSpin, 'save');  同 key 原地更新
    FToasts.Tick(NowMs);                      推进/过期清理
    FToasts.Render(ABuffer, AArea, ATheme);   最后绘制，盖一切
  Toast 活跃期间宿主应保持帧驱动（可查 Visible > 0）。

  渲染纪律：单条框线常量复用，零堆分配；主题由调用方传入 core TTheme
  （16 语义槽，取 .Fg/.Bg 上色，与宿主主屏一致）。
  不实现 IWidget：Render 需要外部 ATheme 参数，与 IWidget.Render 签名
  不兼容（简单 TToastManager 的固定样式方案不适用动画组件）。
*}

interface

uses
  nextpas.core.time,
  nextpas.core.tui.base,     { TRect }
  nextpas.core.tui.color,
  nextpas.core.tui.buffer,
  nextpas.core.tui.style,
  nextpas.core.tui.borders,
  nextpas.core.tui.theme,
  nextpas.core.math.easing,
  nextpas.core.text.width;

type
  { 种类：决定图标与强调色；tkInfo 无图标 }
  TToastKind = (tkInfo, tkSpin, tkOk, tkErr, tkWarn);

  { 单条 Toast 状态（0=最旧，尾=最新/最下） }
  TToastEntry = record
    Key: string;           { 更新键：同 Key 的 Show 原地更新，不新增 }
    Text: string;
    Kind: TToastKind;
    FromKind: TToastKind;  { 换色动画起点种类（种类切换时记录旧值） }
    BornMs: QWord;         { 入栈时刻（入场动画起算） }
    ChangeMs: QWord;       { 最近一次种类切换时刻（换色起算） }
    EndMs: QWord;          { 消失时刻(ms) }
    Progress: Double;      { 1=新，0=消失（剩余时刻占总时长占比）；退场据此下滑淡出 }
  end;

  IToastAnim = interface
    ['{7D348AFF-1583-47DC-871E-16B82CEF2273}']
    procedure Show(const AText: string; AKind: TToastKind = tkInfo;
      const AKey: string = '');
    { 给 key 对应 toast 续期：消失时刻改为 ALifeMs 之后（不重置 BornMs/ChangeMs，
      不重放入场动画）。用于长时 spinner——不续期会提前消失或变新弹 }
    procedure Renew(const AKey: string; ALifeMs: QWord);
    procedure Tick(ANowMs: QWord);
    procedure Render(ABuffer: TBuffer; const AArea: TRect;
      const ATheme: TTheme);
    function GetVisible: Integer;
    property Visible: Integer read GetVisible;
  end;

  TToastAnim = class(TInterfacedObject, IToastAnim)
  private
    FItems: array of TToastEntry;
    FMaxVisible: Integer;
    FDurationMs: Integer;
    procedure DropOldest;
  public
    class function New(ADurationMs: Integer = 1800;
      AMaxVisible: Integer = 3): IToastAnim;

    procedure Show(const AText: string; AKind: TToastKind = tkInfo;
      const AKey: string = '');
    procedure Renew(const AKey: string; ALifeMs: QWord);
    procedure Tick(ANowMs: QWord);
    procedure Render(ABuffer: TBuffer; const AArea: TRect;
      const ATheme: TTheme);
    function GetVisible: Integer;
  end;

implementation

const
  ENTER_MS = 240;      { 入场滑入+淡入 }
  CHANGE_MS = 160;     { 种类切换颜色渐变 }
  EXIT_MS = 260;       { 退场下滑+淡出 }
  SPIN_MS = 50;        { spinner 帧间隔(20fps，60fps 屏上每 3 帧一跳) }

  { 位移幅度：入场从下 8 行滑入，退场下滑 5 行。
    位移用线性（easeOutCubic 尾部近零斜率→尾段全是静止帧，观感
    「弹一下卡住」），颜色才用缓动 }
  ENTER_ROWS = 8;
  EXIT_ROWS = 5;

  { 种类→图标（静态帧；tkSpin 由 SPINNER_FRAMES 轮换）。
    全部用 1 列 ASCII（+ x ! |）与 Braille——不引入 Ambiguous 级字形
    （如 ✓✗⚠⟳ 在 CJK 终端按 2 列渲染会把框线右推错位） }
  TOAST_ICONS: array[TToastKind] of string =
    ('', '|', '+', 'x', '!');
  { 10 帧 Braille spinner（预展开常量帧，零堆分配） }
  SPINNER_FRAMES: array[0..9] of string =
    ('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏');
  FILL = '────────────────────────────────────────────────────────────';
  SPACES = '                                                                ';

function NowMs: QWord; inline;
begin
  Result := GetTickCount64;
end;

{ 满栈：挤掉最旧，整体前移腾出末位 }
procedure TToastAnim.DropOldest;
var
  I: Integer;
begin
  for I := 1 to High(FItems) do
    FItems[I - 1] := FItems[I];
  SetLength(FItems, Length(FItems) - 1);
end;

class function TToastAnim.New(ADurationMs: Integer; AMaxVisible: Integer): IToastAnim;
var
  LSelf: TToastAnim;
begin
  LSelf := TToastAnim.Create;
  LSelf.FItems := nil;
  { 钳制下限：AMaxVisible=0 会在满栈走 DropOldest 触发 SetLength(-1)；
    FDurationMs=0 会让 Tick/DrawOne 除零 }
  if AMaxVisible < 1 then AMaxVisible := 1;
  if ADurationMs < 1 then ADurationMs := 1;
  LSelf.FDurationMs := ADurationMs;
  LSelf.FMaxVisible := AMaxVisible;
  Result := LSelf;
end;

procedure TToastAnim.Show(const AText: string; AKind: TToastKind;
  const AKey: string);
var
  I: Integer;
  E: TToastEntry;
  LNow: QWord;
begin
  if AText = '' then Exit;
  LNow := NowMs;
  { 同 Key 已在栈内：原地更新（重置计时；种类变化记录换色起点） }
  if AKey <> '' then
    for I := 0 to High(FItems) do
      if FItems[I].Key = AKey then
      begin
        FItems[I].Text := AText;
        if FItems[I].Kind <> AKind then
        begin
          FItems[I].FromKind := FItems[I].Kind; { 换色动画起算(旧色) }
          FItems[I].ChangeMs := LNow;
          FItems[I].Kind := AKind;
        end;
        FItems[I].EndMs := LNow + QWord(FDurationMs);
        FItems[I].Progress := 1;
        Exit;
      end;
  if Length(FItems) >= FMaxVisible then
    DropOldest;
  E.Key := AKey;
  E.Text := AText;
  E.Kind := AKind;
  E.FromKind := AKind;
  E.BornMs := LNow;
  E.ChangeMs := LNow;
  E.EndMs := LNow + QWord(FDurationMs);
  E.Progress := 1;
  SetLength(FItems, Length(FItems) + 1);
  FItems[High(FItems)] := E;
end;

procedure TToastAnim.Renew(const AKey: string; ALifeMs: QWord);
{ 续期实现：仅推后 EndMs，不碰 BornMs/ChangeMs——走 Show 会重放入场动画，
  长时 spinner 期间每帧重置开场会有「弹一下」 }
var
  I: Integer;
begin
  if (AKey = '') or (ALifeMs = 0) then Exit;
  for I := 0 to High(FItems) do
    if FItems[I].Key = AKey then
    begin
      FItems[I].EndMs := NowMs + ALifeMs;
      Exit;
    end;
end;

procedure TToastAnim.Tick(ANowMs: QWord);
var
  I, W: Integer;
begin
  W := 0;
  for I := 0 to High(FItems) do
  begin
    if ANowMs >= FItems[I].EndMs then
      Continue;                     { 过期丢弃 }
    FItems[I].Progress := (FItems[I].EndMs - ANowMs) / FDurationMs;
    if FItems[I].Progress < 0 then
      FItems[I].Progress := 0;
    if W <> I then
      FItems[W] := FItems[I];
    Inc(W);
  end;
  SetLength(FItems, W);
end;

function TToastAnim.GetVisible: Integer;
begin
  Result := Length(FItems);
end;

{ 种类→强调色：从语义槽的 Fg 取色（core TTheme 是 TStyle 槽） }
function KindAccent(const ATheme: TTheme; AKind: TToastKind): TColor;
begin
  case AKind of
    tkOk:   Result := ATheme.Success.Fg;
    tkErr:  Result := ATheme.Error_.Fg;
    tkSpin: Result := ATheme.Warning.Fg;
    tkWarn: Result := ATheme.Warning.Fg;
  else
    Result := ATheme.Primary.Fg;
  end;
end;

{ 单条圆角框（水平居中）。规范：内容与边框 1 格呼吸空间。
  布局：│ 呼吸 icon 空格 文案 呼吸 │（无图标时 icon 列留空，列宽不变）
         X   X+1  X+2  X+3   X+4    X+TW+6 }
procedure DrawOne(ABuffer: TBuffer; const AArea: TRect;
  const ATheme: TTheme; const AEntry: TToastEntry; AY, AMaxW: Integer;
  ANow: QWord; ADurationMs: Integer);
var
  LIcon: string;
  LAccent, LFromAccent: TColor;
  LBoxBg, LTextColor: TColor;
  TW, W, X, Y: Integer;
  LSt, LBoxSt, LTextSt: TStyle;
  E, LAlpha: Double;
begin
  { 窄屏(AMaxW≤6 最小框都放不下)：跳过，负宽会让残角散落画到屏外 }
  if AMaxW <= 6 then Exit;
  LBoxBg := ATheme.Bg.Bg;       { 主题必须设置 Bg 槽的背景位（core 预设均满足） }
  LTextColor := ATheme.Fg.Fg;
  LAccent := KindAccent(ATheme, AEntry.Kind);
  LAlpha := 1;   { 整体不透明度：入场淡入 / 退场淡出 }

  { 入场：ENTER_MS 线性位移（从下 ENTER_ROWS 行滑入）+ 淡入 }
  E := (ANow - AEntry.BornMs) / ENTER_MS;
  if E < 1 then
  begin
    if E < 0 then E := 0;
    { 位移：线性（规范要求），从下 ENTER_ROWS 行滑到目标位 }
    Y := AY + Round(ENTER_ROWS * (1 - E));
    { 淡入：颜色从 Dim 缓动到 Accent }
    LAccent := ColorInterp(ATheme.Muted.Fg, LAccent, EaseOutCubic(E));
    LAlpha := E;
  end
  else
    Y := AY;

  { 种类切换：CHANGE_MS 内从旧种类色缓动渐变到新种类色 }
  E := (ANow - AEntry.ChangeMs) / CHANGE_MS;
  if (E < 1) and (AEntry.FromKind <> AEntry.Kind) then
  begin
    LFromAccent := KindAccent(ATheme, AEntry.FromKind);
    LAccent := ColorInterp(LFromAccent, LAccent, EaseOutCubic(E));
  end;

  { 退场：最后 EXIT_MS 线性下滑 EXIT_ROWS 行 + 淡出 }
  if AEntry.Progress < EXIT_MS / ADurationMs then
  begin
    E := 1 - AEntry.Progress * ADurationMs / EXIT_MS;  { 0→1 淡出进度 }
    Y := Y + Round(EXIT_ROWS * E);
    LAccent := ColorInterp(LAccent, ATheme.Muted.Fg, EaseInCubic(E));
    LAlpha := 1 - E;
  end;

  { 图标：tkSpin 按 SPIN_MS 轮换 Braille 帧（常量索引，零堆分配） }
  LIcon := TOAST_ICONS[AEntry.Kind];
  if AEntry.Kind = tkSpin then
    LIcon := SPINNER_FRAMES[(ANow div SPIN_MS) mod 10];

  TW := Integer(StringDisplayWidth(AEntry.Text));
  { 宽度统一为 TW+6：无图标(tkInfo)也预占 icon+空格 2 列。
    种类原地切换(+/x/!)只换图标不换列宽，宽度不随种类跳变 }
  if TW > AMaxW - 6 then
    TW := AMaxW - 6;                   { 超宽裁掉，防溢出(留呼吸空间) }
  W := TW + 6;                         { 边框2 + 左右呼吸2 + icon1 + 空格1 }
  X := AArea.X + (AArea.Width - W) div 2;

  { 入场/退场期间用 Bg 混入降低不透明度（模拟淡入淡出）。
    边框线一律走 Border 槽位（弱化线条纪律，不随种类强调色变亮），
    种类语义只由图标（LSt）承载 }
  if LAlpha < 1 then
  begin
    LSt := TStyle.Default
      .WithFg(ColorInterp(LBoxBg, LAccent, LAlpha))
      .WithBg(LBoxBg);
    LBoxSt := TStyle.Default
      .WithFg(ColorInterp(LBoxBg, ATheme.Border.Fg, LAlpha))
      .WithBg(LBoxBg);
    LTextSt := TStyle.Default
      .WithFg(ColorInterp(LBoxBg, LTextColor, LAlpha))
      .WithBg(LBoxBg);
  end
  else
  begin
    LSt := TStyle.Default.WithFg(LAccent).WithBg(LBoxBg);
    LBoxSt := TStyle.Default.WithFg(ATheme.Border.Fg).WithBg(LBoxBg);
    LTextSt := TStyle.Default.WithFg(LTextColor).WithBg(LBoxBg);
  end;

  { 顶行 ╭ ─ ╮ }
  ABuffer.SetString(X, Y, BORDER_ROUNDED_TL, LBoxSt);
  ABuffer.SetStringN(X + 1, Y, FILL, W - 2, LBoxSt);
  ABuffer.SetString(X + W - 1, Y, BORDER_ROUNDED_TR, LBoxSt);

  { 中行：│ 呼吸 [icon|空格] 空格 文案 呼吸 │
    无图标也写入 icon 列的空格（宽度与有图标时一致，种类切换不跳宽） }
  ABuffer.SetString(X, Y + 1, BORDER_VERTICAL, LBoxSt);
  ABuffer.SetStringN(X + 1, Y + 1, SPACES, W - 2, LTextSt);
  if LIcon <> '' then
    ABuffer.SetString(X + 2, Y + 1, LIcon, LSt)
  else
    ABuffer.SetString(X + 2, Y + 1, ' ', LSt);
  ABuffer.SetStringN(X + 4, Y + 1, AEntry.Text, W - 6, LTextSt);
  ABuffer.SetString(X + W - 1, Y + 1, BORDER_VERTICAL, LBoxSt);

  { 底行 ╰ ─ ╯ }
  ABuffer.SetString(X, Y + 2, BORDER_ROUNDED_BL, LBoxSt);
  ABuffer.SetStringN(X + 1, Y + 2, FILL, W - 2, LBoxSt);
  ABuffer.SetString(X + W - 1, Y + 2, BORDER_ROUNDED_BR, LBoxSt);
end;

procedure TToastAnim.Render(ABuffer: TBuffer; const AArea: TRect;
  const ATheme: TTheme);
var
  I, LBottom: Integer;
  LNow: QWord;
begin
  if Length(FItems) = 0 then Exit;
  LNow := NowMs;
  { 底部 3 行留给操作条/分隔线区域 }
  LBottom := AArea.Y + AArea.Height - 6;
  if LBottom < AArea.Y then LBottom := AArea.Y;  { 矮屏：钳制到区顶，防整体画在屏外 }
  { 两遍绘制：正常条目先画，退场的最后置顶画——EXIT_ROWS=5 > 栈间距 4，
    若不置顶，下滑的旧条会自上而下钻入下层条目之下穿插 }
  for I := 0 to High(FItems) do
    if FItems[I].Progress * FDurationMs >= EXIT_MS then
      DrawOne(ABuffer, AArea, ATheme, FItems[I],
        LBottom - (Length(FItems) - 1 - I) * 4, AArea.Width - 14, LNow, FDurationMs);
  for I := 0 to High(FItems) do
    if FItems[I].Progress * FDurationMs < EXIT_MS then
      DrawOne(ABuffer, AArea, ATheme, FItems[I],
        LBottom - (Length(FItems) - 1 - I) * 4, AArea.Width - 14, LNow, FDurationMs);
end;

end.