/opt/zapret2/nfq2/nfqws2 --dry-run --user="nobody"
/opt/zapret2/nfq2/nfqws2 --dry-run --user="$(head -n1 /etc/passwd | cut -d: -f1)"
 if /opt/zapret2/nfq2/nfqws2 --dry-run --user="nobody" 2>&1 | grep -q "queue"; then
    echo "WS_USER=nobody"
 elif /opt/zapret2/nfq2/nfqws2 --dry-run --user="$(head -n1 /etc/passwd | cut -d: -f1)" 2>&1 | grep -q "queue"; then
    echo "WS_USER=$(head -n1 /etc/passwd | cut -d: -f1)"
 else
  echo -e "${yellow}WS_USER не подошёл. Скорее всего будут проблемы. Если что - пишите в саппорт${plain}"
 fi
