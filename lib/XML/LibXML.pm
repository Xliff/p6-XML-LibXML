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
	$!parser.keep-blanks = $b ?? 1 !! 0;
}
multi method keep-blanks(Int $i where 1 | 0) {
	$!parser.keep-blanks = $i;
}

multi method validate(Bool $b) {
	$!parser.validate = $b ?? 1 !! 0;
}
multi method validate(Int $i where 1 | 0) {
	$!parser.validate = $i;
}

multi method linenumbers(Bool $b) {
	$!parser.linenumbers = $b ?? 1 !! 0;
}
multi method linenumbers(Int $i where 1 | 0) {
	$!parser.linenumbers = $i;
}

multi method pedantic(Bool $b) {
	$!parser.pedantic = $b ?? 1 !! 0;
}
multi method pedantic(Int $i where 1 | 0) {
	$!parser.pedantic = $i;
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

method parse(Str $data) {
	my $r = $!parser.parse($data, flags => 0);
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
