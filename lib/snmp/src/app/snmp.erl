%%
%% %CopyrightBegin%
%%
%% Copyright Ericsson AB 1996-2022. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% %CopyrightEnd%
%%
-module(snmp).


%%----------------------------------------------------------------------
%% This module contains the user interface to the snmp toolkit.
%%----------------------------------------------------------------------

%% Application exports
-export([start/0, start/1, stop/0, 
	 start_agent/0,   start_agent/1, 
	 start_manager/0, start_manager/1, 
	 config/0,
	 
         versions1/0,      versions2/0,
	 print_versions/1, print_versions/2, 
	 print_version_info/0, print_version_info/1, 
 
	 date_and_time/0, 
	 universal_time_to_date_and_time/1,
	 local_time_to_date_and_time_dst/1, 
	 date_and_time_to_universal_time_dst/1,
	 validate_date_and_time/1, validate_date_and_time/2, 
	 date_and_time_to_string/1, date_and_time_to_string/2, 
	 date_and_time_to_string2/1, 

	 str_apply/1,

	 sys_up_time/1, system_start_time/1,

         passwd2localized_key/3, localize_key/3,

	 read_mib/1, 
 
	 log_to_txt/5, log_to_txt/6, log_to_txt/7, log_to_txt/8, 
	 log_to_io/4,  log_to_io/5,  log_to_io/6,  log_to_io/7, 
	 change_log_size/2,

	 octet_string_to_bits/1, bits_to_octet_string/1, 

	 enable_trace/0, disable_trace/0, 
	 set_trace/1, reset_trace/1, 
	 set_trace/2, set_trace/3]).

-export_type([
	      dir/0, 
	      snmp_timer/0, 

              atl_type/0,
              verbosity/0,

	      engine_id/0, 
	      tdomain/0, 
	      community/0, 
	      mms/0, 
	      version/0, 
	      sec_model/0, 
	      sec_name/0, 
	      sec_level/0, 

	      oid/0,
	      varbind/0, 
	      ivarbind/0, 
	      asn1_type/0, 
	      table_info/0, 
	      variable_info/0, 
	      me/0, 
	      trap/0, 
	      notification/0, 
	      pdu/0, 
	      trappdu/0, 
	      mib/0, 
	      mib_name/0,
              pdu_type/0,

              error_status/0,
              error_index/0,
 
	      void/0
	     ]).


%% This is for XREF
%% -deprecated(
%%    [
%%    ]).
 

-define(APPLICATION, snmp).
-define(ATL_BLOCK_DEFAULT, true).

-include_lib("snmp/include/snmp_types.hrl").


%%-----------------------------------------------------------------
%% Types
%%-----------------------------------------------------------------

-type dir()           :: string().
-type snmp_timer()    :: #snmp_incr_timer{}.

-type atl_type()      :: read | write | read_write.
-type verbosity()     :: info | log | debug | trace | silence.

-type engine_id()     :: string().
-type tdomain()       :: transportDomainUdpIpv4 | transportDomainUdpIpv6.
-type community()     :: string().
-type mms()           :: non_neg_integer().
-type version()       :: v1 | v2 | v3.
-type sec_model()     :: any | v1 | v2c | usm.
-type sec_name()      :: string().
-type sec_level()     :: noAuthNoPriv | authNoPriv | authPriv.

-type oid()           :: [non_neg_integer()].
-type varbind()       :: #varbind{}.
-type ivarbind()      :: #ivarbind{}.
-type asn1_type()     :: #asn1_type{}.
-type table_info()    :: #table_info{}.
-type variable_info() :: #variable_info{}.
-type me()            :: #me{}.
-type trap()          :: #trap{}.
-type notification()  :: #notification{}.
-type mib()           :: #mib{}.
-type mib_name()      :: string().
-type pdu()           :: #pdu{}.
-type trappdu()       :: #trappdu{}.
-type pdu_type()      :: 'get-request' | 'get-next-request' | 'get-response' |
                         'set-request' | 'trap' | 'get-bulk-request' | 'inform-request' |
                         'report'.

