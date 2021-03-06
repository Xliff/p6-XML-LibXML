use v6;
use Test;

##
# these testcases are for xml canonization interfaces.
#

plan 18;

use XML::LibXML;

my $parser = XML::LibXML.new();

{
    my $doc = $parser.parse('<a><b/> <c/> <!-- d --> </a>');
    is $doc.c14n,            '<a><b></b> <c></c>  </a>',           'basic test';
    is $doc.c14n(:comments), '<a><b></b> <c></c> <!-- d --> </a>', 'basic test with comments';
}

{
    my $doc = $parser.parse('<a><b/><![CDATA[ >e&f<]]><!-- d --> </a>');
    is $doc.c14n,            '<a><b></b> &gt;e&amp;f&lt; </a>',           'cdata';
    is $doc.c14n(:comments), '<a><b></b> &gt;e&amp;f&lt;<!-- d --> </a>', 'cdata with comments';
}

{
    my $doc = $parser.parse('<a a="foo"/>');
    is $doc.c14n, '<a a="foo"></a>', 'attribute';
}

{
    my $doc = $parser.parse('<b:a xmlns:b="http://foo"/>');
    is $doc.c14n, '<b:a xmlns:b="http://foo"></b:a>', 'attribute with namespace';
}

# ----------------------------------------------------------------- #
# The C14N says: remove unused namespaces, libxml2 just orders them
# ----------------------------------------------------------------- #
{
    my $doc = $parser.parse('<b:a xmlns:b="http://foo" xmlns:a="xml://bar"/>');
    is $doc.c14n, '<b:a xmlns:a="xml://bar" xmlns:b="http://foo"></b:a>', 'ordered attributes';

    # would be correct, but will not work.
    # ok $doc.c14n, '<b:a xmlns:b="http://foo"></b:a>';
}

# ----------------------------------------------------------------- #
# The C14N says: remove redundant namespaces
# ----------------------------------------------------------------- #
{
    my $doc = $parser.parse('<b:a xmlns:b="http://foo"><b:b xmlns:b="http://foo"/></b:a>');
    is $doc.c14n, '<b:a xmlns:b="http://foo"><b:b></b:b></b:a>', 'redundant attributes';
}

{
    my $doc = $parser.parse('<a xmlns="xml://foo"/>');
    is $doc.c14n, '<a xmlns="xml://foo"></a>', 'empty element with attribute';
}

{
    my $doc = $parser.parse(q:to<EOX>);
<?xml version="1.0" encoding="iso-8859-1"?>
<a><b/></a>
EOX

    is $doc.c14n, '<a><b></b></a>', 'xml declaration';
}

