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

method keep-blanks($b) {
	$!parser.keep-blanks(+$b);
}

method replace-entities($b) {
	$!parser.replace-entities(+$b);
}

method pedantic($b) {
	$!parser.pedantic(+$b);
}

method linenumbers($b?) {
	return $!parser.linenumbers unless $b.defined;
	$!parser.linenumbers = +$b;
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