%% We should really specify all of these, but they are so numerous...
%% See the validate_err/1 function in the snmpa_agent.
%% Here are a number of them:
%% badValue |
%% commitFailed |
%% genErr |
%% inconsistentName | inconsistentValue |
%% noAccess | noCreation |
%% noSuchInstance | noSuchName | noSuchObject |
%% notWritable |
%% resourceUnavailable |
%% undoFailed |
%% wrongValue

-type error_status()  :: atom().
-type error_index()   :: pos_integer().

-type void()          :: term().


%%-----------------------------------------------------------------
%% Application
%%-----------------------------------------------------------------

start() ->
    application:start(?APPLICATION).

stop() ->
    application:stop(?APPLICATION).

start(p) ->
    start(permanent);
start(tr) ->
    start(transient);
start(te) ->
    start(temporary);
start(Type) ->
    application:start(?APPLICATION, Type).


start_agent() ->
    snmp_app:start_agent().

start_agent(Type) ->
    snmp_app:start_agent(Type).

start_manager() ->
    snmp_app:start_manager().

start_manager(Type) ->
    snmp_app:start_manager(Type).


config() -> snmp_config:config().


%%-----------------------------------------------------------------

enable_trace() ->
    HandleSpec = {fun handle_trace_event/2, dummy},
    dbg:tracer(process, HandleSpec).

disable_trace() ->    
    dbg:stop().

set_trace(Module) when is_atom(Module) ->
    set_trace([Module]);
set_trace(Modules) when is_list(Modules) ->
    Opts = [], % Use default values for all options
    set_trace(Modules, Opts).

reset_trace(Module) when is_atom(Module) ->
    set_trace(Module, disable);
reset_trace(Modules) when is_list(Modules) ->
    set_trace(Modules, disable).

set_trace(Module, disable) when is_atom(Module) ->
    dbg:ctp(Module);
set_trace(Module, Opts) when is_atom(Module) andalso is_list(Opts) ->
    (catch set_trace(all, Module, Opts));
set_trace(Modules, Opts) when is_list(Modules) ->
    (catch set_trace(all, Modules, Opts)).

set_trace(Item, Module, Opts) when is_atom(Module) ->
    set_trace(Item, [{Module, []}], Opts);
set_trace(_Item, Modules, disable) when is_list(Modules) ->
    DisableTrace = 
	fun(Module) when is_atom(Module) ->
		dbg:ctp(Module);
	   (_) ->
		ok
	end,
    lists:foreach(DisableTrace, Modules);
set_trace(Item, Modules, Opts) when is_list(Modules) ->
    Mods = parse_modules(Modules, Opts),
    SetTrace = 
	fun({Module, ModOpts}) -> 
		set_module_trace(Module, ModOpts)
	end,
    lists:foreach(SetTrace, Mods),
    Flags = 
	case lists:keysearch(timestamp, 1, Opts) of
	    {value, {timestamp, false}} ->
		[call];
	    _ ->
		[call, timestamp]
	end,
    case dbg:p(Item, Flags) of
	{ok, _} ->
	    ok;
	Error ->
	    Error
    end.

set_module_trace(Module, disable) ->
    dbg:ctp(Module);
set_module_trace(Module, Opts) ->
    ReturnTrace = 
	case lists:keysearch(return_trace, 1, Opts) of
	    {value, {return_trace, false}} ->
		[];
	    _ ->
		%% Default is always  to include return values
		[{return_trace}]
	end,
    TraceRes = 
	case lists:keysearch(scope, 1, Opts) of
	    {value, {scope, all_functions}} ->
		dbg:tpl(Module, [{'_', [], ReturnTrace}]);
	    {value, {scope, exported_functions}}  ->
		dbg:tp(Module, [{'_', [], ReturnTrace}]);
	    {value, {scope, Func}}  when is_atom(Func) ->
		dbg:tpl(Module, Func, [{'_', [], ReturnTrace}]);
	    {value, {scope, {Func, Arity}}}  when is_atom(Func) andalso 
						  is_integer(Arity) ->
		dbg:tpl(Module, Func, Arity, [{'_', [], ReturnTrace}]);
	    false ->
	    %% Default scope is exported functions
		dbg:tp(Module, [{'_', [], ReturnTrace}])
	end,
    case TraceRes of
	{error, Reason} ->
	    throw({error, {failed_enabling_trace, Module, Opts, Reason}});
	_ ->
	    ok
    end.


