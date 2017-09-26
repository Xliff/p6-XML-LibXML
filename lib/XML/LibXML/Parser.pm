use v6;

use nqp;

use NativeCall;
use XML::LibXML::Globals;
use XML::LibXML::CStructs :types;

multi trait_mod:<is>(Routine $r, :$aka!) { $r.package.^add_method($aka, $r) };

unit class XML::LibXML::Parser is xmlParserCtxt is repr('CStruct');

my $ERRNO = cglobal(Str, 'errno', int32);

sub strerror(int32) is native { * }

use XML::LibXML::Dom;
use XML::LibXML::Enums;
use XML::LibXML::Error;
use XML::LibXML::Subs;

sub xmlCtxtReadDoc(xmlParserCtxt, Str, Str, Str, int32)  returns xmlDoc is native('xml2') { * }
sub xmlCtxtReadFile(xmlParserCtxt, Str, Str, int32)      returns xmlDoc is native('xml2') { * }
sub xmlReadDoc(Str, Str, Str, int32)                     returns xmlDoc is native('xml2') { * }
sub xmlReadMemory(Str, int32, Str, Str, int32)           returns xmlDoc is native('xml2') { * }
sub htmlParseFile(Str, Str)                              returns xmlDoc is native('xml2') { * }
sub htmlCtxtReadDoc(xmlParserCtxt, Str, Str, Str, int32) returns xmlDoc is native('xml2') { * }
sub htmlCtxtReadFile(xmlParserCtxt, Str, Str, int32)     returns xmlDoc is native('xml2') { * }
sub htmlCtxtUseOptions(xmlParserCtxt, int32)             returns int32  is native('xml2') { * }
sub xmlCtxtUseOptions(xmlParserCtxt, int32)              returns int32  is native('xml2') { * }
sub xmlNewParserCtxt                                     returns XML::LibXML::Parser   is native('xml2') { * }
sub htmlNewParserCtxt                                    returns XML::LibXML::Parser   is native('xml2') { * }

sub setOptions($ctxt, $flags, $html) {
    my $myflags = $flags;
    unless $myflags +& XML_PARSE_DTDLOAD {
        $myflags = $myflags +^ (
            (XML_PARSE_DTDVALID +| XML_PARSE_DTDATTR +| XML_PARSE_NOENT)
        );
        xmlKeepBlanksDefault($myflags +& XML_PARSE_NOBLANKS ?? 1 !! 0);

        # cw: EXTERNAL ENTITY LOADER FUNC -- NYI
    }

    $html ??
        htmlCtxtUseOptions($ctxt, +$flags)
        !!
        xmlCtxtUseOptions($ctxt, +$flags);
}

method new(:$html = False, :$flags) {
    xmlKeepBlanksDefault($html ?? 0 !! 1);
    my $self = $html
            ?? htmlNewParserCtxt()
            !! xmlNewParserCtxt();

    # This stops xml2 printing errors to stderr
    xmlSetStructuredErrorFunc(
      nativecast(Pointer, $self),
      -> OpaquePointer, OpaquePointer { }
    );
    setOptions($self, $flags, $html) if $flags.defined;
        ;
    $self;
}

method setFlags($flags, :$on, :$off) {
  die "Confusing on/off parameters"
    if [&&]($on.defined, $off.defined, $on.Bool == $off.Bool);
  die "Invalid mask specified {$flags}"
    if $flags > (+XML_PARSE_BIG_LINES * 2 - 1);
  # cw: How can we deteremine $html parameter if not tracked by object?
	setOptions(
    self,
		($off || !$on) ?? $.options +& +^$flags !! $.options +| $flags,
    1
	);
}

method setOptions(Int $options) {
    die "Invalid options specified {$options}"
        if $options > (+XML_PARSE_BIG_LINES * 2 - 1);
    &setOptions(self, $options, self.html);
}

# Parser pass-through options.
method keep-blanks(Int $b where 1 | 0)
#  is aka<keep_blanks>
{
	self.setFlags(XML_PARSE_NOBLANKS, :on(!$b))
}

method pedantic(Int $b where 1 | 0)
#  is aka<pedantic_parser>
{
	self.setFlags(XML_PARSE_PEDANTIC, :on($b));
}

method validate(Int $b where 1 | 0)
#  is aka<validation>
{
	self.setFlags(XML_PARSE_DTDVALID, :on($b));
}

method expand-entities(Int $b where 1 | 0)
#  is aka<expand_entities>
{
  self.setFlags(XML_PARSE_NOENT, :on($b));
}

multi method replace-entities(Int $b where 1 | 0)
{
  self.setFlags(XML_PARSE_NOENT, :on($b));
}

