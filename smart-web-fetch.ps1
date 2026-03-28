#!/usr/bin/env pwsh
# Smart Web Fetch Pro - Intelligent Web Scraping Tool (Windows PowerShell Version)
# Replaces built-in web_fetch, automatically uses Jina Reader / markdown.new / defuddle.md
# Supports multi-level fallback strategy, significantly reduces Token consumption

param(
    [Parameter(Position = 0, Mandatory = $false)]
    [string]$Url,

    [Parameter(Mandatory = $false)]
    [string]$Output,

    [Parameter(Mandatory = $false)]
    [ValidateSet("jina", "markdown", "defuddle", "scrapling")]
    [string]$Service,

    [Parameter(Mandatory = $false)]
    [switch]$Detailed,

    [Parameter(Mandatory = $false)]
    [switch]$Json,

    [Parameter(Mandatory = $false)]
    [switch]$NoClean,

    [Parameter(Mandatory = $false)]
    [switch]$Help
)

# Configuration
$TIMEOUT = 30

# Service URLs
$JINA_READER = "https://r.jina.ai/"
$MARKDOWN_NEW = "https://markdown.new/"
$DEFUDDLE_MD = "https://defuddle.md/"

# Color output functions
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Log-Info {
    param([string]$Message)
    if ($Detailed) { Write-ColorOutput "[INFO] $Message" "Cyan" }
}

function Log-Success {
    param([string]$Message)
    if ($Detailed) { Write-ColorOutput "[SUCCESS] $Message" "Green" }
}

function Log-Warn {
    param([string]$Message)
    if ($Detailed) { Write-ColorOutput "[WARN] $Message" "Yellow" }
}

function Log-Error {
    param([string]$Message)
    Write-ColorOutput "[ERROR] $Message" "Red"
}

# Show help
function Show-Help {
    $helpText = @'
Smart Web Fetch Pro - Intelligent Web Scraping Tool (Windows Version)

Usage:
    smart-web-fetch.ps1 <URL> [Options]

Options:
    -Url <URL>          URL to fetch
    -Output <FILE>      Output to file
    -Service <NAME>     Specify service (jina|markdown|defuddle|scrapling)
    -Detailed           Show detailed logs
    -Json               Output JSON format
    -NoClean            Disable HTML cleaning
    -Help               Show help

Examples:
    .\smart-web-fetch.ps1 https://example.com
    .\smart-web-fetch.ps1 -Url https://example.com -Output output.md
    .\smart-web-fetch.ps1 -Url https://example.com -Service jina
    .\smart-web-fetch.ps1 -Url https://mp.weixin.qq.com/s/xxx -Json

Services:
    jina        - Jina Reader (r.jina.ai) - Recommended, most stable
    markdown    - markdown.new API - Backup service
    defuddle    - defuddle.md - Backup service
    scrapling   - Python Scrapling - For anti-crawl pages

Fallback Strategy:
    1. Jina Reader (fastest for normal pages)
    2. markdown.new (fallback when Jina fails)
    3. defuddle.md (fallback when previous fail)
    4. Scrapling (for anti-crawl pages like WeChat articles)
'@
    Write-Host $helpText
}

# Check if content is blocked
function Test-BlockedContent {
    param([string]$Content)
    
    if ([string]::IsNullOrWhiteSpace($Content)) { return $true }
    
    $contentLower = $Content.ToLower()
    $blockKeywords = @('captcha', 'access denied', 'blocked', 'forbidden', '403 forbidden', 'cloudflare')
    
    foreach ($keyword in $blockKeywords) {
        if ($contentLower -match [regex]::Escape($keyword)) {
            return $true
        }
    }
    
    return $false
}

