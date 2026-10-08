object MainForm: TMainForm
  Left = 622
  Top = 252
  Caption = 'MySQL Query Browser'
  ClientHeight = 631
  ClientWidth = 862
  Color = clBtnFace
  Constraints.MinHeight = 572
  Constraints.MinWidth = 800
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  KeyPreview = True
  Menu = MainMenu
  OldCreateOrder = False
  Scaled = False
  OnActivate = TntFormActivate
  OnClose = FormClose
  OnCloseQuery = TntFormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnKeyUp = TntFormKeyUp
  PixelsPerInch = 96
  TextHeight = 13
  object StatusBar: TTntStatusBar
    Left = 0
    Top = 612
    Width = 862
    Height = 19
    Panels = <
      item
        Width = 100
      end
      item
        Style = psOwnerDraw
        Width = 50
      end
      item
        Width = 300
      end>
    OnMouseDown = StatusBarMouseDown
    OnDrawPanel = StatusBarDrawPanel
  end
  object MainMenu: TTntMainMenu
    AutoHotkeys = maManual
    Left = 662
    Top = 26
    object FileMI: TTntMenuItem
      Caption = '&File'
      GroupIndex = 10
      object NewInstanceConnectionMI: TTntMenuItem
        Caption = '&New Instance Connection ...'
        GroupIndex = 11
        OnClick = NewInstanceConnectionMIClick
      end
      object ReconnectMI: TTntMenuItem
        Caption = 'R&econnect'
        GroupIndex = 11
        OnClick = ReconnectMIClick
      end
      object N5: TTntMenuItem
        Caption = '-'
        GroupIndex = 11
      end
      object NewResultsetTabMI: TTntMenuItem
        Caption = '&New Resultset Tab'
        GroupIndex = 11
        OnClick = NewResultsetTabMIClick
      end
      object NewSQLScriptTabMI: TTntMenuItem
        Caption = 'Ne&w Script Tab'
        GroupIndex = 11
        OnClick = NewSQLScriptTabMIClick
      end
      object OpenQueryMI: TTntMenuItem
        Caption = '&Open Query ...'
        GroupIndex = 11
        OnClick = OpenQueryMIClick
      end
      object OpenSQLScriptMI: TTntMenuItem
        Caption = 'O&pen Script ...'
        GroupIndex = 11
        OnClick = OpenSQLScriptMIClick
      end
      object ReopenMI: TTntMenuItem
        Caption = 'Reopen'
        Enabled = False
        GroupIndex = 11
      end
      object N2: TTntMenuItem
        Caption = '-'
        GroupIndex = 11
      end
      object SaveMI: TTntMenuItem
        Caption = '&Save'
        Enabled = False
        GroupIndex = 11
        OnClick = SaveMIClick
      end
      object SaveAsMI: TTntMenuItem
        Caption = 'Save &As ...'
        Enabled = False
        GroupIndex = 11
        OnClick = SaveAsMIClick
      end
      object ExportResultsetMI: TTntMenuItem
        Caption = 'E&xport Resultset'
        GroupIndex = 12
      end
      object CloseTabMI: TTntMenuItem
        Caption = '&Close Tab'
        GroupIndex = 13
        OnClick = CloseTabMIClick
      end
      object N3: TTntMenuItem
        Caption = '-'
        GroupIndex = 13
      end
      object ChangeDefaultSchemaMI: TTntMenuItem
        Caption = 'Change &Default Schema ...'
        GroupIndex = 13
        OnClick = ChangeDefaultSchemaMIClick
      end
      object N4: TTntMenuItem
        Caption = '-'
        GroupIndex = 13
      end
      object PageSetupMI: TTntMenuItem
        Caption = 'Page Setup ...'
        Enabled = False
        GroupIndex = 13
      end
      object PrinttoPDFMI: TTntMenuItem
        Caption = 'Print to PDF ...'
        Enabled = False
        GroupIndex = 13
      end
      object PrintMI: TTntMenuItem
        Caption = 'Print ...'
        Enabled = False
        GroupIndex = 13
      end
      object N10: TTntMenuItem
        Caption = '-'
        GroupIndex = 13
      end
      object CloseMI: TTntMenuItem
        Caption = 'Ex&it'
        GroupIndex = 13
        OnClick = CloseMIClick
      end
    end
    object Edit1: TTntMenuItem
      Caption = '&Edit'
      GroupIndex = 20
      object CutMI: TTntMenuItem
        Caption = 'Cut'
        Enabled = False
        OnClick = CutMIClick
      end
      object CopyMI: TTntMenuItem
        Caption = 'Copy'
        Enabled = False
        OnClick = CopyMIClick
      end
      object PasteMI: TTntMenuItem
        Caption = 'Paste'
        Enabled = False
        OnClick = PasteMIClick
      end
      object SelectAllMI: TTntMenuItem
        Caption = 'Select All'
        Enabled = False
        OnClick = SelectAllMIClick
      end
      object N1: TTntMenuItem
        Caption = '-'
      end
      object FindMI: TTntMenuItem
        Caption = 'Find ...'
        OnClick = FindMIClick
      end
    end
    object ViewMenuItem: TTntMenuItem
      Caption = '&View'
      GroupIndex = 30
    end
    object ToolsMI: TTntMenuItem
      Caption = '&Tools'
      GroupIndex = 200
      object MySQLAdministratorMI: TTntMenuItem
        Caption = 'MySQL Administrator'
        OnClick = MySQLAdministratorMIClick
      end
      object MySQLCommandLineClientMI: TTntMenuItem
        Caption = 'MySQL Command Line Client'
        OnClick = MySQLCommandLineClientMIClick
      end
      object N11: TTntMenuItem
        Caption = '-'
      end
      object WindowsCommandLineMI: TTntMenuItem
        Caption = 'Windows Command Line'
        OnClick = WindowsCommandLineMIClick
      end
      object N12: TTntMenuItem
        Caption = '-'
        GroupIndex = 13
      end
      object RegExTextImporterMI: TTntMenuItem
        Caption = 'RegEx Text Importer ...'
        GroupIndex = 13
        OnClick = RegExTextImporterMIClick
      end
      object N9: TTntMenuItem
        Caption = '-'
        GroupIndex = 13
      end
      object ManageConnectionsMI: TTntMenuItem
        Caption = 'Manage Connections ...'
        GroupIndex = 13
        OnClick = ManageConnectionsMIClick
      end
      object SavecurrentConnectionMI: TTntMenuItem
        Caption = 'Save Current Connection ...'
        GroupIndex = 13
        OnClick = SavecurrentConnectionMIClick
      end
      object N14: TTntMenuItem
        Caption = '-'
        GroupIndex = 13
      end
      object OptionsMI: TTntMenuItem
        Caption = 'Options ...'
        GroupIndex = 13
        OnClick = OptionsMIClick
      end
    end
    object WindowMI: TTntMenuItem
      Caption = '&Window'
      GroupIndex = 210
      object WindowDummyMI: TTntMenuItem
        Caption = '0'
      end
    end
    object HelpMI: TTntMenuItem
      Caption = '&Help'
      GroupIndex = 210
      object LaunchHelpMI: TTntMenuItem
        Caption = 'Help'
        OnClick = LaunchHelpMIClick
      end
      object QuickStartGuideMI: TTntMenuItem
        Caption = 'Quick Start Guide'
        OnClick = QuickStartGuideMIClick
      end
      object N8: TTntMenuItem
        Caption = '-'
      end
      object OnlineDocsMI: TTntMenuItem
        Caption = 'Online Docs'
        OnClick = OnlineDocsMIClick
      end
      object OnlineReferenceCAPIMI: TTntMenuItem
        Caption = 'Online Docs - C API'
        OnClick = OnlineReferenceCAPIMIClick
      end
      object OnlineDocsPHPAPIMI: TTntMenuItem
        Caption = 'Online Docs - PHP API'
        OnClick = OnlineDocsPHPAPIMIClick
      end
      object N6: TTntMenuItem
        Caption = '-'
      end
      object VisitMySQLcomMI: TTntMenuItem
        Caption = 'Launch MySQL.com Site'
        OnClick = VisitMySQLcomMIClick
      end
      object N13: TTntMenuItem
        Caption = '-'
      end
      object ListreportedBugsMI: TTntMenuItem
        Caption = 'List Reported Bugs'
        OnClick = ListreportedBugsMIClick
      end
      object ReportBugMI: TTntMenuItem
        Caption = 'Report a New Bug to MySQL'
        OnClick = ReportBugMIClick
      end
      object N7: TTntMenuItem
        Caption = '-'
      end
      object AboutMI: TTntMenuItem
        Caption = 'About'
        OnClick = AboutMIClick
      end
    end
  end
end
