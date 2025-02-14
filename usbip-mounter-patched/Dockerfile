ARG BUILD_FROM=ghcr.io/hassio-addons/base:17.1.5
# hadolint ignore=DL3006
FROM ${BUILD_FROM} AS build-stage
ARG BUILD_ARCH=amd64

RUN apk add alpine-sdk \
  abuild-rootbld

COPY usbip_build /

RUN mkdir -p /etc/apk/keys && cp /irakhlin.rsa.pub /etc/apk/keys/ \
  && mkdir -p /root/.abuild && mv /irakhlin.rsa /root/.abuild/irakhlin.rsa \
  && cp /irakhlin.rsa.pub /root/.abuild/irakhlin.rsa.pub \
  && mv /abuild.conf /root/.abuild/abuild.conf

WORKDIR /build

RUN abuild -rfFkK


ARG BUILD_FROM=ghcr.io/hassio-addons/base:17.1.5
# hadolint ignore=DL3006
FROM ${BUILD_FROM} AS final

# Setup base
ARG BUILD_ARCH=amd64

COPY --from=build-stage /root/packages/x86_64/linux-tools-usbip-6.13.2-r0.apk /tmp/linux-tools-usbip-6.13.2-r0.apk

# hadolint ignore=DL3003,DL3042
RUN apk add --no-cache \
    kmod \
#    linux-tools-usbip \
    hwdata-usb \
    device-mapper-libs \
    grep
    
RUN apk add --no-cache --allow-untrusted /tmp/linux-tools-usbip-6.13.2-r0.apk

# Copy root filesystem
COPY rootfs /

# Build arguments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="Ilya Rakhlin <i.rakhlin@gmail.com>" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.vendor="Home Assistant Community Add-ons" \
    org.opencontainers.image.authors="Ilya Rakhlin <i.rakhlin@gmail.com>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.url="https://addons.community" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.documentation="https://github.com/${BUILD_REPOSITORY}/blob/main/README.md" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}
