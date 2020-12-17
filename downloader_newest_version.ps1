#Editor-Windows to front for "SendKeys"
#Get-Process | where-Object mainwindowtitle -like '*editor*' | % { $wshell.AppActivate($_.mainwindowtitle) }
#Get around "digital certified error"
#gc .\_downloader_newest_version.ps1 | clip;(New-Object -ComObject wscript.shell).SendKeys('^v{enter}')
#Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# TODO: to be implemented
$dest ="\\homeserver.local\data\install\"

function Install-Silent($file,$local=$false) {
$file = $file.replace('.\','');
if( $local ) { cp $file "$env:temp\"; $file = "$($env:temp)\$file";"$file" }
$a = (gc \\homeserver.local\deploy\bin\winpm-silent.lst)
$a | % { $b= $_.split(';'); if((ls $file).name -like $b[0] ) { "Installing $file $($b[1])...";Start-Process -wait "$file" -Args "$($b[1])" } }
if( $local ) { rm "$file"; "removing $file..." }
}

# Alle Uninstallstrings auslesen fÃ¼r $product und den ersten deinstallieren
function Uninstall-Silent($product,$justShow = $false) {
$regkey = 'HKLM:\software\wow6432node\microsoft\windows\currentversion\uninstall'
$a = (gci $regkey,$regkey.replace('wow6432node\','') | gp | where {$_.DisplayName -match $product } | Select -Property DisplayName, UninstallString)[0].uninstallstring
# Uninstallstring ggf. anpassen
if(($a -match 'msiexec') -and ($a -match '/I')) {$a=$a.replace('/I','/X')}
if(($a -match 'msiexec') -and ($a -notmatch '/qn')) {$a=$a+' /qn'}
if(($a -match 'uninstall.exe') -and ($a -notmatch '/S')) {$a=$a+' /S'}
if(!$justShow) {
	start-process -wait -WindowStyle hidden -filepath $a.split(' ')[0] -argumentlist $a.split(' ')[1..9]
} else {
	"Uninstall "+($a.split(' ')[0])
}
}

function Sync-new() {
ls *.zip,*.exe | % { if(-not (Test-Path "$($dest)\$($_.name)" )) { cp $_ "$($dest)\$($_.name )"; "Copy $($dest)\$($_.name)" } }
}

#https://vivaldi.com/de/download/
#'*.x64.exe'
#(New-Object System.Net.WebClient).DownloadFile($url, $output)
function GetNewVersion($srcurl, $search='', $urlprepand ='', $sort = '', $checkdate = $true, $showprogress = $false, $outname = '') {
    if(!$showprogress) {$ProgressPreference = 'SilentlyContinue'}
	if($search -ne '') {
    $a = (iwr $srcurl -usebasicparsing)
    if( $sort -eq "" ) {
        $url = $urlprepand + ($a.links | where-Object href -like $search | Select-Object -first 1).href
    } else {
        $url = $urlprepand + ($a.links | where-Object href -like $search | sort $sort | Select-Object -first 1).href
    }
    #$a.BaseResponse.ResponseUri
} else {
	$url = $srcurl
}
if(!$outname) {
	$filename = [System.IO.Path]::GetFileName($url)
} else {
	$filename = $outname
}

	$web = try { [System.Net.WebRequest]::Create("$url").GetResponse() } catch [Net.WebException] {}
	"$url last modified "+$web.LastModified

    if( !(Test-Path($filename)) ) {
    	"Downloading $url"
    	iwr $url -usebasicparsing -outfile $filename
	(gi $filename).lastwritetime = $web.LastModified
    } else {
	if( ($checkdate) -and (gi $filename).lastwritetime -ne $web.LastModified ) {
		"Downloading newer Version..."
	    	iwr $url -usebasicparsing -outfile $filename
		(gi $filename).lastwritetime = $web.LastModified
	} else {
	        "$filename already downloaded! Nothing to do."
	}
    }
" "
sleep(1)
}

#Java JRE Test
$url = (iwr "https://www.oracle.com/java/technologies/javase-jre8-downloads.html" -UseBasicParsing)
$res = ($url.Links.outerhtml -like '*jre-*windows-x64.exe*')
$dl = "https:"+((($res -split "data-file='")[1]).split("'"))[0]
#Offline x86 = 223735
#$realdl = "https://javadl.oracle.com/webapps/download/AutoDL?BundleId=243735_"+($dl.split('/')[-2])
#Offline x64 = 223737
$realdl = "https://javadl.oracle.com/webapps/download/AutoDL?BundleId=243737_"+($dl.split('/')[-2])
if( !(test-path $dl.split('/')[-1])) { iwr $realdl -outfile $dl.split('/')[-1] }

GetNewVersion 'https://vivaldi.com/de/download/' '*.x64.exe'
GetNewVersion 'https://github.com/ventoy/Ventoy/releases' '*ventoy-*-windows.zip' 'https://github.com/'
GetNewVersion 'http://www.drivesnapshot.de/de/idown.htm' '*snapshot64.exe'
GetNewVersion 'https://cemu.info/' '*cemu_*.zip'
GetNewVersion 'https://www.vlc.de/vlc_download_64bit.php' '*win64.exe' 'https:' -checkdate $false
GetNewVersion 'https://github.com/NickeManarin/ScreenToGif/releases' '*ScreenToGif.*.Portable.zip' 'https://github.com/'
GetNewVersion 'https://www.teamviewer.com/de/download/windows/' '*teamviewer_setup.exe*'
GetNewVersion 'https://store.steampowered.com/about/' '*SteamSetup.exe'
GetNewVersion "https://geekuninstaller.com/download" "*geek.7z" "https://geekuninstaller.com/"
GetNewVersion "https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html" "*/w64/putty.exe"

#NVidia
# 1080 + Win10 x64
(iwr 'https://www.nvidia.de/Download/processFind.aspx?psid=107&pfid=879&osid=57&lid=9&whql=&lang=de&ctk=0&dtcid=0' -usebasicparsing).content -match ".?([0-9]{3}\.[0-9]{2}).?"
$ver=$Matches[1]
GetNewVersion "http://de.download.nvidia.com/Windows/$ver/$ver-desktop-win10-64bit-international-whql.exe"

#adobeReader
#https://get.adobe.com/de/reader/completion/?installer=Reader_DC_2020.013.20064_German_for_Windows&stype=7775&direct=true&standalone=1
GetNewVersion "https://it-blogger.net/adobe-reader-offline-installer-fuer-windows-und-macos/" *AcroRdrDC*_de_DE.exe*

#GetNewVersion "https://www.irfanview.com/64bit.htm" "*www.irfanview.info/files/iview*g_x64.zip" -checkdate $false
GetNewVersion "https://www.irfanview.com/64bit.htm" "*www.irfanview.info/files/iview*g_x64_setup.exe" -checkdate $false
#GetNewVersion "https://www.fosshub.com/IrfanView.html" "*iview*_plugins_x64_setup.exe"

GetNewVersion "https://winrar.de/downld.php" "*winrar-x64-*d.exe*"

GetNewVersion "https://sourceforge.net/projects/imdisk-toolkit/" "*ImDiskTk-x64.*"

#https://cdn.gog.com/open/galaxy/client/setup_galaxy_2.0.16.187.exe?_ga=2.227079069.1679475251.1607416054-1189309446.1607416054
$url = ((iwr https://www.gog.com/galaxy -UseBasicParsing).links.href -like '*gog_galaxy_*.exe*')[-1]
$url -match '.?(GOG_Galaxy_[0-9]+\.[0-9]+.exe).?'
GetNewVersion $url -outname $Matches[1] -checkdate $false

GetNewVersion 'https://freefilesync.org/download.php' '*FreeFile*windows*.exe' 'https://freefilesync.org' -checkdate $false
#GetNewVersion 'https://www.thunderbird.net/en-US/thunderbird/all/' '*&amp;os=win64&amp;lang=de'
# no filename 
GetNewVersion 'https://7-zip.de/index.html' '*-x64.exe'
GetNewVersion 'https://7-zip.de/index.html' '*-x64.exe' '' 'desc' #get alpha - downloadlist in reversed order
#adobe reader ftp://ftp.adobe.com/pub/adobe/reader/win/
# vscode https://code.visualstudio.com/Download
GetNewVersion 'https://www.makemkv.com/download/' '*setup*.exe' 'https://www.makemkv.com'
# makemkv-code from forum: $code = (iwr 'https://www.makemkv.com/forum/viewtopic.php?f=5&t=1053' -useBasicParsing) | Select-String -pattern "<code>(.*)</code>" -AllMatches | %{$_.matches} | %{ ($_.value).replace('<code>','').replace('</code>','') }
GetNewVersion 'https://www.mp3tag.de/en/dodownload.html' '*mp3tag*setup.exe'

# Chitubox
$url = ((iwr https://www.chitubox.com/en/download/chitubox-free -UseBasicParsing).links.href -like '*.exe')[0]
GetNewVersion $url -outname $url.split('=')[-1] -checkdate $false

# Notepad++
$link = ((iwr "https://notepad-plus-plus.org/downloads/" -UseBasicParsing).links.href -like '*org/downloads/*')[0]
GetNewVersion $link '*x64.exe'

GetNewVersion 'https://www.softwareok.de/Download/Q-Dir_Portable_x64.zip'
#GetNewVersion 'https://www.softwareok.de/Download/QuickTextPaste_x64_Portable.zip'
#GetNewVersion 'https://www.softwareok.de/Download/DesktopNoteOK_x64_Portable.zip'
