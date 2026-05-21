# whodis
Whodis is a cross-platform PowerShell 7 cmdlet/function for a quick short &amp; sweet whois lookup. 

It supports:
- Single IPs
- Hostnames (auto-resolved)
- Variables
- Comma-separated lists / arrays

I added this to my `$PROFILE` so it's always ready to go. Use the one-liner below to do the same.

---

## How It Works

**Step 0:**  
You call `whodis` with `$targets` (IPs, domains, or arrays).  
Everything gets normalized into a list of IPs before querying ARIN.

**Step 1:**  
Detect whether each input is an IPv4, IPv6, or hostname using regex.

**Step 2:**  
Resolve hostnames to IPs in a cross-platform friendly manner using:
```powershell
[System.Net.Dns]::GetHostAddresses($t)
```

**Step 3:**
De-duplicate the resulting IP list and loop through each target.

**Step 4:**
Query ARIN's REST API for WHOIS data.
Failures are retried up to 3 times before displaying an error to the user and logging to $fails to display at the end of the full loop.

# Usage
```powershell
whodis google.com,1.1.1.1,9.9.9.9,bing.com
whodis google.com
whodis 1.1.1.1
whodis @("google.com","1.1.1.1")
```

# One-Liner Setup! (PowerShell 7)
This adds the function to your $profile so its always loaded in your shell. I recommend running this on all accounts you want to use it on.

```powershell
$t = iwr -UseBasicParsing https://raw.githubusercontent.com/BrodyGitsIT/whodis/main/whodis.ps1; "`r`n`r`n$($t.Content)" | Out-File -Append -Encoding utf8NoBOM $PROFILE; . $PROFILE
```
