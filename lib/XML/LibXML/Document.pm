use v6;
use nqp;
use NativeCall;

use XML::LibXML::Globals;
use XML::LibXML::CStructs :types;
use XML::LibXML::C14N;
use XML::LibXML::Subs;
use XML::LibXML::Node;
use XML::LibXML::Attr;
use XML::LibXML::Dom;
use XML::LibXML::Enums;
use XML::LibXML::Error;
use XML::LibXML::Element;

multi trait_mod:<is>(Routine $r, :$aka!) { $r.package.^add_method($aka, $r) };

unit class XML::LibXML::Document is xmlDoc is repr('CStruct') does XML::LibXML::Nodish;

sub xmlNewDoc(Str)
  returns XML::LibXML::Document
  is native('xml2') { * }

sub xmlDocGetRootElement(xmlDoc)
  returns XML::LibXML::Node
  is native('xml2') { * }

sub xmlDocSetRootElement(xmlDoc, xmlNode)
  returns XML::LibXML::Node
  is native('xml2') { * }

sub xmlNewNode(xmlNs, Str)
  returns XML::LibXML::Node
  is native('xml2')
  { * }

sub xmlNewText(Str)
  returns XML::LibXML::Node
  is native('xml2') { * }

sub xmlNewDocComment(xmlDoc, Str)
  returns XML::LibXML::Node
  is native('xml2') { * }

sub xmlNewCDataBlock(xmlDoc, Str, int32)
  returns XML::LibXML::Node
  is native('xml2') { * }

sub xmlReplaceNode(xmlNode, xmlNode)
  returns XML::LibXML::Node
  is native('xml2') { * }

sub xmlNewDocProp(xmlDoc, Str, Str)
  returns XML::LibXML::Attr
  is native('xml2') { * }

sub xmlNewDocNode(xmlDoc, xmlNs, Str, Str)
  returns XML::LibXML::Node
  is native('xml2') { * }

method process-xincludes {
    sub xmlXIncludeProcessFlags(xmlDoc, int32) returns int32 is native('xml2') { * }
    xmlXIncludeProcessFlags(self, 0)
}


# Objects that implement the Document interface have all properties and functions of the Node interface as well as the properties and functions defined below.

## Properties of objects that implement the Document interface:

# cw: Do we need STORE methods for the Proxy objects, if they are truly read-only?
#     If the answer is ro, then do we really need the Proxy objects at all?

#| This read-only property is an object that implements the DocumentType interface.
method doctype is aka<type> {
    xmlElementType(nqp::p6box_i(nqp::getattr_i(nqp::decont(self), xmlDoc, '$!type')))
}

#~ implementation
    #~ This read-only property is an object that implements the DOMImplementation interface.

#| This read-only property is an object that implements the Element interface.
method documentElement
    is aka<root>
    is aka<getDocumentElement>
{
    Proxy.new(
        FETCH => -> $ {
            nativecast(XML::LibXML::Element, xmlDocGetRootElement(self))
        },
        STORE => -> $, $new {
            my $root = xmlDocGetRootElement(self);
            $root ?? xmlReplaceNode($root, $new)
                  !! xmlDocSetRootElement(self, $new);
            $new
        }
    )
}

#~ inputEncoding
    #~ This read-only property is a String.

#| This read-only property is a String.
method xmlEncoding is aka<encoding> {
    Proxy.new(
        FETCH => -> $ {
            xmlGetCharEncodingName(self.charset).lc
        },
        STORE => -> $, Str $new {
            my $enc = xmlParseCharEncoding($new);
            die if $enc < 0;
            self.charset = $enc;
            $new
        }
    )
}

#| This property is a String and can raise an object that implements the DOMException interface on setting.
method xmlVersion is aka<version> {
    Proxy.new(
        FETCH => -> $ {
            Version.new(nqp::getattr(nqp::decont(self), xmlDoc, '$!version'))
        },
        STORE => -> $, $new {
            nqp::bindattr(nqp::decont(self), xmlDoc, '$!version', nqp::unbox_s(~$new));
            $new
        }
    )
}

