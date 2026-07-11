# core-net-async-io 模块改进总结

> 完成时间：2026-07-11
> 分支：core-net-async-io
> 提交：a55882264

## 改进内容

### 1. 新增匿名过程和方法引用回调支持

#### 新增类型
```pascal
// 匿名过程引用
TAsyncCallbackRef = reference to procedure(AContext: Pointer);

// 方法指针
TAsyncCallbackMethod = procedure(AContext: Pointer) of object;

// I/O 完成回调引用
TIoCompletionRef = reference to procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer);
```

#### TAsyncLoop 新方法
- `PostRef` - 使用匿名过程发布跨线程回调
- `PostMethod` - 使用方法指针发布跨线程回调
- `ScheduleRef` - 使用匿名过程调度定时器
- `ScheduleMethod` - 使用方法指针调度定时器
- `AsyncSleepRef` - 使用匿名过程的异步睡眠
- `AsyncRecvRef` - 使用匿名过程的异步接收

#### TAsyncTask 新方法
- `OnCompleteRef` - 使用匿名过程的完成回调
- `OnCompleteMethod` - 使用方法指针的完成回调

#### TTimerHeap 新方法
- `ScheduleRef` / `ScheduleMethod` - 调度定时器
- `ScheduleAfterRef` / `ScheduleAfterMethod` - 延迟调度定时器

### 2. 内部实现改进

#### 引用计数类型安全复制
- 修复 `DrainPending` 中使用 `Move` 复制引用计数类型的问题
- 改为手动复制以正确维护引用计数

#### 灵活的回调存储
- `TAsyncPendingItem` 支持存储 Regular/Ref/Method 三种回调
- `TTimerEntry` 支持存储 Regular/Ref/Method 三种回调
- `TAsyncTask.TAsyncCallbackStorage` 支持存储三种回调

### 3. 测试更新

#### 新增测试
- `TestPostRefCallback` - 验证 PostRef 功能
- `TestPostMethodCallback` - 验证 PostMethod 功能
- `TestScheduleRefCallback` - 验证 ScheduleRef 功能
- `TestScheduleMethodCallback` - 验证 ScheduleMethod 功能
- `TestAsyncSleepRefCallback` - 验证 AsyncSleepRef 功能
- `TestAsyncRecvRefCallback` - 验证 AsyncRecvRef 功能
- `TestOnCompleteRefCallback` - 验证 OnCompleteRef 功能
- `TestOnCompleteMethodCallback` - 验证 OnCompleteMethod 功能

#### 更新测试
- `TestTimerCancelClearsOwnerRefsSourceContract` - 更新为检查新字段

### 4. 测试结果

```
43 passed, 1 failed, 0 skipped

失败测试（预期）：
- AsyncStressUsesCthreadsSourceContract - Unix 压力测试需要 pthreads

内存检查：
9265 memory blocks allocated : 3483177
9265 memory blocks freed     : 3483177
0 unfreed memory blocks : 0
```

## 技术细节

### 匿名过程实现
使用 FPC 的 `{$modeswitch anonymousfunctions}` 和 `{$modeswitch functionreferences}` 特性：
- 匿名过程通过引用计数管理生命周期
- 存储在记录字段中时自动增加引用计数
- 复制时需要手动处理以避免引用计数错误

### 包装器模式
对于 `AsyncRecvRef` 等需要将匿名过程传递给底层 API 的场景：
1. 在堆上分配上下文结构存储匿名过程
2. 创建普通过程包装器
3. 传递包装器给底层 API
4. 在回调中调用匿名过程并释放上下文

## 后续工作

### Phase 2: 架构增强
- 增强 AsyncLoop 与 Net 集成
- 添加异步 DNS 解析
- 完善连接池抽象
- 添加背压控制机制

### Phase 3: 高级特性
- 实现异步文件 I/O
- 添加 TLS 异步握手
- 实现 HTTP/2 异步流
- 性能基准测试

### Phase 4: 质量加固
- 压力测试套件
- 内存泄漏检测
- 线程安全审计
- API 稳定性评估
