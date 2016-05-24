<#
run.ps1

Copyright © 2016 Luke Eckley

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
#>

$EmailFrom = ""
$EmailTo = ""
$SMTPServer = ""

$BasicAuthUser = ""
$BasicAuthPassword = ""

$LiveStreamURL = ""

$Encoders = @{}
$Encoders["HRA Encoder"] = "10.0.0.10"
$Encoders["HRB Encoder"] = "10.0.0.11"
$Encoders["HRC Encoder"] = "10.0.0.12"
$Encoders["HRD Encoder"] = "10.0.0.13"
$Encoders["HRE Encoder"] = "10.0.0.14"
$Encoders["HRF Encoder"] = "10.0.0.15"
$Encoders["House Encoder"] = "10.0.0.16"
$Encoders["Senate Encoder"] = "10.0.0.17"
$Encoders["HR50 Encoder"] = "10.0.0.18"
$Encoders["HR174 Encoder"] = "10.0.0.19"
$Encoders["HR170 Encoder"] = "10.0.0.20"
$Encoders["HR343 Encoder"] = "10.0.0.21"

# Email sent to confirm this script has started
$TimeStamp = Get-Date -Format g
$EmailSubject = "LEGAVBACK - Encoder Check Starting at $TimeStamp"
$Message = "The Encoder Check Powershell process has started on LEGAVBACK at $TimeStamp"
$SMTP = new-object Net.Mail.SmtpClient($SMTPServer)
$SMTP.Send($EmailFrom,$EmailTo,$EmailSubject,$Message)

# Loop forever
While ($true)
{
    foreach ($key in $Encoders.Keys) {
        if (Test-Connection $Encoders[$key] -Count 1 -Quiet) {
            try {
                $webclient = new-object System.Net.WebClient
                $credCache = new-object System.Net.CredentialCache
                $creds = new-object System.Net.NetworkCredential($BasicAuthUser,$BasicAuthPassword)
                $ip = $Encoders[$key]
                $URL = "http://$ip"
                $credCache.Add($URL, "Basic", $creds)
                $webclient.Credentials = $credCache
                $webpage = $webclient.DownloadString($URL)
                # If the webpage is reachable, find something known to exist in the webpage, eg. 'NVS-20'
                $title = $webpage.Contains("NVS-20")                
            }
            catch [exception] {                
                $TimeStamp = Get-Date -Format g
                $EmailSubject = "$key is down at $TimeStamp"
                $Message = "ERROR: can ping $key but web interface is down at $TimeStamp"                
                $SMTP = new-object Net.Mail.SmtpClient($SMTPServer)
                $SMTP.Send($EmailFrom,$EmailTo,$EmailSubject,$Message)
                write-host $Message
            }            
        } else {
            #write-host "- $key is down"
            $TimeStamp = Get-Date -Format g
            $EmailSubject = "$key is down at $TimeStamp"
            $Message = "ERROR: $key is down at $TimeStamp"            
            $SMTP = new-object Net.Mail.SmtpClient($SMTPServer)
            $SMTP.Send($EmailFrom,$EmailTo,$EmailSubject,$Message)
            write-host $Message
        }
    }

    # Check the streams in Wowza
    try {
        $secpasswd = ConvertTo-SecureString $BasicAuthPassword -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ($BasicAuthUser,$secpasswd)

        $webpage = Invoke-WebRequest -Uri $LiveStreamURL -Credential $cred
        $html = $webpage.ParsedHTML

        $wowzaarray = $html.getElementsByTagName('span') | ? { $_.className -eq 'streamTitle' } | % { $_.innerText }
        $hrarray = @("House","HR170","HR174","HR343","HR50","HRA","HRB","HRC","HRD","HRE","HRF","Senate")

        $result = Compare-Object -ReferenceObject $wowzaarray -DifferenceObject $hrarray -PassThru

        if ($result.Length -gt 0) {
            write-host "ERROR: The following streams are not available in Wowza: $($result)"
            $TimeStamp = Get-Date -Format g
            $EmailSubject = "Streams unavailable in Wowza LiveStreamRecord - $TimeStamp"
            $Message = "The following streams are not available in the Wowza LiveStreamRecord interface
            $result"            
            $SMTP = new-object Net.Mail.SmtpClient($SMTPServer)
            $SMTP.Send($EmailFrom,$EmailTo,$EmailSubject,$Message)            
        }
    }
    catch [exception] {
        # Could not connect to Wowza live stream list
        write-host "ERROR: Could not connect to Wowza Live Stream list"
        $TimeStamp = Get-Date -Format g
        $EmailSubject = "Wowza Live Stream listing is not accessible at $TimeStamp"
        $Message = "The Wowza Live Stream listing is not accessible at $TimeStamp"        
        $SMTP = new-object Net.Mail.SmtpClient($SMTPServer)
        $SMTP.Send($EmailFrom,$EmailTo,$EmailSubject,$Message)
    }

    # Sleep for 5 minutes
    Start-Sleep 300
}    
