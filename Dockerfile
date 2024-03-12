FROM jetty:11-jdk17-amazoncorretto AS base

ARG idp_version=5.0.0
ARG idp_hash=7e782a0e82d01d724b4889700d4db603b17d9a912b21f7c0fcedf18527f9efff
ARG idp_oidc_config_version=2.0.0
ARG idp_oidcext_version=4.0.0
ARG idp_oidc_common_version=3.0.1
ARG slf4j_version=2.0.7
ARG slf4j_hash=5d6298b93a1905c32cda6478808ac14c2d4a47e91535e53c41f7feeb85d946f4
ARG logback_version=1.5.3
ARG logback_classic_hash=b5fe96fd5655f94b1bca881db5ce1643d08b9dbdcd8b6fe361e32e4578d5613b
ARG logback_core_hash=7854507a59ad5c58228dc4bc3dab3d79225397f5ef2430edb3ace54445e0111f
ARG logback_access_hash=e791ccfcfee9c0d299d07474d9bfcbfcbebf1181323be601220c8a823062ab99


## IDP env values
ENV IDP_SRC=/opt/shibboleth-identity-provider-$idp_version \
    IDP_HOME=/opt/shibboleth-idp


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
    && tar -xvf "shibboleth-identity-provider-${idp_version}.tar" -C /opt
COPY idp-install.properties /tmp/
RUN $IDP_SRC/bin/install.sh --propertyFile /tmp/idp-install.properties
RUN rm shibboleth-identity-provider-$idp_version.tar \
    && rm -rf /opt/shibboleth-identity-provider-$idp_version

# slf4j - Download, verify and install
RUN curl -sO https://repo1.maven.org/maven2/org/slf4j/slf4j-api/${slf4j_version}/slf4j-api-${slf4j_version}.jar \
    && echo "$slf4j_hash  slf4j-api-${slf4j_version}.jar" | sha256sum -c - \
    && mv "slf4j-api-${slf4j_version}.jar" "${JETTY_BASE}/lib/logging/"

# logback_classic - Download verify and install
RUN curl -sO https://repo1.maven.org/maven2/ch/qos/logback/logback-classic/$logback_version/logback-classic-$logback_version.jar \
    && echo "$logback_classic_hash  logback-classic-$logback_version.jar" | sha256sum -c - \
    && mv logback-classic-${logback_version}.jar $JETTY_BASE/lib/logging/

# logback-core - Download, verify and install
RUN curl -sO https://repo1.maven.org/maven2/ch/qos/logback/logback-core/$logback_version/logback-core-$logback_version.jar \
    && echo "$logback_core_hash  logback-core-$logback_version.jar" | sha256sum -c - \
    && mv "logback-core-${logback_version}.jar" $JETTY_BASE/lib/logging/

# logback-access - Download, verify and install
RUN curl -sO https://repo1.maven.org/maven2/ch/qos/logback/logback-access/$logback_version/logback-access-$logback_version.jar \
    && echo "$logback_access_hash  logback-access-$logback_version.jar" | sha256sum -c - \
    && mv logback-access-$logback_version.jar ${JETTY_BASE}/lib/logging/

# Install plugins
# See: https://stackoverflow.com/questions/34212230/using-bouncycastle-with-gnupg-2-1s-pubring-kbx-file
RUN curl -s https://shibboleth.net/downloads/PGP_KEYS | gpg --import && \ 
    ${IDP_HOME}/bin/plugin.sh -i https://shibboleth.net/downloads/identity-provider/plugins/oidc-common/$idp_oidc_common_version/oidc-common-dist-$idp_oidc_common_version.tar.gz --truststore /root/.gnupg/pubring.gpg --noPrompt && \
    ${IDP_HOME}/bin/plugin.sh -i https://shibboleth.net/downloads/identity-provider/plugins/oidc-config/$idp_oidc_config_version/idp-plugin-oidc-config-dist-$idp_oidc_config_version.tar.gz --truststore /root/.gnupg/pubring.gpg --noPrompt && \
    ${IDP_HOME}/bin/plugin.sh -i https://shibboleth.net/downloads/identity-provider/plugins/oidc-op/$idp_oidcext_version/idp-plugin-oidc-op-distribution-$idp_oidcext_version.tar.gz --truststore /root/.gnupg/pubring.gpg --noPrompt && \
    ${IDP_HOME}/bin/plugin.sh -I net.shibboleth.idp.plugin.nashorn --truststore /root/.gnupg/pubring.gpg --noPrompt

EXPOSE 8080

COPY jetty-base/ $JETTY_BASE/

#establish a healthcheck command so that docker might know the container's true state
HEALTHCHECK --interval=1m --timeout=30s \
    CMD curl -k -f http://127.0.0.1:8080/idp/status || exit 1

CMD \
"$IDP_HOME"/bin/build.sh -Didp.target.dir="$IDP_HOME" && \
"$JAVA_HOME"/bin/java -jar "$JETTY_HOME"/start.jar \
    jetty.home="$JETTY_HOME" jetty.base="$JETTY_BASE"
