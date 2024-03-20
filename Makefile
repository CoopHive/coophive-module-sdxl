include .env
export 
dc:
	docker-compose up

gh:
	alias docker='sudo docker $@'
	git pull && make dc

d:
	docker build -t app --build-arg HUGGINGFACE_TOKEN=${HUGGINGFACE_TOKEN} . 

docker:
	docker buildx build -t sdxl:${tag} --build-arg HUGGINGFACE_TOKEN=${HUGGINGFACE_TOKEN} .

docker-p:
	docker buildx build --platform linux/amd64 -t sdxl:${tag} --build-arg HUGGINGFACE_TOKEN=${HUGGINGFACE_TOKEN} .


dockerv1:
		docker buildx build -f Dockerfile.v1 -t sdxl:${tag} --build-arg HUGGINGFACE_TOKEN=${HUGGINGFACE_TOKEN} .

tag:
	docker tag sdxl:${tag} laciferin/sdxl:${tag}
	docker push laciferin/sdxl:${tag}

all:
	# docker build is enough for the amd64 arch
	docker build -t sdxl:${tag} --build-arg HUGGINGFACE_TOKEN=${HUGGINGFACE_TOKEN} . 
	make tag

rebrandDocker:
	docker build -f Dockerfile.rebrand -t sdxl:${tag} . 
	make tag


jobFile="./module.json"
outDir="./output"
b: 
	bacalhau create --wait  --download --wait-timeout-secs 600 --output-dir ${outDir} ${jobFile}

.PHONY: docker gh dc tag b dockerv1 tag