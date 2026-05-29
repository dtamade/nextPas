#!/usr/bin/env python3
"""
批量编译fafafa.ssl所有核心模块
用于验证Linux环境下的编译兼容性
"""

import os
import argparse
import subprocess
import sys
import tempfile
import shutil
from pathlib import Path

# 项目根目录
PROJECT_ROOT = Path(__file__).parent.parent.resolve()
SRC_DIR = PROJECT_ROOT / "src"

DEFAULT_FPC_EXE = os.environ.get("FAFAFA_FPC_EXE", "fpc")
DEFAULT_FPC_UNITS_BASE = os.environ.get("FAFAFA_FPC_UNITS_BASE", "")
FPC_UNIT_SUBDIRS = [
    "rtl-objpas",
    "rtl",
    "rtl-unix",
    "rtl-extra",
    "fcl-base",
    "fcl-json",
    "fcl-process",
    "pthreads",
]

def resolve_fpc_units_base(raw_base):
    """解析 FPC 单元根目录（支持 CLI 覆盖和环境变量默认）"""
    candidate = (raw_base or "").strip()
    if candidate:
        return Path(candidate).expanduser()

    env_base = DEFAULT_FPC_UNITS_BASE.strip()
    if env_base:
        return Path(env_base).expanduser()

    return Path.home() / "freePascal" / "fpc" / "units" / "x86_64-linux"

def build_unit_paths(fpc_units_base):
    """构建待尝试注入的单元搜索路径列表"""
    paths = [Path(fpc_units_base) / subdir for subdir in FPC_UNIT_SUBDIRS]
    paths.append(PROJECT_ROOT / "src")
    return paths

# FPC单元路径配置（默认）
FPC_BASE = resolve_fpc_units_base("")
UNIT_PATHS = build_unit_paths(FPC_BASE)

# 排除的文件（WinSSL在Linux上无法编译）
EXCLUDE_PATTERNS = [
    "nextpas.core.tls.winssl",  # Windows专用
    "rand_old.pas",        # 已废弃
    "nextpas.core.tls.http.simple",  # 依赖 socket/HTTP 示例，非核心单元
]

def should_compile(file_path):
    """判断文件是否应该编译"""
    file_name = file_path.name
    
    # 排除特定模式
    for pattern in EXCLUDE_PATTERNS:
        if pattern in file_name:
            return False
    
    # 只编译.pas文件
    return file_path.suffix == ".pas"

def build_fpc_command(pas_file, rebuild, unit_output_dir, unit_paths=None, fpc_exe=DEFAULT_FPC_EXE):
    """构建单个模块的 FPC 编译命令"""
    # 构建FPC命令
    resolved_fpc_exe = str(fpc_exe).strip() or "fpc"
    cmd = [resolved_fpc_exe]

    if rebuild:
        cmd.append("-B")

    resolved_unit_paths = UNIT_PATHS if unit_paths is None else unit_paths

    # 添加单元路径
    for unit_path in resolved_unit_paths:
        unit_path = Path(unit_path)
        if unit_path.exists():
            cmd.append(f"-Fu{unit_path}")

    # 隔离单元输出目录，避免并发编译任务写入同一产物路径
    cmd.append(f"-FU{unit_output_dir}")
    
    # 语法模式和其他选项
    cmd.extend([
        "-Mobjfpc",     # ObjFPC模式
        "-Scgi",        # 语法选项
        "-O2",          # 优化级别
        "-g",           # 调试信息
        "-gl",          # 使用行号信息
        "-vewnhi",      # 详细错误信息
        str(pas_file)   # 源文件
    ])
    return cmd

def build_module_unit_output_dir(root_unit_output_dir, pas_file):
    """为单个模块构造隔离的 -FU 子目录。"""
    try:
        module_rel = pas_file.relative_to(SRC_DIR)
        module_name = module_rel.with_suffix('').as_posix()
    except ValueError:
        module_name = pas_file.with_suffix('').name

    module_unit_output_dir = Path(root_unit_output_dir) / module_name.replace('/', '__')
    module_unit_output_dir.mkdir(parents=True, exist_ok=True)
    return module_unit_output_dir

def compile_module(pas_file, rebuild, timeout_seconds, unit_output_dir, unit_paths=None, fpc_exe=DEFAULT_FPC_EXE):
    """编译单个模块"""
    module_unit_output_dir = build_module_unit_output_dir(unit_output_dir, pas_file)
    cmd = build_fpc_command(
        pas_file,
        rebuild,
        module_unit_output_dir,
        unit_paths=unit_paths,
        fpc_exe=fpc_exe,
    )

    try:
        result = subprocess.run(
            cmd,
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            timeout=timeout_seconds
        )
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", f"Compilation timeout after {timeout_seconds}s"
    except Exception as e:
        return False, "", str(e)

def resolve_unit_output_dir(raw_dir):
    """解析并准备 FPC 单元输出目录"""
    if raw_dir:
        unit_dir = Path(raw_dir)
        if not unit_dir.is_absolute():
            unit_dir = (PROJECT_ROOT / unit_dir).resolve()
        unit_dir.mkdir(parents=True, exist_ok=True)
        return unit_dir, False

    tmp_root = PROJECT_ROOT / "tmp"
    tmp_root.mkdir(parents=True, exist_ok=True)
    unit_dir = Path(tempfile.mkdtemp(prefix="compile_all_modules_units_", dir=str(tmp_root)))
    return unit_dir, True

