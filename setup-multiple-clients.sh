#!/bin/bash

# Скрипт для автоматического создания множественных клиентов в Keycloak
# Использование: ./setup-multiple-clients.sh

set -e

KEYCLOAK_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASSWORD="admin"
REALM_NAME="myrealm"

# Массив клиентов для создания
declare -a CLIENTS=(
    "user-service-client:User Service:/api/users"
    "order-service-client:Order Service:/api/orders"
    "payment-service-client:Payment Service:/api/payments"
    "admin-service-client:Admin Service:/api/admin"
)

echo "Ожидание готовности Keycloak..."
until curl -s -f "${KEYCLOAK_URL}/health/ready" > /dev/null; do
    echo "Ожидание Keycloak..."
    sleep 5
done

echo "Получение access token администратора..."
ADMIN_TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASSWORD}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
    echo "Ошибка: Не удалось получить токен администратора"
    exit 1
fi

echo ""
echo "Создание клиентов для realm: ${REALM_NAME}"
echo "=========================================="

# Файл для сохранения секретов
SECRETS_FILE="keycloak-clients-secrets.txt"
echo "# Keycloak Client Secrets для ${REALM_NAME}" > "$SECRETS_FILE"
echo "# Создано: $(date)" >> "$SECRETS_FILE"
echo "" >> "$SECRETS_FILE"

for CLIENT_INFO in "${CLIENTS[@]}"; do
    IFS=':' read -r CLIENT_ID CLIENT_NAME API_PATH <<< "$CLIENT_INFO"
    
    echo ""
    echo "Создание клиента: ${CLIENT_ID} (${CLIENT_NAME})"
    
    # Проверка существования клиента
    CLIENT_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
      -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=${CLIENT_ID}" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}")
    
    if [ "$CLIENT_EXISTS" = "200" ]; then
        echo "  Клиент ${CLIENT_ID} уже существует, получаем его ID..."
        CLIENT_UUID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=${CLIENT_ID}" \
          -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')
    else
        # Создание клиента
        echo "  Создание нового клиента..."
        curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients" \
          -H "Authorization: Bearer ${ADMIN_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "{
            \"clientId\": \"${CLIENT_ID}\",
            \"name\": \"${CLIENT_NAME}\",
            \"enabled\": true,
            \"clientAuthenticatorType\": \"client-secret\",
            \"standardFlowEnabled\": true,
            \"directAccessGrantsEnabled\": true,
            \"serviceAccountsEnabled\": true,
            \"publicClient\": false,
            \"redirectUris\": [
              \"https://api.example.com${API_PATH}/*\",
              \"http://localhost:8000${API_PATH}/*\"
            ],
            \"webOrigins\": [
              \"https://api.example.com\",
              \"http://localhost:8000\"
            ],
            \"protocol\": \"openid-connect\"
          }" > /dev/null
        
        sleep 2
        
        # Получение UUID созданного клиента
        CLIENT_UUID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=${CLIENT_ID}" \
          -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')
        
        echo "  ✓ Клиент создан с UUID: ${CLIENT_UUID}"
    fi
    
    # Получение или генерация client secret
    echo "  Получение client secret..."
    CLIENT_SECRET=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${CLIENT_UUID}/client-secret" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.value')
    
    if [ -z "$CLIENT_SECRET" ] || [ "$CLIENT_SECRET" = "null" ]; then
        echo "  Генерация нового client secret..."
        curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${CLIENT_UUID}/client-secret" \
          -H "Authorization: Bearer ${ADMIN_TOKEN}" > /dev/null
        sleep 1
        CLIENT_SECRET=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${CLIENT_UUID}/client-secret" \
          -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.value')
    fi
    
    echo "  ✓ Client Secret получен"
    
    # Сохранение секрета в файл
    echo "${CLIENT_ID}=${CLIENT_SECRET}" >> "$SECRETS_FILE"
    
    # Настройка audience mapper (опционально)
    echo "  Настройка audience mapper..."
    AUDIENCE_MAPPER_EXISTS=$(curl -s -X GET \
      "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${CLIENT_UUID}/protocol-mappers/models" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r ".[] | select(.name==\"audience-mapper\") | .id")
    
    if [ -z "$AUDIENCE_MAPPER_EXISTS" ]; then
        curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${CLIENT_UUID}/protocol-mappers/models" \
          -H "Authorization: Bearer ${ADMIN_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "{
            \"name\": \"audience-mapper\",
            \"protocol\": \"openid-connect\",
            \"protocolMapper\": \"oidc-audience-mapper\",
            \"config\": {
              \"included.client.audience\": \"${CLIENT_ID}\",
              \"id.token.claim\": \"true\",
              \"access.token.claim\": \"true\"
            }
          }" > /dev/null
        echo "  ✓ Audience mapper настроен"
    else
        echo "  Audience mapper уже существует"
    fi
done

echo ""
echo "=========================================="
echo "Настройка завершена!"
echo "=========================================="
echo ""
echo "Секреты клиентов сохранены в файл: ${SECRETS_FILE}"
echo ""
echo "Обновите kong/kong.yml с этими значениями:"
cat "$SECRETS_FILE"
echo ""
echo "=========================================="
