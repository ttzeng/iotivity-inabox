### Build the image from ubuntu 16.04 LTS
FROM ubuntu:16.04

### Allow to set-up HTTP(S) proxy using '--build-arg'
ARG http_proxy
ENV http_proxy ${http_proxy}
ARG https_proxy
ENV https_proxy ${https_proxy}
RUN echo 'http_proxy='$http_proxy'\nhttps_proxy='$https_proxy

### Clear local repository & install common tools
RUN apt-get clean \
 && apt-get update && apt-get install -y \
        curl            \
        git             \
        unzip           \
        vim             \
        wget

### Configuration settings & options
ENV WORKSPACE           /opt
ENV NOVNC_HOME          $WORKSPACE/noVNC
ENV IOTIVITY            $WORKSPACE/iotivity
ENV ANDROID_HOME        $WORKSPACE/android-sdk-linux
ENV NWJS                $WORKSPACE/nw.js
ENV MOUNT               $WORKSPACE/mnt
ENV HOME                /root
ENV TEMP                $HOME/tmp

ENV NODE_PATH           $WORKSPACE/node_modules
ENV IOTIVITY_NODE       $NODE_PATH/iotivity-node

### Setup VNC environment
WORKDIR $WORKSPACE
RUN : === noVNC requires netstat provided by net-tools \
 && apt-get update && apt-get install -y \
        geany           \
        icewm           \
        net-tools       \
        vnc4server      \
        xterm           \
 && git clone https://github.com/novnc/noVNC.git $NOVNC_HOME

### Install specific Node.js executable
ENV NODE_REVISION v9.1.0
RUN : === install xz-utils required for unpack the download file \
 && apt-get update && apt-get install -y xz-utils \
 && : === download from official Node.js downloads page and unpack \
 && wget https://nodejs.org/dist/$NODE_REVISION/node-$NODE_REVISION-linux-x64.tar.xz \
 && tar -C /usr/local --strip-components 1 -xf node-$NODE_REVISION-linux-x64.tar.xz \
 && : === clean up \
 && rm -f node-$NODE_REVISION-linux-x64.tar.xz
ENV NODE_REVISION ""

### Build iotivity-node
WORKDIR $IOTIVITY_NODE
RUN : === install build dependencies \
          https://wiki.iotivity.org/build_iotivity_with_ubuntu_build_machine \
 && apt-get update && apt-get install -y \
        build-essential git scons libtool autoconf valgrind doxygen wget unzip \
        libboost-dev libboost-program-options-dev libboost-thread-dev \
        uuid-dev libexpat1-dev libglib2.0-dev libsqlite3-dev libcurl4-gnutls-dev \
 && : === checkout the source \
 && git clone -b coaps https://github.com/otcshare/iotivity-node.git $IOTIVITY_NODE \
 && : === start building. --unsafe-perm required as npm fails to downgrade its privileges \
 && npm install --unsafe-perm \
 && : === clean up native artifacts \
 && rm -rf $IOTIVITY_NODE/iotivity-native
ENV PATH $PATH:$IOTIVITY_NODE/iotivity-installed/bin
ENV LD_LIBRARY_PATH $IOTIVITY_NODE/iotivity-installed/lib:$LD_LIBRARY_PATH

### Setup NW.js
WORKDIR $NWJS
ENV NM_REVISION v0.26.6
RUN : === download / untar the prebuilt executable \
 && wget https://dl.nwjs.io/$NM_REVISION/nwjs-$NM_REVISION-linux-x64.tar.gz \
 && tar --strip-components 1 -xf nwjs-$NM_REVISION-linux-x64.tar.gz \
 && : === install dependencies required by the executable \
 && apt-get update && apt-get install -y \
        libgtk-3-0  \
        libnss3     \
        libxss1     \
 && : === clean up \
 && rm -f nwjs-$NM_REVISION-linux-x64.tar.gz
ENV PATH $PATH:$NWJS
ENV NM_PREBUILD ""

### Install Android command line tools
WORKDIR $WORKSPACE
ENV ANDROID_SDK_TOOLS sdk-tools-linux-3859397.zip
RUN wget https://dl.google.com/android/repository/$ANDROID_SDK_TOOLS \
 && unzip $ANDROID_SDK_TOOLS -d $ANDROID_HOME \
 && rm -f $ANDROID_SDK_TOOLS
