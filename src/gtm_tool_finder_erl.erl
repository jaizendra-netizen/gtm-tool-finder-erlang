%% @doc Search the OneGTMLab GTM tool directory (https://www.onegtmlab.dev/tool-directory):
%% API reviews of sales and marketing tools, head-to-head comparisons and GTM glossary terms.
%% The index ships inside the package (priv/index.tsv), so it works offline and sends no data anywhere.
-module(gtm_tool_finder_erl).
-export([all/0, search/1, search/2, search/3, main/1]).
-export_type([entry/0]).

-type entry() :: #{name := binary(), kind := binary(), url := binary(), description := binary()}.

%% @doc Every entry in the directory.
-spec all() -> [entry()].
all() ->
    Bin = read_index(),
    [parse(Line) || Line <- binary:split(Bin, <<"\n">>, [global]), Line =/= <<>>].

read_index() ->
    File = filename:join(code:priv_dir(gtm_tool_finder_erl), "index.tsv"),
    case file:read_file(File) of
        {ok, Bin} -> Bin;
        {error, _} -> read_index_from_escript()
    end.

%% Inside an escript the priv dir lives in the zip archive, not on disk.
read_index_from_escript() ->
    {ok, Sections} = escript:extract(escript:script_name(), []),
    {archive, Archive} = lists:keyfind(archive, 1, Sections),
    {ok, [{_, Bin}]} = zip:extract(Archive, [memory, {file_list, ["gtm_tool_finder_erl/priv/index.tsv"]}]),
    Bin.

parse(Line) ->
    [N, K, U, D] = binary:split(Line, <<"\t">>, [global]),
    #{name => N, kind => K, url => U, description => D}.

%% @doc Entries whose name or description contains every word of the query.
-spec search(string() | binary()) -> [entry()].
search(Query) -> search(Query, "", 20).

-spec search(string() | binary(), string() | binary()) -> [entry()].
search(Query, Kind) -> search(Query, Kind, 20).

%% @doc `Kind' filters by Tool, Category, Comparison or Glossary (case-insensitive, "" means all).
%% `Limit' caps the result count (0 or less means 20).
-spec search(string() | binary(), string() | binary(), integer()) -> [entry()].
search(Query, Kind, Limit0) ->
    Limit = case Limit0 =< 0 of true -> 20; false -> Limit0 end,
    Words = [W || W <- string:lexemes(string:lowercase(to_list(Query)), " "), W =/= []],
    Want = string:lowercase(to_list(Kind)),
    Hits = [E || E = #{kind := K, name := N, description := D} <- all(),
                 Want =:= "" orelse string:lowercase(to_list(K)) =:= Want,
                 begin
                     Text = string:lowercase(to_list(<<N/binary, " ", D/binary>>)),
                     lists:all(fun(W) -> string:find(Text, W) =/= nomatch end, Words)
                 end],
    First = case Words of [F | _] -> F; [] -> none end,
    Ranked = lists:sort([{rank(E, First), Idx, E} || {Idx, E} <- lists:zip(lists:seq(1, length(Hits)), Hits)]),
    lists:sublist([E || {_, _, E} <- Ranked], Limit).

rank(#{name := N, kind := K}, First) ->
    Starts = case First =/= none andalso lists:prefix(First, string:lowercase(to_list(N))) of true -> 0; false -> 1 end,
    {Starts, kind_order(K)}.

kind_order(<<"Tool">>) -> 0;
kind_order(<<"Category">>) -> 1;
kind_order(<<"Comparison">>) -> 2;
kind_order(_) -> 3.

to_list(B) when is_binary(B) -> unicode:characters_to_list(B);
to_list(L) when is_list(L) -> L.

%% @doc Command line: gtm_tool_finder [--kind Tool] [--limit 10] words...
-spec main([string()]) -> no_return().
main(Args) ->
    {Kind, Limit, Words} = parse_args(Args, "", 20, []),
    case search(string:join(lists:reverse(Words), " "), Kind, Limit) of
        [] ->
            io:format("No matches.~n"),
            halt(1);
        Hits ->
            [io:format("~ts: ~ts~n  ~ts~n", [K, N, U]) || #{kind := K, name := N, url := U} <- Hits],
            halt(0)
    end.

parse_args(["--kind", K | R], _, L, W) -> parse_args(R, K, L, W);
parse_args(["--limit", N | R], K, _, W) ->
    L = try list_to_integer(N) catch _:_ -> 20 end,
    parse_args(R, K, L, W);
parse_args([X | R], K, L, W) -> parse_args(R, K, L, [X | W]);
parse_args([], K, L, W) -> {K, L, W}.
