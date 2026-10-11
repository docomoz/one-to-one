# Сервер Appwrite

Как устроен, как поднять заново, как обновлять и что делать при сбое. Зачем свой сервер: `docs/superpowers/specs/2026-10-11-own-backend-design.md`.

## Что где

| Что | Где |
|---|---|
| Сервер | Timeweb Cloud, Санкт-Петербург (в Москве не было мест), Ubuntu 24.04, 2 vCPU / 2 ГБ RAM / 30 ГБ NVMe + swap 4 ГБ, IP `194.87.44.100`, аккаунт Максима. Перед запуском поднять до 4 ГБ RAM |
| Адрес API | `https://api.194-87-44-100.sslip.io/v1` — пока без своего домена (sslip.io сам указывает на IP из имени). Перед публикацией переехать на свой домен, см. «Переезд на свой домен» |
| Консоль Appwrite | `https://api.194-87-44-100.sslip.io/console` (вход: почта и пароль администратора из менеджера паролей Максима). Регистрация закрыта (`_APP_CONSOLE_WHITELIST_ROOT=enabled`): других людей приглашать из консоли, Organization → Members |
| Проект | `one-to-one`, Project ID `6acbe1c5001b61609635`, платформа Apple `com.docomoz.onetoone`, вход только Email OTP |
| Appwrite | версия 2.4.0, база PostgreSQL, файлы и `.env` в `/root/appwrite` на сервере |
| Почта для кодов | на время разработки SMTP Gmail (Google Workspace `maxim@docomoz.com`, пароль приложения). Перед публикацией — сервис рассылок с отправителем на своём домене (Unisender Go) |
| Резервные копии | автоматические бэкапы Timeweb, ежедневно (хранятся отдельно от сервера). Перед запуском добавить ежедневный дамп базы в S3 |
| SSH | `ssh -i ~/.ssh/one-to-one-timeweb root@194.87.44.100` (ключ на Маке Максима; второй ключ для Дарьи добавлять в `/root/.ssh/authorized_keys`) |

Секреты (пароль администратора консоли, секретный ключ Appwrite из мастера, пароль приложения Gmail, позже ключи S3) хранятся только в менеджере паролей и в `/root/appwrite/.env` на сервере. В git их нет.

## Установка с нуля

1. **Сервер.** Timeweb Cloud → Облачные серверы → Создать: регион в России (Москва или Санкт-Петербург; если «предзаказ» — мест нет, выбрать другой город), Ubuntu 24.04, обычный тариф (не «выделенные ядра») от 2 vCPU / 2 ГБ / 30 ГБ NVMe, публичный IPv4, SSH-ключ `~/.ssh/one-to-one-timeweb.pub`, автоматические бэкапы включить.
2. **Почтовые порты.** Новые серверы Timeweb не выпускают почту наружу. Тикет в поддержку: «откройте исходящие 465 и 587 на сервере <IP>, сервер отправляет письма с кодами входа через внешний SMTP». Проверка с сервера: `timeout 8 bash -c "</dev/tcp/smtp.gmail.com/587" && echo open`.
3. **Адрес.** Без своего домена: `api.<IP через дефисы>.sslip.io`. Со своим доменом: запись `A` для `api.<домен>` → IP, проверка `dig +short api.<домен>`.
4. **Подготовка сервера** (по SSH):
   ```bash
   apt-get update && apt-get -y upgrade
   fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
   echo '/swapfile none swap sw 0 0' >> /etc/fstab
   sysctl -w vm.swappiness=10 && echo 'vm.swappiness=10' > /etc/sysctl.d/99-swappiness.conf
   curl -fsSL https://get.docker.com | sh
   ufw allow OpenSSH && ufw allow 80/tcp && ufw allow 443/tcp && ufw --force enable
   ```
5. **Установщик Appwrite.** Мастер слушает только внутри сервера, наружу его не открываем:
   ```bash
   # на сервере
   docker run -d -t --name appwrite-installer --publish 127.0.0.1:20080:20080 \
     --volume /var/run/docker.sock:/var/run/docker.sock \
     --volume /root/appwrite:/usr/src/code/appwrite:rw \
     --entrypoint=install appwrite/appwrite:2.4.0
   docker logs appwrite-installer   # ссылка с ?secret=…
   # на Маке — туннель, затем открыть ссылку из логов в браузере
   ssh -i ~/.ssh/one-to-one-timeweb -f -N -L 20080:127.0.0.1:20080 root@<IP>
   ```
   В мастере: Hostname — адрес из шага 3, «Use HTTPS» включить, база PostgreSQL. Секретный ключ и пароль администратора — в менеджер паролей.
   - На 2 ГБ RAM мастер может написать «Failed to connect with Appwrite in time»: он проверяет сервер по HTTP и получает переадресацию на HTTPS. Не нажимать «Reset Everything». Проверить `cd /root/appwrite && docker compose ps` — если всё `Up`/`healthy`, установка удалась.
   - После мастера: `docker rm -f appwrite-installer` и закрыть туннель (`pkill -f "L 20080"`).
