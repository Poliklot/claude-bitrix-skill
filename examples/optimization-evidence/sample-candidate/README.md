# Optimization evidence pack

Сгенерированный evidence pack для аудита оптимизаций Bitrix-проекта.
Перед коммитом удали secrets, cookies, session ids, production XML/дампы, персональные данные и приватный HTML.

Проверка:

```bash
python3 scripts/validate_optimization_evidence.py examples/optimization-evidence/sample-candidate
```
