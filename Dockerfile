# Base image
FROM ubuntu:20.04 AS base
LABEL Original-Maintainer="Jeremy Combs <jmcombs@me.com>"
LABEL Forked-Maintainer="Filipp Zykov <philzy@vibox.pro>"

# Set non-interactive mode for container build
ENV DEBIAN_FRONTEND=noninteractive

# Dockerfile ARG variables for architecture
ARG TARGETARCH

# Configure apt and install required packages
RUN apt-get update && \
    apt-get -y install --no-install-recommends software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get -y install --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        git \
        gcc \
        locales \
        mkisofs \
        xorriso \
        python3.7 \
        python3.7-dev \
        python3.7-distutils \
        sudo \
        whois \
        p7zip-full \
        mc \
        less \
        libc6 \
        libgcc1 \
        libgssapi-krb5-2 \
        libicu66 \
        libssl1.1 \
        libstdc++6 \
        zlib1g

# Configure en_US.UTF-8 Locale
ENV LANGUAGE=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN localedef -c -i en_US -f UTF-8 en_US.UTF-8 && \
    locale-gen en_US.UTF-8 && \
    dpkg-reconfigure locales

# Define non-root user
ARG USERNAME=devops
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Set up non-root user with sudo privileges
RUN groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID --shell /usr/bin/pwsh --create-home $USERNAME && \
    echo "$USERNAME ALL=(root) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME
WORKDIR /home/$USERNAME

# Installing Powershell on both amd64 and arm64 architectures specific
FROM base AS linux-amd64
ARG DOTNET_ARCH=x64
ARG PS_ARCH=x64

FROM base AS linux-arm64
ARG DOTNET_ARCH=arm64
ARG PS_ARCH=arm64

FROM linux-${TARGETARCH} AS msft-install

# Microsoft .NET Core 3.1 Runtime for VMware PowerCLI
ARG DOTNET_VERSION=3.1.32
ARG DOTNET_PACKAGE=dotnet-runtime-${DOTNET_VERSION}-linux-${DOTNET_ARCH}.tar.gz
ARG DOTNET_PACKAGE_URL=https://dotnetcli.azureedge.net/dotnet/Runtime/${DOTNET_VERSION}/${DOTNET_PACKAGE}
ENV DOTNET_ROOT=/opt/microsoft/dotnet/${DOTNET_VERSION}
ENV PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools
ADD ${DOTNET_PACKAGE_URL} /tmp/${DOTNET_PACKAGE}
RUN mkdir -p ${DOTNET_ROOT} \
    && tar zxf /tmp/${DOTNET_PACKAGE} -C ${DOTNET_ROOT} \
    && rm /tmp/${DOTNET_PACKAGE}

# PowerShell Core 7.2 (LTS) - forcing to install exact version
ENV PS_MAJOR_VERSION=7.2.0
RUN echo "PowerShell Major Version: ${PS_MAJOR_VERSION}" \
    && PS_INSTALL_FOLDER=/opt/microsoft/powershell/${PS_MAJOR_VERSION} \
    && PS_PACKAGE=powershell-${PS_MAJOR_VERSION}-linux-${PS_ARCH}.tar.gz \
    && PS_PACKAGE_URL=https://github.com/PowerShell/PowerShell/releases/download/v${PS_MAJOR_VERSION}/${PS_PACKAGE} \
    && echo "PowerShell Package: ${PS_PACKAGE}" \
    && echo "PowerShell Package URL: ${PS_PACKAGE_URL}" \
    && curl -LO ${PS_PACKAGE_URL} \
    && mkdir -p ${PS_INSTALL_FOLDER} \
    && tar zxf ${PS_PACKAGE} -C ${PS_INSTALL_FOLDER} \
    && chmod a+x,o-w ${PS_INSTALL_FOLDER}/pwsh \
    && ln -s ${PS_INSTALL_FOLDER}/pwsh /usr/bin/pwsh \
    && rm ${PS_PACKAGE} \
    && echo /usr/bin/pwsh >> /etc/shells

# Check installed versions of .NET and PowerShell
RUN pwsh -Command "Write-Output \$PSVersionTable" \
    && pwsh -Command "dotnet --list-runtimes" \
    && pwsh -Command "\$DebugPreference='Continue'; Write-Output 'Debug preference set to Continue'"

FROM msft-install AS vmware-install-arm64


FROM msft-install AS vmware-install-amd64

# Install and setup VMware.PowerCLI PowerShell Module
#RUN pwsh -Command "Install-Module -Name VMware.PowerCLI -RequiredVersion 13.0.0.20829139 -Scope AllUsers -Repository PSGallery -Force -Verbose"

FROM vmware-install-${TARGETARCH} AS vmware-install-common

# PowerShell Core for ARM (important to use this archive file)
ARG POWERCLIURL=https://vdc-download.vmware.com/vmwb-repository/dcr-public/02830330-d306-4111-9360-be16afb1d284/c7b98bc2-fcce-44f0-8700-efed2b6275aa/VMware-PowerCLI-13.0.0-20829139.zip
ARG POWERCLI_PATH="/usr/local/share/powershell/Modules"
ADD ${POWERCLIURL} /tmp/VMware-PowerCLI-13.0.0-20829139.zip
RUN mkdir -p $POWERCLI_PATH \
    && pwsh -Command Expand-Archive -Path /tmp/VMware-PowerCLI-13.0.0-20829139.zip -DestinationPath $POWERCLI_PATH \
    && rm /tmp/VMware-PowerCLI-13.0.0-20829139.zip \
    && ls -d $POWERCLI_PATH/VMware.* | grep -v 'VMware.ImageBuilder' | xargs rm -rf

# Installing Python 3.7 libs: six psutil lxml pyopenssl
# Needed apt package(s): gcc, wget, python3, python3-dev, python3-distutils
USER $USERNAME
RUN mkdir -p /home/$USERNAME/.local/bin && chown ${USER_UID}:${USER_GID} /home/$USERNAME/.local/bin && chmod 755 /home/$USERNAME/.local/bin
ADD --chown=${USER_UID}:${USER_GID} https://bootstrap.pypa.io/pip/3.7/get-pip.py /home/$USERNAME/.local/bin
ENV PATH=${PATH}:/home/$USERNAME/.local/bin
RUN python3.7 /home/$USERNAME/.local/bin/get-pip.py \
    && python3.7 -m pip install --no-cache-dir six psutil lxml pyopenssl \
    && rm /home/$USERNAME/.local/bin/get-pip.py

# Setting up VMware.PowerCLI to $USERNAME
ARG VMWARECEIP=false
RUN pwsh -Command "Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP \$${VMWARECEIP} -Confirm:\$false" \
    && pwsh -Command "Set-PowerCLIConfiguration -PythonPath /usr/bin/python3.7 -Scope User -Confirm:\$false"

# Installing ESXi-Customizer-PS from https://v-front.de
RUN git clone https://github.com/VFrontDe-Org/ESXi-Customizer-PS /home/$USERNAME/files/ESXi-Customizer-PS

# Clean up Finalizing
USER root
RUN apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
USER $USERNAME

# Switching back to interactive after container build
ENV DEBIAN_FRONTEND=dialog

# Setting entrypoint to Powershell
ENTRYPOINT ["pwsh"]