parse_modules(Modules, Opts) ->
    parse_modules(Modules, Opts, []).

parse_modules([], _Opts, Acc) ->
    lists:reverse(Acc);

parse_modules([Module|Modules], Opts, Acc) 
  when is_atom(Module) andalso is_list(Opts) ->
    parse_modules(Modules, Opts, [{Module, Opts}|Acc]);

parse_modules([{Module, ModOpts}|Modules], Opts, Acc) 
  when is_atom(Module) andalso is_list(ModOpts) andalso is_list(Opts) ->
    NewModOpts = update_trace_options(Opts, ModOpts),
    parse_modules(Modules, Opts, [{Module, NewModOpts}|Acc]);

parse_modules([_|Modules], Opts, Acc) ->
    parse_modules(Modules, Opts, Acc).


update_trace_options([], Opts) ->
    Opts;
update_trace_options([{Key, _} = Opt|Opts], ModOpts) ->
    case lists:keysearch(Key, 1, ModOpts) of
	{value, _} ->
	    update_trace_options(Opts, ModOpts);
	_ ->
	    update_trace_options(Opts, [Opt|ModOpts])
    end;
update_trace_options([_|Opts], ModOpts) ->
    update_trace_options(Opts, ModOpts).


handle_trace_event({trace, Who, call, Event}, Data) ->
    io:format("*** call trace event *** "
	      "~n   Who:   ~p"
	      "~n   Event: ~p"
	      "~n", [Who, Event]),
    Data;
handle_trace_event({trace, Who, return_from, Func, Value}, Data) ->
    io:format("*** return trace event *** "
	      "~n   Who:      ~p"
	      "~n   Function: ~p"
	      "~n   Value:    ~p"
	      "~n", [Who, Func, Value]),
    Data;
handle_trace_event({trace_ts, Who, call, {Mod, Func, Args}, Ts}, Data) 
  when is_atom(Mod) andalso is_atom(Func) andalso is_list(Args) ->
    io:format("*** call trace event ~s *** "
	      "~n   Who:  ~p"
	      "~n   Mod:  ~p"
	      "~n   Func: ~p"
	      "~n   Args: ~p"
	      "~n", [format_timestamp(Ts), Who, Mod, Func, Args]),
    Data;
handle_trace_event({trace_ts, Who, call, Event, Ts}, Data) ->
    io:format("*** call trace event ~s *** "
	      "~n   Who:   ~p"
	      "~n   Event: ~p"
	      "~n", [format_timestamp(Ts), Who, Event]),
    Data;
handle_trace_event({trace_ts, Who, return_from, {Mod, Func, Arity}, Value, Ts},
		   Data) 
  when is_atom(Mod) andalso is_atom(Func) andalso is_integer(Arity) ->
    io:format("*** return trace event ~s *** "
	      "~n   Who:   ~p"
	      "~n   Mod:   ~p"
	      "~n   Func:  ~p"
	      "~n   Arity: ~p"
	      "~n   Value: ~p"
	      "~n", [format_timestamp(Ts), Who, Mod, Func, Arity, Value]),
    Data;
handle_trace_event({trace_ts, Who, return_from, Func, Value, Ts}, Data) ->
    io:format("*** return trace event ~s *** "
	      "~n   Who:      ~p"
	      "~n   Function: ~p"
	      "~n   Value:    ~p"
	      "~n", [format_timestamp(Ts), Who, Func, Value]),
    Data;
handle_trace_event(TraceEvent, Data) ->
    io:format("*** trace event *** "
	      "~n   TraceEvent: ~p"
	      "~n", [TraceEvent]),
    Data.

