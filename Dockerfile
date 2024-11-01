# Base image
FROM ubuntu:20.04 AS base
LABEL Maintainer="Jeremy Combs <jmcombs@me.com>"

# Set non-interactive mode for container build
ENV DEBIAN_FRONTEND=noninteractive

# Dockerfile ARG variables for architecture
ARG TARGETARCH

# Configure apt and install required packages
RUN apt-get update && \
    apt-get -y install software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get -y install --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        wget \
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
        gawk \
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
ARG USERNAME=coder
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Set up non-root user with sudo privileges
RUN groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID --shell /usr/bin/pwsh --create-home $USERNAME && \
    echo "$USERNAME ALL=(root) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

WORKDIR /home/$USERNAME
###################################################################################################
# Architecture specific stages

FROM base AS linux-amd64
ARG DOTNET_ARCH=x64
ARG PS_ARCH=x64

FROM base AS linux-arm64
ARG DOTNET_ARCH=arm64
ARG PS_ARCH=arm64

# Uncomment and fix the typo for linux-arm if needed
# FROM base AS linux-arm
# ARG DOTNET_ARCH=arm
# ARG PS_ARCH=arm32

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

# PowerShell Core 7.2 (LTS)
#ENV PS_MAJOR_VERSION=7.2.0
#RUN PS_MAJOR_VERSION=$(curl -Ls -o /dev/null -w %{url_effective} https://aka.ms/powershell-release\?tag\=lts | cut -d 'v' -f 2 | cut -d '.' -f 1) \
#RUN echo "PowerShell Major Version: ${PS_MAJOR_VERSION}" \
#    && echo "PowerShell Major Version: ${PS_MAJOR_VERSION}" \
#    && PS_INSTALL_FOLDER=/opt/microsoft/powershell/${PS_MAJOR_VERSION} \
#    && PS_PACKAGE=$(curl -Ls -o /dev/null -w %{url_effective} https://aka.ms/powershell-release\?tag\=lts | sed 's#https://github.com#https://api.github.com/repos#g; s#tag/#tags/#' | xargs curl -s | grep browser_download_url | grep linux-${PS_ARCH}.tar.gz | cut -d '"' -f 4 | xargs basename) \
#    && echo "PowerShell Package: ${PS_PACKAGE}" \
#    && PS_PACKAGE_URL=$(curl -Ls -o /dev/null -w %{url_effective} https://aka.ms/powershell-release\?tag\=lts | sed 's#https://github.com#https://api.github.com/repos#g; s#tag/#tags/#' | xargs curl -s | grep browser_download_url | grep linux-${PS_ARCH}.tar.gz | cut -d '"' -f 4) \
#    && echo "PowerShell Package URL: ${PS_PACKAGE_URL}" \
#    && curl -LO ${PS_PACKAGE_URL} \
#    && mkdir -p ${PS_INSTALL_FOLDER} \
#    && tar zxf ${PS_PACKAGE} -C ${PS_INSTALL_FOLDER} \
#    && chmod a+x,o-w ${PS_INSTALL_FOLDER}/pwsh \
#    && ln -s ${PS_INSTALL_FOLDER}/pwsh /usr/bin/pwsh \
#    && rm ${PS_PACKAGE} \
#    && echo /usr/bin/pwsh >> /etc/shells

# PowerShell Core 7.2 (LTS)
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
# Check installed versions of .NET and PowerShell
RUN pwsh -Command "Write-Output \$PSVersionTable" \
    && pwsh -Command "dotnet --list-runtimes" \
    && pwsh -Command "\$DebugPreference='Continue'; Write-Output 'Debug preference set to Continue'"



FROM msft-install as vmware-install-arm64

#  PowerShell Core for ARM
#ARG POWERCLI_URL="https://vdc-download.vmware.com/vmwb-repository/dcr-public/02830330-d306-4111-9360-be16afb1d284/c7b98bc2-fcce-44f0-8700-efed2b6275aa/VMware-PowerCLI-13.0.0-20829139.zip"
#ARG MODULE_PATH="/usr/local/share/powershell/Modules"
# Download and install PowerCLI
#RUN curl -L -o /tmp/PowerCLI.zip "$POWERCLI_URL"
#RUN mkdir -p "$MODULE_PATH"
#RUN 7z rn /tmp/PowerCLI.zip $(7z l /tmp/PowerCLI.zip | grep '\\' | awk '{ print $6, gensub(/\\/, "/", "g", $6); }' | paste -s)
#RUN 7z x /tmp/PowerCLI.zip -o"$MODULE_PATH"
#RUN chmod -R 755 "$MODULE_PATH"
#RUN ls -lah "$MODULE_PATH"/VMware.PowerCLI/
#RUN rm /tmp/PowerCLI.zip

