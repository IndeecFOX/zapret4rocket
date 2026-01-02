# Network / access checks

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
