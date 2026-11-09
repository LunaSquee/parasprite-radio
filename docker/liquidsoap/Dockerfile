# Official Liquidsoap 2.x image (Debian trixie based), with the extra
# tools the radio scripts in liq/scripts shell out to.
FROM savonet/liquidsoap:v2.4.6

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      nodejs \
      ffmpeg \
      mediainfo \
      file \
      xmp \
      opus-tools \
      flac \
      sox \
      festival \
      festvox-kallpc16k \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# The repo is bind-mounted at /app (see docker-compose.yml); scripts are
# resolved relative to the liq directory, just like bin/startliq does.
WORKDIR /app/liq

# compose runs this as the host uid, which has no home dir in the image
ENV HOME=/tmp

USER liquidsoap

ENTRYPOINT ["liquidsoap"]
CMD ["radio.liq"]
