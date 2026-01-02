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
    pause_enter
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
      echo "Подбор для хост-листа YouTube (UDP QUIC - браузеры, моб. приложения). Ранее заданная стратегия этого листа сброшена в дефолт."
      #вывод подсказки
      show_hint "UDP"
      try_strategies 8 "/opt/zapret/extra_strats/UDP/YT" "/opt/zapret/extra_strats/UDP/YT/List.txt" ""
      ;;
    "2")
      echo "Подбор для хост-листа YouTube (TCP - основной). Ранее заданная стратегия этого листа сброшена в дефолт."
      #вывод подсказки
      show_hint "TCP"
      try_strategies 17 "/opt/zapret/extra_strats/TCP/YT" "/opt/zapret/extra_strats/TCP/YT/List.txt" ""
      ;;
    "3")
      echo "Подбор для GVideo (Видеопоток YT). Ранее заданная стратегия этого листа сброшена в дефолт."
      #на всякий случай убираем GV из листа YT
      [ -f "/opt/zapret/extra_strats/TCP/YT/List.txt" ] && \
        sed -i '/googlevideo.com/d' "/opt/zapret/extra_strats/TCP/YT/List.txt"
      user_domain="googlevideo.com"
      #вывод подсказки
      show_hint "GV"
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
      echo "Режим кастомного домена"
      # раньше домен спрашивался тут, но теперь ввод домена делается в сабменю
      if [ -z "$user_domain" ]; then
        echo "Домен не задан. Отмена."
        return 0
      fi
      echo "Введён домен: $user_domain"

      try_strategies 17 "/opt/zapret/extra_strats/TCP/temp" "/dev/null" \
        "echo -n > \"/opt/zapret/extra_strats/TCP/temp/\${strat_num}.txt\"; \
         echo \"$user_domain\" >> \"/opt/zapret/extra_strats/TCP/User/\${strat_num}.txt\""
      ;;
    *)
      echo "Пропуск подбора альтернативной стратегии"
      return 0
      ;;
  esac
}
