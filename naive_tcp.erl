%%%-------------------------------------------------------------------
%%% @author dk
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 15. gru 2015 10:54
%%%-------------------------------------------------------------------

-module(naive_tcp).
-compile(export_all).
-define(TCP_OPTIONS, [binary, {active, false}, {reuseaddr, true}]).

start_server(Port) ->
  process_flag(trap_exit, true),
  Clients = [],
  HandlerPID = spawn_link(fun() -> handler(Clients) end),
  listen(Port, HandlerPID).

checknick(Clients, SenderID) ->
  case Clients of
    [{_,_,SenderID}|T] ->
      "Yes";
    [{_,_,SenderID}] ->
      "Yes";
    [{_,_,_}|T] ->
      checknick(T, SenderID);
    _ -> "No"
  end.

positionhandle(Position,SenderID,HandlerPID) ->
  SenderID1 = binary_to_list(SenderID),
  HandlerPID ! {get_client_pid, self(), SenderID1},
  receive
    {pid, SockPID} ->
      gen_tcp:send(SockPID, Position),
      gen_tcp:send(SockPID, "\n");
    _ ->
      io:format("\nnoid\n"),
      {warning, noid}
  end.

searchpid(Clients, SenderID) ->
  case Clients of
    [{_,_,SenderID}] ->
      io:format("error");
    [{_,_,SenderID}|T] ->
      searchpid(T, SenderID);
    [{_,cwrite,_}|T] ->
      searchpid(T, SenderID);
    [{Searching,clisten,Sending}|T] ->
      MyString = string:sub_string(SenderID, 1, string:len(Sending)),
      MyString1 = string:sub_string(Sending, 1, string:len(SenderID)),
      if
        MyString =:= Sending  ->
          searchpid(T, SenderID);
        true ->
          if
            MyString1 =:= SenderID  ->
              searchpid(T, SenderID);
            true ->
              Searching
          end
      end;
    [{_,_,_}] ->
      io:format("error")
  end.

searchnick(Clients, SenderID) ->
  case Clients of
    [{_,_,SenderID}|T] ->
      searchnick(T, SenderID);
    [{_,_,Searching}|T] ->
      Searching
  end.

count([]) -> 0;
count([H|T]) -> 1 + count(T).

handler(Clients) ->
  receive
    {insert_client, Socket, Alias, Mode} ->
      Clients2 = Clients ++ [{Socket, Mode, Alias}],
      handler(Clients2);
    {get_client_pid, ReceiverPID, SenderID} ->
      CPID = searchpid(Clients, SenderID),
      case CPID of
        nopid ->
          ReceiverPID ! {nopid, CPID};
        _ ->
          ReceiverPID ! {pid, CPID}
      end,
      handler(Clients);
    {get_client_nick, ReceiverPID, SenderID} ->
      Nick = searchnick(Clients, SenderID),
      ReceiverPID ! {nick, Nick},
      handler(Clients);
    {check_players, ReceiverPID, SenderID} ->
      HowMany = count(Clients),
      case HowMany of
        0 ->
          ReceiverPID ! "No";
        1 ->
          ReceiverPID ! "No";
        2 ->
          ReceiverPID ! "No";
        _ ->
          ReceiverPID ! "Yes"
      end,
      handler(Clients);
    _ ->
      {error, "I don't know what you want from me :("}
  end.

listen(Port, HandlerPID) ->
  {ok, LSocket} = gen_tcp:listen(Port, ?TCP_OPTIONS),
  spawn_link(fun() -> accept(LSocket, HandlerPID) end),
  LSocket.

movetop(SenderID, HandlerPID) ->
  SenderID1 = binary_to_list(SenderID),
  HandlerPID ! {get_client_pid, self(), SenderID1},
  receive
    {pid, SockPID} ->
      gen_tcp:send(SockPID, "MT\n");
    _ ->
      {error, noid}
  end.

