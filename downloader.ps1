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
$maxJobs = 5

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
        New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
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
    
    [System.Collections.Generic.List[string]]$urls = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]]$destinations = [System.Collections.Generic.List[string]]::new()
    foreach ($file in $files) {
        $filePath = $file.filePath
        $downloadLink = Join-Url $baseUrl $filePath
        $downloadDestination = Join-Path $scriptDirectory ($filePath -replace "updatefiles[\\\/]", "")
        $folderPath = Split-Path -Path $downloadDestination -Parent
        Ensure-FolderExists $folderPath

        $urls.Add($downloadLink)
        $destinations.Add($downloadDestination)
    }

    $downloadJob = Start-Job -ScriptBlock {
        param([System.Collections.Generic.List[string]]$urls, [System.Collections.Generic.List[string]]$destinations, $maxJobs)
        Add-Type -TypeDefinition @"
        using System;
        using System.Collections.Generic;
        using System.Net;
        using System.Threading.Tasks;

        public class Downloader
        {
            public static void DownloadFiles(List<string> urls, List<string> destinations, int maxDegreeOfParallelism)
            {
                try
                {
                    Parallel.ForEach(urls, new ParallelOptions { MaxDegreeOfParallelism = maxDegreeOfParallelism }, (url, state, index) =>
                    {
                        using (WebClient client = new WebClient())
                        {
                            client.DownloadFile(url, destinations[(int)index]);
                        }
                    });
                }
                catch (Exception ex)
                {
                    Console.WriteLine("An error occurred: " + ex.Message);
                    throw;
                }
            }
        }
"@
    [Downloader]::DownloadFiles($urls, $destinations, $maxJobs)
    } -ArgumentList $urls, $destinations, $maxJobs

    write-host "Downloading files. It could take up to 30 minutes!"
    write-host "Meanwhile, visit our site: https://feudalxxl.eu"
    write-host ""

    $s=' '*80+"Please wait!"+' '*80;
    while ($downloadJob.State -eq 'Running')
    {write-host($s.Substring(($i=++$i%($s.length-80)),80)+"`r")-N -F R -B 0;sleep -m 99}

    Receive-Job $downloadJob
    Remove-Job $downloadJob

    save-versionFile $curentVersion "$scriptDirectory\version.json"
}
else {
    write-host "Game is up to date"
}
write-host ""
write-host "Victory will be ours!"
write-host @"
  |
  |
  + \
  \\.G_.*=.
   `(#'/.\|
    .>' (_--.
 _=/d   ,^\
~~ \)-'   '
   / |   
  '  '
"@

Write-Host "Starting the game..."

Start-Sleep -Seconds 4


Start-Process -FilePath "$scriptDirectory\yo_cm_client.exe"

