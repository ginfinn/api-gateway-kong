# API Gateway с mTLS: Nginx + Kong + Keycloak

## Архитектура

```
Client (с клиентским сертификатом)
    ↓ [mTLS]
Nginx (443) - терминация mTLS, проверка клиентского сертификата
    ↓ [HTTP]
Kong (8000) - API Gateway, маршрутизация, плагины
    ↓ [HTTP]
Keycloak (8080) - аутентификация/авторизация через OIDC/OAuth2
    ↓ [HTTP]
Backend Services
```

## Компоненты

1. **Nginx** - терминация SSL/TLS, mTLS (mutual TLS), балансировка нагрузки
2. **Kong** - API Gateway с плагинами для интеграции с Keycloak
3. **Keycloak** - Identity and Access Management (IAM)

## Настройка mTLS

### 1. Генерация сертификатов

#### Создание CA (Certificate Authority)
```bash
# Создать директорию для сертификатов
mkdir -p ssl

# Генерация приватного ключа CA
openssl genrsa -out ssl/ca.key 4096

# Создание самоподписанного сертификата CA
openssl req -new -x509 -days 3650 -key ssl/ca.key -out ssl/ca.crt \
  -subj "/CN=MyCA/O=MyOrg/C=RU"
```

#### Создание серверного сертификата
```bash
# Генерация приватного ключа сервера
openssl genrsa -out ssl/server.key 4096

# Создание CSR (Certificate Signing Request)
openssl req -new -key ssl/server.key -out ssl/server.csr \
  -subj "/CN=api.example.com/O=MyOrg/C=RU"

# Подписание сертификата CA
openssl x509 -req -days 365 -in ssl/server.csr -CA ssl/ca.crt \
  -CAkey ssl/ca.key -CAcreateserial -out ssl/server.crt

# Создание цепочки сертификатов для клиентов
cat ssl/ca.crt > ssl/ca-chain.crt
```

#### Создание клиентского сертификата
```bash
# Генерация приватного ключа клиента
openssl genrsa -out ssl/client.key 4096

# Создание CSR клиента
openssl req -new -key ssl/client.key -out ssl/client.csr \
  -subj "/CN=client1/O=MyOrg/C=RU"

# Подписание клиентского сертификата CA
openssl x509 -req -days 365 -in ssl/client.csr -CA ssl/ca.crt \
  -CAkey ssl/ca.key -CAcreateserial -out ssl/client.crt

# Создание PKCS#12 файла для клиента (для браузера/приложений)
openssl pkcs12 -export -out ssl/client.p12 -inkey ssl/client.key \
  -in ssl/client.crt -certfile ssl/ca.crt -passout pass:password
```

### 2. Структура директории ssl/

```
ssl/
├── ca.key              # Приватный ключ CA (хранить в секрете!)
├── ca.crt              # Сертификат CA (публичный)
├── ca-chain.crt        # Цепочка CA для проверки клиентов
├── server.key          # Приватный ключ сервера
├── server.crt          # Сертификат сервера
├── server.csr          # CSR сервера
├── client.key          # Приватный ключ клиента
├── client.crt          # Сертификат клиента
├── client.csr          # CSR клиента
└── client.p12          # PKCS#12 файл для клиента
```

## Запуск

### 1. Подготовка сертификатов
```bash
# Создайте сертификаты согласно инструкциям выше
# Убедитесь, что файлы находятся в директории ssl/
```

### 2. Инициализация Kong
```bash
# Запуск только базы данных
docker-compose up -d kong-database

# Ожидание готовности БД
sleep 10

# Миграция схемы Kong
docker run --rm \
  --network cursor_api-gateway-network \
  -e KONG_DATABASE=postgres \
  -e KONG_PG_HOST=kong-database \
  -e KONG_PG_USER=kong \
  -e KONG_PG_PASSWORD=kongpassword \
  kong:3.4 kong migrations bootstrap
```

### 3. Запуск всех сервисов
```bash
docker-compose up -d
```

### 4. Проверка статуса
```bash
docker-compose ps
docker-compose logs -f nginx
```

## Тестирование mTLS

### С curl
```bash
# Запрос с клиентским сертификатом
curl -v --cert ssl/client.crt --key ssl/client.key \
  --cacert ssl/ca.crt https://api.example.com/

# Запрос без клиентского сертификата (должен вернуть ошибку)
curl -v --cacert ssl/ca.crt https://api.example.com/
# Ожидаемая ошибка: SSL peer certificate or SSH remote key was not OK
```

### С OpenSSL
```bash
# Тест подключения с mTLS
openssl s_client -connect localhost:443 \
  -cert ssl/client.crt \
  -key ssl/client.key \
  -CAfile ssl/ca.crt
```

## Настройка Kong для работы с Keycloak

### Создание сервиса в Kong
```bash
# Через Admin API Kong
curl -X POST http://localhost:8001/services \
  --data "name=backend-service" \
  --data "url=http://backend:8080"

# Создание роута
curl -X POST http://localhost:8001/services/backend-service/routes \
  --data "paths[]=/api" \
  --data "strip_path=false"
```

### Установка OIDC плагина для Keycloak
```bash
# Установка плагина через Admin API
curl -X POST http://localhost:8001/routes/{route-id}/plugins \
  --data "name=oidc" \
  --data "config.issuer=http://keycloak:8080/realms/myrealm" \
  --data "config.client_id=myclient" \
  --data "config.client_secret=mysecret" \
  --data "config.discovery=http://keycloak:8080/realms/myrealm/.well-known/openid-configuration"
```

## Безопасность

### Рекомендации:

1. **Хранение ключей CA**: Приватный ключ CA (`ca.key`) должен храниться в безопасном месте, не в репозитории
2. **Ротация сертификатов**: Регулярно обновляйте сертификаты
3. **Ограничение доступа**: Используйте файловые права доступа для защиты приватных ключей
   ```bash
   chmod 600 ssl/*.key
   chmod 644 ssl/*.crt
   ```
4. **Валидация CN**: В production добавьте проверку CN клиентского сертификата
5. **CRL/OCSP**: Настройте Certificate Revocation List или OCSP для отзыва сертификатов

## Мониторинг

### Логи Nginx
```bash
# Просмотр логов mTLS подключений
docker-compose logs -f nginx | grep ssl_client
```

### Метрики
- Nginx: доступны через `/health` endpoint
- Kong: метрики через Admin API `/metrics`
- Keycloak: health check через `/health/ready`

## Troubleshooting

### Проблема: "SSL peer certificate or SSH remote key was not OK"
- Проверьте, что клиентский сертификат подписан тем же CA, что указан в `ssl_client_certificate`
- Убедитесь, что `ssl_verify_depth` достаточен для вашей цепочки сертификатов

### Проблема: "No required SSL certificate was sent"
- Убедитесь, что клиент отправляет сертификат
- Проверьте, что `ssl_verify_client on` установлен в конфигурации

### Проблема: "certificate verify failed"
- Проверьте срок действия сертификатов
- Убедитесь, что CA сертификат корректен
