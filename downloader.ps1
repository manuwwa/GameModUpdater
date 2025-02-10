<#
.SYNOPSIS
This script downloads files from a specified URL and checks for new versions.

.DESCRIPTION
The script checks for new versions of files from a specified URL, downloads them if a new version is found, and saves the version information. It also displays a progress bar during the download process.

.LICENSE
Copyleft - https://www.gnu.org/licenses/copyleft.html

.AUTHOR
manuwwa
GitHub: https://github.com/manuwwa
#>

#configuration
$baseUrl = "https://feudalxxl.eu"

# end of configuration


#region Functions

function Join-Url {
    param (
        [string]$BaseUrl,
        [string]$Path
    )
    $BaseUrl.TrimEnd('/') + '/' + $Path.TrimStart('/')
}

function Ensure-FolderExists {
    param (
        [string]$folderPath
    )
    
    if (-Not (Test-Path -Path $folderPath -PathType Container)) {
        New-Item -Path $folderPath -ItemType Directory -Force
    }
}

function save-versionFile {
    param (
        [string]$checksum,
        [string]$filePath
    )

    $versionFile = @{
        checksum = $checksum
    } | ConvertTo-Json

    $versionFile | Set-Content -Path $filePath
}

function Isnew-Version {
    param (
        [string]$checksum,
        [string]$filePath
    )

    if (-Not (Test-Path -Path $filePath -PathType Leaf)) {
        
        return $true
    }

    $fileContent = Get-Content -Path $filePath -Raw | ConvertFrom-Json
    if ($fileContent.checksum -eq $checksum) {
        return $false
    } else {
        return $true
    }
}

#endregion Functions

Write-Host @'

                                   ]=I==II==I=[
                                    \\__||__//                 ]=I==II==I=[
               ]=I==II==I=[          |.. ` *|                   \\__||__//
                \\__||__//           |. /\ #|                    |-_ []#|
                 | []   |            |  ## *|                    |      |
                 |    ..|            | . , #|                  ]=I==II==I=[
 ___   ____  ___ |   .. |         __ |..__.*| __                \\__||__//
 ] I---I  I--I [ |..    |        |  ||_|  |_|| |                 |    _*|
 ]_____________[ | .. []|         \--\-|-|--/-//                 |   _ #|
  \_\| |_| |/_/  |_   _ | _   _   _|      ' *|                   |`    *|
   |  .     |'-'-` '-` '-` '-` '-` | []     #|-|--|-_-_-_-_ _ _ _|_'   #|
   |     '  |=-=-=-=-=-=-=-=-=-=-=-|      []*|-----________` ` `   ]   *|
   |  ` ` []|      _-_-_-_-_  '    |-       #|      ,    ' ```````['  _#|
   | '  `  '|   [] | | | | |  []`  |  []    *|   `          . `   |'  I*|
   |      - |    ` | | | | | `     | ;  '   #|     .  |        '  |    #|
  /_'_-_-___-\__,__|_|_|_|_|_______|   `  , *|    _______+___,__,-/._.._.\
              _,--'    __,-'      /,_,_v_Y_,_v\\-'
         _____              _       ___  ____  ___                 
        |  ___|__ _   _  __| | __ _| \ \/ /\ \/ / |      ___ _   _ 
        | |_ / _ \ | | |/ _` |/ _` | |\  /  \  /| |     / _ \ | | |
        |  _|  __/ |_| | (_| | (_| | |/  \  /  \| |___ |  __/ |_| |
        |_|  \___|\__,_|\__,_|\__,_|_/_/\_\/_/\_\_____(_)___|\__,_|
                                                                    
'@

$scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

$response = Invoke-RestMethod https://feudalxxl.eu/update_list.php

$curentVersion = $response.checksum 

$isNewVersion = Isnew-Version $curentVersion "$scriptDirectory\version.json"

if ($isNewVersion) {
    write-host "New version found downloading files..."
    $files = $response.files

    $totalFiles = $files.Count
    $downloadTimes = @()

    for ($i = 0; $i -lt $totalFiles; $i++) 
    {
        $startTime = Get-Date
        $file = $files[$i]
        $filePath = $file.filePath
        $downloadLink = Join-Url $baseUrl $filePath
        $donloadDestination = Join-Path $scriptDirectory ($filePath -replace "updatefiles[\\\/]", "")
        $folderPath = Split-Path -Path $donloadDestination -Parent
        Ensure-FolderExists $folderPath  
        Invoke-WebRequest -Uri $downloadLink -OutFile $donloadDestination | Out-Null

        # Create a progress bar
        $endTime = Get-Date

        $downloadTime = ($endTime - $startTime).TotalSeconds
        $downloadTimes += $downloadTime

        $averageDownloadTime = ($downloadTimes | Measure-Object -Average).Average
        $remainingFiles = $totalFiles - ($i + 1)
        $estimatedTimeRemaining = $remainingFiles * $averageDownloadTime

        $percentComplete = (($i + 1) / $totalFiles) * 100

        Write-Progress -Activity "Downloading files" -Status "Processing file $($i + 1) of $totalFiles" -PercentComplete $percentComplete -SecondsRemaining $estimatedTimeRemaining
        # End progress bar
    }
    save-versionFile $curentVersion "$scriptDirectory\version.json"
}
else {
    write-host "Game is up to date"
}


Write-Host "Starting the game..."



# Start-Process -FilePath "$scriptDirectory\yo_cm_client.exe"

