param(
    [string]$OutDir = "",
    [string]$SourceJsonUrl = "https://raw.githubusercontent.com/snarfnet/KeirinPredictor/main/generated/tekkyaku/latest.json",
    [string]$MailConfigPath = ""
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$desktop = [Environment]::GetFolderPath("Desktop")
$folderName = -join ([char[]](0x7af6, 0x8f2a, 0x4e88, 0x60f3))
$defaultSubjectPrefix = -join ([char[]](0x9244, 0x811a, 0x535a, 0x58eb, 0x306e, 0x7af6, 0x8f2a, 0x4e88, 0x60f3))
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $desktop $folderName
}
if ([string]::IsNullOrWhiteSpace($MailConfigPath)) {
    $MailConfigPath = Join-Path $OutDir "mail_config.json"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$utf8Bom = New-Object System.Text.UTF8Encoding $true
$logPath = Join-Path $OutDir "export_log.txt"
if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $scriptDir = $PSScriptRoot
} elseif (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptDir = Split-Path -Parent $PSCommandPath
} else {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$repoRoot = Split-Path -Parent $scriptDir
$tempOutDir = Join-Path $env:TEMP "tekkyaku_note_export"

function Write-ExportLog {
    param([string]$Message)
    $line = "[{0}] {1}{2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message, [Environment]::NewLine
    [IO.File]::AppendAllText($logPath, $line, $utf8Bom)
}

function Get-RemoteUtf8Text {
    param([string]$Url)

    $lastError = $null
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            $cacheKey = [DateTimeOffset]::Now.ToUnixTimeSeconds()
            $separator = "?"
            if ($Url.Contains("?")) {
                $separator = "&"
            }
            $finalUrl = "{0}{1}v={2}" -f $Url, $separator, $cacheKey
            $client = New-Object Net.WebClient
            $client.Headers.Set("Cache-Control", "no-cache")
            $client.Headers.Set("Pragma", "no-cache")
            $bytes = $client.DownloadData($finalUrl)
            return [Text.Encoding]::UTF8.GetString($bytes)
        } catch {
            $lastError = $_.Exception.Message
            Write-ExportLog ("download attempt {0} failed: {1}" -f $attempt, $lastError)
            if ($attempt -lt 3) {
                Start-Sleep -Seconds (15 * $attempt)
            }
        }
    }

    throw "download failed after 3 attempts: $lastError"
}

function Sync-RepoBestEffort {
    try {
        $git = Get-Command git -ErrorAction Stop
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $output = & $git.Source -C $repoRoot pull --ff-only 2>&1
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorAction
        if ($exitCode -eq 0) {
            Write-ExportLog ("git pull result: {0}" -f (($output | Out-String).Trim()))
        } else {
            Write-ExportLog ("git pull skipped or failed: {0}" -f (($output | Out-String).Trim()))
        }
    } catch {
        $ErrorActionPreference = "Stop"
        Write-ExportLog ("git pull skipped or failed: {0}" -f $_.Exception.Message)
    }
}

function Get-LocalGeneratedJsonText {
    $generator = Join-Path $repoRoot "scripts\generate_tekkyaku_predictions.py"
    if (-not (Test-Path $generator)) {
        throw "generator not found: $generator"
    }

    if (Test-Path $tempOutDir) {
        Remove-Item -Recurse -Force $tempOutDir
    }
    New-Item -ItemType Directory -Force -Path $tempOutDir | Out-Null

    $repoGenerated = Join-Path $repoRoot "generated\tekkyaku"
    if (Test-Path $repoGenerated) {
        Copy-Item -Path (Join-Path $repoGenerated "*") -Destination $tempOutDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    $python = Get-Command python -ErrorAction Stop
    $output = & $python.Source $generator --out $tempOutDir 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("local generation failed: {0}" -f (($output | Out-String).Trim()))
    }

    $latestJson = Join-Path $tempOutDir "latest.json"
    if (-not (Test-Path $latestJson)) {
        throw "local generation did not create latest.json"
    }
    Write-ExportLog ("local generation result: {0}" -f (($output | Out-String).Trim()))
    return [IO.File]::ReadAllText($latestJson, [Text.Encoding]::UTF8)
}

function Get-LocalFallbackNote {
    $paths = @(
        (Join-Path $tempOutDir "latest.md"),
        (Join-Path $repoRoot "generated\tekkyaku\latest.md")
    )
    foreach ($localLatest in $paths) {
        if (Test-Path $localLatest) {
            Write-ExportLog ("using local fallback: {0}" -f $localLatest)
            return [IO.File]::ReadAllText($localLatest, [Text.Encoding]::UTF8)
        }
    }
    return $null
}

function Ensure-MailConfigSample {
    $samplePath = Join-Path $OutDir "mail_config.sample.json"

    $sample = [ordered]@{
        enabled = $false
        smtp_host = "smtp.gmail.com"
        smtp_port = 587
        smtp_user = "your-gmail-address@gmail.com"
        smtp_password = "gmail-app-password"
        from = "your-gmail-address@gmail.com"
        to = @("send-to@example.com")
        subject_prefix = $defaultSubjectPrefix
        attach_text_file = $true
    } | ConvertTo-Json -Depth 4
    [IO.File]::WriteAllText($samplePath, $sample, $utf8Bom)
}