method recover(Int $b where 1 | 0) {
  self.setFlags(XML_PARSE_RECOVER, :on($b));
}

multi method linenumbers is rw
  #is aka<line_numbers>
{
  Proxy.new(
    FETCH => -> $        { return $.linenumbers  },
    STORE => -> $, $new  { $.linenumbers = $new }
  );
}
multi method linenumbers(Int $i where 1 | 0) {
	$.linenumbers = +$i;
}

method parse(Str:D $str, Str :$uri, :$flags) {
    my $useFlags = $flags.defined ?? $flags
        !! self.html == 1 ?? HTML_PARSE_RECOVER + HTML_PARSE_NOBLANKS !! 0;

    my $doc = self.html == 1
            ?? htmlCtxtReadDoc(self, $str, $uri, Str, +$useFlags)
            !! xmlCtxtReadDoc(self, $str, $uri, Str, +$useFlags);
    fail XML::LibXML::Error.get-last(self, :orig($str)) unless $doc;
    $doc
}

# cw: This method is to fulfil testing requirements from 06elements.
method parse-string($str, :$url, :$flags) {
    sub xmlReadDoc(Str, Str, Str, int32) returns xmlDoc is native('xml2') { * }

    return unless $str.defined && $str.trim.chars;

    my $myurl   = $url.defined   ??  $url   !! Str;
    my $myflags = $flags.defined ?? +$flags !! 0;

    # cw: -YYY- Not worring about encoding at this time.
    my $ret = xmlReadDoc($str, $url, Str, $myflags);
    fail XML::LibXML::Error.get-last(self, :orig($str)) unless $ret;
    $ret;
}

multi method parse-file(Str $s, :$flags = 0) {
    unless $s.chars && $s.IO.e {
        warn "Attempted to parse using" ~ (!$s.defined || !$s.chars) ??
            "null filename" !! "bad filename '{$s}'";
        return;
    }

    # cw: Should we assume unicode, here or just use default?
    # cw: What about defined options? -- For now we set blank, but that might
    #     come a-haunting in the future.
    my $myflags = $flags.defined ?? +$flags !! 0;
    self.html ??
        #htmlCtxtReadFile(self, $s, "UTF8", self.options)
        htmlCtxtReadFile(self, $s, Str, $myflags)
        !!
        #xmlCtxtReadFile(self, $s, "UTF8", self.options)
        xmlCtxtReadFile(self, $s, Str, $myflags)
}

method parse-xml-chunk($_xml) {
    my $xml = $_xml.defined ?? $_xml.trim !! Nil;
    return unless $xml.defined && $xml.chars;

    # cw: The naked 0 below may not be correct.
    my $ret = domReadWellBalancedString(xmlDoc, $xml, 0);
    my $frag;
    if $ret.defined {
        my $end;

        $frag = domNewDocFragment();
        # cw: Also might want to make a helper function for this.
        nqp::bindattr(
            nqp::decont($frag),
            xmlNode,
            '$!children',
            nqp::decont(nativecast(xmlNodePtr, $ret))
        );
        $end = $ret;
        while $end.next.defined {
            $end.parent = nativecast(xmlNodePtr, $frag);
            $end = nativecast(xmlNode, $end.next);
        }
        nqp::bindattr(
            nqp::decont($end),
            xmlNode,
            '$!parent',
            nqp::decont(nativecast(xmlNodePtr, $frag))
        );
        nqp::bindattr(
            nqp::decont(nativecast(xmlNode, $frag)),
            xmlNode,
            '$!last',
            nqp::decont(nativecast(xmlNodePtr, $end))
        );
    }
    $frag;
}

#~ multi method expand-entities() {
    #~ sub xmlCtxtUseOptions(xmlParserCtxt, int32)                     returns int32 is native('xml2') { * }
    #~ say self.replaceEntities;
    #~ say xmlCtxtUseOptions(self, XML_PARSE_NOENT);
    #~ say self.replaceEntities;

    #~ if (scalar(@_) and $_[0]) {
      #~ return $self->__parser_option(XML_PARSE_NOENT | XML_PARSE_DTDLOAD,1);
    #~ }
    #~ return $self->__parser_option(XML_PARSE_NOENT,@_);
#~ }
#~ multi method expand-entities() {
    #~ my $self = shift;
    #~ if (scalar(@_) and $_[0]) {
      #~ return $self->__parser_option(XML_PARSE_NOENT | XML_PARSE_DTDLOAD,1);
    #~ }
    #~ return $self->__parser_option(XML_PARSE_NOENT,@_);
#~ }
