$modulePath = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'Modules'

# Import the Networking Common Modules
Import-Module -Name (Join-Path -Path $modulePath `
        -ChildPath (Join-Path -Path 'NetworkingDsc.Common' `
            -ChildPath 'NetworkingDsc.Common.psm1'))

Import-Module -Name (Join-Path -Path $modulePath -ChildPath 'DscResource.Common')

# Import Localization Strings
$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'

<#
    This is an array of all the parameters used by this resource.
#>
$resourceData = Import-LocalizedData `
    -BaseDirectory $PSScriptRoot `
    -FileName 'DSC_NetTcpSetting.data.psd1'

# This must be a script parameter so that it is accessible
$script:parameterList = $resourceData.ParameterList

<#
    .SYNOPSIS
        Returns the current Network TCP Settings.

    .PARAMETER IsSingleInstance
        Specifies the resource is a single instance, the value must be 'Yes'.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [System.String]
        $IsSingleInstance
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.GettingNetTcpSettingMessage)
        ) -join '' )

    # Get the current Net TCP Settings
    $netTcpSetting = Get-NetTcpSetting -ErrorAction Stop

    $returnValue = @()

    foreach ($setting in $netTcpSetting)
    {
        $settingValue = @{}
        foreach ($parameter in $script:parameterList)
        {
            $settingValue += @{
                $parameter.Name = $setting.$($parameter.name)
            }
        }
        $returnValue += $settingValue
    }

    return $returnValue
} # Get-TargetResource

<#
    .SYNOPSIS
        Sets the Network TCP Settings.

    .NOTES
        1. You can modify Custom and Non-Custom settings on windows server 2016 and 2019.
        2. You can modify only Custom settings, Internet and Datacenter settings Cannot be modified on windows 2012 or earlier versions.
        3. You cannot modify the NetTCPsetting on Client Operating systems(Windows 7, 8.1 and 10) as they are Read-Only.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [System.String]
        $IsSingleInstance,

        [Parameter()]
        [System.String]
        $SettingName,

        [Alias('MinRtoMs')]
        [Parameter()]
        [System.Uint32]
        $MinRto,

        [Alias('InitialCongestionWindowMss')]
        [Parameter()]
        [System.Uint32]
        $InitialCongestionWindow,

        [Parameter()]
        [ValidateSet('Default', 'CTCP', 'DCTCP')]
        [System.String]
        $CongestionProvider,

        [Parameter()]
        [ValidateSet('True', 'False')]
        [System.String]
        $CwndRestart,

        [Alias('DelayedAckTimeoutMs')]
        [Parameter()]
        [System.Uint32]
        $DelayedAckTimeout,

        [Parameter()]
        [System.Byte]
        $DelayedAckFrequency,

        [Parameter()]
        [ValidateSet('Disabled', 'Enabled', 'Default')]
        [System.String]
        $MemoryPressureProtection,

        [Parameter()]
        [ValidateSet('Disabled', 'HighlyRestricted', 'Restricted', 'Normal', 'Experimental')]
        [System.String]
        $AutoTuningLevelLocal,

        [Parameter()]
        [ValidateSet('Disabled', 'Enabled')]
        [System.String]
        $EcnCapability,

        [Parameter()]
        [ValidateSet('Disabled', 'Enabled')]
        [System.String]
        $Timestamps,

        [Alias('InitialRtoMs')]
        [Parameter()]
        [System.Uint32]
        $InitialRto,

        [Parameter()]
        [ValidateSet('Disabled', 'Enabled')]
        [System.String]
        $ScalingHeuristics,

        [Parameter()]
        [System.Uint16]
        $DynamicPortRangeStartPort,

        [Parameter()]
        [System.Uint16]
        $DynamicPortRangeNumberOfPorts,

        [Parameter()]
        [ValidateSet('Disabled', 'Enabled')]
        [System.String]
        $AutomaticUseCustom,

        [Parameter()]
        [ValidateSet('Disabled', 'Enabled')]
        [System.String]
        $NonSackRttResiliency,

        [Parameter()]
        [ValidateSet('Disabled', 'Enabled')]
        [System.String]
        $ForceWS,

        [Parameter()]
        [System.Byte]
        $MaxSynRetransmissions,

        [Parameter()]
        [System.Uint16]
        $AutoReusePortRangeStartPort,

        [Parameter()]
        [System.Uint16]
        $AutoReusePortRangeNumberOfPorts
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.SettingNetTcpSettingMessage)
        ) -join '' )

    # Get the current Net TCP Settings
    $existingNetTcpSettings = Get-TargetResource -IsSingleInstance 'Yes'
    if ($PSBoundParameters.Keys -contains 'SettingName')
    {
        $netTcpSetting = ($existingNetTcpSettings).Where{$_.SettingName -eq $SettingName}
    }
    else
    {
        $netTcpSetting = ($existingNetTcpSettings).Where{$_.SettingName -ne 'Automatic'}
    }
