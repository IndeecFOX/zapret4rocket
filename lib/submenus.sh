# submenus.sh
# Единый стиль: loop + return на 0/Enter

#функция меню "1. Сменить стратегии"
strategies_submenu() {
  while true; do
    local strategies_status
    strategies_status=$(get_current_strategies_info)
    check_config_default_update_notice
    clear

    echo -e "${cyan}--- Управление стратегиями ---${plain}"
    if [ -n "$CONFIG_UPDATE_NOTICE" ]; then
      echo -e "${green}${CONFIG_UPDATE_NOTICE}${plain}"
      echo -e "${green}При желании можете ввести 55 для обновления config (Обновление зифира как через пункт 5 в главном меню).${plain}"
    fi
    echo -e "Текущие стратегии [${strategies_status}]"
    echo -e 

    submenu_item "	1" "YouTube с видеопотоком (UDP QUIC)." "$(strategy_variants_label UDP)"
    submenu_item "	2" "YouTube (TCP. Интерфейс)." "$(strategy_variants_label TCP) (Приоритетнее безразборного режима)"
    submenu_item "	3" "YouTube (TCP. Видеопоток/GV домен)." "$(strategy_variants_label TCP) (Приоритетнее безразборного режима)"
    submenu_item "	4" "RKN (Популярные блокированные сайты. Дискорд в т.ч.)." "$(strategy_variants_label TCP)"
    submenu_item "	5" "Отдельный домен." "$(strategy_variants_label TCP) (Приоритетнее безразборного режима)"
    submenu_item "	6" "Включить/отключить или добавить стратегию"
    if [ -n "$CONFIG_UPDATE_NOTICE" ]; then
      submenu_item "	55" "Обновить config (пункт 5 главного меню)"
    fi
	submenu_item "	9" "$([ "$(get_fooling_mode)" = "ts,badsum" ] && echo "Переключить фулинг с ${yellow}ts+badsum на ts" || echo "Переключить фулинг с ${yellow}ts на ts+badsum")" "Может помочь с Discord или иными ресурсами"
    submenu_item "	0" "Назад"
    echo ""

    read -re -p "Ваш выбор: " ans

    case "$ans" in
      "1"|"2"|"3"|"4")
        Strats_Tryer "$ans"
        pause_enter
        ;;
      "5")
        local user_domain=""
        echo "Через пробел можно указать несколько доменов, но проверка будет недоступна"
        read -re -p "Введите домен (например test.com или https://test.com/) или Enter для выхода: " user_domain
        user_domain=$(sed -E 's~https?://~~g; s~([^[:space:]]+)/~\1~g' <<< "$user_domain")
        [ -z "$user_domain" ] && continue
        Strats_Tryer "$user_domain"
        pause_enter
        ;;
      "55")
        if [ -n "$CONFIG_UPDATE_NOTICE" ]; then
          menu_action_update_config_reset
          pause_enter
        else
          echo -e "${yellow}Неверный ввод.${plain}"
          sleep 1
        fi
        ;;
      "6")
        strategy_files_submenu
        ;;
	  "9")
		echo "Выполняем переключение и перезапуск zapret"
		toggle_fooling_mode_state
		rebuild_config_and_restart
		echo -e "${green}Выполнено переключение фулинга. Запрет перезапущен ${plain}"
		pause_enter
		;;
      "0"|"")
        return
        ;;
      *)
        echo -e "${yellow}Неверный ввод.${plain}"
        sleep 1
        ;;
    esac
  done
}

strategy_files_submenu() {
  local pending_tcp=""
  local pending_udp=""
  local has_changes=0
  local ans num strategy_line type

  toggle_pending_strategy_num() {
    local list="$1"
    local item="$2"
    local line out="" found=0

    while IFS= read -r line; do
      [ -n "$line" ] || continue
      if [ "$line" = "$item" ]; then
        found=1
        continue
      fi
      out="${out}${out:+
}$line"
    done <<EOF
$list
EOF

    if [ "$found" -eq 0 ]; then
      out="${out}${out:+
}$item"
    fi
    echo "$out"
  }

  remove_pending_strategy_num() {
    local list="$1"
    local item="$2"
    local line out=""

    while IFS= read -r line; do
      [ -n "$line" ] || continue
      [ "$line" = "$item" ] && continue
      out="${out}${out:+
}$line"
    done <<EOF
