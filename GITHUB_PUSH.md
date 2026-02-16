# Как запушить проект на GitHub

## Шаг 1: Создайте репозиторий на GitHub

1. Откройте https://github.com/new
2. Введите имя репозитория (например: `api-gateway-nginx-kong-keycloak`)
3. **Не** добавляйте README, .gitignore или лицензию (они уже есть в проекте)
4. Нажмите **Create repository**
5. Скопируйте URL репозитория (например: `https://github.com/ВАШ_USERNAME/api-gateway-nginx-kong-keycloak.git`)

## Шаг 2: Выполните команды в терминале

Откройте **PowerShell** или **cmd** в папке проекта и выполните по порядку:

```powershell
# Перейти в папку проекта
cd "c:\Users\IngoBank\OneDrive\Рабочий стол\cursor"

# Инициализировать git (если ещё не инициализирован)
git init

# Добавить удалённый репозиторий (замените URL на свой!)
git remote add origin https://github.com/ВАШ_USERNAME/ИМЯ_РЕПОЗИТОРИЯ.git

# Добавить все файлы
git add .

# Проверить, что добавлено (не должно быть .env, ssl/*.key и т.д. — они в .gitignore)
git status

# Первый коммит
git commit -m "Initial commit: Nginx + Kong + Keycloak API Gateway with mTLS"

# Переименовать ветку в main (если нужно)
git branch -M main

# Запушить на GitHub (потребуется авторизация)
git push -u origin main
```

## Шаг 3: Авторизация на GitHub

При `git push` вас могут попросить:

- **GitHub CLI** — если установлен, войдите: `gh auth login`
- **Логин и пароль** — для HTTPS используйте **Personal Access Token** вместо пароля:
  1. GitHub → Settings → Developer settings → Personal access tokens
  2. Generate new token (classic), права: `repo`
  3. Подставьте токен вместо пароля при запросе
- **SSH** — если настроен ключ, замените remote на SSH URL:
  ```powershell
  git remote set-url origin git@github.com:ВАШ_USERNAME/ИМЯ_РЕПОЗИТОРИЯ.git
  git push -u origin main
  ```

## Быстрая шпаргалка (после создания репо на GitHub)

```powershell
cd "c:\Users\IngoBank\OneDrive\Рабочий стол\cursor"
git init
git remote add origin https://github.com/ВАШ_USERNAME/ИМЯ_РЕПОЗИТОРИЯ.git
git add .
git commit -m "Initial commit: API Gateway Nginx + Kong + Keycloak mTLS"
git branch -M main
git push -u origin main
```

**Важно:** замените `ВАШ_USERNAME` и `ИМЯ_РЕПОЗИТОРИЯ` на свои данные.

## Что не попадёт в репозиторий (благодаря .gitignore)

- Папка `ssl/` с ключами и секретами
- Файл `.env` с паролями
- Логи в `nginx/logs/`
- Файл `keycloak-clients-secrets.txt`

Таким образом секреты не окажутся на GitHub.
