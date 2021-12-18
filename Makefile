build:
	docker build --tag klio .

build-full:
	docker build --tag klio --no-cache .

run:
	docker container stop klio-dev || /usr/bin/true
	docker run --rm --detach --name=klio-dev --hostname klio -p 8000:8000 -v /root/.WolframEngine/Licensing/mathpass:/home/klio/.WolframEngine/Licensing/mathpass klio
