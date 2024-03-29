FROM nvidia/cuda:11.6.2-base-ubuntu20.04

ARG HUGGINGFACE_TOKEN

RUN mkdir /app
WORKDIR /app


RUN mkdir -p /inputs 
RUN mkdir -p /outputs



# Install lora and pre-cache stable diffusion xl 0.9 model to avoid re-downloading
# it for every inference.
ADD requirements.txt /app/requirements.txt

ENV PIP_TIMEOUT=1000

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update -y && apt-get install -y python3 python3-pip git libgl1-mesa-glx libglib2.0-0 && \
    pip3 install -r requirements.txt && \
    pip3 install huggingface_hub==0.16.4 && \
    huggingface-cli login --token $HUGGINGFACE_TOKEN && \
    python3 -c 'from diffusers import DiffusionPipeline; import torch; DiffusionPipeline.from_pretrained("stabilityai/stable-diffusion-xl-base-0.9", torch_dtype=torch.float16, use_safetensors=True, variant="fp16")' && \
    rm /root/.cache/huggingface/token

# TODO: cache:
# pipe.unet = torch.compile(pipe.unet, mode="reduce-overhead", fullgraph=True)

ENV HF_DATASETS_OFFLINE=1 
ENV TRANSFORMERS_OFFLINE=1 
ENV OUTPUT_DIR="/outputs/"
ENV RANDOM_SEED=40

ADD inference.py /app/inference.py
ENTRYPOINT ["python3", "/app/inference.py"]
