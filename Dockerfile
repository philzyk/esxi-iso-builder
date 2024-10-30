# syntax=docker/dockerfile:1

FROM ubuntu:20.04 AS base
LABEL Maintainer = "Jeremy Combs <jmcombs@me.com>"

ENV DEBIAN_FRONTEND=noninteractive \
    LANGUAGE=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# Dockerfile ARG variables for architecture
ARG TARGETARCH
ARG USERNAME=coder
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Combine RUN commands to reduce layers and improve caching
RUN apt-get update && \
    apt-get -y install --no-install-recommends software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get -y install --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        gcc \
        locales \
        mkisofs \
        xorriso \
        python3.7 \
        python3.7-dev \
        python3.7-distutils \
        sudo \
        whois \
        less \
        libc6 \
        libgcc1 \
        libgssapi-krb5-2 \
        libicu66 \
        libssl1.1 \
        libstdc++6 \
        p7zip-full \
        unzip \
        zlib1g
    # Configure locale
RUN localedef -c -i en_US -f UTF-8 en_US.UTF-8 && \
    locale-gen en_US.UTF-8 && \
    dpkg-reconfigure locales
    # Set up non-root user
RUN groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID --shell /usr/bin/pwsh --create-home $USERNAME && \
    echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME
    # Clean up
RUN apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /home/$USERNAME

# Architecture-specific builds
FROM base AS linux-amd64
ARG DOTNET_ARCH=x64
ARG PS_ARCH=x64

FROM base AS linux-arm64
ARG DOTNET_ARCH=arm64
ARG PS_ARCH=arm64

FROM base AS linux-arm
ARG DOTNET_ARCH=arm
ARG PS_ARCH=arm32

FROM linux-${TARGETARCH} AS msft-install

# Install .NET Core Runtime
ARG DOTNET_VERSION=3.1.32
ARG DOTNET_PACKAGE=dotnet-runtime-${DOTNET_VERSION}-linux-${DOTNET_ARCH}.tar.gz
ARG DOTNET_PACKAGE_URL=https://dotnetcli.azureedge.net/dotnet/Runtime/${DOTNET_VERSION}/${DOTNET_PACKAGE}
ENV DOTNET_ROOT=/opt/microsoft/dotnet/${DOTNET_VERSION} \
    PATH=$PATH:/opt/microsoft/dotnet/${DOTNET_VERSION}:/opt/microsoft/dotnet/${DOTNET_VERSION}/tools

RUN mkdir -p ${DOTNET_ROOT} && \
    curl -L ${DOTNET_PACKAGE_URL} | tar xz -C ${DOTNET_ROOT}

# Install PowerShell Core
RUN PS_MAJOR_VERSION=$(curl -Ls -o /dev/null -w %{url_effective} https://aka.ms/powershell-release\?tag\=lts | cut -d 'v' -f 2 | cut -d '.' -f 1) && \
    PS_INSTALL_FOLDER=/opt/microsoft/powershell/${PS_MAJOR_VERSION} && \
    PS_PACKAGE_URL=$(curl -Ls -o /dev/null -w %{url_effective} https://aka.ms/powershell-release\?tag\=lts | \
        sed 's#https://github.com#https://api.github.com/repos#g; s#tag/#tags/#' | \
        xargs curl -s | grep browser_download_url | grep linux-${PS_ARCH}.tar.gz | cut -d '"' -f 4) && \
    mkdir -p ${PS_INSTALL_FOLDER} && \
    curl -L ${PS_PACKAGE_URL} | tar xz -C ${PS_INSTALL_FOLDER} && \
    chmod a+x,o-w ${PS_INSTALL_FOLDER}/pwsh && \
    ln -s ${PS_INSTALL_FOLDER}/pwsh /usr/bin/pwsh && \
    echo /usr/bin/pwsh >> /etc/shells

# Architecture-specific PowerCLI installation
FROM msft-install AS vmware-install-arm64
RUN apt-get update && \
    apt-get -y install p7zip-full curl
ARG POWERCLIURL=https://vdc-download.vmware.com/vmwb-repository/dcr-public/02830330-d306-4111-9360-be16afb1d284/c7b98bc2-fcce-44f0-8700-efed2b6275aa/VMware-PowerCLI-13.0.0-20829139.zip
RUN mkdir -p /usr/local/share/powershell/Modules
RUN curl -L ${POWERCLIURL} -o /tmp/vmware-powercli.zip
RUN file /tmp/vmware-powercli.zip
RUN 7z e /tmp/vmware-powercli.zip -0 /usr/local/share/powershell/Modules
RUN ls -lah /usr/local/share/powershell/Modules
RUN rm /tmp/vmware-powercli.zip

FROM msft-install AS vmware-install-amd64
RUN pwsh -Command "Install-Module -Name VMware.PowerCLI -Scope AllUsers -Repository PSGallery -Force -Verbose"

FROM vmware-install-${TARGETARCH} AS vmware-install-common

# Switch to non-root user and setup Python
USER $USERNAME
ENV PATH=${PATH}:/home/$USERNAME/.local/bin

RUN curl -L https://bootstrap.pypa.io/pip/3.7/get-pip.py | python3.7 && \
    python3.7 -m pip install six psutil lxml pyopenssl
RUN pwsh -Command "Install-Module -Name VMware.PowerCLI -Scope CurrentUser -Repository PSGallery -Force" && \
    pwsh -Command "Import-Module VMware.PowerCLI" && \
    pwsh -Command "Set-PowerCLIConfiguration -InvalidCertificateAction Fail" && \
    pwsh -Command "Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP \$false -Confirm:\$false" && \
    pwsh -Command "Set-PowerCLIConfiguration -PythonPath /usr/bin/python3.7 -Scope User -Confirm:\$false"

ENV DEBIAN_FRONTEND=dialog
ENTRYPOINT ["pwsh"]
