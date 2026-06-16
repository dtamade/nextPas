# Platform Windows Real Runtime 测试补充计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 补充 platform.io 和 platform.socket 的 Real Windows runtime 测试，缩小 Wine 与 Real Windows 之间的差距。

**Architecture:**
- 在 `core/tests/nextpas.core.platform/` 下创建 `test_platform_io_windows_real/` 和 `test_platform_socket_windows_real/` 两个新测试套件
- 利用已有的 `platform-windows-focused-smoke.sh` 基础设施，通过 SCP + SSH 部署到 Windows VM
- 测试套件使用 nextpas.core.testing 框架，输出与现有 Wine 测试一致的格式

**Tech Stack:** FPC 3.3.1 (Win64 cross-compile), nextpas.core.testing, platform.io/socket APIs

---

## Phase 1: platform.io Windows Real 测试

### Task 1: 创建 test_platform_io_windows_real 测试框架

**Files:**
- Create: `core/tests/nextpas.core.platform/test_platform_io_windows_real/test_platform_io_windows_real.lpr`
- Create: `core/tests/nextpas.core.platform/test_platform_io_windows_real/Makefile`

**Step 1: 创建目录结构**

```bash
mkdir -p core/tests/nextpas.core.platform/test_platform_io_windows_real
```

**Step 2: 编写 test_platform_io_windows_real.lpr**

测试用例列表（10 个）:

