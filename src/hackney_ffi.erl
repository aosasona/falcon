-module(hackney_ffi).

-export([send/5]).

send(Method, Url, Headers, Body, Options) ->
  MergedOptions = lists:merge(Options, [{with_body, true}]),
  case hackney:request(Method, Url, Headers, Body, MergedOptions) of
    {ok, Status, ResponseHeaders, ResponseBody} ->
      {ok, {response, Status, ResponseHeaders, ResponseBody}};
    {ok, Status, ResponseHeaders} ->
      {ok, {response, Status, ResponseHeaders, <<>>}};
    {error, Error} ->
      {error, {other, Error}}
  end.
