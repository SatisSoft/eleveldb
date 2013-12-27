%% -------------------------------------------------------------------
%%
%%  eleveldb: Erlang Wrapper for LevelDB (http://code.google.com/p/leveldb/)
%%
%% Copyright (c) 2010-2013 Basho Technologies, Inc. All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------
-module(iterators).

-compile(export_all).

-include_lib("eunit/include/eunit.hrl").

prev_test() ->
    os:cmd("rm -rf ltest"),  % NOTE
    {ok, Ref} = eleveldb:open("ltest", [{create_if_missing, true}]),
    try
      eleveldb:put(Ref, <<"a">>, <<"x">>, []),
      eleveldb:put(Ref, <<"b">>, <<"y">>, []),
      {ok, I} = eleveldb:iterator(Ref, []),
        ?assertEqual({ok, [{<<"a">>, <<"x">>}]},eleveldb:iterator_move(I, <<>> , 1)),
        ?assertEqual({ok, [{<<"b">>, <<"y">>}]},eleveldb:iterator_move(I, next, 1)),
        ?assertEqual({ok, [{<<"a">>, <<"x">>}]},eleveldb:iterator_move(I, prev, 1)),
      
      eleveldb:put(Ref, <<"c">>, <<"z">>, []),
      {ok, I2} = eleveldb:iterator(Ref, []),
        ?assertEqual({ok, [{<<"a">>, <<"x">>}]},eleveldb:iterator_move(I2, <<>> , 1)),
        ?assertEqual({ok, [{<<"b">>, <<"y">>}, {<<"c">>, <<"z">>}]}, eleveldb:iterator_move(I2, next, 2)),
      
      {ok, I3} = eleveldb:iterator(Ref, []),
        ?assertEqual({ok, [{<<"a">>, <<"x">>}]},eleveldb:iterator_move(I3, <<>> , 1)),
        ?assertEqual({ok, [{<<"b">>, <<"y">>}]}, eleveldb:iterator_move(I3, prefetch, 1)),
        ?assertEqual({ok, [{<<"c">>, <<"z">>}]}, eleveldb:iterator_move(I3, prefetch, 1)),
      
      {ok, I4} = eleveldb:iterator(Ref, []),
        ?assertEqual({ok, [{<<"a">>, <<"x">>}]},eleveldb:iterator_move(I4, <<>> , 10)),
        ?assertEqual({ok, [{<<"b">>, <<"y">>}, {<<"c">>, <<"z">>}]}, eleveldb:iterator_move(I4, prefetch, 20)),
        ?assertEqual({error, invalid_iterator}, eleveldb:iterator_move(I4, prefetch, 2)),
      
      ?assertEqual([<<"cz">>, <<"by">>, <<"ax">>], eleveldb:fold(Ref, fun({K,V}, Acc) -> [<<K/binary, V/binary>>|Acc] end, [], [], 2)),
      ?assertEqual([<<"cz">>, <<"by">>, <<"ax">>], eleveldb:fold(Ref, fun({K,V}, Acc) -> [<<K/binary, V/binary>>|Acc] end, [], [], 20)),
      ?assertEqual([<<"cz">>, <<"ax">>],
                   eleveldb:fold_pattern(Ref, fun({K,V}, Acc) -> [<<K/binary, V/binary>>|Acc] end, [], [], 20,
                   [{<<"a">>, <<"a">>}, {<<"c">>, <<"x">>}])),
      SmartFoldFun = fun
              ({K, V}, Acc) when length(Acc) =:= 1->
                  {next_key, <<"a">>, [<<K/binary, V/binary>>|Acc]};
              ({K,V}, Acc) ->
                  [<<K/binary, V/binary>>|Acc]
          end,
      ?assertEqual([<<"cz">>,<<"by">>,<<"ax">>,<<"by">>,<<"ax">>], eleveldb:fold(Ref, SmartFoldFun, [], [], 20)),

       {ok, I5} = eleveldb:iterator(Ref, []),
        ?assertEqual({ok, [{<<"a">>, <<"x">>}]},eleveldb:iterator_move(I5, <<>> , 20)),
        ?assertEqual({ok, [{<<"b">>, <<"y">>}, {<<"c">>, <<"z">>}]}, eleveldb:iterator_move(I5, prefetch, 20)),
        ?assertEqual({ok, [{<<"a">>, <<"x">>}]},eleveldb:iterator_move(I5, <<"a">> , 20)),
        ?assertEqual({ok, [{<<"b">>, <<"y">>}, {<<"c">>, <<"z">>}]}, eleveldb:iterator_move(I5, prefetch, 20))

    after
      eleveldb:close(Ref)
    end.

return_from_nowhere() ->
    os:cmd("rm -rf ltest"),  % NOTE
    {ok, Ref} = eleveldb:open("ltest", [{create_if_missing, true}]),
    try
        eleveldb:put(Ref, <<"a">>, <<"x">>, []),
        eleveldb:put(Ref, <<"b">>, <<"y">>, []),
        {ok, I} = eleveldb:iterator(Ref, []),
        ?assertEqual({ok, [{<<"a">>, <<"x">>}]},eleveldb:iterator_move(I, <<>> , 1)),
        ?assertEqual({ok, [{<<"b">>, <<"y">>}]}, eleveldb:iterator_move(I, next, 10)),
        ?assertEqual({error, invalid_iterator}, eleveldb:iterator_move(I, next, 2)),
        ?assertEqual({ok, [{<<"a">>, <<"x">>}]},eleveldb:iterator_move(I, <<>> , 1))
    after
        eleveldb:close(Ref)
    end.

batch_read_jump() ->
   %% os:cmd("rm -rf ltest"),  % NOTE
    {ok, Ref} = eleveldb:open("ltest", [{create_if_missing, true}]),
    try
        Data = [{<<Key:64/integer>>, <<Value:64/integer>>} || Key <- lists:seq(1,1000), Value <- lists:seq(1,1000)],
        io:format("prepared~n"),
        [{K1, _}|_] = lists:dropwhile(fun (_X) -> random:uniform() > 0.7 end, Data),
        [{K2, _}|_] = lists:dropwhile(fun (_X) -> random:uniform() > 0.7 end, Data),

        lists:foreach(fun({X,Y}) -> eleveldb:put(Ref, X, Y, []) end, Data),

        lists:foreach(
            fun(_) ->
                {ok, I} = eleveldb:iterator(Ref, []),
                eleveldb:iterator_move(I, K1 , 1),
                eleveldb:iterator_move(I, prefetch, 1000),
                eleveldb:iterator_move(I, K2 , 1),
                eleveldb:iterator_move(I, prefetch, 1000),
                eleveldb:iterator_close(I)
            end,
            lists:seq(1,1000)),
        ok
    after
        eleveldb:close(Ref)
    end.
