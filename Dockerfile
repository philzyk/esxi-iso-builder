FROM ubuntu:20.04 AS base
LABEL Maintainer = "Jeremy Combs <jmcombs@me.com>"

# Switching to non-interactive for cotainer build
ENV DEBIAN_FRONTEND=noninteractive

# Dockerfile ARG variables set automatically to aid in software installation
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
        libc6 \
        libgcc1 \
        libgssapi-krb5-2 \
        libicu66 \
        libssl1.1 \
        libstdc++6 \
        p7zip-full \
        zlib1g

# Configure en_US.UTF-8 Locale
## apt-get package: locales
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

# Microsoft .NET Core 3.1 Runtime for VMware PowerCLI
# apt package(s): libc6m, libgcc1, libgssapi-krb5-2, libicu66, libssl1.1, libstdc++6, unzip, wget, zlib1g
ARG DOTNET_VERSION=3.1.32
    ARG DOTNET_PACKAGE=dotnet-runtime-${DOTNET_VERSION}-linux-${DOTNET_ARCH}.tar.gz
    ARG DOTNET_PACKAGE_URL=https://dotnetcli.azureedge.net/dotnet/Runtime/${DOTNET_VERSION}/${DOTNET_PACKAGE}
    ENV DOTNET_ROOT=/opt/microsoft/dotnet/${DOTNET_VERSION}
    ENV PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools
ADD ${DOTNET_PACKAGE_URL} /tmp/${DOTNET_PACKAGE}
RUN mkdir -p ${DOTNET_ROOT} \
    && tar zxf /tmp/${DOTNET_PACKAGE} -C ${DOTNET_ROOT} \
    && rm /tmp/${DOTNET_PACKAGE}

# PowerShell Core 7.2 (LTS)
# apt package(s): ca-certificates, less, libssl1.1, libicu66, wget, unzip
RUN PS_MAJOR_VERSION=$(curl -Ls -o /dev/null -w %{url_effective} https://aka.ms/powershell-release\?tag\=lts | cut -d 'v' -f 2 | cut -d '.' -f 1) \
    && PS_INSTALL_FOLDER=/opt/microsoft/powershell/${PS_MAJOR_VERSION} \
    && PS_PACKAGE=$(curl -Ls -o /dev/null -w %{url_effective} https://aka.ms/powershell-release\?tag\=lts | sed 's#https://github.com#https://api.github.com/repos#g; s#tag/#tags/#' | xargs curl -s | grep browser_download_url | grep linux-${PS_ARCH}.tar.gz | cut -d '"' -f 4 | xargs basename) \
    && PS_PACKAGE_URL=$(curl -Ls -o /dev/null -w %{url_effective} https://aka.ms/powershell-release\?tag\=lts | sed 's#https://github.com#https://api.github.com/repos#g; s#tag/#tags/#' | xargs curl -s | grep browser_download_url | grep linux-${PS_ARCH}.tar.gz | cut -d '"' -f 4) \
    && curl -LO ${PS_PACKAGE_URL} \
    && mkdir -p ${PS_INSTALL_FOLDER} \
    && tar zxf ${PS_PACKAGE} -C ${PS_INSTALL_FOLDER} \
    && chmod a+x,o-w ${PS_INSTALL_FOLDER}/pwsh \
    && ln -s ${PS_INSTALL_FOLDER}/pwsh /usr/bin/pwsh \
    && rm ${PS_PACKAGE} \
    && echo /usr/bin/pwsh >> /etc/shells

FROM msft-install as vmware-install-arm64

ARG POWERCLIURL=https://vdc-download.vmware.com/vmwb-repository/dcr-public/02830330-d306-4111-9360-be16afb1d284/c7b98bc2-fcce-44f0-8700-efed2b6275aa/VMware-PowerCLI-13.0.0-20829139.zip
ADD ${POWERCLIURL} /tmp/vmware-powercli.zip
RUN apt-get update && apt-get install -y p7zip-full \
    && mkdir -p /usr/local/share/powershell/Modules \
    && 7z x /tmp/vmware-powercli.zip -o/usr/local/share/powershell/Modules \
    && chmod -R 755 /usr/local/share/powershell/Modules \
    && rm /tmp/vmware-powercli.zip \
    && pwsh -Command '$PSVersionTable.PSVersion'
RUN pwsh -Command "Get-Module -Name VMware.* -ListAvailable | Format-List | ForEach-Object { Write-Output $_ }"

##ADD ${POWERCLIURL} /tmp/vmware-powercli.zip
##RUN pwsh -Command '$PSVersionTable.PSVersion'
##RUN mkdir -p /usr/local/share/powershell/Modules
##RUN pwsh -Command Expand-Archive -Path /tmp/vmware-powercli.zip -DestinationPath /usr/local/share/powershell/Modules
##RUN rm /tmp/vmware-powercli.zip

FROM msft-install as vmware-install-amd64

# Install and setup VMware.PowerCLI PowerShell Module
RUN pwsh -Command Install-Module -Name VMware.PowerCLI -Scope AllUsers -Repository PSGallery -Force -Verbose

FROM vmware-install-${TARGETARCH} as vmware-install-common

ARG VMWARECEIP=false

# Switch to non-root user for remainder of build
USER $USERNAME

# Python 3 for VMware PowerCLI
# apt package(s): gcc, wget, python3, python3-dev, python3-distutils
ADD --chown=${USER_UID}:${USER_GID} https://bootstrap.pypa.io/pip/3.7/get-pip.py /tmp/
ENV PATH=${PATH}:/home/$USERNAME/.local/bin
RUN python3.7 /tmp/get-pip.py \
    && python3.7 -m pip install six psutil lxml pyopenssl \
    && rm /tmp/get-pip.py
# Display all installed PowerCLI modules
RUN pwsh -Command "Get-Module -Name VMware.* -ListAvailable | Format-List | ForEach-Object { Write-Output $_ }"
RUN pwsh -Command Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP \$${VMWARECEIP} -Confirm:\$false \
    && pwsh -Command Set-PowerCLIConfiguration -PythonPath /usr/bin/python3.7 -Scope User -Confirm:\$false

# Switching back to interactive after container build
ENV DEBIAN_FRONTEND=dialog
# Setting entrypoint to Powershell
ENTRYPOINT ["pwsh"]
