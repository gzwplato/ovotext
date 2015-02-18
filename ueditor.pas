unit ueditor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Dialogs, ComCtrls,
  SynEditTypes, SynEdit, SynGutter, SynGutterMarks, SynGutterChanges, SynGutterLineNumber,
  Stringcostants, Forms, Graphics, Config, udmmain;

type

  TEditor = class;
  TEditorTabSheet = class;
  TEditorFactory = class;

  { TEditorFactory }

  TOnBeforeClose = procedure(Editor: TEditor; var Cancel: boolean) of object;
  TOnEditorEvent = procedure(Editor: TEditor) of object;

  TEditor = class(TSynEdit)
  private
    FFileName: TFilename;
    FSheet: TEditorTabSheet;
    FUntitled: boolean;
    procedure CreateDefaultGutterParts;
    procedure SetFileName(AValue: TFileName);
    procedure SetUntitled(AValue: boolean);

  public
    constructor Create(AOwner: TComponent); override;
    property Sheet: TEditorTabSheet read FSheet;
    //-- Helper functions//
    procedure SetLineText(Index: integer; NewText: string);
    // -- File handling//
    property FileName: TFileName read FFileName write SetFileName;
    property Untitled: boolean read FUntitled write SetUntitled;
    procedure LoadFromFile(AFileName: TFileName);
    function Save: boolean;
    function SaveAs(AFileName: TFileName): boolean;
  end;

  { TEditorTabSheet }

  TEditorTabSheet = class(TTabSheet)
  private
    FEditor: TEditor;
  protected
    procedure DoShow; override;

  public
    property Editor: TEditor read FEditor;
    //--//
  end;


  TEditorFactory = class(TPageControl)
  private
    FOnBeforeClose: TOnBeforeClose;
    FOnNewEditor: TOnEditorEvent;
    FonStatusChange: TStatusChangeEvent;
    fUntitledCounter: integer;
    function GetCurrentEditor: TEditor;
    procedure SetOnBeforeClose(AValue: TOnBeforeClose);
    procedure SetOnNewEditor(AValue: TOnEditorEvent);
    procedure ShowHintEvent(Sender: TObject; HintInfo: PHintInfo);
    function CreateEmptyFile(AFileName: TFileName): boolean;
  protected
    procedure DoChange; override;
  public
    property CurrentEditor: TEditor read GetCurrentEditor;
    property OnStatusChange: TStatusChangeEvent read FonStatusChange write FOnStatusChange;
    property OnBeforeClose: TOnBeforeClose read FOnBeforeClose write SetOnBeforeClose;
    property OnNewEditor: TOnEditorEvent read FOnNewEditor write SetOnNewEditor;
    //--//
    procedure DoCloseTabClicked(APage: TCustomPage); override;
    function AddEditor(FileName: TFilename = ''): TEditor;
    function CloseEditor(Editor: TEditor): boolean;
    function CloseAll: boolean;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

uses lclproc;

{ TEditorTabSheet }

procedure TEditorTabSheet.DoShow;
begin
  inherited DoShow;

end;

{ TEditor }

procedure TEditor.SetFileName(AValue: TFileName);
begin
  if FFileName = AValue then
    Exit;

  FFileName := AValue;
  if FFileName <> EmptyStr then
    FUntitled := False;
end;

procedure TEditor.SetUntitled(AValue: boolean);
begin
  if FUntitled = AValue then
    Exit;

  FUntitled := AValue;
  if FUntitled then
    FFileName := EmptyStr;
end;

constructor TEditor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  CreateDefaultGutterParts;
end;

procedure TEditor.SetLineText(Index: integer; NewText: string);
begin
  TextBetweenPoints[Point(1, Index + 1), PhysicalToLogicalPos(Point(Length(Lines[Index]) + 1, Index + 1))] := NewText;
end;

procedure TEditor.LoadFromfile(AFileName: TFileName);
begin
  FFileName := AFileName;
  Lines.LoadFromFile(FFileName);
  Highlighter := dmMain.getHighLighter(ExtractFileExt(fFileName));
  FSheet.Caption := ExtractFileName(fFileName);
  FUntitled := False;

end;

function TEditor.Save: boolean;
begin
  Result := SaveAs(FFileName);
end;

function TEditor.SaveAs(AFileName: TFileName): boolean;
var
  Retry: boolean;
begin
  repeat
    Retry := False;
    try
      FFileName := AFileName;
      Lines.SaveToFile(AFileName);
      Result := True;
      FUntitled := False;
      Modified := False;
    except
      Result := False;
    end;

    if not Result then
      begin
        case MessageDlg(RSError, Format(RSCannotSave, [fFileName]), mtError, [mbRetry, mbCancel, mbIgnore], 0) of
          mrAbort: Result := False;
          mrIgnore: Result := True;
          mrRetry: Retry := True;
        end;
      end;
  until not Retry;

end;

function TEditorFactory.CreateEmptyFile(AFileName: TFileName): boolean;
var
  fs: TFileStream;
  Retry: boolean;
begin
  repeat
    Retry := False;
    try
      fs := TFileStream.Create(AFileName, fmCreate);
      fs.Free;
      Result := True;
    except
      Result := False;
    end;

    if not Result then
      begin
        case MessageDlg(RSError, Format(RSCannotCreate, [AFileName]), mtError, [mbRetry, mbAbort], 0) of
          mrAbort: Result := False;
          mrRetry: Retry := True;
        end;
      end;
  until not Retry;

end;

procedure TEditor.CreateDefaultGutterParts;
begin
  Gutter.Parts.Clear;
  with TSynGutterMarks.Create(Gutter.Parts) do
    Name := 'SynGutterMarks1';
  with TSynGutterLineNumber.Create(Gutter.Parts) do
    Name := 'SynGutterLineNumber1';
  with TSynGutterChanges.Create(Gutter.Parts) do
    Name := 'SynGutterChanges1';
