unit nextpas.core.tui.interaction;

{**
 * @desc 交互原语：指针捕获、悬停追踪、命中测试、交互会话管理。
 *
 * 这些是 drag、hover、Esc-cancel 语义的构建块。紧密耦合故放在同一单元
 * （capture 影响 hover，session 影响 capture）。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.event;

type
  THoverChange = (hcNone, hcEntered, hcLeft, hcStay);

  { 指针捕获：消费方检查 Active 判断事件是否属于当前 drag 会话。
    TTerminal 在 MouseUp（commit）或 Esc（cancel）时自动释放。 }
  TPointerCapture = record
    Active: Boolean;
    Target: Pointer;       { 不透明；消费方自行 cast }
    Button: TMouseButton;  { 发起捕获的按钮 }
    procedure Acquire(ATarget: Pointer; AButton: TMouseButton);
    procedure Release;
  end;

  { 交互会话：表示一次 drag/stroke/rename/filter 从开始到 commit/cancel。 }
  TSessionState = (ssNone, ssActive, ssCommitted, ssCancelled);

  TInteractionSession = record
    State: TSessionState;
    Target: Pointer;
    procedure Begin_(ATarget: Pointer);
    procedure Commit;
    procedure Cancel;
    function IsActive: Boolean; inline;
  end;

{ 命中测试：鼠标位置是否在 rect 内？ }
function HitTest(const AArea: TRect; AX, AY: Word): Boolean; inline;
function HitTestEvent(const AArea: TRect; const AEv: TMouseEvent): Boolean; inline;

{ 悬停变化检测：比较前后鼠标位置与区域的关系。 }
function DetectHoverChange(const AArea: TRect;
  APrevX, APrevY, ACurrX, ACurrY: Word): THoverChange;

implementation

{ TPointerCapture }

procedure TPointerCapture.Acquire(ATarget: Pointer; AButton: TMouseButton);
begin
  Active := True;
  Target := ATarget;
  Button := AButton;
end;

procedure TPointerCapture.Release;
begin
  Active := False;
  Target := nil;
  Button := mbNone;
end;

{ TInteractionSession }

procedure TInteractionSession.Begin_(ATarget: Pointer);
begin
  State := ssActive;
  Target := ATarget;
end;

procedure TInteractionSession.Commit;
begin
  if State = ssActive then
    State := ssCommitted;
end;

procedure TInteractionSession.Cancel;
begin
  if State = ssActive then
    State := ssCancelled;
end;

function TInteractionSession.IsActive: Boolean;
begin
  Result := State = ssActive;
end;

{ Hit-test }

function HitTest(const AArea: TRect; AX, AY: Word): Boolean;
begin
  Result := (AX >= AArea.X) and (AX < AArea.X + AArea.Width) and
            (AY >= AArea.Y) and (AY < AArea.Y + AArea.Height);
end;

function HitTestEvent(const AArea: TRect; const AEv: TMouseEvent): Boolean;
begin
  Result := HitTest(AArea, AEv.X, AEv.Y);
end;

function DetectHoverChange(const AArea: TRect;
  APrevX, APrevY, ACurrX, ACurrY: Word): THoverChange;
var
  LWasIn, LIsIn: Boolean;
begin
  LWasIn := HitTest(AArea, APrevX, APrevY);
  LIsIn  := HitTest(AArea, ACurrX, ACurrY);
  if (not LWasIn) and LIsIn then Result := hcEntered
  else if LWasIn and (not LIsIn) then Result := hcLeft
  else if LWasIn and LIsIn then Result := hcStay
  else Result := hcNone;
end;

end.
