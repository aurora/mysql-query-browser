object QueryBrowserOptionPagesForm: TQueryBrowserOptionPagesForm
  Left = 556
  Top = 319
  AutoScroll = False
  Caption = 'QueryBrowserOptionPagesForm'
  ClientHeight = 372
  ClientWidth = 577
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Scaled = False
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    577
    372)
  PixelsPerInch = 96
  TextHeight = 16
  object OptionPageControl: TTntPageControl
    Left = 0
    Top = 0
    Width = 577
    Height = 362
    ActivePage = BrowserTabSheet
    Anchors = [akLeft, akTop, akRight]
    Style = tsFlatButtons
    TabHeight = 16
    TabOrder = 0
    object BrowserTabSheet: TTntTabSheet
      Caption = 'Browser'
      ImageIndex = 2
      DesignSize = (
        569
        336)
      object GroupBox4: TTntGroupBox
        Left = 0
        Top = 6
        Width = 565
        Height = 103
        Anchors = [akLeft, akTop, akRight]
        Caption = 'Display Options'
        TabOrder = 0
        object ShowAdvancedToolbarMI: TTntCheckBox
          Left = 16
          Top = 46
          Width = 261
          Height = 17
          Caption = 'Show advanced toolbars'
          TabOrder = 2
          OnClick = DoChange
        end
        object HideTabWhenOneOpenCBox: TTntCheckBox
          Left = 278
          Top = 20
          Width = 279
          Height = 17
          Caption = 'Hide the tab when only one page is open'
          TabOrder = 0
          OnClick = DoChange
        end
        object ToolbarGradientCBox: TTntCheckBox
          Left = 16
          Top = 20
          Width = 261
          Height = 17
          Caption = 'Toolbars use a gradient background'
          TabOrder = 1
          OnClick = DoChange
        end
        object ShowFieldOverlayImagesCBox: TTntCheckBox
          Left = 16
          Top = 72
          Width = 261
          Height = 17
          Caption = 'Show field overlay images for BLOB fields'
          TabOrder = 3
          OnClick = DoChange
        end
        object ShowMouseCursorToolbarGroupCBox: TTntCheckBox
          Left = 278
          Top = 46
          Width = 279
          Height = 17
          Caption = 'Show composer buttons toolbar'
          TabOrder = 4
          OnClick = DoChange
        end
      end
      object TntGroupBox1: TTntGroupBox
        Left = 0
        Top = 118
        Width = 565
        Height = 153
        Anchors = [akLeft, akTop, akRight]
        Caption = 'Query Options'
        TabOrder = 1
        DesignSize = (
          565
          153)
        object TntLabel1: TTntLabel
          Left = 390
          Top = 73
          Width = 84
          Height = 16
          Alignment = taRightJustify
          Anchors = [akTop, akRight]
          Caption = 'Substitude LF:'
        end
        object TntLabel2: TTntLabel
          Left = 241
          Top = 73
          Width = 88
          Height = 16
          Alignment = taRightJustify
          Anchors = [akTop, akRight]
          Caption = 'Substitude CR:'
        end
        object EnforceEditableQueriesCBox: TTntCheckBox
          Left = 16
          Top = 20
          Width = 537
          Height = 17
          Caption = 
            'Enforce queries to be editable by adding primary key columns to ' +
            'the select'
          TabOrder = 0
          OnClick = DoChange
        end
        object OpenExportedResultsetCBox: TTntCheckBox
          Left = 16
          Top = 46
          Width = 537
          Height = 17
          Caption = 'Open resultset in associated application after export'
          TabOrder = 1
          OnClick = DoChange
        end
        object EnableFriendlyLineBreaksCBox: TTntCheckBox
          Left = 16
          Top = 72
          Width = 183
          Height = 17
          Caption = 'Enable friendly line breaks'
          TabOrder = 2
          OnClick = DoChange
        end
        object SubstLFLU: TTntComboBox
          Left = 480
          Top = 69
          Width = 47
          Height = 24
          Anchors = [akTop, akRight]
          ItemHeight = 16
          TabOrder = 3
          OnChange = DoChange
          Items.WideStrings = (
            #182
            #172
            #166)
          Items.WideStrings_UTF7 = (
            '+ALY'
            '+AKw'
            '+AKY')
        end
        object SubstCRLU: TTntComboBox
          Left = 336
          Top = 69
          Width = 47
          Height = 24
          Anchors = [akTop, akRight]
          ItemHeight = 16
          TabOrder = 4
          OnChange = DoChange
          Items.WideStrings = (
            #183
            #172
            #187)
          Items.WideStrings_UTF7 = (
            '+ALc'
            '+AKw'
            '+ALs')
        end
        object CreateWindowsStyleLineBreaksCBox: TTntCheckBox
          Left = 16
          Top = 98
          Width = 277
          Height = 17
          Caption = 'Create Windows style line breaks (LF CR)'
          TabOrder = 5
          OnClick = DoChange
        end
        object AlignNumericColsRightCBox: TTntCheckBox
          Left = 16
          Top = 122
          Width = 239
          Height = 17
          Caption = 'Align numeric columns to the right'
          TabOrder = 6
          OnClick = DoChange
        end
      end
      object TntGroupBox2: TTntGroupBox
        Left = 0
        Top = 280
        Width = 561
        Height = 51
        Anchors = [akLeft, akTop, akRight]
        Caption = 'Various'
        TabOrder = 2
        object AssociateFileExtensionsCBox: TTntCheckBox
          Left = 16
          Top = 20
          Width = 495
          Height = 17
          Caption = 'Associate sql/query files with Query Browser'
          TabOrder = 0
          OnClick = DoChange
        end
      end
    end
  end
end