```pascal
program test_platform_io_windows_real;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.platform.io;

var
  T: TTestRunner;

procedure TestCreateWithWinsockInit;
var
  LPoller: TPlatformPoller;
begin
  LPoller := platform_poller_create(64);
  Check(LPoller <> nil, 'platform_poller_create should succeed');
  if LPoller <> nil then
    platform_poller_close(LPoller);
end;

procedure TestCloseCleansUpWinsock;
var
  LPoller: TPlatformPoller;
begin
  LPoller := platform_poller_create(64);
  Check(LPoller <> nil, 'platform_poller_create should succeed');
  platform_poller_close(LPoller);
  // 二次关闭应安全
  platform_poller_close(LPoller);
end;

procedure TestWaitPollingWithReadySocket;
var
  LPoller: TPlatformPoller;
  LSock: TPlatformSocket;
  LEvent: TPlatformPollerEvent;
  LEvents: array[0..7] of TPlatformPollerEvent;
  LCount: Int32;
begin
  LSock := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  Check(LSock <> nil, 'socket_create should succeed');
  LPoller := platform_poller_create(64);
  Check(LPoller <> nil, 'platform_poller_create should succeed');
  platform_poller_add(LPoller, platform_socket_handle(LSock), PLATFORM_POLLIN);
  // 无事件时立即返回
  LCount := platform_poller_wait(LPoller, @LEvents, 8, 0);
  Check(LCount >= 0, 'platform_poller_wait should return >= 0');
  platform_poller_close(LPoller);
  platform_socket_close(LSock);
end;

procedure TestWaitTimeoutNoEvents;
var
  LPoller: TPlatformPoller;
  LEvents: array[0..7] of TPlatformPollerEvent;
  LCount: Int32;
begin
  LPoller := platform_poller_create(64);
  Check(LPoller <> nil, 'platform_poller_create should succeed');
  LCount := platform_poller_wait(LPoller, @LEvents, 8, 100);
  Check(LCount = 0, 'timeout with no events should return 0');
  platform_poller_close(LPoller);
end;

procedure TestAddDuplicateFdError;
var
  LPoller: TPlatformPoller;
  LSock: TPlatformSocket;
  LRet: Int32;
begin
  LSock := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  Check(LSock <> nil, 'socket_create should succeed');
  LPoller := platform_poller_create(64);
  Check(LPoller <> nil, 'platform_poller_create should succeed');
  LRet := platform_poller_add(LPoller, platform_socket_handle(LSock), PLATFORM_POLLIN);
  Check(LRet = 0, 'first add should succeed');
  LRet := platform_poller_add(LPoller, platform_socket_handle(LSock), PLATFORM_POLLIN);
  Check(LRet <> 0, 'duplicate add should return error');
  platform_poller_close(LPoller);
  platform_socket_close(LSock);
end;

procedure TestRemoveNonexistentFdError;
var
  LPoller: TPlatformPoller;
  LRet: Int32;
begin
  LPoller := platform_poller_create(64);
  Check(LPoller <> nil, 'platform_poller_create should succeed');
  LRet := platform_poller_remove(LPoller, 9999);
  Check(LRet <> 0, 'remove nonexistent fd should return error');
  platform_poller_close(LPoller);
end;

procedure TestModifyNonexistentFdError;
var
  LPoller: TPlatformPoller;
  LRet: Int32;
begin
  LPoller := platform_poller_create(64);
  Check(LPoller <> nil, 'platform_poller_create should succeed');
  LRet := platform_poller_modify(LPoller, 9999, PLATFORM_POLLIN, PLATFORM_POLLOUT);
  Check(LRet <> 0, 'modify nonexistent fd should return error');
  platform_poller_close(LPoller);
end;

procedure TestEnableWakeSocketPair;
var
  LPoller: TPlatformPoller;
  LRet: Int32;
begin
  LPoller := platform_poller_create(64);
  Check(LPoller <> nil, 'platform_poller_create should succeed');
  LRet := platform_poller_enable_wake(LPoller);
  Check(LRet = 0, 'enable_wake should succeed');
  platform_poller_close(LPoller);
end;

procedure TestWakeDrainRoundtrip;
var
  LPoller: TPlatformPoller;
  LRet: Int32;
begin
  LPoller := platform_poller_create(64);
  Check(LPoller <> nil, 'platform_poller_create should succeed');
  platform_poller_enable_wake(LPoller);
  platform_poller_wake(LPoller);
  LRet := platform_poller_drain_wake(LPoller);
  Check(LRet >= 0, 'drain_wake should return >= 0');
  platform_poller_close(LPoller);
end;

procedure TestPollMultipleSockets;
var
  LPoller: TPlatformPoller;
  LSock1, LSock2: TPlatformSocket;
  LEvents: array[0..7] of TPlatformPollerEvent;
  LCount: Int32;
begin
  LSock1 := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  LSock2 := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  Check((LSock1 <> nil) and (LSock2 <> nil), 'sockets should create');
  LPoller := platform_poller_create(64);
  Check(LPoller <> nil, 'platform_poller_create should succeed');
  platform_poller_add(LPoller, platform_socket_handle(LSock1), PLATFORM_POLLIN);
  platform_poller_add(LPoller, platform_socket_handle(LSock2), PLATFORM_POLLIN);
  LCount := platform_poller_wait(LPoller, @LEvents, 8, 0);
  Check(LCount >= 0, 'platform_poller_wait should return >= 0');
  platform_poller_close(LPoller);
  platform_socket_close(LSock2);
  platform_socket_close(LSock1);
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.io.windows_real');
  T.Run('create_with_winsock_init', @TestCreateWithWinsockInit);
  T.Run('close_cleans_up_winsock', @TestCloseCleansUpWinsock);
  T.Run('wait_polling_with_ready_socket', @TestWaitPollingWithReadySocket);
  T.Run('wait_timeout_no_events', @TestWaitTimeoutNoEvents);
  T.Run('add_duplicate_fd_error', @TestAddDuplicateFdError);
  T.Run('remove_nonexistent_fd_error', @TestRemoveNonexistentFdError);
  T.Run('modify_nonexistent_fd_error', @TestModifyNonexistentFdError);
  T.Run('enable_wake_socket_pair', @TestEnableWakeSocketPair);
  T.Run('wake_drain_roundtrip', @TestWakeDrainRoundtrip);
  T.Run('poll_multiple_sockets', @TestPollMultipleSockets);
  T.Summary;
end.
```

**Step 3: 创建 Makefile**

```makefile
FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform/test_platform_io_windows_real
PROGRAM := test_platform_io_windows_real
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -Twin64 -Px86_64 -MObjFPC -Sh -O2 -gl
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

clean:
	rm -rf $(BUILD_DIR)
```

**Step 4: 验证编译**

Run: `make -C core/tests/nextpas.core.platform/test_platform_io_windows_real build`
Expected: 编译成功，生成 Win64 EXE

**Step 5: 提交**

```bash
git add core/tests/nextpas.core.platform/test_platform_io_windows_real/
git commit -m "feat(platform): add test_platform_io_windows_real — 10 tests for platform.io on real Windows"
```

---

