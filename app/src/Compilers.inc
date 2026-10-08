{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Replacement for the original Compilers.inc (which detects Delphi versions from VERxxx symbols).
  The sources were written for Delphi 2006 (compiler version 10); FPC gets the same symbols so
  that the conditional code keeps taking the Delphi 2006 branches. }

{$define DELPHI}
{$define COMPILER_10}
{$define COMPILER_1_UP}
{$define DELPHI_1_UP}
{$define COMPILER_2_UP}
{$define DELPHI_2_UP}
{$define COMPILER_3_UP}
{$define DELPHI_3_UP}
{$define COMPILER_4_UP}
{$define DELPHI_4_UP}
{$define COMPILER_5_UP}
{$define DELPHI_5_UP}
{$define COMPILER_6_UP}
{$define DELPHI_6_UP}
{$define COMPILER_7_UP}
{$define DELPHI_7_UP}
{$define COMPILER_8_UP}
{$define DELPHI_8_UP}
{$define COMPILER_9_UP}
{$define DELPHI_9_UP}
{$define COMPILER_10_UP}
{$define DELPHI_10_UP}
{$define DELPHI_10}