movebottom(SenderID, HandlerPID) ->
  SenderID1 = binary_to_list(SenderID),
  HandlerPID ! {get_client_pid, self(), SenderID1},
  receive
    {pid, SockPID} ->
      gen_tcp:send(SockPID, "MB\n");
    _ ->
      {error, noid}
  end.

movestop(SenderID, HandlerPID) ->
  SenderID1 = binary_to_list(SenderID),
  HandlerPID ! {get_client_pid, self(), SenderID1},
  receive
    {pid, SockPID} ->
      gen_tcp:send(SockPID, "S\n");
    _ ->
      {error, noid}
  end.

accept(LSocket, HandlerPID) ->
  {ok, Socket} = gen_tcp:accept(LSocket),
  Pid = spawn(fun() ->
    io:format("Connection accepted ~n", []),
    loop(Socket, HandlerPID)
              end),
  gen_tcp:controlling_process(Socket, Pid),
  accept(LSocket, HandlerPID).


checktrash(Trash, HandlerPID) ->
  case Trash of
    <<$\n, "MT:", SenderID:1/binary, $\n, Tr/binary>> ->
      movetop(SenderID, HandlerPID);
    <<$\n, "MT:", SenderID:2/binary, $\n, Tr/binary>> ->
      movetop(SenderID, HandlerPID);
    <<$\n, "MT:", SenderID:3/binary, $\n, Tr/binary>> ->
      movetop(SenderID, HandlerPID);
    <<$\n, "MT:", SenderID:4/binary, $\n, Tr/binary>> ->
      movetop(SenderID, HandlerPID);
    <<$\n, "MT:", SenderID:5/binary, $\n, Tr/binary>> ->
      movetop(SenderID, HandlerPID);
    <<$\n, "MB:", SenderID:1/binary, $\n, Tr/binary>> ->
      movebottom(SenderID, HandlerPID);
    <<$\n, "MB:", SenderID:2/binary, $\n, Tr/binary>> ->
      movebottom(SenderID, HandlerPID);
    <<$\n, "MB:", SenderID:3/binary, $\n, Tr/binary>> ->
      movebottom(SenderID, HandlerPID);
    <<$\n, "MB:", SenderID:4/binary, $\n, Tr/binary>> ->
      movebottom(SenderID, HandlerPID);
    <<$\n, "MB:", SenderID:5/binary, $\n, Tr/binary>> ->
      movebottom(SenderID, HandlerPID);
    _-> io:format("~s", [Trash])
  end.