#| This property is a Boolean and can raise an object that implements the DOMException interface on setting.
method xmlStandalone is aka<standalone> {
    Proxy.new(
        FETCH => -> $ {
            nqp::p6box_i(nqp::getattr_i(nqp::decont(self), xmlDoc, '$!standalone'))
        },
        STORE => -> $, int32 $new {
            #~ self.standalone =
            nqp::bindattr_i(nqp::decont(self), xmlDoc, '$!standalone', $new);
            $new
        }
    )
}

#~ strictErrorChecking
    #~ This property is a Boolean.

#| This property is a String.
method documentURI is aka<uri> {
    Proxy.new(
        FETCH => -> $ {
            nqp::getattr(nqp::decont(self), xmlDoc, '$!uri')
        },
        STORE => -> $, $new {
            nqp::bindattr(nqp::decont(self), xmlDoc, '$!uri', nqp::unbox_s(~$new));
            $new
        }
    )
}

method base-uri() {
    Proxy.new(
        FETCH => -> $ {
            xmlNodeGetBase(self, self)
        },
        STORE => -> $, $new {
            #~ nqp::bindattr(nqp::decont(self), xmlDoc, '$!uri', nqp::unbox_s(~$new));
            xmlNodeSetBase(self, ~$new);
            $new
        }
    )
}

#~ domConfig
    #~ This read-only property is an object that implements the DOMConfiguration interface.

## Functions of objects that implement the Document interface:

#~ createElement(tagName)
    #~ This function returns an object that implements the Element interface.
    #~ The tagName parameter is a String.
    #~ This function can raise an object that implements the DOMException interface.
#~ createDocumentFragment()
    #~ This function returns an object that implements the DocumentFragment interface.
#~ createTextNode(data)
    #~ This function returns an object that implements the Text interface.
    #~ The data parameter is a String.
#~ createComment(data)
    #~ This function returns an object that implements the Comment interface.
    #~ The data parameter is a String.
#~ createCDATASection(data)
    #~ This function returns an object that implements the CDATASection interface.
    #~ The data parameter is a String.
    #~ This function can raise an object that implements the DOMException interface.
#~ createProcessingInstruction(target, data)
    #~ This function returns an object that implements the ProcessingInstruction interface.
    #~ The target parameter is a String.
    #~ The data parameter is a String.
    #~ This function can raise an object that implements the DOMException interface.
#~ createAttribute(name)
    #~ This function returns an object that implements the Attr interface.
    #~ The name parameter is a String.
    #~ This function can raise an object that implements the DOMException interface.
#~ createEntityReference(name)
    #~ This function returns an object that implements the EntityReference interface.
    #~ The name parameter is a String.
    #~ This function can raise an object that implements the DOMException interface.
#~ getElementsByTagName(tagname)
    #~ This function returns an object that implements the NodeList interface.
    #~ The tagname parameter is a String.
#~ importNode(importedNode, deep)
    #~ This function returns an object that implements the Node interface.
    #~ The importedNode parameter is an object that implements the Node interface.
    #~ The deep parameter is a Boolean.
    #~ This function can raise an object that implements the DOMException interface.
#~ createElementNS(namespaceURI, qualifiedName)
    #~ This function returns an object that implements the Element interface.
    #~ The namespaceURI parameter is a String.
    #~ The qualifiedName parameter is a String.
    #~ This function can raise an object that implements the DOMException interface.
#~ createAttributeNS(namespaceURI, qualifiedName)
    #~ This function returns an object that implements the Attr interface.
    #~ The namespaceURI parameter is a String.
    #~ The qualifiedName parameter is a String.
    #~ This function can raise an object that implements the DOMException interface.
#~ getElementsByTagNameNS(namespaceURI, localName)
    #~ This function returns an object that implements the NodeList interface.
    #~ The namespaceURI parameter is a String.
    #~ The localName parameter is a String.