ENV ANDROID_SDK_TOOLS ""

### Install the required packages with Android SDK manager
WORKDIR $ANDROID_HOME
RUN : === Android aapt requires 32-bit libraries installed \
 && apt-get update && apt-get install -y \
        default-jdk     \
        lib32stdc++6    \
        lib32z1         \
 && tools/bin/sdkmanager --update \
 && yes | tools/bin/sdkmanager --licenses \
 && : === 'Android API 21' and 'Android SDK Build Tools 20.0.0' required by IoTivity Android \
 && tools/bin/sdkmanager \
        "platforms;android-21" \
        "build-tools;20.0.0"

### Create Android Virtual Device
ENV ANDROID_SYSIMG "system-images;android-21;default;x86_64"
RUN tools/bin/sdkmanager --update \
 && tools/bin/sdkmanager \
        "emulator" \
        $ANDROID_SYSIMG \
 && echo no | tools/bin/avdmanager create avd -n MyAVD -k $ANDROID_SYSIMG -f -d "Nexus 5"
ENV ANDROID_SYSIMG ""
ENV PATH $PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin

### Build native IoTivity
WORKDIR $IOTIVITY
RUN : === install build dependencies \
          https://wiki.iotivity.org/build_iotivity_with_ubuntu_build_machine \
 && apt-get update && apt-get install -y \
        build-essential git scons libtool autoconf valgrind doxygen wget unzip \
        libboost-dev libboost-program-options-dev libboost-thread-dev \
        uuid-dev libexpat1-dev libglib2.0-dev libsqlite3-dev libcurl4-gnutls-dev \
 && : === checkout the source \
 && git clone https://gerrit.iotivity.org/gerrit/p/iotivity.git $IOTIVITY \
 && git checkout 1.3.1 \
 && : === pull the tinycbor and mbedtls projects before building IoTivity \
 && git clone https://github.com/01org/tinycbor.git extlibs/tinycbor/tinycbor -b v0.4.1 \
 && git clone https://github.com/ARMmbed/mbedtls.git extlibs/mbedtls/mbedtls -b mbedtls-2.4.2 \
 && : === build targets \
 && scons TARGET_OS=android ANDROID_HOME=$ANDROID_HOME TARGET_ARCH=armeabi java \
 && scons TARGET_OS=android ANDROID_HOME=$ANDROID_HOME TARGET_ARCH=x86     java

### Install the library to local maven repository
RUN apt-get update && apt-get install -y maven \
 && mvn install:install-file \
        -Dfile=$IOTIVITY/java/iotivity-android/build/outputs/aar/iotivity-base-x86-release.aar \
        -DgroupId=org.iotivity \
        -DartifactId=base \
        -Dversion=1.3.1-secured \
        -Dpackaging=aar

### Build SmartHome companion app
WORKDIR $TEMP
ADD patches/SmartHome-Demo $TEMP/patches
RUN : === setup SmartHome-Demo repo \
 && git clone https://github.com/intel/SmartHome-Demo.git \
 && cd SmartHome-Demo \
 && git config user.email "docker@localhost" \
 && if [ -f $TEMP/patches/*.patch ]; then git am $TEMP/patches/*.patch; fi \
 && : === build the companion app \
 && cd smarthome-companion \
 && echo 'sdk.dir='$ANDROID_HOME > local.properties \
 && ./gradlew assembleDebug \
 && : === clean up only keep the deliverable \
 && cp app/build/outputs/apk/app-debug.apk $HOME/companion-debug.apk \
 && rm -rf $TEMP

### Listen ports [ VNC:5901, onVNC:6080 ]
EXPOSE 5901 6080

### Unset variables
ENV http_proxy ""
ENV https_proxy ""

### Mount points for holding external volumes
VOLUME $MOUNT
WORKDIR $MOUNT

ENTRYPOINT \
    : === clear artifacts if any \
 && rm -f /root/.vnc/*.pid /tmp/.X1-lock /tmp/.X11-unix/X1 \
 && USER=root vncserver :1 \
 && $NOVNC_HOME/utils/launch.sh --vnc localhost:5901
