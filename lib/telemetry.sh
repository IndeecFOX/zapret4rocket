# ---- Telemetry module integration ----
# Настройки Google Forms
STATS_FORM_ID="1FAIpQLScrUf7Pybm0n61aK8aZuxuAR8KhyNYZ-X0xjSUS8K72SmEhPw"
ENTRY_UUID="entry.1346249141"
ENTRY_ISP="entry.2008245653"
ENTRY_UDP="entry.592144534"
ENTRY_TCP="entry.1826276405"
ENTRY_GV="entry.1549076812"
ENTRY_RKN="entry.1527830884"

# 2. Пути к файлам (используем простые форматы)
CACHE_DIR="/opt/zapret/extra_strats/cache"
TELEMETRY_CFG="$CACHE_DIR/telemetry.config"
PROVIDER_TXT="$CACHE_DIR/provider.txt"

# Функция инициализации (Спрашивает пользователя один раз)
init_telemetry() {
    mkdir -p "$CACHE_DIR"
    local tel_enabled=""
    local tel_uuid=""

    # 1. Загружаем конфиг, если он есть
    [ -f "$TELEMETRY_CFG" ] && source "$TELEMETRY_CFG"

    # 2. Если статус еще не задан — спрашиваем
    if [ -z "$tel_enabled" ]; then
        echo ""
        echo -e "${green}Хотите отправлять анонимную статистику (Провайдер + Стратегии)?${plain}"
        echo -e "Это поможет понять, какие стратегии работают лучше всего."
        read -p "Разрешить? (y/n): " stats_yn

        case "$stats_yn" in
            [Yy]*) tel_enabled="1" ;;
            *)     tel_enabled="0" ;;
        esac

        # Сразу сохраняем выбор
        echo "tel_enabled=$tel_enabled" > "$TELEMETRY_CFG"
        echo "tel_uuid=$tel_uuid" >> "$TELEMETRY_CFG"

        if [ "$tel_enabled" == "1" ]; then
            echo -e "${green}Спасибо! Статистика включена.${plain}"
        else
            echo -e "${red}Статистика отключена.${plain}"
        fi
        sleep 1
    fi

    # 3. Генерация UUID (если включено и его нет)
    if [ "$tel_enabled" == "1" ] && [ -z "$tel_uuid" ]; then
        # Пытаемся взять системный UUID или генерируем md5 от времени
        if [ -f /proc/sys/kernel/random/uuid ]; then
            tel_uuid=$(cat /proc/sys/kernel/random/uuid | cut -c1-8)
        else
            tel_uuid=$(date +%s%N | md5sum | head -c 8)
        fi

        # Перезаписываем конфиг с новым UUID
        echo "tel_enabled=$tel_enabled" > "$TELEMETRY_CFG"
        echo "tel_uuid=$tel_uuid" >> "$TELEMETRY_CFG"
    fi
}

# Функция отправки статистики
send_stats() {
    # Если конфига нет, значит init_telemetry не запускался — выходим
    [ ! -f "$TELEMETRY_CFG" ] && return 0

    # Читаем переменные (tel_enabled, tel_uuid)
    source "$TELEMETRY_CFG"

    # Если пользователь запретил — выходим
    if [ "$tel_enabled" != "1" ]; then
        return 0
    fi

    # 1. Провайдер (Читаем из provider.txt, который создает Provider detector)
    local my_isp="Unknown"
    if [ -s "$PROVIDER_TXT" ]; then
        my_isp=$(cat "$PROVIDER_TXT")
    else
        # Фолбек: если provider.txt еще нет, пробуем быстро узнать
        my_isp=$(curl -s --max-time 3 "http://ip-api.com/line?fields=org" | tr -cd '[:alnum:] ._-')
    fi

    # Обрезаем до 60 символов и ставим заглушку если пусто
    my_isp=$(echo "$my_isp" | head -c 60)
    [ -z "$my_isp" ] && my_isp="Unknown"

    # 2. Определяем номера стратегий
    local s_udp=$(get_active_strat_num "/opt/zapret/extra_strats/UDP/YT" 8)
    local s_tcp=$(get_active_strat_num "/opt/zapret/extra_strats/TCP/YT" 17)
    local s_gv=$(get_active_strat_num "/opt/zapret/extra_strats/TCP/GV" 17)
    local s_rkn=$(get_active_strat_num "/opt/zapret/extra_strats/TCP/RKN" 17)

    # 3. Отправка в Google Forms (Тихий режим, в фоне &)
    curl -sL --max-time 10 \
        -d "$ENTRY_UUID=$tel_uuid" \
        -d "$ENTRY_ISP=$my_isp" \
        -d "$ENTRY_UDP=$s_udp" \
        -d "$ENTRY_TCP=$s_tcp" \
        -d "$ENTRY_GV=$s_gv" \
        -d "$ENTRY_RKN=$s_rkn" \
        "https://docs.google.com/forms/d/e/$STATS_FORM_ID/formResponse" > /dev/null 2>&1 &
}
# ---- /Telemetry module integration ----
