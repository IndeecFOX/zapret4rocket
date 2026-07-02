# Contributing

## Smoke tests

Для проверки profile lock логики перед PR запустите:

```bash
bash tests/profile_lock_smoke.sh
```

Тест работает только с временной директорией в `/tmp`:

- не пишет в `/opt`;
- не запускает и не останавливает `zapret2`;
- проверяет `bash -n` для основных shell-файлов;
- проверяет `profile.lock` storage: `auto` как отсутствие записи, `skip`, `N`, `clear`;
- проверяет idempotent `profile_apply_all`;
- проверяет `YT_UDP`, `YT_TCP`, `RKN`, `VOICE_UDP`;
- проверяет, что TCP hostlist-правки не затрагивают отдельную Discord TCP-строку;
- проверяет, что некорректный stale lock вроде `YT_UDP 99` не роняет apply.

Успешный результат:

```text
profile_lock smoke ok
```
