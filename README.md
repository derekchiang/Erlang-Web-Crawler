This is a web crawler written in Erlang.

To use, call `crawler:start_crawling(Url, Depth, OutputDirectory)`.

For example:

`crawler:start_crawling("http://learnyousomeerlang.com/content", 1, "./")`
