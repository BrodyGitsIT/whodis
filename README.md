# whodis
Whodis is a Cross Platform PowerShell 7 cmdlet/function for a quick short &amp; sweet whois lookup. You can pass single IPs, DNS names, variables or comma seperated lists / array variables! I added this to my $profile so its always ready for me. Use the one-liner below to get set up like me!

# One-Liner Setup!
This adds the function to your $profile so its always loaded in your shell. I reccomended running on your admin and non-admin account
```
iwr https://raw.githubusercontent.com/BrodyGetsIT/whodis/main/whodis.ps1 -UseBasicParsing | iex; iwr https://raw.githubusercontent.com/BrodyGetsIT/whodis/main/whodis.ps1 -UseBasicParsing | Out-File -Append $PROFILE
```
