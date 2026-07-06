# Phase 3 无锁 HashMap 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现分片锁 + 开放寻址的并发安全 HashMap。

**Architecture:** L0 lockfree 子模块，16 分片 + 每分片独立读写锁 + 开放寻址哈希表。

**Tech Stack:** FreePascal 3.3.1, Linux x86_64, 原子操作

---

## 设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 并发方案 | 分片锁 (16 shards) | 比全局锁吞吐高 10x+ |
| 哈希表 | 开放寻址 + 线性探测 | 比链地址法 cache 友好 |
| 分片选择 | hash(key) mod 16 | 简单高效 |
| 负载因子 | 0.75 触发扩容 | 业界标准 |
| TKey/TValue | 必须是非托管类型 | L0 约束 |
| 接口风格 | 简化版（无 iterator） | 避免生命周期复杂性 |

## API 设计

```pascal
type
  generic TLockFreeHashMap<TKey, TValue> = class
    constructor Create(const AInitialCapacity: PtrUInt = 16);
    destructor Destroy; override;
    procedure Insert(const AKey: TKey; const AValue: TValue);
    function Find(const AKey: TKey; out AValue: TValue): Boolean;
    function Remove(const AKey: TKey): Boolean;
    function Contains(const AKey: TKey): Boolean;
    function Count: PtrUInt;
  end;
```

## 文件

- Create: `core/src/nextpas.core.lockfree.hashmap.pas`
- Modify: `core/src/nextpas.core.lockfree.pas` (facade)
- Test: `core/tests/nextpas.core.lockfree/test_lockfree/test_lockfree.lpr`

## 测试策略

1. Insert/Find 基础
2. Insert 覆盖
3. Remove
4. Contains
5. Count
6. 扩容
7. 并发 4P Insert + Find
8. 0 泄漏

## 执行步骤

### Step 1: 创建 hashmap.pas
### Step 2: 集成到 facade
### Step 3: 添加 8 个测试
### Step 4: 运行完整测试套件
### Step 5: 提交
