# Platform API 一致性改进计划

**日期**: 2026-07-06
**目标**: 提升接口设计、调用一致性、边界条件防护评分从 8.0 到 8.5

---

## 1. 接口设计改进

### 1.1 缓冲区参数命名统一

**当前问题**:
- `ACount` (file_read/write) - 表示字节数
- `ALen` (socket_send/recv) - 表示字节数
- `ABufLen` (args, dl, readlink) - 表示缓冲区大小
- `ASize` (file_getcwd) - 表示缓冲区大小

**改进方案**:
- `ASize`: 表示缓冲区大小（字节）
- `ALen`: 表示数据长度（字节）
- `ACount`: 表示元素个数

**影响范围**:
- `platform_file_read/write`: `ACount` → `ALen`
- `platform_socket_send/recv`: `ALen` 保持不变
- `platform_args_get`: `ABufLen` → `ABufSize`
- `platform_dl_error`: `ABufLen` → `ABufSize`

### 1.2 返回值语义一致性

**当前问题**:
- 大多数返回 `Int32` 错误码
- 有些返回 `Boolean` (如 `platform_dir_read`)
- 有些返回 `Pointer` (如 `platform_aligned_alloc`)

**改进方案**:
- 保持现有设计，因为这是 L0 层的合理设计
- 在文档中明确说明返回值约定

---

## 2. 调用一致性改进

### 2.1 参数顺序统一

**当前模式**:
- 文件操作: `(handle, buf, len, out bytes)`
- Socket操作: `(socket, buf, len, flags, out sent)`

**改进方案**:
- 保持现有模式，因为 socket 需要 flags 参数
- 在文档中说明参数顺序约定

### 2.2 命名风格一致性

**当前状态**: ✅ 已经一致
- 所有函数使用 `platform_` 前缀
- 所有类型使用 `TPlatform` 前缀
- 所有常量使用 `PLATFORM_` 前缀

---

## 3. 边界条件防护改进

### 3.1 nil guard 覆盖率提升

**当前状态**: 277 处 nil 检查

**需要添加 nil guard 的函数**:
1. `platform_file_read/write` - ABuf 参数
2. `platform_socket_send/recv` - ABuf 参数
3. `platform_console_read/write` - ABuf 参数
4. `platform_pipe_create` - APipe 参数 (var, 但需要初始化检查)

### 3.2 参数验证增强

**需要添加验证的函数**:
1. `platform_aligned_alloc` - ✅ 已有验证
2. `platform_file_seek` - AWhence 参数范围检查
3. `platform_socket_create` - ADomain/AType 参数范围检查

---

## 4. 实施步骤

### Phase 1: 缓冲区参数命名统一 (1h)
1. 修改 `platform_file_read/write` 的 `ACount` → `ALen`
2. 修改 `platform_args_get` 的 `ABufLen` → `ABufSize`
3. 修改 `platform_dl_error` 的 `ABufLen` → `ABufSize`
4. 更新相关测试

### Phase 2: nil guard 补全 (2h)
1. 为 `platform_file_read/write` 添加 ABuf nil 检查
2. 为 `platform_socket_send/recv` 添加 ABuf nil 检查
3. 为 `platform_console_read/write` 添加 ABuf nil 检查
4. 更新相关测试

### Phase 3: 参数验证增强 (1h)
1. 为 `platform_file_seek` 添加 AWhence 范围检查
2. 为 `platform_socket_create` 添加参数范围检查
3. 更新相关测试

### Phase 4: 文档更新 (30m)
1. 更新 API 参考文档
2. 更新 QUICKSTART.md 中的示例
3. 更新 USABILITY-ASSESSMENT.md 评分

---

## 5. 预期效果

| 维度 | 改进前 | 改进后 | 变化 |
|------|--------|--------|------|
| 接口设计 | 8.0 | 8.5 | +0.5 |
| 调用一致性 | 8.0 | 8.5 | +0.5 |
| 边界条件防护 | 8.0 | 8.5 | +0.5 |
| **总分** | **8.33** | **8.56** | **+0.23** |

---

**批准**: 待用户确认
