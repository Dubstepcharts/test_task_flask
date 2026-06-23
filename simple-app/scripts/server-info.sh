#!/bin/bash
LOG_FILE="server-info.log"

TOTAL_CHECKS=0
FAILED_CHECKS=0

OS_TYPE="$(uname -s)"

show_help() {
    cat << EOF
Использование: $0 [URL1 URL2 ...]

Описание:
    Собирает информацию о системе и проверяет доступность сервисов.

Аргументы:
    URL1 URL2 ...  URL-адреса для проверки доступности

Флаги:
    --help Показать эту справку

Примеры:
    $0
    $0 http://localhost:5000/health http://localhost:8080/health

Код возврата:
    0 - все проверки успешны
    1 - хотя бы один сервис недоступен
EOF
    exit 0
}

check_dependency() {
    local dep="$1"

    if ! command -v "$dep" &> /dev/null; then
        echo -e "⚠️  Предупреждение: $dep не установлен"
        return 1
    fi
    return 0
}

get_system_info() {
    echo "=== Server Diagnostics ==="
    echo ""

    echo -e "Date:     $(date "+%Y-%m-%d %H:%M:%S")"
    echo -e "Hostname: $(hostname)"

    if command -v lsb_release &> /dev/null; then
        OS=$(lsb_release -d | cut -f2-)
    else
        OS=$(uname -srm)
    fi
    echo -e "OS:       $OS"

    echo -e "Kernel:   $(uname -r)"

    if [[ "$OS_TYPE" == "Linux" ]]; then
        UPTIME=$(uptime -p 2>/dev/null)
    else
        UPTIME_RAW=$(wmic os get LastBootUpTime 2>/dev/null | awk 'NR==2 {print $1}')
        if [ -n "$UPTIME_RAW" ]; then
            UPTIME="${UPTIME_RAW:0:4}-${UPTIME_RAW:4:2}-${UPTIME_RAW:6:2} ${UPTIME_RAW:8:2}:${UPTIME_RAW:10:2}:${UPTIME_RAW:12:2}"
        else
            UPTIME=$(uptime 2>/dev/null | awk -F'up' '{print $2}' | cut -d',' -f1 | xargs)
            if [ -z "$UPTIME" ]; then
                UPTIME="Не удалось определить"
            fi
        fi
    fi
    echo -e "Uptime:   $UPTIME"
    echo ""
}

get_resources_info() {
    echo "=== Resources ==="
    echo ""
    
    if [[ "$OS_TYPE" == "Linux" ]]; then
        CORES=$(nproc)
        LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)
        echo -e "CPU:      $CORES cores, load average: $LOAD"
    else
        CORES=$(nproc)
        echo -e "CPU:      $CORES cores"
    fi
    
    if [[ "$OS_TYPE" == "Linux" ]]; then
        RAM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
        RAM_USED=$(free -m | awk '/^Mem:/{print $3}')
        
        if [ "$RAM_TOTAL" -gt 0 ]; then
            RAM_PERCENT=$(( (RAM_USED * 100) / RAM_TOTAL ))
        else
            RAM_PERCENT=0
        fi
        
        if [ "$RAM_TOTAL" -ge 1024 ]; then
            RAM_TOTAL_GB=$(echo "scale=1; $RAM_TOTAL/1024" | bc 2>/dev/null || echo "$RAM_TOTAL")
            RAM_USED_GB=$(echo "scale=1; $RAM_USED/1024" | bc 2>/dev/null || echo "$RAM_USED")
            echo -e "RAM:      ${RAM_USED_GB}G / ${RAM_TOTAL_GB}G (${RAM_PERCENT}%)"
        else
            echo -e "RAM:      ${RAM_USED}M / ${RAM_TOTAL}M (${RAM_PERCENT}%)"
        fi
    else
        RAM_TOTAL_MB=$(wmic os get TotalVisibleMemorySize 2>/dev/null | awk 'NR==2 {printf "%.0f", $1/1024}')
        if [ -n "$RAM_TOTAL_MB" ] && [ "$RAM_TOTAL_MB" -gt 0 ]; then
            RAM_TOTAL_GB=$(echo "scale=1; $RAM_TOTAL_MB/1024" | bc 2>/dev/null || echo "$RAM_TOTAL_MB")
            echo -e "RAM:      ~${RAM_TOTAL_GB}G (Windows)"
        else
            echo -e "RAM:      Не удалось определить (Windows)"
        fi
    fi

    if [[ "$OS_TYPE" == "Linux" ]]; then
        DISK_INFO=$(df -h / | tail -n1)
        DISK_USED=$(echo "$DISK_INFO" | awk '{print $3}')
        DISK_TOTAL=$(echo "$DISK_INFO" | awk '{print $2}')
        DISK_PERCENT=$(echo "$DISK_INFO" | awk '{print $5}' | tr -d '%')
        echo -e "Disk /:   $DISK_USED / $DISK_TOTAL (${DISK_PERCENT}%)"
    else
        DISK_INFO=$(df -h . | tail -n1)
        DISK_USED=$(echo "$DISK_INFO" | awk '{print $3}')
        DISK_TOTAL=$(echo "$DISK_INFO" | awk '{print $2}')
        DISK_PERCENT=$(echo "$DISK_INFO" | awk '{print $5}' | tr -d '%')
        echo -e "Disk .:   $DISK_USED / $DISK_TOTAL (${DISK_PERCENT}%)"
    fi
    echo ""
}

get_docker_info() {
    echo "=== Docker ==="
    echo ""
    
    if check_dependency docker; then
        if docker info &> /dev/null; then
            docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Status}}" 2>/dev/null || echo "Нет запущенных контейнеров"
        else
            echo -e "⚠️  Docker установлен, но не запущен"
        fi
    else
        echo -e "⚠️  Docker не установлен"
    fi
    echo ""
}

check_service() {
    local url="$1"
    
    if ! check_dependency curl; then
        echo "Ошибка: curl не установлен, невозможно проверить сервисы" >&2
        return 1
    fi
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)
    
    if [ -n "$HTTP_CODE" ] && [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
        echo -e "[OK]   $url ($HTTP_CODE)"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - OK - $url ($HTTP_CODE)" >> "$LOG_FILE"
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        echo -e "[FAIL] $url (недоступен)"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - FAIL - $url (недоступен)" >> "$LOG_FILE"
    fi
}

show_summary() {
    echo ""
    echo -e "Result: $((TOTAL_CHECKS - FAILED_CHECKS))/$TOTAL_CHECKS services healthy"
    
    if [ "$FAILED_CHECKS" -gt 0 ]; then
        return 1
    fi
    return 0
}

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
fi

get_system_info
get_resources_info
get_docker_info

if [ $# -gt 0 ]; then
    echo "=== Service Health Checks ==="
    echo ""
    
    for URL in "$@"; do
        check_service "$URL"
    done
    
    show_summary
else
    echo "=== No services to check ==="
    echo ""
    echo "Передайте URL-адреса для проверки или используйте --help"
    echo ""
fi

if [ "$FAILED_CHECKS" -gt 0 ]; then
    exit 1
else
    exit 0
fi