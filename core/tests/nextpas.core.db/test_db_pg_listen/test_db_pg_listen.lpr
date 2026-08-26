program test_db_pg_listen;

{ Contract tests for nextpas.core.db.pg.listen (V3-B7 LISTEN/NOTIFY)
   against a live local PostgreSQL. Requires: PG server reachable via
   $NEXTPAS_PG_TEST_CONN (default host=/var/run/postgresql
   dbname=nextpas_pg_test). All tests TestSeq (serial): they share one
   database and real backend sessions. The disconnect/reconnect case
   terminates the listener's own backend via pg_terminate_backend
   (same-role backends are always terminable). }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.pg.base,
  nextpas.core.db.pg,
  nextpas.core.db.pg.listen;

var
  T: TTestSuite;
  GConn: string;

function TestConnStr: string;
begin
  Result := GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN');
  if Result = '' then
    Result := 'host=/var/run/postgresql dbname=nextpas_pg_test user=dtamade';
end;

function SenderBackendPid(S: TPgConn): Int64;
var
  Q: TPgQuery;
begin
  Q := S.Query('SELECT pg_backend_pid()');
  try
    Check(Q.Step, 'backend pid row present');
    Result := Q.GetInt64(0);
  finally
    Q.Free;
  end;
end;

{ ===== listen + self-send/self-receive roundtrip ===== }

procedure TestListenNotifyRoundtrip;
var
  L: TPgListener;
  S: TPgConn;
  SPid: Int64;
  A: TDbPgNotificationArray;
begin
  L := PgOpenListener(GConn);
  try
    Check(L.Connected, 'listener connected after open');
    Check(L.BackendPid > 0, 'backend pid positive');
    L.Listen('np_b7_rt');
    Sleep(150);   { LISTEN 异步应用，等其生效再发通知 }
    CheckEqual(Int64(1), Int64(Length(L.SubscribedChannels)),
      'one subscribed channel');
    S := PgOpen(GConn);
    try
      SPid := SenderBackendPid(S);
      S.Exec('NOTIFY np_b7_rt, ''hello-b7''');
      A := L.Receive(2000);
      CheckEqual(Int64(1), Int64(Length(A)), 'one notification received');
      if Length(A) = 1 then
      begin
        CheckEqual('np_b7_rt', A[0].Channel, 'channel roundtrip');
        CheckEqual('hello-b7', A[0].Payload, 'payload roundtrip');
        CheckEqual(SPid, Int64(A[0].SenderPid), 'sender pid roundtrip');
      end;
    finally
      S.Free;
    end;
  finally
    L.Free;
  end;
end;

{ ===== 无载 NOTIFY ===== }

procedure TestNotifyWithoutPayload;
var
  L: TPgListener;
  S: TPgConn;
  A: TDbPgNotificationArray;
begin
  L := PgOpenListener(GConn);
  try
    L.Listen('np_b7_nopld');
    Sleep(150);   { 同上：应用窗口设防 }
    S := PgOpen(GConn);
    try
      S.Exec('NOTIFY np_b7_nopld');
      A := L.Receive(2000);
      CheckEqual(Int64(1), Int64(Length(A)), 'notification received');
      if Length(A) = 1 then
      begin
        CheckEqual('', A[0].Payload, 'empty payload for bare NOTIFY');
        Check(A[0].SenderPid > 0, 'sender pid still present');
      end;
    finally
      S.Free;
    end;
  finally
    L.Free;
  end;
end;

{ ===== 多条通知 FIFO 保序 ===== }

procedure TestMultipleNotificationsInOrder;
var
  L: TPgListener;
  S: TPgConn;
  A: TDbPgNotificationArray;
  I: Integer;
