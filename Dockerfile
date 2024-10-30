# Base image with Ubuntu 20.04
FROM ubuntu:20.04 AS base
LABEL Maintainer="Jeremy Combs <jmcombs@me.com>"

# Setting environment to non-interactive for apt operations
ENV DEBIAN_FRONTEND=noninteractive

# Arguments for architecture and .NET / PowerShell versioning
ARG TARGETARCH

# Configure apt and install packages
RUN apt-get update \
    && apt-get -y install software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get -y install --no-install-recommends \
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
        unzip \
        p7zip-full \
        libc6 \
        libgcc1 \
        libgssapi-krb5-2 \
        libicu66 \
        libssl1.1 \
        libstdc++6 \
        zlib1g \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configure en_US.UTF-8 Locale
ENV LANGUAGE=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8
RUN localedef -c -i en_US -f UTF-8 en_US.UTF-8 \
    && locale-gen en_US.UTF-8 \
    && dpkg-reconfigure locales

# Defining non-root User
ARG USERNAME=coder
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Set up non-root User and grant sudo privileges
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID --shell /usr/bin/pwsh --create-home $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL >> /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME
WORKDIR /home/$USERNAME

# .NET Core Runtime for VMware PowerCLI
ARG DOTNET_VERSION=3.1.32
ARG DOTNET_PACKAGE=dotnet-runtime-${DOTNET_VERSION}-linux-${TARGETARCH}.tar.gz
ARG DOTNET_PACKAGE_URL=https://dotnetcli.azureedge.net/dotnet/Runtime/${DOTNET_VERSION}/${DOTNET_PACKAGE}
ENV DOTNET_ROOT=/opt/microsoft/dotnet/${DOTNET_VERSION}
ENV PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools
RUN curl -LO ${DOTNET_PACKAGE_URL} \
    && mkdir -p ${DOTNET_ROOT} \
    && tar zxf ${DOTNET_PACKAGE} -C ${DOTNET_ROOT} \
    && rm ${DOTNET_PACKAGE}

# PowerShell Core 7.2 (LTS)
RUN PS_PACKAGE_URL="https://github.com/PowerShell/PowerShell/releases/download/v7.2.0/powershell-7.2.0-linux-${TARGETARCH}.tar.gz" \
    && PS_INSTALL_FOLDER="/opt/microsoft/powershell/7" \
    && curl -L ${PS_PACKAGE_URL} -o /tmp/powershell.tar.gz \
    && mkdir -p ${PS_INSTALL_FOLDER} \
    && tar zxf /tmp/powershell.tar.gz -C ${PS_INSTALL_FOLDER} \
    && rm /tmp/powershell.tar.gz \
    && ln -s ${PS_INSTALL_FOLDER}/pwsh /usr/bin/pwsh

# Add PowerCLI for both x64 and arm64 architectures
FROM base AS vmware-install
ARG POWERCLIURL=https://vdc-download.vmware.com/vmwb-repository/dcr-public/02830330-d306-4111-9360-be16afb1d284/c7b98bc2-fcce-44f0-8700-efed2b6275aa/VMware-PowerCLI-13.0.0-20829139.zip
RUN curl -Lo /tmp/vmware-powercli.zip ${POWERCLIURL} \
    && mkdir -p /usr/local/share/powershell/Modules \
    && unzip /tmp/vmware-powercli.zip -d /usr/local/share/powershell/Modules \
    && rm /tmp/vmware-powercli.zip

# Switching to non-root user for remainder of build
USER $USERNAME

# Install pip and Python dependencies for VMware PowerCLI
ADD --chown=${USER_UID}:${USER_GID} https://bootstrap.pypa.io/pip/3.7/get-pip.py /tmp/
ENV PATH=${PATH}:/home/$USERNAME/.local/bin
RUN python3.7 /tmp/get-pip.py \
    && python3.7 -m pip install six psutil lxml pyopenssl \
    && rm /tmp/get-pip.py

# Set PowerCLI configurations
RUN pwsh -Command Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP \$false -Confirm:\$false \
    && pwsh -Command Set-PowerCLIConfiguration -PythonPath /usr/bin/python3.7 -Scope User -Confirm:\$false

# Setting entrypoint to PowerShell
ENTRYPOINT ["pwsh"]