## Phase 2: platform.socket Windows Real 测试

### Task 2: 创建 test_platform_socket_windows_real 测试框架

**Files:**
- Create: `core/tests/nextpas.core.platform/test_platform_socket_windows_real/test_platform_socket_windows_real.lpr`
- Create: `core/tests/nextpas.core.platform/test_platform_socket_windows_real/Makefile`

**Step 1: 创建目录结构**

```bash
mkdir -p core/tests/nextpas.core.platform/test_platform_socket_windows_real
```

**Step 2: 编写 test_platform_socket_windows_real.lpr**

测试用例列表（16 个）:

```pascal
program test_platform_socket_windows_real;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.platform.socket;

var
  T: TTestRunner;

procedure TestTcpBindSpecificPort;
var
  LSock: TPlatformSocket;
  LRet: Int32;
begin
  LSock := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  Check(LSock <> nil, 'socket_create should succeed');
  LRet := platform_socket_bind(LSock, '127.0.0.1', 18765);
  Check(LRet = 0, 'bind should succeed');
  platform_socket_close(LSock);
end;

procedure TestTcpListenBacklog;
var
  LSock: TPlatformSocket;
  LRet: Int32;
begin
  LSock := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  Check(LSock <> nil, 'socket_create should succeed');
  platform_socket_bind(LSock, '127.0.0.1', 18766);
  LRet := platform_socket_listen(LSock, 16);
  Check(LRet = 0, 'listen should succeed');
  platform_socket_close(LSock);
end;

procedure TestAcceptReturnsClient;
var
  LServer, LClient, LAccepted: TPlatformSocket;
  LRet: Int32;
begin
  LServer := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  Check(LServer <> nil, 'server socket should create');
  platform_socket_bind(LServer, '127.0.0.1', 18767);
  platform_socket_listen(LServer, 4);
  LClient := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  Check(LClient <> nil, 'client socket should create');
  platform_socket_connect(LClient, '127.0.0.1', 18767);
  LAccepted := platform_socket_accept(LServer);
  Check(LAccepted <> nil, 'accept should return client socket');
  platform_socket_close(LAccepted);
  platform_socket_close(LClient);
  platform_socket_close(LServer);
end;

procedure TestFullTcpRoundtrip;
var
  LServer, LClient, LAccepted: TPlatformSocket;
  LBuf: array[0..63] of AnsiChar;
  LRet: Int32;
begin
  LServer := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  platform_socket_bind(LServer, '127.0.0.1', 18768);
  platform_socket_listen(LServer, 4);
  LClient := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  platform_socket_connect(LClient, '127.0.0.1', 18768);
  LAccepted := platform_socket_accept(LServer);
  Check(LAccepted <> nil, 'accept should succeed');

  // 客户端发送
  LRet := platform_socket_send(LClient, 'Hello, World!', 13);
  Check(LRet > 0, 'send should succeed');

  // 服务端接收
  LRet := platform_socket_recv(LAccepted, @LBuf, 64);
  Check(LRet > 0, 'recv should succeed');

  platform_socket_close(LAccepted);
  platform_socket_close(LClient);
  platform_socket_close(LServer);
end;

procedure TestShutdownRdwr;
var
  LSock: TPlatformSocket;
  LRet: Int32;
begin
  LSock := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  Check(LSock <> nil, 'socket_create should succeed');
  LRet := platform_socket_shutdown(LSock, SHUT_RDWR);
  Check(LRet = 0, 'shutdown should succeed');
  platform_socket_close(LSock);
end;

procedure TestSetsockoptKeepalive;
var
  LSock: TPlatformSocket;
  LRet: Int32;
begin
  LSock := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  Check(LSock <> nil, 'socket_create should succeed');
  LRet := platform_socket_setsockopt(LSock, SOL_SOCKET, SO_KEEPALIVE, 1);
  Check(LRet = 0, 'setsockopt SO_KEEPALIVE should succeed');
  platform_socket_close(LSock);
end;

procedure TestSetsockoptNodelay;
var
  LSock: TPlatformSocket;
  LRet: Int32;
begin
  LSock := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  Check(LSock <> nil, 'socket_create should succeed');
  LRet := platform_socket_setsockopt(LSock, IPPROTO_TCP, TCP_NODELAY, 1);
  Check(LRet = 0, 'setsockopt TCP_NODELAY should succeed');
  platform_socket_close(LSock);
end;

procedure TestSetsockoptRcvtimeo;
var
  LSock: TPlatformSocket;
  LRet: Int32;
begin
  LSock := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  Check(LSock <> nil, 'socket_create should succeed');
  LRet := platform_socket_set_timeout(LSock, 1000, 0);
  Check(LRet = 0, 'set_timeout should succeed');
  platform_socket_close(LSock);
end;

procedure TestSetsockoptSndtimeo;
var
  LSock: TPlatformSocket;
  LRet: Int32;
begin
  LSock := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  Check(LSock <> nil, 'socket_create should succeed');
  LRet := platform_socket_set_timeout(LSock, 0, 1000);
  Check(LRet = 0, 'set_timeout should succeed');
  platform_socket_close(LSock);
end;

procedure TestGetSocknameAfterBind;
var
  LSock: TPlatformSocket;
  LHost: string;
  LPort: UInt16;
  LRet: Int32;
begin
  LSock := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  Check(LSock <> nil, 'socket_create should succeed');
  platform_socket_bind(LSock, '127.0.0.1', 18769);
  LRet := platform_socket_getsockname(LSock, LHost, LPort);
  Check(LRet = 0, 'getsockname should succeed');
  Check(LHost = '127.0.0.1', 'host should be 127.0.0.1');
  Check(LPort = 18769, 'port should be 18769');
  platform_socket_close(LSock);
end;

procedure TestGetPeernameAfterConnect;
var
  LServer, LClient: TPlatformSocket;
  LHost: string;
  LPort: UInt16;
  LRet: Int32;
begin
  LServer := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  platform_socket_bind(LServer, '127.0.0.1', 18770);
  platform_socket_listen(LServer, 4);
  LClient := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  platform_socket_connect(LClient, '127.0.0.1', 18770);
  LRet := platform_socket_getpeername(LClient, LHost, LPort);
  Check(LRet = 0, 'getpeername should succeed');
  Check(LHost = '127.0.0.1', 'host should be 127.0.0.1');
  platform_socket_close(LClient);
  platform_socket_close(LServer);
end;

procedure TestUdpSendtoRecvfrom;
var
  LSock1, LSock2: TPlatformSocket;
  LBuf: array[0..63] of AnsiChar;
  LRet: Int32;
begin
  LSock1 := platform_socket_create(AF_INET, DGRAM, IPPROTO_UDP);
  LSock2 := platform_socket_create(AF_INET, DGRAM, IPPROTO_UDP);
  Check((LSock1 <> nil) and (LSock2 <> nil), 'UDP sockets should create');
  platform_socket_bind(LSock2, '127.0.0.1', 18771);
  LRet := platform_socket_sendto(LSock1, 'UDP Test', 8, '127.0.0.1', 18771);
  Check(LRet > 0, 'sendto should succeed');
  LRet := platform_socket_recvfrom(LSock2, @LBuf, 64, LHost, LPort);
  Check(LRet > 0, 'recvfrom should succeed');
  platform_socket_close(LSock2);
  platform_socket_close(LSock1);
end;

procedure TestResolveIpv4InvalidHost;
var
  LAddr: TPlatformSocketAddress;
  LRet: Int32;
begin
  LRet := platform_socket_resolve_ipv4('this.is.invalid.hostname.xyz', LAddr);
  Check(LRet <> 0, 'invalid hostname should fail');
end;

procedure TestSetNonblockingTrue;
var
  LSock: TPlatformSocket;
  LRet: Int32;
begin
  LSock := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  Check(LSock <> nil, 'socket_create should succeed');
  LRet := platform_socket_set_nonblocking(LSock, True);
  Check(LRet = 0, 'set_nonblocking(true) should succeed');
  platform_socket_close(LSock);
end;

procedure TestSetNonblockingFalse;
var
  LSock: TPlatformSocket;
  LRet: Int32;
begin
  LSock := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  Check(LSock <> nil, 'socket_create should succeed');
  platform_socket_set_nonblocking(LSock, True);
  LRet := platform_socket_set_nonblocking(LSock, False);
  Check(LRet = 0, 'set_nonblocking(false) should succeed');
  platform_socket_close(LSock);
end;

procedure TestErrorWouldBlock;
var
  LSock: TPlatformSocket;
  LRet: Int32;
begin
  LSock := platform_socket_create(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  Check(LSock <> nil, 'socket_create should succeed');
  platform_socket_set_nonblocking(LSock, True);
  LRet := platform_socket_recv(LSock, nil, 0);
  Check(LRet < 0, 'recv on non-blocking empty socket should return error');
  Check(platform_socket_error_would_block(LSock), 'should be would_block error');
  platform_socket_close(LSock);
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.socket.windows_real');
  T.Run('tcp_bind_specific_port', @TestTcpBindSpecificPort);
  T.Run('tcp_listen_backlog', @TestTcpListenBacklog);
  T.Run('accept_returns_client', @TestAcceptReturnsClient);
  T.Run('full_tcp_roundtrip', @TestFullTcpRoundtrip);
  T.Run('shutdown_rdwr', @TestShutdownRdwr);
  T.Run('setsockopt_keepalive', @TestSetsockoptKeepalive);
  T.Run('setsockopt_nodelay', @TestSetsockoptNodelay);
  T.Run('setsockopt_rcvtimeo', @TestSetsockoptRcvtimeo);
  T.Run('setsockopt_sndtimeo', @TestSetsockoptSndtimeo);
  T.Run('getsockname_after_bind', @TestGetSocknameAfterBind);
  T.Run('getpeername_after_connect', @TestGetPeernameAfterConnect);
  T.Run('udp_sendto_recvfrom', @TestUdpSendtoRecvfrom);
  T.Run('resolve_ipv4_invalid_host', @TestResolveIpv4InvalidHost);
  T.Run('set_nonblocking_true', @TestSetNonblockingTrue);
  T.Run('set_nonblocking_false', @TestSetNonblockingFalse);
  T.Run('error_would_block', @TestErrorWouldBlock);
  T.Summary;
end.
```

