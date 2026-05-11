STRATEGIES_DIR="${STRATEGIES_DIR:-/opt/zapret/z4r_strategies}"
HOSTLIST_STATE_DIR="${HOSTLIST_STATE_DIR:-/opt/zapret/extra_strats}"
BEZRAZBOR_STATE_FILE="${BEZRAZBOR_STATE_FILE:-$HOSTLIST_STATE_DIR/cache/bezrazbor.strategy}"
FOOLING_STATE_FILE="${FOOLING_STATE_FILE:-$HOSTLIST_STATE_DIR/cache/fooling.mode}"
SNI_STATE_FILE="${SNI_STATE_FILE:-$HOSTLIST_STATE_DIR/cache/fake_tls_sni}"
CUSTOM_STRATEGY_START=1000

strategy_dir() {
    case "$1" in
        UDP) echo "$STRATEGIES_DIR/UDP" ;;
        *) echo "$STRATEGIES_DIR/TCP" ;;
    esac
}

strategy_num_from_name() {
    local name="$1"
    name="${name##*/}"
    case "$name" in
        [0-9]*.disabled.txt) echo "${name%%.disabled.txt}" ;;
        [0-9]*.txt) echo "${name%%.txt}" ;;
        *) echo "" ;;
    esac
}

strategy_is_enabled() {
    local type="$1"
    local num="$2"
    local dir
    dir="$(strategy_dir "$type")"

    [ -s "$dir/${num}.txt" ]
}

strategy_is_custom_num() {
    local num="$1"
    case "$num" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$num" -ge "$CUSTOM_STRATEGY_START" ]
}

strategy_max_num() {
    local type="$1"
    local dir file base num max=0
    dir="$(strategy_dir "$type")"

    [ -d "$dir" ] || { echo 0; return; }
    for file in "$dir"/*.txt; do
        [ -e "$file" ] || continue
        base="${file##*/}"
        num="$(strategy_num_from_name "$base")"
        case "$num" in
            ''|*[!0-9]*) continue ;;
        esac
        [ "$num" -gt "$max" ] && max="$num"
    done

    echo "$max"
}

strategy_builtin_max_num() {
    local type="$1"
    local dir file base num max=0
    dir="$(strategy_dir "$type")"

    [ -d "$dir" ] || { echo 0; return; }
    for file in "$dir"/*.txt; do
        [ -e "$file" ] || continue
        base="${file##*/}"
        num="$(strategy_num_from_name "$base")"
        case "$num" in
            ''|*[!0-9]*) continue ;;
        esac
        [ "$num" -ge "$CUSTOM_STRATEGY_START" ] && continue
        [ "$num" -gt "$max" ] && max="$num"
    done

    echo "$max"
}

strategy_custom_max_num() {
    local type="$1"
    local dir file base num max=0
    dir="$(strategy_dir "$type")"

    [ -d "$dir" ] || { echo 0; return; }
    for file in "$dir"/*.txt; do
        [ -e "$file" ] || continue
        base="${file##*/}"
        num="$(strategy_num_from_name "$base")"
        case "$num" in
            ''|*[!0-9]*) continue ;;
        esac
        [ "$num" -lt "$CUSTOM_STRATEGY_START" ] && continue
        [ "$num" -gt "$max" ] && max="$num"
    done

    echo "$max"
}

strategy_enabled_count() {
    local type="$1"
    local dir file base count=0
    dir="$(strategy_dir "$type")"

    [ -d "$dir" ] || { echo 0; return; }
    for file in "$dir"/*.txt; do
        [ -e "$file" ] || continue
        [ -s "$file" ] || continue
        base="${file##*/}"
        case "$base" in
            *.disabled.txt) ;;
            [0-9]*.txt) count=$((count + 1)) ;;
        esac
    done

    echo "$count"
}

strategy_plural_ru() {
    local n="$1"
    local n10 n100 word
    n10=$((n % 10))
    n100=$((n % 100))

    if [ "$n10" -eq 1 ] && [ "$n100" -ne 11 ]; then
        word="вариант"
    elif [ "$n10" -ge 2 ] && [ "$n10" -le 4 ] && { [ "$n100" -lt 12 ] || [ "$n100" -gt 14 ]; }; then
        word="варианта"
    else
        word="вариантов"
    fi

    echo "$n $word"
}

strategy_variants_label() {
    strategy_plural_ru "$(strategy_enabled_count "$1")"
}

strategy_sni_mod_nums_label() {
    local dir max num file nums=""
    dir="$(strategy_dir TCP)"
    max="$(strategy_max_num TCP)"

    num=1
    while [ "$num" -le "$max" ]; do
        for file in "$dir/${num}.txt" "$dir/${num}.disabled.txt"; do
            [ -s "$file" ] || continue
            if grep -q -e '--dpi-desync-fake-tls-mod=[^[:space:]]*sni=[^,[:space:]]*$' -e '--dpi-desync-fake-tls-mod=[^[:space:]]*sni=[^,[:space:]]*[[:space:]]' "$file"; then
                if [ -n "$nums" ]; then
                    nums="$nums,$num"
                else
                    nums="$num"
                fi
                break
            fi
        done
        num=$((num + 1))
    done

    [ -n "$nums" ] || nums="нет"
    echo "$nums"
}

ensure_strategy_hostlist_files_for_num() {
    local type="$1"
    local num="$2"

    if [ "$type" = "UDP" ]; then
        mkdir -p "$HOSTLIST_STATE_DIR/UDP/YT" 2>/dev/null || true
        [ -e "$HOSTLIST_STATE_DIR/UDP/YT/${num}.txt" ] || : > "$HOSTLIST_STATE_DIR/UDP/YT/${num}.txt"
        return 0
    fi

    mkdir -p "$HOSTLIST_STATE_DIR/TCP/RKN" "$HOSTLIST_STATE_DIR/TCP/User" \
             "$HOSTLIST_STATE_DIR/TCP/YT" "$HOSTLIST_STATE_DIR/TCP/temp" \
             "$HOSTLIST_STATE_DIR/TCP/GV" 2>/dev/null || true
    [ -e "$HOSTLIST_STATE_DIR/TCP/RKN/${num}.txt" ] || : > "$HOSTLIST_STATE_DIR/TCP/RKN/${num}.txt"
    [ -e "$HOSTLIST_STATE_DIR/TCP/User/${num}.txt" ] || : > "$HOSTLIST_STATE_DIR/TCP/User/${num}.txt"
    [ -e "$HOSTLIST_STATE_DIR/TCP/YT/${num}.txt" ] || : > "$HOSTLIST_STATE_DIR/TCP/YT/${num}.txt"
    [ -e "$HOSTLIST_STATE_DIR/TCP/temp/${num}.txt" ] || : > "$HOSTLIST_STATE_DIR/TCP/temp/${num}.txt"
    [ -e "$HOSTLIST_STATE_DIR/TCP/GV/${num}.txt" ] || : > "$HOSTLIST_STATE_DIR/TCP/GV/${num}.txt"
}