$list
EOF
    echo "$out"
  }

  apply_pending_strategy_toggles() {
    local type="$1"
    local list="$2"
    local line

    while IFS= read -r line; do
      [ -n "$line" ] || continue
      toggle_strategy_file "$type" "$line" || return 1
    done <<EOF
$list
EOF
    return 0
  }

  reset_pending_strategy_toggles() {
    pending_tcp=""
    pending_udp=""
    has_changes=0
  }

  resolve_custom_strategy_type() {
    local num="$1"
    local tcp_exists=0 udp_exists=0 choice

    strategy_file_exists TCP "$num" && tcp_exists=1
    strategy_file_exists UDP "$num" && udp_exists=1

    if [ "$tcp_exists" -eq 1 ] && [ "$udp_exists" -eq 0 ]; then
      echo "TCP"
      return 0
    fi
    if [ "$tcp_exists" -eq 0 ] && [ "$udp_exists" -eq 1 ]; then
      echo "UDP"
      return 0
    fi
    if [ "$tcp_exists" -eq 1 ] && [ "$udp_exists" -eq 1 ]; then
      read -re -p "Найдены TCP и UDP стратегии с этим номером. Введите тип (TCP/UDP): " choice
      case "$choice" in
        TCP|tcp) echo "TCP"; return 0 ;;
        UDP|udp) echo "UDP"; return 0 ;;
      esac
      echo "Неверный тип стратегии." >&2
      return 1
    fi

    echo "Пользовательская стратегия $num не найдена." >&2
    return 1
  }

  while true; do
    clear
    echo -e "${cyan}--- Файлы стратегий ---${plain}"
    print_strategy_files_status TCP "$pending_tcp"
    echo ""
    print_strategy_files_status UDP "$pending_udp"
    echo ""
    submenu_item "1" "Включить/отключить TCP стратегию"
    submenu_item "2" "Включить/отключить UDP стратегию"
    submenu_item "3" "Добавить пользовательскую TCP стратегию"
    submenu_item "4" "Добавить пользовательскую UDP стратегию"
    submenu_item "5" "Удалить пользовательскую стратегию (полностью)"
    submenu_item "6" "Посмотреть пользовательскую стратегию"
    submenu_item "0" "Назад / Сохранить"
    echo ""

    read -re -p "Ваш выбор: " ans
    case "$ans" in
      "1")
        read -re -p "Введите номер TCP стратегии: " num
        if strategy_file_exists TCP "$num"; then
          pending_tcp="$(toggle_pending_strategy_num "$pending_tcp" "$num")"
          has_changes=1
        else
          echo "Стратегия TCP/$num не найдена."
        fi
        pause_enter
        ;;
      "2")
        read -re -p "Введите номер UDP стратегии: " num
        if strategy_file_exists UDP "$num"; then
          pending_udp="$(toggle_pending_strategy_num "$pending_udp" "$num")"
          has_changes=1
        else
          echo "Стратегия UDP/$num не найдена."
        fi
        pause_enter
        ;;
      "3")
        read -re -p "Введите строку TCP стратегии: " strategy_line
        if add_custom_strategy_file TCP "$strategy_line"; then
          has_changes=1
        fi
        pause_enter
        ;;
      "4")
        read -re -p "Введите строку UDP стратегии: " strategy_line
        if add_custom_strategy_file UDP "$strategy_line"; then
          has_changes=1
        fi
        pause_enter
        ;;
      "5")
        read -re -p "Введите номер пользовательской стратегии для удаления: " num
        case "$num" in
          ''|*[!0-9]*) echo "Неверный номер стратегии." ;;
          *)
            if [ "$num" -lt "$CUSTOM_STRATEGY_START" ]; then
              echo "Удалять можно только пользовательские стратегии с номером $CUSTOM_STRATEGY_START и выше."
            else
              type="$(resolve_custom_strategy_type "$num")"
              if [ "$type" = "TCP" ] || [ "$type" = "UDP" ]; then
                if delete_custom_strategy_file "$type" "$num"; then
                  pending_tcp="$(remove_pending_strategy_num "$pending_tcp" "$num")"
                  pending_udp="$(remove_pending_strategy_num "$pending_udp" "$num")"
                  apply_pending_strategy_toggles TCP "$pending_tcp" || { pause_enter; continue; }
                  apply_pending_strategy_toggles UDP "$pending_udp" || { pause_enter; continue; }
                  if rebuild_config_and_restart; then
                    delete_strategy_hostlists_full "$type" "$num"
                    reset_pending_strategy_toggles
                  fi
                fi
              fi
            fi
            ;;
        esac
        pause_enter
        ;;
      "6")
        read -re -p "Введите номер пользовательской стратегии для просмотра: " num
        case "$num" in
          ''|*[!0-9]*) echo "Неверный номер стратегии." ;;
          *)
            if [ "$num" -lt "$CUSTOM_STRATEGY_START" ]; then
              echo "Просматривать здесь можно только пользовательские стратегии с номером $CUSTOM_STRATEGY_START и выше."
            else
              type="$(resolve_custom_strategy_type "$num")"
              if [ "$type" = "TCP" ] || [ "$type" = "UDP" ]; then
                show_custom_strategy_file "$type" "$num"
              fi
            fi
            ;;
        esac
        pause_enter
        ;;
      "0"|"")
        if [ "$has_changes" -eq 1 ]; then
          apply_pending_strategy_toggles TCP "$pending_tcp" || { pause_enter; continue; }
          apply_pending_strategy_toggles UDP "$pending_udp" || { pause_enter; continue; }
          rebuild_config_and_restart
        fi
        return
        ;;
      *)
        echo -e "${yellow}Неверный ввод.${plain}"
        sleep 1
        ;;
    esac
  done
}

