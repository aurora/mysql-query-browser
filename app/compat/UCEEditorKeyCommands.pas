{ SPDX-License-Identifier: GPL-2.0-or-later }
{ UniCodeEditor's key command constants, mapped to SynEdit's command numbers (ADR-0012). The
  names are the original's; only the ones the ported code uses are defined. }
unit UCEEditorKeyCommands;

{$mode delphi}

interface

uses
  SynEditKeyCmds, SynEditMiscClasses;

type
  TEditorCommand = SynEditKeyCmds.TSynEditorCommand;
  TKeyStroke = SynEditKeyCmds.TSynEditKeyStroke;

const
  ecDeleteLastChar = SynEditKeyCmds.ecDeleteLastChar;
  ecUserFirst = SynEditKeyCmds.ecUserFirst;

implementation

end.