ensure_strategy_hostlist_files() {
    local type max i
    for type in TCP UDP; do
        max="$(strategy_builtin_max_num "$type")"
        i=1
        while [ "$i" -le "$max" ]; do
            ensure_strategy_hostlist_files_for_num "$type" "$i"
            i=$((i + 1))
        done
        max="$(strategy_custom_max_num "$type")"
        i="$CUSTOM_STRATEGY_START"
        while [ "$i" -le "$max" ]; do
            if [ -s "$(strategy_dir "$type")/${i}.txt" ] || [ -s "$(strategy_dir "$type")/${i}.disabled.txt" ]; then
                ensure_strategy_hostlist_files_for_num "$type" "$i"
            fi
            i=$((i + 1))
        done
    done
}

clear_strategy_hostlists_on_disable() {
    local type="$1"
    local num="$2"

    if [ "$type" = "UDP" ]; then
        [ -e "$HOSTLIST_STATE_DIR/UDP/YT/${num}.txt" ] && : > "$HOSTLIST_STATE_DIR/UDP/YT/${num}.txt"
        return 0
    fi

    [ -e "$HOSTLIST_STATE_DIR/TCP/RKN/${num}.txt" ] && : > "$HOSTLIST_STATE_DIR/TCP/RKN/${num}.txt"
    [ -e "$HOSTLIST_STATE_DIR/TCP/YT/${num}.txt" ] && : > "$HOSTLIST_STATE_DIR/TCP/YT/${num}.txt"
    [ -e "$HOSTLIST_STATE_DIR/TCP/temp/${num}.txt" ] && : > "$HOSTLIST_STATE_DIR/TCP/temp/${num}.txt"
    [ -e "$HOSTLIST_STATE_DIR/TCP/GV/${num}.txt" ] && : > "$HOSTLIST_STATE_DIR/TCP/GV/${num}.txt"
}

remove_domains_from_other_user_hostlists() {
    local current_num="$1"
    local domains="$2"
    local file tmp domain

    for file in "$HOSTLIST_STATE_DIR/TCP/User/"*.txt; do
        [ -e "$file" ] || continue
        case "${file##*/}" in
            "${current_num}.txt") continue ;;
        esac

        tmp="${file}.tmp"
        : > "$tmp"
        while IFS= read -r domain; do
            [ -n "$domain" ] || continue
            if echo "$domains" | grep -q -x -F "$domain"; then
                continue
            fi
            echo "$domain" >> "$tmp"
        done < "$file"
        mv -f "$tmp" "$file"
    done
}

confirm_user_hostlist_duplicates() {
    local current_num="$1"
    local domains="$2"
    local file domain file_num duplicates="" duplicate_lines="" answer
    local line new_duplicate_lines found

    for file in "$HOSTLIST_STATE_DIR/TCP/User/"*.txt; do
        [ -e "$file" ] || continue
        case "${file##*/}" in
            "${current_num}.txt") continue ;;
        esac
        file_num="${file##*/}"
        file_num="${file_num%%.txt}"

        while IFS= read -r domain; do
            [ -n "$domain" ] || continue
            if echo "$domains" | grep -q -x -F "$domain"; then
                case "
$duplicates
" in
                    *"
$domain
"*) ;;
                    *) duplicates="${duplicates}${duplicates:+
}$domain" ;;
                esac
                found=0
                new_duplicate_lines=""
                while IFS= read -r line; do
                    [ -n "$line" ] || continue
                    case "$line" in
                        "$domain ["*"]")
                            line="${line%]}"
                            line="$line,$file_num]"
                            found=1
                            ;;
                    esac
                    new_duplicate_lines="${new_duplicate_lines}${new_duplicate_lines:+
}$line"
                done <<EOF
$duplicate_lines
EOF
                duplicate_lines="$new_duplicate_lines"
                if [ "$found" -eq 0 ]; then
                    duplicate_lines="${duplicate_lines}${duplicate_lines:+
}$domain [$file_num]"
                fi
            fi
        done < "$file"
    done

    [ -z "$duplicates" ] && return 0

    echo -e "${yellow}Эти домены уже есть в других User hostlist:${plain}"
    echo "$duplicate_lines"
    echo "1 - удалить их из других стратегий и добавить сюда"
    echo "2 - оставить дубли и добавить сюда"
    echo "0 или Enter - прервать добавление"
    read -re -p "Ваш выбор: " answer

    case "$answer" in
        "1")
            remove_domains_from_other_user_hostlists "$current_num" "$duplicates"
            return 0
            ;;
        "2")
            return 0
            ;;
        *)
            echo "Добавление доменов отменено."
            return 1
            ;;
    esac
}

# Функция определяет номер активной стратегии в указанной папке
# Использование: get_active_strat_num "/path/to/folder" MAX_COUNT [TCP|UDP]
get_active_strat_num() {
    local folder="$1"
    local max="$2"
    local type="${3:-TCP}"
    local i
    
    # Перебираем файлы от 1 до MAX
    for ((i=1; i<=max; i++)); do
        if [ -s "${folder}/${i}.txt" ] && strategy_is_enabled "$type" "$i"; then
            echo "$i"
            return
        fi
    done
    
    # Если ничего не найдено - 0
    echo "0"
}