#~ getElementById(elementId)
    #~ This function returns an object that implements the Element interface.
    #~ The elementId parameter is a String.
#~ adoptNode(source)
    #~ This function returns an object that implements the Node interface.
    #~ The source parameter is an object that implements the Node interface.
    #~ This function can raise an object that implements the DOMException interface.
#~ normalizeDocument()
    #~ This function has no return value.
#~ renameNode(n, namespaceURI, qualifiedName)
    #~ This function returns an object that implements the Node interface.
    #~ The n parameter is an object that implements the Node interface.
    #~ The namespaceURI parameter is a String.
    #~ The qualifiedName parameter is a String.
    #~ This function can raise an object that implements the DOMException interface.



    multi method elems() {
        sub xmlChildElementCount(xmlDoc)           returns ulong      is native('xml2') { * }
        xmlChildElementCount(self)
    }

    method push($child) is aka<appendChild> {
        sub xmlAddChild(xmlDoc,  xmlNode)  returns XML::LibXML::Node  is native('xml2') { * }
        xmlAddChild(self, $child)
    }

    multi method Str(:$format = 0) {
        my $ret;

        for self.childNodes -> $n {
          next if [&&](
            $n.type == XML_DTD_NODE,
            $XML::LibXML::Globals::skipDTD,
            $XML::LibXML::Globals::skipXMLDeclaration
          );
          # cw: Returning (Any)
          $ret ~= $n.Str(:$format);
        }
        $ret;
    }

    #~ multi method Str(:$skip-xml-declaration) {
        #~ self.list.grep({ !xmlIsBlankNode($_) })».Str.join
        #~ self.list.grep({ $_.type != XML_DTD_NODE && !xmlIsBlankNode($_) })».Str(:!format).join: ''
        #~ self.list».Str(:!format).join: ''

    #~ }

    method gist(XML::LibXML::Document:D:) {
        my $result = CArray[Str].new();
        my $len    = CArray[int32].new();
        $result[0] = "";
        $len[0]    = 0;
        xmlDocDumpFormatMemory(self, $result, $len, 1);
        $result[0]
    }

method new(:$version = '1.0', :$encoding) {
    my $doc       = xmlNewDoc(~$version);
    $doc.encoding = $encoding if $encoding;
    $doc
}

method new-doc-fragment(XML::LibXML::Document:D:) {
    nativecast(XML::LibXML::Node, domNewDocFragment(self));
}

method new-elem(Str $elem) is aka<createElement> {
    if $elem.match(/[ ^<[\W\d]> | <-[\w_.-]> ]/) -> $bad {
        fail X::XML::InvalidName.new( :name($elem), :pos($bad.from), :routine(&?ROUTINE) )
    }

    my $node = xmlNewNode( xmlNs, $elem );
    nqp::bindattr(nqp::decont($node), xmlNode, '$!doc', nqp::decont(self.doc));
    nativecast(XML::LibXML::Element, $node);
}

multi method new-elem-ns(Pair $kv, $uri) {
    my ($prefix, $name) = $kv.key.split(':', 2);

    unless $name {
        $name   = $prefix;
        $prefix = Str;
    }

    my $ns = xmlNewNs(xmlDoc, $uri, $prefix);

    my $buffer = $kv.value && xmlEncodeEntitiesReentrant(self, $kv.value);
    my $node   = xmlNewDocNode(self, $ns, $name, $buffer);
    nqp::bindattr(nqp::decont($node), xmlNode, '$!nsDef', nqp::decont($ns));
    nqp::bindattr(nqp::decont($node), xmlNode, '$!doc',   nqp::decont(self));
    nativecast(::('XML::LibXML::Element'), $node);
}
multi method new-elem-ns(%kv where *.elems == 1, $uri) {
    self.new-elem-ns(%kv.list[0], $uri)
}
multi method new-elem-ns($name, $uri) {
    self.new-elem-ns($name => Str, $uri)
}

