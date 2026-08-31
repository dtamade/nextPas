PROGRAM := test_tui_clipboard_wine
# 断言 Windows 专属通道（cmWin32 检测/空拷贝拒绝），Linux 宿主编译必然误报；
# truth tier = wine-runtime-smoke（Win64 交叉 + Wine 运行），无 wine 时 skip。
WINE_ONLY_TEST := 1
include ../../common.mk
