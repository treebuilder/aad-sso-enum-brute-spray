                $requestId = (New-Guid).ToString()

                $user = $Args[0]
$domain = $user.Split("@")[1]
                $password = $Args[1]

                $now = Get-Date
                $created = $now.toUniversalTime().toString("o")
                $expires = $now.addMinutes(10).toUniversalTime().toString("o")

               $url = "https://autologon.microsoftazuread-sso.com/$domain/winauth/trust/2005/usernamemixed?client-request-id=$requestid"
              
                $body=@"
<?xml version='1.0' encoding='UTF-8'?>
<s:Envelope xmlns:s='http://www.w3.org/2003/05/soap-envelope' xmlns:wsse='http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd' xmlns:saml='urn:oasis:names:tc:SAML:1.0:assertion' xmlns:wsp='http://schemas.xmlsoap.org/ws/2004/09/policy' xmlns:wsu='http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd' xmlns:wsa='http://www.w3.org/2005/08/addressing' xmlns:wssc='http://schemas.xmlsoap.org/ws/2005/02/sc' xmlns:wst='http://schemas.xmlsoap.org/ws/2005/02/trust' xmlns:ic='http://schemas.xmlsoap.org/ws/2005/05/identity'>
    <s:Header>
        <wsa:Action s:mustUnderstand='1'>http://schemas.xmlsoap.org/ws/2005/02/trust/RST/Issue</wsa:Action>
        <wsa:To s:mustUnderstand='1'>$url</wsa:To>
        <wsa:MessageID>urn:uuid:$((New-Guid).ToString())</wsa:MessageID>
        <wsse:Security s:mustUnderstand="1">
            <wsu:Timestamp wsu:Id="_0">
                <wsu:Created>$created</wsu:Created>
                <wsu:Expires>$expires</wsu:Expires>
            </wsu:Timestamp>
            <wsse:UsernameToken wsu:Id="uuid-$((New-Guid).toString())">
                <wsse:Username>$User</wsse:Username>
                <wsse:Password>$Password</wsse:Password>
            </wsse:UsernameToken>
        </wsse:Security>
    </s:Header>
    <s:Body>
        <wst:RequestSecurityToken Id='RST0'>
            <wst:RequestType>http://schemas.xmlsoap.org/ws/2005/02/trust/Issue</wst:RequestType>
                <wsp:AppliesTo>
                    <wsa:EndpointReference>
                        <wsa:Address>urn:federation:MicrosoftOnline</wsa:Address>
                    </wsa:EndpointReference>
                </wsp:AppliesTo>
                <wst:KeyType>http://schemas.xmlsoap.org/ws/2005/05/identity/NoProofKey</wst:KeyType>
        </wst:RequestSecurityToken>
    </s:Body>
</s:Envelope>
"@
                $exists = $false

                try
                {
                    $response = Invoke-RestMethod -UseBasicParsing -Uri $url -Method Post -Body $body -ErrorAction SilentlyContinue
                    $exists = $true # Very bad password
                }
                catch
                {
                    $stream = $_.Exception.Response.GetResponseStream()
                    $responseBytes = New-Object byte[] $stream.Length

                    $stream.Position = 0
                    $stream.Read($responseBytes,0,$stream.Length) | Out-Null
            
                    $responseXml = [xml][text.encoding]::UTF8.GetString($responseBytes)

                    $errorDetails = $responseXml.Envelope.Body.Fault.Detail.error.internalerror.text
                }

            # Parse the error code. Only AADSTS50034 would need to be checked but good to know other errors too.
            if(!$exists -and $errorDetails)
            {
                if($errorDetails.startsWith("AADSTS50053")) # The account is locked, you've tried to sign in too many times with an incorrect user ID or password.
                {
                    $exists = "locked"
                }
                elseif($errorDetails.StartsWith("AADSTS50126")) # Error validating credentials due to invalid username or password.
                {
                    $exists = "bad password"
                }
                elseif($errorDetails.StartsWith("AADSTS50056")) 
                {
                    $exists = "exists w/no password"
                }
                elseif($errorDetails.StartsWith("AADSTS50014")) 
                {
                    $exists = "exists, but max passthru auth time exceeded"
                }
                elseif($errorDetails.StartsWith("AADSTS50076")) # Due to a configuration change made by your administrator, or because you moved to a new location, you must use multi-factor authentication to access '{resource}'
                {
                    $exists = "need mfa"
                }
                elseif($errorDetails.StartsWith("AADSTS700016")) # Application with identifier '{appIdentifier}' was not found in the directory '{tenantName}'. This can happen if the application has not been installed by the administrator of the tenant or consented to by any user in the tenant. You may have sent your authentication request to the wrong tenant.
                {
                    $exists = "no app"
                }
                elseif($errorDetails.StartsWith("AADSTS50034")) # The user account {identifier} does not exist in the {tenant} directory. To sign into this application, the account must be added to the directory.
                {
                    $exists = "no user"
                }
                else
                {
                    Remove-Variable exists
                }
            }

        return $user+"		"+$exists
        return $errorDetails

