FROM ubuntu:24.04

ARG WORKER_REPO=https://github.com/affinipay/terraform-worker
ARG WORKER_REF=release/ap/1.3.1

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    git \
    curl \
    unzip \
    ca-certificates \
    gnupg \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2 (verified checksum using official AWS procedure)
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && curl -o "awscliv2.sig" https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip.sig

COPY awscliv2.gpg awscliv2.gpg

RUN gpg --import awscliv2.gpg \
    && gpg --verify awscliv2.sig awscliv2.zip \
    && unzip awscliv2.zip \
    && ./aws/install -i /usr/local/aws-cli -b /usr/local/bin \
    && rm -rf awscliv2.zip awscliv2.sig awscliv2.gpg ./aws

# Clone and install terraform-worker
RUN git clone $WORKER_REPO /opt/terraform-worker \
    && cd /opt/terraform-worker \
    && git checkout $WORKER_REF \
    && python3 -m venv /opt/venv \
    && . /opt/venv/bin/activate \
    && pip3 install poetry \
    && poetry config virtualenvs.create false --local \
    && poetry install --no-root \
    && poetry build \
    && pip install dist/*.whl \
    && rm -rf /root/.cache /opt/terraform-worker/.venv

ENV PATH="/opt/venv/bin:$PATH"

ENTRYPOINT ["/bin/bash"]