format_timestamp({_N1, _N2, N3} = Now) ->
    {Date, Time}   = calendar:now_to_datetime(Now),
    {YYYY,MM,DD}   = Date,
    {Hour,Min,Sec} = Time,
    FormatDate =
        io_lib:format("~.4w:~.2.0w:~.2.0w ~.2.0w:~.2.0w:~.2.0w 4~w",
                      [YYYY,MM,DD,Hour,Min,Sec,round(N3/1000)]),
    lists:flatten(FormatDate).


%%-----------------------------------------------------------------
%% {ok, Vs} = snmp:versions1(), snmp:print_versions(Vs).

print_version_info() ->
    {ok, Vs} = versions1(),
    print_versions(Vs).

print_version_info(Prefix) ->
    {ok, Vs} = versions1(),
    print_versions(Prefix, Vs).

print_versions(Versions) ->
    print_versions("", Versions).

print_versions(Prefix, Versions) 
  when is_list(Prefix) andalso is_list(Versions) ->
    do_print_versions(Prefix, Versions);
print_versions(Prefix, Versions) 
  when (is_integer(Prefix) andalso (Prefix >= 0)) andalso is_list(Versions) ->
    do_print_versions(lists:duplicate(Prefix, $ ), Versions);
print_versions(Prefix, BadVersions) 
  when is_list(Prefix) orelse (is_integer(Prefix) andalso (Prefix >= 0)) ->
    {error, {bad_versions, BadVersions}};
print_versions(Prefix, BadVersions) 
  when is_list(BadVersions) ->
    {error, {bad_prefix, Prefix}};
print_versions(Prefix, BadVersions) -> 
    {error, {bad_args, Prefix, BadVersions}}.

do_print_versions(Prefix, Versions) ->
    print_sys_info(Prefix, Versions),
    print_os_info(Prefix, Versions),
    print_mods_info(Prefix, Versions).

print_sys_info(Prefix, Versions) ->
    case key1search(sys_info, Versions) of
        {value, SysInfo} when is_list(SysInfo) ->
            {value, Arch} = key1search(arch, SysInfo, "Not found"),
            {value, Ver}  = key1search(ver, SysInfo, "Not found"),
            io:format("~sSystem info: "
                      "~n~s   Arch: ~s"
                      "~n~s   Ver:  ~s"
                      "~n", [Prefix, 
			     Prefix, Arch, 
			     Prefix, Ver]),
            ok;
        _ ->
            io:format("System info: Not found~n", []),
            not_found
    end.

print_os_info(Prefix, Versions) ->
    case key1search(os_info, Versions) of
        {value, OsInfo} when is_list(OsInfo) ->
            Fam =
                case key1search(fam, OsInfo, "Not found") of
                    {value, F} when is_atom(F) ->
                        atom_to_list(F);
                    {value, LF} when is_list(LF) ->
                        LF;
                    {value, XF} ->
                        lists:flatten(io_lib:format("~p", [XF]))
                end,
            Name =
                case key1search(name, OsInfo) of
                    {value, N} when is_atom(N) ->
                        "[" ++ atom_to_list(N) ++ "]";
                    {value, LN} when is_list(LN) ->
                        "[" ++ LN ++ "]";
                    not_found ->
                        ""
                end,
            Ver =
                case key1search(ver, OsInfo, "Not found") of
                    {value, T} when is_tuple(T) ->
                        tversion(T);
                    {value, LV} when is_list(LV) ->
                        LV;
                    {value, XV} ->
                        lists:flatten(io_lib:format("~p", [XV]))
                end,
            io:format("~sOS info: "
                      "~n~s   Family: ~s ~s"
                      "~n~s   Ver:    ~s"
                      "~n", [Prefix, 
			     Prefix, Fam, Name, 
			     Prefix, Ver]),
            ok;
        _ ->
            io:format("~sOS info:     Not found~n", [Prefix]),
            not_found
    end.

tversion(T) ->
    L = tuple_to_list(T),
    lversion(L).

lversion([]) ->
    "";
lversion([A]) ->
    integer_to_list(A);
lversion([A|R]) ->
    integer_to_list(A) ++ "." ++ lversion(R).

