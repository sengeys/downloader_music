[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}}
AppName=Downloader Music
AppVersion=1.0.9
AppPublisher=TuNai Plus
DefaultDirName={autopf}\Downloader Music
DefaultGroupName=Downloader Music
DisableProgramGroupPage=yes
OutputDir=installer_output
OutputBaseFilename=downloader_music_Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
SetupIconFile=app_icon.ico
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Downloader Music"; Filename: "{app}\downloader_music.exe"
Name: "{autodesktop}\Downloader Music"; Filename: "{app}\downloader_music.exe"

[Run]
Filename: "{app}\downloader_music.exe"; Description: "{cm:LaunchProgram,Downloader Music}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\Downloader Music"