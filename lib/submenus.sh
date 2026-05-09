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
    echo -e "${yellow}Подобрать стратегию? (1-5 для подбора, 0 или Enter для отмены)${plain}"
    echo -e "  Текущие стратегии [${strategies_status}]"
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
  while true; do
    clear
    echo -e "${cyan}--- Файлы стратегий ---${plain}"
    print_strategy_files_status TCP
    echo ""
    print_strategy_files_status UDP
    echo ""
    submenu_item "1" "Включить/отключить TCP стратегию"
    submenu_item "2" "Включить/отключить UDP стратегию"
    submenu_item "3" "Добавить пользовательскую TCP стратегию"
    submenu_item "4" "Добавить пользовательскую UDP стратегию"
    submenu_item "0" "Назад"
    echo ""

    read -re -p "Ваш выбор: " ans
    case "$ans" in
      "1")
        read -re -p "Введите номер TCP стратегии: " num
        if toggle_strategy_file TCP "$num"; then
          rebuild_config_and_restart
        fi
        pause_enter
        ;;
      "2")
        read -re -p "Введите номер UDP стратегии: " num
        if toggle_strategy_file UDP "$num"; then
          rebuild_config_and_restart
        fi
        pause_enter
        ;;
      "3")
        read -re -p "Введите строку TCP стратегии: " strategy_line
        if add_custom_strategy_file TCP "$strategy_line"; then
          rebuild_config_and_restart
        fi
        pause_enter
        ;;
      "4")
        read -re -p "Введите строку UDP стратегии: " strategy_line
        if add_custom_strategy_file UDP "$strategy_line"; then
          rebuild_config_and_restart
        fi
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
