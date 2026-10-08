{ SPDX-License-Identifier: GPL-2.0-or-later }
{ The original code uses VirtualTreeView 4.x: `uses VirtualTrees`, class TVirtualStringTree.
  Lazarus ships a port (unit laz.VirtualTrees, class TLazVirtualStringTree). Ported units use
  `laz.VirtualTrees, VTCompat`; this unit supplies the original class name, also for loading
  .lfm files. Event and property signatures of the newer VirtualTreeView differ in places and
  are fixed in the ported units. }
unit VTCompat;

{$mode delphi}

interface

uses
  Classes, laz.VirtualTrees;

type
  TVirtualStringTree = TLazVirtualStringTree;

implementation

initialization
  RegisterClassAlias(TLazVirtualStringTree, 'TVirtualStringTree');

end.
