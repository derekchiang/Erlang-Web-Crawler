This is a web crawler written in Erlang.

To use, call `crawler:start_crawling(Url, Depth, OutputDirectory)`.

For example:

    crawler:start_crawling("http://learnyousomeerlang.com/content", 1, "./")

Since this module is dependent on [Mochiweb](https://github.com/mochi/mochiweb) for parsing HTML, it's important to include `ebin/` (which contains beam files of mochiweb) when compile the module.  You can do:

    erl -pa "ebin/"

and then:

    c(crawler). 
