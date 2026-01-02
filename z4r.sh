#!/bin/bash

set -e
#Переменная содержащая версию на случай невозможности получить информацию о lastest с github
DEFAULT_VER="72.5"

#Чтобы удобнее красить текст
plain='\033[0m'
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
pink='\033[0;35m'
cyan='\033[0;36m'
Fplain='\033[1;37m'
Fred='\033[0;31m'
Fgreen='\033[0;32m'
Fyellow='\033[0;33m'
Fblue='\033[0;34m'
Fpink='\033[0;35m'
Fcyan='\033[0;36m'
Bplain='\033[47m'
Bred='\033[41m'
Bgreen='\033[42m'
Byellow='\033[43m'
Bblue='\033[44m'
Bpink='\033[45m'
Bcyan='\033[46m'



# ---- Provider detector integration by AloofLibra ----
# Используем provider.txt как основной источник правды (просто строка "Provider - City")
PROVIDER_CACHE="/opt/zapret/extra_strats/cache/provider.txt"
PROVIDER_MENU="Не определён"
PROVIDER_INIT_DONE=0

# Вспомогательная функция: делает запрос к API и пишет в файл
_detect_api_simple() {
    # 1. Скачиваем ответ во временный файл (чтобы точно видеть, что пришло)
    local tmp_file="/tmp/z4r_provider_debug.txt"
    curl -s --max-time 10 "http://ip-api.com/line?fields=isp,city" > "$tmp_file"

    # 2. Читаем построчно (без пайпов, чтобы не терять код возврата)
    local p_name=$(head -n 1 "$tmp_file")
    local p_city=$(head -n 2 "$tmp_file" | tail -n 1)

    # 3. Чистим жестко (оставляем только латиницу, цифры и пробелы)
    # Удаляем вообще все странные символы
    p_name=$(echo "$p_name" | tr -cd 'a-zA-Z0-9 ._-')
    p_city=$(echo "$p_city" | tr -cd 'a-zA-Z0-9 ._-')

    # Убираем дублирование, если API вернул 1 строку
    if [ "$p_city" = "$p_name" ]; then p_city=""; fi

    # 4. Формируем результат
    local res="$p_name"
    if [ -n "$p_city" ]; then
        res="$res - $p_city"
    fi
    
       # 5. Проверка результата перед записью
    if [ -n "$res" ]; then
        mkdir -p "$(dirname "$PROVIDER_CACHE")"
        
        echo "$res" > "$PROVIDER_CACHE"
    else

        echo "DEBUG: Результат парсинга пустой! (Raw: $(cat $tmp_file))" >&2
    fi
    
    # Чистим за собой
    rm -f "$tmp_file"
}

provider_init_once() {
  [ "$PROVIDER_INIT_DONE" = "1" ] && return 0
  PROVIDER_INIT_DONE=1

  # Если кэша нет или он пустой — пробуем определить
  if [ ! -s "$PROVIDER_CACHE" ]; then
    echo "Определяем провайдера..."
    _detect_api_simple
  fi

  # Читаем результат в переменную меню
  if [ -s "$PROVIDER_CACHE" ]; then
      PROVIDER_MENU="$(cat "$PROVIDER_CACHE")"
  else
      PROVIDER_MENU="Не определён"
  fi
}

provider_force_redetect() {
  echo "Обновляем данные о провайдере..."
  rm -f "$PROVIDER_CACHE"
  _detect_api_simple
  
  if [ -s "$PROVIDER_CACHE" ]; then
      PROVIDER_MENU="$(cat "$PROVIDER_CACHE")"
  else
      PROVIDER_MENU="Не удалось определить"
  fi
}

provider_set_manual_menu() {
  read -re -p "Провайдер (например MTS/Beeline): " p
  read -re -p "Город (можно пусто): " c
  
  # Чистим ввод
  p=$(echo "$p" | tr -cd '[:alnum:] ._-')
  c=$(echo "$c" | tr -cd '[:alnum:] ._-')
  
  local res="$p"
  [ -n "$c" ] && res="$res - $c"
  
  mkdir -p "$(dirname "$PROVIDER_CACHE")"
  echo "$res" > "$PROVIDER_CACHE"
  PROVIDER_MENU="$res"
}
# ---- /Provider detector integration by AloofLibra ----

# ---- Telemetry module integration by AloofLibra ----
# Настройки Google Forms
STATS_FORM_ID="1FAIpQLScrUf7Pybm0n61aK8aZuxuAR8KhyNYZ-X0xjSUS8K72SmEhPw"
ENTRY_UUID="entry.1346249141"
ENTRY_ISP="entry.2008245653"
ENTRY_UDP="entry.592144534"
ENTRY_TCP="entry.1826276405"
ENTRY_RKN="entry.1527830884"

# 2. Пути к файлам (используем простые форматы)
CACHE_DIR="/opt/zapret/extra_strats/cache"
TELEMETRY_CFG="$CACHE_DIR/telemetry.config"
PROVIDER_TXT="$CACHE_DIR/provider.txt"

# Помощник: находит номер активной стратегии (ищет непустой файл 1.txt ... N.txt)
get_active_strat_num() {
    local dir="$1"
    local max="$2"
    for i in $(seq 1 "$max"); do 
        if [ -s "$dir/$i.txt" ]; then 
            echo "$i"
            return
        fi
    done
    echo "0"
}

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
            *) tel_enabled="0" ;;
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
    local s_rkn=$(get_active_strat_num "/opt/zapret/extra_strats/TCP/RKN" 17)

    # 3. Отправка в Google Forms (Тихий режим, в фоне &)
    curl -sL --max-time 10 \
        -d "$ENTRY_UUID=$tel_uuid" \
        -d "$ENTRY_ISP=$my_isp" \
        -d "$ENTRY_UDP=$s_udp" \
        -d "$ENTRY_TCP=$s_tcp" \
        -d "$ENTRY_RKN=$s_rkn" \
        "https://docs.google.com/forms/d/e/$STATS_FORM_ID/formResponse" > /dev/null 2>&1 &
}
# ---- /Telemetry module integration by AloofLibra ----

# ---- ZEFEER PREMIUM (777/999) ----
# Сделано исключительно ради мемов. Практического смысла не несёт. (code by AloofLibra)
PREMIUM_FLAG="$CACHE_DIR/premium.enabled"
PREMIUM_TITLE_FILE="$CACHE_DIR/premium.title"

rand_from_list() {
  # usage: rand_from_list "a" "b" "c"
  local n=$#
  (( n == 0 )) && return 1
  local idx=$(( (RANDOM % n) + 1 ))
  eval "echo \"\${$idx}\""
}

spinner_for_seconds() {
  local seconds="${1:-2}"
  local msg="${2:-Работаем}"
  local frames="|/-\\"
  local i=0
  local end=$((SECONDS + seconds))

local _had_tput=0
  if command -v tput >/dev/null 2>&1; then
    _had_tput=1
    tput civis
    trap 'tput cnorm; trap - EXIT INT TERM' EXIT INT TERM
  fi

  while (( SECONDS < end )); do
    i=$(( (i + 1) % 4 ))
    # \r + \033[2K: в начало строки и стереть строку
    printf "\r\033[2K%s... [%c]" "$msg" "${frames:$i:1}"
    sleep 1
  done
  printf "\r\033[2K%s... [OK]\n" "$msg"

  if (( _had_tput )); then
    tput cnorm
    trap - EXIT INT TERM
  fi
}

premium_get_or_set_title() {
  mkdir -p "$CACHE_DIR"
  if [[ -s "$PREMIUM_TITLE_FILE" ]]; then
    cat "$PREMIUM_TITLE_FILE"
    return 0
  fi

  local title
  title="$(rand_from_list \
    "Граф Дезинхрона" \
    "Барон QUIC'а" \
    "Хранитель Hostlist'ов" \
    "Лорд --new" \
    "Грандмастер FakeTLS" \
    "Архитектор Сплитов" \
    "Повелитель RST (легальный)" \
    "Смотрящий за ipset'ом" \
    "Владыка TTL (ненадолго)" \
    "Амбассадор «Тест не точен»" \
  )"

  echo "$title" > "$PREMIUM_TITLE_FILE"
  echo "$title"
}

