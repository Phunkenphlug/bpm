#Set-Executionpolicy -Scope CurrentUser -ExecutionPolicy UnRestricted -Force;. .\_downloader_newest_version.ps1
#Editor-Windows to front for "SendKeys"
#Get-Process | where-Object mainwindowtitle -like '*edge*' | % { (New-Object -ComObject wscript.shell).AppActivate($_.mainwindowtitle) }
#Get around "digital certified error"
#Add-Type -AssemblyName System.Windows.Forms;[System.Windows.Forms.SendKeys]::SendWait("^v")
#Start wirh Admin: start powershell -verb runas -ArgumentList "-nop -noexit -c cd \\homeserver\usbtemp\_newapps_;gc _down*.*|clip;(New-Object -ComObject wscript.shell).SendKeys('^v{enter}')"
#gc .\_downloader_newest_version.ps1 | clip;(New-Object -ComObject wscript.shell).SendKeys('^v{enter}')
# also see https://gist.github.com/VonC/5995144

#foreach($a in 0..100) {Write-Host -nonewline "`rUpdating  $a%... ";start-sleep -Milliseconds 200}

# TODO: to implement
$dest ="\\homeserver.local\data\install\"
$silentSwitches = "\\homeserver.local\deploy\bin\winpm-silent.lst"

function do-reload {
gc .\_downloader_newest_version.ps1 | clip;(New-Object -ComObject wscript.shell).SendKeys('^v{enter}')
}

