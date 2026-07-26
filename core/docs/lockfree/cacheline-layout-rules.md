# Lockfree 缓存行布局与热路径法则

> 来源：2026-07-26 F-032～F-037 五轮修复的沉淀。bench 证据见
> `bench-results/2026-07-26-dtamade-f03*.md`；测量纪律见 `bench-envelope.md`。
> 新增或改动 lockfree 结构时，本文档是布局与热路径设计的检查单。

## 1. Pad 有效性 = pad 宽度 × 实例对齐保证（F-032）

FPC 堆只保证 8/16B 实例对齐（全库无 `NewInstance` 覆写），所以任何小于
一整行的 pad 都可能被基址相位抵消：24B 热组 + 32B pad = 56B 组间距，基址
mod 64 ∈ {16,32} 时两组仍落同一行——约一半堆摆放下 pad 完全失效。

**规则**：
- pad 一律用 `TCacheLinePad`（`array[0..7] of Int64`，整行 64B）。间隔 ≥64B
  时，任意基址对齐下两组不可能共享任何一行。
- 只读 header（`FSlots`/`FCapacity`/`FMask` 等每 op 必读字段）与首个热写
  字段之间必须有 `FPadHeader`，否则是无条件读侧伪共享。
- 手写 `array[0..N] of Byte` pad 一律视为缺陷（"Pad to 64" 注释不可信，
  8+48=56 到不了一行）。
- 128B pad（对抗相邻行预取器）是 bench 驱动的调优项，无数据不做。

## 2. 线程亲和分组法则（F-033）

字段按「访问线程」分组，不按「方向/语义」分组。

**每缓存行 = 一个线程每 op 写的全部字段**：

| 行 | 内容 |
|----|------|
| 生产者行 | own index + own published + 对端 cache + 自己 notify 的等待单元 |
| 消费者行 | 镜像 |
| 冷行 | `FClosed` 等 read-mostly 控制字，独立于任何热写行 |

要点：
- 等待单元（epoch + waiters）归 **notify 方**：notify 是每 op 潜在写。
- 对端 cache 字段归 **读它的线程**（如 `FHeadCache` 在生产者行）。
- 被所有线程每 op RMW 的字段不能与 read-mostly 字段同行（见 §5）。
- 参照：rigtorp SPSCQueue / folly ProducerConsumerQueue。

## 3. notify 守卫（F-034）

`LockFreeNotifyData/Space` 每次调用无条件 locked `atomic_fetch_add`（epoch
bump），约 6.5ns/次（Broadwell）。

**规则**：所有成功路径 notify 站点加守卫：

```pascal
{ Fast path: only notify if there are waiters }
if atomic_load(F*Waiters, mo_relaxed) > 0 then
  LockFreeNotify*(...);
```

错过唤醒窗口（waiter 在守卫读与返回之间注册）由阻塞循环的
`LOCKFREE_WAIT_TIMEOUT_NS`（10ms 有界超时）兜底——语义与既有守卫结构一致。
T1 全家（spsc/mpmc/channel/channel.spsc/spmc/bag）已对齐。

## 4. 对端位置缓存（F-036）

单侧结构（SPSC 型：该侧只有一个线程）每 op acquire 读对端 index 是每 op
一次必然 coherence miss。

**规则**：单侧结构必须带对端位置缓存（`FHeadCache`/`FTailCache` /
`FRecvCache`/`FSendCache` 模式）：缓存判满/判空失败才 acquire 刷新真值，
刷新后仍满/空才失败。刷新路径保持原 acquire 语义，可见性论证不变。
多侧（M 端）index 需 CAS 推进，缓存模式不适用。

`IsEmpty`/`ApproxLen` 等跨线程观察者读真实 published 位置，不走缓存。

## 5. 全线程共享计数器条带化（F-037）

被所有线程每 op RMW 的单一计数器（如 resize 守卫 `FActiveOperations`）
= 每 op 一次跨线程行 ping-pong，且 pad 帮不上忙（争用在字段本身）。

**规则**：拆成 `N`（2 的幂）个各占独立行的条带；线程用 **乘法哈希**
（乘奇常数取高位，`{$Q-}{$R-}` 包裹）选带——Linux pthread 描述符地址常按
8MB 等距分布，裸移位会系统性撞带。聚合方（如 `TryResize` 静默扫描）遍历
全部条带。

**正确性要点**：
- 条带索引在调用方算一次、显式传给 Enter/Leave 配对——两次独立重算若用
  栈地址类来源会因栈深不同减错条带，导致聚合方提前判定静默（use-after-free）。
- 静默论证与单计数器同构：聚合方先置标志再扫描，后来者 bump 条带后重读
  标志必回退；x86 上由 locked RMW 全栅栏闭合 Dekker 型 store-load 窗口。
  条带化不引入新的内存序假设。

## 6. 过程纪律

- **先加 bench 场景、在基线侧构建测量，再改源码**。drain 型 micro（99.9%
  走空路径）看不见成功路径成本，必须用稳态配对场景（每迭代必经被测代码）。
- **布局/字段改动后必须 clean 构建**：stale PPU 对 class 布局变化不健壮，
  增量构建可触发 FPC ICE（EAccessViolation）。
- **归因签名**：布局/缓存类改动单线程零成本——「跨线程场景大幅动 + 单线程
  micro 持平 + 未动结构对照持平」才是干净归因；单线程也大动说明测到了别的
  （代码布局漂移或环境污染）。
- **对照组兼作环境探测器**：未动过的结构出离群值 = 机器被外部负载污染，
  该批样本作废，等安静后重测。
- 绝对数字必须带 envelope（`bench-envelope.md`），声明需 N≥3 样本；after
  侧方差大时补样本，报中位数并披露全区间。
