#!/bin/bash
set -e

#New Script Warning
bold_red='\033[1;31m'
reset='\033[0m'
echo -e "${bold_red}Это версия скрипта более не поддерживается, новая версия в репозитарии https://github.com/IndeecFOX/zapret4rocket
Скрипт новой версии:
curl -O https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/refs/heads/master/z4r.sh && bash z4r.sh && rm z4r.sh${reset}"

#Запрос на установку 3x-ui или аналогов
read -p "Install tunneling software?: (3xui, marzban, wg, 3proxy or Enter for none): " answer
# Удаляем лишние символы и пробелы, приводим к верхнему регистру
clean_answer=$(echo "$answer" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
if [[ -z "$clean_answer" ]]; then
    echo "Skipping tunneling soft installation (default action)."
elif [[ "$clean_answer" == "3XUI" ]]; then
    echo "Installing 3x-ui panel..."
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
elif [[ "$clean_answer" == "WG" ]]; then
    echo "Installing wg..."
    bash <(curl -Ls https://raw.githubusercontent.com/angristan/wireguard-install/refs/heads/master/wireguard-install.sh)
elif [[ "$clean_answer" == "3PROXY" ]]; then
    echo "Installing 3proxy..."
    bash <(curl -Ls https://raw.githubusercontent.com/SnoyIatk/3proxy/master/3proxyinstall.sh)
    wget -O /etc/3proxy/.proxyauth https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/refs/heads/master/del.proxyauth
    wget -O /etc/3proxy/3proxy.cfg https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/refs/heads/master/3proxy.cfg
    #mv del.proxyauth .proxyauth
    #mv .proxyauth /etc/3proxy/
    #mv 3proxy.cfg /etc/3proxy/
    systemctl restart 3proxy
elif [[ "$clean_answer" == "MARZBAN" ]]; then
    bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install
else
    echo "Skipping tunneling soft installation."
fi

# Обновление пакетов и установка unzip
apt update && apt install -y unzip && apt install -y git

# Переход в директорию /opt
cd /opt

#Удаление старого запрета, если есть
if [ -f "zapret/uninstall_easy.sh" ]; then
    echo "Файл zapret/uninstall_easy.sh найден. Выполняем его"
    sh zapret/uninstall_easy.sh
    echo "Скрипт uninstall_easy.sh выполнен."
else
    echo "Файл zapret/uninstall_easy.sh не найден. Переходим к следующему шагу."
fi
if [ -d "zapret" ]; then
    echo "Удаляем папку zapret"
    rm -rf zapret
    echo "Папка zapret успешно удалена."
else
    echo "Папка zapret не существует."
fi

# Распаковка архива zapret и его удаление
wget https://github.com/bol-van/zapret/releases/download/v71.1/zapret-v71.1.zip
unzip zapret-v71.1.zip
rm -f zapret-v71.1.zip
mv zapret-v71.1 zapret

#Клонируем репозиторий и забираем папки lists и fake, удаляем репозиторий
git clone https://github.com/IndeecFOX/zapret4rocket.git
cp -r zapret4rocket/lists /opt/zapret/
cp -r zapret4rocket/fake /opt/zapret/files/
cp -r zapret4rocket/extra_strats /opt/zapret/
rm -rf zapret4rocket
#chmod -R 777 /opt/zapret/fake
#chmod -R 777 /opt/zapret/lists

#Копирование нашего конфига на замену стандартному
wget -O config.default https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/config.default
mv config.default /opt/zapret/

# Запуск установочных скриптов
sh zapret/install_bin.sh
sh zapret/install_prereq.sh
sh -i zapret/install_easy.sh

# Перезагрузка zapret с помощью systemd
echo "Перезагружаем zapret..."
systemctl restart zapret
echo "Установка завершена"
