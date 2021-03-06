use v6;
use Test;

plan 7;

use XML::LibXML;

my $xmlstring = '<foo>
                    <bar>
                        test 1
                    </bar>
                    <bar>
                        test 2
                    </bar>
                </foo>';

{
    my $parser = XML::LibXML.new();
    my $doc    = $parser.parse($xmlstring);

    ok $doc, 'Parsing successful.';

    {
        my @nodes = $doc.find("/foo/bar");

        is @nodes.elems, 2, 'Two bar nodes';

        #~ # TEST
        #~ ok( $doc->isSameNode($nodes[0]->ownerDocument),
            #~ 'Doc is the same as the owner document.' );

        #~ my $compiled = XML::LibXML::XPathExpression->new("/foo/bar");
        #~ foreach my $idx (1..3) {
            #~ @nodes = $doc->findnodes( $compiled );
            #~ # TEST*3
            #~ is( scalar( @nodes ), 2, "Two nodes for /foo/bar - try No. $idx" );
        #~ }

        #~ # TEST
        #~ ok( $doc->isSameNode($nodes[0]->ownerDocument),
            #~ 'Same owner as previous one',
        #~ );

        #~ my $n = $doc->createElement( "foobar" );

        #~ my $p = $nodes[1]->parentNode;
        #~ $p->insertBefore( $n, $nodes[1] );

        #~ # TEST

        #~ ok( $p->isSameNode( $doc->documentElement ), 'Same as document elem' );
        #~ @nodes = $p->childNodes;
        #~ # TEST
        #~ is( scalar( @nodes ), 6, 'Found child nodes' );
    }

    {
        my $result = $doc.find("/foo/bar");
        #~ # TEST
        #~ ok( $result, ' TODO : Add test name' );
        #~ # TEST
        #~ ok( $result->isa( "XML::LibXML::NodeList" ), ' TODO : Add test name' );
        #~ # TEST
        #~ is( $result->size, 2, ' TODO : Add test name' );

        #~ # TEST

        #~ ok( $doc->isSameNode($$result[0]->ownerDocument), ' TODO : Add test name' );

        #~ $result = $doc->find( XML::LibXML::XPathExpression->new("/foo/bar") );
        #~ # TEST
        #~ ok( $result, ' TODO : Add test name' );
        #~ # TEST
        #~ ok( $result->isa( "XML::LibXML::NodeList" ), ' TODO : Add test name' );
        #~ # TEST
        #~ is( $result->size, 2, ' TODO : Add test name' );

        #~ # TEST

        #~ ok( $doc->isSameNode($$result[0]->ownerDocument), ' TODO : Add test name' );

        #~ $result = $doc->find( "string(/foo/bar)" );
        #~ # TEST
        #~ ok( $result, ' TODO : Add test name' );
        #~ # TEST
        #~ ok( $result->isa( "XML::LibXML::Literal" ), ' TODO : Add test name' );
        #~ # TEST
        #~ ok( $result->string_value =~ /test 1/, ' TODO : Add test name' );

        $result = $doc.find("string(/foo/bar)");
        ok $result,               'xmlDoc.find as string';
        ok $result.isa(Str),      'xmlDoc.find isa Str';
        ok $result ~~ /'test 1'/, 'xmlDoc.find matches /"test 1"/';

        #~ $result = $doc->find( XML::LibXML::XPathExpression->new("count(/foo/bar)") );
        #~ # TEST
        #~ ok( $result, ' TODO : Add test name' );
        #~ # TEST
        #~ ok( $result->isa( "XML::LibXML::Number" ), ' TODO : Add test name' );
        #~ # TEST
        #~ is( $result->value, 2, ' TODO : Add test name' );

        $result = $doc.find("contains(/foo/bar[1], 'test 1')");
        ok $result,           'xmlDoc.find as boolean';
        ok $result.isa(Bool), 'xmlDoc.find isa Bool';
        #~ is( $result->string_value, "true", ' TODO : Add test name' );

        #~ $result = $doc->find( XML::LibXML::XPathExpression->new("contains(/foo/bar[1], 'test 1')") );
        #~ # TEST
        #~ ok( $result, ' TODO : Add test name' );
        #~ # TEST
        #~ ok( $result->isa( "XML::LibXML::Boolean" ), ' TODO : Add test name' );
        #~ # TEST
        #~ is( $result->string_value, "true", ' TODO : Add test name' );

        #~ $result = $doc->find( "contains(/foo/bar[3], 'test 1')" );
        #~ # TEST
        #~ ok( $result == 0, ' TODO : Add test name' );

        #~ # TEST

        #~ ok( $doc->exists("/foo/bar[2]"), ' TODO : Add test name' );
        #~ # TEST
        #~ is( $doc->exists("/foo/bar[3]"), 0, ' TODO : Add test name' );
        #~ # TEST
        #~ is( $doc->exists("-7.2"),1, ' TODO : Add test name' );
        #~ # TEST
        #~ is( $doc->exists("0"),0, ' TODO : Add test name' );
        #~ # TEST
        #~ is( $doc->exists("'foo'"),1, ' TODO : Add test name' );
        #~ # TEST
        #~ is( $doc->exists("''"),0, ' TODO : Add test name' );
        #~ # TEST
        #~ is( $doc->exists("'0'"),1, ' TODO : Add test name' );

        #~ my ($node) = $doc->findnodes("/foo/bar[1]" );
        #~ # TEST
        #~ ok( $node, ' TODO : Add test name' );
        #~ # TEST
        #~ ok ($node->exists("following-sibling::bar"), ' TODO : Add test name');
    }

    #~ {
        #~ # test the strange segfault after xpathing
        #~ my $root = $doc->documentElement();
        #~ foreach my $bar ( $root->findnodes( 'bar' )  ) {
            #~ $root->removeChild($bar);
        #~ }
        #~ # TEST
        #~ ok(1, ' TODO : Add test name');
        #~ # warn $root->toString();

        #~ $doc =  $parser->parse_string( $xmlstring );
        #~ my @bars = $doc->findnodes( '//bar' );

        #~ foreach my $node ( @bars ) {
            #~ $node->parentNode()->removeChild( $node );
        #~ }
        #~ # TEST
        #~ ok(1, ' TODO : Add test name');
    #~ }
}

