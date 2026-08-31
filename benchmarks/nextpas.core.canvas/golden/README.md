# Golden poster 512×256

- 生成：`examples/graphics/demo_vector_poster.lpr` → `PngEncodeRgba`（STRIDE 64 已紧凑化）
- 尺寸：512×256 RGBA，文件 `poster_512x256.png` 4350 bytes，`md5 1120e4a1c355a4f1d9b09638577a1d28`
- 容差：逐字节精确（det 渲染，无抗锯齿随机）；`test_golden` 允许容差 ≤1（为未来 AA 误差预留），当前 0。
- 刷新：`make -C benchmarks/nextpas.core.canvas golden` 或直接运行 demo_vector_poster 后 `cp /tmp/demo_poster.png golden/poster_512x256.png`。
- 关联：`core/docs/graphics/GOAL_TREE S2 golden` 门禁；`bench_raster` 与之联合保证性能不破画。
