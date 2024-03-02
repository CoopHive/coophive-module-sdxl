FROM python:3.10-slim AS hf-builder

ARG HUGGINGFACE_TOKEN

WORKDIR /app

RUN pip3 install huggingface_hub==0.16.4 
RUN huggingface-cli login --token $HUGGINGFACE_TOKEN 
RUN python3 -c 'from diffusers import DiffusionPipeline; import torch; DiffusionPipeline.from_pretrained("stabilityai/stable-diffusion-xl-base-0.9", torch_dtype=torch.float16, use_safetensors=True, variant="fp16")' 
RUN rm ~/.cache/huggingface/token

FROM python:3.10 AS builder

WORKDIR /app

ENV PIP_TIMEOUT=1000

# Install Poetry
RUN pip install poetry

ENV POETRY_VIRTUALENVS_IN_PROJECT=true
ENV POETRY_VIRTUALENVS_OPTIONS_ALWAYS_COPY=true
ENV POETRY_VIRTUALENVS_OPTIONS_NO_PIP=false
ENV POETRY_VIRTUALENVS_OPTIONS_NO_SETUPTOOLS=true
# ENV POETRY_VIRTUALENVS_PATH={cache-dir}/virtualenvs not required since virtual env is set in

# Copy only the dependency-related files
COPY pyproject.toml poetry.lock ./

# Install project dependencies using Poetry
RUN poetry install --no-root

FROM nvidia/cuda:11.6.2

RUN mkdir /app
WORKDIR /app

RUN mkdir -p /inputs 
RUN mkdir -p /outputs

# Copy dependencies from the builder stage
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=builder /app/.venv /app/venv

# Activate the virtual environment
RUN . venv/bin/activate

# Install lora and pre-cache stable diffusion xl 0.9 model to avoid re-downloading
# it for every inference.

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update -y && apt-get install -y python3.10 python3-pip git libgl1-mesa-glx libglib2.0-0 

# TODO: cache:
# pipe.unet = torch.compile(pipe.unet, mode="reduce-overhead", fullgraph=True)

ENV HF_DATASETS_OFFLINE=1 
ENV TRANSFORMERS_OFFLINE=1 
ENV OUTPUT_DIR="/outputs/"
ENV RANDOM_SEED=40

ADD inference.py /app/inference.py
ENTRYPOINT ["python3.10", "/app/inference.py"]
