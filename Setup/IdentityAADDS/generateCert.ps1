$domainName = 'lbgworkshop.local'

#Check if I am a local admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Error "You must be a local admin to run this script"
    exit 1
}

#Get input for the PFX password
$pfxCertificatePassword = Read-Host -Prompt "Enter the PFX password" -AsSecureString

#Generate a PFX self-signed certificate and convert it to base64 encoded to pass it to the AADDS bicep
Write-Host "Generating PFX certificate and converting to base64 encoded"
#$pfxCertificatePassword = ConvertTo-SecureString '<<YourPfxCertificatePassword>>' -AsPlainText -Force
$certInputObject = @{
    Subject           = "CN=*.$domainName"
    DnsName           = "*.$domainName"
    CertStoreLocation = 'cert:\LocalMachine\My'
    KeyExportPolicy   = 'Exportable'
    Provider          = 'Microsoft Enhanced RSA and AES Cryptographic Provider'
    NotAfter          = (Get-Date).AddMonths(1)
    HashAlgorithm     = 'SHA256'
}
$rawCert = New-SelfSignedCertificate @certInputObject
Export-PfxCertificate -Cert ('Cert:\localmachine\my\' + $rawCert.Thumbprint) -FilePath "$home/aadds.pfx" -Password $pfxCertificatePassword -Force
$rawCertByteStream = Get-Content "$home/aadds.pfx" -AsByteStream
$pfxCertificate = [System.Convert]::ToBase64String($rawCertByteStream)

#Check to make sure that pfxCertificate is not an empty string otherwise error
if ($pfxCertificate -eq '') {
    Write-Error "pfxCertificate is empty. Please check the pfxCertificatePassword"
    exit 1
}

Write-Host "Copy and paste the following into the deploy.ps1 script - make a note of your password as you will need it later"
$pfxCertificate

