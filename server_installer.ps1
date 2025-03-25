$global:PythonCommand = ""
$global:defaultPath = "C:/Program Files/ASC Timer Server"
$global:defaultPort = "80"
$global:zipName = "application_server_v0-1-0-alpha.zip"

# check if script is running as Administrator
function Check-Admin {
    $currentUser = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    $response = Read-Host "Detected non-administrative priviliges. If installed without administrative privileges, 
    the server will host on port 8080 by default (although this can be modified later in the installation process).
    Continue with installation as a non-administrative user (Y) or exit(n)?"
    if ($response -eq 'Y' -or $response -eq 'y') {
        Write-Output "updating default path to AppData/Local..."
        $global:defaultPath = (Join-Path $env:LOCALAPPDATA "") + "ASC Timer Server"
        Write-Output "updating default port to 8080..."
        $global:defaultPort = "8080"
    }
    else {
        Write-Output "exiting now. Please rerun as an administrative user."
        exit
    }
}

function Install-Python {
    Write-Output "Checking for Python 3.12 or above..."
    
    $pythonVersion = python3.exe --version 2>&1
    $global:PythonCommand = "python3.exe"

    if ($pythonVersion -notmatch "Python (\d+)\.(\d+)\.(\d+)") {
        $pythonVersion = python.exe --version 2>&1
        $global:PythonCommand = "python.exe"
    }

    if ($pythonVersion -match "Python (\d+)\.(\d+)\.(\d+)") {
        $major = [int]$matches[1]
        $minor = [int]$matches[2]
        
        if ($major -gt 3 -or ($major -eq 3 -and $minor -ge 12)) {
            Write-Output "Python $pythonVersion is installed and meets the requirement. Using $global:PythonCommand."
            return
        } else {
            Write-Output "Python version $pythonVersion is below the required 3.12."
        }
    } else {
        Write-Output "python3.exe or python.exe not found in system path."
    }

    $response = Read-Host "Would you like to download and install Python 3.12? (Y/N)"
    if ($response -eq 'Y' -or $response -eq 'y') {
        Write-Output "Downloading and installing Python 3.12.2 from python.org... (this may take a minute or two; please be patient!)"
        $pythonInstallerUrl = "https://www.python.org/ftp/python/3.12.2/python-3.12.2-amd64.exe"
        $installerPath = "$env:TEMP\python-installer.exe"
        Invoke-WebRequest -Uri $pythonInstallerUrl -OutFile $installerPath
        Start-Process -FilePath $installerPath -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait
        Write-Output "Python 3.12.2 installed successfully."
        $global:PythonCommand = "python.exe"
    } else {
        Write-Output "Python installation skipped. Exiting server installation."
        exit 1
    }
} 

function Unzip-File {
    param(
        [string]$zipFilePath,
        [string]$extractPath
    )
    # Step 1: Unzip the encrypted file
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Add-Type -AssemblyName System.IO.Compression
    # Extract the zip file
    Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force
}

function Setup-VenvAndDependencies {
    $response = Read-Host "Would you like to use the default installation path ($global:defaultPath)? (Y/N)"

    if ($response -eq 'Y' -or $response -eq 'y') {
        $global:VenvPath = $defaultPath
    } else {
        do {
            $global:VenvPath = Read-Host "Enter your desired path for the virtual environment"
            if (-Not (Test-Path $global:VenvPath)) {
                try {
                    New-Item -ItemType Directory -Path $global:VenvPath -Force
                    Write-Output "Directory created: $global:VenvPath"
                } catch {
                    Write-Output "Failed to create directory. Please enter a valid path."
                    $global:VenvPath = ""
                }
            }
        } while (-Not (Test-Path $global:VenvPath))
    }
    Write-Output "Setting up virtual environment at $global:VenvPath..."
    & $global:PythonCommand -m venv "$global:VenvPath"

    Write-Output "Modifying script execution policy for this process to enable virtual environment activation script..."
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    Write-Output "Activating virtual environment..." 
    & "$global:VenvPath/Scripts/Activate.ps1"
    $global:defaultPath = $global:VenvPath
    Write-Output "unzipping server files to $global:defaultPath..."
    #Copy-Item -Path "application_server_v0-1-0-alpha.zip" -Destination $global:defaultPath 
    
    Unzip-File -zipFilePath "application_server_v0-1-0-alpha.zip" -extractPath $global:defaultPath 


    & pip install -r "$global:defaultPath/requirements.txt"
    Write-Output "Virtual environment setup complete."
    
}

# Configure Application
function Configure-App {
    Write-Output "Configuring the application..."
    $configPath = ".\config.json"
    if (-not (Test-Path $configPath)) {
        Write-Output "Template config.json not found. Creating from default..."
        @"
{
  "DATABASE_HOST": "localhost",
  "DATABASE_PORT": "$global:defaultPort",
}
"@ | Out-File -FilePath $configPath
    }

    $config = Get-Content $configPath | ConvertFrom-Json

    # $config.DATABASE_HOST = Read-Host "Enter Database Host (e.g., localhost)"
    # $config.DATABASE_PORT = Read-Host "Enter Database Port (e.g., 5432)"
    # $config.DATABASE_USER = Read-Host "Enter Database User"
    # $config.DATABASE_PASSWORD = Read-Host "Enter Database Password"

    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
    Write-Output "Configuration saved to config.json."
}

function Write-StartServerScript {
    Write-Output "Creating server startup script..."
    $powershellScript= @"
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
& Scripts/Activate.ps1
python -c """
from waitress import serve
from timer_server.wsgi import application
host='0.0.0.0'
port=$global:defaultPort
print(f'starting ASC Timer Server at http://{host}:{port}...')
serve(application, host=host, port=port)
"""
"@    
    $filePath = "$global:defaultPath\start_server.ps1"
    try {
        # Ensure the directory exists
        $directory = Split-Path -Path $filePath
        if (-not (Test-Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force
        }

        # Write the script to the specified file
        $powershellScript | Set-Content -Path $filePath -Force
        Write-Output "Start server script written to: $filePath"
    } catch {
        Write-Output "Error writing the server script: $_"
    }
}

# Main Execution
Write-Output "Starting Installer..."
Check-Admin
Install-Python

Setup-VenvAndDependencies

cd "$global:defaultPath"

#Configure-App

Write-Output "creating and migrating database..."
# this works now because we're in the python VENV where 'python' maps properly to the venv python 
& python manage.py migrate
Write-Output "collecting static files..."
& python manage.py collectstatic
Write-StartServerScript
Write-Output "Installation and configuration complete! The ASC Timer App server has been installed."
Write-Output "To run the application server, execute the start_server.ps1 script."

