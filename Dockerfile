FROM ubuntu:20.04 AS base
LABEL Maintainer = "Jeremy Combs <jmcombs@me.com>"

# Dockerfile ARG variables set automatically to aid in software installation
ARG TARGETARCH

RUN echo What is ${TARGETARCH}

FROM base AS linux-amd64
ARG ARCH=x64

FROM base AS linux-arm64
ARG ARCH=arm64

FROM base AS linux-arm
ARG ARCH=arm

FROM linux-${TARGETARCH} AS final

# Switching to non-interactive for cotainer build
ENV DEBIAN_FRONTEND=noninteractive

# Configure apt and install packages
RUN apt-get update \
    && apt-get -y install software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get -y install --no-install-recommends  \ 
        apt-transport-https \
        ca-certificates \
        gcc \
        locales \
        mkisofs \
        python3.7 \
        python3.7-dev \
        python3.7-distutils \
        sudo \
        unzip \
        wget \
        whois \
        less \
        libc6 \
        libgcc1 \
        libgssapi-krb5-2 \
        libicu66 \
        libssl1.1 \
        libstdc++6 \
        zlib1g

# Configure en_US.UTF-8 Locale
## apt-get package: locales
ENV LANGUAGE=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8
RUN localedef -c -i en_US -f UTF-8 en_US.UTF-8 \
    && locale-gen en_US.UTF-8 \
    && dpkg-reconfigure locales

# Microsoft .NET Core 3.1 Runtime for VMware PowerCLI
# apt package(s): libc6m, libgcc1, libgssapi-krb5-2, libicu66, libssl1.1, libstdc++6, unzip, wget, zlib1g
ARG DOTNET_VERSION=3.1.32
    ARG DOTNET_PACKAGE=dotnet-runtime-${DOTNET_VERSION}-linux-${ARCH}.tar.gz
    ARG DOTNET_PACKAGE_URL=https://dotnetcli.azureedge.net/dotnet/Runtime/${DOTNET_VERSION}/${DOTNET_PACKAGE}
    ENV DOTNET_ROOT=/opt/microsoft/dotnet/${DOTNET_VERSION}
    ENV PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools
RUN wget -N -O /tmp/dotnet-install.tar.gz ${DOTNET_PACKAGE_URL} \
    && mkdir -p ${DOTNET_ROOT} \
    && tar zxf /tmp/dotnet-install.tar.gz -C ${DOTNET_ROOT} \
    && rm /tmp/dotnet-install.tar.gz

# PowerShell Core 7.2 (LTS)
# apt package(s): ca-certificates, less, libssl1.1, libicu66, wget, unzip
ARG PS_VERSION=7.2.7
    ARG PS_PACKAGE=powershell-${PS_VERSION}-linux-${ARCH}.tar.gz
    ARG PS_PACKAGE_URL=https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/${PS_PACKAGE}
    ARG PS_INSTALL_VERSION=7
    ARG PS_INSTALL_FOLDER=/opt/microsoft/powershell/$PS_INSTALL_VERSION
RUN wget -N -O /tmp/powershell.tar.gz https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell-${PS_VERSION}-linux-${ARCH}.tar.gz \
    && mkdir -p ${PS_INSTALL_FOLDER} \
    && tar zxf /tmp/powershell.tar.gz -C ${PS_INSTALL_FOLDER} \
    && chmod a+x,o-w ${PS_INSTALL_FOLDER}/pwsh \
    && ln -s ${PS_INSTALL_FOLDER}/pwsh /usr/bin/pwsh \
    && rm /tmp/powershell.tar.gz \
    && echo /usr/bin/pwsh >> /etc/shells

# Python 3.7 for VMware PowerCLI
# apt package(s): gcc, wget, python3.7, python3.7-dev, python3.7-distutils
RUN wget -P /tmp https://bootstrap.pypa.io/get-pip.py \
     && python3.7 /tmp/get-pip.py \
     && python3.7 -m pip install six psutil lxml pyopenssl

ARG VMWARECEIP=false
# Install and setup VMware.PowerCLI PowerShell Module
RUN pwsh -Command Install-Module -Name VMware.PowerCLI -Scope AllUsers -Repository PSGallery -Force -Verbose \
    && pwsh -Command Set-PowerCLIConfiguration -PythonPath /usr/bin/python3.7 -Scope User -Confirm:\$false \
    && pwsh -Command Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP \$${VMWARECEIP} -Confirm:\$false \
    && pwsh -Command \
        Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock { \
            param\(\$commandName, \$wordToComplete, \$cursorPosition\) \
                dotnet complete --position \$cursorPosition \"\$wordToComplete\" \| ForEach-Object { \
                    [System.Management.Automation.CompletionResult]::new\(\$_, \$_, \'ParameterValue\', \$_\) \
                } \
        }

# Defining non-root User
ARG USERNAME=coder
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Set up non-root User and grant sudo privileges 
# apt-get package: sudo
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID --shell /usr/bin/pwsh --create-home $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL >> /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME
WORKDIR /home/$USERNAME

# Clean up
RUN apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Use non-root user as default account when launching container
USER $USERNAME
# Switching back to interactive after container build
ENV DEBIAN_FRONTEND=dialog
# Setting entrypoint to Powershell
ENTRYPOINT ["pwsh"]
