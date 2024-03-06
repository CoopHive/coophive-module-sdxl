FROM laciferin/coophive-sdxl-base:ubuntu-latest as builder 
# is Dockerfile.base

FROM ubuntu:20.04 AS hf-builder

ARG HUGGINGFACE_TOKEN

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update -y && \
    apt install -y software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa -y && \
    apt update -y && \
    apt install -y python3.11-full python3-pip

WORKDIR /app
ENV HF_HOME=/app/.huggingface

RUN pip3 install huggingface_hub==0.16.4 
RUN huggingface-cli login --token $HUGGINGFACE_TOKEN 

COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /app/.venv /app/venv

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update -y && apt-get install -y git libgl1-mesa-glx libglib2.0-0 

RUN venv/bin/python3 -c 'from diffusers import DiffusionPipeline; import torch; DiffusionPipeline.from_pretrained("stabilityai/stable-diffusion-xl-base-0.9", torch_dtype=torch.float16, use_safetensors=True, variant="fp16")' 
RUN rm $HF_HOME/token

FROM nvidia/cuda:11.6.2-base-ubuntu20.04

RUN mkdir /app
WORKDIR /app
ENV HF_HOME=/app/.huggingface

RUN mkdir -p /inputs 
RUN mkdir -p /outputs


# Copy dependencies from the builder stage
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
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
