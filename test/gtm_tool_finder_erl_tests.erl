-module(gtm_tool_finder_erl_tests).
-include_lib("eunit/include/eunit.hrl").

index_loaded_test() -> ?assertEqual(287, length(gtm_tool_finder_erl:all())).

apollo_first_test() ->
    [#{url := Url} | _] = gtm_tool_finder_erl:search("apollo", "", 5),
    ?assertMatch(<<"https://www.onegtmlab.dev/", _/binary>>, Url).

kind_filter_test() ->
    Hits = gtm_tool_finder_erl:search("clay", "comparison", 10),
    ?assert(Hits =/= []),
    ?assert(lists:all(fun(#{kind := K}) -> K =:= <<"Comparison">> end, Hits)).

no_hit_test() -> ?assertEqual([], gtm_tool_finder_erl:search("zzzznotatool")).
