use v6;

use NativeCall;

# cw: Having to include all of these things in what basically amounts to
#     client code may not be a good thing.
use XML::LibXML::CStructs :types;
use XML::LibXML::Document;
use XML::LibXML::Parser;

unit class XML::LibXML;

has XML::LibXML::Parser $!parser;

submethod BUILD {
	$!parser = XML::LibXML::Parser.new;
}

# Parser pass-through options.
multi method keep-blanks(Bool $b) {
	$!parser.setFlags(XML_PARSE_NOBLANKS, :on(!$b))
}
multi method keep-blanks(Int $i where 1 | 0) {
	$!parser.setFlags(XML_PARSE_NOBLANKS, :on(!$i));
}

multi method validate(Bool $b) {
	$!parser.setFlags(XML_PARSE_DTDVALID, :on($b));
}
multi method validate(Int $i where 1 | 0) {
	$!parser.setFlags(XML_PARSE_DTDVALID, :on($i));
}

multi method linenumbers(Bool $b) {
	$!parser.linenumbers = $b ?? 1 !! 0;
}
multi method linenumbers(Int $i where 1 | 0) {
	$!parser.linenumbers = $i;
}

multi method pedantic(Bool $b) {
	$!parser.setFlags(XML_PARSE_PEDANTIC, :on($b));
}
multi method pedantic(Int $i where 1 | 0) {
	$!parser.setFlags(XML_PARSE_PEDANTIC, :on($i));
}

multi method replace-entities(Bool $b) {
	$!parser.replace-entities = $b ?? 1 !! 0;
}
multi method replace-entities(Int $i where 1 | 0) {
	$!parser.replace-entities = $i;
}


method parser-version() {
    my $ver = cglobal('xml2', 'xmlParserVersion', Str);
    Version.new($ver.match(/ (.)? (..)+ $/).list.join: '.')
}

method parse(Str $data, :$flags) {
	my $r = $!parser.parse($data, :$flags);
	# Without the assignment, nativecast() gets a P6Opaque.
	($r ~~ xmlDoc) ?? nativecast(XML::LibXML::Document, $r) !! $r;
}

method parse-xml(Str $xml, :$flags) is export {
	  my $r = $!parser.parse($xml, :$flags);
		($r ~~ xmlDoc) ?? nativecast(XML::LibXML::Document, $r) !! $r;
}

method parse-html(Str $html, :$flags) is export {
	my $r = $!parser.parse($html, :$flags);
	($r ~~ xmlDoc) ?? nativecast(XML::LibXML::Document, $r) !! $r;
}

method parse-string(Str $s, :$url, :$flags) is export {
	my $r = $!parser.parse-string($s, :$url, :$flags);
	($r ~~ xmlDoc) ?? nativecast(XML::LibXML::Document, $r) !! $r;
}

method parse-file(Str $filename, :$flags) is export {
	my $r = $!parser.parse-file($filename, :$flags);
	($r ~~ xmlDoc) ?? nativecast(XML::LibXML::Document, $r) !! $r;
}