loop(Socket, HandlerPID) ->
  inet:setopts(Socket, [{active, once}]),
  receive
    {tcp, Socket, <<$\n, "MT:", SenderID:1/binary, $\n, Trash/binary>>} ->
      movetop(SenderID, HandlerPID),
      checktrash(Trash, HandlerPID),
      loop(Socket, HandlerPID);
    {tcp, Socket, <<$\n, "MT:", SenderID:2/binary, $\n, Trash/binary>>} ->
      movetop(SenderID, HandlerPID),
      loop(Socket, HandlerPID);
    {tcp, Socket, <<$\n, "MT:", SenderID:3/binary, $\n, Trash/binary>>} ->
      movetop(SenderID, HandlerPID),
      loop(Socket, HandlerPID);
    {tcp, Socket, <<$\n, "MT:", SenderID:4/binary, $\n, Trash/binary>>} ->
      movetop(SenderID, HandlerPID),
      loop(Socket, HandlerPID);
    {tcp, Socket, <<$\n, "MT:", SenderID:5/binary, $\n, Trash/binary>>} ->
      movetop(SenderID, HandlerPID),
      loop(Socket, HandlerPID);
    {tcp, Socket, <<$\n, "MB:", SenderID:1/binary, $\n, Trash/binary>>} ->
      movebottom(SenderID, HandlerPID),
      loop(Socket, HandlerPID);
    {tcp, Socket, <<$\n, "MB:", SenderID:2/binary, $\n, Trash/binary>>} ->
      movebottom(SenderID, HandlerPID),
      loop(Socket, HandlerPID);
    {tcp, Socket, <<$\n, "MB:", SenderID:3/binary, $\n, Trash/binary>>} ->
      movebottom(SenderID, HandlerPID),
      loop(Socket, HandlerPID);
    {tcp, Socket, <<$\n, "MB:", SenderID:4/binary, $\n, Trash/binary>>} ->
      movebottom(SenderID, HandlerPID),
      loop(Socket, HandlerPID);
    {tcp, Socket, <<$\n, "MB:", SenderID:5/binary, $\n, Trash/binary>>} ->
      movebottom(SenderID, HandlerPID),
      loop(Socket, HandlerPID);
    {tcp, Socket, <<$\n, "S:", SenderID:1/binary, $\n, Trash/binary>>} ->
      movestop(SenderID, HandlerPID),
      loop(Socket, HandlerPID);
    {tcp, Socket, <<$\n, "S:", SenderID:2/binary, $\n, Trash/binary>>} ->
      movestop(SenderID, HandlerPID),
      loop(Socket, HandlerPID);
    {tcp, Socket, <<$\n, "S:", SenderID:3/binary, $\n, Trash/binary>>} ->
      movestop(SenderID, HandlerPID),
      loop(Socket, HandlerPID);
    {tcp, Socket, <<$\n, "S:", SenderID:4/binary, $\n, Trash/binary>>} ->
      movestop(SenderID, HandlerPID),
      loop(Socket, HandlerPID);
    {tcp, Socket, <<$\n, "S:", SenderID:5/binary, $\n, Trash/binary>>} ->
      movestop(SenderID, HandlerPID),
      loop(Socket, HandlerPID);


  %%--------------- Enter Handle
  %%--------------- Enter Handle
  %%--------------- Enter Handle


    {tcp, Socket, <<"EnterL", SenderID/binary>>} ->
      SenderID1 = binary_to_list(SenderID),
      HandlerPID ! {insert_client, Socket, SenderID1, clisten},
      loop(Socket, HandlerPID);
    {tcp, Socket, <<"EnterW", SenderID/binary>>} ->
      SenderID1 = binary_to_list(SenderID),
      HandlerPID ! {insert_client, Socket, SenderID1, cwrite},
      HandlerPID ! {check_players, self(), SenderID1},
      receive
        "Yes" ->
          HandlerPID ! {get_client_pid, self(), SenderID1},
          receive
            {pid, SockPID} ->
              HandlerPID ! {get_client_nick, self(), SenderID1},
              receive
                {nick, Nick} ->
                  io:format(Nick),
                  Nick1 = list_to_binary(Nick),
                  gen_tcp:send(SockPID, "AllConnected:"),
                  gen_tcp:send(SockPID, "Ball:"),
                  gen_tcp:send(SockPID, SenderID),
                  gen_tcp:send(SockPID, "\n"),
                  HandlerPID ! {get_client_pid, self(), Nick},
                  receive
                    {pid, SockPID2} ->
                      gen_tcp:send(SockPID2, "AllConnected:"),
                      gen_tcp:send(SockPID2, "notBall:"),
                      gen_tcp:send(SockPID2, Nick1),
                      gen_tcp:send(SockPID2, "\n");
                    _ ->
                      io:format("\nnoid\n"),
                      {warning, noid}
                  end;
                  _ ->
                {error, nonick}
              end;
            _ ->
              io:format("\nnoid\n"),
              {warning, noid}
          end,
          loop(Socket, HandlerPID);
        "No" ->
          loop(Socket, HandlerPID);
        _ ->
          {error, nodata}
      end,
    loop(Socket, HandlerPID);
    {tcp, Socket, Data} ->
      io:format("~w", Data),
    loop(Socket, HandlerPID);
    {tcp_closed, Socket} ->
      io:format("Socket ~p closed~n", [Socket]);
    {tcp_error, Socket, Reason} ->
      io:format("Error on socket ~p reason: ~p~n", [Socket, Reason])
  end.