zefeer_premium_777() {
  mkdir -p "$CACHE_DIR"

  if [[ -f "$PREMIUM_FLAG" ]]; then
    local title
    title="$(premium_get_or_set_title)"
    echo -e "${yellow}ZEFEER PREMIUM уже активирован.${plain}"
    echo -e "Ваш титул: ${green}${title}${plain}"
    return 0
  fi

  echo -e "${yellow}Подключаемся к платёжному шлюзу...${plain}"
  spinner_for_seconds 2 "Проверяем поддержку проекта"

  # Фальш-результат
  local verdict
  verdict="$(rand_from_list \
    "Транзакция не найдена, но найден хороший человек." \
    "Оплата не прошла, зато прошли вы. В сердечко." \
    "Биллинг лежит. Premium — стоит." \
    "Счёт не выставлялся. Списали уважение." \
    "Донат не обнаружен. Обнаружена смелость нажать 777." \
  )"
  echo -e "${green}${verdict}${plain}"

  local title
  title="$(premium_get_or_set_title)"
  echo -e "Premium активирован ${green}ヽ(o^ ^o)ﾉ ${plain}"
  echo -e "Присвоен титул: ${pink}${title}${plain}"

  : > "$PREMIUM_FLAG"
}

zefeer_space_999() {
  echo -e "${cyan}Секретный протокол 999: попытка связи с космосом...${plain}"
  spinner_for_seconds 6 "Наводим тарелку на созвездие Пакетных Потерь"

  local excuse
  excuse="$(rand_from_list \
    "Меркурий не в том доме." \
    "Вспышка на Солнце сбила сигнал." \
    "Ретроградный NAT. Портал закрыт." \
    "Слишком много DPI на орбите — сигнал дропнули." \
    "Космос ответил RST." \
    "Сигнал ушёл по QUIC, а обратно пришёл по SMTP." \
    "Спутник занят: обновляет hostlist." \
    "Астральный ipset переполнен." \
    "Связь есть, но только с IPv6, а вы в IPv4 настроении." \
    "Сбой калибровки антенны: /dev/space не найден." \
  )"

  echo -e "${red}Ошибка связи:${plain} ${yellow}${excuse}${plain}"
}
# ---- /ZEFEER PREMIUM by AloofLibra ----

# ---- Recomendations module by AloofLibra ----
RECS_URL="https://raw.githubusercontent.com/AloofLibra/zapret4rocket/master/recommendations.txt"
RECS_FILE="/opt/zapret/extra_strats/cache/recommendations.txt"

# 1. Функция обновления базы (в фоне)
update_recommendations() {
    mkdir -p "$(dirname "$RECS_FILE")"

    # Проверка: если файл существует И он моложе 1 дня (24 часа) - выходим.
    # -mtime -1 означает "изменен менее 1 дня назад"
    if [ -f "$RECS_FILE" ] && [ -n "$(find "$RECS_FILE" -mtime -1 2>/dev/null)" ]; then
        # Файл свежий, обновлять не нужно
        return 0
    fi

    # Если файла нет или он старый - качаем
    curl -s --max-time 5 "$RECS_URL" -o "$RECS_FILE" || rm -f "$RECS_FILE"
}

# 2. Функция показа подсказки (Logic + UI)
show_hint() {
    local strat_type="$1" # UDP, TCP или RKN
    local my_isp=""
    
    # А. Узнаем провайдера
    if [ -s "/opt/zapret/extra_strats/cache/provider.txt" ]; then
        my_isp=$(cat "/opt/zapret/extra_strats/cache/provider.txt")
    fi
    
    # Б. Проверяем наличие базы
    if [ -z "$my_isp" ] || [ ! -f "$RECS_FILE" ]; then
        return
    fi
    
    # В. Ищем строку (grep -F для безопасности спецсимволов)
    local line=$(grep -F "$my_isp|" "$RECS_FILE" | head -n 1)
    [ -z "$line" ] && return
    
    # Г. Парсим
    # Формат: ISP|UDP:x|TCP:y|RKN:z
    local part=""
    case "$strat_type" in
        "UDP") part=$(echo "$line" | cut -d'|' -f2 | cut -d':' -f2) ;;
        "TCP") part=$(echo "$line" | cut -d'|' -f3 | cut -d':' -f2) ;;
        "RKN") part=$(echo "$line" | cut -d'|' -f4 | cut -d':' -f2) ;;
    esac
    
    # Д. Выводим
    if [ -n "$part" ] && [ "$part" != "-" ]; then
        echo ""
        echo -e "${cyan}💡 Подсказка:${plain} Пользователи ${green}$my_isp${plain} часто выбирают: ${yellow}$part${plain}"
        echo -e "Попробуйте начать с них."
        echo ""
    fi
}
# ---- /Recomendations module by AloofLibra ----

#___Сначала идут анонсы функций____
# Функция определяет номер активной стратегии в указанной папке
# Использование: get_active_strat_num "/path/to/folder" MAX_COUNT
get_active_strat_num() {
    local folder="$1"
    local max="$2"
    local i
    
    # Перебираем файлы от 1 до MAX
    for ((i=1; i<=max; i++)); do
        if [ -s "${folder}/${i}.txt" ]; then
            echo "$i"
            return
        fi
    done
    
    # Если ничего не найдено - 0
    echo "0"
}

# Функция для генерации строки статуса стратегий
get_current_strategies_info() {
    local s_udp=$(get_active_strat_num "/opt/zapret/extra_strats/UDP/YT" 8)
    local s_tcp=$(get_active_strat_num "/opt/zapret/extra_strats/TCP/YT" 17)
    local s_gv=$(get_active_strat_num "/opt/zapret/extra_strats/TCP/GV" 17)
    local s_rkn=$(get_active_strat_num "/opt/zapret/extra_strats/TCP/RKN" 17)
    
    # Формируем красивую строку. Цвета можно менять.
    # Функция для окраски: 0 - серый, >0 - зеленый
    colorize_num() {
        if [ "$1" == "0" ]; then
            echo "${gray}Def${plain}"
        else
            echo "${green}$1${plain}"
        fi
    }

    echo -e "UDP:$(colorize_num "$s_udp") TCP:$(colorize_num "$s_tcp") GV:$(colorize_num "$s_gv") RKN:$(colorize_num "$s_rkn")"
}