RUN pwsh -c "Save-Module -Name VMware.PowerCLI  -RequiredVersion 13.0.0.20829139 -Path ~/"
RUN pwsh -c "Install-Module -Name VMware.PowerCLI -Scope AllUsers -Force"
RUN pwsh -c "Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP 0 -Confirm:0"
RUN pwsh -c "Set-PowerCLIConfiguration -Scope User -InvalidCertificateAction Ignore -Confirm:0"
RUN pwsh -c "Get-Module -ListAvailable VMware.PowerCLI"
RUN pwsh -c "Import-Module VMware.PowerCLI"

FROM msft-install as vmware-install-amd64

# Install and setup VMware.PowerCLI PowerShell Module
# RUN pwsh -Command "Install-Module -Name VMware.PowerCLI -Scope AllUsers -Repository PSGallery -Force -Verbose"
RUN pwsh -Command "Install-Module -Name VMware.PowerCLI -RequiredVersion 13.0.0.20829139 -Scope AllUsers -Repository PSGallery -Force -Verbose"


FROM vmware-install-${TARGETARCH} as vmware-install-common

ARG VMWARECEIP=false
# Switch to non-root user for remainder of build
USER $USERNAME
RUN mkdir -p /home/$USERNAME/.local/bin && chown ${USER_UID}:${USER_GID} /home/$USERNAME/.local/bin && chmod 755 /home/$USERNAME/.local/bin
# Python 3 for VMware PowerCLI
# apt package(s): gcc, wget, python3, python3-dev, python3-distutils
ADD --chown=${USER_UID}:${USER_GID} https://bootstrap.pypa.io/pip/3.7/get-pip.py /home/$USERNAME/.local/bin
ENV PATH=${PATH}:/home/$USERNAME/.local/bin
RUN python3.7 /home/$USERNAME/.local/bin/get-pip.py \
    && python3.7 -m pip install --no-cache-dir six psutil lxml pyopenssl \
    && rm /home/$USERNAME/.local/bin/get-pip.py

RUN mkdir -p /home/coder/files/{cfg_files,iso_temp} \
    && mkdir -p /home/coder/files/esxi6_7/{repo_zip_esxi6_7,ready_iso_esxi6_7,drivers_esxi6_7} \
    && mkdir -p /home/coder/files/esxi7/{repo_zip_esxi7,ready_iso_esxi7,drivers_esxi7} \
    && mkdir -p /home/coder/files/esxi8/{repo_zip_esxi8,ready_iso_esxi8,drivers_esxi8}
#RUN find /usr/local -iname VMware.PowerCLI.psd1
# Split PSModulePath to check directories (single line output for clarity in Docker)

# Import VMware.PowerCLI with error handling in a single line
#RUN pwsh -Command "$env:PSModulePath -split ';' | ForEach-Object { Write-Host $_ }"
#RUN pwsh -Command "try { Import-Module VMware.PowerCLI -Verbose } catch { Write-Host 'Failed to import module:' $_.Exception.Message }"
#RUN pwsh -Command "Import-Module -Name /usr/local/share/powershell/Modules/VMware.PowerCLI/13.0.0.20829139/VMware.PowerCLI.psd1"
#RUN pwsh -Command "$env:DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER='0'"
#RUN pwsh -Command "$env:PSModulePath -split ';'"
#RUN ls -lah /usr/local/share/powershell/Modules/
#RUN pwsh -Command "Get-Host"
#RUN pwsh -Command "Import-Module VMware.PowerCLI -Verbose"
RUN pwsh -Command "Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP \$${VMWARECEIP} -Confirm:\$false" \
    && pwsh -Command "Set-PowerCLIConfiguration -PythonPath /usr/bin/python3.7 -Scope User -Confirm:\$false"

# Clean up
USER root
RUN apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

USER $USERNAME
# Switching back to interactive after container build
ENV DEBIAN_FRONTEND=dialog
# Setting entrypoint to Powershell
ENTRYPOINT ["pwsh"]
