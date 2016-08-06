use v6.c;

use XML::LibXML;
use XML::LibXML::Dtd;

#use Test::More tests => 18;
use Test;

# cw: Removed three tests.
plan 15;

# cw: Not really a test.
#ok(1, "Loaded");

my $dtdstr = 'example/test.dtd'.IO.open.slurp-rest;
$dtdstr.=subst(/\r/, '', :g);
$dtdstr.=subst(/<[ \r \n ]>*$/, '', :g);

# cw: Also not really a test.
#ok $dtdstr, "DTD String read");

{
    # parse a DTD from a SYSTEM ID
    my $dtd = XML::LibXML::DTD.new('ignore', 'example/test.dtd');
    isa-ok $dtd, XML::LibXML::DTD, 'XML::LibXML::DTD successful.';

    my $newstr = $dtd.toString();
    $newstr.=subst(/\r/, '', :g);
    $newstr.=subst(/^.*?\n/, '', :g);
    $newstr.=subst(/\n^.*\n?$/, '', :g);
    # cw: Needed because libxml2 will complete the tag, which will then make
    #     the test fail.
    $newstr.=subst(/\n\]\>$$/, '');
    is $newstr, $dtdstr, 'DTD String same as new string.';
}

{
    # parse a DTD from a string
    my $dtd = XML::LibXML::DTD.parse-string($dtdstr);
    
    isa-ok 
        $dtd, XML::LibXML::DTD, 
        'parsed string with XML::LibXML::DTD.parse-string()';
}

{
    # validate with the DTD
    my $dtd = XML::LibXML::DTD.parse_string($dtdstr);

    isa-ok 
        $dtd, XML::LibXML::DTD, 
        'XML::LibXML::DTD.parse_string() still works';

    my $xml = parse-file('example/article.xml');
    isa-ok $xml, XML::LibXML::Document, 'parsed the article.xml file';
    ok $xml.is_valid($dtd), 'is_valid passes';
    lives-ok { $xml.validate($dtd) }, 'validate passes';
}

{
    # validate a bad document
    my $dtd = XML::LibXML::DTD.parse_string($dtdstr);
    isa-ok 
        $dtd, XML::LibXML::DTD, 
        'XML::LibXML::DTD.parse_string() 3';

    my $xml = parse-file('example/article_bad.xml');
    nok $xml.is_valid($dtd), 'is_valid() fails';
    nok $xml.validate($dtd), 'validate() fails';
    
    my $parser = XML::LibXML::Parser.new;

    # cw: Difference in interface currently eliminates this.
    #ok $parser->validation(1), 'Parser validation() returns 1';
    # ---
    # this one is OK as it's well formed (no DTD)

    dies-ok 
        { $parser.parse-file('example/article_bad.xml'); },
        'Parser threw an exception on bad xml';
    
    dies-ok 
        { $parser.parse-file('example/article_internal_bad.xml'); },
        'Parser threw an exception on another type of bad xml';
}

# this test fails under XML-LibXML-1.00 with a segfault because the
# underlying DTD element in the C libxml library was freed twice

{
    my $doc = parse-file('example/dtd.xml');
    my @a = $doc.getChildNodes;
    is @a.elems, 2, 'Two child nodes';
}

##
# Tests for ticket 2021
{
    my $dtd;
    dies-ok 
        { $dtd = XML::LibXML::DTD.new('',''); },
        'XML::LibXML::DTD not defined when invoked with empty parameters';
}

{
    my $dtd = XML::LibXML::DTD.new('', 'example/test.dtd');
    isa-ok 
        $dtd, XML::LibXML::DTD, 
        'XML::LibXML::DTD.new works correctly';
}
