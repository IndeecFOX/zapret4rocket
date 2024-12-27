Установит запрет 69.8
Включит скрипт для дискорда, установит рабочие на данный момент стратегии.
Всё что нужно - это ввести целиком скопировав команды данные ниже и нажать Enter. Затем повторить нажание Enter на любые запросы.
Метод подключения к серверу выбираете самостоятельно. Я проверял на WG. Vless так же работает (Для Discord нужен TUN)
Проверено на rocketcloud.ru ubuntu 24v. Дебиан так же должен подойти.

Установка и развёртвывание zapret antiDPI под ключ на российских VPS (проверено на rocketcloud.ru) копируем всё сразу и вставляем в ssh:
```
wget https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/refs/heads/master/fast_install.sh -O fast_install.sh && chmod +x fast_install.sh && ./fast_install.sh
```

На все вопросы жмём Enter. По окончании всё будет работать. К серверу подключаетесь как хотите уже, WG/VLESS/OpenVPN
YouTube летает, есть доступы к ntc.party, meduza.io и прочему. Дискорд (Discord) работает (при подключении через TUN для VLESS или протоколы с поддержкой UDP, иначе войса не будет)
