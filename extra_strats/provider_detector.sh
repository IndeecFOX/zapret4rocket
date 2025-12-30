#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
# Provider Detector для zapret4rocket
# Автор: AloofLibra
# Версия: 1.0
# ═══════════════════════════════════════════════════════════════════

PROVIDER_CACHE="/opt/zapret/extra_strats/cache/provider.json"
PROVIDER_CACHE_DIR="/opt/zapret/extra_strats/cache"

# Цвета для вывода
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
plain='\033[0m'

# База данных AS → Провайдер
declare -A AS_DATABASE=(
    # Ростелеком
    ["AS12389"]="Rostelecom"
    ["AS42610"]="Rostelecom"
    ["AS8369"]="Rostelecom"
    ["AS20485"]="Rostelecom"
    
    # МТС
    ["AS8359"]="MTS"
    ["AS3216"]="MTS"
    ["AS29280"]="MTS"
    
    # Билайн
    ["AS8402"]="Beeline"
    ["AS3267"]="Beeline"
    ["AS13335"]="Beeline"
    
    # Теле2
    ["AS41330"]="Tele2"
    ["AS31163"]="Tele2"
    
    # МегаФон
    ["AS25159"]="MegaFon"
    ["AS25513"]="MegaFon"
    ["AS31133"]="MegaFon"
    
    # Дом.ру
    ["AS41733"]="Dom.ru"
    ["AS51604"]="Dom.ru"
    
    # ТТК
    ["AS20485"]="TTK"
    
    # Другие
    ["AS47775"]="Yota"
    ["AS203978"]="Akado"
    ["AS31200"]="Enforta"
    ["AS50928"]="Enforta"
)

# ═══════════════════════════════════════════════════════════════════
# Функция: Создание директории для кэша
# ═══════════════════════════════════════════════════════════════════
init_cache_dir() {
    if [[ ! -d "$PROVIDER_CACHE_DIR" ]]; then
        mkdir -p "$PROVIDER_CACHE_DIR"
    fi
}

# ═══════════════════════════════════════════════════════════════════
# Функция: Определение провайдера через ip-api.com
# ═══════════════════════════════════════════════════════════════════
detect_provider_api() {
    echo -e "${cyan}⏳ Определяю провайдера через API...${plain}" >&2
    
    # Получаем внешний IP
    local external_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 api.ipify.org 2>/dev/null)
    
    if [[ -z "$external_ip" ]]; then
        echo -e "${red}❌ Не удалось получить внешний IP${plain}" >&2
        echo "Unknown"
        return 1
    fi
    
    echo -e "${blue}   IP: $external_ip${plain}" >&2
    
    # Запрос к ip-api.com
    local api_response=$(curl -s --max-time 10 "http://ip-api.com/json/$external_ip?fields=status,isp,org,as,city,country")
    local status=$(echo "$api_response" | jq -r '.status' 2>/dev/null)
    
    if [[ "$status" == "success" ]]; then
        local as_number=$(echo "$api_response" | jq -r '.as' 2>/dev/null | awk '{print $1}')
        local isp=$(echo "$api_response" | jq -r '.isp' 2>/dev/null)
        local org=$(echo "$api_response" | jq -r '.org' 2>/dev/null)
        local city=$(echo "$api_response" | jq -r '.city' 2>/dev/null)
        local country=$(echo "$api_response" | jq -r '.country' 2>/dev/null)
        
        echo -e "${blue}   ASN: $as_number${plain}" >&2
        echo -e "${blue}   ISP: $isp${plain}" >&2
        echo -e "${blue}   Город: $city, $country${plain}" >&2
        
        # Проверяем в базе AS
        if [[ -n "${AS_DATABASE[$as_number]}" ]]; then
            local provider="${AS_DATABASE[$as_number]}"
            echo -e "${green}✅ Провайдер определён: $provider${plain}" >&2
            
            # Сохраняем в кэш
            save_to_cache "$provider" "$as_number" "$isp" "$org" "$city" "$country" "$external_ip"
            echo "$provider"
            return 0
        fi
        
        # Fallback: парсим ISP
        case "$isp" in
            *Rostelecom*|*RTTK*) 
                local provider="Rostelecom"
                save_to_cache "$provider" "$as_number" "$isp" "$org" "$city" "$country" "$external_ip"
                echo "$provider"
                return 0
                ;;
            *MTS*|*MGTS*) 
                local provider="MTS"
                save_to_cache "$provider" "$as_number" "$isp" "$org" "$city" "$country" "$external_ip"
                echo "$provider"
                return 0
                ;;
            *Beeline*|*VimpelCom*) 
                local provider="Beeline"
                save_to_cache "$provider" "$as_number" "$isp" "$org" "$city" "$country" "$external_ip"
                echo "$provider"
                return 0
                ;;
            *Tele2*) 
                local provider="Tele2"
                save_to_cache "$provider" "$as_number" "$isp" "$org" "$city" "$country" "$external_ip"
                echo "$provider"
                return 0
                ;;
            *MegaFon*) 
                local provider="MegaFon"
                save_to_cache "$provider" "$as_number" "$isp" "$org" "$city" "$country" "$external_ip"
                echo "$provider"
                return 0
                ;;
            *Dom.ru*|*ER-Telecom*) 
                local provider="Dom.ru"
                save_to_cache "$provider" "$as_number" "$isp" "$org" "$city" "$country" "$external_ip"
                echo "$provider"
                return 0
                ;;
            *TTK*) 
                local provider="TTK"
                save_to_cache "$provider" "$as_number" "$isp" "$org" "$city" "$country" "$external_ip"
                echo "$provider"
                return 0
                ;;
        esac
        
        # Не нашли в базе - возвращаем ISP как есть
        echo -e "${yellow}⚠ Провайдер не определён точно, используем: $isp${plain}" >&2
        save_to_cache "$isp" "$as_number" "$isp" "$org" "$city" "$country" "$external_ip"
        echo "$isp"
        return 0
    fi
    
    # API не сработал
    echo -e "${red}❌ API недоступен${plain}" >&2
    echo "Unknown"
    return 1
}