function Install-Silent($files,[switch]$local,[switch]$edit) {
if( $edit ) {notepad $silentSwitches; break}
foreach($file in $files) {
	if( !(test-path $file)) {
		$file = (ls "$file*"|sort LastWriteTime -desc).name
		if( $file.count -ne 1 ) { $file = $file[0] }
	}

	$doSilent=$false
	$file = $file.replace('.\','');
	if( $local ) { cp $file "$env:temp\"; $file = "$($env:temp)\"+$file.split('\')[-1];"Copying to $file" }
	(gc $silentSwitches) | % { $b= $_.split(';'); if((ls $file).name -like $b[0]) { "Installing $file $($b[1])...";Start-Process -wait "$file" -Args "$($b[1])";$doSilent=$true; }}
	if( !$doSilent) { "No Silent option found!";Start-Process -wait "$file"}
	if( $local ) { rm "$file"; "removing $file..." }
}
}

# Alle Uninstallstrings auslesen fÃ¼r $product und den ersten deinstallieren
function Uninstall-Silent($product,[switch]$whatif) {
$regkey = 'HKLM:\software\wow6432node\microsoft\windows\currentversion\uninstall'
$a = (gci $regkey,$regkey.replace('wow6432node\','') | gp | where {$_.DisplayName -match $product } | Select -Property DisplayName, UninstallString)[0].uninstallstring
# Uninstallstring ggf. anpassen
$ext = '.exe';
if( $a.indexof('"') -eq -1) { $a = '"'+$a.Substring(0,$a.IndexOf($ext))+$ext+'"'+$a.Substring($a.IndexOf($ext)+$ext.length) }

if(($a -match 'msiexec') -and ($a -match '/I')) {$a=$a.replace('/I','/X')}
if(($a -match 'msiexec') -and ($a -notmatch '/qn')) {$a=$a+' /qn'}
if(($a -match "\\uninstall.exe") -and ($a -notmatch '/S')) {$a=$a+' /S'}
if(($a -match "\\iv_uninstall.exe") -and ($a -notmatch '/silent')) {$a=$a+' /silent'}
if(($a -match 'unins0*.exe') -and ($a -notmatch '/S')) {$a=$a+' /S'}
if(!$whatif) {
	start-process -wait -WindowStyle hidden -filepath $a.split('"')[1] -argumentlist $a.split('"')[2].trim().split(' ')
} else {
	"Uninstall $a"
}
}

function List-Functions {
	(gc $MyInvocation.MyCommand) -like '*function*'|% { $_.replace('function ','').split('(')[0].split('{')[0].Trim() }
}

function Get-InstalledVersion($pattern='',$prop="DisplayVersion") {
	$e=((gci HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\,HKLM:\SOFTWARE\wow6432node\Microsoft\Windows\CurrentVersion\Uninstall\) | gp | ? displayname -match $pattern);
	if( ($prop -eq '*') -or ($prop -eq '') ) { return $e } else { return $e."$prop" };
}

function Sync-new($pattern="*.zip,*.exe,*.7z") {
<#
        .SYNOPSIS
        Syncs files from this directory with directory stored in $dest.

        .DESCRIPTION
        Checks ether if file is present in $dest or timestamp of lastwrittentime is newer than of $dest and copies those files

        .EXAMPLE
        PS> Sync-New 
        Copy file dummy.exe

        .EXAMPLE
        PS> extension -name "File" -extension "doc"
        File.doc

        .EXAMPLE
        PS> extension "File" "doc"
        File.doc
    #>
$list = ls *.zip,*.exe,*.7z
$list | % {$c=0}{
	$c++;
	$p=$c/$list.length*100;
	write-host -nonewline "`r"$p.tostring('#')"% "$_.name
	if(-not (Test-Path "$($dest)$($_.name)" )) {
		write-host " copy to $($dest)$($_.name)"
		cp $_ "$($dest)$($_.name )";
	};
	$r=(ls "$($dest)$($_.name)");
		if( !($_.LastWriteTime -eq $r.lastwritetime)) {
		write-host " copy to $($dest)$($_.name)"
		cp $_ "$($dest)$($_.name )";
		}
	}
}

#function Get-LastModifiedFromUrl($url) {
#	$web = try { [System.Net.WebReque#st]::Create("$url").GetResponse() } catch [Net.WebException] {}
#	return $web.LastModified
#}

function Get-Link($url, $pattern, $resultitem=0,[switch]$dotrim) {
	$base = (iwr -useb $url)
	$link = $base.links.href -like $pattern
	if($link.count -gt 0) { $link = $link[$resultitem]}
	if( ($link.StartsWith('..')) ) { return $url.replace($url.split('/')[-1],'')+$link }
	if( ($link.StartsWith('//')) ) { return $url.split('/')[0]+$link;break; }
	if( ($link.StartsWith('/')) ) { return ($url.split('/')[0..2] -join '/')+$link;break; }
	if( ($link.StartsWith('https') -or $link.StartsWith('http')) ) { return $link;break; }
	# $url = $url.replace($url.split('/')[-1],'')
	$r = $url + $link
	#if( $dotrim) {$r = "dotrim "+$base.baseresponse.ResponseUri.AbsoluteUri.replace($base.baseresponse.ResponseUri.AbsolutePath,'')+"/$link"}
	if( $dotrim) {$r = ($base.baseresponse.ResponseUri.AbsoluteUri).split('?')[0].replace($base.baseresponse.ResponseUri.AbsolutePath,'')+"/$link"}
	return $r
}

function Set-Lastwrite($file, $date) {
	(gci $file).lastwritetime = $date
}

function Get-FileFromUrl( $url ) {
	# TODO
	#$a = iwr -UseBasicParsing $url -Method Head
	#if( $a.Headers['content-type'] -eq "application/octet-stream" ) { $filename = $a.Headers['content-disposition'].split('"')[1] } else { $filename = $url.split('/')[-1] }

	$filename = $url.split('/')[-1]
	# iwr -usebasicparsing $url -outfile $filename
	wget.exe $url -O $filename
	return $filename
}

function Get-RedirectedUrl {

    Param (
        [Parameter(Mandatory=$true)]
        [String]$URL
    )

    $request = [System.Net.WebRequest]::Create($url)
    $request.AllowAutoRedirect=$false
    $response=$request.GetResponse()

    If ($response.StatusCode -eq "Found")
    {
        $response.GetResponseHeader("Location")
    }
    $response.close
}

#{$_ -in 'A','B','C'} {}
#Import-Module BitsTransfer
function start-download($url, $file, $type=0) {
	switch ($type) {
		0 {
			invoke-webrequest -usebasicparsing $url -outfile $file
		}

		1 {
			(new-object System.Net.WebClient).DownloadFile($url,$file)
		}
		2 {
			Start-BitsTransfer -Source $url -Destination $file
		}
		3 {
			aria2c.exe $url -o $file
		}
		4 {
			wget.exe $url -O $file
		}
	}
}



function Comp-Strings-ld {
	param([string] $first, [string] $second, [switch] $ignoreCase)

	$len1 = $first.length
	$len2 = $second.length

	if($len1 -eq 0)
	{ return $len2 }

	if($len2 -eq 0)
	{ return $len1 }

	if($ignoreCase -eq $true)
	{
	$first = $first.tolowerinvariant()
	$second = $second.tolowerinvariant()
	}

	$dist = new-object -type 'int[,]' -arg ($len1+1),($len2+1)

	for($i = 0; $i -le $len1; $i++) 
	{  $dist[$i,0] = $i }
	for($j = 0; $j -le $len2; $j++) 
	{  $dist[0,$j] = $j }

	$cost = 0

	for($i = 1; $i -le $len1;$i++)
	{
	for($j = 1; $j -le $len2;$j++)
	{
		if($second[$j-1] -ceq $first[$i-1])
		{
		$cost = 0
		}
		else   
		{
		$cost = 1
		}
		
		$tempmin = [System.Math]::Min(([int]$dist[($i-1),$j]+1) , ([int]$dist[$i,($j-1)]+1))
		$dist[$i,$j] = [System.Math]::Min($tempmin, ([int]$dist[($i-1),($j-1)] + $cost))
	}
	}
	return $dist[$len1, $len2];
}

function GetNewVersion($srcurl, $search='', $urlprepand ='', $sort = '', $checkdate = $true, [switch] $showprogress=$false, $outname = '',[switch] $whatif=$false,$outfilesplit='/',[switch] $redirected) {
	$progressPreference = 'Continue'
	if(!$showprogress) {$ProgressPreference = 'SilentlyContinue'}
	#if($redirected) { $_srcurl = Get-RedirectedUrl($srcurl);if($_srcurl -ne $null) { $srcurl = $_srcurl}}
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

	if($redirected) {
		$url = Get-RedirectedUrl($url)
	}

	# fix "no-host" in Download URL
	if( $url[0] -eq '/') {
		$url = ($srcurl.split('/')[0..2] -join '/') + $url
	}

	if(!$outname) {
	
		#$web.headers.get('content-description') -eq 'File Transfer'
		$filename = [System.IO.Path]::GetFileName($url)
		$split = $filename.split( $outfilesplit );
		if( $split.count -gt 1 ) {
			$filename = $split[-1]
		}
	
		# If Content-type = Download ;-)
		$web = try { [System.Net.WebRequest]::Create("$url").GetResponse() } catch [Net.WebException] {}
		if($web.Headers.get('content-disposition') -match ',?filename="(.*)".?') {
			$filename = $Matches[1] 
		}
	
	} else {
		$filename = $outname
	}	

	$web = try { [System.Net.WebRequest]::Create("$url").GetResponse() } catch [Net.WebException] {}
	"$url last modified "+$web.LastModified

	if( $whatif ) {
		"Downloading from $url and save as $filename"
	} else {

		if( !(Test-Path($filename)) ) {
			"Downloading from $url ($filename)"
			iwr $url -usebasicparsing -outfile $filename
			# wget.exe "$url" -O "$filename"
			(gi $filename).lastwritetime = $web.LastModified
		} else {
			if( ($checkdate) -and (gi $filename).lastwritetime -ne $web.LastModified ) {
				"Downloading newer Version from $url ($filename)..."
				iwr $url -usebasicparsing -outfile $filename
				# wget.exe "$url" -O "$filename"
				(gi $filename).lastwritetime = $web.LastModified
			} else {
				"$filename already downloaded! Nothing to do."
			}
		}
    }

	" "
	sleep(1)
	if(!$showprogress) { $progressPreference = 'Continue' }
}
function WriteYellow($text) {
	Write-Host -ForegroundColor Yellow "$text"
}
function Clean-AllKnown {
@("Every*setup.exe","Krita*","vlc*","Inkscape*","obs-studio*","npp*","freefile*","Tlaunch*","setup_makemkv*","ocen*","screentogif*","Ventoy*","powertoy*","vscode*","winrar*","viva*","thunderbird*","shotcut*","rpc*","acordr*.exe","*-international-whql.exe","audacity-*","cemu_*.zip","crystaldisk*.exe","firefox*","filezilla*","freefilesync*","mp3tag*") | % { clean-old $_ -confirm}
}

function Clean-Old($pattern,[switch]$confirm,$keep=1) {
		$files=ls $pattern|sort LastWriteTime -desc|select -skip $keep
		if($confirm){
			if($files.count -gt 0) { $files|rm;"Removing $files..." }
		} else {
			$files
		}
}
function Get-NewVersion( $url, $patterns=$NULL,$filenamematch=$NULL,[switch]$nodatecheck,  [switch]$nofilename,  [switch]$nocertcheck, [switch]$nodownload ) {
	$ProgressPreference = 'SilentlyContinue'
	$outputfilename = $NULL
	$option = "-N --no-hsts"
	$option2 = ""
	if(!($nofilename)) { $option2 = ""+$option2+"--content-disposition" }
	if($nocertcheck) { $option2 = ""+$option2+" --no-check-certificate" }
	if($nodatecheck) { $option = "-nc" }
	if( $patterns.count -gt 0 ) {
		foreach( $pat in $patterns) { if($pat.split('|') -gt 1) {$patsingle,$num=$pat.split('|');$url = get-link $url $patsingle $num} else {$url = get-link $url $pat} }
	}
	if($nodownload) { return $url.tostring();break;}

	if(!($filenamematch -eq $NULL)) { if($url -match $filenamematch) {$outputfilename = "-O'"+$Matches[1]+"'"} }
	iex ".\wget.exe -nv --show-progress --progress=bar:force:noscroll $option $option2 ""$url"" $outputfilename"
	#.\wget.exe --progress=bar:force:noscroll $option $option2 $url
	# Set-Lastwrite (Get-FileFromUrl $url) (Get-lastmodifiedfromUrl $url)
}

"Start downloads via 'Do-Downloads'"
"Check for doubles via 'Check-Doubles'"

function Check-Doubles($pattern = '*.*') {
	$a = (ls $pattern).name
	foreach($name1 in $a) {
		foreach($name2 in $a) {
			if( !($name -eq $name2) ) {
				$d= (Comp-Strings-ld $name1 $name2);
				if( $d-lt 7 -and $d -gt 0) {""+$d+" "+$name1+" "+$name2 }
			}
	 }
	}
}

function Get-LastModifiedUrl( $url ) {
	$a = iwr -method head $url
	return $a.headers.'Last-Modified'
}

function Do-Downloads {


WriteYellow "wget"
$wget = Get-NewVersion "https://eternallybored.org/misc/wget/" "*/64/wget.exe" -nodownload
$wgetlast = Get-LastModifiedUrl $wget
if (!((ls .\wget.exe).LastWriteTime -eq $wgetlast)) { iwr -UseBasicParsing $wget -outfile "wget.exe";Set-Lastwrite '.\wget.exe' $wgetlast }

WriteYellow "Java JRE Test"
$a = iwr "https://www.oracle.com/de/java/technologies/javase-jre8-downloads.html" -UseBasicParsing
$b = ($a.Links.outerHTML -like '*x64.exe*').split("'")
$url = $b[$b.IndexOf(' data-file=')+1].replace('/otn/','/otn-pub/')
.\wget.exe -c --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" $url

$b = ($a.Links.outerHTML -like '*i586.exe*').split("'")
$url = $b[$b.IndexOf(' data-file=')+1].replace('/otn/','/otn-pub/')
.\wget.exe -c --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" $url

WriteYellow "aria2"
Get-NewVersion "http://aria2.github.io" @('*aria2/aria2/releases*',"*win-64bit*.zip") -nofilename

WriteYellow "UPX"
Get-NewVersion https://upx.github.io/main/2016/09/01/moving-to-github.html @('*/upx/upx/releases/latest*','*win64.zip') -nofilename

WriteYellow "VLC"
Get-NewVersion "http://www.videolan.org/vlc/" @('*win64*','*win64*')

WriteYellow "ScreenToGif"
Get-NewVersion 'https://github.com/NickeManarin/ScreenToGif/releases' '*ScreenToGif.*.Portable.zip'  -nofilename

WriteYellow "Vivaldi Browser"
Get-NewVersion 'https://vivaldi.com/de/download/' '*x64.exe'
WriteYellow "Ventoy"
Get-NewVersion 'https://github.com/ventoy/Ventoy/releases' '*ventoy-*-windows.zip' -nofilename
WriteYellow "Drive Snapshot"
Get-NewVersion 'http://www.drivesnapshot.de/de/idown.htm' '*snapshot64.exe'

# CEMU
# Get used Version: $ver = (ls d:\*cemu* | % { (get-command "$($_.fullname)\cemu.exe").version.tostring() })
# Update: $cemupath="d:\cemu";ls cemu_*.zip | cp -Destination $env:temp; ls "$($env:temp)\cemu_*.zip" | select -last 1| % { 7z rn $_.fullname ($_.name).replace('.zip','\') '\'; 7z x -y $_.fullname -O"$Cemupath";rm $_.fullname }
WriteYellow "CEMU - WiiU Emulator"
Get-NewVersion 'https://cemu.info/' '*cemu_*.zip'
WriteYellow "Yuzu - Switch Emulator"
Get-NewVersion 'https://yuzu-emu.org/downloads/' '*yuzu_install.exe' -nofilename
WriteYellow "RPCS3 - PS3-Emulator"
Get-NewVersion 'https://rpcs3.net/download' '*win64.7z' -nofilename

WriteYellow "MSI Afterburner"
Get-NewVersion -nocertcheck "https://www.filehorse.com/download-msi-afterburner/" @('*download/','*download/file*')

WriteYellow "TeamViewer"
Get-NewVersion 'https://www.teamviewer.com/de/download/windows/' '*teamviewer_setup.exe*'
WriteYellow "Steam Client"
Get-NewVersion 'https://store.steampowered.com/about/' '*SteamSetup.exe'
WriteYellow "Geek Uninstaller"
Get-NewVersion "https://geekuninstaller.com/download" "*geek.7z"
WriteYellow "Putty"
Get-NewVersion "https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html" "*/w64/putty.exe"
WriteYellow "Kitty"
Get-NewVersion "http://www.9bis.net/kitty/files/kitty_portable.exe"

WriteYellow "KeePass"
Get-newversion "https://keepass.info/download.html" '*setup.exe*'
WriteYellow "Cmder"
Get-NewVersion 'https://github.com/cmderdev/cmder/releases/' '*cmder_mini.zip*' -nofilename

WriteYellow "Microsoft PowerToys"
Get-NewVersion 'https://github.com/microsoft/PowerToys/releases/' '*-x64.exe*' -nofilename

WriteYellow "Everything Search"
Get-NewVersion "https://www.voidtools.com/downloads/" "*x64-setup.exe"

WriteYellow "Sumatra PDF"
Get-NewVersion "https://www.sumatrapdfreader.org/download-free-pdf-viewer" "*64-install.exe" -nodatecheck

WriteYellow "Arduino IDE"
Get-NewVersion "https://www.arduino.cc/en/software/" "*.exe"

WriteYellow "Reshade"
Get-NewVersion "https://reshade.me" '*.exe'

WriteYellow "Ocen Audio Editor"
Get-NewVersion "https://www.ocenaudio.com/downloads/ocenaudio64.exe" -nodatecheck

WriteYellow "Audacity"
#GetNewVersion "https://www.fosshub.com/Audacity.html?dwl=audacity-win-2.4.2.exe" -outfilesplit "="
get-newversion "https://www.audacityteam.org/download/windows/" "*.exe"

WriteYellow "MiniTool Partition"
# https://cdn2.minitool.com/?p=pw&e=pw-free
Get-NewVersion "https://cdn2.minitool.com/?p=pw&e=pw-free-offline" -nodatecheck

WriteYellow "NVidia GFX Drivers"
# installed version: $ver = ((gci HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\) | gp | ? displayname -like '*nvidia grafiktreiber*').displayversion
# 1080 + Win10 x64
if( (iwr 'https://www.nvidia.de/Download/processFind.aspx?psid=107&pfid=879&osid=57&lid=9&whql=&lang=de&ctk=0&dtcid=0' -usebasicparsing).content -match ".?([0-9]{3}\.[0-9]{2}).?") {
$ver=$Matches[1];
$url = "https://de.download.nvidia.com/Windows/$ver/$ver-desktop-win10-64bit-international-whql.exe";
Get-NewVersion $url;
}

WriteYellow "PDF24-Creator"
Get-NewVersion "https://creator.pdf24.org/listVersions.php" '*exe'

WriteYellow "Adobe Reader"
# TIM AG: Get-NewVersion "https://www.adobe.com/devnet-docs/acrobatetk/tools/ReleaseNotesDC/" @("*classic/dcclassic17*",'*acrordr*_mui.msp')
# Get Current MSP an recreate the offline-installer link 
$a = (Get-NewVersion "https://www.adobe.com/devnet-docs/acrobatetk/tools/ReleaseNotesDC/" @("*continuous/*",'*acrordr*.msp') -nodownload).tostring()
Get-NewVersion $a.replace('.msp','_de_DE.exe').replace('DCUpd','DC')

WriteYellow "IrfanView"
Get-newversion "https://www.irfanview.com/64bit.htm" "*www.irfanview.info/files/iview*g_x64_setup.exe" -nodownload | % { .\wget.exe -c -nc "$_" --header "Referer: $_" }
(Get-newversion "https://www.irfanview.com/64bit.htm" "*iview*_plugins_x64_setup.exe" -nodownload).split('/')[-1] | % { .\wget.exe -c -nc "https://www.irfanview.info/files/$_" --header "Referer: https://www.irfanview.info/files/$_" }

WriteYellow "WinRAR"
Get-NewVersion "https://www.rarlab.com/download.htm" "*winrar-x64-*d.exe*"

WriteYellow "ImDisk - RamDisk"
# Install: 7z x .\ImDiskTk-x64.zip -O"$($env:temp)\imdiskinstall";cmd /c (ls "$($env:temp)\imdiskinstall\*.bat" -Recurse).fullname /fullsilent
# Version in File: if( ((7z l .\ImDiskTk-x64.zip) -join '') -match 'ImDiskTk([0-9]+)') { $ver=$Matches[1] }
Get-NewVersion "https://sourceforge.net/projects/imdisk-toolkit/" "*ImDiskTk-x64.*"

WriteYellow "GOG Client"
Get-NewVersion "https://www.gog.com/galaxy" '*gog_galaxy_*.exe*|-1' -nodatecheck -filenamematch '(GOG_galaxy_[0-9.a-zA-Z]+.exe)'

WriteYellow "FreeFileSync"
Get-NewVersion 'https://freefilesync.org/download.php' '*FreeFile*windows*.exe' -nodatecheck

WriteYellow "Thunderbird DE"
Get-NewVersion "https://www.thunderbird.net/en-US/thunderbird/all/" '*-ssl&os=win64&lang=de'

WriteYellow "7-Zip"
Get-NewVersion 'https://7-zip.org/' '*-x64.exe'
#alpha
Get-NewVersion (Get-link 'https://7-zip.org/' '*-x64.exe' -resultitem 1)
#GetNewVersion 'https://7-zip.org/index.html' '*-x64.exe' '' 'desc' #get alpha - downloadlist in reversed order

WriteYellow "VSDC Video-Editor"
get-newversion "http://www.videosoftdev.com/de/free-video-editor/download" "*productId=1"

WriteYellow "Microsoft VSCode"
Get-NewVersion "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64" -redirected

WriteYellow "Make MKV"
Get-NewVersion 'https://www.makemkv.com/download/' '*setup*.exe'
# makemkv-code from forum: if ((iwr 'https://www.makemkv.com/forum/viewtopic.php?f=5&t=1053' -useBasicParsing) -match "<code>(.*)</code>") { $code=$Matches[1] }

WriteYellow "MP3 Tag"
Get-NewVersion 'https://www.mp3tag.de/en/dodownload.html' '*mp3tag*setup.exe'

WriteYellow "Chitubox (need Login https://cc.chitubox.com/login)"
get-newversion (Get-NewVersion "https://www.chitubox.com/en/download/chitubox-free" "*.exe" -nodownload).replace('&amp;','&') -nodatecheck -filenamematch '(CHITUBOX64install_V[0-9.]+.exe)'

WriteYellow "Inno Unpacker"
Get-NewVersion "https://sourceforge.net/projects/innounp/files/latest/download"

WriteYellow "Notepad++"
#$link = ((iwr "https://notepad-plus-plus.org/downloads/" -UseBasicParsing).links.href -like '*org/downloads/*')[0]
#Get-NewVersion $link '*x64.exe'
Get-NewVersion "https://notepad-plus-plus.org/downloads/" @('*org/downloads/*','*x64.exe')

WriteYellow "Paint DotNet"
Get-NewVersion "https://www.dotpdn.com/downloads/pdn.html" "*install.zip"

WriteYellow "OBS - Open Broadcaster Software"
Get-NewVersion "https://obsproject.com/de/download" "*x64.exe"

WriteYellow "Speedtest"
Get-NewVersion 'https://www.speedtest.net/de/apps/cli' '*win64.zip'

WriteYellow "WinScp"
Get-NewVersion 'https://winscp.net/eng/download.php' '*setup.exe'

WriteYellow "CrystalDiskInfo"
Get-NewVersion 'https://crystalmark.info/redirect.php?product=CrystalDiskInfoInstaller' -nocertcheck

WriteYellow "Greenshot (Portable)"
Get-NewVersion "https://getgreenshot.org/version-history/" "*no-installer*"

WriteYellow "Shotcut Video-Editor"
get-newversion "https://github.com/mltframework/shotcut/releases/" "*shotcut-win64*.exe"

WriteYellow "Filezilla"
get-newversion "https://filezilla-project.org/download.php?show_all=1" "*win64-setup.exe*" -filenamematch "(FileZilla_[-_.a-zA-Z0-9]+_win64-setup.exe)" -nodatecheck

WriteYellow "Plantronics Hub"
Get-NewVersion 'https://www.poly.com/de/de/support/enterprise-software' '*x64.msi'

WriteYellow "Godot Engine"
get-newversion "https://godotengine.org/download/windows" "*Godot_v*-stable_win64.exe.zip"

WriteYellow "CPU-Z"
Get-NewVersion "https://www.cpuid.com/softwares/cpu-z.html" @("*.zip","*.zip")

WriteYellow "Core-Temp"
Get-NewVersion "https://www.alcpu.com/CoreTemp/" "*.exe"

# WriteYellow "MKVToolnix"
# get-link "https://www.fosshub.com/MKVToolNix.html" "*64-bit*.exe"

WriteYellow "CCleaner"
Get-newversion "https://www.ccleaner.com/de-de/ccleaner/download/standard" "*.exe"

WriteYellow "Speccy"
Get-newversion "https://www.ccleaner.com/speccy/download/standard" "*.exe"

WriteYellow "Inkscape"
get-newversion "https://inkscape.org/de/releases/" @("*/platforms*",'*.exe')

WriteYellow "Krita"
Get-NewVersion "https://krita.org/en/download/krita-desktop/" "*.exe"

WriteYellow "AnyBurn portable"
Get-NewVersion "https://www.anyburn.com/anyburn.zip"

WriteYellow "MediaCreatonTool.bat"
$a=iwr -useb "https://gist.github.com/AveYo"
$file = (get-newversion ($a.links | ? outerHTML -like '*mediacreationtool.bat ..*' | ? href -Match 'https').href "*.zip" -nodownload)
get-newversion $file
#ls "*$(basename $file)" | % { 7z e -y $_ *\mediacreationtool.bat; rm $_ -force}

WriteYellow "TLauncher (Minecraft)"
Get-NewVersion "https://tlauncher.org/installer" -nodatecheck

WriteYellow "QDir"
Get-NewVersion 'https://www.softwareok.de/Download/Q-Dir_Portable_x64.zip'
WriteYellow "QuickTextPaste"
Get-NewVersion 'https://www.softwareok.de/Download/QuickTextPaste_x64_Portable.zip'
WriteYellow "Desktop Note"
Get-NewVersion 'https://www.softwareok.de/Download/DesktopNoteOK_x64_Portable.zip'
}