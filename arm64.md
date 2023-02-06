# Test arm64

Test to build on arm64.

```
diff --git a/Dockerfiles/suricata.Dockerfile b/Dockerfiles/suricata.Dockerfile
index 7a2723ca..600e5a83 100644
--- a/Dockerfiles/suricata.Dockerfile
+++ b/Dockerfiles/suricata.Dockerfile
@@ -28,13 +28,13 @@ ENV PGROUP "suricata"
 ENV PUSER_PRIV_DROP false
 
 ENV SUPERCRONIC_VERSION "0.2.1"
-ENV SUPERCRONIC_URL "https://github.com/aptible/supercronic/releases/download/v$SUPERCRONIC_VERSION/supercronic-linux-amd64"
-ENV SUPERCRONIC "supercronic-linux-amd64"
-ENV SUPERCRONIC_SHA1SUM "d7f4c0886eb85249ad05ed592902fa6865bb9d70"
+ENV SUPERCRONIC_URL "https://github.com/aptible/supercronic/releases/download/v$SUPERCRONIC_VERSION/supercronic-linux-arm64"
+ENV SUPERCRONIC "supercronic-linux-arm64"
+ENV SUPERCRONIC_SHA1SUM "0003a1f84a4bc547b6ff3d88347916e4b96a2177"
 ENV SUPERCRONIC_CRONTAB "/etc/crontab"
 
 ENV YQ_VERSION "4.24.2"
-ENV YQ_URL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64"
+ENV YQ_URL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_arm64"
 
 ENV SURICATA_CONFIG_DIR /etc/suricata
 ENV SURICATA_CONFIG_FILE "$SURICATA_CONFIG_DIR"/suricata.yaml
@@ -72,7 +72,6 @@ RUN sed -i "s/bullseye main/bullseye main contrib non-free/g" /etc/apt/sources.l
         libgeoip1 \
         libhiredis0.14 \
         libhtp2 \
-        libhyperscan5 \
         libjansson4 \
         liblua5.1-0 \
         libluajit-5.1-2 \
```


