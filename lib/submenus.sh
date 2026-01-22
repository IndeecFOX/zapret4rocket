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
    submenu_item "	2" "YouTube (TCP. Интерфейс)." "17 вариантов"
    submenu_item "	3" "YouTube (TCP. Видеопоток/GV домен)." "17 вариантов"
    submenu_item "	4" "RKN (Популярные блокированные сайты. Дискорд в т.ч.)." "17 вариантов"
    submenu_item "	5" "Отдельный домен." "17 вариантов"
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

tcp443_submenu() {
  while true; do
  clear
  num=$(sed -n '112,128p' /opt/zapret/config | grep -n '^--filter-tcp=443 --hostlist-domains= --' | head -n1 | cut -d: -f1)
  echo -e "${yellow}Безразборный режим по стратегии: ${plain}$((num ? num : 0))"
  echo -e "\033[33mС каким номером применить стратегию? (1-17, 0 - отключение безразборного режима, Enter - выход) \033[31mПри активации кастомно подобранные домены будут очищены:${plain}"
  read -re -p " " answer_bezr
  
  case "$answer_bezr" in
    "" )
      return
      ;;
    *)
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
          echo "Добавить ru домены в исключения? (Обычно не заблокированы и могут ломаться режимом)"
          read -re -p "Enter - да, 1 - нет: " add_ru
          if [ -n "$add_ru" ]; then
            echo "Пропуск добавления ru доменов."
          else
            echo "ru" >> /opt/zapret/lists/netrogat.txt
            echo -e "Домены ru добавлены в исключения (netrogat.txt)."
          fi
          sed -i "$((111 + answer_bezr))s/--hostlist-domains=none\.dom/--hostlist-domains=/" /opt/zapret/config
          /opt/zapret/init.d/sysv/zapret restart
          echo -e "${green}Выполнена команда перезапуска zapret. ${yellow}Безразборный режим активирован на $answer_bezr стратегии для TCP-443. Проверка доступа к meduza.io${plain}"
          check_access_list
        fi
        read -n 1 -s -r -p "Нажмите любую клавишу для продолжения..."
      else
        echo -e "${yellow}Неверный ввод.${plain}"
        sleep 1
        pause_enter
      fi
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
