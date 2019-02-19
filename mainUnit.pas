unit mainUnit;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, IPPeerClient,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param,
  FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf,
  IdComponent, FMX.Controls.Presentation, FMX.StdCtrls, IdBaseComponent,
  IdTCPConnection, IdTCPClient, IdHTTP, REST.Response.Adapter, REST.Client,
  Data.DB, FireDAC.Comp.DataSet, FireDAC.Comp.Client, Data.Bind.Components,
  Data.Bind.ObjectScope, System.Threading, iniFiles, Winapi.ShellAPI, Winapi.Windows;

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
  private
    FIniFile: TInifile;
    procedure AfterUpdater_Run_Apps(p_filename: string);
    procedure TimerTerminateAppTimer(Sender: TObject);
    procedure UpdateFiles;
    function GetExeName: string;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  mainForm: TmainForm;

implementation

{$R *.fmx}

procedure TmainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  self.FIniFile.Free;
end;

procedure TmainForm.FormCreate(Sender: TObject);
var
  FnIni, FnOldIni: string;
begin
  FnIni := ChangeFileExt(self.GetExeName, '.ini');
  FnOldIni := ExtractFilePath(self.GetExeName) + 'tmp.ini';
  if ((not FileExists(FnIni)) and FileExists(FnOldIni)) then
    CopyFile(pwideChar(FnOldIni), pwideChar(FnIni), false);
  self.FIniFile := TInifile.Create(FnIni);
  TimerCheck.Enabled := true;
end;

function TmainForm.GetExeName: string;
begin
  Result := ParamStr(0);
end;

procedure TmainForm.IdHTTP1Work(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
begin
  if AWorkMode = wmRead then
    ProgressBar1.Value := AWorkCount;
end;

procedure TmainForm.IdHTTP1WorkBegin(ASender: TObject; AWorkMode: TWorkMode; AWorkCountMax: Int64);
begin
  if AWorkMode = wmRead then
  begin
    ProgressBar1.Max := AWorkCountMax;
    ProgressBar1.Value := 0;
  end;
end;

procedure TmainForm.IdHTTP1WorkEnd(ASender: TObject; AWorkMode: TWorkMode);
begin
  ProgressBar1.Value := 0;
  self.AfterUpdater_Run_Apps(FDMemTableCheck.FieldByName('filename').AsString);
end;

procedure TmainForm.TimerCheckTimer(Sender: TObject);
var
  aTask: ITask;
begin
  TTimer(Sender).Enabled := false;
  aTask := TTask.Create(
    procedure()
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

procedure TmainForm.UpdateFiles;
var
  ms: TMemoryStream;
  run: boolean;
begin
  run := false;
  if FDMemTableCheck.FieldByName('version').AsString <> self.FIniFile.ReadString('version_info', 'version', '1.0.0')
  then
  begin
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
        on E: Exception do
        begin
          MessageBox(0, PChar(E.message), 'Message', MB_ICONERROR or MB_OK);
        end;
      end;
    finally
      ms.Free;
    end;
  end;
  if run = false then
  begin
    self.AfterUpdater_Run_Apps(FDMemTableCheck.FieldByName('version').AsString + '\' +
      FDMemTableCheck.FieldByName('filename').AsString);
  end;
end;

procedure TmainForm.AfterUpdater_Run_Apps(p_filename: string);
var
  v_filename: string;
begin
  self.FIniFile.WriteString('version_info', 'version', FDMemTableCheck.FieldByName('version').AsString);
  self.FIniFile.WriteString('version_info', 'update_date', FDMemTableCheck.FieldByName('update_date').AsString);
  v_filename := ExtractFileDir(self.GetExeName) + '\' + p_filename;
  ShellExecute(0, PChar('open'), PChar(v_filename), PChar(self.GetExeName), nil, SW_SHOWNORMAL);
  self.TimerTerminateApp.Enabled := true;
end;

end.
