# submenus.sh
# Единый стиль: loop + return на 0/Enter

#функция меню "1. Сменить стратегии"
strategies_submenu() {
  while true; do
    local strategies_status
    strategies_status=$(get_current_strategies_info)
    clear

    echo -e "${cyan}--- Управление стратегиями ---${plain}"
    echo -e "${yellow}Подобрать стратегию? (1-5 для подбора, 0 или Enter для отмены)${plain}"
    echo -e "  Текущие стратегии [${strategies_status}]"
    echo -e 

    submenu_item "	1" "YouTube с видеопотоком (UDP QUIC)." "8 вариантов"
    submenu_item "	2" "YouTube (TCP. Интерфейс)." "17 вариантов (Приоритетнее безразборного режима)"
    submenu_item "	3" "YouTube (TCP. Видеопоток/GV домен)." "17 вариантов (Приоритетнее безразборного режима)"
    submenu_item "	4" "RKN (Популярные блокированные сайты. Дискорд в т.ч.)." "17 вариантов"
    submenu_item "	5" "Отдельный домен." "17 вариантов (Приоритетнее безразборного режима)"
	submenu_item "	9" "$(grep -q "fooling=ts,badsum" "/opt/zapret/config" && echo "Переключить фулинг с ${yellow}ts+badsum на ts" || echo "Переключить фулинг с ${yellow}ts на ts+badsum")" "Может помочь с Discord или иными ресурсами"
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
	  "9")
		echo "Выполняем переключение и перезапуск zapret"
		sed -i '/fooling=ts,badsum/s/ts,badsum/ts/; t; s/fooling=ts/fooling=ts,badsum/' /opt/zapret/config
		/opt/zapret/init.d/sysv/zapret restart
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