function Send-NoteMailIfConfigured {
    param(
        [string]$Note,
        [string]$Date,
        [string]$Title,
        [string]$ArchivePath
    )

    Ensure-MailConfigSample
    if (-not (Test-Path $MailConfigPath)) {
        Write-ExportLog ("mail skipped: config not found: {0}" -f $MailConfigPath)
        return
    }

    $config = [IO.File]::ReadAllText($MailConfigPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if (-not $config.enabled) {
        Write-ExportLog "mail skipped: config disabled"
        return
    }

    $hostName = [string]$config.smtp_host
    $port = [int]$config.smtp_port
    $user = [string]$config.smtp_user
    $password = ([string]$config.smtp_password) -replace "\s+", ""
    $from = [string]$config.from
    $subjectPrefix = [string]$config.subject_prefix
    if ([string]::IsNullOrWhiteSpace($subjectPrefix)) {
        $subjectPrefix = $defaultSubjectPrefix
    }

    if ([string]::IsNullOrWhiteSpace($hostName) -or
        [string]::IsNullOrWhiteSpace($user) -or
        [string]::IsNullOrWhiteSpace($password) -or
        [string]::IsNullOrWhiteSpace($from) -or
        $null -eq $config.to) {
        throw "mail config is incomplete"
    }

    $message = New-Object Net.Mail.MailMessage
    $message.From = $from
    foreach ($address in @($config.to)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$address)) {
            $message.To.Add([string]$address)
        }
    }
    if ($message.To.Count -eq 0) {
        throw "mail config has no recipient"
    }

    $message.Subject = ("{0} {1}" -f $subjectPrefix, $Date)
    $message.SubjectEncoding = [Text.Encoding]::UTF8
    $message.BodyEncoding = [Text.Encoding]::UTF8
    $message.Body = $Note
    if (-not [string]::IsNullOrWhiteSpace($Title)) {
        $message.Body = $Title + [Environment]::NewLine + [Environment]::NewLine + $Note
    }
    if ($config.attach_text_file -and (Test-Path $ArchivePath)) {
        $attachment = New-Object Net.Mail.Attachment($ArchivePath)
        $message.Attachments.Add($attachment) | Out-Null
    }

    $client = New-Object Net.Mail.SmtpClient($hostName, $port)
    $client.EnableSsl = $true
    $client.Credentials = New-Object Net.NetworkCredential($user, $password)

    try {
        $client.Send($message)
        $recipients = (@($config.to) -join ", ")
        Write-ExportLog ("mail sent: {0}" -f $recipients)
    } finally {
        $message.Dispose()
        $client.Dispose()
    }
}

try {
    Sync-RepoBestEffort
    try {
        $jsonText = Get-LocalGeneratedJsonText
    } catch {
        Write-ExportLog ("local generation skipped or failed: {0}" -f $_.Exception.Message)
        $jsonText = Get-RemoteUtf8Text $SourceJsonUrl
    }
    $json = $jsonText | ConvertFrom-Json
    $note = [string]$json.note_markdown
    $date = [string]$json.date
    $title = [string]$json.note_title

    if ([string]::IsNullOrWhiteSpace($note)) {
        throw "note_markdown is empty"
    }
    if ([string]::IsNullOrWhiteSpace($date)) {
        $date = Get-Date -Format "yyyyMMdd"
    }

    $archivePath = Join-Path $OutDir ("keirin_note_{0}.txt" -f $date)
    $latestPath = Join-Path $OutDir "latest_note.txt"
    $statusPath = Join-Path $OutDir "latest_status.json"

    [IO.File]::WriteAllText($archivePath, $note, $utf8Bom)
    [IO.File]::WriteAllText($latestPath, $note, $utf8Bom)

    $status = [ordered]@{
        exported_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
        date = $date
        title = $title
        archive = $archivePath
        latest = $latestPath
        source = $SourceJsonUrl
    } | ConvertTo-Json -Depth 3
    [IO.File]::WriteAllText($statusPath, $status, $utf8Bom)

    Write-ExportLog ("exported note: {0}" -f $archivePath)
    try {
        Send-NoteMailIfConfigured -Note $note -Date $date -Title $title -ArchivePath $archivePath
    } catch {
        Write-ExportLog ("mail failed: {0}" -f $_.Exception.Message)
    }
    Write-Output $archivePath
    exit 0
} catch {
    Write-ExportLog ("remote export failed: {0}" -f $_.Exception.Message)
    $fallback = Get-LocalFallbackNote
    if (-not [string]::IsNullOrWhiteSpace($fallback)) {
        $date = Get-Date -Format "yyyyMMdd"
        $archivePath = Join-Path $OutDir ("keirin_note_{0}_fallback.txt" -f $date)
        $latestPath = Join-Path $OutDir "latest_note.txt"
        [IO.File]::WriteAllText($archivePath, $fallback, $utf8Bom)
        [IO.File]::WriteAllText($latestPath, $fallback, $utf8Bom)
        Write-ExportLog ("exported fallback note: {0}" -f $archivePath)
        Write-Output $archivePath
        exit 0
    }
    Write-Error $_
    exit 1
}
