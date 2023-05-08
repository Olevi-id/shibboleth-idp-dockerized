FROM jetty:10-jdk17-amazoncorretto as base

ARG idp_version=4.3.0
ARG idp_hash=ef0b01af99c1364c2b6f88b06a697ed335a56e47528f9aa9dff123a7453325fa
ARG idp_oidcext_version=3.3.0
ARG idp_oidc_common_version=2.1.0
ARG slf4j_version=1.7.29
ARG slf4j_hash=47b624903c712f9118330ad2fb91d0780f7f666c3f22919d0fc14522c5cad9ea
ARG logback_version=1.2.9
ARG logback_classic_hash=ad745cc243805800d1ebbf5b7deba03b37c95885e6bce71335a73f7d6d0f14ee
ARG logback_core_hash=4a9ef7ed809b1fbc6992bf87d404087c247e7a9766e25bb84377b58ed5c9eb58
ARG logback_access_hash=4db03561790664b823181cf8db78260c675464741372459ecba4fadf6d5538d2


## IDP env values
ENV IDP_SRC=/opt/shibboleth-identity-provider-$idp_version \
    IDP_SCOPE=example.org \
    IDP_PUBLIC_URL=https://idp.example.org/idp/shibboleth \
    IDP_HOME=/opt/shibboleth-idp \
    IDP_HOST_NAME=idp.example.org \
    IDP_KEYSTORE_PASSWORD=idpkstorepwd \
    IDP_SEALER_PASSWORD=idpsealerpwd

# Switch to root during installations and configurations
USER root
RUN yum install -y curl gnupg

# JETTY Configure
RUN mkdir -p $JETTY_BASE/modules $JETTY_BASE/lib/ext $JETTY_BASE/lib/logging $JETTY_BASE/resources \
    && java -jar $JETTY_HOME/start.jar --create-startd \
    --add-modules=http2c,annotations,rewrite,http-forwarded \
    --approve-all-licenses

# Shibboleth IdP - Download, verify hash and install
RUN curl -sO https://shibboleth.net/downloads/identity-provider/$idp_version/shibboleth-identity-provider-$idp_version.tar.gz \
    && echo "$idp_hash shibboleth-identity-provider-$idp_version.tar.gz" | sha256sum -c - \
    && gzip -d shibboleth-identity-provider-$idp_version.tar.gz \
    && tar -xvf shibboleth-identity-provider-$idp_version.tar -C /opt \
    && $IDP_SRC/bin/install.sh \
    -Didp.scope=$IDP_SCOPE \
    -Didp.target.dir=$IDP_HOME \
    -Didp.src.dir=$IDP_SRC \
    -Didp.scope=$IDP_SCOPE \
    -Didp.host.name=$IDP_HOST_NAME \
    -Didp.noprompt=true \
    -Didp.sealer.password=$IDP_SEALER_PASSWORD \
    -Didp.keystore.password=$IDP_KEYSTORE_PASSWORD \
    -Didp.entityID=$IDP_PUBLIC_URL \
    && rm shibboleth-identity-provider-$idp_version.tar \
    && rm -rf /opt/shibboleth-identity-provider-$idp_version

# slf4j - Download, verify and install
RUN curl -sO https://repo1.maven.org/maven2/org/slf4j/slf4j-api/$slf4j_version/slf4j-api-$slf4j_version.jar \
    && echo "$slf4j_hash  slf4j-api-$slf4j_version.jar" | sha256sum -c - \
    && mv slf4j-api-$slf4j_version.jar $JETTY_BASE/lib/logging/

# logback_classic - Download verify and install
RUN curl -sO https://repo1.maven.org/maven2/ch/qos/logback/logback-classic/$logback_version/logback-classic-$logback_version.jar \
    && echo "$logback_classic_hash  logback-classic-$logback_version.jar" | sha256sum -c - \
    && mv logback-classic-$logback_version.jar $JETTY_BASE/lib/logging/

# logback-core - Download, verify and install
RUN curl -sO https://repo1.maven.org/maven2/ch/qos/logback/logback-core/$logback_version/logback-core-$logback_version.jar \
    && echo "$logback_core_hash  logback-core-$logback_version.jar" | sha256sum -c - \
    && mv logback-core-$logback_version.jar $JETTY_BASE/lib/logging/

# logback-access - Download, verify and install
RUN curl -sO https://repo1.maven.org/maven2/ch/qos/logback/logback-access/$logback_version/logback-access-$logback_version.jar \
    && echo "$logback_access_hash  logback-access-$logback_version.jar" | sha256sum -c - \
    && mv logback-access-$logback_version.jar $JETTY_BASE/lib/logging/

# Install plugins
# See: https://stackoverflow.com/questions/34212230/using-bouncycastle-with-gnupg-2-1s-pubring-kbx-file
RUN curl -s https://shibboleth.net/downloads/PGP_KEYS | gpg --import && \ 
    ${IDP_HOME}/bin/plugin.sh -i https://shibboleth.net/downloads/identity-provider/plugins/oidc-common/$idp_oidc_common_version/oidc-common-dist-$idp_oidc_common_version.tar.gz --truststore /root/.gnupg/pubring.gpg --noPrompt && \
    ${IDP_HOME}/bin/plugin.sh -i https://shibboleth.net/downloads/identity-provider/plugins/oidc-op/$idp_oidcext_version/idp-plugin-oidc-op-distribution-$idp_oidcext_version.tar.gz --truststore /root/.gnupg/pubring.gpg --noPrompt && \
    ${IDP_HOME}/bin/plugin.sh -I net.shibboleth.idp.plugin.nashorn --truststore /root/.gnupg/pubring.gpg --noPrompt

EXPOSE 8080
EXPOSE 8443

COPY jetty-base/ $JETTY_BASE/

#establish a healthcheck command so that docker might know the container's true state
HEALTHCHECK --interval=1m --timeout=30s \
    CMD curl -k -f http://127.0.0.1:8080/idp/status || exit 1

CMD \
"$IDP_HOME"/bin/build.sh -Didp.target.dir="$IDP_HOME" && \
"$JAVA_HOME"/bin/java -jar "$JETTY_HOME"/start.jar \
    jetty.home="$JETTY_HOME" jetty.base="$JETTY_BASE"