# Fetch using Jina Reader
function Invoke-JinaFetch {
    param([string]$Url)
    
    Log-Info "Trying Jina Reader..."
    
    $jinaUrl = "$JINA_READER$Url"
    
    try {
        $response = Invoke-WebRequest -Uri $jinaUrl -TimeoutSec $TIMEOUT -UseBasicParsing -ErrorAction Stop
        
        $content = $response.Content
        
        if ([string]::IsNullOrWhiteSpace($content) -or $content.Length -lt 100) {
            Log-Warn "Jina Reader returned content too short"
            return $null
        }
        
        if (Test-BlockedContent $content) {
            Log-Warn "Jina Reader content may be blocked"
            return $null
        }
        
        Log-Success "Jina Reader success"
        return $content
    }
    catch {
        Log-Warn "Jina Reader failed: $($_.Exception.Message)"
        return $null
    }
}

# Fetch using markdown.new
function Invoke-MarkdownNewFetch {
    param([string]$Url)
    
    Log-Info "Trying markdown.new..."
    
    $apiUrl = "$MARKDOWN_NEW$Url"
    
    try {
        $response = Invoke-WebRequest -Uri $apiUrl -TimeoutSec $TIMEOUT -UseBasicParsing -ErrorAction Stop
        
        $content = $response.Content
        
        if ([string]::IsNullOrWhiteSpace($content) -or $content.Length -lt 100) {
            Log-Warn "markdown.new returned content too short"
            return $null
        }
        
        if (Test-BlockedContent $content) {
            Log-Warn "markdown.new content may be blocked"
            return $null
        }
        
        Log-Success "markdown.new success"
        return $content
    }
    catch {
        Log-Warn "markdown.new failed: $($_.Exception.Message)"
        return $null
    }
}

# Fetch using defuddle.md
function Invoke-DefuddleFetch {
    param([string]$Url)
    
    Log-Info "Trying defuddle.md..."
    
    $apiUrl = "$DEFUDDLE_MD$Url"
    
    try {
        $response = Invoke-WebRequest -Uri $apiUrl -TimeoutSec $TIMEOUT -UseBasicParsing -ErrorAction Stop
        
        $content = $response.Content
        
        if ([string]::IsNullOrWhiteSpace($content) -or $content.Length -lt 100) {
            Log-Warn "defuddle.md returned content too short"
            return $null
        }
        
        if (Test-BlockedContent $content) {
            Log-Warn "defuddle.md content may be blocked"
            return $null
        }
        
        Log-Success "defuddle.md success"
        return $content
    }
    catch {
        Log-Warn "defuddle.md failed: $($_.Exception.Message)"
        return $null
    }
}

# Fetch using Scrapling (for anti-crawl pages)
function Invoke-ScraplingFetch {
    param([string]$Url)
    
    Log-Info "Trying Scrapling (for anti-crawl pages)..."
    
    # Check Python availability
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonCmd) {
        $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
    }
    
    if (-not $pythonCmd) {
        Log-Warn "Python not installed"
        return $null
    }
    
    # Get script directory
    $scriptDir = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptDir)) {
        $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    }
    $scraplingScript = Join-Path $scriptDir "fetch_scrapling.py"
    
    if (-not (Test-Path $scraplingScript)) {
        Log-Warn "Scrapling script not found: $scraplingScript"
        return $null
    }
    
    try {
        $result = & $pythonCmd.Source $scraplingScript $Url 2>&1
        
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($result)) {
            try {
                $jsonResult = $result | ConvertFrom-Json
                if ($jsonResult.success) {
                    Log-Success "Scrapling success"
                    return $jsonResult.content
                }
            }
            catch {
                Log-Success "Scrapling success"
                return $result
            }
        }
    }
    catch {
        Log-Warn "Scrapling failed: $($_.Exception.Message)"
    }
    
    return $null
}

# Basic fetch using curl
function Invoke-BasicFetch {
    param([string]$Url)
    
    Log-Info "Trying basic fetch..."
    
    try {
        $headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        }
        
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec $TIMEOUT -Headers $headers -UseBasicParsing -ErrorAction Stop
        
        $content = $response.Content
        
        # Simple HTML cleaning
        $content = $content -replace '<script[^>]*>.*?</script>', '' -replace '<style[^>]*>.*?</style>', ''
        $content = $content -replace '<[^>]+>', ' '
        $content = $content -replace '\s+', ' '
        $content = $content.Trim()
        
        Log-Success "Basic fetch success"
        return $content
    }
    catch {
        Log-Warn "Basic fetch failed: $($_.Exception.Message)"
        return $null
    }
}

