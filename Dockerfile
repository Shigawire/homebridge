ARG DEBIAN_FRONTEND=noninteractive
ARG SNX_VERSION=2.9.0

FROM balenalib/armv7hf-ubuntu:jammy as base
ARG DEBIAN_FRONTEND
ARG SNX_VERSION

ENV DEBIAN_FRONTEND=$DEBIAN_FRONTEND
ENV SNX_VERSION=$SNX_VERSION

FROM base as snx-rs-build
#ENV SNX_VERSION=$SNX_VERSION
#ENV DEBIAN_FRONTEND=$DEBIAN_FRONTEND

RUN apt update && apt install -y curl unzip build-essential pkg-config libssl-dev # libgtk-3-dev libsoup-3.0-dev # libwebkit2gtk-4.1-dev libjavascriptcoregtk-4.1-dev
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

#RUN echo $SNX_VERSION && exit 1

RUN curl -L https://github.com/ancwrd1/snx-rs/archive/refs/tags/v$SNX_VERSION.zip -o /tmp/snx-rs.zip && \
    unzip /tmp/snx-rs.zip -d /tmp

ENV PATH="/root/.cargo/bin:${PATH}"

RUN cd /tmp/snx-rs-$SNX_VERSION && \
    cargo build --release --workspace --exclude snx-rs-gui

FROM base
COPY --from=snx-rs-build /tmp/snx-rs-$SNX_VERSION/target/release/snx-rs /usr/local/bin/snx-rs

RUN apt update && apt install -y iproute2 redis-tools jq
RUN curl -fsSL https://tailscale.com/install.sh | sh

RUN echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf && \
    echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf && \
    sudo sysctl -p /etc/sysctl.d/99-tailscale.conf

ADD Gemfile .

RUN apt install -y ruby \
    && gem install bundler \
    && bundle install

ADD vpn_controller.rb /usr/local/bin/vpn_controller.rb
ADD vpn_client.sh /usr/local/bin/vpn_client.sh
