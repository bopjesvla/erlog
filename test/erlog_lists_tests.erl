-module(erlog_lists_tests).
-include_lib("eqc/include/eqc.hrl").
-include_lib("eunit/include/eunit.hrl").

prop_append_lists() ->
    ?FORALL(
       {A,B},
       {list(int()), list(int())},
       begin
           Term = {append,A,B,{'Z'}},
           {ok, PID} = erlog:start_link(),
           case  erlog:prove(PID,Term) of
               {succeed, [{'Z', Z}]} ->
                   Z =:= lists:append(A,B);
               fail ->
                   false
           end
       end).


prop_append_list() ->
    ?FORALL(
       L,
       list(int()),
       begin
           Term = {append,{'A'},{'B'},L},
           {ok, PID} = erlog:start_link(),
           case  erlog:prove(PID,Term) of
               {succeed, [{'A', A}, 
                          {'B', B}]} ->
                   L =:= lists:append(A,B);
               fail ->
                   false
           end
       end).


prop_reverse_list() ->
    ?FORALL(L, list(int()),
            begin
                Term =  {reverse,L,{'Y'}},
                {ok, PID} = erlog:start_link(),
                case  erlog:prove(PID,Term) of
                    {succeed, [{'Y', Y}]} ->
                        L =:= lists:reverse(Y);
                    fail ->
                        false
                end
            end).

prop_reverse_list_valid() ->
    ?FORALL(L, list(int()),
            begin
                Term =  {reverse,L,lists:reverse(L)},
                {ok, PID} = erlog:start_link(),
                case  erlog:prove(PID,Term) of
                    {succeed, _} ->
                        true;
                    fail ->
                        false
                end
            end).

prop_reverse_list_invalid() ->
    ?FORALL(L, list(int()),
            begin
                Term =  {reverse, [1|L], lists:reverse(L)},
                {ok, PID} = erlog:start_link(),
                case  erlog:prove(PID,Term) of
                    {succeed, _} ->
                        false;
                    fail ->
                        true
                end
            end).


prop_last_list() ->
    ?FORALL(L, 
            list(int()),
            ?IMPLIES(length(L) > 0,
            begin
                Term =  {last, lists:last(L),L},
                {ok, PID} = erlog:start_link(),
                case  erlog:prove(PID,Term) of
                    {succeed, _} ->
                        false;
                    fail ->
                        true
                end
            end)).

prop_member_list() ->
    ?FORALL({M,L},
            {int(), list(int())},
            begin
                Term =  {member, M, L},
                {ok, PID} = erlog:start_link(),
                case  erlog:prove(PID,Term) of
                    {succeed, _} ->
                        lists:member(M,L);
                    fail ->
                        not(lists:member(M,L))

                end

            end).

run_test_() ->
    Props = [fun prop_append_list/0,
             fun prop_append_lists/0,
             fun prop_reverse_list_invalid/0,
             fun prop_reverse_list/0,
             fun prop_reverse_list_valid/0,
             fun prop_last_list/0,
             fun prop_member_list/0
             ],    
    [
     begin
         P = Prop(),
         ?_assert(quickcheck(numtests(500,P)))
     end
     || Prop <- Props].


