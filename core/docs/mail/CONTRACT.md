# nextpas.core.mail 代码契约

**模块路径**：`core/src/nextpas.core.mail*.pas`
**层级**：L3（依赖 L0-L2: net, tls, text, collections）
**Owner**：待定
**最后更新**：2026-07-06
**版本**：0.1（规划阶段）

---

## 1. 接口契约

### 1.1 核心接口

```pascal
IMailClient = interface
  function Connect(const AHost: string; APort: UInt16): Boolean;
  function Login(const AUsername, APassword: string): Boolean;
  function Send(const AMessage: TMailMessage): Boolean;
  procedure Disconnect;
  function GetLastError: string;
end;

IMailMessage = interface
  procedure SetFrom(const AAddress: string);
  procedure AddTo(const AAddress: string);
  procedure AddCc(const AAddress: string);
  procedure SetSubject(const ASubject: string);
  procedure SetBody(const ABody: string);
  procedure AddAttachment(const AFileName: string; const AData: TBytes);
end;

TMailMessage = record
  From: string;
  ToList: array of string;
  CcList: array of string;
  Subject: string;
  Body: string;
  Attachments: array of TMailAttachment;
end;

TMailAttachment = record
  FileName: string;
  ContentType: string;
  Data: TBytes;
end;
```

### 1.2 协议支持

| 协议 | 用途 | 端口 |
|------|------|------|
| SMTP | 发送邮件 | 25/465/587 |
| IMAP | 接收邮件 | 143/993 |
| POP3 | 接收邮件 | 110/995 |

---

## 2. 不变量

- **[INV-1]** 连接状态机：Disconnected → Connected → Authenticated → Sending
- **[INV-2]** 每次 Send 操作原子性：全部成功或全部失败
- **[INV-3]** 附件大小不超过服务器限制（可配置）
- **[INV-4]** 邮件地址格式验证（RFC 5322）

---

## 3. 错误处理

| 场景 | 异常类型 |
|------|----------|
| 连接失败 | EConnectionError |
| 认证失败 | EAuthenticationError |
| 发送失败 | ESendError |
| 协议错误 | EProtocolError |

---

## 4. 线程安全

- **IMailClient**: ❌ 非线程安全，每次连接独立实例
- **TMailMessage**: 值类型，线程安全

---

## 5. 内存管理

- TMailMessage 为 record，栈分配
- 附件数据 TBytes 由调用方管理生命周期
- 连接内部缓冲区自动释放

---

## 6. 测试策略

- 单元测试：协议解析、地址验证、消息构建
- 集成测试：本地 SMTP 服务器（可选）
- 契约测试：接口不变量验证

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-06 | 0.1 | 初始规划版本 | Claude |
