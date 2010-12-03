kanjivg2svg
===========

This Ruby 1.9 script takes data from the [KanjiVG](http://kanjivg.tagaini.net/) and outputs SVG files with special formatting.

Usage
-----

    $ mkdir svgs
    $ ruby kanjivg2svg.rb path/to/kanjivg.xml [frames|animated|numbers]

You can change the output type by setting the second argument. If not set it will default to 'frames'. The animated and numbers are less perfected compared to the frames output.

In this repo I've included svg files generated with the 'frames' option.

License
-------

By Kim Ahlström <kim.ahlstrom@gmail.com>

[Creative Commons Attribution-Share Alike 3.0](http://creativecommons.org/licenses/by-sa/3.0/)

KanjiVG
-------

KanjiVG is copyright (c) 2009/2010 Ulrich Apel and released under the Creative Commons Attribution-Share Alike 3.0