print_mods_info(Prefix, Versions) ->
    case key1search(mod_info, Versions) of
        {value, ModsInfo} when is_list(ModsInfo) ->
            io:format("~sModule info: ~n", [Prefix]),
	    F = fun(MI) -> print_mod_info(Prefix, MI) end,
            lists:foreach(F, ModsInfo);
        _ ->
            io:format("~sModule info: Not found~n", [Prefix]),
            not_found
    end.

print_mod_info(Prefix, {Module, Info}) ->
    Vsn =
        case key1search(vsn, Info) of
            {value, I} when is_integer(I) ->
                integer_to_list(I);
            _ ->
                "Not found"
        end,
    AppVsn =
        case key1search(app_vsn, Info) of
            {value, S1} when is_list(S1) ->
                S1;
            _ ->
                "Not found"
        end,
    CompVer =
        case key1search(compiler_version, Info) of
            {value, S2} when is_list(S2) ->
                S2;
            _ ->
                "Not found"
        end,
    Digest =
        case key1search(md5, Info) of
            {value, MD5} when is_binary(MD5) ->
		[io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= MD5];
            _ ->
                "Not found"
        end,
    io:format("~s   ~w:~n"
              "~s      Vsn:          ~s~n"
              "~s      App vsn:      ~s~n"
              "~s      Compiler ver: ~s~n"
              "~s      MD5 digest:   ~s~n",
              [Prefix, Module, 
	       Prefix, Vsn, 
	       Prefix, AppVsn, 
	       Prefix, CompVer,
	       Prefix, Digest]),
    ok.

key1search(Key, Vals) ->
    case lists:keysearch(Key, 1, Vals) of
        {value, {Key, Val}} ->
            {value, Val};
        false ->
            not_found
    end.

key1search(Key, Vals, Def) ->
    case key1search(Key, Vals) of
	not_found ->
	    {value, Def};
	Value ->
	    Value
    end.


%%-----------------------------------------------------------------

versions1() ->
    case ms1() of
        {ok, Mods} ->
            {ok, version_info(Mods)};
        Error ->
            Error
    end.

versions2() ->
    case ms2() of
        {ok, Mods} ->
            {ok, version_info(Mods)};
        Error ->
            Error
    end.

version_info(Mods) ->
    SysInfo = sys_info(),
    OsInfo  = os_info(),
    ModInfo = [mod_version_info(Mod) || Mod <- Mods],
    [{sys_info, SysInfo}, {os_info, OsInfo}, {mod_info, ModInfo}].

mod_version_info(Mod) ->
    Info = Mod:module_info(),
    {Mod,
     case key1search(attributes, Info) of
	 {value, Attr} ->
	     case key1search(vsn, Attr) of
		 {value, [Vsn]} ->
		     [{vsn, Vsn}];
		 not_found ->
		     []
	     end ++
		 case key1search(app_vsn, Attr) of
		     {value, AppVsn} ->
			 [{app_vsn, AppVsn}];
		     not_found ->
			 []
		 end;
	 not_found ->
	     []
     end ++
	 case key1search(compile, Info) of
	     {value, Comp} ->
		 case key1search(version, Comp) of
		     {value, Ver} ->
			 [{compiler_version, Ver}];
		     not_found ->
			 []
		 end;
	     not_found ->
		 []
	 end ++
	 case key1search(md5, Info) of
	     {value, Bin} ->
		 [{md5, Bin}];
	     not_found ->
		 []
	 end}.

sys_info() ->
    SysArch = string:strip(erlang:system_info(system_architecture),right,$\n),
    SysVer  = string:strip(erlang:system_info(system_version),right,$\n),
    [{arch, SysArch}, {ver, SysVer}].
 
os_info() ->
    {OsFam, OsName} = os:type(),
    [{fam, OsFam}, {name, OsName}, {ver, os:version()}].

ms1() ->
    App    = ?APPLICATION,
    LibDir = code:lib_dir(App),
    File   = filename:join([LibDir, "ebin", atom_to_list(App) ++ ".app"]),
    case file:consult(File) of
        {ok, [{application, App, AppFile}]} ->
            case lists:keysearch(modules, 1, AppFile) of
                {value, {modules, Mods}} ->
                    {ok, Mods};
                _ ->
                    {error, {invalid_format, modules}}
            end;
        Error ->
            {error, {invalid_format, Error}}
    end.

