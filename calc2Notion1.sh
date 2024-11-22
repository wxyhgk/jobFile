#!/bin/bash
#PBS -N notion-gaussian
#PBS -q short
#PBS -l nodes=1:ppn=4
#PBS -l walltime=32:00:00

# === 加载环境 ===
source /home/scicons/profiles/profile.g16
export GAUSS_SCRDIR=$(mktemp -d)

# 切换到作业提交的工作目录
cd $PBS_O_WORKDIR
CURRENT_DIR=$(pwd)

# === 本地机器配置 ===
MASTER_IP="11.11.11.101"
MASTER_USER="zhangdd"
MASTER_PASSWORD="zdd@114"
LOCAL_CONDA_PATH="/data/zhangdd/my_local_apps/conda3/bin/activate"
LOCAL_SCRIPTS_DIR="/data/zhangdd/guan-scripts/test-1/calc2Notion"

# === 加载所有bash函数文件 ===
FUNC_DIR="/data/zhangdd/guan-scripts/test-1/lib"

# 检查函数目录是否存在
if [[ ! -d "$FUNC_DIR" ]]; then
    echo "错误：找不到函数目录 ${FUNC_DIR}"
    exit 1
fi

# 加载目录下所有的 .sh 文件包括 notion 函数相关的
for func_file in "$FUNC_DIR"/*.sh; do
    if [[ -f "$func_file" ]]; then
        source "$func_file"
    else
        echo "错误：函数目录 ${FUNC_DIR} 中没有找到任何 .sh 文件"
        exit 1
    fi
done




run_step() {
    local file=$1
    local step=$2
    local dep_file=$3
    local step_id=$4
    local step_log_file="${log_dir}/step${step}_${file}.txt"
    
    # 首先检查输入文件
    if ! check_gjf_file "$file" "$step_log_file"; then
        update_notion_status "$PAGE_ID" "输入文件检查失败"
        exit 1
    fi

    # 如果有依赖的 chk 文件，先复制
    if [[ -n "$dep_file" ]]; then
        cp "${dep_file%.gjf}.chk" "${file%.gjf}.chk" || exit 1
    fi

    # 运行Gaussian计算
    if ! run_gaussian_with_logging "$file" "$log_dir" "$step"; then
        update_notion_status "$PAGE_ID" "计算失败"
        if [[ -f "$step_log_file" ]]; then
            run_on_master "create_toggleCode.py" "${step_id} '$(cat ${step_log_file})' '计算失败日志'"
        fi
        exit 1
    fi

    # 检查频率并更新Notion
    local freq_check_type=$(determine_freq_check "$file")
    local freq_check_result="success"
    
    case "$freq_check_type" in
        "normal")
            if ! check_frequency_with_logging "${file%.gjf}.log" "$step_log_file"; then
                freq_check_result="failed"
            fi
            ;;
        "ts")
            if ! check_ts_frequency_with_logging "${file%.gjf}.log" "$step_log_file"; then
                freq_check_result="failed"
            fi
            ;;
    esac

    # 将步骤日志更新到Notion，只使用cat读取日志
    if [[ -f "$step_log_file" ]]; then
        run_on_master "create_toggleCode.py" "${step_id} '$(cat ${step_log_file})' '计算步骤日志'"
    fi

    # 如果频率检查失败，更新状态
    if [[ "$freq_check_result" == "failed" ]]; then
        update_notion_status "$PAGE_ID" "频率检查失败"
        exit 1
    fi
}


# === 设置日志环境 ===
setup_info=$(setup_logging)
log_dir="${setup_info%:*}"
time_log="${log_dir}/time.txt"

# === 创建主Notion页面 ===
current_datetime=$(date '+%Y-%m%d-%H%M-%S')
PAGE_TITLE="process-${current_datetime}"
INITIAL_PROPERTIES='{
    "状态": {"status": {"name": "计算中"}},
    "任务所在文件夹": {"rich_text": [{"text": {"content": "'"${CURRENT_DIR}"'"}}]}
}'

echo "开始创建Notion页面..."
PAGE_ID=$(run_on_master "create_notion_page.py" "'${PAGE_TITLE}' '${INITIAL_PROPERTIES}'")

if [ -z "$PAGE_ID" ]; then
    echo "Error: 无法获取page_id"
    exit 1
fi
echo "创建的主页面ID: $PAGE_ID"

# === 创建页面结构 ===
echo "创建页面标题..."
BASIC_INFO_ID=$(run_on_master "create_h1.py" "${PAGE_ID} '1.基本信息'")
CALC_GROUP_ID=$(run_on_master "create_h1.py" "${PAGE_ID} '2.计算文件组'")

# === 创建计算步骤页面 ===
echo "创建步骤页面..."
step1="s0.gjf"
step2="s0_tda.gjf"
step3="s1.gjf"
step4="s1_tda.gjf"

# 创建每个步骤的页面并保存ID
S0_ID=$(run_on_master "create_multi_steps.py" "${PAGE_ID} '${step1}'")
S0_TDA_ID=$(run_on_master "create_multi_steps.py" "${PAGE_ID} '${step2}'")
S1_ID=$(run_on_master "create_multi_steps.py" "${PAGE_ID} '${step3}'")
S1_TDA_ID=$(run_on_master "create_multi_steps.py" "${PAGE_ID} '${step4}'")

DATA_ANALYSIS_ID=$(run_on_master "create_h1.py" "${PAGE_ID} '3.数据分析'")

# === 开始计算 ===
total_start_time=$(date '+%Y-%m-%d %H:%M:%S')
total_start_epoch=$(date +%s)

update_notion_status "$PAGE_ID" "计算中"

# 执行计算步骤
run_step "${step1}" "1" "" "$S0_ID"
run_step "${step2}" "2" "" "$S0_TDA_ID"
run_step "${step3}" "3" "${step1}" "$S1_ID"
run_step "${step4}" "4" "" "$S1_TDA_ID"

# === 记录完成信息 ===
total_end_time=$(date '+%Y-%m-%d %H:%M:%S')
total_end_epoch=$(date +%s)
total_duration=$(( total_end_epoch - total_start_epoch ))
formatted_total_duration=$(format_time $total_duration)

# 记录总体信息到本地日志
write_to_log "$time_log" "====================================="
write_to_log "$time_log" "任务开始时间: $total_start_time"
write_to_log "$time_log" "任务完成时间: $total_end_time"
write_to_log "$time_log" "总计耗时: $formatted_total_duration"
write_to_log "$time_log" "状态: 成功"
write_to_log "$time_log" "===================================="

# 更新Notion最终状态
update_notion_status "$PAGE_ID" "计算完成"

# === 清理工作 ===
rm -rf $GAUSS_SCRDIR
echo "任务完成"