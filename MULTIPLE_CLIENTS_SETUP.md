# Настройка множественных клиентов Keycloak для разных бэкендов

## Обзор

Когда API Gateway обслуживает множество бэкенд-сервисов, рекомендуется создавать отдельный клиент в Keycloak для каждого сервиса. Это обеспечивает:

- **Изоляцию доступа**: каждый сервис имеет свой client_id и client_secret
- **Гибкость**: разные настройки токенов и прав доступа для разных сервисов
- **Безопасность**: компрометация одного клиента не влияет на другие
- **Аудит**: легче отслеживать доступ к каждому сервису отдельно

## Архитектура

```
Client Application
    ↓ [mTLS]
Nginx (443)
    ↓ [HTTP]
Kong API Gateway
    ├─→ /api/users → user-service-client → User Backend
    ├─→ /api/orders → order-service-client → Order Backend
    ├─→ /api/payments → payment-service-client → Payment Backend
    └─→ /api/admin → admin-service-client → Admin Backend
         ↓
    Keycloak (проверка токенов для каждого клиента)
```

## Шаг 1: Создание множественных клиентов в Keycloak

### 1.1. Создание клиентов для каждого сервиса

Для каждого бэкенд-сервиса создайте отдельный клиент в Keycloak:

#### User Service Client
1. **Clients** → **Create client**
2. **Client ID**: `user-service-client`
3. **Client authentication**: `ON`
4. **Standard flow**: `ON`
5. **Direct access grants**: `ON`
6. **Service accounts**: `ON`
7. **Valid redirect URIs**: `https://api.example.com/api/users/*`
8. Сохраните **Client Secret** из вкладки **Credentials**

#### Order Service Client
1. **Clients** → **Create client**
2. **Client ID**: `order-service-client`
3. **Client authentication**: `ON`
4. **Standard flow**: `ON`
5. **Direct access grants**: `ON`
6. **Service accounts**: `ON`
7. **Valid redirect URIs**: `https://api.example.com/api/orders/*`
8. Сохраните **Client Secret**

#### Payment Service Client
1. **Clients** → **Create client**
2. **Client ID**: `payment-service-client`
3. **Client authentication**: `ON`
4. **Standard flow**: `ON`
5. **Direct access grants**: `ON`
6. **Service accounts**: `ON`
7. **Valid redirect URIs**: `https://api.example.com/api/payments/*`
8. Сохраните **Client Secret**

#### Admin Service Client
1. **Clients** → **Create client**
2. **Client ID**: `admin-service-client`
3. **Client authentication**: `ON`
4. **Standard flow**: `ON`
5. **Direct access grants**: `ON`
6. **Service accounts**: `ON`
7. **Valid redirect URIs**: `https://api.example.com/api/admin/*`
8. Сохраните **Client Secret**

### 1.2. Настройка Audience для каждого клиента (опционально)

Для дополнительной безопасности можно настроить audience в токенах:

1. Перейдите в **Clients** → выберите клиент → **Client scopes**
2. Или создайте mapper:
   - **Mappers** → **Add mapper** → **By configuration**
   - **Mapper type**: `Audience`
   - **Included Client Audience**: имя клиента (например, `user-service-client`)
   - **Add to ID token**: `ON`
   - **Add to access token**: `ON`

## Шаг 2: Настройка Kong для множественных клиентов

### 2.1. Обновление конфигурации Kong

Отредактируйте `kong/kong.yml` с реальными значениями:

```yaml
services:
  - name: user-service
    url: http://user-backend:8080
    routes:
      - name: user-service-route
        paths:
          - /api/users
    plugins:
      - name: oidc
        config:
          issuer: http://keycloak:8080/realms/myrealm
          client_id: user-service-client
          client_secret: REAL_USER_SERVICE_SECRET
          # ... остальные настройки
```

### 2.2. Использование переменных окружения (рекомендуется)

Для безопасности храните секреты в переменных окружения:

```bash
# .env файл
USER_SERVICE_CLIENT_SECRET=your-secret-here
ORDER_SERVICE_CLIENT_SECRET=your-secret-here
PAYMENT_SERVICE_CLIENT_SECRET=your-secret-here
ADMIN_SERVICE_CLIENT_SECRET=your-secret-here
```

Обновите `docker-compose.yml`:

```yaml
kong:
  environment:
    - USER_SERVICE_CLIENT_SECRET=${USER_SERVICE_CLIENT_SECRET}
    - ORDER_SERVICE_CLIENT_SECRET=${ORDER_SERVICE_CLIENT_SECRET}
    # ...
```

## Шаг 3: Настройка ролей и прав доступа

### 3.1. Создание ролей в Keycloak

1. Перейдите в **Realm roles**
2. Создайте роли для каждого сервиса:
   - `user-service:read`
   - `user-service:write`
   - `order-service:read`
   - `order-service:write`
   - `payment-service:process`
   - `admin-service:full-access`

### 3.2. Назначение ролей пользователям