###### need to look at this section
    foreach ($setting in $netTcpSetting)
    {
        # Generate a list of parameters that will need to be changed within this setting.
        $settingChangeParameters = @{}

        foreach ($parameter in $script:parameterList.Where{$_.Name -ne 'SettingName'})
        {
            $parameterSourceValue = $netTcpSetting.$($parameter.name)
            $parameterNewValue = (Get-Variable -Name ($parameter.name)).Value

            if ($PSBoundParameters.ContainsKey($parameter.Name) `
                    -and (Compare-Object -ReferenceObject $parameterSourceValue -DifferenceObject $parameterNewValue -SyncWindow 0))
            {
                $settingChangeParameters += @{
                    $($parameter.name) = $parameterNewValue
                }

                Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($script:localizedData.NetTcpSettingUpdateParameterMessage) `
                            -f $parameter.Name,($parameterNewValue -join ',')
                    ) -join '' )
            } # if

        } # foreach

        if ($changeParameters.Count -gt 0)
        {
            # Update any parameters that were identified as different
            $null = Set-NetTcpSetting @ChangeParameters -ErrorAction Stop

            Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($script:localizedData.NetTcpSettingUpdatedMessage)
                ) -join '' )
        } # if

    } # foreach
#######

} # Set-TargetResource

<#
    .SYNOPSIS
        Tests the state of Network TCP Settings.

    .NOTES
        1. You can modify Custom and Non-Custom settings on windows server 2016 and 2019.
        2. You can modify only Custom settings, Internet and Datacenter settings Cannot be modified on windows 2012 or earlier versions.
        3. You cannot modify the NetTCPsetting on Client Operating systems(Windows 7, 8.1 and 10) as they are Read-Only.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [System.String]
        $IsSingleInstance,

        [Parameter()]
        [System.String]
        $SettingName,

        [Alias('MinRtoMs')]
        [Parameter()]
        [System.Uint32]
        $MinRto,

        [Alias('InitialCongestionWindowMss')]
        [Parameter()]
        [System.Uint32]
        $InitialCongestionWindow,

        [Parameter()]
        [ValidateSet('Default', 'CTCP', 'DCTCP')]
        [System.String]
        $CongestionProvider,

        [Parameter()]
        [ValidateSet('True', 'False')]
        [System.String]
        $CwndRestart,

        [Alias('DelayedAckTimeoutMs')]
        [Parameter()]
        [System.Uint32]
        $DelayedAckTimeout,

        [Parameter()]
        [System.Byte]
        $DelayedAckFrequency,

        [Parameter()]
        [ValidateSet('Disabled', 'Enabled', 'Default')]
        [System.String]
        $MemoryPressureProtection,

        [Parameter()]
        [ValidateSet('Disabled', 'HighlyRestricted', 'Restricted', 'Normal', 'Experimental')]
        [System.String]
        $AutoTuningLevelLocal,

        [Parameter()]
        [ValidateSet('Disabled', 'Enabled')]
        [System.String]
        $EcnCapability,

        [Parameter()]
        [ValidateSet('Disabled', 'Enabled')]
        [System.String]
        $Timestamps,

        [Alias('InitialRtoMs')]
        [Parameter()]
        [System.Uint32]
        $InitialRto,

        [Parameter()]
        [ValidateSet('Disabled', 'Enabled')]
        [System.String]
        $ScalingHeuristics,

        [Parameter()]
        [System.Uint16]
        $DynamicPortRangeStartPort,

        [Parameter()]
        [System.Uint16]
        $DynamicPortRangeNumberOfPorts,

        [Parameter()]
        [ValidateSet('Disabled', 'Enabled')]
        [System.String]
        $AutomaticUseCustom,

        [Parameter()]
        [ValidateSet('Disabled', 'Enabled')]
        [System.String]
        $NonSackRttResiliency,

        [Parameter()]
        [ValidateSet('Disabled', 'Enabled')]
        [System.String]
        $ForceWS,

        [Parameter()]
        [System.Byte]
        $MaxSynRetransmissions,

        [Parameter()]
        [System.Uint16]
        $AutoReusePortRangeStartPort,

        [Parameter()]
        [System.Uint16]
        $AutoReusePortRangeNumberOfPorts
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.TestingNetTcpSettingMessage)
        ) -join '' )

    # Flag to signal whether settings are correct
    $desiredConfigurationMatch = $true

    # Get the current Net TCP Settings for the setting name, if supplied
    $existingNetTcpSettings = Get-TargetResource -IsSingleInstance 'Yes'
    if ($PSBoundParameters.Keys -contains 'SettingName')
    {
        $netTcpSetting = ($existingNetTcpSettings).Where{$_.SettingName -eq $SettingName}
    }
    else
    {
        $netTcpSetting = ($existingNetTcpSettings).Where{$_.SettingName -ne 'Automatic'}
    }

    foreach ($setting in $netTcpSetting)
    {
        # Check each parameter within this setting
        foreach ($parameter in $script:parameterList.Where{$_.Name -ne 'SettingName'})
        {
            $parameterSourceValue = $setting.$($parameter.name)
            $parameterNewValue = (Get-Variable -Name ($parameter.name)).Value
            $parameterValueMatch = $true

            if ($PSBoundParameters.ContainsKey($parameter.Name) -and $parameterSourceValue -ne $parameterNewValue)
            {
                $parameterValueMatch = $false
            }

            if ($parameterValueMatch -eq $false)
            {
                Write-Verbose -Message ( @( "$($MyInvocation.MyCommand): "
                        $($script:localizedData.NetTcpSettingParameterNeedsUpdateMessage) `
                            -f $setting.SettingName, $parameter.Name, ($parameterSourceValue -join ','), ($parameterNewValue -join ',')
                    ) -join '')
                $desiredConfigurationMatch = $false
            }
        } # foreach
    }

    return $desiredConfigurationMatch
} # Test-TargetResource

Export-ModuleMember -Function *-TargetResource