# Функция для генерации строки статуса стратегий
get_current_strategies_info() {
    local tcp_max udp_max
    tcp_max="$(strategy_max_num TCP)"
    udp_max="$(strategy_max_num UDP)"
    local s_udp=$(get_active_strat_num "$HOSTLIST_STATE_DIR/UDP/YT" "$udp_max" UDP)
    local s_tcp=$(get_active_strat_num "$HOSTLIST_STATE_DIR/TCP/YT" "$tcp_max" TCP)
    local s_gv=$(get_active_strat_num "$HOSTLIST_STATE_DIR/TCP/GV" "$tcp_max" TCP)
    local s_rkn=$(get_active_strat_num "$HOSTLIST_STATE_DIR/TCP/RKN" "$tcp_max" TCP)
    
    # Формируем красивую строку. Цвета можно менять.
    # Функция для окраски: 0 - серый, >0 - зеленый
    colorize_num() {
        if [ "$1" == "0" ]; then
            echo "${gray}Def${plain}"
        else
            echo "${green}$1${plain}"
        fi
    }

    echo -e "YT_UDP:$(colorize_num "$s_udp") YT_TCP:$(colorize_num "$s_tcp") YT_GV:$(colorize_num "$s_gv") RKN:$(colorize_num "$s_rkn")"
}

# Проверка обновлений config.default в репозитории без скачивания файла.
# Использует commits API с path=config.default и кэширует результат.
CONFIG_UPDATE_CACHE_DIR="/opt/zapret/extra_strats/cache"
CONFIG_UPDATE_TTL_SEC=21600
CONFIG_UPDATE_BASE_SHA_FILE="$CONFIG_UPDATE_CACHE_DIR/config_base_sha"
CONFIG_UPDATE_REMOTE_SHA_FILE="$CONFIG_UPDATE_CACHE_DIR/config_remote_sha"
CONFIG_UPDATE_REMOTE_DATE_FILE="$CONFIG_UPDATE_CACHE_DIR/config_remote_date"
CONFIG_UPDATE_LAST_CHECK_FILE="$CONFIG_UPDATE_CACHE_DIR/config_last_check"
CONFIG_UPDATE_HAS_UPDATE_FILE="$CONFIG_UPDATE_CACHE_DIR/config_has_update"
CONFIG_UPDATE_NOTICE=""

_config_update_latest_remote() {
    local api_url="https://api.github.com/repos/IndeecFOX/zapret4rocket/commits?path=config.default&per_page=1"
    local body remote_sha remote_date

    body="$(curl -s --max-time 8 "$api_url")"
    remote_sha="$(echo "$body" | grep -m1 '"sha"' | cut -d'"' -f4)"
    remote_date="$(echo "$body" | grep -m1 '"date"' | cut -d'"' -f4)"

    if [ -n "$remote_sha" ]; then
        echo "$remote_sha|$remote_date"
        return 0
    fi
    return 1
}

config_update_mark_repo_synced() {
    mkdir -p "$CONFIG_UPDATE_CACHE_DIR" 2>/dev/null || true
    local latest remote_sha remote_date now_ts
    latest="$(_config_update_latest_remote 2>/dev/null)" || return 0

    remote_sha="${latest%%|*}"
    remote_date="${latest#*|}"
    now_ts="$(date +%s 2>/dev/null || echo 0)"

    echo "$remote_sha" > "$CONFIG_UPDATE_BASE_SHA_FILE"
    echo "$remote_sha" > "$CONFIG_UPDATE_REMOTE_SHA_FILE"
    echo "$remote_date" > "$CONFIG_UPDATE_REMOTE_DATE_FILE"
    echo "$now_ts" > "$CONFIG_UPDATE_LAST_CHECK_FILE"
    echo "0" > "$CONFIG_UPDATE_HAS_UPDATE_FILE"
}

check_config_default_update_notice() {
    mkdir -p "$CONFIG_UPDATE_CACHE_DIR" 2>/dev/null || true

    local now_ts last_ts has_update base_sha remote_sha remote_date latest
    now_ts="$(date +%s 2>/dev/null || echo 0)"
    last_ts="$(cat "$CONFIG_UPDATE_LAST_CHECK_FILE" 2>/dev/null || echo 0)"
    has_update="$(cat "$CONFIG_UPDATE_HAS_UPDATE_FILE" 2>/dev/null || echo 0)"
    base_sha="$(cat "$CONFIG_UPDATE_BASE_SHA_FILE" 2>/dev/null || true)"
    remote_sha="$(cat "$CONFIG_UPDATE_REMOTE_SHA_FILE" 2>/dev/null || true)"
    remote_date="$(cat "$CONFIG_UPDATE_REMOTE_DATE_FILE" 2>/dev/null || true)"

    if [ $((now_ts - last_ts)) -ge "$CONFIG_UPDATE_TTL_SEC" ] || [ -z "$remote_sha" ]; then
        latest="$(_config_update_latest_remote 2>/dev/null)" || latest=""
        if [ -n "$latest" ]; then
            remote_sha="${latest%%|*}"
            remote_date="${latest#*|}"
            echo "$remote_sha" > "$CONFIG_UPDATE_REMOTE_SHA_FILE"
            echo "$remote_date" > "$CONFIG_UPDATE_REMOTE_DATE_FILE"
            echo "$now_ts" > "$CONFIG_UPDATE_LAST_CHECK_FILE"
        fi
    fi

    # Первая инициализация базы: не тревожим пользователя, пока не появится новое изменение после первого check.
    if [ -z "$base_sha" ] && [ -n "$remote_sha" ]; then
        echo "$remote_sha" > "$CONFIG_UPDATE_BASE_SHA_FILE"
        echo "0" > "$CONFIG_UPDATE_HAS_UPDATE_FILE"
        CONFIG_UPDATE_NOTICE=""
        return 0
    fi

    if [ -n "$base_sha" ] && [ -n "$remote_sha" ] && [ "$base_sha" != "$remote_sha" ]; then
        has_update=1
        echo "1" > "$CONFIG_UPDATE_HAS_UPDATE_FILE"
        if [ -n "$remote_date" ]; then
            CONFIG_UPDATE_NOTICE="В репозитории есть обновление config.default (UTC +0: $remote_date)"
        else
            CONFIG_UPDATE_NOTICE="В репозитории есть обновление config.default"
        fi
    else
        has_update=0
        echo "0" > "$CONFIG_UPDATE_HAS_UPDATE_FILE"
        CONFIG_UPDATE_NOTICE=""
    fi
}