**Step 3: 创建 Makefile**

```makefile
FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.platform/test_platform_socket_windows_real
PROGRAM := test_platform_socket_windows_real
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -Twin64 -Px86_64 -MObjFPC -Sh -O2 -gl
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src

.PHONY: build run test clean

build:
	@mkdir -p $(BUILD_DIR)
	$(FPC) $(FPC_FLAGS) $(SOURCE)

run: build
	$(BUILD_DIR)/$(PROGRAM)

test: run

clean:
	rm -rf $(BUILD_DIR)
```

**Step 4: 验证编译**

Run: `make -C core/tests/nextpas.core.platform/test_platform_socket_windows_real build`
Expected: 编译成功，生成 Win64 EXE

**Step 5: 提交**

```bash
git add core/tests/nextpas.core.platform/test_platform_socket_windows_real/
git commit -m "feat(platform): add test_platform_socket_windows_real — 16 tests for platform.socket on real Windows"
```

---

## Phase 3: 集成到 Real Windows CI

### Task 3: 更新 platform-windows-focused-smoke.sh

**Files:**
- Modify: `core/scripts/platform-windows-focused-smoke.sh`

**Step 1: 添加 --windows-real-only 选项**

在脚本中添加 `--windows-real-only` 选项，只运行 Real Windows 必需的测试：
- test_platform_io_windows_real
- test_platform_socket_windows_real
- test_reactor_iocp_wine（扩展）

**Step 2: 提交**

```bash
git add core/scripts/platform-windows-focused-smoke.sh
git commit -m "feat(platform): add --windows-real-only option for Real Windows CI"
```

---

## 验证清单

- [ ] test_platform_io_windows_real 编译通过（Win64）
- [ ] test_platform_socket_windows_real 编译通过（Win64）
- [ ] Real Windows VM SSH 连接可用
- [ ] 部署到 VM 并运行测试
- [ ] 所有 26 个测试用例在 Real Windows 上通过
- [ ] 内存泄漏检测通过（-gh 编译）
- [ ] 更新 goal-tree.md 记录 Real Windows 测试状态

## 预计工作量

| Task | 测试用例数 | 预计时间 |
|------|----------|---------|
| Task 1: platform.io Windows Real | 10 | 1-2 小时 |
| Task 2: platform.socket Windows Real | 16 | 1-2 小时 |
| Task 3: CI 集成 | - | 30 分钟 |
| **总计** | **26** | **3-4 小时** |