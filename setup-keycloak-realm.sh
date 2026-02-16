#!/bin/bash

# Скрипт для автоматической настройки Keycloak Realm и Client через REST API
# Использование: ./setup-keycloak-realm.sh

set -e

KEYCLOAK_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASSWORD="admin"
REALM_NAME="myrealm"
CLIENT_ID="kong-client"
CLIENT_SECRET=""

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

echo "Создание realm: ${REALM_NAME}..."
# Проверка существования realm
REALM_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

if [ "$REALM_EXISTS" = "200" ]; then
    echo "Realm ${REALM_NAME} уже существует, пропускаем создание"
else
    curl -s -X POST "${KEYCLOAK_URL}/admin/realms" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{
        \"realm\": \"${REALM_NAME}\",
        \"enabled\": true,
        \"displayName\": \"My Realm\",
        \"sslRequired\": \"external\"
      }"
    echo "Realm ${REALM_NAME} создан"
fi

echo "Создание client: ${CLIENT_ID}..."
# Проверка существования client
CLIENT_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=${CLIENT_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

if [ "$CLIENT_EXISTS" = "200" ]; then
    echo "Client ${CLIENT_ID} уже существует, получаем его ID..."
    CLIENT_UUID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=${CLIENT_ID}" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')
else
    # Создание client
    CLIENT_RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{
        \"clientId\": \"${CLIENT_ID}\",
        \"enabled\": true,
        \"clientAuthenticatorType\": \"client-secret\",
        \"standardFlowEnabled\": true,
        \"directAccessGrantsEnabled\": true,
        \"serviceAccountsEnabled\": true,
        \"publicClient\": false,
        \"redirectUris\": [\"https://api.example.com/*\", \"http://localhost:8000/*\"],
        \"webOrigins\": [\"https://api.example.com\", \"http://localhost:8000\"],
        \"protocol\": \"openid-connect\"
      }")
    
    # Получение UUID созданного client
    sleep 2
    CLIENT_UUID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=${CLIENT_ID}" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')
    echo "Client ${CLIENT_ID} создан с UUID: ${CLIENT_UUID}"
fi

echo "Получение client secret..."
CLIENT_SECRET=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${CLIENT_UUID}/client-secret" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.value')

if [ -z "$CLIENT_SECRET" ] || [ "$CLIENT_SECRET" = "null" ]; then
    echo "Генерация нового client secret..."
    curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${CLIENT_UUID}/client-secret" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}"
    sleep 1
    CLIENT_SECRET=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${CLIENT_UUID}/client-secret" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.value')
fi

echo ""
echo "=========================================="
echo "Настройка завершена!"
echo "=========================================="
echo "Realm: ${REALM_NAME}"
echo "Client ID: ${CLIENT_ID}"
echo "Client Secret: ${CLIENT_SECRET}"
echo ""
echo "Обновите kong/kong.yml с этими значениями:"
echo "  client_id: ${CLIENT_ID}"
echo "  client_secret: ${CLIENT_SECRET}"
echo "=========================================="