strategy_params_file() {
    local type="$1"
    local num="$2"
    local dir
    dir="$(strategy_dir "$type")"

    if [ -s "$dir/${num}.txt" ]; then
        echo "$dir/${num}.txt"
    else
        echo ""
    fi
}

strategy_first_custom_num() {
    echo "$CUSTOM_STRATEGY_START"
}

read_strategy_params() {
    local file="$1"
    [ -s "$file" ] || return 1
    sed -n '1{s/^[[:space:]]*//;s/[[:space:]]*$//;p;q;}' "$file"
}

get_fooling_mode() {
    local mode
    mode="$(cat "$FOOLING_STATE_FILE" 2>/dev/null || true)"
    case "$mode" in
        ts|ts,badsum) echo "$mode"; return 0 ;;
    esac

    if [ ! -f /opt/zapret/config ]; then
        echo "ts,badsum"
    elif grep -q "fooling=ts,badsum" /opt/zapret/config 2>/dev/null; then
        echo "ts,badsum"
    else
        echo "ts"
    fi
}

toggle_fooling_mode_state() {
    mkdir -p "$HOSTLIST_STATE_DIR/cache" 2>/dev/null || true
    if [ "$(get_fooling_mode)" = "ts,badsum" ]; then
        echo "ts" > "$FOOLING_STATE_FILE"
    else
        echo "ts,badsum" > "$FOOLING_STATE_FILE"
    fi
}

get_fake_tls_sni() {
    local sni
    sni="$(cat "$SNI_STATE_FILE" 2>/dev/null || true)"
    [ -n "$sni" ] && { echo "$sni"; return 0; }

    sni="$(sed -n 's/.*--dpi-desync-fake-tls-mod=[^[:space:]]*sni=\([^,[:space:]]*\)[[:space:]].*/\1/p; s/.*--dpi-desync-fake-tls-mod=[^[:space:]]*sni=\([^,[:space:]]*\)$/\1/p' /opt/zapret/config 2>/dev/null | tail -n1)"
    [ -n "$sni" ] || sni="msn.com"
    echo "$sni"
}

set_fake_tls_sni_state() {
    local sni="$1"
    mkdir -p "$HOSTLIST_STATE_DIR/cache" 2>/dev/null || true
    echo "$sni" > "$SNI_STATE_FILE"
}

apply_strategy_overrides() {
    local params="$1"
    local fooling_mode sni

    fooling_mode="$(get_fooling_mode)"
    if [ "$fooling_mode" = "ts,badsum" ]; then
        params="$(echo "$params" | sed 's/fooling=ts,badsum/fooling=__Z4R_TS_BADSUM__/g; s/fooling=ts/fooling=ts,badsum/g; s/fooling=__Z4R_TS_BADSUM__/fooling=ts,badsum/g')"
    else
        params="$(echo "$params" | sed 's/fooling=ts,badsum/fooling=ts/g')"
    fi

    sni="$(get_fake_tls_sni)"
    if [ -n "$sni" ]; then
        params="$(echo "$params" | sed "s|\(--dpi-desync-fake-tls-mod=[^[:space:]]*sni=\)[^,[:space:]]*\([[:space:]]\)|\1${sni}\2|g; s|\(--dpi-desync-fake-tls-mod=[^[:space:]]*sni=\)[^,[:space:]]*$|\1${sni}|g")"
    fi

    echo "$params"
}

apply_config_overrides_file() {
    local file="$1"
    local tmp="${file}.override"
    local fooling_mode sni

    [ -f "$file" ] || return 1
    fooling_mode="$(get_fooling_mode)"
    sni="$(get_fake_tls_sni)"

    if [ "$fooling_mode" = "ts,badsum" ]; then
        sed 's/fooling=ts,badsum/fooling=__Z4R_TS_BADSUM__/g; s/fooling=ts/fooling=ts,badsum/g; s/fooling=__Z4R_TS_BADSUM__/fooling=ts,badsum/g' "$file" > "$tmp"
    else
        sed 's/fooling=ts,badsum/fooling=ts/g' "$file" > "$tmp"
    fi

    if [ -n "$sni" ]; then
        sed "s|\(--dpi-desync-fake-tls-mod=[^[:space:]]*sni=\)[^,[:space:]]*\([[:space:]]\)|\1${sni}\2|g; s|\(--dpi-desync-fake-tls-mod=[^[:space:]]*sni=\)[^,[:space:]]*$|\1${sni}|g" "$tmp" > "${tmp}.sni"
        mv -f "${tmp}.sni" "$tmp"
    fi

    mv -f "$tmp" "$file"
}

preserve_runtime_config_settings() {
    local old_config="$1"
    local new_config="$2"
    local fwtype flowoffload udp_ports
    local fw_expr flow_expr udp_expr voice_expr udp_games_expr
    local noop='s/$^//'

    [ -f "$old_config" ] || return 0
    [ -f "$new_config" ] || return 0
    [ "$old_config" = "$new_config" ] && return 0

    fw_expr="$noop"
    flow_expr="$noop"
    udp_expr="$noop"
    voice_expr="$noop"
    udp_games_expr="$noop"

    fwtype="$(sed -n 's|^FWTYPE=||p' "$old_config" 2>/dev/null | tail -n1)"
    case "$fwtype" in
        iptables|nftables|ipfw) fw_expr="s|^FWTYPE=.*|FWTYPE=${fwtype}|" ;;
    esac

    flowoffload="$(sed -n 's|^FLOWOFFLOAD=||p' "$old_config" 2>/dev/null | tail -n1)"
    case "$flowoffload" in
        donttouch|none|software|hardware) flow_expr="s|^FLOWOFFLOAD=.*|FLOWOFFLOAD=${flowoffload}|" ;;
    esac

    udp_ports="$(sed -n 's|^NFQWS_PORTS_UDP=||p' "$old_config" 2>/dev/null | tail -n1)"
    case "$udp_ports" in
        [0-9]*)
            case "$udp_ports" in
                *[!0-9,-]*) ;;
                *) udp_expr="s|^NFQWS_PORTS_UDP=.*|NFQWS_PORTS_UDP=${udp_ports}|" ;;
            esac
            ;;
    esac

    if grep -q '^--skip --filter-udp=50000' "$old_config" 2>/dev/null; then
        voice_expr='s|^--filter-udp=50000|--skip --filter-udp=50000|'
    elif grep -q '^--filter-udp=50000' "$old_config" 2>/dev/null; then
        voice_expr='s|^--skip --filter-udp=50000|--filter-udp=50000|'
    fi

    if grep -q '^--skip --filter-udp=1026' "$old_config" 2>/dev/null; then
        udp_games_expr='s|^--filter-udp=1026|--skip --filter-udp=1026|'
    elif grep -q '^--filter-udp=1026' "$old_config" 2>/dev/null; then
        udp_games_expr='s|^--skip --filter-udp=1026|--filter-udp=1026|'
    fi

    sed -e "$fw_expr" -e "$flow_expr" -e "$udp_expr" -e "$voice_expr" -e "$udp_games_expr" "$new_config" > "${new_config}.preserve"
    mv -f "${new_config}.preserve" "$new_config"
}

