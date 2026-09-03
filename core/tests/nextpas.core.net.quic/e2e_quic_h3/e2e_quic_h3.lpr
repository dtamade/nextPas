program e2e_quic_h3;

{ Q4 真机握手取证：QUIC v1 1-RTT 握手闭环（TQuicClientConnection +
  net.async UDP 驱动）。
  默认对 cloudflare-quic.com:443 解析后握手；本机 fake-ip DNS 且
  UDP/443 无回程的网络环境下可传参直连：
    e2e_quic_h3 <ip> [port]
  证书策略走 CertVerifyHook 路径（CV 签名恒验后由钩子裁决）：钩子捕获
  对端证书链 DER 落盘 /tmp/q4_e2e/ 并放行——链信任离线用 openssl 复核。
  单线程事件驱动：RunOnce 主循环 + 常驻 100ms tick 定时器（OnTimer 重发/
  出站排空，同时保证 RunOnce 等待有界）+ 有界 recv 重挂。 }
{$I nextpas.core.settings.inc}

uses nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.fs.dir,
  nextpas.core.fs.path,
  nextpas.core.fs.util,
  nextpas.core.encoding.base64,
  nextpas.core.time.base,
  nextpas.core.time.cpu,
  nextpas.core.time.deadline,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.net.base,
  nextpas.core.net.async.resolve,
  nextpas.core.net.async.udp,
  nextpas.core.net.quic.conn;

{$I ../../fpc_rtl_uses_scan.inc}

const
  CHost = 'cloudflare-quic.com';
  CPort = 443;
  CTickMs = 100;
  CRecvTimeoutMs = 250;
  COverallTimeoutMs = 10000;
  CEvidenceDir = '/tmp/q4_e2e';

type
  TDrv = class
  public
    Loop: TAsyncLoop;
    Udp: IAsyncUdpSocket;
    Conn: TQuicClientConnection;
    ServerAddr: TNetAddress;
    Resolved: Boolean;
    RecvArmed: Boolean;
    DoneOk, DoneFail: Boolean;
    StartMs: UInt64;
    Rx: array[0..4095] of Byte;
    Captured: TQuicDerList;
    procedure ArmRecv;
    procedure SendDgram(const ADgram: TBytes);
    procedure DrainOutbound;
    class procedure OnResolved(const AResult: TDnsResult; AContext: Pointer); static;
    class procedure OnSent(AResult: Int32; ABytes: Int32; AContext: Pointer); static;
    class procedure OnRecv(AResult: Int32; ABytes: Int32; const AFrom: TNetAddress;
      AContext: Pointer); static;
    procedure OnTick(AContext: Pointer);
    function HookAccept(const ACerts: TQuicDerList;
      out AError: string): Boolean;
  end;

class procedure TDrv.OnResolved(const AResult: TDnsResult; AContext: Pointer);
var
  LDrv: TDrv;
begin
  LDrv := TDrv(AContext);
  if AResult.Success then
  begin
    LDrv.ServerAddr := AResult.FirstAddress;
    LDrv.Resolved := True;
  end
  else
    LDrv.DoneFail := True;
end;

class procedure TDrv.OnSent(AResult: Int32; ABytes: Int32; AContext: Pointer);
begin
  { 发送失败不致命：tick 的 OnTimer 重发兜底 }
end;

procedure TDrv.SendDgram(const ADgram: TBytes);
begin
  Udp.AsyncSendTo(@ADgram[0], UInt32(Length(ADgram)), ServerAddr,
    @TDrv.OnSent, nil);
end;

procedure TDrv.DrainOutbound;
var
  LOut: TBytes;
begin
  while Conn.TakeOutbound(LOut) do
    SendDgram(LOut);
end;

procedure TDrv.ArmRecv;
var
  LOk: Boolean;
begin
  if RecvArmed or (Udp = nil) or DoneOk or DoneFail then
    Exit;
  { 先置已挂再提交：reactor 对已就绪数据会在提交调用内同步完成回调
    （清标志），后写 LOk 会把该清除覆盖回 True 造成永久停读 }
  RecvArmed := True;
  LOk := Udp.AsyncRecvFromTimeout(@Rx[0], UInt32(Length(Rx)),
    TDeadline.After(TDuration.FromMilliseconds(CRecvTimeoutMs)),
    @TDrv.OnRecv, Self);
  if not LOk then
    RecvArmed := False;   { 提交被拒：下一 tick 重试 }
end;

class procedure TDrv.OnRecv(AResult: Int32; ABytes: Int32;
  const AFrom: TNetAddress; AContext: Pointer);
{ 完成约定（net.async.udp）：AResult ≥ 0 为成功字节数，< 0 为 -errno }
var
  LDrv: TDrv;
  LDgram: TBytes;
  LI, LN: Integer;
begin
  LDrv := TDrv(AContext);
  LDrv.RecvArmed := False;
  if AResult < 0 then
    Exit;   { 超时/暂错：tick 重新挂收 }
  LN := AResult;
  if LN <= 0 then
    Exit;
  SetLength(LDgram, LN);
  for LI := 0 to LN - 1 do
    LDgram[LI] := LDrv.Rx[LI];
  WriteLn('[e2e] rx ', LN, 'B');
  Flush(Output);
  if not LDrv.Conn.OnDatagram(LDgram) then
    LDrv.DoneFail := True;
  case LDrv.Conn.Phase of
    qcpConnected:
      LDrv.DoneOk := True;
    qcpClosed:
      LDrv.DoneFail := True;
  else
    ;   { InitialSent/Handshake：继续 tick 驱动 }
  end;
