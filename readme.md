# PostgreSQL Exercises

This repository contains the instructions and files to support PostgreSQL exercises in [Microsoft Learn](https://learn.microsoft.com) modules.

# How to start

Start lab, run Windows terminal, and run this in it:

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

OK! Type the command below to start labs (NN is 12 to 19)

```pwsh
pwsh labNN.ps1
```
