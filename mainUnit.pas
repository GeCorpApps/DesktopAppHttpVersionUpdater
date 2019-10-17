unit mainUnit;

interface

uses System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, FMX.Types, FMX.Controls, FMX.Forms,
  FMX.Graphics, FMX.Dialogs, IPPeerClient, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param,
  FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, IdComponent, FMX.Controls.Presentation,
  FMX.StdCtrls, IdBaseComponent, IdTCPConnection, IdTCPClient, IdHTTP, REST.Response.Adapter, REST.Client, Data.DB,
  FireDAC.Comp.DataSet, FireDAC.Comp.Client, Data.Bind.Components, Data.Bind.ObjectScope, System.Threading, iniFiles,
  Winapi.ShellAPI, Winapi.Windows,

  REST.Types, System.Net.URLClient, System.Net.HttpClient, System.Net.HttpClientComponent, FMX.Objects,
  System.NetEncoding, System.IOUtils;

type
  TmainForm = class(TForm)
    RESTClient: TRESTClient;
    RESTRequestCheck: TRESTRequest;
    TimerTerminateApp: TTimer;
    TimerCheck: TTimer;
    FDMemTableCheck: TFDMemTable;
    FDMemTableCheckid: TWideStringField;
    FDMemTableCheckfilename: TWideStringField;
    FDMemTableCheckversion: TWideStringField;
    FDMemTableCheckexecutable: TWideStringField;
    FDMemTableCheckdl_url: TWideStringField;
    FDMemTableCheckupdate_date: TWideStringField;
    FDMemTableCheckupload_date: TWideStringField;
    FDMemTableCheckfeatures: TWideStringField;
    RESTResponseCheck: TRESTResponse;
    RESTResponseDataSetAdapterCheck: TRESTResponseDataSetAdapter;
    IdHTTP1: TIdHTTP;
    ProgressBar1: TProgressBar;
    procedure TimerCheckTimer(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure IdHTTP1WorkEnd(ASender: TObject; AWorkMode: TWorkMode);
    procedure IdHTTP1Work(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
    procedure IdHTTP1WorkBegin(ASender: TObject; AWorkMode: TWorkMode; AWorkCountMax: Int64);
    procedure TimerTerminateAppTimer(Sender: TObject);
  private
  var
    FIniFile: TInifile;
    procedure downloadFile(pURL, pVersion, pFileName, pUpdateDate: String; pIsExecutable: boolean);
    procedure DownloadNewFile;
    procedure runApp(vLocal: boolean; pVersion, pFileName, pUpdateDate: string);

  const
    baseURL: String = 'http://pilotproject.napr.gov.ge/';
    segmentOfUrl: String = 'api/checkversion';
    userAgent: String = 'SmartCity Updater RESTClient/1.0';

    procedure UpdateFiles;
    function GetExeName: string;
    procedure HttpWork(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
    { Private declarations }
  public
    { Public declarations }
  end;

var mainForm: TmainForm;

implementation

{$R *.fmx}

procedure TmainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  self.FIniFile.Free;
end;

procedure TmainForm.FormCreate(Sender: TObject);
var FnIni, FnOldIni: string;
begin
  RESTClient.baseURL := self.baseURL;
  RESTRequestCheck.Resource := self.segmentOfUrl;
  FnIni := ChangeFileExt(self.GetExeName, '.ini');
  FnOldIni := ExtractFilePath(self.GetExeName) + 'tmp.ini';
  if ((not FileExists(FnIni)) and FileExists(FnOldIni)) then CopyFile(pwideChar(FnOldIni), pwideChar(FnIni), false);
  self.FIniFile := TInifile.Create(FnIni);
  TimerCheck.Enabled := true;
end;

function TmainForm.GetExeName: string;
begin
  Result := ParamStr(0);
end;

procedure TmainForm.IdHTTP1Work(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
begin
  if AWorkMode = wmRead then ProgressBar1.Value := AWorkCount;
end;

procedure TmainForm.IdHTTP1WorkBegin(ASender: TObject; AWorkMode: TWorkMode; AWorkCountMax: Int64);
begin
  if AWorkMode = wmRead then begin
    ProgressBar1.Max := AWorkCountMax;
    ProgressBar1.Value := 0;
  end;
end;

procedure TmainForm.IdHTTP1WorkEnd(ASender: TObject; AWorkMode: TWorkMode);
begin
  ProgressBar1.Value := 0;
  self.runApp(FDMemTableCheck.FieldByName('filename').AsString);
end;

procedure TmainForm.TimerCheckTimer(Sender: TObject);
var aTask: ITask;
begin
  TTimer(Sender).Enabled := false;
  aTask := TTask.Create(procedure()
    begin
      RESTRequestCheck.Execute;
      self.UpdateFiles;
    end);
  aTask.Start;
end;

procedure TmainForm.TimerTerminateAppTimer(Sender: TObject);
begin
  ExitProcess(1);
end;

{ procedure TmainForm.UpdateFiles;
  var ms: TMemoryStream; run: boolean;
  begin
  run := false;
  if FDMemTableCheck.FieldByName('version').AsString <> self.FIniFile.ReadString('version_info', 'version', '1.0.0')
  then begin
  ms := TMemoryStream.Create;
  try
  try
  IdHTTP1.Get(FDMemTableCheck.FieldByName('dl_url').AsString, ms);
  MkDir(FDMemTableCheck.FieldByName('version').AsString);
  ms.SaveToFile(FDMemTableCheck.FieldByName('version').AsString + '/' + FDMemTableCheck.FieldByName('filename')
  .AsString);
  self.AfterUpdater_Run_Apps(FDMemTableCheck.FieldByName('version').AsString + '\' +
  FDMemTableCheck.FieldByName('filename').AsString);
  run := true;
  except
  on E: Exception do begin
  MessageBox(0, PChar(E.message), 'Message', MB_ICONERROR or MB_OK);
  end;
  end;
  finally ms.Free;
  end;
  end;
  if run = false then begin
  self.AfterUpdater_Run_Apps(FDMemTableCheck.FieldByName('version').AsString + '\' +
  FDMemTableCheck.FieldByName('filename').AsString);
  end;
  end; }

procedure TmainForm.runApp(vLocal: boolean; pVersion, pFileName, pUpdateDate: string);
var v_filename, v_filename1: string;
begin
  self.TimerTerminateApp.Enabled := true;
  if vLocal = false then begin
    ShellExecute(0, PChar('open'), PChar(pFileName), PChar(self.GetExeName), nil, SW_SHOWNORMAL);
  end else begin
    v_filename := self.FIniFile.ReadString('version_info', 'executable_filename', '');
    if FileExists(v_filename) then begin
      ShellExecute(0, PChar('open'), PChar(v_filename), PChar(self.GetExeName), nil, SW_SHOWNORMAL);
    end else begin
      TThread.Queue(nil, procedure
        begin
          ShowMessage('Something went wrong');
        end);
    end;
  end;
end;

procedure TmainForm.DownloadNewFile;
var URL: string; LResponse: IHTTPResponse; LFileName, vURL, vCurrentDir, vExecutableFile: string; LSize: Int64;
  vLocal: boolean; vVersion, vUpdateDate, DocumentsPath: string; vIsExecutable: boolean;
begin
  vExecutableFile := '';
  FDMemTableCheck.First;
  if (FDMemTableCheck.FieldByName('version').AsString <> self.FIniFile.ReadString('version_info', 'version', '1.0.0'))
  // or (FDMemTableCheck.FieldByName('executable').AsInteger = 0)
  then begin
    vLocal := false;
    while not FDMemTableCheck.Eof do begin

      vVersion := FDMemTableCheck.FieldByName('version').AsString;
      vUpdateDate := FDMemTableCheck.FieldByName('update_date').AsString;

      vCurrentDir := System.SysUtils.GetCurrentDir;
      vURL := FDMemTableCheck.FieldByName('dl_url').AsString;
      LFileName := vCurrentDir + '\' + vVersion + '\' + FDMemTableCheck.FieldByName('filename').AsString;

      if not DirectoryExists(vCurrentDir + '\' + vVersion) then begin
        MkDir(vVersion);
      end;

      vIsExecutable := false;
      if (FDMemTableCheck.FieldByName('executable').AsInteger = 1) and
        (FDMemTableCheck.FieldByName('file_type').AsString = 'exe') then begin
        vExecutableFile := LFileName;
        vIsExecutable := true;
      end;

      if FDMemTableCheck.FieldByName('file_type').AsString = 'db' then begin
        DocumentsPath := TPath.Combine(TPath.GetDocumentsPath, FDMemTableCheck.FieldByName('filename').AsString);
        if not FileExists(DocumentsPath) then begin
          LFileName := DocumentsPath;
        end;
      end;

      if not FileExists(LFileName) then begin
        self.downloadFile(vURL, vVersion, LFileName, vUpdateDate, vIsExecutable);
      end;

      FDMemTableCheck.Next;
    end;
  end else begin
    vLocal := true;
  end;

  if (vExecutableFile <> '') or (vLocal = true) then begin
    self.runApp(vLocal, vVersion, vExecutableFile, vUpdateDate);
  end;
end;

procedure TmainForm.downloadFile(pURL, pVersion, pFileName, pUpdateDate: String; pIsExecutable: boolean);
var Http: TIdHTTP; ms: TMemoryStream;
begin
  Http := TIdHTTP.Create(nil);
  try
    ms := TMemoryStream.Create;
    try
      Http.OnWork := HttpWork;
      Http.Get(pURL, ms);
      ms.SaveToFile(pFileName);
      self.FIniFile.WriteString('version_info', 'version', pVersion);
      self.FIniFile.WriteString('version_info', 'update_date', pUpdateDate);
      if pIsExecutable = true then begin
        self.FIniFile.WriteString('version_info', 'executable_filename', pFileName);
      end else begin
        self.FIniFile.WriteString('version_info', 'db_filename', pFileName);
      end;
    finally ms.Free;
    end;
  finally Http.Free;
  end;
end;

procedure TmainForm.HttpWork(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
var Http: TIdHTTP; ContentLength: Int64; Percent: Integer;
begin
  Http := TIdHTTP(ASender);
  ContentLength := Http.Response.ContentLength;
  if (Pos('chunked', LowerCase(Http.Response.TransferEncoding)) = 0) and (ContentLength > 0) then begin
    Percent := 100 * AWorkCount div ContentLength;
    ProgressBar1.Value := Percent;
  end;
end;

end.
