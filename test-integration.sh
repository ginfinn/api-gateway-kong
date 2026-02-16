#!/bin/bash

# Скрипт для тестирования интеграции Keycloak + Kong
# Использование: ./test-integration.sh

set -e

KEYCLOAK_URL="http://localhost:8080"
REALM_NAME="myrealm"
CLIENT_ID="kong-client"
CLIENT_SECRET="${CLIENT_SECRET:-your-client-secret-here}"
USERNAME="${USERNAME:-testuser}"
PASSWORD="${PASSWORD:-testpassword}"
KONG_URL="http://localhost:8000"
API_ENDPOINT="${API_ENDPOINT:-/api/test}"

echo "=========================================="
echo "Тестирование интеграции Keycloak + Kong"
echo "=========================================="
echo ""

# Проверка доступности Keycloak
echo "1. Проверка доступности Keycloak..."
if curl -s -f "${KEYCLOAK_URL}/health/ready" > /dev/null; then
    echo "   ✓ Keycloak доступен"
else
    echo "   ✗ Keycloak недоступен"
    exit 1
fi

# Проверка OIDC discovery endpoint
echo "2. Проверка OIDC discovery endpoint..."
DISCOVERY_URL="${KEYCLOAK_URL}/realms/${REALM_NAME}/.well-known/openid-configuration"
if curl -s -f "${DISCOVERY_URL}" > /dev/null; then
    echo "   ✓ OIDC discovery endpoint доступен"
    echo "   URL: ${DISCOVERY_URL}"
else
    echo "   ✗ OIDC discovery endpoint недоступен"
    exit 1
fi

# Получение токена доступа
echo "3. Получение access token..."
TOKEN_RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "username=${USERNAME}" \
  -d "password=${PASSWORD}" \
  -d "grant_type=password")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "   ✗ Не удалось получить токен"
    echo "   Ответ: $TOKEN_RESPONSE"
    exit 1
fi

echo "   ✓ Токен получен успешно"
echo "   Токен (первые 50 символов): ${ACCESS_TOKEN:0:50}..."

# Проверка запроса без токена (должна быть ошибка)
echo "4. Тестирование запроса без токена..."
NO_TOKEN_RESPONSE=$(curl -s -w "\n%{http_code}" "${KONG_URL}${API_ENDPOINT}")
HTTP_CODE=$(echo "$NO_TOKEN_RESPONSE" | tail -n1)
if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "   ✓ Запрос без токена отклонен (код: ${HTTP_CODE})"
else
    echo "   ⚠ Неожиданный код ответа: ${HTTP_CODE}"
fi

# Проверка запроса с токеном
echo "5. Тестирование запроса с токеном..."
WITH_TOKEN_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "${KONG_URL}${API_ENDPOINT}")
HTTP_CODE=$(echo "$WITH_TOKEN_RESPONSE" | tail -n1)
BODY=$(echo "$WITH_TOKEN_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "404" ]; then
    echo "   ✓ Запрос с токеном обработан (код: ${HTTP_CODE})"
    if [ "$HTTP_CODE" = "404" ]; then
        echo "   ⚠ Backend сервис не найден (это нормально, если сервис не настроен)"
    fi
else
    echo "   ✗ Ошибка при запросе с токеном (код: ${HTTP_CODE})"
    echo "   Ответ: $BODY"
fi

# Проверка introspection endpoint
echo "6. Тестирование introspection endpoint..."
INTROSPECTION_RESPONSE=$(curl -s -X POST \
  "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/token/introspect" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "token=${ACCESS_TOKEN}")

ACTIVE=$(echo "$INTROSPECTION_RESPONSE" | jq -r '.active')
if [ "$ACTIVE" = "true" ]; then
    echo "   ✓ Токен валиден (introspection)"
    USERNAME_FROM_TOKEN=$(echo "$INTROSPECTION_RESPONSE" | jq -r '.username // .preferred_username')
    echo "   Пользователь: ${USERNAME_FROM_TOKEN}"
else
    echo "   ✗ Токен невалиден"
fi

echo ""
echo "=========================================="
echo "Тестирование завершено"
echo "=========================================="