6. **Сертификат HTTPS.** Если `echo | openssl s_client -connect <адрес>:443 -servername <адрес> 2>/dev/null | openssl x509 -noout -issuer` показывает `TRAEFIK DEFAULT CERT`, выпустить вручную: `cd /root/appwrite && docker compose exec appwrite ssl --domain=<адрес>`. Через минуту issuer — Let's Encrypt.
7. **Консоль:** первый зарегистрированный — администратор, дальше регистрация закрыта. Create project `one-to-one`; Add platform → Apple → iOS, bundle id `com.docomoz.onetoone`; Auth → Settings: только Email OTP.
8. **Почта.** Сам пароль через Claude не проходит: Максим запускает у себя команду, которая спрашивает адрес и пароль и пишет их в `/root/appwrite/.env`:
   ```bash
   ssh -t -i ~/.ssh/one-to-one-timeweb root@<IP> 'read -p "Адрес Gmail: " G; read -s -p "Пароль приложения: " P; echo; cd /root/appwrite && cp .env .env.bak && for k in _APP_SMTP_HOST _APP_SMTP_PORT _APP_SMTP_SECURE _APP_SMTP_USERNAME _APP_SMTP_PASSWORD _APP_SYSTEM_EMAIL_ADDRESS _APP_SYSTEM_EMAIL_NAME; do sed -i "/^$k=/d" .env; done && printf "%s\n" "_APP_SMTP_HOST=smtp.gmail.com" "_APP_SMTP_PORT=587" "_APP_SMTP_SECURE=tls" "_APP_SMTP_USERNAME=$G" "_APP_SMTP_PASSWORD=${P// /}" "_APP_SYSTEM_EMAIL_ADDRESS=$G" "_APP_SYSTEM_EMAIL_NAME=one-to-one" >> .env && docker compose up -d >/dev/null 2>&1 && rm -f .env.bak && echo "Готово"'
   ```
   Для другого SMTP поменять `_APP_SMTP_HOST`, порт и логин. Проверить: `docker compose exec appwrite vars | grep SMTP`.

## Проверка, что всё работает

```bash
curl -s https://api.194-87-44-100.sslip.io/v1/health/version
# Письмо с кодом на тестовую почту:
curl -s -X POST https://api.194-87-44-100.sslip.io/v1/account/tokens/email \
  -H 'Content-Type: application/json' -H 'X-Appwrite-Project: 6acbe1c5001b61609635' \
  -d '{"userId":"unique()","email":"<тестовая почта>"}'
```
Письмо с кодом должно прийти, не в спам. Тест создаёт неподтверждённого пользователя в проекте — удалить его в консоли (Auth → Users).

## Резервные копии

- Автоматические бэкапы Timeweb: снимок всего диска раз в сутки, хранятся отдельно от сервера, восстанавливаются из панели Timeweb. Включены.
- Перед запуском (#88): ежедневный дамп базы в S3 Timeweb и один раз проверенное восстановление.

## Переезд на свой домен (перед публикацией)

1. Запись `A` для `api.<домен>` → `194.87.44.100`.
2. В `/root/appwrite/.env`: `_APP_DOMAIN` и `_APP_DOMAIN_TARGET` = `api.<домен>`; `docker compose up -d`.
3. Сертификат: `docker compose exec appwrite ssl --domain=api.<домен>`.
4. В приложении поменять адрес API (`Config/App.xcconfig`, появится в #83) и выпустить новую сборку. Данные никуда не переезжают.
5. Отправитель писем на своём домене (Unisender Go: подтвердить домен записями SPF и DKIM, поменять SMTP в `.env`).

## Обновление Appwrite

1. Снять бэкап (снимок в Timeweb + дамп базы).
2. Прочитать заметки к новой версии на appwrite.io/changelog: нет ли ломающих изменений.
3. По SSH, из `/root`:
   ```bash
   docker run -it --rm \
     --volume /var/run/docker.sock:/var/run/docker.sock \
     --volume /root/appwrite:/usr/src/code/appwrite:rw \
     --entrypoint="upgrade" \
     appwrite/appwrite:<новая версия>
   cd /root/appwrite && docker compose exec appwrite migrate
   ```
4. Проверка из раздела выше. Поменять версию в этом документе.

## Если что-то сломалось

- **API не отвечает:** `cd /root/appwrite && docker compose ps` — все контейнеры `running`? Если нет: `docker compose logs --tail=100 <контейнер>`, затем `docker compose up -d`.
- **Кончилось место:** `df -h`; почистить старые образы `docker image prune -a`.
- **Письма не приходят:** `docker compose logs --since=10m appwrite-worker | grep -A8 v1-mails` — `mail.status` должен быть `success`. Проверить SMTP в `.env` и что почтовые порты открыты (шаг 2 установки).
- **Сертификат HTTPS:** шаг 6 установки; логи — `docker compose logs --since=10m appwrite-worker | grep -A8 v1-certificates`. Адрес должен указывать на сервер, порт 80 открыт.
- **Совсем плохо:** восстановить снимок сервера в панели Timeweb.

## Журнал

| Дата | Что сделано |
|---|---|
| 2026-10-11 | Сервер в Питере (Москва — предзаказ), Appwrite 2.4.0 на `api.194-87-44-100.sslip.io`, сертификат выпущен вручную, Timeweb открыл почтовые порты (тикет N12816391), SMTP Gmail, тестовое письмо с кодом дошло. Проект `one-to-one` создан. |
