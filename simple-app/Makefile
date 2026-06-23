.PHONY: help install test run docker-build docker-run docker-compose-up docker-compose-down clean shellcheck

APP_DIR = app
DOCKER_IMAGE = simple-app

help:
	@echo "Доступные команды:"
	@echo "  make install          - Установить зависимости (локально)"
	@echo "  make test             - Запустить тесты"
	@echo "  make run              - Запустить приложение локально"
	@echo "  make docker-build     - Собрать Docker образ"
	@echo "  make docker-run       - Запустить Docker контейнер"
	@echo "  make docker-compose-up   - Запустить через docker-compose"
	@echo "  make docker-compose-down - Остановить docker-compose"
	@echo "  make clean            - Очистить временные файлы"
	@echo "  make shellcheck       - Проверить Bash-скрипт"

install:
	cd $(APP_DIR) && pip install -r requirements.txt

test:
	cd $(APP_DIR) && pytest tests/test_app.py -v

run:
	cd $(APP_DIR) && python main.py

docker-build:
	docker build -t $(DOCKER_IMAGE):latest .

docker-run:
	docker run -p 5000:5000 $(DOCKER_IMAGE):latest

docker-compose-up:
	docker-compose up -d

docker-compose-down:
	docker-compose down

docker-compose-logs:
	docker-compose logs -f app

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	rm -rf .pytest_cache
	rm -rf htmlcov
	rm -rf .coverage

shellcheck:
	shellcheck scripts/server-info.sh

all: install test shellcheck docker-build