ms2() ->
    application:get_key(?APPLICATION, modules).


%%-----------------------------------------------------------------
%% Returns: current time as a DateAndTime type (defined in rfc1903)
%%-----------------------------------------------------------------
date_and_time() ->
    UTC   = calendar:universal_time(),
    Local = calendar:universal_time_to_local_time(UTC),
    date_and_time(Local, UTC).

date_and_time(Local, UTC) ->
    DiffSecs = calendar:datetime_to_gregorian_seconds(Local) -
	calendar:datetime_to_gregorian_seconds(UTC),
    short_time(Local) ++ diff(DiffSecs).

short_time({{Y,M,D},{H,Mi,S}}) ->
    [y1(Y), y2(Y), M, D, H, Mi, S, 0].

%% This function will only be called if there has been some 
%% validation error, and as it is strict, it always returns 
%% false. 
strict_validation(_What, _Data) ->
    false.

kiribati_validation(diff, Diff) ->
    check_kiribati_diff(Diff);
kiribati_validation(_What, _Data) ->
    false.

check_kiribati_diff([$+, H, M]) 
  when ((0 =< H) andalso (H < 14) andalso (0 =< M) andalso (M < 60)) orelse
       ((H =:= 14) andalso (M =:= 0)) -> 
    true;
check_kiribati_diff([$-, H, M]) 
  when ((0 =< H) andalso (H < 14) andalso (0 =< M) andalso (M < 60)) orelse
       ((H =:= 14) andalso (M =:= 0)) ->
    true;
check_kiribati_diff(_) ->
    false.


date_and_time_to_string2(DAT) ->
    Validate = fun(What, Data) -> kiribati_validation(What, Data) end,
    date_and_time_to_string(DAT, Validate).

date_and_time_to_string(DAT) ->
    Validate = fun(What, Data) -> strict_validation(What, Data) end,
    date_and_time_to_string(DAT, Validate).
date_and_time_to_string(DAT, Validate) when is_function(Validate) ->
    case validate_date_and_time(DAT, Validate) of
	true ->
	        dat2str(DAT);
	false ->
	        exit({badarg, {?MODULE, date_and_time_to_string, [DAT]}})
    end.

dat2str([Y1,Y2, Mo, D, H, M, S, Ds | Diff]) ->
    lists:flatten(io_lib:format("~w-~w-~w,~w:~w:~w.~w",
				[y(Y1,Y2),Mo,D,H,M,S,Ds]) ++
		    case Diff of
			      [Sign,Hd,Md] ->
			      io_lib:format(",~c~w:~w",
					    [Sign,Hd,Md]);
			      _ -> []
		      end).
    

y1(Y) -> (Y bsr 8) band 255.
y2(Y) -> Y band 255.

y(Y1, Y2) -> 256 * Y1 + Y2.
    
diff(Secs) ->
    case calendar:seconds_to_daystime(Secs) of
	{0, {H, M,_}} ->
	        [$+, H, M];
	{-1, _} ->
	        {0, {H, M, _}} = calendar:seconds_to_daystime(-Secs),
	        [$-, H, M]
    end.

universal_time_to_date_and_time(UTC) ->
    short_time(UTC) ++ [$+, 0, 0].

local_time_to_date_and_time_dst(Local) ->
    case calendar:local_time_to_universal_time_dst(Local) of
	[] ->
	    [];
	[UTC] ->
	    [date_and_time(Local, UTC)];
	[UTC1, UTC2] ->
	    [date_and_time(Local, UTC1), date_and_time(Local, UTC2)]
    end.

date_and_time_to_universal_time_dst([Y1, Y2, Mo, D, H, M, S, _Ds]) ->
    %% Local time specified, convert to UTC
    Local = {{y(Y1,Y2), Mo, D}, {H, M, S}},
    calendar:local_time_to_universal_time_dst(Local);