# Main fetch function
function Invoke-SmartFetch {
    param(
        [string]$Url,
        [string]$SpecifiedService
    )
    
    $finalUrl = $Url
    
    # Validate URL
    if ([string]::IsNullOrWhiteSpace($finalUrl)) {
        Log-Error "Please provide a URL"
        return @{
            Content = $null
            Source = "none"
            Success = $false
            Error = "No URL provided"
        }
    }
    
    # Add protocol prefix if missing
    if ($finalUrl -notmatch '^https?://') {
        $finalUrl = "https://$finalUrl"
        Log-Info "Auto-added https:// prefix: $finalUrl"
    }
    
    Log-Info "Starting fetch: $finalUrl"
    
    # If service is specified, use it directly
    if (-not [string]::IsNullOrWhiteSpace($SpecifiedService)) {
        $content = $null
        switch ($SpecifiedService) {
            "jina" { $content = Invoke-JinaFetch $finalUrl }
            "markdown" { $content = Invoke-MarkdownNewFetch $finalUrl }
            "defuddle" { $content = Invoke-DefuddleFetch $finalUrl }
            "scrapling" { $content = Invoke-ScraplingFetch $finalUrl }
        }
        
        if ($null -ne $content) {
            return @{
                Content = $content
                Source = $SpecifiedService
                Success = $true
            }
        }
        
        return @{
            Content = $null
            Source = $SpecifiedService
            Success = $false
            Error = "Specified service failed"
        }
    }
    
    # Default fallback strategy
    Log-Info "Using auto fallback strategy..."
    
    # 1. Try Jina Reader
    $content = Invoke-JinaFetch $finalUrl
    if ($null -ne $content) {
        return @{ Content = $content; Source = "jina"; Success = $true }
    }
    
    # 2. Try markdown.new
    $content = Invoke-MarkdownNewFetch $finalUrl
    if ($null -ne $content) {
        return @{ Content = $content; Source = "markdown"; Success = $true }
    }
    
    # 3. Try defuddle.md
    $content = Invoke-DefuddleFetch $finalUrl
    if ($null -ne $content) {
        return @{ Content = $content; Source = "defuddle"; Success = $true }
    }
    
    # 4. Try Scrapling
    $content = Invoke-ScraplingFetch $finalUrl
    if ($null -ne $content) {
        return @{ Content = $content; Source = "scrapling"; Success = $true }
    }
    
    # 5. Basic fetch
    if (-not $NoClean) {
        $content = Invoke-BasicFetch $finalUrl
        if ($null -ne $content) {
            return @{ Content = $content; Source = "basic"; Success = $true }
        }
    }
    
    return @{
        Content = $null
        Source = "none"
        Success = $false
        Error = "All fetch methods failed"
    }
}

# Main program
if ($Help -or [string]::IsNullOrWhiteSpace($Url)) {
    Show-Help
    if ([string]::IsNullOrWhiteSpace($Url)) { exit 1 }
    exit 0
}

$result = Invoke-SmartFetch -Url $Url -SpecifiedService $Service

if ($result.Success) {
    if ($Json) {
        $jsonOutput = @{
            success = $true
            url = $Url
            content = $result.Content
            source = $result.Source
        }
        $jsonOutput | ConvertTo-Json -Depth 10
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Output)) {
        $result.Content | Out-File -FilePath $Output -Encoding UTF8
        Log-Success "Content saved to: $Output"
    }
    else {
        Write-Output $result.Content
    }
}
else {
    if ($Json) {
        $jsonOutput = @{
            success = $false
            url = $Url
            content = ""
            source = $result.Source
            error = $result.Error
        }
        $jsonOutput | ConvertTo-Json -Depth 10
    }
    else {
        Log-Error $result.Error
    }
    exit 1
}