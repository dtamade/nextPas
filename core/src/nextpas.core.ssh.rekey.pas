unit nextpas.core.ssh.rekey;

{** nextpas.core.ssh - Rekey 策略（可复用）。
 *
 * 将同步/异步 transport 中重复的阈值计数与时间判断收口为单一记录，
 * 消除双实现漂移；基于 nextpas.core.time.TInstant 单调时钟，
 * 不再直连 SysUtils.GetTickCount64。
 * 供 transport / transport.async 共同复用，亦可被其他长连接协议复用。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base,
  nextpas.core.ssh.base;

type
  TSshRekeyPolicy = record
  private
    FThresholdBytes: UInt64;
    FIntervalMs: Integer;
    FBytesSince: UInt64;
    FLast: TInstant;
  public
    procedure Init(ABeBytes: UInt64; AIntervalMs: Integer);
    procedure Reset;
    procedure Account(ALen: UInt64);
    function ShouldRekey(const AStateEncrypted: Boolean): Boolean;
    property ThresholdBytes: UInt64 read FThresholdBytes;
    property IntervalMs: Integer read FIntervalMs;
    property BytesSince: UInt64 read FBytesSince;
  end;

implementation

procedure TSshRekeyPolicy.Init(ABeBytes: UInt64; AIntervalMs: Integer);
begin
  FThresholdBytes := ABeBytes;
  FIntervalMs := AIntervalMs;
  FBytesSince := 0;
  FLast := TInstant.Now;
  if FThresholdBytes = 0 then
    FThresholdBytes := 0;
  if FThresholdBytes = UInt64(0) then
  begin
    { 保持 1GiB 默认由 base 常量驱动；上层传入 0 表示禁用 }
  end;
end;

procedure TSshRekeyPolicy.Reset;
begin
  FBytesSince := 0;
  FLast := TInstant.Now;
end;

procedure TSshRekeyPolicy.Account(ALen: UInt64);
begin
  Inc(FBytesSince, ALen);
end;

function TSshRekeyPolicy.ShouldRekey(const AStateEncrypted: Boolean): Boolean;
begin
  Result := False;
  if not AStateEncrypted then Exit;
  if (FThresholdBytes > 0) and (FBytesSince >= FThresholdBytes) then Exit(True);
  if (FIntervalMs > 0) and (FLast.Elapsed.AsMilliseconds >= Int64(FIntervalMs)) then Exit(True);
end;

end.