begin
  L := PgOpenListener(GConn);
  try
    L.Listen('np_b7_order');
    Sleep(150);   { 同上：应用窗口设防 }
    S := PgOpen(GConn);
    try
      { 单次 Exec 原子到达：一批十条级联投递，顺序由服务端保证 }
      S.Exec('NOTIFY np_b7_order, ''m01''; ' +
             'NOTIFY np_b7_order, ''m02''; ' +
             'NOTIFY np_b7_order, ''m03''');
      A := L.Receive(2000);
      CheckEqual(Int64(3), Int64(Length(A)), 'three notifications drained');
      for I := 0 to High(A) do
        CheckEqual('m0' + IntToStr(I + 1), A[I].Payload,
          'fifo order at ' + IntToStr(I));
    finally
      S.Free;
    end;
  finally
    L.Free;
  end;
end;

{ ===== 静默超时返回空数组 ===== }

procedure TestReceiveTimeoutEmpty;
var
  L: TPgListener;
  A: TDbPgNotificationArray;
begin
  L := PgOpenListener(GConn);
  try
    L.Listen('np_b7_quiet');
    A := L.Receive(150);
    CheckEqual(Int64(0), Int64(Length(A)), 'quiet timeout returns empty');
    { 非阻塞探测同样为空 }
    A := L.Receive(0);
    CheckEqual(Int64(0), Int64(Length(A)), 'poll probe returns empty');
  finally
    L.Free;
  end;
end;

{ ===== 非法频道名客户端拒绝（不触网） ===== }

procedure TestInvalidChannelRejected;
var
  L: TPgListener;

  procedure ExpectReject(const AChannel: string);
  var
    LWasRaised: Boolean;
  begin
    LWasRaised := False;
    try
      L.Listen(AChannel);
    except
      on E: EDbError do
        LWasRaised := True;
    end;
    Check(LWasRaised, 'rejected: "' + AChannel + '"');
  end;

begin
  L := PgOpenListener(GConn);
  try
    ExpectReject('');
    ExpectReject('bad-name');
    ExpectReject('has space');
    ExpectReject('quote''chan');
    ExpectReject(StringOfChar('a', 64));
    { 合法边界：63 字符可订阅 }
    L.Listen(StringOfChar('a', 63));
    CheckEqual(Int64(1),
      Int64(Length(L.SubscribedChannels)), '63-char channel accepted');
  finally
    L.Free;
  end;
end;

{ ===== unlisten 停投 / relisten 恢复 ===== }

procedure LRaiseProbe(L: TPgListener; const AChannel: string);
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    L.Unlisten(AChannel);
  except
    on E: EDbError do
      LRaised := True;
  end;
  Check(LRaised, 'unlisten unknown channel rejected');
end;

procedure TestUnlistenStopsAndRelistenResumes;
var
  L: TPgListener;
  S: TPgConn;
  A: TDbPgNotificationArray;
begin
  L := PgOpenListener(GConn);
  try
    L.Listen('np_b7_toggle');
    S := PgOpen(GConn);
    try
      S.Exec('NOTIFY np_b7_toggle, ''before''');
      A := L.Receive(2000);
      CheckEqual(Int64(1), Int64(Length(A)), 'received before unlisten');
      L.Unlisten('np_b7_toggle');
      CheckEqual(Int64(0),
        Int64(Length(L.SubscribedChannels)), 'snapshot cleared');
      { 等 UNLISTEN 应用并越过在途窗口，再发不应送达 }
      Sleep(200);
      S.Exec('NOTIFY np_b7_toggle, ''after-unlisten''');
      A := L.Receive(400);
      CheckEqual(Int64(0), Int64(Length(A)),
        'nothing delivered after unlisten');
      { 重订阅恢复 }
      L.Listen('np_b7_toggle');
      Sleep(120);
      S.Exec('NOTIFY np_b7_toggle, ''resumed''');
      A := L.Receive(2000);
      CheckEqual(Int64(1), Int64(Length(A)), 'delivered after relisten');
      if Length(A) = 1 then
        CheckEqual('resumed', A[0].Payload, 'resumed payload');
      { 未订阅频道 Unlisten 客户端拒绝 }
      LRaiseProbe(L, 'np_b7_never');
    finally
      S.Free;
    end;
  finally
    L.Free;
  end;
