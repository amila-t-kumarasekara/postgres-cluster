generate-configs:
	npm install typescript ts-node dotenv
	npx ts-node-esm generate-configs.ts
	echo 'PostgreSQL configuration files generated!'

run-docker-compose:
	docker-compose up --build -d

stop-docker-compose:
	docker-compose down

restart-docker-compose:
	docker-compose down && docker-compose up --build -d

show-docker-compose-logs:
	docker-compose logs -f

show-docker-compose-logs-tail:
	docker-compose logs -f --tail 100
