# How to start

Start lab VM, run Windows terminal. Copy below and paste in the terminal.

```pwsh
# Sign in to Azure
az login

# Download and extract lab files
$url = "https://github.com/hiryamada/mslearn-postgresql/archive/refs/heads/main.zip"
$currentTime = (Get-Date).ToString("HHmmss")
$folder = "lab-$currentTime"
$zipPath = "$folder.zip"
(New-Object System.Net.WebClient).DownloadFile($url, $zipPath)
Expand-Archive -LiteralPath $zipPath

# change current directory to lab folder
cd $folder/mslearn-postgresql-main
```

Ok, type the command below to start labs (NN will be from 12 to 19 in this course, but currently only 12 and 13 is available)

```pwsh
pwsh labNN.ps1
```