```
diff --git a/Dockerfiles/zeek.Dockerfile b/Dockerfiles/zeek.Dockerfile
index 69291e3b..432b0f57 100644
--- a/Dockerfiles/zeek.Dockerfile
+++ b/Dockerfiles/zeek.Dockerfile
@@ -1,4 +1,4 @@
-FROM debian:11-slim
+FROM ubuntu:22.04
 
 # Copyright (c) 2023 Battelle Energy Alliance, LLC.  All rights reserved.
 
@@ -37,9 +37,9 @@ ENV ZEEK_LTS $ZEEK_LTS
 ENV ZEEK_VERSION $ZEEK_VERSION
 
 ENV SUPERCRONIC_VERSION "0.2.1"
-ENV SUPERCRONIC_URL "https://github.com/aptible/supercronic/releases/download/v$SUPERCRONIC_VERSION/supercronic-linux-amd64"
-ENV SUPERCRONIC "supercronic-linux-amd64"
-ENV SUPERCRONIC_SHA1SUM "d7f4c0886eb85249ad05ed592902fa6865bb9d70"
+ENV SUPERCRONIC_URL "https://github.com/aptible/supercronic/releases/download/v$SUPERCRONIC_VERSION/supercronic-linux-arm64"
+ENV SUPERCRONIC "supercronic-linux-arm64"
+ENV SUPERCRONIC_SHA1SUM "0003a1f84a4bc547b6ff3d88347916e4b96a2177"
 ENV SUPERCRONIC_CRONTAB "/etc/crontab"
 
 # for build
@@ -112,16 +112,16 @@ RUN export DEBARCH=$(dpkg --print-architecture) && \
       cd /tmp/zeek-packages && \
       if [ -n "${ZEEK_LTS}" ]; then ZEEK_LTS="-lts"; fi && export ZEEK_LTS && \
       curl -sSL --remote-name-all \
-        "https://download.opensuse.org/repositories/security:/zeek/Debian_11/amd64/libbroker${ZEEK_LTS}-dev_${ZEEK_VERSION}_amd64.deb" \
-        "https://download.opensuse.org/repositories/security:/zeek/Debian_11/amd64/zeek${ZEEK_LTS}-core-dev_${ZEEK_VERSION}_amd64.deb" \
-        "https://download.opensuse.org/repositories/security:/zeek/Debian_11/amd64/zeek${ZEEK_LTS}-core_${ZEEK_VERSION}_amd64.deb" \
-        "https://download.opensuse.org/repositories/security:/zeek/Debian_11/amd64/zeek${ZEEK_LTS}-spicy-dev_${ZEEK_VERSION}_amd64.deb" \
-        "https://download.opensuse.org/repositories/security:/zeek/Debian_11/amd64/zeek${ZEEK_LTS}_${ZEEK_VERSION}_amd64.deb" \
-        "https://download.opensuse.org/repositories/security:/zeek/Debian_11/amd64/zeekctl${ZEEK_LTS}_${ZEEK_VERSION}_amd64.deb" \
-        "https://download.opensuse.org/repositories/security:/zeek/Debian_11/all/zeek${ZEEK_LTS}-client_${ZEEK_VERSION}_all.deb" \
-        "https://download.opensuse.org/repositories/security:/zeek/Debian_11/all/zeek${ZEEK_LTS}-zkg_${ZEEK_VERSION}_all.deb" \
-        "https://download.opensuse.org/repositories/security:/zeek/Debian_11/all/zeek${ZEEK_LTS}-btest_${ZEEK_VERSION}_all.deb" \
-        "https://download.opensuse.org/repositories/security:/zeek/Debian_11/all/zeek${ZEEK_LTS}-btest-data_${ZEEK_VERSION}_all.deb" && \
+        "https://download.opensuse.org/repositories/security:/zeek/xUbuntu_22.04/arm64/libbroker${ZEEK_LTS}-dev_${ZEEK_VERSION}_arm64.deb" \
+        "https://download.opensuse.org/repositories/security:/zeek/xUbuntu_22.04/arm64/zeek${ZEEK_LTS}-core-dev_${ZEEK_VERSION}_arm64.deb" \
+        "https://download.opensuse.org/repositories/security:/zeek/xUbuntu_22.04/arm64/zeek${ZEEK_LTS}-core_${ZEEK_VERSION}_arm64.deb" \
+        "https://download.opensuse.org/repositories/security:/zeek/xUbuntu_22.04/arm64/zeek${ZEEK_LTS}-spicy-dev_${ZEEK_VERSION}_arm64.deb" \
+        "https://download.opensuse.org/repositories/security:/zeek/xUbuntu_22.04/arm64/zeek${ZEEK_LTS}_${ZEEK_VERSION}_arm64.deb" \
+        "https://download.opensuse.org/repositories/security:/zeek/xUbuntu_22.04/arm64/zeekctl${ZEEK_LTS}_${ZEEK_VERSION}_arm64.deb" \
+        "https://download.opensuse.org/repositories/security:/zeek/xUbuntu_22.04/all/zeek${ZEEK_LTS}-client_${ZEEK_VERSION}_all.deb" \
+        "https://download.opensuse.org/repositories/security:/zeek/xUbuntu_22.04/all/zeek${ZEEK_LTS}-zkg_${ZEEK_VERSION}_all.deb" \
+        "https://download.opensuse.org/repositories/security:/zeek/xUbuntu_22.04/all/zeek${ZEEK_LTS}-btest_${ZEEK_VERSION}_all.deb" \
+        "https://download.opensuse.org/repositories/security:/zeek/xUbuntu_22.04/all/zeek${ZEEK_LTS}-btest-data_${ZEEK_VERSION}_all.deb" && \
       dpkg -i ./*.deb && \
     curl -fsSLO "$SUPERCRONIC_URL" && \
       echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - && \
```
