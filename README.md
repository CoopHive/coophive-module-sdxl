# SDXL v0.9 in Docker 🐋

```
export HUGGINGFACE_TOKEN=<my huggingface token>
```

```
docker build -t sdxl:v0.9 --build-arg HUGGINGFACE_TOKEN=$HUGGINGFACE_TOKEN .
```

```
mkdir -p outputs
```

```
docker run -ti --gpus all \
    -v $PWD/outputs:/outputs \
    -e OUTPUT_DIR=/outputs/ \
    -e PROMPT="an astronaut riding an orange horse" \
    sdxl:v0.9
```

Will overwrite `outputs/image0.png` each time.

### Coophive Module

```
hive run sdxl:v0.2.10 -i PromptEnv="PROMPT=hiro saves the hive" -i SeedEnv="RANDOM_SEED=42"
```
