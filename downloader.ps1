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

function Write-DonloadProgress {
    param (
        [int[]]$downloadTimes,
        [int]$totalFiles
    )

    $averageDownloadTime = ($downloadTimes | Measure-Object -Average).Average
    $remainingFiles = $totalFiles - $downloadTimes.Count
    $estimatedTimeRemaining = $remainingFiles * $averageDownloadTime

    $percentComplete = ($downloadTimes.Count / $totalFiles) * 100

    Write-Progress -Activity "Downloading files" -Status "Processing file $($downloadTimes.Count) of $totalFiles" -PercentComplete $percentComplete -SecondsRemaining $estimatedTimeRemaining
}

function Download-File {
    param (
        [string]$downloadLink,
        [string]$downloadDestination
    )
    $startTime = Get-Date
    Invoke-WebRequest -Uri $downloadLink -OutFile $downloadDestination | Out-Null
    write-host "Finishing $downloadLink"
    $endTime = Get-Date
    $downloadTime = ($endTime - $startTime).TotalSeconds
    return $downloadTime
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
    $maxJobs = 10
    $jobs = @()
    $i= 0
    foreach ($file in $files) 
    {
        $i++
        $filePath = $file.filePath
        $downloadLink = Join-Url $baseUrl $filePath
        $donloadDestination = Join-Path $scriptDirectory ($filePath -replace "updatefiles[\\\/]", "")
        $folderPath = Split-Path -Path $donloadDestination -Parent
        Ensure-FolderExists $folderPath
        write-host "starting job $i $downloadLink"
        # Start a new job
        $jobs += Start-Job -Name "downloader $i" -ScriptBlock {
            param ($downloadLink, $downloadDestination)
            Download-File -downloadLink $downloadLink -downloadDestination $downloadDestination
        } -ArgumentList $downloadLink, $downloadDestination

        # If we have reached the max number of jobs, wait for any job to complete
        while ($jobs.Count -ge $maxJobs) {
            $completedJob = Wait-Job -Any -Job $jobs
            $downloadTimes += Receive-Job -Job $completedJob
            Write-DonloadProgress $downloadTimes $totalFiles
            Remove-Job -Job $completedJob
            $jobs = $jobs | Where-Object { $_.Id -ne $completedJob.Id }
        }
    }

        # Wait for all remaining jobs to complete
        $jobs | ForEach-Object {
            $completedJob = Wait-Job -Job $_
            $downloadTimes += Receive-Job -Job $completedJob
            Write-DonloadProgress $downloadTimes $totalFiles
            Remove-Job -Job $completedJob
        }
    save-versionFile $curentVersion "$scriptDirectory\version.json"
}
else {
    write-host "Game is up to date"
}


Write-Host "Starting the game..."



# Start-Process -FilePath "$scriptDirectory\yo_cm_client.exe"