end;

{ TEditorFactory }

function TEditorFactory.GetCurrentEditor: TEditor;
begin
  Result := nil;
  if (PageCount > 0) and (ActivePageIndex >= 0) then
    Result := TEditorTabSheet(ActivePage).Editor;

end;

procedure TEditorFactory.SetOnBeforeClose(AValue: TOnBeforeClose);
begin
  if FOnBeforeClose = AValue then
    Exit;
  FOnBeforeClose := AValue;
end;

procedure TEditorFactory.SetOnNewEditor(AValue: TOnEditorEvent);
begin
  if FOnNewEditor = AValue then
    Exit;
  FOnNewEditor := AValue;
end;

procedure TEditorFactory.DoChange;
begin
  inherited DoChange;
  //  Hint := TEditorTabSheet(ActivePage).Editor.FileName;
  if Assigned(OnStatusChange) then
    OnStatusChange(GetCurrentEditor, [scCaretX, scCaretY, scModified, scInsertMode]);

  TEditorTabSheet(ActivePage).Editor.SetFocus;
end;

procedure TEditorFactory.DoCloseTabClicked(APage: TCustomPage);
begin
  inherited DoCloseTabClicked(APage);
  if Assigned(APage) and (APage is TEditorTabSheet) then
    CloseEditor(TEditorTabSheet(APage).FEditor);
end;

function TEditorFactory.AddEditor(FileName: TFilename = ''): TEditor;
var
  Sheet: TEditorTabSheet;
  i: integer;
  DefaultAttr: TFontAttributes;
begin
  if FileName <> EmptyStr then
    begin
    // do not reopen same file
    for i := 0 to PageCount - 1 do
      begin
        Sheet := TEditorTabSheet(Pages[i]);
        if Sheet.Editor.FileName = FileName then
          begin
            ActivePageIndex := i;
            exit;
          end;
      end;

    if (FileName <> EmptyStr) and not FileExists(FileName) then
      begin
        case MessageDlg('', format(RSAskFileCreation, [FileName]), mtConfirmation, [mbYes, mbNo], 0) of
          mrNo: Exit;
          mrYes: if not CreateEmptyFile(FileName) then
              Exit;
        end;
      end;

    // try to reuse an empty sheet
    for i := 0 to PageCount - 1 do
      begin
        Sheet := TEditorTabSheet(Pages[i]);
        if (Sheet.Editor.Untitled) and not Sheet.Editor.Modified then
          begin
            Sheet.Editor.LoadFromfile(FileName);
            ActivePageIndex := i;
            exit;
          end;
        end;

    end;

  Sheet := TEditorTabSheet.Create(Self);
  Sheet.PageControl := Self;

  Result := TEditor.Create(Sheet);
  Result.Font.Assign(ConfigObj.Font);
  DefaultAttr := ConfigObj.ReadFontAttributes('Default/Text/', FontAttributes());

  Result.FSheet := Sheet;

  Result.Align := alClient;
  Sheet.FEditor := Result;

  Result.Font.Color := DefaultAttr.Foreground;
  Result.Font.Style := DefaultAttr.Styles;

  Result.Color := DefaultAttr.Background;

  Result.Options := Result.Options + [eoHideRightMargin];
  Result.BookMarkOptions.BookmarkImages := dmMain.imgBookMark;

  Result.OnStatusChange := OnStatusChange;
  if Assigned(OnStatusChange) then
    OnStatusChange(Result, [scCaretX, scCaretY, scModified, scInsertMode]);

  Result.Parent := Sheet;
  if FileName = EmptyStr then
    begin
      Sheet.Caption := Format(RSNewFile, [fUntitledCounter]);
      Result.FUntitled := True;
      Inc(fUntitledCounter);
    end
  else
    Result.LoadFromfile(FileName);

  ActivePage := Sheet;

  if Assigned(FOnNewEditor) then
    FOnNewEditor(Result);

end;

function TEditorFactory.CloseEditor(Editor: TEditor): boolean;
var
  Sheet: TEditorTabSheet;
begin
  Result := True;
  // if last tab in unused
  if (PageCount = 1) and Editor.Untitled and not Editor.Modified and not ConfigObj.AppSettings.CloseWithLastTab then
    exit;

  if Assigned(FOnBeforeClose) then
    FOnBeforeClose(Editor, Result);

  if not Result then
    begin
      Sheet := Editor.FSheet;
      Editor.PopupMenu := nil;
      Application.ReleaseComponent(Editor);
      Application.ReleaseComponent(Sheet);
      Application.ProcessMessages;
      if (PageCount = 0) and not ConfigObj.AppSettings.CloseWithLastTab then
        AddEditor();
    end;

end;

function TEditorFactory.CloseAll: boolean;
var
  i: integer;
begin
  for i := PageCount - 1 downto 0 do
    if not CloseEditor(TEditorTabSheet(Pages[i]).Editor) then
      break;
end;

procedure TEditorFactory.ShowHintEvent(Sender: TObject; HintInfo: PHintInfo);
var
  Tab: integer;

begin
  if (PageCount = 0) or (HintInfo = nil) then
    Exit;
  Tab := TabIndexAtClientPos(ScreenToClient(Mouse.CursorPos));

  if Tab < 0 then
    Exit;

  HintInfo^.HintStr := TEditorTabSheet(Pages[Tab]).Editor.FileName;

end;

constructor TEditorFactory.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fUntitledCounter := 0;
  Options := Options + [nboShowCloseButtons];
  OnShowHint := @ShowHintEvent;
end;

destructor TEditorFactory.Destroy;
begin
  inherited Destroy;
end;



end.