{
    my $doc = $parser.parse(q:to<EOX>);
<?xml version="1.0" encoding="iso-8859-1"?>
<a><b><c/><d/></b></a>
EOX
# / <-- just for messed up syntax highlighting
    is( $doc.c14n(:xpath<//d>), '<d></d>', 'canonize with xpath expressions' );
}

{
    my $doc = $parser.parse(q:to<EOX>);
<?xml version="1.0" encoding="iso-8859-1"?>
<a xmlns="http://foo/test#"><b><c/><d><e/></d></b></a>
EOX
# / <-- just for messed up syntax highlighting

    my $root = $doc.root;
    is $root.c14n(:xpath<//*[local-name()='d']>),  '<d></d>',                                               'c14n with xpath';
    is $doc.find("//*[local-name()='d']")[0].c14n, '<d xmlns="http://foo/test#"><e></e></d>',               'c14n with xpath and attributes';
    is $doc.root[0].c14n,                          '<b xmlns="http://foo/test#"><c></c><d><e></e></d></b>', 'c14n on the first child of the root node';
}

if XML::LibXML.parser-version before v2.6.20 {
    skip("skipping Exclusive C14N tests for libxml2 < 2.6.17") for 15..20;
} else {
  my $xml1 = q:to<EOX>;
<n0:local xmlns:n0="http://something.org" xmlns:n3="ftp://example.org">
  <n1:elem2 xmlns:n1="http://example.net" xml:lang="en">
     <n3:stuff xmlns:n3="ftp://example.org"/>
  </n1:elem2>
</n0:local>
EOX
# / <-- just for messed up syntax highlighting

  my $xml2 = q:to<EOX>;
<n2:pdu xmlns:n1="http://example.com"
           xmlns:n2="http://foo.example"
           xml:lang="fr"
           xml:space="preserve">
  <n1:elem2 xmlns:n1="http://example.net" xml:lang="en">
     <n3:stuff xmlns:n3="ftp://example.org"/>
  </n1:elem2>
</n2:pdu>
EOX
# / <-- just for messed up syntax highlighting

    my $xpath       = "(//. | //@* | //namespace::*)[ancestor-or-self::*[name()='n1:elem2']]";
    my $result      = qq{<n1:elem2 xmlns:n1="http://example.net" xml:lang="en">\n     <n3:stuff xmlns:n3="ftp://example.org"></n3:stuff>\n  </n1:elem2>};
    my $result_n0n2 = qq{<n1:elem2 xmlns:n1="http://example.net" xmlns:n2="http://foo.example" xml:lang="en">\n     <n3:stuff xmlns:n3="ftp://example.org"></n3:stuff>\n  </n1:elem2>};
    my $doc1        = $parser.parse($xml1);
    my $doc2        = $parser.parse($xml2);

    is $doc1.ec14n(:$xpath),                       $result,      'exclusive c14n for document 1';
    is $doc2.ec14n(:$xpath),                       $result,      'exclusive c14n for document 2';
    is $doc2.ec14n(:$xpath, :inc-prefixes<n1 n3>), $result,      'exclusive c14n with include prefixes <n1 n3>';
    is $doc2.ec14n(:$xpath, :inc-prefixes<n0 n2>), $result_n0n2, 'exclusive c14n with include prefixes <n1 n3>';
}

{
    my $xml    = '<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd" xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" xmlns:wsrl="http://docs.oasis-open.org/wsrf/rl-2" xmlns:wsp="http://schemas.xmlsoap.org/ws/2004/09/policy" xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/" xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:Profile="urn:ehealth:profiles:timestamping:1.0" xmlns:tsa="http://www.behealth.be/webservices/tsa" xmlns:urn="urn:oasis:names:tc:dss:1.0:core:schema" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:wsrp="http://docs.oasis-open.org/wsrf/rp-2" xmlns:wsa="http://www.w3.org/2005/08/addressing" xmlns:ds="http://www.w3.org/2000/09/xmldsig#" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><soapenv:Header><wsa:Action wsu:Id="Action">http://www.behealth.be/webservices/tsa/TSConsultTSBagRequest</wsa:Action><wsa:To wsu:Id="To">https://www.ehealth.fgov.be/timestampauthority_1_5/timestampauthority</wsa:To><wsa:MessageID wsu:Id="MessageID">urn:www.sve.man.ac.uk-54690551758351720271010843310</wsa:MessageID><wsa:ReplyTo wsu:Id="ReplyTo"><wsa:Address>http://www.w3.org/2005/08/addressing/anonymous</wsa:Address></wsa:ReplyTo></soapenv:Header><soapenv:Body wsu:Id="myBody"><TSConsultTSBagRequest xmlns="http://www.behealth.be/webservices/tsa"><tsa:IDHospital>tsa_0406798006_01</tsa:IDHospital><tsa:TSList><tsa:sequenceNumber>80300231753732</tsa:sequenceNumber><tsa:dateTime>1226995312781</tsa:dateTime></tsa:TSList></TSConsultTSBagRequest></soapenv:Body></soapenv:Envelope>';
    my $xpath  = q{(//. | //@* | //namespace::*)[ancestor-or-self::x:MessageID]};
    my $xpath2 = q{(//. | //@* | //namespace::*)[ancestor-or-self::*[local-name()='MessageID' and namespace-uri()='http://www.w3.org/2005/08/addressing']]};

    #~ my $doc = XML::LibXML->load_xml(string=>$xml);
    #~ my $xpc = XML::LibXML::XPathContext->new($doc);
    #~ $xpc->registerNs(x => "http://www.w3.org/2005/08/addressing");
    #~ my $expect = '<wsa:MessageID xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/" xmlns:wsa="http://www.w3.org/2005/08/addressing" xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="MessageID">urn:www.sve.man.ac.uk-54690551758351720271010843310</wsa:MessageID>';

    #~ is $doc->toStringEC14N( 0, $xpath2, [qw(soap)] ),       $expect, ' TODO : Add test name';
    #~ is $doc->toStringEC14N( 0, $xpath, $xpc, [qw(soap)] ),  $expect, ' TODO : Add test name';
    #~ is $doc->toStringEC14N( 0, $xpath2, $xpc, [qw(soap)] ), $expect, ' TODO : Add test name';
}
