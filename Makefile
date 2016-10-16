install: build rm create

build:
	docker build -t taiga .

run: create start

create:
	docker create --name taiga --env-file taiga_env -p 3001:80 -v /mnt/taiga:/usr/src/taiga-back/media taiga

start:
	docker start taiga

stop:
	docker stop taiga

reload:
	docker kill -s HUP taiga

restart: stop start

rm:
	docker rm -f -v taiga

ps:
	docker ps

logs:
	docker logs taiga

shell:
	docker exec -t -i -u root taiga /bin/bash
