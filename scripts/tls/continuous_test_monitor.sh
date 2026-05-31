#!/bin/bash

#############################################################################
# 持续测试监控脚本
#
# 功能：
# - 循环运行模块测试
# - 跟踪测试结果趋势
# - 生成历史报告
# - 失败时发送警报
#
# 用法：
#   ./scripts/continuous_test_monitor.sh [options]
#
# 选项：
#   --interval SECONDS    测试间隔（默认：3600秒/1小时）
#   --max-runs NUMBER     最大运行次数（默认：无限）
#   --alert-on-fail       失败时发送警报
#   --modules             指定要测试的模块（逗号分隔）
#############################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
REPORTS_DIR="$PROJECT_ROOT/test-reports"
MONITOR_DIR="$REPORTS_DIR/monitor"
HISTORY_FILE="$MONITOR_DIR/test_history.csv"
SUMMARY_FILE="$MONITOR_DIR/monitor_summary.txt"

# 默认选项
INTERVAL=3600  # 1 hour
MAX_RUNS=0     # 0 = infinite
ALERT_ON_FAIL=false
SPECIFIC_MODULES=""
RUN_COUNT=0

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --interval)
      INTERVAL="$2"
      shift 2
      ;;
    --max-runs)
      MAX_RUNS="$2"
      shift 2
      ;;
    --alert-on-fail)
      ALERT_ON_FAIL=true
      shift
      ;;
    --modules)
      SPECIFIC_MODULES="$2"
      shift 2
      ;;
    *)
      echo "未知选项: $1"
      exit 1
      ;;
  esac
done

# 创建监控目录
mkdir -p "$MONITOR_DIR"

# 初始化历史文件
if [ ! -f "$HISTORY_FILE" ]; then
  echo "timestamp,run_number,total_tests,passed,failed,skipped,pass_rate" > "$HISTORY_FILE"
fi

# 日志函数
log_info() {
  echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$SUMMARY_FILE"
}

log_success() {
  echo -e "${GREEN}[PASS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$SUMMARY_FILE"
}

log_error() {
  echo -e "${RED}[FAIL]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$SUMMARY_FILE"
}

log_warning() {
  echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$SUMMARY_FILE"
}

# 发送警报
send_alert() {
  local message=$1
  log_error "ALERT: $message"

  # 可以在这里添加其他警报机制：
  # - 发送邮件
  # - 发送 Slack 消息
  # - 发送系统通知

  # 系统通知（如果可用）
  if command -v notify-send &> /dev/null; then
    notify-send "测试失败警报" "$message"
  fi
}

# 运行测试
run_tests() {
  local run_number=$1

  log_info "========== 运行 #$run_number =========="

  # 构建测试命令
  local test_cmd="$SCRIPTS_DIR/run_all_module_tests.sh"
  if [ -n "$SPECIFIC_MODULES" ]; then
    test_cmd="$test_cmd --modules $SPECIFIC_MODULES"
  fi

  # 运行测试
  local test_output
  local test_exit_code

  if test_output=$($test_cmd 2>&1); then
    test_exit_code=0
  else
    test_exit_code=$?
  fi

  # 解析测试结果
  local total_tests=$(echo "$test_output" | grep "总测试数:" | awk '{print $2}')
  local passed=$(echo "$test_output" | grep "通过:" | awk '{print $2}')
  local failed=$(echo "$test_output" | grep "失败:" | awk '{print $2}')
  local skipped=$(echo "$test_output" | grep "跳过:" | awk '{print $2}')

  # 计算通过率
  local pass_rate=0
  if [ "$total_tests" -gt 0 ]; then
    pass_rate=$(awk "BEGIN {printf \"%.1f\", $passed * 100.0 / $total_tests}")
  fi

  # 记录到历史文件
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$timestamp,$run_number,$total_tests,$passed,$failed,$skipped,$pass_rate" >> "$HISTORY_FILE"

  # 显示结果
  log_info "测试结果: $passed/$total_tests 通过 ($pass_rate%)"

  # 检查是否需要发送警报
  if [ "$test_exit_code" -ne 0 ] && [ "$ALERT_ON_FAIL" = true ]; then
    send_alert "测试运行 #$run_number 失败: $failed 个测试失败"
  fi

  return $test_exit_code
}