def main():
    """主函数"""
    parser = argparse.ArgumentParser(description="批量编译 fafafa.ssl 核心模块")
    parser.add_argument(
        "--rebuild",
        action="store_true",
        help="使用 fpc -B 强制全量重编译（用于规避增量产物导致的链接/调试符号不一致）",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=120,
        help="单文件编译超时时间（秒，默认: 120）",
    )
    parser.add_argument(
        "--unit-output-dir",
        type=str,
        default="",
        help="指定 FPC 单元输出目录（-FU）；默认自动创建临时隔离目录",
    )
    parser.add_argument(
        "--keep-unit-output-dir",
        action="store_true",
        help="保留自动创建的临时单元输出目录（便于排查编译问题）",
    )
    parser.add_argument(
        "--fpc-exe",
        type=str,
        default="",
        help="指定 FPC 可执行文件（默认读取 FAFAFA_FPC_EXE 或 fpc）",
    )
    parser.add_argument(
        "--fpc-units-base",
        type=str,
        default="",
        help="指定 FPC 单元根目录（默认读取 FAFAFA_FPC_UNITS_BASE 或 ~/freePascal/...）",
    )
    parser.add_argument(
        "--warn-limit",
        type=int,
        default=0,
        help="编译警告数上限；超过此值视为失败（0=不限制，默认: 0）",
    )
    args = parser.parse_args()

    if args.timeout <= 0:
        print("[FAIL] --timeout must be a positive integer")
        return 1

    fpc_exe = (args.fpc_exe or DEFAULT_FPC_EXE).strip() or "fpc"
    fpc_units_base = resolve_fpc_units_base(args.fpc_units_base)
    unit_paths = build_unit_paths(fpc_units_base)

    unit_output_dir = None
    unit_output_is_temp = False

    try:
        unit_output_dir, unit_output_is_temp = resolve_unit_output_dir(args.unit_output_dir)

        print("=" * 60)
        print("fafafa.ssl 批量编译测试 - Linux环境")
        print("=" * 60)
        print(f"FPC executable: {fpc_exe}")
        print(f"FPC units base: {fpc_units_base}")
        print(f"FPC unit output dir: {unit_output_dir}")
        print()
        
        # 收集所有.pas文件
        all_files = list(SRC_DIR.glob("**/*.pas"))
        compile_files = [f for f in all_files if should_compile(f)]
        
        print(f"发现 {len(all_files)} 个.pas文件")
        print(f"将编译 {len(compile_files)} 个核心模块")
        print(f"跳过 {len(all_files) - len(compile_files)} 个文件 (WinSSL/deprecated)")
        print()
        
        # 编译统计
        success_count = 0
        failed_count = 0
        failed_files = []
        total_warnings = 0
        warning_categories = {}  # category -> count

        # 逐个编译
        for i, pas_file in enumerate(compile_files, 1):
            rel_path = pas_file.relative_to(SRC_DIR)
            print(f"[{i}/{len(compile_files)}] 编译 {rel_path}...", end=" ")

            success, stdout, stderr = compile_module(
                pas_file,
                args.rebuild,
                args.timeout,
                unit_output_dir,
                unit_paths=unit_paths,
                fpc_exe=fpc_exe,
            )
            
            if success:
                print("✓ 成功")
                success_count += 1
                # 统计警告
                warn_lines = [l for l in (stdout + stderr).split('\n') if 'Warning:' in l]
                total_warnings += len(warn_lines)
                for wl in warn_lines:
                    # 提取警告类型（如 "Symbol deprecated", "Function result variable" 等）
                    cat = wl.split('Warning:', 1)[-1].strip().split()[0] if 'Warning:' in wl else 'other'
                    warning_categories[cat] = warning_categories.get(cat, 0) + 1
            else:
                print("✗ 失败")
                failed_count += 1
                failed_files.append((rel_path, stderr))
        
        # 输出摘要
        print()
        print("=" * 60)
        print("编译摘要")
        print("=" * 60)
        print(f"总文件数: {len(compile_files)}")
        print(f"编译成功: {success_count} ({success_count/len(compile_files)*100:.1f}%)")
        print(f"编译失败: {failed_count} ({failed_count/len(compile_files)*100:.1f}%)")
        print(f"编译警告: {total_warnings}")
        if warning_categories:
            top_warnings = sorted(warning_categories.items(), key=lambda x: -x[1])[:5]
            for cat, cnt in top_warnings:
                print(f"  - {cat}: {cnt}")
        print()
        
        # 显示失败文件
        if failed_files:
            print("失败的文件:")
            for file_path, error in failed_files[:10]:  # 只显示前10个
                print(f"  - {file_path}")
                # 提取关键错误信息
                error_lines = [line for line in error.split('\n') if 'Error:' in line or 'Fatal:' in line]
                for line in error_lines[:3]:
                    print(f"    {line.strip()}")
            
            if len(failed_files) > 10:
                print(f"  ... 还有 {len(failed_files) - 10} 个失败文件")
        
        # 检查是否达标
        success_rate = success_count / len(compile_files) * 100
        target_rate = 100.0
        
        print()
        result_code = 0

        if success_rate >= target_rate:
            print(f"✅ 编译成功率 {success_rate:.1f}% 达到目标 ({target_rate}%)")
        else:
            print(f"⚠️  编译成功率 {success_rate:.1f}% 未达到目标 ({target_rate}%)")
            result_code = 1

        if args.warn_limit > 0:
            if total_warnings <= args.warn_limit:
                print(f"✅ 编译警告数 {total_warnings} 在限制内 ({args.warn_limit})")
            else:
                print(f"⚠️  编译警告数 {total_warnings} 超过限制 ({args.warn_limit})")
                result_code = 1

        return result_code
    finally:
        if (
            unit_output_dir is not None
            and unit_output_is_temp
            and (not args.keep_unit_output_dir)
            and unit_output_dir.exists()
        ):
            shutil.rmtree(unit_output_dir, ignore_errors=True)

if __name__ == "__main__":
    sys.exit(main())