get_bezrazbor_num_from_config() {
    local config_file="${1:-/opt/zapret/config}"
    local src_start core line params file num max

    [ -f "$config_file" ] || return 0
    src_start="--filter-tcp=443,2053,2083,2087,2096,8443 --hostlist-exclude-domains=googlevideo.com --hostlist-exclude=$HOSTLIST_STATE_DIR/TCP/YT/List.txt"
    core="$(sed -n "s|.*$src_start \(.*\) --new.*|\1|p" "$config_file" | head -n 1)"
    [ -n "$core" ] || return 0
    [ "$core" = "--hostlist-domains=bezrazbor.disabled" ] && return 0

    max="$(strategy_max_num TCP)"
    num=1
    while [ "$num" -le "$max" ]; do
        file="$(strategy_params_file TCP "$num")"
        if [ -n "$file" ]; then
            params="$(read_strategy_params "$file")"
            params="$(apply_strategy_overrides "$params")"
            [ "$core" = "$params" ] && { echo "$num"; return 0; }
        fi
        num=$((num + 1))
    done
}

generate_strategy_lines_for_type() {
    local type="$1"
    local line_kind="$2"
    local max num file params

    max="$(strategy_builtin_max_num "$type")"
    num=1
    while [ "$num" -le "$max" ]; do
        file="$(strategy_params_file "$type" "$num")"
        if [ -n "$file" ]; then
            params="$(read_strategy_params "$file")"
            params="$(apply_strategy_overrides "$params")"
            case "$line_kind" in
                udp_yt) echo "--filter-udp=443 --hostlist-domains=none.dom --hostlist=$HOSTLIST_STATE_DIR/UDP/YT/${num}.txt $params --new" ;;
                tcp_user) echo "--filter-tcp=443,8443 --hostlist-domains=none.dom --hostlist-exclude-domains=googlevideo.com --hostlist-exclude=$HOSTLIST_STATE_DIR/TCP/YT/List.txt --hostlist=$HOSTLIST_STATE_DIR/TCP/temp/${num}.txt --hostlist=$HOSTLIST_STATE_DIR/TCP/User/${num}.txt $params --new" ;;
                tcp_gv) echo "--filter-tcp=443 --hostlist-domains=none.dom --hostlist=$HOSTLIST_STATE_DIR/TCP/GV/${num}.txt $params --new" ;;
                tcp_yt_rkn) echo "--filter-tcp=443,2053,2083,2087,2096,8443 --hostlist-domains=none.dom --hostlist=$HOSTLIST_STATE_DIR/TCP/YT/${num}.txt --hostlist=$HOSTLIST_STATE_DIR/TCP/RKN/${num}.txt $params --new" ;;
            esac
        fi
        num=$((num + 1))
    done

    max="$(strategy_custom_max_num "$type")"
    num="$CUSTOM_STRATEGY_START"
    while [ "$num" -le "$max" ]; do
        file="$(strategy_params_file "$type" "$num")"
        if [ -n "$file" ]; then
            params="$(read_strategy_params "$file")"
            params="$(apply_strategy_overrides "$params")"
            case "$line_kind" in
                udp_yt) echo "--filter-udp=443 --hostlist-domains=none.dom --hostlist=$HOSTLIST_STATE_DIR/UDP/YT/${num}.txt $params --new" ;;
                tcp_user) echo "--filter-tcp=443,8443 --hostlist-domains=none.dom --hostlist-exclude-domains=googlevideo.com --hostlist-exclude=$HOSTLIST_STATE_DIR/TCP/YT/List.txt --hostlist=$HOSTLIST_STATE_DIR/TCP/temp/${num}.txt --hostlist=$HOSTLIST_STATE_DIR/TCP/User/${num}.txt $params --new" ;;
                tcp_gv) echo "--filter-tcp=443 --hostlist-domains=none.dom --hostlist=$HOSTLIST_STATE_DIR/TCP/GV/${num}.txt $params --new" ;;
                tcp_yt_rkn) echo "--filter-tcp=443,2053,2083,2087,2096,8443 --hostlist-domains=none.dom --hostlist=$HOSTLIST_STATE_DIR/TCP/YT/${num}.txt --hostlist=$HOSTLIST_STATE_DIR/TCP/RKN/${num}.txt $params --new" ;;
            esac
        fi
        num=$((num + 1))
    done
}

generate_strategy_config_block() {
    local out="$1"
    local file params

    : > "$out"

    {
        echo "'Запасные стратегии UDP QUIC YouTube'"
        generate_strategy_lines_for_type UDP udp_yt

        echo "'Запасные стратегии только для TCP user domain листов имеющие приоритет над всеми другими, кроме ютубных'"
        generate_strategy_lines_for_type TCP tcp_user

        echo "'Запасные стратегии googlevideo.com'"
        generate_strategy_lines_for_type TCP tcp_gv

        echo "'Строка безразборного режима'"
        local bezr_num
        bezr_num="$(cat "$BEZRAZBOR_STATE_FILE" 2>/dev/null || true)"
        case "$bezr_num" in
            ''|*[!0-9]*) bezr_num="$(get_bezrazbor_num_from_config /opt/zapret/config)" ;;
        esac
        file="$(strategy_params_file TCP "$bezr_num")"
        if [ -n "$bezr_num" ] && [ -n "$file" ]; then
            params="$(read_strategy_params "$file")"
            params="$(apply_strategy_overrides "$params")"
            echo "--filter-tcp=443,2053,2083,2087,2096,8443 --hostlist-exclude-domains=googlevideo.com --hostlist-exclude=$HOSTLIST_STATE_DIR/TCP/YT/List.txt $params --new"
        else
            echo "--filter-tcp=443,2053,2083,2087,2096,8443 --hostlist-exclude-domains=googlevideo.com --hostlist-exclude=$HOSTLIST_STATE_DIR/TCP/YT/List.txt --hostlist-domains=bezrazbor.disabled --new"
        fi

        echo "'Запасные стратегии TCP YouTube интерфейса и остального РКН листа'"
        generate_strategy_lines_for_type TCP tcp_yt_rkn
    } >> "$out"
}

