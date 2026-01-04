# ---- ZEFEER PREMIUM (777/999) ----
# Сделано исключительно ради мемов. Практического смысла не несёт. 
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
# ---- /ZEFEER PREMIUM ----