date_and_time_to_universal_time_dst([Y1, Y2, Mo, D, H, M, S, _Ds, Sign, Hd, Md]) ->
     %% Time specified as local time + diff from UTC. Conv to UTC.
    Local = {{y(Y1,Y2), Mo, D}, {H, M, S}},
    LocalSecs = calendar:datetime_to_gregorian_seconds(Local),
    Diff = (Hd*60 + Md)*60,
    UTCSecs = if Sign == $+ -> LocalSecs - Diff;
		 Sign == $- -> LocalSecs + Diff
	      end,
    [calendar:gregorian_seconds_to_datetime(UTCSecs)].


validate_date_and_time(DateAndTime) ->
    Validate = fun(What, Data) -> strict_validation(What, Data) end,
    validate_date_and_time(DateAndTime, Validate).

validate_date_and_time(DateAndTime, Validate) when is_function(Validate) ->
    do_validate_date_and_time(DateAndTime, Validate).

do_validate_date_and_time([Y1,Y2, Mo, D, H, M, S, Ds | Diff], Validate) 
  when ((0 =< Y1) andalso (0 =< Y2)) andalso 
       ((0 < Mo) andalso (Mo < 13)) andalso 
       ((0 < D) andalso (D < 32) andalso (0 =< H)) andalso 
       (H < 24) andalso 
       ((0 =< M) andalso (M < 60)) andalso  
       ((0 =< S) andalso (S < 61)) andalso  
       ((0 =< Ds) andalso (Ds < 10)) ->
    case check_diff(Diff, Validate) of
	true ->
	    Year = y(Y1,Y2), 
	    case calendar:valid_date(Year, Mo, D) of
		true ->
		    true;
		_ ->
		    Validate(valid_date, {Year, Mo, D})
	    end;
	false ->
	    false
    end;
do_validate_date_and_time([Y1,Y2, Mo, D, H, M, S, Ds | Diff], Validate) ->
    Valid = 
	Validate(year,         {Y1, Y2}) andalso 
	Validate(month,        Mo)       andalso 
	Validate(day,          D)        andalso 
	Validate(hour,         H)        andalso 
	Validate(minute,       M)        andalso 
	Validate(seconds,      S)        andalso 
	Validate(deci_seconds, Ds),
    if 
	Valid =:= true ->
	    case check_diff(Diff, Validate) of
		true ->
		    Year = y(Y1,Y2), 
		    case calendar:valid_date(Year, Mo, D) of
			true ->
			    true;
			_ ->
			    Validate(valid_date, {Year, Mo, D})
		    end;
		false ->
		    false
	    end;
	true ->
	    false
    end;
do_validate_date_and_time(_, _) -> 
    false.

%% OTP-4206 (now according to RFC-2579)
check_diff([], _) -> 
    true;
check_diff([$+, H, M], _) 
  when (0 =< H) andalso (H < 14) andalso (0 =< M) andalso (M < 60) -> 
    true;
check_diff([$-, H, M], _) 
  when (0 =< H) andalso (H < 14) andalso (0 =< M) andalso (M < 60) -> 
    true;
check_diff(Diff, Validate) -> 
    Validate(diff, Diff).


%%-----------------------------------------------------------------
%% System start- and up-time
%%-----------------------------------------------------------------

system_start_time(agent) ->
    snmpa:system_start_time();
system_start_time(manager) ->
    snmpm:system_start_time().

sys_up_time(agent) ->
    snmpa:sys_up_time();
sys_up_time(manager) ->
    snmpm:sys_up_time().



%%-----------------------------------------------------------------
%% Utility functions for OCTET-STRING / BITS conversion.
%%-----------------------------------------------------------------

octet_string_to_bits(S) ->
    snmp_pdus:octet_str_to_bits(S).

bits_to_octet_string(B) ->
    snmp_pdus:bits_to_str(B).


%%%-----------------------------------------------------------------
%%% USM functions
%%%-----------------------------------------------------------------

passwd2localized_key(Alg, Passwd, EngineID) ->
    snmp_usm:passwd2localized_key(Alg, Passwd, EngineID).

localize_key(Alg, Key, EngineID) ->
    snmp_usm:localize_key(Alg, Key, EngineID).


%%%-----------------------------------------------------------------
%%% Read a mib
%%%-----------------------------------------------------------------

