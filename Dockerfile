FROM python:3.10 AS builder

USER root

WORKDIR /app

ENV PIP_TIMEOUT=1000000

# Install Poetry
RUN pip install poetry

ENV PYTHONHTTPSVERIFY=0

ENV POETRY_VIRTUALENVS_IN_PROJECT=true
ENV POETRY_VIRTUALENVS_OPTIONS_ALWAYS_COPY=true
ENV POETRY_VIRTUALENVS_OPTIONS_NO_PIP=false
ENV POETRY_VIRTUALENVS_OPTIONS_NO_SETUPTOOLS=true
# ENV POETRY_VIRTUALENVS_PATH={cache-dir}/virtualenvs not required since virtual env is set in

# Copy only the dependency-related files
COPY pyproject.toml poetry.lock ./

# RUN sysctl -w net.ipv6.conf.all.disable_ipv6=1
# RUN sysctl -w net.ipv6.conf.default.disable_ipv6=1

RUN echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf && \
    echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf

RUN python3 -m pip install --upgrade pip

RUN poetry config installer.max-workers $(grep -c ^processor /proc/cpuinfo)

# Install project dependencies using Poetry
RUN poetry install --no-root

FROM python:3.10-slim AS hf-builder

ARG HUGGINGFACE_TOKEN

WORKDIR /app
ENV HF_HOME=/app/.huggingface

COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=builder /app/.venv /app/venv

RUN pip3 install huggingface_hub==0.16.4 
RUN huggingface-cli login --token $HUGGINGFACE_TOKEN 
RUN venv/bin/python3 -c 'from diffusers import DiffusionPipeline; import torch; DiffusionPipeline.from_pretrained("stabilityai/stable-diffusion-xl-base-0.9", torch_dtype=torch.float16, use_safetensors=True, variant="fp16")' 
RUN rm $HF_HOME/token

FROM nvidia/cuda:11.6.2-base-ubuntu20.04

RUN mkdir /app
WORKDIR /app
ENV HF_HOME=/app/.huggingface

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
    apt-get update -y && apt-get install -y git libgl1-mesa-glx libglib2.0-0 

# TODO: cache:
# pipe.unet = torch.compile(pipe.unet, mode="reduce-overhead", fullgraph=True)

ENV HF_DATASETS_OFFLINE=1 
ENV TRANSFORMERS_OFFLINE=1 
ENV OUTPUT_DIR="/outputs/"
ENV RANDOM_SEED=40

COPY --from=hf-builder /app/.huggingface $HF_HOME

ADD inference.py /app/inference.py
ENTRYPOINT ["venv/bin/python3", "/app/inference.py"]