# ═══════════════════════════════════════════════════════════════════
# Функция: Сохранение в кэш
# ═══════════════════════════════════════════════════════════════════
save_to_cache() {
    local provider="$1"
    local asn="$2"
    local isp="$3"
    local org="$4"
    local city="$5"
    local country="$6"
    local ip="$7"
    
    init_cache_dir
    
    cat > "$PROVIDER_CACHE" <<EOF
{
  "provider": "$provider",
  "asn": "$asn",
  "isp": "$isp",
  "org": "$org",
  "city": "$city",
  "country": "$country",
  "ip": "$ip",
  "detected_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "method": "auto"
}
EOF
    
    echo -e "${green}💾 Информация сохранена в кэш${plain}" >&2
}

# ═══════════════════════════════════════════════════════════════════
# Функция: Чтение из кэша
# ═══════════════════════════════════════════════════════════════════
get_cached_provider() {
    if [[ ! -f "$PROVIDER_CACHE" ]]; then
        return 1
    fi
    
    # Проверяем валидность JSON
    if ! jq empty "$PROVIDER_CACHE" 2>/dev/null; then
        return 1
    fi
    
    local provider=$(jq -r '.provider' "$PROVIDER_CACHE" 2>/dev/null)
    
    if [[ -n "$provider" && "$provider" != "null" ]]; then
        echo "$provider"
        return 0
    fi
    
    return 1
}

# ═══════════════════════════════════════════════════════════════════
# Функция: Получить провайдера с городом из кэша
# ═══════════════════════════════════════════════════════════════════
get_provider_with_city() {
    if [[ ! -f "$PROVIDER_CACHE" ]]; then
        echo "Не определён"
        return 1
    fi
    
    # Проверяем валидность JSON
    if ! jq empty "$PROVIDER_CACHE" 2>/dev/null; then
        echo "Не определён"
        return 1
    fi
    
    local provider=$(jq -r '.provider' "$PROVIDER_CACHE" 2>/dev/null)
    local city=$(jq -r '.city' "$PROVIDER_CACHE" 2>/dev/null)
    
    # Если провайдер не определён
    if [[ -z "$provider" || "$provider" == "null" ]]; then
        echo "Не определён"
        return 1
    fi
    
    # Если город есть и это не "N/A" и не "null"
    if [[ -n "$city" && "$city" != "null" && "$city" != "N/A" ]]; then
        echo "$provider - $city"
    else
        echo "$provider"
    fi
    
    return 0
}


