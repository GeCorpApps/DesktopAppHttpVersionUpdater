program AppUpdater;

uses
  System.StartUpCopy,
  FMX.Forms,
  mainUnit in 'mainUnit.pas' {mainForm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TmainForm, mainForm);
  Application.Run;
end.
