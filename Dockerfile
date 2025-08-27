FROM jetty:12-jdk21-amazoncorretto AS base

ARG idp_version=5.1.6
ARG idp_hash=6c195cfa88df0cdfb2fa8ef0f788ae977c4e14b8ac8f4e679aa74e5b6f844810
ARG idp_oidc_config_version=2.2.0
ARG idp_oidcext_version=4.2.1
ARG idp_oidc_common_version=3.2.0
ARG slf4j_version=2.0.17
ARG slf4j_hash=7b751d952061954d5abfed7181c1f645d336091b679891591d63329c622eb832
ARG logback_version=1.5.17
ARG logback_classic_hash=e7bd342d91e50a15f1e16f80a526ce7dffc418daf73cd2094db4f802c0204880
ARG logback_core_hash=2fbd5f0272b1a3546e5740a588e735e071acd0cd0226e048f711946a30eac337
ARG logback_access_hash=e791ccfcfee9c0d299d07474d9bfcbfcbebf1181323be601220c8a823062ab99


## IDP env values
ENV IDP_SRC=/opt/shibboleth-identity-provider-$idp_version \
    IDP_HOME=/opt/shibboleth-idp


# Switch to root during installations and configurations
USER root
RUN yum install -y curl gnupg

# JETTY Configure
RUN mkdir -p $JETTY_BASE/modules $JETTY_BASE/lib/ext $JETTY_BASE/lib/logging $JETTY_BASE/resources \
    && java -jar $JETTY_HOME/start.jar \
    --create-startd \
    --add-modules=http2c,rewrite,forwarded,logging-logback \
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