flowoffload_submenu() {
  while true; do
    clear
    echo -e "${cyan}--- FLOWOFFLOAD ---${plain}"
    echo "Текущее состояние: $(grep '^FLOWOFFLOAD=' /opt/zapret/config 2>/dev/null)"
    echo ""

    submenu_item "1" "software (программное ускорение)"
    submenu_item "2" "hardware (аппаратное NAT)"
    submenu_item "3" "none (отключено)"
    submenu_item "4" "donttouch (дефолт)"
    submenu_item "0" "Назад"
    echo ""

    read -re -p "Ваш выбор: " ans

    case "$ans" in
      "1")
        sed -i 's/^FLOWOFFLOAD=.*/FLOWOFFLOAD=software/' "/opt/zapret/config"
        /opt/zapret/install_prereq.sh
        /opt/zapret/init.d/sysv/zapret restart
        echo -e "${green}FLOWOFFLOAD=software применён.${plain}"
        pause_enter
        ;;
      "2")
        sed -i 's/^FLOWOFFLOAD=.*/FLOWOFFLOAD=hardware/' "/opt/zapret/config"
        /opt/zapret/install_prereq.sh
        /opt/zapret/init.d/sysv/zapret restart
        echo -e "${green}FLOWOFFLOAD=hardware применён.${plain}"
        pause_enter
        ;;
      "3")
        sed -i 's/^FLOWOFFLOAD=.*/FLOWOFFLOAD=none/' "/opt/zapret/config"
        /opt/zapret/install_prereq.sh
        /opt/zapret/init.d/sysv/zapret restart
        echo -e "${green}FLOWOFFLOAD=none применён.${plain}"
        pause_enter
        ;;
      "4")
        sed -i 's/^FLOWOFFLOAD=.*/FLOWOFFLOAD=donttouch/' "/opt/zapret/config"
        /opt/zapret/install_prereq.sh
        /opt/zapret/init.d/sysv/zapret restart
        echo -e "${green}FLOWOFFLOAD=donttouch применён.${plain}"
        pause_enter
        ;;
      "0"|"")
        return
        ;;
      *)
        echo -e "${yellow}Неверный ввод.${plain}"
        sleep 1
        ;;
    esac
  done
}

provider_submenu() {
  provider_init_once

  while true; do
    clear
    echo -e "${cyan}--- Провайдер / подсказки ---${plain}"
    echo -e "Текущий провайдер: ${green}${PROVIDER_MENU}${plain}"
    echo ""

    submenu_item "1" "Указать провайдера вручную"
    submenu_item "2" "Определить провайдера заново (сбросить кэш)"
    submenu_item "3" "Обновить базу рекомендаций (подсказки)"
    submenu_item "0" "Назад"
    echo ""

    read -re -p "Ваш выбор: " ans

    case "$ans" in
      "1")
        provider_set_manual_menu
        sleep 1
        pause_enter
        ;;
      "2")
        provider_force_redetect
        sleep 1
        pause_enter
        ;;
      "3")
        echo "Обновляем базу рекомендаций..."
        rm -f "$RECS_FILE"
        update_recommendations
        if [ -s "$RECS_FILE" ]; then
          echo -e "${green}База успешно обновлена!${plain}"
        else
          echo -e "${red}Ошибка обновления базы.${plain}"
        fi
        sleep 1
        pause_enter
        ;;
      "0"|"")
        return
        ;;
      *)
        echo -e "${yellow}Неверный ввод.${plain}"
        sleep 1
        ;;
    esac
  done
}

keenetic_policy_submenu() {
  while true; do
    clear
    echo -e "${cyan}--- Keenetic Policy ---${plain}"
    echo -e "Текущее состояние: ${green}$(get_keenetic_policy_status)${plain}"
    echo ""

    submenu_item "1" "Задать или очистить имя политики"
    submenu_item "2" "$( [ "$(get_keenetic_policy_mode_label)" = "Все, кроме устройств из политики" ] && echo "Переключить режим применения на \"Только устройства из политики\"" || echo "Переключить режим применения на \"Все, кроме устройств из политики\"" )"
    submenu_item "0" "Назад"
    echo ""

    read -re -p "Ваш выбор: " ans

    case "$ans" in
      "1")
        menu_action_set_keenetic_policy_name
        pause_enter
        ;;
      "2")
        menu_action_toggle_keenetic_policy_mode
        pause_enter
        ;;
      "0"|"")
        return
        ;;
      *)
        echo -e "${yellow}Неверный ввод.${plain}"
        sleep 1
        ;;
    esac
  done
}
