# Syntax version
syntax = docker/dockerfile:1

# Base image
FROM ubuntu:20.04 AS base
LABEL maintainer="Jeremy Combs <jmcombs@me.com>"

# Set environment to non-interactive for apt install
ENV DEBIAN_FRONTEND=noninteractive

# Dockerfile ARG variables for installation
ARG TARGETARCH
ARG USERNAME=coder
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG DOTNET_VERSION=3.1.32
ARG VMWARECEIP=false

# Set Locale environment variables
ENV LANGUAGE=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PATH=/opt/microsoft/dotnet/${DOTNET_VERSION}:/opt/microsoft/dotnet/${DOTNET_VERSION}/tools:/home/$USERNAME/.local/bin:$PATH \
    DOTNET_ROOT=/opt/microsoft/dotnet/${DOTNET_VERSION}

# Configure apt and install base packages
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
        p7zip-full \
        unzip \
        libc6 \
        libgcc1 \
        libgssapi-krb5-2 \
        libicu66 \
        libssl1.1 \
        libstdc++6 \
        zlib1g && \
    # Set Locale
    localedef -c -i en_US -f UTF-8 en_US.UTF-8 && \
    locale-gen en_US.UTF-8 && \
    dpkg-reconfigure locales && \
    # Set up non-root User and sudo privileges
    groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID --shell /usr/bin/pwsh --create-home $USERNAME && \
    echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME && \
    # Clean up
    apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /home/$USERNAME

# Architecture-specific stages
FROM base AS linux-amd64
ARG DOTNET_ARCH=x64
ARG PS_ARCH=x64

FROM base AS linux-arm64
ARG DOTNET_ARCH=arm64
ARG PS_ARCH=arm64

FROM base AS linux-arm
ARG DOTNET_ARCH=arm
ARG PS_ARCH=arm

# Microsoft installations
FROM linux-${TARGETARCH} AS msft-install
ARG DOTNET_VERSION
ARG DOTNET_ARCH
ARG PS_ARCH

# Install .NET Core
RUN DOTNET_PACKAGE=dotnet-runtime-${DOTNET_VERSION}-linux-${DOTNET_ARCH}.tar.gz && \
    DOTNET_PACKAGE_URL=https://dotnetcli.azureedge.net/dotnet/Runtime/${DOTNET_VERSION}/${DOTNET_PACKAGE} && \
    curl -L ${DOTNET_PACKAGE_URL} -o /tmp/dotnet.tar.gz && \
    mkdir -p ${DOTNET_ROOT} && \
    tar zxf /tmp/dotnet.tar.gz -C ${DOTNET_ROOT} && \
    rm /tmp/dotnet.tar.gz

# Install PowerShell Core
RUN PS_MAJOR_VERSION=$(curl -Ls -o /dev/null -w %{url_effective} https://aka.ms/powershell-release?tag=lts | cut -d 'v' -f 2 | cut -d '.' -f 1) && \
    PS_INSTALL_FOLDER=/opt/microsoft/powershell/${PS_MAJOR_VERSION} && \
    PS_PACKAGE_URL=$(curl -Ls -o /dev/null -w %{url_effective} https://aka.ms/powershell-release?tag=lts | \
        sed 's#https://github.com#https://api.github.com/repos#g; s#tag/#tags/#' | \
        xargs curl -s | grep browser_download_url | grep linux-${PS_ARCH}.tar.gz | cut -d '"' -f 4) && \
    curl -L ${PS_PACKAGE_URL} -o powershell.tar.gz && \
    mkdir -p ${PS_INSTALL_FOLDER} && \
    tar zxf powershell.tar.gz -C ${PS_INSTALL_FOLDER} && \
    chmod a+x,o-w ${PS_INSTALL_FOLDER}/pwsh && \
    ln -s ${PS_INSTALL_FOLDER}/pwsh /usr/bin/pwsh && \
    rm powershell.tar.gz && \
    echo /usr/bin/pwsh >> /etc/shells

# VMware PowerCLI installation stages
FROM msft-install AS vmware-install-arm64
# For ARM64, we'll use PowerShell Gallery with a specific version
RUN pwsh -Command "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted" && \
    pwsh -Command "Install-Module -Name VMware.PowerCLI -RequiredVersion 13.0.0.20829139 -Scope AllUsers -Repository PSGallery -Force"

FROM msft-install AS vmware-install-amd64
RUN pwsh -Command "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted" && \
    pwsh -Command "Install-Module -Name VMware.PowerCLI -Scope AllUsers -Repository PSGallery -Force"

# Final stage
FROM vmware-install-${TARGETARCH}

USER $USERNAME

# Install Python dependencies for VMware PowerCLI
ADD --chown=${USER_UID}:${USER_GID} https://bootstrap.pypa.io/pip/3.7/get-pip.py /tmp/get-pip.py
RUN python3.7 /tmp/get-pip.py && \
    python3.7 -m pip install six psutil lxml pyopenssl && \
    rm /tmp/get-pip.py && \
    # Configure PowerCLI
    pwsh -Command "if ('${VMWARECEIP}' -eq 'true') { Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP \$true -Confirm:\$false } else { Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP \$false -Confirm:\$false }" && \
    pwsh -Command "Set-PowerCLIConfiguration -PythonPath /usr/bin/python3.7 -Scope User -Confirm:\$false"

ENV DEBIAN_FRONTEND=dialog

ENTRYPOINT ["pwsh"]