# 生成趋势报告
generate_trend_report() {
  log_info "生成趋势报告..."

  local trend_file="$MONITOR_DIR/trend_report.txt"

  {
    echo "========================================"
    echo "测试趋势报告"
    echo "生成时间: $(date)"
    echo "========================================"
    echo ""

    # 统计信息
    local total_runs=$(tail -n +2 "$HISTORY_FILE" | wc -l)
    echo "总运行次数: $total_runs"
    echo ""

    # 最近10次运行
    echo "最近10次运行:"
    echo "----------------------------------------"
    echo "时间                  | 运行# | 通过率"
    echo "----------------------------------------"
    tail -n 10 "$HISTORY_FILE" | while IFS=',' read -r timestamp run_number total_tests passed failed skipped pass_rate; do
      printf "%-20s | %-5s | %5s%%\n" "$timestamp" "$run_number" "$pass_rate"
    done
    echo ""

    # 平均通过率
    local avg_pass_rate=$(tail -n +2 "$HISTORY_FILE" | awk -F',' '{sum+=$7; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}')
    echo "平均通过率: $avg_pass_rate%"

    # 最高/最低通过率
    local max_pass_rate=$(tail -n +2 "$HISTORY_FILE" | awk -F',' 'BEGIN{max=0} {if($7>max) max=$7} END{print max}')
    local min_pass_rate=$(tail -n +2 "$HISTORY_FILE" | awk -F',' 'BEGIN{min=100} {if($7<min) min=$7} END{print min}')
    echo "最高通过率: $max_pass_rate%"
    echo "最低通过率: $min_pass_rate%"
    echo ""

    # 趋势分析
    echo "趋势分析:"
    local recent_avg=$(tail -n 5 "$HISTORY_FILE" | awk -F',' '{sum+=$7; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}')
    local older_avg=$(tail -n 10 "$HISTORY_FILE" | head -n 5 | awk -F',' '{sum+=$7; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}')

    if (( $(echo "$recent_avg > $older_avg" | bc -l) )); then
      echo "  ✓ 测试质量正在改善 (最近5次: $recent_avg%, 之前5次: $older_avg%)"
    elif (( $(echo "$recent_avg < $older_avg" | bc -l) )); then
      echo "  ✗ 测试质量正在下降 (最近5次: $recent_avg%, 之前5次: $older_avg%)"
    else
      echo "  - 测试质量保持稳定 (最近5次: $recent_avg%, 之前5次: $older_avg%)"
    fi

  } > "$trend_file"

  cat "$trend_file"
}

# 清理函数
cleanup() {
  log_info "收到中断信号，正在清理..."
  generate_trend_report
  log_info "监控已停止。总运行次数: $RUN_COUNT"
  exit 0
}

# 注册信号处理
trap cleanup SIGINT SIGTERM

# 主循环
echo "========================================"
echo "持续测试监控"
echo "========================================"
echo "项目: fafafa.ssl"
echo "测试间隔: $INTERVAL 秒"
if [ "$MAX_RUNS" -gt 0 ]; then
  echo "最大运行次数: $MAX_RUNS"
else
  echo "最大运行次数: 无限"
fi
echo "警报模式: $([ "$ALERT_ON_FAIL" = true ] && echo "启用" || echo "禁用")"
if [ -n "$SPECIFIC_MODULES" ]; then
  echo "指定模块: $SPECIFIC_MODULES"
fi
echo "========================================"
echo ""

log_info "监控开始..."

while true; do
  RUN_COUNT=$((RUN_COUNT + 1))

  # 运行测试
  if run_tests "$RUN_COUNT"; then
    log_success "运行 #$RUN_COUNT 完成"
  else
    log_error "运行 #$RUN_COUNT 失败"
  fi

  # 每5次运行生成一次趋势报告
  if [ $((RUN_COUNT % 5)) -eq 0 ]; then
    generate_trend_report
  fi

  # 检查是否达到最大运行次数
  if [ "$MAX_RUNS" -gt 0 ] && [ "$RUN_COUNT" -ge "$MAX_RUNS" ]; then
    log_info "达到最大运行次数 ($MAX_RUNS)"
    break
  fi

  # 等待下一次运行
  log_info "等待 $INTERVAL 秒后进行下一次运行..."
  sleep "$INTERVAL"
done

# 生成最终报告
generate_trend_report
log_info "监控完成。总运行次数: $RUN_COUNT"