build_config_from_strategies() {
    local template="${1:-/opt/zapret/config.default}"
    local target="${2:-/opt/zapret/config}"
    local block tmp

    [ -f "$template" ] || return 1
    mkdir -p "$HOSTLIST_STATE_DIR/cache" 2>/dev/null || true
    ensure_strategy_hostlist_files

    block="$HOSTLIST_STATE_DIR/cache/strategy_block.$$"
    tmp="${target}.$$"
    generate_strategy_config_block "$block"

    if grep -q '# Z4R_STRATEGIES_START' "$template" 2>/dev/null; then
        awk -v block="$block" '
            BEGIN {
                while ((getline line < block) > 0) generated = generated line "\n"
            }
            /# Z4R_STRATEGIES_START/ {
                print
                printf "%s", generated
                skip = 1
                next
            }
            /# Z4R_STRATEGIES_END/ {
                skip = 0
                print
                next
            }
            !skip { print }
        ' "$template" > "$tmp"
    else
        cp -f "$template" "$tmp"
    fi

    apply_config_overrides_file "$tmp"
    preserve_runtime_config_settings "$target" "$tmp"
    mv -f "$tmp" "$target"
    rm -f "$block"
}

rebuild_config_and_restart() {
    build_config_from_strategies /opt/zapret/config.default /opt/zapret/config || {
        echo -e "${red}Ошибка пересборки /opt/zapret/config${plain}"
        return 1
    }
    /opt/zapret/init.d/sysv/zapret restart
    echo -e "${green}Config пересобран, zapret перезапущен.${plain}"
}

print_strategy_files_status() {
    local type="$1"
    local pending="${2:-}"
    local max builtin_max num enabled_file disabled_file state display_num
    max="$(strategy_max_num "$type")"
    builtin_max="$(strategy_builtin_max_num "$type")"

    echo -e "${cyan}${type}:${plain} $(strategy_variants_label "$type") включено"
    num=1
    while [ "$num" -le "$max" ]; do
        enabled_file="$(strategy_dir "$type")/${num}.txt"
        disabled_file="$(strategy_dir "$type")/${num}.disabled.txt"
        state=""
        if strategy_is_custom_num "$num"; then
            [ -s "$enabled_file" ] && state="вкл"
            [ -s "$disabled_file" ] && state="выкл"
            display_num="${yellow}${num}${plain}"
        else
            [ -s "$enabled_file" ] && state="вкл"
            [ -s "$disabled_file" ] && state="выкл"
            display_num="$num"
        fi
        if [ -n "$state" ] && echo "$pending" | grep -q -x -F "$num"; then
            case "$state" in
                вкл) state="выкл" ;;
                выкл) state="вкл" ;;
            esac
        fi
        [ -n "$state" ] && echo -e "  $display_num: $state"
        if [ "$num" -lt "$CUSTOM_STRATEGY_START" ] && [ "$num" -ge "$builtin_max" ]; then
            num="$CUSTOM_STRATEGY_START"
        else
            num=$((num + 1))
        fi
    done
}

toggle_strategy_file() {
    local type="$1"
    local num="$2"
    local dir enabled_file disabled_file
    dir="$(strategy_dir "$type")"
    enabled_file="$dir/${num}.txt"
    disabled_file="$dir/${num}.disabled.txt"

    case "$num" in
        ''|*[!0-9]*) echo "Неверный номер стратегии."; return 1 ;;
    esac

    if [ -s "$enabled_file" ]; then
        strategy_can_be_disabled_or_deleted "$type" "$num" "отключить" || return 1
        mv -f "$enabled_file" "$disabled_file"
        clear_strategy_hostlists_on_disable "$type" "$num"
        echo "Стратегия $type/$num отключена."
    elif [ -s "$disabled_file" ]; then
        mv -f "$disabled_file" "$enabled_file"
        echo "Стратегия $type/$num включена."
    else
        echo "Стратегия $type/$num не найдена."
        return 1
    fi

    ensure_strategy_hostlist_files_for_num "$type" "$num"
    return 0
}

next_custom_strategy_num() {
    local type="$1"
    local max
    max="$(strategy_custom_max_num "$type")"
    if [ "$max" -lt "$CUSTOM_STRATEGY_START" ]; then
        echo "$CUSTOM_STRATEGY_START"
    else
        echo $((max + 1))
    fi
}

add_custom_strategy_file() {
    local type="$1"
    local strategy_line="$2"
    local dir num file
    dir="$(strategy_dir "$type")"
    mkdir -p "$dir" 2>/dev/null || true

    strategy_line="$(echo "$strategy_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "$strategy_line" ] || { echo "Пустая стратегия не добавлена."; return 1; }

    num="$(next_custom_strategy_num "$type")"
    file="$dir/${num}.txt"
    echo "$strategy_line" > "$file"
    ensure_strategy_hostlist_files_for_num "$type" "$num"
    echo "Добавлена пользовательская стратегия $type/$num."
}

strategy_file_exists() {
    local type="$1"
    local num="$2"
    local dir
    dir="$(strategy_dir "$type")"
    [ -s "$dir/${num}.txt" ] || [ -s "$dir/${num}.disabled.txt" ]
}

