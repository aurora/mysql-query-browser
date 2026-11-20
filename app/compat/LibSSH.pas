{ SPDX-License-Identifier: GPL-2.0-or-later }
{ The part of libssh (https://www.libssh.org/, LGPL-2.1-or-later) the SSH tunnel uses (ADR-0048), declared from
  libssh.h of version 0.12. The library is linked dynamically: libssh.so.4 on Linux (the AppImage bundles its own
  build, tools/appimage/build-libssh.sh), libssh.dll from MSYS2 on Windows. Enum values follow the header's order;
  libssh only appends to them. }
unit LibSSH;

{$mode objfpc}{$H+}

interface

uses
  ctypes;

const
  {$IFDEF MSWINDOWS}
  LIB_SSH = 'libssh.dll';
  {$ELSE}
  LIB_SSH = 'ssh';
  {$ENDIF}

  SSH_OK = 0;
  SSH_ERROR = -1;
  SSH_AGAIN = -2;
  SSH_EOF = -127;

  // enum ssh_auth_e
  SSH_AUTH_SUCCESS = 0;
  SSH_AUTH_DENIED = 1;
  SSH_AUTH_PARTIAL = 2;
  SSH_AUTH_INFO = 3;
  SSH_AUTH_AGAIN = 4;
  SSH_AUTH_ERROR = -1;

  SSH_AUTH_METHOD_NONE = $0001;
  SSH_AUTH_METHOD_PASSWORD = $0002;
  SSH_AUTH_METHOD_PUBLICKEY = $0004;
  SSH_AUTH_METHOD_INTERACTIVE = $0010;

  // enum ssh_known_hosts_e
  SSH_KNOWN_HOSTS_ERROR = -2;
  SSH_KNOWN_HOSTS_NOT_FOUND = -1;
  SSH_KNOWN_HOSTS_UNKNOWN = 0;
  SSH_KNOWN_HOSTS_OK = 1;
  SSH_KNOWN_HOSTS_CHANGED = 2;
  SSH_KNOWN_HOSTS_OTHER = 3;

  // enum ssh_publickey_hash_type
  SSH_PUBLICKEY_HASH_SHA1 = 0;
  SSH_PUBLICKEY_HASH_MD5 = 1;
  SSH_PUBLICKEY_HASH_SHA256 = 2;

  // enum ssh_options_e (only the values used; position in the enum)
  SSH_OPTIONS_HOST = 0;
  SSH_OPTIONS_PORT = 1;
  SSH_OPTIONS_USER = 4;
  SSH_OPTIONS_SSH_DIR = 5;
  SSH_OPTIONS_KNOWNHOSTS = 8;
  SSH_OPTIONS_TIMEOUT = 9;
  SSH_OPTIONS_LOG_VERBOSITY = 13;
  SSH_OPTIONS_STRICTHOSTKEYCHECK = 21;
  SSH_OPTIONS_GLOBAL_KNOWNHOSTS = 35;
  SSH_OPTIONS_NODELAY = 36;
  SSH_OPTIONS_PROCESS_CONFIG = 38;
  SSH_OPTIONS_IDENTITY_AGENT = 42;

type
  ssh_session = Pointer;
  ssh_channel = Pointer;
  ssh_key = Pointer;
  Pssh_key = ^ssh_key;
  {$IFDEF MSWINDOWS}
  ssh_socket_t = PtrUInt;
  {$ELSE}
  ssh_socket_t = cint;
  {$ENDIF}
  ssh_auth_callback = function(prompt: PChar; buf: PChar; len: csize_t; echo, verify: cint; userdata: Pointer): cint;
    cdecl;

function ssh_new: ssh_session; cdecl; external LIB_SSH;
procedure ssh_free(session: ssh_session); cdecl; external LIB_SSH;
function ssh_options_set(session: ssh_session; type_: cint; value: Pointer): cint; cdecl; external LIB_SSH;
function ssh_options_parse_config(session: ssh_session; filename: PChar): cint; cdecl; external LIB_SSH;
function ssh_connect(session: ssh_session): cint; cdecl; external LIB_SSH;
procedure ssh_disconnect(session: ssh_session); cdecl; external LIB_SSH;
function ssh_is_connected(session: ssh_session): cint; cdecl; external LIB_SSH;
function ssh_get_error(error: Pointer): PChar; cdecl; external LIB_SSH;
function ssh_get_fd(session: ssh_session): ssh_socket_t; cdecl; external LIB_SSH;
function ssh_send_ignore(session: ssh_session; data: PChar): cint; cdecl; external LIB_SSH;

function ssh_get_server_publickey(session: ssh_session; key: Pssh_key): cint; cdecl; external LIB_SSH;
function ssh_get_publickey_hash(key: ssh_key; type_: cint; hash: PPByte; hlen: pcsize_t): cint; cdecl;
  external LIB_SSH;
function ssh_get_fingerprint_hash(type_: cint; hash: PByte; len: csize_t): PChar; cdecl; external LIB_SSH;
procedure ssh_clean_pubkey_hash(hash: PPByte); cdecl; external LIB_SSH;
procedure ssh_string_free_char(s: PChar); cdecl; external LIB_SSH;
function ssh_session_is_known_server(session: ssh_session): cint; cdecl; external LIB_SSH;
function ssh_session_update_known_hosts(session: ssh_session): cint; cdecl; external LIB_SSH;

function ssh_userauth_none(session: ssh_session; username: PChar): cint; cdecl; external LIB_SSH;
function ssh_userauth_list(session: ssh_session; username: PChar): cint; cdecl; external LIB_SSH;
function ssh_userauth_publickey_auto(session: ssh_session; username, passphrase: PChar): cint; cdecl;
  external LIB_SSH;
function ssh_userauth_publickey(session: ssh_session; username: PChar; privkey: ssh_key): cint; cdecl;
  external LIB_SSH;
function ssh_userauth_password(session: ssh_session; username, password: PChar): cint; cdecl; external LIB_SSH;

function ssh_pki_import_privkey_file(filename, passphrase: PChar; auth_fn: ssh_auth_callback; auth_data: Pointer;
  pkey: Pssh_key): cint; cdecl; external LIB_SSH;
function ssh_pki_import_privkey_base64(b64_key, passphrase: PChar; auth_fn: ssh_auth_callback; auth_data: Pointer;
  pkey: Pssh_key): cint; cdecl; external LIB_SSH;
procedure ssh_key_free(key: ssh_key); cdecl; external LIB_SSH;

function ssh_channel_new(session: ssh_session): ssh_channel; cdecl; external LIB_SSH;
function ssh_channel_open_forward(channel: ssh_channel; remotehost: PChar; remoteport: cint; sourcehost: PChar;
  localport: cint): cint; cdecl; external LIB_SSH;
function ssh_channel_write(channel: ssh_channel; data: Pointer; len: cuint32): cint; cdecl; external LIB_SSH;
function ssh_channel_read_nonblocking(channel: ssh_channel; dest: Pointer; count: cuint32; is_stderr: cint): cint;
  cdecl; external LIB_SSH;
function ssh_channel_poll(channel: ssh_channel; is_stderr: cint): cint; cdecl; external LIB_SSH;
function ssh_channel_is_eof(channel: ssh_channel): cint; cdecl; external LIB_SSH;
function ssh_channel_send_eof(channel: ssh_channel): cint; cdecl; external LIB_SSH;
function ssh_channel_close(channel: ssh_channel): cint; cdecl; external LIB_SSH;
procedure ssh_channel_free(channel: ssh_channel); cdecl; external LIB_SSH;

implementation

end.
