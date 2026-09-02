# Graphics 图像编解码补齐计划 — Web五件套双轨

**目标**：`png/jpeg/webp/gif/bmp` 全量 `Probe+FFI+Pure+Loader` 双后端，`QOI` 追加，`bench_image` 固化，守 L0-L3/四件套/owner

## 任务 DAG

| id | title | dependencies | 验收 |
|---|---|---|---|
| gif-pure | GIF 纯Pas首帧（GIF87a/89a Probe, LZW 256色, TryImageDecode不抛） |  | `image.gif.pas` + `test_image_gif` Probe 3 case |
| jpeg-pure | JPEG 纯Pas基线（DCT/Huffman Baseline, 复用 simd） |  | `image.jpeg.pure.pas` 单文件 ≤600行 |
| webp-pure | WEBP 纯Pas VP8L子集（RIFF/WEBP Probe） |  | `image.webp.pure.pas` + FFI 回退 |
| qoi | QOI 纯Pas（<300行, 零依赖） |  | `image.qoi.pas` Encode/Decode 互转 |
| image-dispatch-integrate | 调度集成+文档+Bench收口（dispatch注册、CONTRACT 0.2.1、bench_image 1MB） | gif-pure, jpeg-pure, webp-pure, qoi | `image.dispatch` 注册4新格式, `bench --verify` |

> 解析约束：`id` 小写短横线，`dependencies` 为前置 `id` 数组，L2 `image.*` 只依 `L0-L1`，门面 `image.pas` 纯 re-export

## 执行层级
- L1 并行：`gif-pure, jpeg-pure, webp-pure, qoi` 无依赖同层
- L2 串行：`image-dispatch-integrate` 依赖前四

## 门禁
`HYGIENE 0 / G/I/C/V 0 / DEMO md5 27b73e0d9a765c491bee8c85b367cef2 / TryImageDecode不抛 / 16M Cap`