end;

procedure TDrv.OnTick(AContext: Pointer);
begin
  if DoneOk or DoneFail then
    Exit;
  Conn.OnTimer(GetTickCount64 * 1000);
  DrainOutbound;
  ArmRecv;
  Loop.Schedule(TDuration.FromMilliseconds(CTickMs),
    TAsyncCallback(@TDrv.OnTick), Self);
end;

function TDrv.HookAccept(const ACerts: TQuicDerList;
  out AError: string): Boolean;
begin
  Captured := ACerts;
  AError := '';
  Result := True;
end;

function PortArg: UInt16;
var
  LS: string;
  LV, LI: Integer;
begin
  Result := CPort;
  LS := ParamStr(2);
  if LS = '' then
    Exit;
  LV := 0;
  for LI := 1 to Length(LS) do
    if (LS[LI] >= '0') and (LS[LI] <= '9') then
      LV := LV * 10 + Ord(LS[LI]) - Ord('0')
    else
      Exit;
  if (LV > 0) and (LV < 65536) then
    Result := UInt16(LV);
end;

function PemBlock(const ADer: TBytes): string;
var
  LB64: string;
  LI, LN: Integer;
begin
  Result := '-----BEGIN CERTIFICATE-----'#10;
  LB64 := Base64Encode(ADer);
  LN := Length(LB64);
  LI := 1;
  while LI <= LN do
  begin
    if LI + 64 <= LN then
      Result := Result + Copy(LB64, LI, 64) + #10
    else
      Result := Result + Copy(LB64, LI, LN - LI + 1) + #10;
    Inc(LI, 64);
  end;
  Result := Result + '-----END CERTIFICATE-----'#10;
end;

var
  LDrv: TDrv;
  LParams: TQuicClientParams;
  LEafPath, LChainPath, LPem: string;
  LI: Integer;
begin
  LDrv := TDrv.Create;
  try
    LDrv.Loop := TAsyncLoop.Create;
    try
      LDrv.StartMs := GetTickCount64;
      if ParamStr(1) <> '' then
      begin
        { 直连地址（fake-ip DNS 无回程 / 本地互操作服务器）；
          SNI/证书仍按 CHost 处理 }
        LDrv.ServerAddr := TNetAddress.IPv4(ParamStr(1), PortArg);
        LDrv.Resolved := True;
        WriteLn('[e2e] direct ', ParamStr(1), ':', PortArg);
      end
      else
      begin
        WriteLn('[e2e] resolving ', CHost, '...');
        if not AsyncResolve(LDrv.Loop, CHost, @TDrv.OnResolved,
          Pointer(LDrv)) then
        begin
          WriteLn('[e2e] resolve dispatch failed');
          Halt(2);
        end;
        while (not LDrv.Resolved) and (not LDrv.DoneFail) and
          (GetTickCount64 - LDrv.StartMs < COverallTimeoutMs) do
          LDrv.Loop.RunOnce;
        if not LDrv.Resolved then
        begin
          WriteLn('[e2e] resolve failed/unreachable — network-dependent run');
          Halt(3);
        end;
        LDrv.ServerAddr.Port := CPort;
      end;
      Flush(Output);
      WriteLn('[e2e] server=', LDrv.ServerAddr.IP, ':',
        LDrv.ServerAddr.Port);

      LDrv.Udp := AsyncUdpBind(LDrv.Loop, '0.0.0.0', 0);

      LParams := Default(TQuicClientParams);
      LParams.Hostname := CHost;
      LParams.ALPN := 'h3';
      { 走钩子路径：CV 恒验生效 + 链裁决显式化（捕获证据后放行） }
      LParams.InsecureSkipVerify := False;
      LParams.CertVerifyHook := @LDrv.HookAccept;
      LDrv.Conn := TQuicClientConnection.Create(LParams);
      try
        LDrv.Conn.Start;
        LDrv.DrainOutbound;
        LDrv.ArmRecv;
        LDrv.Loop.Schedule(TDuration.FromMilliseconds(CTickMs),
          TAsyncCallback(@TDrv.OnTick), LDrv);

        while (not LDrv.DoneOk) and (not LDrv.DoneFail) and
          (GetTickCount64 - LDrv.StartMs < COverallTimeoutMs) do
          LDrv.Loop.RunOnce;

        if not LDrv.DoneOk then
        begin
          WriteLn('[e2e] handshake FAILED phase=',
            Ord(LDrv.Conn.Phase), ' err=', LDrv.Conn.LastError);
          Halt(4);
        end;

        WriteLn('[e2e] CONNECTED in ', GetTickCount64 - LDrv.StartMs,
          ' ms certs=', Length(LDrv.Captured));

        FsMkdirAll(CEvidenceDir);
        LEafPath := FsPathJoin([CEvidenceDir, 'leaf.der']);
        FsWriteFile(LEafPath, LDrv.Captured[0]);
        LChainPath := FsPathJoin([CEvidenceDir, 'chain.pem']);
        LPem := '';
        for LI := 0 to High(LDrv.Captured) do
          LPem := LPem + PemBlock(LDrv.Captured[LI]);
        FsWriteFileText(LChainPath, LPem);
        WriteLn('[e2e] evidence: ', LEafPath, ' + ', LChainPath);
      finally
        LDrv.Conn.Free;
      end;
    finally
      LDrv.Loop.Free;
    end;
  finally
    LDrv.Free;
  end;
end.