#~ {
    #~ # from #39178
    #~ my $p = XML::LibXML->new;
    #~ my $doc = $p->parse_file("example/utf-16-2.xml");
    #~ # TEST
    #~ ok($doc, ' TODO : Add test name');
    #~ my @nodes = $doc->findnodes("/cml/*");
    #~ # TEST
    #~ ok (@nodes == 2, ' TODO : Add test name');
    #~ # TEST
    #~ is ($nodes[1]->textContent, "utf-16 test with umlauts: \x{e4}\x{f6}\x{fc}\x{c4}\x{d6}\x{dc}\x{df}", ' TODO : Add test name');
#~ }

#~ {
    #~ # from #36576
    #~ my $p = XML::LibXML->new;
    #~ my $doc = $p->parse_html_file("example/utf-16-1.html");
    #~ # TEST
    #~ ok($doc, ' TODO : Add test name');
    #~ use utf8;
    #~ my @nodes = $doc->findnodes("//p");
    #~ # TEST
    #~ ok (@nodes == 1, ' TODO : Add test name');

    #~ # TEST
    #~ _utf16_content_test(\@nodes, 'nodes content is fine.');
#~ }

#~ {
    #~ # from #36576
    #~ my $p = XML::LibXML->new;
    #~ my $doc = $p->parse_html_file("example/utf-16-2.html");
    #~ # TEST
    #~ ok($doc, ' TODO : Add test name');
    #~ my @nodes = $doc->findnodes("//p");
    #~ # TEST
    #~ is (scalar(@nodes), 1, 'Found one p');
    #~ # TEST
    #~ _utf16_content_test(\@nodes, 'p content is fine.');
#~ }

{
    # from #69096
    my $doc   = XML::LibXML::Document.new(:version<1.0>, :enoding<utf-8>);
    my $root  = $doc.new-elem('root');
    $doc.root = $root;
    my $e     = $doc.new-elem("child");
    my $e2    = $doc.new-elem("child");
    my $t1    = $doc.new-text( "te" );
    my $t2    = $doc.new-text( "st" );
    $root.push: $e;
    $root.push: $e2;
    $e2.push:   $t1;
    $e2.push:   $t2;

    #~ $doc->normalize(); # XXX that is not exposed by libxml2
    my @cn = $doc.find('//child[text()="test"]');
    #~ is( scalar( @cn ), 1, 'xpath testing adjacent text nodes' );
}

#~ sub _utf16_content_test
#~ {
    #~ local $Test::Builder::Level = $Test::Builder::Level + 1;

    #~ my ($nodes_ref, $blurb) = @_;

    #~ SKIP:
    #~ {
        #~ if (XML::LibXML::LIBXML_RUNTIME_VERSION() < 20700)
        #~ {
            #~ skip "UTF-16 and HTML broken in libxml2 < 2.7", 1;
        #~ }

        #~ is ($nodes_ref->[0]->textContent,
            #~ "utf-16 test with umlauts: \x{e4}\x{f6}\x{fc}\x{c4}\x{d6}\x{dc}\x{df}",
            #~ $blurb,
        #~ );
    #~ }
#~ }