# ═══════════════════════════════════════════════════════════════════
# Функция: Получить полную информацию из кэша
# ═══════════════════════════════════════════════════════════════════
get_cached_info() {
    if [[ ! -f "$PROVIDER_CACHE" ]]; then
        return 1
    fi
    
    if ! jq empty "$PROVIDER_CACHE" 2>/dev/null; then
        return 1
    fi
    
    cat "$PROVIDER_CACHE"
    return 0
}

# ═══════════════════════════════════════════════════════════════════
# Функция: Ручная установка провайдера
# ═══════════════════════════════════════════════════════════════════
set_provider_manual() {
    local provider="$1"
    
    init_cache_dir
    
    cat > "$PROVIDER_CACHE" <<EOF
{
  "provider": "$provider",
  "asn": "manual",
  "isp": "$provider",
  "org": "manual",
  "city": "N/A",
  "country": "N/A",
  "ip": "N/A",
  "detected_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "method": "manual"
}
EOF
    
    echo -e "${green}✅ Провайдер установлен вручную: $provider${plain}"
}

# ═══════════════════════════════════════════════════════════════════
# Функция: Очистка кэша
# ═══════════════════════════════════════════════════════════════════
clear_cache() {
    if [[ -f "$PROVIDER_CACHE" ]]; then
        rm -f "$PROVIDER_CACHE"
        echo -e "${green}🗑️  Кэш очищен${plain}"
    else
        echo -e "${yellow}⚠ Кэш уже пуст${plain}"
    fi
}

# ═══════════════════════════════════════════════════════════════════
# Функция: Основная логика определения
# ═══════════════════════════════════════════════════════════════════
detect_provider() {
    local force_update="$1"
    
    # Проверяем кэш
    if [[ "$force_update" != "true" ]]; then
        local cached=$(get_cached_provider)
        if [[ $? -eq 0 ]]; then
            echo "$cached"
            return 0
        fi
    fi
    
    # Определяем провайдера
    detect_provider_api
}

# ═══════════════════════════════════════════════════════════════════
# Функция: Показать подробную информацию
# ═══════════════════════════════════════════════════════════════════
show_provider_info() {
    if [[ ! -f "$PROVIDER_CACHE" ]]; then
        echo -e "${yellow}⚠ Провайдер ещё не определён${plain}"
        return 1
    fi
    
    local info=$(get_cached_info)
    if [[ $? -ne 0 ]]; then
        echo -e "${red}❌ Ошибка чтения кэша${plain}"
        return 1
    fi
    
    local provider=$(echo "$info" | jq -r '.provider')
    local asn=$(echo "$info" | jq -r '.asn')
    local isp=$(echo "$info" | jq -r '.isp')
    local city=$(echo "$info" | jq -r '.city')
    local country=$(echo "$info" | jq -r '.country')
    local detected_at=$(echo "$info" | jq -r '.detected_at')
    local method=$(echo "$info" | jq -r '.method')
    
    echo -e "${blue}╔═══════════════════════════════════════════════╗${plain}"
    echo -e "${blue}║        Информация о провайдере                ║${plain}"
    echo -e "${blue}╠═══════════════════════════════════════════════╣${plain}"
    echo -e "${blue}║${plain} Провайдер:  ${green}$provider${plain}"
    echo -e "${blue}║${plain} ISP:         $isp"
    echo -e "${blue}║${plain} AS Number:   $asn"
    echo -e "${blue}║${plain} Локация:     $city, $country"
    echo -e "${blue}║${plain} Метод:       $method"
    echo -e "${blue}║${plain} Определён:   $detected_at"
    echo -e "${blue}╚═══════════════════════════════════════════════╝${plain}"
}

# ═══════════════════════════════════════════════════════════════════
# Экспорт функций (если скрипт вызывается через source)
# ═══════════════════════════════════════════════════════════════════
export -f detect_provider
export -f get_cached_provider
export -f set_provider_manual
export -f clear_cache
export -f show_provider_info