1. Перейдите в **Users** → выберите пользователя → **Role mapping**
2. Назначьте соответствующие роли

### 3.3. Настройка Client Scopes для включения ролей в токены

1. Перейдите в **Client scopes** → `roles` → **Mappers**
2. Убедитесь, что mapper `realm roles` включен:
   - **Token Claim Name**: `realm_access.roles`
   - **Add to ID token**: `ON`
   - **Add to access token**: `ON`

## Шаг 4: Тестирование множественных клиентов

### 4.1. Получение токенов для разных сервисов

```bash
# Токен для User Service
USER_TOKEN=$(curl -s -X POST http://localhost:8080/realms/myrealm/protocol/openid-connect/token \
  -d "client_id=user-service-client" \
  -d "client_secret=USER_SERVICE_SECRET" \
  -d "username=testuser" \
  -d "password=testpassword" \
  -d "grant_type=password" | jq -r '.access_token')

# Токен для Order Service
ORDER_TOKEN=$(curl -s -X POST http://localhost:8080/realms/myrealm/protocol/openid-connect/token \
  -d "client_id=order-service-client" \
  -d "client_secret=ORDER_SERVICE_SECRET" \
  -d "username=testuser" \
  -d "password=testpassword" \
  -d "grant_type=password" | jq -r '.access_token')
```

### 4.2. Тестирование доступа к разным сервисам

```bash
# Доступ к User Service
curl -H "Authorization: Bearer $USER_TOKEN" \
  http://localhost:8000/api/users

# Доступ к Order Service
curl -H "Authorization: Bearer $ORDER_TOKEN" \
  http://localhost:8000/api/orders

# Попытка доступа к Order Service с токеном User Service (должна быть ошибка)
curl -H "Authorization: Bearer $USER_TOKEN" \
  http://localhost:8000/api/orders
```

## Шаг 5: Дополнительные настройки безопасности

### 5.1. Использование Audience для валидации

Включите проверку audience в Kong конфигурации:

```yaml
plugins:
  - name: oidc
    config:
      audience: "user-service-client"  # Проверка audience в токене
```

### 5.2. Настройка разных сроков действия токенов

В Keycloak для каждого клиента можно настроить разные сроки действия:

1. **Clients** → выберите клиент → **Advanced settings**
2. **Access Token Lifespan**: настройте индивидуально для каждого клиента

### 5.3. Использование Service Accounts для M2M коммуникации

Для machine-to-machine коммуникации используйте Service Accounts:

```bash
# Получение токена через Service Account
SERVICE_TOKEN=$(curl -s -X POST http://localhost:8080/realms/myrealm/protocol/openid-connect/token \
  -d "client_id=user-service-client" \
  -d "client_secret=USER_SERVICE_SECRET" \
  -d "grant_type=client_credentials" | jq -r '.access_token')
```

## Шаг 6: Мониторинг и логирование

### 6.1. Логирование доступа к разным сервисам

В Kong можно настроить логирование с информацией о клиенте:

```yaml
plugins:
  - name: file-log
    config:
      path: /var/log/kong/user-service-access.log
      reopen: true
```

### 6.2. Метрики по клиентам

Используйте Prometheus плагин для сбора метрик:

```yaml
plugins:
  - name: prometheus
    config:
      per_consumer: true  # Метрики по каждому клиенту
```

## Шаг 7: Управление секретами

### 7.1. Использование секретов в Docker Compose

```yaml
services:
  kong:
    secrets:
      - user_service_secret
      - order_service_secret
    environment:
      USER_SERVICE_CLIENT_SECRET_FILE: /run/secrets/user_service_secret
```

### 7.2. Использование внешних систем управления секретами

- **HashiCorp Vault**
- **AWS Secrets Manager**
- **Kubernetes Secrets**

## Best Practices

1. **Один клиент на сервис**: не используйте один клиент для нескольких сервисов
2. **Уникальные секреты**: каждый клиент должен иметь уникальный client_secret
3. **Минимальные права**: настройте минимально необходимые права для каждого клиента
4. **Ротация секретов**: регулярно обновляйте client_secret
5. **Мониторинг**: отслеживайте использование каждого клиента
6. **Audit logging**: включите аудит в Keycloak для отслеживания доступа

## Troubleshooting

### Проблема: Токен от одного клиента не работает для другого сервиса

**Решение**: Это ожидаемое поведение. Каждый сервис должен использовать свой клиент и получать токены для своего клиента.

### Проблема: "Invalid client credentials"

**Решение**: 
- Проверьте, что client_id и client_secret соответствуют клиенту в Keycloak
- Убедитесь, что используете правильный секрет для каждого сервиса

### Проблема: "Audience mismatch"

**Решение**: 
- Проверьте настройку audience в Keycloak и Kong
- Убедитесь, что audience в токене соответствует ожидаемому значению в Kong

## Примеры конфигураций

См. файл `kong/kong.yml` для полного примера конфигурации с множественными клиентами.