end;

{ ===== unlisten all 双频道齐停 ===== }

procedure TestUnlistenAll;
var
  L: TPgListener;
  S: TPgConn;
  A: TDbPgNotificationArray;
begin
  L := PgOpenListener(GConn);
  try
    L.Listen('np_b7_all_a');
    L.Listen('np_b7_all_b');
    CheckEqual(Int64(2),
      Int64(Length(L.SubscribedChannels)), 'two channels subscribed');
    L.UnlistenAll;
    CheckEqual(Int64(0),
      Int64(Length(L.SubscribedChannels)), 'snapshot empty after all');
    Sleep(200);
    S := PgOpen(GConn);
    try
      S.Exec('NOTIFY np_b7_all_a; NOTIFY np_b7_all_b');
      A := L.Receive(400);
      CheckEqual(Int64(0), Int64(Length(A)),
        'neither channel delivers after UNLISTEN *');
    finally
      S.Free;
    end;
  finally
    L.Free;
  end;
end;

{ ===== 队列溢出保旧弃新（容量 4，一次到批 10 条） ===== }

procedure TestQueueOverflowKeepsOldest;
var
  L: TPgListener;
  S: TPgConn;
  A: TDbPgNotificationArray;
  LSql: string;
  I: Integer;
begin
  L := TPgListener.Create(GConn, 20, 4);
  try
    L.Listen('np_b7_cap4');
    S := PgOpen(GConn);
    try
      LSql := '';
      for I := 1 to 10 do
      begin
        if LSql <> '' then
          LSql := LSql + '; ';
        LSql := LSql + 'NOTIFY np_b7_cap4, ''n' +
          Copy('0' + IntToStr(I), Length(IntToStr(I)), 2) + '''';
      end;
      S.Exec(LSql);
      Sleep(250);                      { 让整批入队（含丢弃裁决） }
      CheckEqual(Int64(6), L.DroppedCount,
        'six newest dropped (10 into cap 4)');
      A := L.Receive(500);
      CheckEqual(Int64(4), Int64(Length(A)), 'oldest four preserved');
      if Length(A) = 4 then
        for I := 0 to 3 do
          CheckEqual('n0' + IntToStr(I + 1), A[I].Payload,
            'kept oldest order at ' + IntToStr(I));
    finally
      S.Free;
    end;
  finally
    L.Free;
  end;
end;

{ ===== Token 取消协同停泵 ===== }

procedure TestTokenCancelStopsPump;
var
  L: TPgListener;
  LRaised: Boolean;
begin
  L := PgOpenListener(GConn);
  try
    Check(not L.Token.IsCancelled, 'token initially live');
    L.Token.Cancel;
    Check(L.Token.IsCancelled, 'token cancelled');
    Sleep(200);                        { 泵 ≤1 节拍内退出 }
    LRaised := False;
    try
      L.Listen('np_b7_after_cancel');
    except
      on E: EDbError do
      begin
        LRaised := True;
        Check(Pos('stopped', E.Message) > 0, 'stopped marker in message');
      end;
    end;
    Check(LRaised, 'listen after cancel raises stopped');
    LRaised := False;
    try
      L.Receive(50);
    except
      on E: EDbError do
        LRaised := True;
    end;
    Check(LRaised, 'receive after cancel drains-then-raises');
  finally
    L.Free;
  end;
end;

{ ===== 坏 conninfo 构造 fail-fast（异常路径自动析构不崩溃不泄漏） ===== }

procedure TestBadConninfoFailFast;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    { 不存在的 socket 目录 + 短 connect_timeout：建连必败且快速返回 }
    PgOpenListener('host=/no-such-socket-dir dbname=nothing user=nobody ' +
      'connect_timeout=1');
  except
    on E: EDbError do
    begin
      LRaised := True;
      Check(Pos('pg listener:', E.Message) > 0,
        'listener context carried in message');
    end;
  end;
  Check(LRaised, 'bad conninfo raises EDbError fail-fast');
end;

{ ===== 断线自动重连 + 订阅重放（真机） ===== }

procedure TestDisconnectAutoReconnectAndRelisten;
var
  L: TPgListener;
  S: TPgConn;
  A: TDbPgNotificationArray;
  LOldPid, LDeadline: Int64;
begin
  L := PgOpenListener(GConn);
  try
    L.Listen('np_b7_reconn');
    LOldPid := L.BackendPid;
    Check(LOldPid > 0, 'old backend pid known');
    Sleep(120);                        { 确保 LISTEN 已应用 }
    S := PgOpen(GConn);
    try
      { 掐掉监听会话自己的后端（同角色后端恒可终止）：断线窗口开启 }
      S.Exec('SELECT pg_terminate_backend(' + IntToStr(LOldPid) + ')');
      { 等缺口计数出现（诚实上报）——上限 ~5s }
      LDeadline := 0;
      while (L.GapCount < 1) and (LDeadline < 100) do
      begin
        Sleep(50);
        Inc(LDeadline);
      end;
      Check(L.GapCount >= 1, 'gap counted honestly');
      { 等重连完成（服务端健在，间隔 4 节拍 + connect_timeout 上限） }
      LDeadline := 0;
      while (not L.Connected) and (LDeadline < 100) do
      begin
        Sleep(50);
        Inc(LDeadline);
      end;
      Check(L.Connected, 'reconnected automatically');
      Check(L.BackendPid > 0, 'new backend pid known');
      Check(L.BackendPid <> LOldPid, 'backend actually replaced');
      { 重放订阅生效：新会话再发通知仍可达 }
      Sleep(120);
      S.Exec('NOTIFY np_b7_reconn, ''after-reconnect''');
      A := L.Receive(3000);
      CheckEqual(Int64(1), Int64(Length(A)),
        'delivered after reconnect');
      if Length(A) = 1 then
        CheckEqual('after-reconnect', A[0].Payload,
          'post-reconnect payload');
    finally
      S.Free;
    end;
  finally
    L.Free;
  end;
