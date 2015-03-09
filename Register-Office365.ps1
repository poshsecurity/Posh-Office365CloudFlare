Param
(
    [String]$CloudFlareApiToken,
    [String]$CloudFlareEmailAddress,
    [String]$Domain,
    [String]$VerificationValue,
    [switch]$VerificationMX,
    [switch]$MailEnable,
    [switch]$LyncEnable
)

if (-not $MailEnable -and -not $LyncEnable -and -not $VerificationValue)
{
    Write-Error "You must select either: -VerificationValue, -MailEnable, -LyncEnabled or any combination"
}

if ($VerificationValue)
{
    if ($VerificationMX)
    {
        'This script will create the MX record for verifying the domain with Office 365'
        
        $MXRecord = [pscustomobject]@{
            APIToken = $CloudFlareApiToken
            Email    = $CloudFlareEmailAddress
            Zone     = $Domain
            Name     = '@'
            Content  = '{0}.msv1.invalid' -f $VerificationValue
            Type     = 'MX'
            Priority = 32767
            TTL      = 3600
        }
        try
        {$null = $MXRecord | New-CFDNSRecord}
        catch
        {Write-Error -Message "An error was encountered creating MX record, $_"}
    }
    else
    {
        'This script will create the TXT record for verifying the domain with Office 365'

        $VerificationRecord = [pscustomobject]@{
            APIToken = $CloudFlareApiToken
            Email    = $CloudFlareEmailAddress
            Zone     = $Domain
            Name     = '@'
            Content  = 'MS={0}' -f $VerificationValue
            Type     = 'TXT'
            TTL      = 3600
        }

        try
        {$null = $VerificationRecord | New-CFDNSRecord}
        catch
        {Write-Error -Message "An error was encountered creating VerificationRecord record, $_"}
    }
}

if ($MailEnable)
{
    'This script will create the following records to enable mail delivery via Office 365:'
    "`tMX Record"
    "`tAutoDiscovery Record"
    "`tMSOID Record"
    "`tSPF TXT Record"

    # MX
    $MXRecord = [pscustomobject]@{
        APIToken = $CloudFlareApiToken
        Email    = $CloudFlareEmailAddress
        Zone     = $Domain
        Name     = '@'
        Content  = '{0}.mail.protection.outlook.com' -f $Domain.Replace('.', '-')
        Type     = 'MX'
        Priority = 0
        TTL      = 3600
    }
    try
    {$null = $MXRecord | New-CFDNSRecord}
    catch
    {Write-Error -Message "An error was encountered creating MX record, $_"}

    # Autodiscover
    $AutoDiscoverRecord  = [pscustomobject]@{
        APIToken = $CloudFlareApiToken
        Email    = $CloudFlareEmailAddress
        Zone     = $Domain
        Name     = 'autodiscover'
        Content  = 'autodiscover.outlook.com'
        Type     = 'CNAME'
        TTL      = 3600
    }
    
    try
    {$null = $AutoDiscoverRecord | New-CFDNSRecord}
    catch
    {Write-Error -Message "An error was encountered creating AutoDiscover record, $_"}

    # MSOID
    $MSOIDRecord  = [pscustomobject]@{
        APIToken = $CloudFlareApiToken
        Email    = $CloudFlareEmailAddress
        Zone     = $Domain
        Name     = 'msoid'
        Content  = 'clientconfig.microsoftonline-p.net'
        Type     = 'CNAME'
        TTL      = 3600
    }
    
    try
    {$null = $MSOIDRecord | New-CFDNSRecord}
    catch
    {Write-Error -Message "An error was encountered creating MSOID record, $_"}

    # SPF
    $SPFRecord  = [pscustomobject]@{
        APIToken = $CloudFlareApiToken
        Email    = $CloudFlareEmailAddress
        Zone     = $Domain
        Name     = '@'
        Content  = 'v=spf1 include:spf.protection.outlook.com -all'
        Type     = 'TXT'
        TTL      = 3600
    }
    
    try
    {$null = $SPFRecord | New-CFDNSRecord}
    catch
    {Write-Error -Message "An error was encountered creating SPF record, $_"}
}

if ($LyncEnable)
{
    'This script will create the following records to enable Lync with Office 365:'
    "`tSIPDIR record"
    "`tLync Discover Record"
    "`t_sip SRV Record"
    "`t_sipfederationtls Record"

    # SIP
    $SIPRecord  = [pscustomobject]@{
        APIToken = $CloudFlareApiToken
        Email    = $CloudFlareEmailAddress
        Zone     = $Domain
        Name     = 'sip'
        Content  = 'sipdir.online.lync.com'
        Type     = 'CNAME'
        TTL      = 3600
    }

    try
    {$null = $SIPRecord | New-CFDNSRecord}
    catch
    {Write-Error -Message "An error was encountered creating SIP record, $_"}

    # LyncDiscover
    $LyncDiscoverRecord  = [pscustomobject]@{
        APIToken = $CloudFlareApiToken
        Email    = $CloudFlareEmailAddress
        Zone     = $Domain
        Name     = 'lyncdiscover'
        Content  = 'webdir.online.lync.com'
        Type     = 'CNAME'
        TTL      = 3600
    }

    try
    {$null = $LyncDiscoverRecord | New-CFDNSRecord}
    catch
    {Write-Error -Message "An error was encountered creating LyncDiscover record, $_"}
    
    # _SIP
    $SIPSRVRecord  = [pscustomobject]@{
        APIToken = $CloudFlareApiToken
        Email    = $CloudFlareEmailAddress
        Zone     = $Domain
        Name     = '@'
        Content  = 'sipdir.online.lync.com'
        Type     = 'SRV'
        TTL      = 3600
        Service  = '_sip'
        Protocol = '_tls'
        Weight   = 1
        Port     = 443
        Priority = 100
    }
    
    try
    {$null = $SIPSRVRecord | New-CFDNSRecord}
    catch
    {Write-Error -Message "An error was encountered creating _sip record, $_"}
        
    # _SIPDEFERATIONTLS
    $SIPFEDSRVRecord  = [pscustomobject]@{
        APIToken = $CloudFlareApiToken
        Email    = $CloudFlareEmailAddress
        Zone     = $Domain
        Name     = '@'
        Content  = 'sipfed.online.lync.com'
        Type     = 'SRV'
        TTL      = 3600
        Service  = '_sipfederationtls'
        Protocol = '_tcp'
        Weight   = 1
        Port     = 5061
        Priority = 100
    }
    
    try
    {$null = $SIPFEDSRVRecord | New-CFDNSRecord}
    catch
    {Write-Error -Message "An error was encountered creating _sipfederationtls record, $_"}
}

