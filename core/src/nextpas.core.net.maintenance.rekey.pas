unit nextpas.core.net.maintenance.rekey;

{** nextpas.core.net.maintenance.rekey - 通用重协商策略（L1）。
 *
 *  从 `nextpas.core.ssh.rekey.TSshRekeyPolicy` 抽离的通用记录：
 *  按字节数/时间双阈值触发重协商/密钥轮换，基于 `nextpas.core.time.TInstant`
 *  单调时钟，零 `SysUtils/GetTickCount64` 直连，消除 sync/async 双实现漂移。
 *  复用：ssh rekey、tls/quic key phase、长连接轮换。
 *  单源：阈值判断在 ShouldRekey 单点；bytes.ops 不涉及，零拷贝值语义。
 *  性能：record 零堆，Init/Reset/Account/ShouldRekey 全 inline 薄转发。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base,
  nextpas.core.net.maintenance.base;

type
  TRekeyPolicy = record
  private
    FThresholdBytes: UInt64;
    FIntervalMs: Integer;
    FBytesSince: UInt64;
    FLast: TInstant;
  public
    procedure Init(ABeBytes: UInt64; AIntervalMs: Integer); inline;
    procedure Reset; inline;
    procedure Account(ALen: UInt64); inline;
    function ShouldRekey(const AEncrypted: Boolean): Boolean; inline;
    property ThresholdBytes: UInt64 read FThresholdBytes;
    property IntervalMs: Integer read FIntervalMs;
    property BytesSince: UInt64 read FBytesSince;
  end;

implementation

procedure TRekeyPolicy.Init(ABeBytes: UInt64; AIntervalMs: Integer); inline;
begin
  FThresholdBytes := ABeBytes;
  FIntervalMs := AIntervalMs;
  FBytesSince := 0;
  FLast := TInstant.Now;
end;

procedure TRekeyPolicy.Reset; inline;
begin
  FBytesSince := 0;
  FLast := TInstant.Now;
end;

procedure TRekeyPolicy.Account(ALen: UInt64); inline;
begin
  Inc(FBytesSince, ALen);
end;

function TRekeyPolicy.ShouldRekey(const AEncrypted: Boolean): Boolean; inline;
begin
  Result := False;
  if not AEncrypted then Exit;
  if (FThresholdBytes > 0) and (FBytesSince >= FThresholdBytes) then Exit(True);
  if (FIntervalMs > 0) and (FLast.Elapsed.AsMilliseconds >= Int64(FIntervalMs)) then Exit(True);
end;

end.