strategy_usage_labels() {
    local type="$1"
    local num="$2"
    local usage="" bezr_num

    if [ "$type" = "UDP" ]; then
        [ -s "$HOSTLIST_STATE_DIR/UDP/YT/${num}.txt" ] && usage="${usage}${usage:+
}YouTube UDP QUIC"
        echo "$usage"
        return 0
    fi

    [ -s "$HOSTLIST_STATE_DIR/TCP/YT/${num}.txt" ] && usage="${usage}${usage:+
}YouTube TCP"
    [ -s "$HOSTLIST_STATE_DIR/TCP/GV/${num}.txt" ] && usage="${usage}${usage:+
}YouTube GV"
    [ -s "$HOSTLIST_STATE_DIR/TCP/RKN/${num}.txt" ] && usage="${usage}${usage:+
}RKN"
    [ -s "$HOSTLIST_STATE_DIR/TCP/User/${num}.txt" ] && usage="${usage}${usage:+
}User-домены"

    bezr_num="$(cat "$BEZRAZBOR_STATE_FILE" 2>/dev/null || true)"
    case "$bezr_num" in
        ''|*[!0-9]*) bezr_num="$(get_bezrazbor_num_from_config /opt/zapret/config)" ;;
    esac
    if [ "$bezr_num" = "$num" ]; then
        usage="${usage}${usage:+
}Безразборный режим"
    fi

    echo "$usage"
}

print_strategy_usage_error() {
    local type="$1"
    local num="$2"
    local action="$3"
    local usage="$4"

    echo -e "${red}Нельзя ${action} стратегию $type/$num - она выбрана в режимах:${plain}"
    echo "$usage"
}

strategy_can_be_disabled_or_deleted() {
    local type="$1"
    local num="$2"
    local action="$3"
    local usage

    usage="$(strategy_usage_labels "$type" "$num")"
    [ -z "$usage" ] && return 0
    [ "$usage" = "User-домены" ] && return 0

    print_strategy_usage_error "$type" "$num" "$action" "$usage"
    return 1
}

delete_strategy_hostlists_full() {
    local type="$1"
    local num="$2"

    if [ "$type" = "UDP" ]; then
        rm -f "$HOSTLIST_STATE_DIR/UDP/YT/${num}.txt"
        return 0
    fi

    rm -f "$HOSTLIST_STATE_DIR/TCP/RKN/${num}.txt" \
          "$HOSTLIST_STATE_DIR/TCP/User/${num}.txt" \
          "$HOSTLIST_STATE_DIR/TCP/YT/${num}.txt" \
          "$HOSTLIST_STATE_DIR/TCP/temp/${num}.txt" \
          "$HOSTLIST_STATE_DIR/TCP/GV/${num}.txt"
}

delete_custom_strategy_file() {
    local type="$1"
    local num="$2"
    local dir

    case "$num" in
        ''|*[!0-9]*) echo "Неверный номер стратегии."; return 1 ;;
    esac
    if [ "$num" -lt "$CUSTOM_STRATEGY_START" ]; then
        echo "Удалять можно только пользовательские стратегии с номером $CUSTOM_STRATEGY_START и выше."
        return 1
    fi

    dir="$(strategy_dir "$type")"
    if ! strategy_file_exists "$type" "$num"; then
        echo "Пользовательская стратегия $type/$num не найдена."
        return 1
    fi
    strategy_can_be_disabled_or_deleted "$type" "$num" "удалить" || return 1

    rm -f "$dir/${num}.txt" "$dir/${num}.disabled.txt"
    echo "Пользовательская стратегия $type/$num удалена."
}

show_custom_strategy_file() {
    local type="$1"
    local num="$2"
    local dir file=""

    case "$num" in
        ''|*[!0-9]*) echo "Неверный номер стратегии."; return 1 ;;
    esac
    if [ "$num" -lt "$CUSTOM_STRATEGY_START" ]; then
        echo "Просматривать здесь можно только пользовательские стратегии с номером $CUSTOM_STRATEGY_START и выше."
        return 1
    fi

    dir="$(strategy_dir "$type")"
    [ -s "$dir/${num}.txt" ] && file="$dir/${num}.txt"
    [ -z "$file" ] && [ -s "$dir/${num}.disabled.txt" ] && file="$dir/${num}.disabled.txt"
    [ -n "$file" ] || { echo "Пользовательская стратегия $type/$num не найдена."; return 1; }

    echo -e "${cyan}${type}/${num}:${plain}"
    cat "$file"
}

clear_strategy_selection_files() {
    local type="$1"
    local base_path="$2"
    local max num

    max="$(strategy_builtin_max_num "$type")"
    num=1
    while [ "$num" -le "$max" ]; do
        [ -e "$base_path/${num}.txt" ] && : > "$base_path/${num}.txt"
        num=$((num + 1))
    done

    max="$(strategy_custom_max_num "$type")"
    num="$CUSTOM_STRATEGY_START"
    while [ "$num" -le "$max" ]; do
        [ -e "$base_path/${num}.txt" ] && : > "$base_path/${num}.txt"
        num=$((num + 1))
    done
}

