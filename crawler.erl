-module (crawler).
-compile (export_all).

-define(DEBUG, true).

-ifdef(DEBUG).
-define(LOG_FILE, "log.txt").
-define(show(X), file:write_file(?LOG_FILE, io_lib:format("~p~n", [X]), [append])).
-endif.

-spec start_crawling(string(), integer(), string()) -> 'done' | 'not_html' | 'url_not_valid'.
start_crawling(Url, Depth, OutputPath) ->
	inets:start(),
	file:write_file(?LOG_FILE, ""),
	Pid = spawn(?MODULE, listen, [self(), 0]),
	crawl_all(Pid, [Url], Depth, OutputPath),
	receive
		done -> done
	end.


-spec listen(pid(), integer()) -> done.
listen(Pid, Count) ->
	receive
		starting ->
			io:format("Receiving a starting~n"),
			listen(Pid, Count + 1);
		ending ->
			io:format("Receiving an ending~n"),
			listen(Pid, Count - 1)
	after 1000 ->
		io:format("Waited for 1 sec~n"),
		if
			Count =:= 0 ->
				Pid ! done;
			true ->
				listen(Pid, Count)
		end
	end.


-spec crawl_all(pid(), [any()],_,_) -> 'done'.
crawl_all(_, [], _, _) -> done;
crawl_all(Pid, [Head | Rest], Depth, OutputPath) ->
	Pid ! starting,
	spawn(?MODULE, crawl, [Pid, Head, Depth, OutputPath]),
	crawl_all(Pid, Rest, Depth, OutputPath).

-spec crawl(pid(), string(), integer(), string()) -> 'done' | 'not_html' | 'url_not_valid'.
crawl(Pid, _, Depth, _) when Depth < 0 -> Pid ! ending;
crawl(Pid, Url, Depth, OutputPath) ->
	case httpc:request(Url) of
		{ok, {{_, 200, _}, _, Body}} ->
			Tokens = mochiweb_html:parse(Body),
			case Tokens of
				% See if it's a html document.
				{<<"html">>, _, _} ->
					Title = extract_title(Tokens),
					Links = extract_links(Tokens, Url),
					file:write_file(OutputPath ++ binary_to_list(Title) ++ ".html", Body),
					crawl_all(Pid, Links, Depth - 1, OutputPath);
				_ ->
					not_html
			end;
		Error ->
			?show(Error),
			?show(Url),
			url_not_valid
	end,
	Pid ! ending.

% Given a maybe-relative url and a base url, 
% return an absolute url.
-spec fix_link(string(), string()) -> [any()].
fix_link(Link, BaseUrl) ->
	L4 = string:left(Link, 4),
	L1 = string:left(Link, 1),
	if
		% Dealing with absolute URLs like "http://www.google.com"
		L4 =:= "http" ->
			Link;
		% Dealing with relative URLs like "/haha"
		L1 =:= "/" ->
			% Given an URL like "http://www.google.com/haha", the
			% helper function returns "http://www.google.com"
			Helper = fun ([Head | Rest], Count, Helper) ->
					if
						% We check if Count is 2 because in an absolute URL,
						% there are 2 '/' in "http://".  Therefore, the third
						% '/' will be the end of the base URL.
						(Head =:= $/) and (Count =:= 2) ->
							""; % empty string
						Head =:= $/ ->
							[Head | Helper(Rest, Count + 1, Helper)];
						true ->
							[Head | Helper(Rest, Count, Helper)]
					end
			end,
			Helper(BaseUrl, 0, Helper) ++ Link;
		% Dealing with relative URLs like "haha"
		true ->
			R1 = string:right(BaseUrl, 1),
			if
				R1 =:= "/" ->
					BaseUrl ++ Link;
				true ->
					BaseUrl ++ "/" ++ Link
			end
	end.


-spec extract_links(_,string()) -> [any()].
extract_links(Tokens, BaseUrl) ->
	Helper = fun (Attributes) ->
			?show(Attributes), 
			case [Value || {Name, Value} <- Attributes, Name =:= <<"href">>] of
				[Link | _] ->
					{true, fix_link(binary_to_list(Link), BaseUrl)};
				[] ->
					false
			end
	end,
	Links = extract_token(Tokens, <<"a">>),
	lists:zf(Helper, [Attributes || {_Tag, Attributes, _Children} <- Links]).

-spec extract_title(_) -> any().
extract_title(Tokens) ->
	[{_Tag, _Attributes, [Title]}] = extract_token(Tokens, <<"title">>),
	Title.


-spec extract_token_from_all([any()],_) -> [{_,_,_}].
extract_token_from_all([], _) -> [];
extract_token_from_all([Head | Rest], Token) ->
	extract_token(Head, Token) ++ extract_token_from_all(Rest, Token).

% Extracts Token from Tokens. Token should be a string.
-spec extract_token(_, binary()) -> [{_,_,_}].
extract_token(Tokens, Token) ->
	case Tokens of
		{Name, _Attributes, Children} ->
			if
				Name =:= Token -> [Tokens];
				true -> extract_token_from_all(Children, Token)
			end;
		_ -> []
	end.