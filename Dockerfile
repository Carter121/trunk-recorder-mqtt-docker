###############################################################################
# Stage 1 – compile trunk-recorder                                            #
###############################################################################
FROM ubuntu:24.04 AS builder

RUN apt-get update && apt-get -y upgrade && \
    apt-get install --no-install-recommends -y \
    # ── toolchain ────────────────────────────────────────────────────────────
        build-essential cmake git curl pkg-config wget \
    # ── SDR headers/libs for trunk-recorder + Soapy build ───────────────────
        ffmpeg gnuradio-dev gr-osmosdr libosmosdr-dev \
        libairspy-dev libairspyhf-dev libbladerf-dev libfreesrp-dev \
        libhackrf-dev libmirisdr-dev libuhd-dev libxtrx-dev librtlsdr-dev \
    # ── generic libs ────────────────────────────────────────────────────────
        libboost-all-dev libcurl4-openssl-dev libgmp-dev liborc-0.4-dev \
        libpaho-mqtt-dev libpaho-mqttpp-dev libpthread-stubs0-dev libsndfile1-dev \
        libssl-dev python3-six openssh-client ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
# ───────────────────────── trunk-recorder (core) ─────────────────────────────
RUN git clone --depth 1 https://github.com/TrunkRecorder/trunk-recorder.git && \
    mkdir -p trunk-recorder/build

# MQTT plugin
RUN git -C trunk-recorder/user_plugins \
       clone --depth 1 https://github.com/TrunkRecorder/tr-plugin-mqtt.git

WORKDIR /src/trunk-recorder/build
RUN cmake .. \
 && make -j"$(nproc)" \
 && make DESTDIR=/newroot install      # staged for the final image

###############################################################################
# Stage 2 – lightweight runtime image                                         #
###############################################################################
FROM ubuntu:24.04

RUN apt-get update && apt-get -y upgrade && \
    apt-get install --no-install-recommends -y \
    # ── trunk-recorder runtime deps ──────────────────────────────────────────
        ca-certificates curl wget sox fdkaac docker.io \
        libboost-chrono1.83.0t64 libboost-log1.83.0 \
        libgnuradio-analog3.10.9t64 libgnuradio-digital3.10.9t64 \
        libgnuradio-filter3.10.9t64 libgnuradio-network3.10.9t64 \
        libgnuradio-osmosdr0.2.0t64 libgnuradio-uhd3.10.9t64 \
        libpaho-mqtt-dev libpaho-mqttpp-dev \
        libairspyhf1 libfreesrp0 librtlsdr2 libxtrx0 \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/share/{doc,man,info} /usr/local/share/{doc,man,info}

# copy everything we staged in builder (/newroot/*) into the final FS
COPY --from=builder /newroot /

# ── tame GNURadio log level ─────────────────────────────────────────────────
RUN mkdir -p /etc/gnuradio/conf.d && \
    echo 'log_level = info' > /etc/gnuradio/conf.d/gnuradio-runtime.conf && \
    ldconfig

WORKDIR /app
ENV HOME=/tmp

ENTRYPOINT ["trunk-recorder", "--config=/app/config.json"]