get_yt_cluster_domain() {
    local letters_list_a=('u' 'z' 'p' 'k' 'f' 'a' '5' '0' 'v' 'q' 'l' 'g' 'b' '6' '1' 'w' 'r' 'm' 'h' 'c' '7' '2' 'x' 's' 'n' 'i' 'd' '8' '3' 'y' 't' 'o' 'j' 'e' '9' '4' '-')
    local letters_list_b=('0' '1' '2' '3' '4' '5' '6' '7' '8' '9' 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 'o' 'p' 'q' 'r' 's' 't' 'u' 'v' 'w' 'x' 'y' 'z' '-')
    letters_map_a="${letters_list_a[*]}"
    letters_map_b="${letters_list_b[*]}"
    cluster_codename=$(curl -s --max-time 2 "https://redirector.xn--ngstr-lra8j.com/report_mapping?di=no"| sed -n 's/.*=>[[:space:]]*\([^ (:)]*\).*/\1/p')
	#Второй раз для пробития нерелевантного ответа
	cluster_codename=$(curl -s --max-time 2 "https://redirector.xn--ngstr-lra8j.com/report_mapping?di=no"| sed -n 's/.*=>[[:space:]]*\([^ (:)]*\).*/\1/p')

    [ -z "$cluster_codename" ] && {
        echo "Не удалось получить cluster_codename. Используем тогда rr1---sn-5goeenes.googlevideo.com" >&2
		echo "rr1---sn-5goeenes.googlevideo.com"
        return
    }

	local converted_name=""
    local i char idx a b
    for ((i=0; i<${#cluster_codename}; i++)); do
        char="${cluster_codename:$i:1}"
        idx=0
        for a in $letters_map_a; do
            [ "$a" = "$char" ] && break
            idx=$((idx+1))
        done
        b=$(echo "$letters_map_b" | cut -d' ' -f $((idx+1)))
        converted_name="${converted_name}${b}"
    done
    echo "rr1---sn-${converted_name}.googlevideo.com"
}

check_access() {
	local TestURL="$1"
	# Проверка TLS 1.2
	if curl --tls-max 1.2 --max-time 1 -s -o /dev/null "$TestURL"; then
		echo -e "${green}Есть ответ по TLS 1.2 (важно для ТВ и т.п.). ${yellow}Тест может быть ошибочен.${plain}"
	else
		echo -e "${yellow}Нет ответа по TLS 1.2 (важно для ТВ и т.п.) Таймаут 2сек. ${red}Проверьте доступность вручную. Возможно ошибка теста.${plain}"
	fi
	# Проверка TLS 1.3
	if curl --tlsv1.3 --max-time 1 -s -o /dev/null "$TestURL"; then
		echo -e "${green}Есть ответ по TLS 1.3 (важно в основном для всего современного) ${yellow}Тест может быть ошибочен.${plain}"
	else
		echo -e "${yellow}Нет ответа по TLS 1.3 (важно в основном для всего современного) Таймаут 2сек. ${red}Проверьте доступность вручную. Возможно ошибка теста.${plain}"
	fi
}

check_access_list() {
   echo "Проверка доступности youtube.com (YT TCP)"
   check_access "https://www.youtube.com/"
   echo "Проверка доступности $(get_yt_cluster_domain) (YT TCP)"
   check_access "https://$(get_yt_cluster_domain)"
   echo "Проверка доступности meduza.io (RKN list)"
   check_access "https://meduza.io"
   echo "Проверка доступности www.instagram.com (RKN list + нужен рабочий DNS)"
   check_access "https://www.instagram.com/"
}

exit_to_menu() {
   read -p "Enter для выхода в меню"
   get_menu
}

#Запрос на резервирование настроек в подборе стратегий
backup_strats() {
  if [ -d /opt/zapret/extra_strats ]; then
    read -re -p $'\033[0;33mХотите сохранить текущие настройки ручного подбора стратегий? Не рекомендуется. (5 - сохранить, Enter - нет\n0 - прервать операцию): \033[0m' answer_backup
    if [[ "$answer_backup" == "5" ]]; then
		cp -rf /opt/zapret/extra_strats /opt/
  		echo "Настройки подбора резервированы."
	elif [[ "$answer_backup" == "0" ]]; then
		exit_to_menu
	fi
	answer_backup=""
	read -re -p $'\033[0;33mХотите сохранить добавленные в лист исключений домены? Не рекомендуется. (\"5\" - сохранить, Enter - нет): \033[0m' answer_backup
	if [[ "$answer_backup" == "5" ]]; then
		cp -f /opt/zapret/lists/netrogat.txt /opt/
       	echo "Лист исключений резервирован."
  	fi	
  fi
}

#Раскомменчивание юзера под keenetic или merlin
change_user() {
   if /opt/zapret/nfq/nfqws --dry-run --user="nobody" 2>&1 | grep -q "queue"; then
    echo "WS_USER=nobody"
	sed -i 's/^#\(WS_USER=nobody\)/\1/' /opt/zapret/config.default
   elif /opt/zapret/nfq/nfqws --dry-run --user="$(head -n1 /etc/passwd | cut -d: -f1)" 2>&1 | grep -q "queue"; then
    echo "WS_USER=$(head -n1 /etc/passwd | cut -d: -f1)"
    sed -i "s/^#WS_USER=nobody$/WS_USER=$(head -n1 /etc/passwd | cut -d: -f1)/" "/opt/zapret/config.default"
   else
    echo -e "${yellow}WS_USER не подошёл. Скорее всего будут проблемы. Если что - пишите в саппорт${plain}"
   fi
}

#Создаём папки и забираем файлы папок lists, fake, extra_strats, копируем конфиг, скрипты для войсов DS, WA, TG
get_repo() {
 mkdir -p /opt/zapret/lists /opt/zapret/extra_strats/TCP/{RKN,User,YT,temp,GV} /opt/zapret/extra_strats/UDP/YT
 for listfile in cloudflare-ipset.txt cloudflare-ipset_v6.txt netrogat.txt russia-discord.txt russia-youtube-rtmps.txt russia-youtube.txt russia-youtubeQ.txt tg_cidr.txt; do curl -L -o /opt/zapret/lists/$listfile https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/lists/$listfile; done
 curl -L "https://github.com/IndeecFOX/zapret4rocket/raw/master/fake_files.tar.gz" | tar -xz -C /opt/zapret/files/fake
 curl -L -o /opt/zapret/extra_strats/UDP/YT/List.txt https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/UDP/YT/List.txt
 curl -L -o /opt/zapret/extra_strats/TCP/RKN/List.txt https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/TCP/RKN/List.txt
 curl -L -o /opt/zapret/extra_strats/TCP/YT/List.txt https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/TCP/YT/List.txt
 touch /opt/zapret/lists/autohostlist.txt /opt/zapret/extra_strats/UDP/YT/{1..8}.txt /opt/zapret/extra_strats/TCP/RKN/{1..17}.txt /opt/zapret/extra_strats/TCP/User/{1..17}.txt /opt/zapret/extra_strats/TCP/YT/{1..17}.txt /opt/zapret/extra_strats/TCP/GV/{1..17}.txt /opt/zapret/extra_strats/TCP/temp/{1..17}.txt
 if [ -d /opt/extra_strats ]; then
  rm -rf /opt/zapret/extra_strats
  mv /opt/extra_strats /opt/zapret/
  echo "Востановление настроек подбора из резерва выполнено."
 fi
 if [ -f "/opt/netrogat.txt" ]; then
   mv -f /opt/netrogat.txt /opt/zapret/lists/netrogat.txt
   echo "Востановление листа исключений выполнено."
 fi
 #Копирование нашего конфига на замену стандартному и скриптов для войсов DS, WA, TG
 curl -L -o /opt/zapret/config.default https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/config.default
 if command -v nft >/dev/null 2>&1; then
  sed -i 's/^FWTYPE=iptables$/FWTYPE=nftables/' "/opt/zapret/config.default"
 fi
 curl -L -o /opt/zapret/init.d/sysv/custom.d/50-stun4all https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-stun4all
 curl -L -o /opt/zapret/init.d/sysv/custom.d/50-discord-media https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-discord-media
 cp -f /opt/zapret/init.d/sysv/custom.d/50-stun4all /opt/zapret/init.d/openwrt/custom.d/50-stun4all
 cp -f /opt/zapret/init.d/sysv/custom.d/50-discord-media /opt/zapret/init.d/openwrt/custom.d/50-discord-media

# cache
mkdir -p /opt/zapret/extra_strats/cache

}

#Функция для функции подбора стратегий
try_strategies() {
    local count="$1"
    local base_path="$2"
    local list_file="$3"
    local final_action="$4"
    
    read -re -p "Введите номер стратегии к которой перейти или Enter: " strat_num
    if (( strat_num < 1 || strat_num > count )); then
        echo "Введено значение не из диапазона. Начинаем с 1 стратегии"
        strat_num=1
    fi

    # Предварительная очистка всех файлов стратегий в папке
    for ((clr_txt=1; clr_txt<=count; clr_txt++)); do
        echo -n > "$base_path/${clr_txt}.txt"
    done

    # Основной цикл перебора
    for ((strat_num=strat_num; strat_num<=count; strat_num++)); do
        
        # Очищаем файл предыдущей стратегии (чтобы не было дублей)
        if [[ $strat_num -ge 2 ]]; then
            prev=$((strat_num - 1))
            echo -n > "$base_path/${prev}.txt"
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
        
        # Блок проверки доступности (curl)
        # Работает только для TCP стратегий
        if [[ "$count" == "17" ]]; then
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
                eval "$final_action"
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
    echo -n > "$base_path/${count}.txt"
    echo "Все стратегии испробованы. Ничего не подошло."
    exit_to_menu
}

#Сама функция подбора стратегий
Strats_Tryer() {
	local mode_domain="$1"
	
	if [ -z "$mode_domain" ]; then
		# если аргумент не передан — спрашиваем вручную
		echo -e '\033[33mПодобрать стратегию? (1-5 или Enter для отмены):\033[32m
	1. YouTube с видеопотоком (UDP QUIC). \033[0m8 вариантов\033[32m
	2. YouTube (TCP. Интерфейс). \033[0m17 вариантов\033[32m
	3. YouTube (TCP. Видеопоток/GV домен). \033[0m17 вариантов\033[32m
	4. RKN (Популярные блокированные сайты. Дискорд в т.ч.). \033[0m17 вариантов\033[32m
	5. Отдельный домен. \033[0m17 вариантов'	
		read -re -p "" answer_strat_mode
	else
		if [ "${#mode_domain}" -gt 1 ]; then
			answer_strat_mode="4"
			user_domain="$mode_domain"
		else
			answer_strat_mode="$mode_domain"
		fi
	fi
	
    case "$answer_strat_mode" in
        "1")
            echo "Подбор для хост-листа YouTube с видеопотоком (UDP QUIC - браузеры, моб. приложения). Ранее заданная стратегия этого листа сброшена в дефолт."
			#вывод подсказки
			show_hint "UDP"
            try_strategies 8 "/opt/zapret/extra_strats/UDP/YT" "/opt/zapret/extra_strats/UDP/YT/List.txt" ""
            ;;
        "2")
            echo "Подбор для хост-листа YouTube (TCP - сам интерфейс. Без видео-домена). Ранее заданная стратегия этого листа сброшена в дефолт."
			#вывод подсказки
			show_hint "TCP"
            try_strategies 17 "/opt/zapret/extra_strats/TCP/YT" "/opt/zapret/extra_strats/TCP/YT/List.txt" ""
            ;;
        "3")
			echo "Подбор для googlevideo.com (Видеопоток YouTube). Ранее заданная стратегия этого листа сброшена в дефолт."
			#на всякий случай убираем GV из листа YT
			[ -f "/opt/zapret/extra_strats/TCP/YT/List.txt" ] && \
    			sed -i '/googlevideo.com/d' "/opt/zapret/extra_strats/TCP/YT/List.txt"
			user_domain="googlevideo.com"
			#вывод подсказки
			#закомментировано, т.к. пока не поддерживается бэком
			#show_hint "TCP"
            try_strategies 17 "/opt/zapret/extra_strats/TCP/GV" "/dev/null" ""
            ;;
		"4")
            echo "Подбор для хост-листа основных доменов блока RKN. Проверка доступности задана на домен meduza.io. Ранее заданная стратегия этого листа сброшена в дефолт."
			for numRKN in {1..17}; do
				echo -n > "/opt/zapret/extra_strats/TCP/RKN/${numRKN}.txt"
			done
			user_domain="meduza.io"
			#вывод подсказки
			show_hint "RKN"
            try_strategies 17 "/opt/zapret/extra_strats/TCP/RKN" "/opt/zapret/extra_strats/TCP/RKN/List.txt" ""
            ;;
        "5")
            echo "Режим ручного указания домена"
			if [ -z "$mode_domain" ]; then
				read -re -p "Введите домен (например, mydomain.com): " user_domain
			fi
			echo "Введён домен: $user_domain"

            try_strategies 17 "/opt/zapret/extra_strats/TCP/temp" "/dev/null" \
            "echo -n > \"/opt/zapret/extra_strats/TCP/temp/\${strat_num}.txt\"; \
             echo \"$user_domain\" >> \"/opt/zapret/extra_strats/TCP/User/\${strat_num}.txt\""
            ;;
        *)
            echo "Пропуск подбора альтернативной стратегии"
            ;;
    esac
}

#Удаление старого запрета, если есть
remove_zapret() {
 if [ -f "/opt/zapret/init.d/sysv/zapret" ] && [ -f "/opt/zapret/config" ]; then
 	/opt/zapret/init.d/sysv/zapret stop
 fi
 if [ -f "/opt/zapret/config" ] && [ -f "/opt/zapret/uninstall_easy.sh" ]; then
     echo "Выполняем zapret/uninstall_easy.sh"
     sh /opt/zapret/uninstall_easy.sh
     echo "Скрипт uninstall_easy.sh выполнен."
 else
     echo "zapret не инсталлирован в систему. Переходим к следующему шагу."
 fi
 if [ -d "/opt/zapret" ]; then
     echo "Удаляем папку zapret"
     rm -rf /opt/zapret
 else
     echo "Папка zapret не существует."
 fi
}

#Запрос желаемой версии zapret
version_select() {
   while true; do
	read -re -p $'\033[0;32mВведите желаемую версию zapret (Enter для новейшей версии): \033[0m' VER
    # Если пустой ввод — берем значение по умолчанию
	if [ -z "$VER" ]; then
		lastest_release="https://api.github.com/repos/bol-van/zapret/releases/latest"
	    # проверяем результаты по порядку
		echo -e "${yellow}Поиск последней версии...${plain}"
    	VER1=$(curl -sL $lastest_release | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
		if [ ${#VER1} -ge 2 ]; then
			VER="$VER1"
			echo -e "${green}Выбрано: $VER (метод: sed -E)${plain}"
		else
			VER2=$(curl -sL $lastest_release | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4 | sed 's/^v//')
			if [ ${#VER2} -ge 2 ]; then
				VER="$VER2"
				echo -e "${green}Выбрано: $VER (метод: grep+cut)${plain}"
			else
				VER3=$(curl -sL $lastest_release | grep '"tag_name":' | sed -r 's/.*"v([^"]+)".*/\1/')
				if [ ${#VER3} -ge 2 ]; then
					VER="$VER3"
					echo -e "${green}Выбрано: $VER (метод: sed -r)${plain}"
				else
					VER4=$(curl -sL $lastest_release | grep '"tag_name":' | awk -F'"' '{print $4}' | sed 's/^v//')
					if [ ${#VER4} -ge 2 ]; then
						VER="$VER4"
						echo -e "${green}Выбрано: $VER (метод: awk)${plain}"
					else
						echo -e "${yellow}Не удалось получить информацию о последней версии с GitHub. Будет использоваться версия $DEFAULT_VER.${plain}"
						VER="$DEFAULT_VER"
					fi
				fi
			fi
    	fi
    	break
	fi
    #Считаем длину
    LEN=${#VER}
    #Проверка длины и простая валидация формата (цифры и точки)
    if [ "$LEN" -gt 4 ]; then
        echo "Некорректный ввод. Максимальная длина — 4 символа. Попробуйте снова."
        continue
    elif ! echo "$VER" | grep -Eq '^[0-9]+(\.[0-9]+)*$'; then
        echo "Некорректный формат версии. Пример: 72.3"
        continue
    fi
    echo "Будет использоваться версия: $VER"
    break
done
}

#Скачивание, распаковка архива zapret, очистка от ненуных бинарей
zapret_get() {
 if [[ "$OSystem" == "VPS" ]]; then
     tarfile="zapret-v$VER.tar.gz"
 else
     tarfile="zapret-v$VER-openwrt-embedded.tar.gz"
 fi
 curl -L "https://github.com/bol-van/zapret/releases/download/v$VER/$tarfile" | tar -xz
 mv "zapret-v$VER" zapret
 sh /tmp/zapret/install_bin.sh
 find /tmp/zapret/binaries/* -maxdepth 0 -type d ! -name "$(basename "$(dirname "$(readlink /tmp/zapret/nfq/nfqws)")")" -exec rm -rf {} +
 mv zapret /opt/zapret
}

#Запуск установочных скриптов и перезагрузка
install_zapret_reboot() {
 sh -i /opt/zapret/install_easy.sh
 /opt/zapret/init.d/sysv/zapret restart
 if pidof nfqws >/dev/null; then
  check_access_list
  echo -e "\033[32mzapret перезапущен и полностью установлен\n\033[33mЕсли требуется меню (например не работают какие-то ресурсы) - введите скрипт ещё раз или просто напишите "z4r" в терминале. Саппорт: tg: zee4r\033[0m"
 else
  echo -e "${yellow}zapret полностью установлен, но не обнаружен после запуска в исполняемых задачах через pidof\nСаппорт: tg: zee4r${plain}"
 fi
}

#Для Entware Keenetic + merlin
entware_fixes() {
 if [ "$hardware" = "keenetic" ]; then
  curl -L -o /opt/zapret/init.d/sysv/zapret https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/Entware/zapret
  chmod +x /opt/zapret/init.d/sysv/zapret
  echo "Права выданы /opt/zapret/init.d/sysv/zapret"
  curl -L -o /opt/etc/ndm/netfilter.d/000-zapret.sh https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/Entware/000-zapret.sh
  chmod +x /opt/etc/ndm/netfilter.d/000-zapret.sh
  echo "Права выданы /opt/etc/ndm/netfilter.d/000-zapret.sh"
  curl -L -o /opt/etc/init.d/S00fix https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/Entware/S00fix
  chmod +x /opt/etc/init.d/S00fix
  echo "Права выданы /opt/etc/init.d/S00fix"
  cp -a /opt/zapret/init.d/custom.d.examples.linux/10-keenetic-udp-fix /opt/zapret/init.d/sysv/custom.d/10-keenetic-udp-fix
  echo "10-keenetic-udp-fix скопирован"
 elif [ "$hardware" = "merlin" ]; then
  if sed -n '167p' /opt/zapret/install_easy.sh | grep -q '^nfqws_opt_validat'; then
	sed -i '172s/return 1/return 0/' /opt/zapret/install_easy.sh
  fi
	grep -qxF '/opt/zapret/init.d/sysv/zapret restart-fw' /jffs/scripts/firewall-start || echo '/opt/zapret/init.d/sysv/zapret restart-fw' >> /jffs/scripts/firewall-start
	chmod +x /jffs/scripts/firewall-start
 fi
 
 sh /opt/zapret/install_bin.sh
 
 # #Раскомменчивание юзера под keenetic или merlin
 change_user
 #Патчинг на некоторых merlin /opt/zapret/common/linux_fw.sh
 if command -v sysctl >/dev/null 2>&1; then
  echo "sysctl доступен. Патч linux_fw.sh не требуется"
 else
  echo "sysctl отсутствует. MerlinWRT? Патчим /opt/zapret/common/linux_fw.sh"
  sed -i 's|sysctl -w net.netfilter.nf_conntrack_tcp_be_liberal=\$1|echo \$1 > /proc/sys/net/netfilter/nf_conntrack_tcp_be_liberal|' /opt/zapret/common/linux_fw.sh
  sed -i 's|sysctl -q -w net.ipv4.conf.\$1.route_localnet="\$enable"|echo "\$enable" > /proc/sys/net/ipv4/conf/\$1/route_localnet|' /opt/zapret/common/linux_iphelper.sh
 fi
 #sed для пропуска запроса на прочтение readme, т.к. система entware. Дабы скрипт отрабатывал далее на Enter
 sed -i 's/if \[ -n "\$1" \] || ask_yes_no N "do you want to continue";/if true;/' /opt/zapret/common/installer.sh
 ln -fs /opt/zapret/init.d/sysv/zapret /opt/etc/init.d/S90-zapret
 echo "Добавлено в автозагрузку: /opt/etc/init.d/S90-zapret > /opt/zapret/init.d/sysv/zapret"
}

#Запрос на установку 3x-ui или аналогов
get_panel() {
 read -re -p $'\033[33mУстановить ПО для туннелирования?\033[0m \033[32m(3xui, marzban, wg, 3proxy или Enter для пропуска): \033[0m' answer_panel
 # Удаляем лишние символы и пробелы, приводим к верхнему регистру
 clean_answer=$(echo "$answer_panel" | tr '[:lower:]' '[:upper:]')
 if [[ -z "$clean_answer" ]]; then
     echo "Пропуск установки ПО туннелирования."
 elif [[ "$clean_answer" == "3XUI" ]]; then
     echo "Установка 3x-ui панели."
     bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
 elif [[ "$clean_answer" == "WG" ]]; then
     echo "Установка WG (by angristan)"
     bash <(curl -Ls https://raw.githubusercontent.com/angristan/wireguard-install/refs/heads/master/wireguard-install.sh)
 elif [[ "$clean_answer" == "3PROXY" ]]; then
     echo "Установка 3proxy (by SnoyIatk). Доустановка с apt build-essential для сборки (debian/ubuntu)"
	 apt update && apt install build-essential
     bash <(curl -Ls https://raw.githubusercontent.com/SnoyIatk/3proxy/master/3proxyinstall.sh)
     curl -L -o /etc/3proxy/.proxyauth https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/refs/heads/master/del.proxyauth
     curl -L -o /etc/3proxy/3proxy.cfg https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/refs/heads/master/3proxy.cfg
 elif [[ "$clean_answer" == "MARZBAN" ]]; then
     echo "Установка Marzban"
     bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install
 else
     echo "Пропуск установки ПО туннелирования."
 fi
}

#webssh ttyd
ttyd_webssh() {
 echo -e $'\033[33mВведите логин для доступа к zeefeer через браузер (0 - отказ от логина через web в z4r и переход на логин в ssh (может помочь в safari). Enter - пустой логин, \033[31mно не рекомендуется, панель может быть доступна из интернета!)\033[0m'
 read -re -p '' ttyd_login
 echo -e "${yellow}Если вы открыли пункт через браузер - вас выкинет. Используйте SSH для установки${plain}"
 
 ttyd_login_have="-c "${ttyd_login}": bash z4r"
 if [[ "$ttyd_login" == "0" ]]; then
	echo "Отключение логина в веб. Перевод с z4r на CLI логин."
    ttyd_login_have="login"
 fi
 
 if [[ "$OSystem" == "VPS" ]]; then
	echo -e "${yellow}Установка ttyd for VPS${plain}"
	systemctl stop ttyd 2>/dev/null || true
	curl -L -o /usr/bin/ttyd https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64
	chmod +x /usr/bin/ttyd
	
	cat > /etc/systemd/system/ttyd.service <<EOF
[Unit]
Description=ttyd WebSSH Service
After=network.target

[Service]
ExecStart=/usr/bin/ttyd -p 17681 -W -a ${ttyd_login_have}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

	systemctl daemon-reload
	systemctl enable ttyd
	systemctl start ttyd
 elif [[ "$OSystem" == "WRT" ]]; then
	echo -e "${yellow}Установка ttyd for WRT${plain}"
	/etc/init.d/ttyd stop 2>/dev/null || true
	opkg install ttyd 2>/dev/null || apk add ttyd 2>/dev/null
    uci set ttyd.@ttyd[0].interface=''
    uci set ttyd.@ttyd[0].command="-p 17681 -W -a ${ttyd_login_have}"
	uci commit ttyd
	/etc/init.d/ttyd enable
	/etc/init.d/ttyd start
 elif [[ "$OSystem" == "entware" ]]; then
	echo -e "${yellow}Установка ttyd for Entware${plain}"
	/opt/etc/init.d/S99ttyd stop 2>/dev/null || true
	opkg install ttyd 2>/dev/null || apk add ttyd 2>/dev/null
	
	cat > /opt/etc/init.d/S99ttyd <<EOF
#!/bin/sh

START=99

case "\$1" in
  start)
    echo "Starting ttyd..."
    ttyd -p 17681 -W -a ${ttyd_login_have} &
    ;;
  stop)
    echo "Stopping ttyd..."
    killall ttyd
    ;;
  restart)
    \$0 stop
    sleep 1
    \$0 start
    ;;
  *)
    echo "Usage: \$0 {start|stop|restart}"
    exit 1
    ;;
esac
EOF

  chmod +x /opt/etc/init.d/S99ttyd
  /opt/etc/init.d/S99ttyd start
  sleep 1
  if netstat -tuln | grep -q ':17681'; then
	echo -e "${green}Порт 17681 для службы ttyd слушается${plain}"
  else
	echo -e "${red}Порт 17681 для службы ttyd не прослушивается${plain}"
  fi
 fi

 if pidof ttyd >/dev/null; then
	echo -e "Проверка...${green}Служба ttyd запущена.${plain}"
 else
	echo -e "Проверка...${red}Служба ttyd не запущена! Если у вас Entware, то после перезагрузки роутера служба скорее всего заработает!${plain}"
 fi
 echo -e "${plain}Выполнение установки завершено. ${green}Доступ по ip вашего роутера/VPS в формате ip:17681, например 192.168.1.1:17681 или mydomain.com:17681 ${yellow}логин: ${ttyd_login} пароль - не испольузется.${plain} Был выполнен выход из скрипта для сохранения состояния."
}

#Функция меню "14. Провайдер" by AloofLibra
provider_submenu() {
  provider_init_once

  echo -e "${yellow}Провайдер: ${plain}${PROVIDER_MENU}${yellow}
${green}1.${yellow} Указать вручную
${green}2.${yellow} Определить заново (сбросить кэш)
${green}3.${yellow} Обновить базу рекомендаций (Подсказки)
${green}0.${yellow} Назад${plain}"
  read -re -p "" answer_provider

  case "$answer_provider" in
    "1") 
        provider_set_manual_menu 
        exit_to_menu 
        ;;
    "2") 
        provider_force_redetect 
        exit_to_menu 
        ;;
    "3") 
        echo "Обновляем базу рекомендаций..."
        # Принудительно удаляем старый файл, чтобы update_recommendations скачал новый
        rm -f "$RECS_FILE"
        update_recommendations
        if [ -s "$RECS_FILE" ]; then
            echo -e "${green}База успешно обновлена!${plain}"
        else
            echo -e "${red}Ошибка обновления базы.${plain}"
        fi
        sleep 1
        exit_to_menu 
        ;;
    "0"|"") 
        exit_to_menu 
        ;;
    *) 
        exit_to_menu 
        ;;
  esac
}


#Меню, проверка состояний и вывод с чтением ответа
get_menu() {
local strategies_status=$(get_current_strategies_info)
TITLE_MENU_LINE=""
if [[ -s "$PREMIUM_TITLE_FILE" ]]; then
  TITLE_MENU_LINE="\n${pink}Титул:${plain} $(cat "$PREMIUM_TITLE_FILE")${yellow}\n"
fi
provider_init_once
init_telemetry
update_recommendations
 echo -e '
'${red}'      *
     ***            '${Fcyan}'by Dmitriy Utkin:
      *
'${green}'     /|\             '${plain}'.   .      .
'${green}'    //|\\\             '${plain}'.     '${Fred}'* '${plain}'.   .
'${green}'   ///|\\\\\                 '${green}'/ \  '${plain}'.
'${green}'  ////|\\\\\\\           '${plain}'.   '${green}'/ '${Fcyan}'* '${green}'\      '${plain}'.
'${green}'   ///|\\\\\\               '${green}'/  .  \   '${plain}'.
'${green}'  ////|\\\\\\\\         '${plain}'.   '${green}'/ '${Fpink}'* . '${Fyellow}'* '${green}'\
'${green}' /////|\\\\\\\\\\           '${green}'/  .   .  \  '${plain}'.
'${green}'  ////|\\\\\\\\\      '${plain}'.   '${green}'/ '${Fcyan}'* . '${plain}'* . '${Fred}'* '${green}'\   '${plain}'.
'${green}' /////|\\\\\\\\\\\        '${green}'/_____________\
'${green}'//////|\\\\\\\\\\\\\      '${plain}'.     '${green}'[___]   '${plain}'.  .
'"Город/провайдер: ${plain}${PROVIDER_MENU}${yellow}"'
'"${TITLE_MENU_LINE}"'
\033[32mВыберите необходимое действие:\033[33m
Enter (без цифр) - переустановка/обновление zapret
0. Выход
01. Проверить доступность сервисов (Тест не точен)
1. Сменить стратегии или добавить домен в хост-лист. Текущие: '${plain}[ ${strategies_status} ]${yellow}'
2. Стоп/пере(запуск) zapret (сейчас: '$(pidof nfqws >/dev/null && echo "${green}Запущен${yellow}" || echo "${red}Остановлен${yellow}")')
3. Тут могла быть ваша реклама :D (Функция перенесена во 2 пункт. Резерв)
4. Удалить zapret
5. Обновить стратегии, сбросить листы подбора стратегий и исключений (есть бэкап)
6. Исключить домен из zapret обработки
7. Открыть в редакторе config (Установит nano редактор ~250kb)
8. Преключатель скриптов bol-van обхода войсов DS,WA,TG на стандартные страты или возврат к скриптам. Сейчас: '${plain}$(grep -Eq '^NFQWS_PORTS_UDP=.*443$' /opt/zapret/config && echo "Скрипты" || (grep -Eq '443,1400,3478-3481,5349,50000-50099,19294-19344$' /opt/zapret/config && echo "Классические стратегии" || echo "Незвестно"))${yellow}'
9. Переключатель zapret на nftables/iptables (На всё жать Enter). Актуально для OpenWRT 21+. Может помочь с войсами. Сейчас: '${plain}$(grep -q '^FWTYPE=iptables$' /opt/zapret/config && echo "iptables" || (grep -q '^FWTYPE=nftables$' /opt/zapret/config && echo "nftables" || echo "Неизвестно"))${yellow}'
10. (Де)активировать обход UDP на 1026-65531 портах (BF6, Fifa и т.п.). Сейчас: '${plain}$(grep -q '^NFQWS_PORTS_UDP=443' /opt/zapret/config && echo "Выключен" || (grep -q '^NFQWS_PORTS_UDP=1026-65531,443' /opt/zapret/config && echo "Включен" || echo "Неизвестно"))${yellow}'
11. Управление аппаратным ускорением zapret. Может увеличить скорость на роутере. Сейчас: '${plain}$(grep '^FLOWOFFLOAD=' /opt/zapret/config)${yellow}'
12. Меню (Де)Активации работы по всем доменам TCP-443 без хост-листов (не затрагивает youtube стратегии) (безразборный режим) Сейчас: '${plain}$(num=$(sed -n '112,128p' /opt/zapret/config | grep -n '^--filter-tcp=443 --hostlist-domains= --' | head -n1 | cut -d: -f1); [ -n "$num" ] && echo "$num" || echo "Отключен")${yellow}'
13. Активировать доступ в меню через браузер (~3мб места)
14. Провайдер
777. Активировать zeefeer premium (Нажимать только Valery ProD, avg97, Xoz, GeGunT, blagodarenya, mikhyan, Whoze, andric62, Necronicle, Andrei_5288515371, Nomand, Dina_turat, Nergalss, Александру, АлександруП, vecheromholodno, ЕвгениюГ, Dyadyabo, skuwakin, izzzgoy, subzeero452, Grigaraz, Reconnaissance, comandante1928, umad, railwayfx, vtokarev1604, rudnev2028 и остальным поддержавшим проект. Но если очень хочется - можно нажать и другим)\033[0m'
if [[ -f "$PREMIUM_FLAG" ]]; then
  echo -e "${red}999. Секретный пункт. Нажимать на свой страх и риск${plain}"
fi
 read -re -p '' answer_menu
 case "$answer_menu" in
  "0")
   echo "Выход выполнен"
   exit 0
   ;;
  "01")
   check_access_list
   exit_to_menu
   ;;
  "1")
   echo "Режим подбора других стратегий"
   Strats_Tryer
   exit_to_menu
   ;;
  "2")
   if pidof nfqws >/dev/null; then
	/opt/zapret/init.d/sysv/zapret stop
  	echo -e "${green}Выполнена команда остановки zapret${plain}"
   else
	/opt/zapret/init.d/sysv/zapret restart
   	echo -e "${green}Выполнена команда перезапуска zapret${plain}"
   fi 
   exit_to_menu
   ;;
  "3")
   exit_to_menu
   ;;
  "4")
   remove_zapret
   echo -e "${yellow}zapret удалён${plain}"
   exit_to_menu
   ;;
  "5")
   echo -e "${yellow}Конфиг обновлен (UTC +0): $(curl -s "https://api.github.com/repos/IndeecFOX/zapret4rocket/commits?path=config.default&per_page=1" | grep '"date"' | head -n1 | cut -d'"' -f4) ${plain}"
   backup_strats
   /opt/zapret/init.d/sysv/zapret stop
   rm -rf /opt/zapret/lists /opt/zapret/extra_strats
   rm -f /opt/zapret/files/fake/http_fake_MS.bin /opt/zapret/files/fake/quic_{1..7}.bin /opt/zapret/files/fake/syn_packet.bin /opt/zapret/files/fake/tls_clienthello_{1..18}.bin /opt/zapret/files/fake/tls_clienthello_2n.bin /opt/zapret/files/fake/tls_clienthello_6a.bin /opt/zapret/files/fake/tls_clienthello_4pda_to.bin
   get_repo
   #Раскомменчивание юзера под keenetic или merlin
   change_user
   cp -f /opt/zapret/config.default /opt/zapret/config
   /opt/zapret/init.d/sysv/zapret start
   check_access_list
   echo -e "${green}Config файл обновлён. Листы подбора стратегий и исключений сброшены в дефолт, если не просили сохранить. Фейк файлы обновлены.${plain}"
   exit_to_menu
   ;;
  "6")
   read -re -p "Введите домен, который добавить в исключения (например, mydomain.com): " user_domain
   if [ -n "$user_domain" ]; then
    echo "$user_domain" >> /opt/zapret/lists/netrogat.txt
    echo -e "Домен ${yellow}$user_domain${plain} добавлен в исключения (netrogat.txt). zapret перезапущен."
   else
    echo "Ввод пустой, ничего не добавлено"
   fi
   exit_to_menu
   ;;
  "7")
   if [[ "$OSystem" == "VPS" ]]; then
	apt install nano
   else
	opkg remove nano 2>/dev/null || apk del nano 2>/dev/null && opkg install nano-full 2>/dev/null || apk add nano-full 2>/dev/null
   fi
   nano /opt/zapret/config
   exit_to_menu
   ;;
  "8")
	if grep -Eq '^NFQWS_PORTS_UDP=.*443$' "/opt/zapret/config"; then
     # Был только 443 → добавляем порты и убираем --skip, удаляем скрипты
     sed -i '76s/443$/443,1400,3478-3481,5349,50000-50099,19294-19344/' /opt/zapret/config
	 sed -i 's/^--skip --filter-udp=50000/--filter-udp=50000/' "/opt/zapret/config"
	 rm -f \opt\zapret\init.d\sysv\custom.d\50-discord-media \opt\zapret\init.d\sysv\custom.d\50-stun4all /opt/zapret/init.d/openwrt/custom.d/50-stun4all /opt/zapret/init.d/openwrt/custom.d/50-discord-media
     echo -e "${green}Уход от скриптов bol-van. Выделены порты 50000-50099,1400,3478-3481,5349 и раскомментированы стратегии DS, WA, TG${plain}"
	elif grep -q '443,1400,3478-3481,5349,50000-50099,19294-19344$' "/opt/zapret/config"; then
     # Уже расширенный список → возвращаем к 443 и добавляем --skip, возвращаем скрипты
     sed -i 's/443,1400,3478-3481,5349,50000-50099,19294-19344$/443/' "/opt/zapret/config"
	 sed -i 's/^--filter-udp=50000/--skip --filter-udp=50000/' "/opt/zapret/config"
	 curl -L -o /opt/zapret/init.d/sysv/custom.d/50-stun4all https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-stun4all
	 curl -L -o /opt/zapret/init.d/sysv/custom.d/50-discord-media https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-discord-media
	 cp -f /opt/zapret/init.d/sysv/custom.d/50-stun4all /opt/zapret/init.d/openwrt/custom.d/50-stun4all
 	 cp -f /opt/zapret/init.d/sysv/custom.d/50-discord-media /opt/zapret/init.d/openwrt/custom.d/50-discord-media
     echo -e "${green}Работа от скриптов bol-van. Вернули строку к виду NFQWS_PORTS_UDP=443 и добавили "--skip " в начале строк стратегии войса${plain}"
	else
     echo -e "${yellow}Неизвестное состояние строки NFQWS_PORTS_UDP. Проверь конфиг вручную.${plain}"
	fi
	/opt/zapret/init.d/sysv/zapret restart
 	echo -e "${green}Выполнение переключений завершено.${plain}"
   exit_to_menu
   ;;
  "9")
	if grep -q '^FWTYPE=iptables$' "/opt/zapret/config"; then
     # Был только 443 → добавляем порты и убираем --skip
     sed -i 's/^FWTYPE=iptables$/FWTYPE=nftables/' "/opt/zapret/config"
	 /opt/zapret/install_prereq.sh
  	 /opt/zapret/init.d/sysv/zapret restart
     echo -e "${green}Zapret moode: nftables.${plain}"
	elif grep -q '^FWTYPE=nftables$' "/opt/zapret/config"; then
     sed -i 's/^FWTYPE=nftables$/FWTYPE=iptables/' "/opt/zapret/config"
	 /opt/zapret/install_prereq.sh
  	 /opt/zapret/init.d/sysv/zapret restart
     echo -e "${green}Zapret moode: iptables.${plain}"
	else
     echo -e "${yellow}Неизвестное состояние строки FWTYPE. Проверь конфиг вручную.${plain}"
	fi
   exit_to_menu
   ;;
  "10")
	if grep -q '^NFQWS_PORTS_UDP=443' "/opt/zapret/config"; then
     # Был только 443 → добавляем порты и убираем --skip
     sed -i 's/^NFQWS_PORTS_UDP=443/NFQWS_PORTS_UDP=1026-65531,443/' "/opt/zapret/config"
	 sed -i 's/^--skip --filter-udp=1026/--filter-udp=1026/' "/opt/zapret/config"
     echo -e "${green}Стратегия UDP обхода активирована. Выделены порты 1026-65531${plain}"
	elif grep -q '^NFQWS_PORTS_UDP=1026-65531,443' "/opt/zapret/config"; then
     # Уже расширенный список → возвращаем к 443 и добавляем --skip
     sed -i 's/^NFQWS_PORTS_UDP=1026-65531,443/NFQWS_PORTS_UDP=443/' "/opt/zapret/config"
	 sed -i 's/^--filter-udp=1026/--skip --filter-udp=1026/' "/opt/zapret/config"
     echo -e "${green}Стратегия UDP обхода ДЕактивирована. Выделенные порты 1026-65531 убраны${plain}"
	else
     echo -e "${yellow}Неизвестное состояние строки NFQWS_PORTS_UDP. Проверь конфиг вручную.${plain}"
	fi
	/opt/zapret/init.d/sysv/zapret restart
 	echo -e "${green}Выполнение переключений завершено.${plain}"
    exit_to_menu 
   ;;
  "11")
	echo "Текущее состояние: $(grep '^FLOWOFFLOAD=' /opt/zapret/config)"
 	read -re -p $'\033[33mСменить аппаратное ускорение? (1-4 или Enter для выхода):\033[0m\n\033[32m1. software. Программное ускорение. \n2. hardware. Аппаратное NAT\n3. none. Отключено.\n4. donttouch. Не трогать (дефолт).\033[0m\n' answer_offload

    case "$answer_offload" in
        "1")
 	  	    sed -i 's/^FLOWOFFLOAD=.*/FLOWOFFLOAD=software/' "/opt/zapret/config"
			/opt/zapret/install_prereq.sh
  			/opt/zapret/init.d/sysv/zapret restart
            ;;
        "2")
 	  	    sed -i 's/^FLOWOFFLOAD=.*/FLOWOFFLOAD=hardware/' "/opt/zapret/config"
			/opt/zapret/install_prereq.sh
  			/opt/zapret/init.d/sysv/zapret restart
            ;;
        "3")
 	  	    sed -i 's/^FLOWOFFLOAD=.*/FLOWOFFLOAD=none/' "/opt/zapret/config"
			/opt/zapret/install_prereq.sh
  			/opt/zapret/init.d/sysv/zapret restart         
            ;;
        "4")
 	  	    sed -i 's/^FLOWOFFLOAD=.*/FLOWOFFLOAD=donttouch/' "/opt/zapret/config"
			/opt/zapret/install_prereq.sh
  			/opt/zapret/init.d/sysv/zapret restart
            ;;
        *)
            echo "Выход"
            ;;
    esac

   echo -e "${green}Выполнено.${plain}"
   exit_to_menu
   ;;
  "12")
   num=$(sed -n '112,128p' /opt/zapret/config | grep -n '^--filter-tcp=443 --hostlist-domains= --' | head -n1 | cut -d: -f1); echo -e "${yellow}Безразборный режим по стратегии: ${plain}$((num ? num : 0))"
   echo -e "\033[33mС каким номером применить стратегию? (1-17, 0 - отключение безразборного режима, Enter - выход) \033[31mПри активации кастомно подобранные домены будут очищены:${plain}"
   read -re -p " " answer_bezr
   if echo "$answer_bezr" | grep -Eq '^[0-9]+$' && [ "$answer_bezr" -ge 0 ] && [ "$answer_bezr" -le 17 ]; then
	#Отключение
    for i in $(seq 112 128); do
	 if sed -n "${i}p" /opt/zapret/config | grep -Fq -- '--filter-tcp=443 --hostlist-domains= --h'; then
		sed -i "${i}s#--filter-tcp=443 --hostlist-domains= --h#--filter-tcp=443 --hostlist-domains=none.dom --h#" /opt/zapret/config
		/opt/zapret/init.d/sysv/zapret restart
   		echo -e "${green}Выполнена команда перезапуска zapret${plain}"
		echo "Безразборный режим отключен"
		break
	fi
	done
	if [ "$answer_bezr" -ge 1 ] && [ "$answer_bezr" -le 17 ]; then
		for f_clear in $(seq 1 17); do
			echo -n > "/opt/zapret/extra_strats/TCP/User/$f_clear.txt"
			echo -n > "/opt/zapret/extra_strats/TCP/temp/$f_clear.txt"
		done
		sed -i "$((111 + answer_bezr))s/--hostlist-domains=none\.dom/--hostlist-domains=/" /opt/zapret/config
		/opt/zapret/init.d/sysv/zapret restart
		echo -e "${green}Выполнена команда перезапуска zapret. ${yellow}Безразборный режим активирован на $answer_bezr стратегии для TCP-443. Проверка доступа к meduza.io${plain}"
		check_access_list
	fi
   else
    get_menu
   fi
   exit_to_menu
   ;;
  "13")
   ttyd_webssh
   exit 7
   ;;
  "14")
   provider_submenu
   ;;
  "777")
   echo -e "${green}Специальный zeefeer premium для Valery ProD, avg97, Xoz, GeGunT, blagodarenya, mikhyan, andric62, Whoze, Necronicle, Andrei_5288515371, Nomand, Dina_turat, Nergalss, Александра, АлександраП, vecheromholodno, ЕвгенияГ, Dyadyabo, skuwakin, izzzgoy, Grigaraz, Reconnaissance, comandante1928, rudnev2028, umad, rutakote, railwayfx, vtokarev1604, Grigaraz, a40letbezurojaya и subzeero452 активирован. Наверное. Так же благодарю поддержавших проект hey_enote, VssA, vladdrazz, Alexey_Tob, Bor1sBr1tva, Azamatstd, iMLT, Qu3Bee, SasayKudasay1, alexander_novikoff, MarsKVV, porfenon123, bobrishe_dazzle, kotov38, Levonkas, DA00001, trin4ik, geodomin, I_ZNA_I и анонимов${plain}"
   zefeer_premium_777
   exit_to_menu
   ;;
  "999")
  zefeer_space_999
  exit_to_menu
  ;; 
  esac
 }

#___Само выполнение скрипта начинается тут____

#Добавление ссылки на быстрый вызов скрипта, проверка на актуальность сначала если есть
if [ -d /opt/bin ]; then
    if [ ! -f /opt/bin/z4r ] || ! grep -q 'opt/z4r.sh "$@"' /opt/bin/z4r; then	
		echo "Скачиваем /opt/bin/z4r"
        curl -L -o /opt/bin/z4r https://raw.githubusercontent.com/IndeecFOX/z4r/main/z4r
        chmod +x /opt/bin/z4r
    fi
elif [ ! -f /usr/bin/z4r ] || ! grep -q 'opt/z4r.sh "$@"' /usr/bin/z4r; then
	echo "Скачиваем /usr/bin/z4r"
    curl -L -o /usr/bin/z4r https://raw.githubusercontent.com/IndeecFOX/z4r/main/z4r
    chmod +x /usr/bin/z4r
fi

#Проверка ОС
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
elif [[ -f /opt/etc/entware_release ]]; then
    release="entware"
elif [[ -f /etc/entware_release ]]; then
    release="entware"
else
    echo "Не удалось определить ОС. Прекращение работы скрипта." >&2
    exit 1
fi
if [[ "$release" == "entware" ]]; then
 if [ -d /jffs ] || uname -a | grep -qi "Merlin"; then
    hardware="merlin"
 elif grep -Eqi "netcraze|keenetic" /proc/version; then
   	hardware="keenetic"
 else
  echo -e "${yellow}Железо не определено. Будем считать что это Keenetic. Если будут проблемы - пишите в саппорт.${plain}"
  hardware="keenetic"
 fi
fi

#По просьбе наших слушателей) Теперь netcraze официально детектится скриптом не как keenetic, а отдельно)
if grep -q "netcraze" "/bin/ndmc" 2>/dev/null; then
 echo "OS: $release Netcraze"
else
 echo "OS: $release $hardware"
fi

#Запуск скрипта под нужную версию
if [[ "$release" == "ubuntu" || "$release" == "debian" || "$release" == "endeavouros" || "$release" == "arch" ]]; then
	OSystem="VPS"
elif [[ "$release" == "openwrt" || "$release" == "immortalwrt" || "$release" == "asuswrt" || "$release" == "x-wrt" || "$release" == "kwrt" || "$release" == "istoreos" ]]; then
	OSystem="WRT"
elif [[ "$release" == "entware" || "$hardware" = "keenetic" ]]; then
	OSystem="entware"
else
	read -re -p $'\033[31mДля этой ОС нет подходящей функции. Или ОС определение выполнено некорректно.\033[33m Рекомендуется обратиться в чат поддержки
Enter - выход
1 - Плюнуть и продолжить как OpenWRT
2 - Плюнуть и продолжить как entware
3 - Плюнуть и продолжить как VPS\033[0m\n' os_answer
	case "$os_answer" in
	"1")
		OSystem="WRT"
	;;
	"2")
		OSystem="entware"
	;;
	"3")
		OSystem="VPS"
	;;
	*)
		echo "Выбран выход"
		exit 0
	;;
esac 
fi

#Инфа о времени обновления скрпта
commit_date=$(curl -s --max-time 30 "https://api.github.com/repos/IndeecFOX/zapret4rocket/commits?path=z4r.sh&per_page=1" | grep '"date"' | head -n1 | cut -d'"' -f4)
if [[ -z "$commit_date" ]]; then
    echo -e "${red}Не был получен доступ к api.github.com (таймаут 30 сек). Возможны проблемы при установке.${plain}"
	if [ "$hardware" = "keenetic" ]; then
		echo "Добавляем ip с от DNS 1.1.1.1 к api.github.com и пытаемся снова"
		ndmc -c "ip host api.github.com $(nslookup api.github.com 1.1.1.1 | sed -n 's/^Address [0-9]*: \([0-9.]*\).*/\1/p' | tail -n1)"
		echo -e "${yellow}zeefeer обновлен (UTC +0): $(curl -s --max-time 10 "https://api.github.com/repos/IndeecFOX/zapret4rocket/commits?path=z4r.sh&per_page=1" | grep '"date"' | head -n1 | cut -d'"' -f4) ${plain}"
	fi
else
    echo -e "${yellow}zeefeer обновлен (UTC +0): $commit_date ${plain}"
fi

#Проверка доступности raw.githubusercontent.com
if [[ -z "$(curl -s --max-time 10 "https://raw.githubusercontent.com/test")" ]]; then
    echo -e "${red}Не был получен доступ к raw.githubusercontent.com (таймаут 10 сек). Возможны проблемы при установке.${plain}"
	if [ "$hardware" = "keenetic" ]; then
		echo "Добавляем ip с от DNS 1.1.1.1 к raw.githubusercontent.com и пытаемся снова"
		ndmc -c "ip host raw.githubusercontent.com $(nslookup raw.githubusercontent.com 1.1.1.1 | sed -n 's/^Address [0-9]*: \([0-9.]*\).*/\1/p' | tail -n1)"
	fi
fi

#Выполнение общего для всех ОС кода с ответвлениями под ОС
#Запрос на установку 3x-ui или аналогов для VPS
if [[ "$OSystem" == "VPS" ]] && [ ! $1 ]; then
 get_panel
fi

#Меню и быстрый запуск подбора стратегии
 if [ -d /opt/zapret/extra_strats ] && [ -f "/opt/zapret/config" ]; then
	if [ $1 ]; then
		Strats_Tryer $1
	fi
    get_menu
 fi
 
#entware keenetic and merlin preinstal env.
if [ "$hardware" = "keenetic" ]; then
 opkg install coreutils-sort grep gzip ipset iptables xtables-addons_legacy 2>/dev/null || apk add coreutils-sort grep gzip ipset iptables xtables-addons_legacy 2>/dev/null
 opkg install kmod_ndms 2>/dev/null || apk add kmod_ndms 2>/dev/null || echo -e "\033[31mНе удалось установить kmod_ndms. Если у вас не keenetic - игнорируйте.\033[0m"
elif [ "$hardware" = "merlin" ]; then
 opkg install coreutils-sort grep gzip ipset iptables xtables-addons_legacy 2>/dev/null || apk add coreutils-sort grep gzip ipset iptables xtables-addons_legacy 2>/dev/null
fi

#Проверка наличия каталога opt и его создание при необходиомости (для некоторых роутеров), переход в tmp
mkdir -p /opt
cd /tmp

#Запрос на резервирование стратегий, если есть что резервировать
backup_strats

#Удаление старого запрета, если есть
remove_zapret

#Запрос желаемой версии zapret
echo -e "${yellow}Конфиг обновлен (UTC +0): $(curl -s "https://api.github.com/repos/IndeecFOX/zapret4rocket/commits?path=config.default&per_page=1" | grep '"date"' | head -n1 | cut -d'"' -f4) ${plain}"
version_select

#Запрос на установку web-ssh
read -re -p $'\033[33mАктивировать доступ в меню через браузер (~3мб места)? 1 - Да, Enter - нет\033[0m\n' ttyd_answer
case "$ttyd_answer" in
	"1")
		ttyd_webssh
	;;
	*)
		echo "Пропуск (пере)установки web-терминала"
	;;
esac 
 
#Скачивание, распаковка архива zapret и его удаление
zapret_get

#Создаём папки и забираем файлы папок lists, fake, extra_strats, копируем конфиг, скрипты для войсов DS, WA, TG
get_repo

#Для Keenetic и merlin
if [[ "$OSystem" == "entware" ]]; then
 entware_fixes
fi

#Для x-wrt
if [[ "$release" == "x-wrt" ]]; then
	sed -i 's/kmod-nft-nat kmod-nft-offload/kmod-nft-nat/' /opt/zapret/common/installer.sh
fi

#Запуск установочных скриптов и перезагрузка
install_zapret_reboot
