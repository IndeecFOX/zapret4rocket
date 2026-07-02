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
    local s_udp s_tcp s_gv s_rkn s_voice

    profile_status_value() {
        local profile="$1"
        local folder="$2"
        local max="$3"
        local state active

        state="$(profile_lock_get "$profile")"
        case "$state" in
          "skip")
            echo "0"
            return
            ;;
          "auto"|"")
            ;;
          *)
            if echo "$state" | grep -Eq '^[1-9][0-9]*$'; then
              echo "$state"
              return
            fi
            ;;
        esac

        active="$(get_active_strat_num "$folder" "$max")"
        if [ "$active" = "0" ]; then
          echo "auto"
        else
          echo "$active"
        fi
    }

    colorize_state() {
        case "$1" in
          "auto") echo "${yellow}auto${plain}" ;;
          "0")    echo "${red}0${plain}" ;;
          *)      echo "${green}$1${plain}" ;;
        esac
    }

    s_udp="$(profile_status_value "YT_UDP" "$(profile_strategy_base YT_UDP)" 8)"
    s_tcp="$(profile_status_value "YT_TCP" "$(profile_strategy_base YT_TCP)" 17)"
    s_gv="$(profile_status_value "YT_GV" "$(profile_strategy_base YT_GV)" 17)"
    s_rkn="$(profile_status_value "RKN" "$(profile_strategy_base RKN)" 17)"
    s_voice="$(profile_lock_get "VOICE_UDP")"
    [ "$s_voice" = "skip" ] && s_voice="0"
    [ -z "$s_voice" ] && s_voice="auto"

    echo -e "YT_UDP=$(colorize_state "$s_udp") YT_TCP=$(colorize_state "$s_tcp") YT_GV=$(colorize_state "$s_gv") RKN=$(colorize_state "$s_rkn") VOICE_UDP=$(colorize_state "$s_voice")"
}