end;

var
  LHasEnv: Boolean;
begin
  GConn := TestConnStr;
  LHasEnv := GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN') <> '';
  T := TTestSuite.Create('nextpas.core.db.pg.listen');
  if not LHasEnv then
  begin
    WriteLn('[SKIP] live PG section: NEXTPAS_PG_TEST_CONN not set');
    Exit;
  end;
  T.TestSeq('listen & notify roundtrip', @TestListenNotifyRoundtrip);
  T.TestSeq('notify without payload', @TestNotifyWithoutPayload);
  T.TestSeq('multiple notifications fifo order',
    @TestMultipleNotificationsInOrder);
  T.TestSeq('receive timeout returns empty', @TestReceiveTimeoutEmpty);
  T.TestSeq('invalid channel rejected client-side',
    @TestInvalidChannelRejected);
  T.TestSeq('unlisten stops & relisten resumes',
    @TestUnlistenStopsAndRelistenResumes);
  T.TestSeq('unlisten all silences every channel', @TestUnlistenAll);
  T.TestSeq('queue overflow keeps oldest & counts drops',
    @TestQueueOverflowKeepsOldest);
  T.TestSeq('token cancel stops pump cooperatively',
    @TestTokenCancelStopsPump);
  T.TestSeq('bad conninfo fails fast & clean', @TestBadConninfoFailFast);
  T.TestSeq('disconnect auto-reconnect & relisten (live)',
    @TestDisconnectAutoReconnectAndRelisten);
  if not T.Run then Halt(1);
end.
