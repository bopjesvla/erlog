%%%-------------------------------------------------------------------
%%% @author tihon
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 18. июн 2014 18:00
%%%-------------------------------------------------------------------

-module(erlog_dict).

-include("erlog_core.hrl").

-behaviour(erlog_storage).

%% erlog callbacks
-export([new/1,
  assertz_clause/2,
  asserta_clause/2,
  retract_clause/2,
  abolish_clauses/2,
  get_procedure/2,
  get_procedure_type/2,
  get_interp_functors/1,
  findall/2,
  listing/2,
  close/2,
  next/2]).

new(_) -> {ok, dict:new()}.

assertz_clause({_, _, Db} = Memory, {Head, Body0}) ->
  Udb = clause(Head, Body0, Memory,
    fun(Functor, Cs, Body) ->
      case check_duplicates(Cs, Head, Body) of
        true -> Db;  %found - do nothing
        _ -> dict:append(Functor, {length(Cs), Head, Body}, Db) %not found - insert new
      end
    end),
  {ok, Udb}.

asserta_clause({_, _, Db} = Memory, {Head, Body0}) ->
  Udb = clause(Head, Body0, Memory,
    fun(Functor, Cs, Body) ->
      case check_duplicates(Cs, Head, Body) of
        true -> Db;  %found - do nothing
        _ ->
          dict:update(Functor,
            fun(Old) ->
              [{length(Cs), Head, Body} | Old]
            end, [{length(Cs), Head, Body}], Db) %not found - insert new
      end
    end),
  {ok, Udb}.

retract_clause({_, _, Db}, {Functor, Ct}) ->
  Udb = case dict:is_key(Functor, Db) of
          true ->
            dict:update(Functor, fun(Old) -> lists:keydelete(Ct, 1, Old) end, [], Db);
          false -> Db        %Do nothing
        end,
  {ok, Udb}.

abolish_clauses({_, _, Db}, Functor) ->
  Udb = case dict:is_key(Functor, Db) of
          true -> dict:erase(Functor, Db);
          false -> Db        %Do nothing
        end,
  {ok, Udb}.

findall({StdLib, ExLib, Db}, Goal) ->  %for bagof
  Functor = erlog_ec_support:functor(Goal),
  case dict:find(Functor, StdLib) of %search built-in first
    {ok, StFun} -> {StFun, Db};
    error ->
      case dict:find(Functor, ExLib) of  %search libraryspace then
        {ok, ExFun} -> {ExFun, Db};
        error ->
          case dict:find(Functor, Db) of  %search userspace last
            {ok, Cs} -> {Cs, Db};
            error -> {[], Db}
          end
      end
  end.

close(Db, _) -> {ok, Db}.

next(Db, undefined) -> {[], Db};
next(Db, Queue) ->
  case queue:out(Queue) of  %take variant
    {{value, Val}, UQ} ->
      {{cursor, UQ, result, Val}, Db};  %return it
    {empty, UQ} -> {{cursor, UQ, result, []}, Db}  %nothing to return
  end.

get_procedure({StdLib, ExLib, Db}, Goal) ->
  Functor = erlog_ec_support:functor(Goal),
  Res = case dict:find(Functor, StdLib) of %search built-in first
          {ok, StFun} -> StFun;
          error ->
            case dict:find(Functor, ExLib) of  %search libraryspace then
              {ok, Cs} when is_list(Cs) ->
                work_with_clauses(Cs);
              {ok, ExFun} -> ExFun;
              error ->
                case dict:find(Functor, Db) of  %search userspace last
                  {ok, Cs} ->
                    work_with_clauses(Cs);
                  error -> undefined
                end
            end
        end,
  {Res, Db}.

get_procedure_type({StdLib, ExLib, Db}, Goal) ->
  Functor = erlog_ec_support:functor(Goal),
  Res = case dict:is_key(Functor, StdLib) of %search built-in first
          true -> built_in;
          false ->
            case dict:is_key(Functor, ExLib) of  %search libraryspace then
              true -> compiled;
              false ->
                case dict:is_key(Functor, Db) of  %search userspace last
                  true -> interpreted;
                  false -> undefined
                end
            end
        end,
  {Res, Db}.

get_interp_functors({_, ExLib, Db}) ->
  Library = dict:fetch_keys(ExLib),
  UserSpace = dict:fetch_keys(Db),
  {lists:concat([Library, UserSpace]), Db}.

listing({_, _, Db}, [Functor, Arity]) ->
  {dict:fold(
    fun({F, A} = Res, _, Acc) when F == Functor andalso A == Arity ->
      [Res | Acc];
      (_, _, Acc) -> Acc
    end, [], Db), Db};
listing({_, _, Db}, [Functor]) ->
  {dict:fold(
    fun({F, Arity}, _, Acc) when F == Functor ->
      [{Functor, Arity} | Acc];
      (_, _, Acc) -> Acc
    end, [], Db), Db};
listing({_, _, Db}, []) ->
  {dict:fetch_keys(Db), Db}.

%% @private
clause(Head, Body0, {_, _, Db}, ClauseFun) ->
  {Functor, Body} = case catch {ok, erlog_ec_support:functor(Head), erlog_ec_body:well_form_body(Body0, false, sture)} of
                      {erlog_error, E} -> erlog_errors:erlog_error(E, Db);
                      {ok, F, B} -> {F, B}
                    end,
  case dict:find(Functor, Db) of
    {ok, Cs} -> ClauseFun(Functor, Cs, Body);
    error -> dict:append(Functor, {0, Head, Body}, Db)
  end.

%% @private
%% true - duplicate found
-spec check_duplicates(list(), tuple(), tuple()) -> boolean().
check_duplicates(Cs, Head, Body) ->
  catch (lists:foldl(
    fun({_, H, B}, _) when H == Head andalso B == Body -> throw(true);  %find same fact
      (_, Acc) -> Acc
    end, false, Cs)).

%% @private
form_clauses([]) -> {[], queue:new()};
form_clauses([First | Loaded]) ->
  Queue = queue:from_list(Loaded),
  {First, Queue}.

%% @private
work_with_clauses(Cs) ->
  {First, Cursor} = form_clauses(Cs),
  {cursor, Cursor, result, {clauses, First}}.