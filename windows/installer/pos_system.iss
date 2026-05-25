; Inno Setup script for POS System - Flutter Desktop
; Requires Inno Setup 6.x — https://jrsoftware.org/isinfo.php
;
; BEFORE building this installer:
;   1. Run: .\scripts\sync_windows_app_icon.ps1  (app_icon.png -> app_icon.ico)
;   2. Run: flutter build windows --release
;   3. Copy release\app_config.example.json to release\app_config.json
;   4. Run: .\scripts\prepare_windows_release.ps1
;   5. Open this file in Inno Setup Compiler and click Build → Compile

#define AppName      "POS System"
#define AppVersion   "1.0.0"
#define AppPublisher "Your Company Name"
#define AppExeName   "pos_system.exe"
#define ReleaseDir   "..\..\build\windows\x64\runner\Release"
#define ConfigDir    "..\..\release"
#define AppIcon      "..\..\assets\images\app_icon.ico"

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
SetupIconFile={#AppIcon}
UninstallDisplayIcon={#AppIcon}
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
OutputDir={#ConfigDir}\installer_output
OutputBaseFilename=POSSystemSetup_{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
DisableProgramGroupPage=yes
ShowLanguageDialog=no
WizardStyle=modern
MinVersion=10.0.17763

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; Flutter release bundle (executable + DLLs + data/)
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

; Production API config pranë exe (app_config.json ose shembulli)
#ifnexist "..\..\release\app_config.json"
Source: "{#ConfigDir}\app_config.example.json"; DestDir: "{app}"; DestName: "app_config.json"; Flags: ignoreversion
#else
Source: "{#ConfigDir}\app_config.json"; DestDir: "{app}"; Flags: ignoreversion
#endif

[Icons]
; Start Menu shortcut
Name: "{group}\{#AppName}";     Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"

; Desktop shortcut
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"

[Run]
; Optional: launch after install
Filename: "{app}\{#AppExeName}"; \
  Description: "Launch {#AppName}"; \
  Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Clean up app_config.json written by operator (not tracked by uninstaller otherwise)
Type: files; Name: "{app}\app_config.json"