method createElementNS($_uri, $_name) {
    unless testNodeName($_name) {
        die "bad name";
        # cw: For .resume inside CATCH
        return;
    }

    self.new-elem-ns($_name, $_uri);
}

multi method createAttribute($key, $value) {
    self.new-attr($key => $value);
}
multi method createAttribute(*%kv where *.elems == 1) {
    self.new-attr(%kv.list[0])
}
multi method createAttribute(Pair $kv) {
    self.new-attr($kv);
}

multi method new-attr($key, $value) {
    self.new-attr($key => $value);
}
multi method new-attr(Pair $kv) {
    my $buffer = xmlEncodeEntitiesReentrant(self, $kv.value);
    my $attr   = xmlNewDocProp(self, $kv.key, $buffer);
    nqp::bindattr(nqp::decont($attr), xmlAttr, '$!doc', nqp::decont(self));
    nativecast(::('XML::LibXML::Attr'), $attr);
}
multi method new-attr(*%kv where *.elems == 1) {
    self.new-attr(%kv.list[0])
}


multi method new-attr-ns(Pair $kv, $uri) {
    my $root = self.root;
    fail "Can't create a new namespace on an attribute!" unless $root;

    my ($prefix, $name) = $kv.key.split(':', 2);

    unless $name {
        $name   = $prefix;
        $prefix = Str;
    }

    my $ns = xmlSearchNsByHref(self, $root, $uri);
    unless $ns {
        $ns = xmlNewNs($root, $uri, $prefix); # create a new NS if the NS does not already exists
    }

    my $buffer = xmlEncodeEntitiesReentrant(self, $kv.value);
    my $attr   = xmlNewDocProp(self, $name, $buffer);
    xmlSetNs($attr, $ns);
    nqp::bindattr(nqp::decont($attr), xmlAttr, '$!doc', nqp::decont(self));
    nativecast(::('XML::LibXML::Attr'), $attr);
}
multi method new-attr-ns(%kv where *.elems == 1, $uri) {
    self.new-attr-ns(%kv.list[0], $uri);
}

method createAttributeNS($nsUri, $name, $val) {
    self.new-attr-ns($name => $val, $nsUri);
}

method new-text(Str $text) {
    my $node = xmlNewText( $text );
    nqp::bindattr(nqp::decont($node), xmlNode, '$!doc', nqp::decont(self));
    $node
}

method new-comment(Str $comment) {
    my $node = xmlNewDocComment( self, $comment );
    nqp::bindattr(nqp::decont($node), xmlNode, '$!doc', nqp::decont(self));
    $node
}

method new-cdata-block(Str $cdata) {
    my $node = xmlNewCDataBlock( self, $cdata, xmlStrlen($cdata) );
    nqp::bindattr(nqp::decont($node), xmlNode, '$!doc', nqp::decont(self));
    $node
}

method createTextNode(Str $content) {
    my $newText = self.new-text($content);
    my $docfrag = self.new-doc-fragment();
    xmlAddChild($docfrag.getNodePtr, $newText.getNodePtr);

    $newText;
}

method setDocumentElement($e) {
    my $elem = nativecast(xmlNode, $e);

    if $elem.type != XML_ELEMENT_NODE {
        die "setDocumentElement: ELEMENT node required";
        # cw: To properly handle .resume in CATCH {}
        return;
    }

    domImportNode(self, $elem, 1, 1);
    my $oelem = xmlDocGetRootElement(self);
    if (!$oelem.defined || !$oelem._private.defined) {
        xmlDocSetRootElement(self, $elem);
    }
    else {
        my $docfrag = self.new-doc-fragment();
        xmlReplaceNode($oelem, $elem);
        xmlAddChild($docfrag, $oelem)
        # PmmFixOwner( ((ProxyNodePtr)oelem->_private), docfrag);
        #PmmFixOwner( SvPROXYNODE(proxy), PmmPROXYNODE(self));
        #    if $elem.private !=:= Pointer;
    }
}
