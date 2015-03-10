<# 
    .SYNOPSIS
    Configure a domain with DNS hosted with CloudFlare for Office 365.

    .DESCRIPTION
    The aim for this script is to allow for an automated provisioning of domains with CloudFlare hosted DNS to support Office 365.

    The entries that need to be created are actuallly pretty simple, with there only two entires that change:
        1. The verification entry
        2. The MX record.

    The MX record always follows a specific pattern, so we can calculate that.

    This script will not remove old MX records, and will generate errors if the specific domains already exist.

    This script requires that the Posh-CloudFlare module be in a discoverable location (or preloaded using import-module).

    .PARAMETER CloudFlareApiToken
    This is your CloudFlare ClientAPI Token. To find your token, look in the account page "Your API key is:". 

    .PARAMETER CloudFlareEmailAddress
    This is the email address you use to sign into CloudFlare's management console.

    .PARAMETER Domain
    The domain you want to setup Office365 for.

    .PARAMETER VerificationValue
    The setup wizard for a new domain will ask for either a TXT record or a MX record to be created to verify the domain. 
    If you want the script to create the TXT record (or optionally the MX record), specify the value here.
    The value is the value after the MS= in the TXT record display or the first piece of the content of the MX records as provided by Microsoft's wizard.

    .PARAMETER VerificationMX
    Specify to create the verification as MX and not a TXT record.

    .PARAMETER MailEnable
    Specifies if script should create DNS records for mail delivery (SMTP) to Office 365. These will include MX, SPF, MSOID, and AutoDiscover. 
    
    .PARAMETER EnableMailAliases  
    The script will also create two CNAME entries mail and webmail which point to mail.office365.com, allowing you to tell users to go to mail.yourdomain.com or webmail.yourdomain.com and for them to be directed to Outlook web access (OWA).

    .PARAMETER LyncEnable
    Specifies if script shoudl create DNS records for Lync, this includes SIP and Service (SRV) Records.

    .INPUTS
    This takes no input from the pipeline.

    .OUTPUTS
    Status messages only.

    .EXAMPLE
    Register-Office365 -CloudFlareApiToken <token> -CloudFlareEmailAddress admin@contoso.com -Domain contoso.com -VerificationValue <value>
    Create the domain verification TXT record for the specified domain, contoso.com. This would be a TXT record a the root of the domain (@) with value MS=<value>

    .EXAMPLE
    Register-Office365 -CloudFlareApiToken <token> -CloudFlareEmailAddress admin@contoso.com -Domain contoso.com -MailEnable
    Creates the MX, SPF (TXT), MSOID (CNAME), and AutoDiscover (CNAME) records in the contoso.com domain. 
    These are required for mail to be delivered for this domain to Offfice 365 as well as for email clients to connect.

    .EXAMPLE
    Register-Office365 -CloudFlareApiToken <token> -CloudFlareEmailAddress admin@contoso.com -Domain contoso.com -MailEnable -EnableMailAliases
    Creates the MX, SPF (TXT), MSOID (CNAME), and AutoDiscover (CNAME) records in the contoso.com domain as in the previous example.
    The script will also create a mail and webmail entry that allow for users to type mail.contoso.com or webmail.contoso.com and be redirected to the Office365 login page (and OWA)

    .EXAMPLE
    Register-Office365 -CloudFlareApiToken <token> -CloudFlareEmailAddress admin@contoso.com -Domain contoso.com -LyncEnable
    Creates the SIP (CNAME), SRV and LyncDiscover (CNAME) records in the contoso.com domain.
    These are required for Lync client connectivity.

    .EXAMPLE
    Register-Office365 -CloudFlareApiToken <token> -CloudFlareEmailAddress admin@contoso.com -Domain contoso.com -MailEnable -LyncEnable
    This will create both sets of records as outlined in example 3 and 4.

    .EXAMPLE
    Register-Office365 -CloudFlareApiToken <token> -CloudFlareEmailAddress admin@contoso.com -Domain contoso.com -VerificationValue <value> -VerificationMX -MailEnable -EnableMailAliases -LyncEnable
    This will create the verification record (as an MX entry), the mail delivery, mail and webmail aliases and the Lync records for the specified domain.

    .LINK
    http://poshsecurity.com

#>
Param
(
    [Parameter(mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [String]
    $CloudFlareApiToken,

    [Parameter(mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [String]
    $CloudFlareEmailAddress,

    [Parameter(mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [String]
    $Domain,

    [Parameter(mandatory = $False)]
    [ValidateNotNullOrEmpty()]
    [String]
    $VerificationValue,

    [Parameter(mandatory = $False)]
    [switch]
    $VerificationMX,

    [Parameter(mandatory = $False)]
    [switch]
    $MailEnable,

    [Parameter(mandatory = $False)]
    [switch]
    $EnableMailAliases,

    [Parameter(mandatory = $False)]
    [switch]
    $LyncEnable
)

if (-not $MailEnable -and -not $LyncEnable -and -not $VerificationValue)
{ Write-Error "You must select either: -VerificationValue, -MailEnable, -LyncEnabled or any combination" }

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
        { $null = $MXRecord | New-CFDNSRecord }
        catch
        { Write-Error -Message "An error was encountered creating MX record, $_" }
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

    if ($EnableMailAliases)
    {
        'This script will create the following records to allow for users to easily get to OWA:'
        "`tWebmail"
        "`tMail"

        # Mail
        $MailRecord  = [pscustomobject]@{
            APIToken = $CloudFlareApiToken
            Email    = $CloudFlareEmailAddress
            Zone     = $Domain
            Name     = 'mail'
            Content  = 'mail.office365.com'
            Type     = 'CNAME'
            TTL      = 3600
        }
    
        try
        {$null = $MailRecord | New-CFDNSRecord}
        catch
        {Write-Error -Message "An error was encountered creating mail record, $_"}

        # WebMail
        $WebMailRecord  = [pscustomobject]@{
            APIToken = $CloudFlareApiToken
            Email    = $CloudFlareEmailAddress
            Zone     = $Domain
            Name     = 'webmail'
            Content  = 'mail.office365.com'
            Type     = 'CNAME'
            TTL      = 3600
        }
    
        try
        {$null = $WebMailRecord | New-CFDNSRecord}
        catch
        {Write-Error -Message "An error was encountered creating webmail record, $_"}
    }
}

if ($LyncEnable)
{
    'This script will create the following records to enable Lync with Office 365:'
    "`tSIP record"
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

