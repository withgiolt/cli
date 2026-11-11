-module(giolt_ffi_api).
-export([transmit/3]).

% A String and a BitArray are both binaries on Erlang, so the request goes
% to send_bits as it is.
transmit(Request, _Method, _Url) ->
    {ok, _} = application:ensure_all_started(gleam_httpc),
    case 'gleam@httpc':send_bits(Request) of
        {ok, {response, Status, _Headers, Body}} ->
            case unicode:characters_to_binary(Body) of
                Text when is_binary(Text) -> {ok, {Status, {ok, Text}}};
                _ -> {ok, {Status, {error, nil}}}
            end;
        {error, _} ->
            {error, nil}
    end.
