# nextpas.core.cookie 代码契约

**模块路径**：`core/src/nextpas.core.cookie*.pas`（2 个源文件）
**层级**：L2（依赖 L0: base, text）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：1.2

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| cookie.base | TCookie, TSetCookie 记录类型 |
| cookie.pas | Cookie 解析/序列化/匹配逻辑 |

### 1.2 核心类型

```pascal
TCookie = record
  Name: string;
  Value: string;
end;

TSetCookie = record
  Name: string;
  Value: string;
  Domain: string;
  Path: string;
  Expires: TInstant;
  MaxAge: Int64;
  HttpOnly: Boolean;
  Secure: Boolean;
  SameSite: string;
end;
```

### 1.3 核心函数

```pascal
function ParseCookies(const AHeader: string): TCookieArray;
function SetCookieToStr(const ACookie: TSetCookie): string;
function ParseSetCookie(const AHeader: string): TSetCookie;
```

---

## 2. 不变量

- Cookie 名称不含空格、分号、逗号
- Domain 以 `.` 开头表示通配域
- MaxAge > 0 表示持久 Cookie，= 0 表示删除

---

## 3. 错误处理

- 解析函数遇到格式错误返回空结果，不抛异常

---

## 4. 线程安全

- 纯函数式设计，无共享状态，线程安全

---

## 5. 内存管理

- 返回的记录和数组由调用方负责释放
- 所有字符串使用标准 Pascal 引用计数

---

## 6. 测试覆盖

- `test_cookie`: 8 测试，覆盖 Parse/SetCookie/Domain/Path/HttpOnly/Secure
