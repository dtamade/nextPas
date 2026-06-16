# Phase 3 Hazard Pointer 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现 Hazard Pointer 内存回收方案，与 EBR 互补。

**Architecture:** L0 lockfree 子模块，复用 EBR 的 TLockFreeReclaimProc 类型。

**Tech Stack:** FreePascal 3.3.1, Linux x86_64, 原子操作

---

## 设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| HP 数组大小 | 2 (默认) | Michael 经典论文默认值 |
| 线程注册 | 手动 Register/Unregister | 避免 TLS 依赖（L0 约束） |
| 退休链表 | 无锁 (Treiber stack) | 与 EBR 风格一致 |
| 回收阈值 | batch_size=10 | 平衡延迟和吞吐 |
| 类型共享 | 复用 EBR 的 TLockFreeReclaimProc | 减少重复定义 |

## API 设计

```pascal
type
  THazardDomain = class
  public
    constructor Create(const AHPCount: PtrUInt = 2);
    destructor Destroy; override;
    
    // 线程注册/注销
    function RegisterThread: PtrUInt;  // 返回线程 ID
    procedure UnregisterThread(const AThreadId: PtrUInt);
    
    // Hazard Pointer 操作
    function Protect(const AThreadId: PtrUInt; const AHPIndex: PtrUInt; const APtr: Pointer): Pointer;
    procedure Clear(const AThreadId: PtrUInt; const AHPIndex: PtrUInt);
    
    // 退休与回收
    procedure Retire(AData: Pointer; AReclaim: TLockFreeReclaimProc; AUserData: Pointer = nil);
    procedure Collect(const AThreadId: PtrUInt);
    
    // 查询
    function ActiveThreads: PtrUInt;
    function RetiredCount: PtrUInt;
  end;
```

## 实现结构

```
nextpas.core.lockfree.hazard.pas
  interface:
    THazardThreadRec - 每线程记录 (HP 数组 + 退休链表)
    THazardDomain - 全局管理
  implementation:
    - RegisterThread: CAS 插入线程链表
    - Protect: 存储指针 + memory barrier
    - Retire: 推入退休栈 + 批量触发 Collect
    - Collect: 扫描 HP 数组 + 回收孤儿指针
```

## 测试策略

1. 基础: Protect/Clear 配对
2. 回收: Retire → Collect 正确调用 reclaim
3. 保护: Protected pointer 不被回收
4. 多线程: 2 线程并发 protect/retire
5. 边界: RegisterThread/UnregisterThread 配对
6. 泄漏: 所有路径验证 0 泄漏

## 执行步骤

### Step 1: 创建 hazard.pas 骨架
- 类型定义
- 构造函数/Destructor

### Step 2: 实现 RegisterThread/UnregisterThread
- 线程链表 CAS 操作

### Step 3: 实现 Protect/Clear
- 带 memory barrier 的指针存储

### Step 4: 实现 Retire
- 退休栈推送
- 批量阈值触发 Collect

### Step 5: 实现 Collect
- 收集所有活跃 HP
- 遍历退休栈，回收不在 HP 中的指针

### Step 6: 门面集成
- lockfree.pas 添加 re-export
- lockfree facade 添加 THazardDomain 类型别名

### Step 7: 测试
- 基础功能测试 (5 个)
- 并发测试 (2 个)
- 泄漏验证

### Step 8: 基准
- HP vs EBR 性能对比

## 验证命令

```bash
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test
```