read_mib(FileName) ->
    snmp_misc:read_mib(FileName).


%%%-----------------------------------------------------------------
%%% Audit Trail Log functions
%%%-----------------------------------------------------------------

log_to_txt(LogDir, Mibs, OutFile, LogName, LogFile) -> 
    Block = ?ATL_BLOCK_DEFAULT, 
    Start = null, 
    Stop  = null, 
    log_to_txt(LogDir, Mibs, OutFile, LogName, LogFile, Block, Start, Stop).

log_to_txt(LogDir, Mibs, OutFile, LogName, LogFile, Block) 
  when ((Block =:= true) orelse (Block =:= false)) -> 
    Start = null, 
    Stop  = null, 
    log_to_txt(LogDir, Mibs, OutFile, LogName, LogFile, Block, Start, Stop);
log_to_txt(LogDir, Mibs, OutFile, LogName, LogFile, Start) -> 
    Block = ?ATL_BLOCK_DEFAULT, 
    Stop  = null, 
    log_to_txt(LogDir, Mibs, OutFile, LogName, LogFile, Block, Start, Stop).

log_to_txt(LogDir, Mibs, OutFile, LogName, LogFile, Block, Start) 
  when ((Block =:= true) orelse (Block =:= false)) -> 
    Stop  = null, 
    log_to_txt(LogDir, Mibs, OutFile, LogName, LogFile, Block, Start, Stop);
log_to_txt(LogDir, Mibs, OutFile, LogName, LogFile, Start, Stop) -> 
    Block = ?ATL_BLOCK_DEFAULT, 
    log_to_txt(LogDir, Mibs, OutFile, LogName, LogFile, Block, Start, Stop).

log_to_txt(LogDir, Mibs, OutFile, LogName, LogFile, Block, Start, Stop) -> 
    snmp_log:log_to_txt(LogName, Block, LogFile, LogDir, Mibs, OutFile, 
			Start, Stop).


log_to_io(LogDir, Mibs, LogName, LogFile) -> 
    Block = ?ATL_BLOCK_DEFAULT, 
    Start = null, 
    Stop  = null, 
    log_to_io(LogDir, Mibs, LogName, LogFile, Block, Start, Stop).

log_to_io(LogDir, Mibs, LogName, LogFile, Block) 
  when ((Block =:= true) orelse (Block =:= false)) -> 
    Start = null, 
    Stop  = null, 
    log_to_io(LogDir, Mibs, LogName, LogFile, Block, Start, Stop);
log_to_io(LogDir, Mibs, LogName, LogFile, Start) -> 
    Block = ?ATL_BLOCK_DEFAULT, 
    Stop  = null, 
    log_to_io(LogDir, Mibs, LogName, LogFile, Block, Start, Stop).

log_to_io(LogDir, Mibs, LogName, LogFile, Block, Start) 
  when ((Block =:= true) orelse (Block =:= false)) -> 
    Stop  = null, 
    log_to_io(LogDir, Mibs, LogName, LogFile, Block, Start, Stop);
log_to_io(LogDir, Mibs, LogName, LogFile, Start, Stop) -> 
    Block = ?ATL_BLOCK_DEFAULT, 
    log_to_io(LogDir, Mibs, LogName, LogFile, Block, Start, Stop).

log_to_io(LogDir, Mibs, LogName, LogFile, Block, Start, Stop) -> 
    snmp_log:log_to_io(LogName, Block, LogFile, LogDir, Mibs, Start, Stop).

change_log_size(LogName, NewSize) -> 
    snmp_log:change_size(LogName, NewSize).


%%%-----------------------------------------------------------------
%%% Misc
%%%-----------------------------------------------------------------

%% Usage: erl -s snmp str_apply '{Mod,Func,ArgList}'
str_apply([Atom]) ->
    Str = atom_to_list(Atom),
    {Mod, Func, Args} = to_erlang_term(Str),
    apply(Mod, Func, Args).

to_erlang_term(String) ->
    {ok, Tokens, _} = erl_scan:string(lists:append([String, ". "])),
    {ok, Term}      = erl_parse:parse_term(Tokens),
    Term.


