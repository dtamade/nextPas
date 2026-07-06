 # 清除所有 PPU 缓存（stage0 输出目录 + rtl 源码目录的散落产物）
 rm -f "$OUT"/*.ppu "$OUT"/*.o
 rm -f "$ROOT"/rtl/core/base/*.ppu "$ROOT"/rtl/core/base/*.o
 rm -f "$ROOT"/rtl/core/text/*.ppu "$ROOT"/rtl/core/text/*.o
rm -f "$ROOT"/core/src/*.ppu "$ROOT"/core/src/*.o