#Функция для функции подбора стратегий
try_strategies() {
    local count="$1"
    local base_path="$2"
    local list_file="$3"
    local final_action="$4"
    local strategy_type="TCP"
    local prev_strat=""
    case "$base_path" in
        */UDP/*) strategy_type="UDP" ;;
    esac
    
    read -re -p "Введите номер стратегии к которой перейти или Enter: " strat_num
    case "$strat_num" in
        ''|*[!0-9]*) strat_num=1 ;;
    esac
    if (( strat_num < 1 || strat_num > count )); then
        echo "Введено значение не из диапазона. Начинаем с 1 стратегии"
        strat_num=1
    fi

    # Предварительная очистка всех существующих файлов стратегий в папке
    clear_strategy_selection_files "$strategy_type" "$base_path"

    # Основной цикл перебора
    for ((strat_num=strat_num; strat_num<=count; strat_num++)); do
        if ! strategy_is_enabled "$strategy_type" "$strat_num"; then
            continue
        fi
        
        # Очищаем предыдущую реально попробованную стратегию
        if [ -n "$prev_strat" ]; then
            echo -n > "$base_path/${prev_strat}.txt"
        fi

        # Запись в файл текущей стратегии
        if [[ "$list_file" != "/dev/null" ]]; then
            # Режим списка (копируем весь файл)
            cp "$list_file" "$base_path/${strat_num}.txt"
        else
            # Режим одного домена
            echo "$user_domain" > "$base_path/${strat_num}.txt"
        fi
        
        echo "Стратегия номер $strat_num активирована"
        prev_strat="$strat_num"
        
        # Блок проверки доступности (curl)
        # Работает только для TCP стратегий
        if [[ "$strategy_type" == "TCP" ]]; then
             local TestURL=""
             
             # ЛОГИКА ВЫБОРА ДОМЕНА ДЛЯ ПРОВЕРКИ
             if [[ "$user_domain" == "googlevideo.com" ]]; then
                # 1. Если это GVideo - ищем живой кластер для проверки видеопотока
                local cluster
                cluster=$(get_yt_cluster_domain)
                TestURL="https://$cluster"
                echo "Проверка доступности (кластер): $cluster"
                
             elif [[ -z "$user_domain" ]]; then
                # 2. Если домен пустой (обычный режим YT) - проверяем доступ к самому сайту
                TestURL="https://www.youtube.com"
                
             else
                # 3. Для кастомных доменов и RKN проверяем сам введенный домен
                TestURL="https://$user_domain"
             fi
             
             check_access "$TestURL"
        fi
            
        read -re -p "Проверьте работу (1 - сохранить, 0 - отмена, Enter - далее): " answer_strat
        
        if [[ "$answer_strat" == "1" ]]; then
            echo "Стратегия $strat_num сохранена."
            send_stats  # Отправка телеметрии (если включена)
            
            # Если передано дополнительное действие (final_action), выполняем его
            if [[ -n "$final_action" ]]; then
				user_domain="$(echo "$user_domain" | sed 's/[[:space:]]\+/\n/g')"
                if ! confirm_user_hostlist_duplicates "$strat_num" "$user_domain"; then
                    echo -n > "$HOSTLIST_STATE_DIR/TCP/temp/${strat_num}.txt"
                    return
                fi
				echo -n > "$HOSTLIST_STATE_DIR/TCP/temp/${strat_num}.txt"
				echo "$user_domain" >> "$HOSTLIST_STATE_DIR/TCP/User/${strat_num}.txt"
            fi
            return
            
        elif [[ "$answer_strat" == "0" ]]; then
            # Сброс текущей стратегии при отмене
            echo -n > "$base_path/${strat_num}.txt"
            echo "Изменения отменены."
            return
        fi
    done

    # Если цикл закончился, а пользователь ничего не выбрал
    [ -n "$prev_strat" ] && echo -n > "$base_path/${prev_strat}.txt"
    echo "Все стратегии испробованы. Ничего не подошло."
    return
}

#Сама функция подбора стратегий
Strats_Tryer() {
  local mode_domain="$1"
  local answer_strat_mode=""
  local user_domain=""

  # ВАЖНО: теперь Strats_Tryer не рисует меню и не спрашивает режим сам.
  # Режим выбирается снаружи (strategies_submenu), а сюда приходит либо:
  # - "1".."4" (режим)
  # - или строка-домен (режим кастомного домена)

  case "$mode_domain" in
    "1"|"2"|"3"|"4")
      answer_strat_mode="$mode_domain"
      ;;
    *)
      # Если аргумент не похож на режим — считаем, что это домен
      answer_strat_mode="5"
      user_domain="$mode_domain"
      ;;
  esac

  case "$answer_strat_mode" in
    "1")
      echo "Подбор для хост-листа YouTube с видеопотоком (UDP QUIC - браузеры, моб. приложения). Ранее заданная стратегия этого листа сброшена в дефолт."
      #вывод подсказки
      show_hint "UDP"
      try_strategies "$(strategy_max_num UDP)" "$HOSTLIST_STATE_DIR/UDP/YT" "$HOSTLIST_STATE_DIR/UDP/YT/List.txt" ""
      ;;
    "2")
      echo "Подбор для хост-листа YouTube (TCP - сам интерфейс. Без видео-домена). Ранее заданная стратегия этого листа сброшена в дефолт."
      #вывод подсказки
      show_hint "TCP"
      try_strategies "$(strategy_max_num TCP)" "$HOSTLIST_STATE_DIR/TCP/YT" "$HOSTLIST_STATE_DIR/TCP/YT/List.txt" ""
      ;;
    "3")
      echo "Подбор для googlevideo.com (Видеопоток YouTube). Ранее заданная стратегия этого листа сброшена в дефолт."
      #на всякий случай убираем GV из листа YT
      [ -f "$HOSTLIST_STATE_DIR/TCP/YT/List.txt" ] && \
        sed -i '/googlevideo.com/d' "$HOSTLIST_STATE_DIR/TCP/YT/List.txt"
      user_domain="googlevideo.com"
      #вывод подсказки
      show_hint "GV"
      try_strategies "$(strategy_max_num TCP)" "$HOSTLIST_STATE_DIR/TCP/GV" "/dev/null" ""
      ;;
    "4")
      echo "Подбор для хост-листа основных доменов блока RKN. Проверка доступности задана на домен meduza.io. Ранее заданная стратегия этого листа сброшена в дефолт."
      local numRKN=1
      local tcp_max
      tcp_max="$(strategy_max_num TCP)"
      while [ "$numRKN" -le "$tcp_max" ]; do
        echo -n > "$HOSTLIST_STATE_DIR/TCP/RKN/${numRKN}.txt"
        numRKN=$((numRKN + 1))
      done
      user_domain="meduza.io"
      #вывод подсказки
      show_hint "RKN"
      try_strategies "$tcp_max" "$HOSTLIST_STATE_DIR/TCP/RKN" "$HOSTLIST_STATE_DIR/TCP/RKN/List.txt" ""
      ;;
    "5")
      echo "Режим ручного указания домена"
      # раньше домен спрашивался тут, но теперь ввод домена делается в сабменю
      if [ -z "$user_domain" ]; then
        echo "Домен не задан. Отмена."
        return 0
      fi
      echo "Введён домен: $user_domain"

      try_strategies "$(strategy_max_num TCP)" "$HOSTLIST_STATE_DIR/TCP/temp" "/dev/null" \
        "echo -n > \"$HOSTLIST_STATE_DIR/TCP/temp/\${strat_num}.txt\"; \
         echo \"$user_domain\" >> \"$HOSTLIST_STATE_DIR/TCP/User/\${strat_num}.txt\""
      ;;
    *)
      echo "Пропуск подбора альтернативной стратегии"
      return 0
      ;;
  esac
}
