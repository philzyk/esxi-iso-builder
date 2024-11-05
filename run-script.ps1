param(
    [Parameter(Mandatory=$false)]
    [string]$iZip,
    [Parameter(Mandatory=$false)]
    [string]$outDir,
    [Parameter(Mandatory=$false)]
    [string[]]$pkgDir,
    [Parameter(Mandatory=$false)]
    [switch]$update,
    [Parameter(Mandatory=$false)]
    [switch]$vft,
    [Parameter(Mandatory=$false)]
    [string[]]$load,
    [Parameter(Mandatory=$false)]
    [string[]]$remove,
    [Parameter(Mandatory=$false)]
    [string]$ipname,
    [Parameter(Mandatory=$false)]
    [switch]$ozip,
    [Parameter(Mandatory=$false)]
    [switch]$v80,
    [Parameter(Mandatory=$false)]
    [switch]$v70,
    [Parameter(Mandatory=$false)]
    [switch]$v67,
    [Parameter(Mandatory=$false)]
    [switch]$v65
)

# Import PowerCLI module
Import-Module VMware.PowerCLI

# Execute the main script with parameters
& "/scripts/esxi-customizer.ps1" @PSBoundParameters