#Функция для функции подбора стратегий
try_strategies() {
    local count="$1"
    local base_path="$2"
    local list_file="$3"
    local final_action="$4"
    local profile_name="$5"
    local strat_num answer_strat
    
    read -re -p "Введите номер стратегии (0 - отключить профиль, Enter - без изменений): " strat_num
    if [[ -z "$strat_num" ]]; then
        echo "Без изменений."
        return
    fi

    if [[ "$strat_num" == "0" ]]; then
        if [[ -n "$profile_name" ]] && profile_can_skip "$profile_name"; then
            profile_lock_set "$profile_name" "skip"
            profile_apply_one "$profile_name" "skip"
            if [[ -n "${ZAPRET2_INIT:-}" && -f "$ZAPRET2_INIT" ]]; then
              "$ZAPRET2_INIT" restart || true
            fi
            echo "Профиль $profile_name отключён и сохранён как 0."
        else
            echo "Этот профиль пока нельзя безопасно отключить через 0."
        fi
        return
    fi

    if ! echo "$strat_num" | grep -Eq '^[0-9]+$' || (( strat_num < 1 || strat_num > count )); then
        echo "Введено значение не из диапазона. Начинаем с 1 стратегии"
        strat_num=1
    fi

    mkdir -p "$base_path"

    # Предварительная очистка всех файлов стратегий в папке
    for ((clr_txt=1; clr_txt<=count; clr_txt++)); do
        [ -s "$base_path/${clr_txt}.txt" ] && echo -n > "$base_path/${clr_txt}.txt"
    done

    # Основной цикл перебора
    for ((strat_num=strat_num; strat_num<=count; strat_num++)); do
        
        # Очищаем файл предыдущей стратегии (чтобы не было дублей)
        if [[ $strat_num -ge 2 ]]; then
            prev=$((strat_num - 1))
            [ -s "$base_path/${prev}.txt" ] && echo -n > "$base_path/${prev}.txt"
        fi

        # Запись в файл текущей стратегии
        if [[ "$list_file" != "/dev/null" ]]; then
            # Режим списка (копируем весь файл)
            if [ ! -s "$list_file" ]; then
              echo "Не найден список доменов: $list_file"
              return 1
            fi
            if [ ! -f "$base_path/${strat_num}.txt" ] || ! cmp -s "$list_file" "$base_path/${strat_num}.txt"; then
              cp "$list_file" "$base_path/${strat_num}.txt"
            fi
        else
            # Режим одного домена
            profile_write_if_changed "$base_path/${strat_num}.txt" "$user_domain"
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
            if [[ -n "$profile_name" ]]; then
              profile_lock_set "$profile_name" "$strat_num"
              profile_apply_one "$profile_name" "$strat_num"
              if [[ -n "${ZAPRET2_INIT:-}" && -f "$ZAPRET2_INIT" ]]; then
                "$ZAPRET2_INIT" restart || true
              fi
            fi
            send_stats  # Отправка телеметрии (если включена)
            
            # Если передано дополнительное действие (final_action), выполняем его
            if [[ -n "$final_action" ]]; then
                eval "$final_action"
            fi
            return
            
        elif [[ "$answer_strat" == "0" ]]; then
            # Сброс текущей стратегии при отмене
            [ -s "$base_path/${strat_num}.txt" ] && echo -n > "$base_path/${strat_num}.txt"
            echo "Изменения отменены."
            return
        fi
    done

    # Если цикл закончился, а пользователь ничего не выбрал
    [ -s "$base_path/${count}.txt" ] && echo -n > "$base_path/${count}.txt"
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
      echo "Подбор для хост-листа YouTube с видеопотоком (UDP QUIC - браузеры, моб. приложения). Ранее заданная стратегия этого листа сброшена в дефолт."
      #вывод подсказки
      show_hint "UDP"
      try_strategies 8 "$(profile_strategy_base YT_UDP)" "$(profile_strategy_list_file YT_UDP)" "" "YT_UDP"
      ;;
    "2")
      echo "Подбор для хост-листа YouTube (TCP - сам интерфейс. Без видео-домена). Ранее заданная стратегия этого листа сброшена в дефолт."
      #вывод подсказки
      show_hint "TCP"
      try_strategies 17 "$(profile_strategy_base YT_TCP)" "$(profile_strategy_list_file YT_TCP)" "" "YT_TCP"
      ;;
    "3")
      echo "Подбор для googlevideo.com (Видеопоток YouTube). Ранее заданная стратегия этого листа сброшена в дефолт."
      #на всякий случай убираем GV из листа YT
      [ -f "/opt/zapret2/extra_strats/TCP/YT/List.txt" ] && \
        sed -i '/googlevideo.com/d' "/opt/zapret2/extra_strats/TCP/YT/List.txt"
      user_domain="googlevideo.com"
      #вывод подсказки
      show_hint "GV"
      try_strategies 17 "$(profile_strategy_base YT_GV)" "/dev/null" "" "YT_GV"
      ;;
    "4")
      echo "Подбор для хост-листа основных доменов блока RKN. Проверка доступности задана на домен meduza.io. Ранее заданная стратегия этого листа сброшена в дефолт."
      profile_clear_strategy_files "RKN"
      user_domain="meduza.io"
      #вывод подсказки
      show_hint "RKN"
      try_strategies 17 "$(profile_strategy_base RKN)" "$(profile_strategy_list_file RKN)" "" "RKN"
      ;;
    "5")
      echo "Режим ручного указания домена"
      # раньше домен спрашивался тут, но теперь ввод домена делается в сабменю
      if [ -z "$user_domain" ]; then
        echo "Домен не задан. Отмена."
        return 0
      fi
      echo "Введён домен: $user_domain"

      try_strategies 17 "/opt/zapret2/extra_strats/TCP/temp" "/dev/null" \
        "echo -n > \"/opt/zapret2/extra_strats/TCP/temp/\${strat_num}.txt\"; \
         echo \"$user_domain\" >> \"/opt/zapret2/extra_strats/TCP/User/\${strat_num}.txt\""
      ;;
    *)
      echo "Пропуск подбора альтернативной стратегии"
      return 0
      ;;
  esac
}
