# Быстрый старт: Keycloak + Kong OIDC

## Минимальные шаги для настройки

### 1. Запуск сервисов
```bash
docker-compose up -d
```

### 2. Настройка Keycloak через веб-интерфейс

1. Откройте http://localhost:8080
2. Войдите: `admin` / `admin`
3. Создайте Realm: `myrealm`
4. Создайте Client:
   - Client ID: `kong-client`
   - Client authentication: `ON`
   - Standard flow: `ON`
   - Direct access grants: `ON`
   - Service accounts: `ON`
   - Valid redirect URIs: `https://api.example.com/*`
5. Скопируйте **Client Secret** из вкладки **Credentials**

### 3. Обновление конфигурации Kong

Отредактируйте `kong/kong.yml`:
- Замените `YOUR_CLIENT_SECRET_HERE` на реальный Client Secret
- Проверьте `client_id: kong-client`

### 4. Перезапуск Kong
```bash
docker-compose restart kong
```

### 5. Тестирование

```bash
# Получение токена
export CLIENT_SECRET="your-client-secret"
export USERNAME="testuser"
export PASSWORD="testpassword"

curl -X POST http://localhost:8080/realms/myrealm/protocol/openid-connect/token \
  -d "client_id=kong-client" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "username=${USERNAME}" \
  -d "password=${PASSWORD}" \
  -d "grant_type=password" | jq -r '.access_token'

# Использование токена
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8000/api/test
```

## Автоматическая настройка (альтернатива)

```bash
# Настройка через скрипт (требует jq)
chmod +x setup-keycloak-realm.sh
./setup-keycloak-realm.sh

# Тестирование
chmod +x test-integration.sh
export CLIENT_SECRET="your-secret"
export USERNAME="testuser"
export PASSWORD="testpassword"
./test-integration.sh
```

## Основные параметры для Kong OIDC плагина

| Параметр | Значение | Описание |
|----------|----------|----------|
| `issuer` | `http://keycloak:8080/realms/myrealm` | URL realm |
| `client_id` | `kong-client` | ID клиента из Keycloak |
| `client_secret` | `***` | Секрет клиента |
| `discovery` | `http://keycloak:8080/realms/myrealm/.well-known/openid-configuration` | Discovery endpoint |
| `bearer_only` | `yes` | Только проверка токенов |
| `realm` | `myrealm` | Имя realm |

## Полезные команды

```bash
# Проверка health
curl http://localhost:8080/health/ready  # Keycloak
curl http://localhost:8001/status        # Kong

# Просмотр логов
docker-compose logs -f keycloak
docker-compose logs -f kong

# Проверка OIDC discovery
curl http://localhost:8080/realms/myrealm/.well-known/openid-configuration | jq
```

## Множественные клиенты для разных бэкендов

Если у вас несколько бэкенд-сервисов, создайте отдельный клиент в Keycloak для каждого:

```bash
# Автоматическое создание множественных клиентов
chmod +x setup-multiple-clients.sh
./setup-multiple-clients.sh
```

См. [MULTIPLE_CLIENTS_SETUP.md](./MULTIPLE_CLIENTS_SETUP.md) для подробной инструкции.

Подробная документация: см. `KEYCLOAK_KONG_SETUP.md`
