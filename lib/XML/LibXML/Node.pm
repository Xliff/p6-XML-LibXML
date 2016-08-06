use v6;
use nqp;
use NativeCall;
use XML::LibXML::Attr;
use XML::LibXML::C14N;
use XML::LibXML::CStructs :types;
use XML::LibXML::Dom;
use XML::LibXML::Enums;
use XML::LibXML::Subs;
use XML::LibXML::XPath;

class XML::LibXML::Node is xmlNode is repr('CStruct') { ... }

multi trait_mod:<is>(Routine $r, :$aka!) { $r.package.^add_method($aka, $r) };

my &_nc = &nativecast;

role XML::LibXML::Nodish does XML::LibXML::C14N {

    method childNodes() 
        is aka<list> 
        is aka<getChildNodes>
    {
        my $elem = self.children.getNode;
        my @ret;
        while $elem {
            # cw: Should we attempt to cast to the right node type, 
            #     or should the user be responsible for that?
            push @ret, _nc(XML::LibXML::Node, $elem); # unless $elem.type == XML_ATTRIBUTE_NODE;
            $elem = $elem.next.getNode;
        }
        @ret
    }

    method AT-POS(Int $idx) {
        my $elem = self.children.getNode;
        my $i    = 0;
        while $elem && $i++ < $idx {
            $elem = $elem.next.getNode;
        }
        $elem
    }

    #~ method base-uri() {
        #~ xmlNodeGetBase(self.doc, self)
    #~ }

    method type() is aka<nodeType> {
        xmlElementType(nqp::p6box_i(nqp::getattr_i(nqp::decont(self), xmlNode, '$!type')));
    }

    method _name() {
        do given self.type {
            when XML_COMMENT_NODE {
                "#comment";
            }
            when XML_CDATA_SECTION_NODE {
                "#cdata-section";
            }
            when XML_TEXT_NODE {
                "#text";
            }
            when XML_DOCUMENT_NODE|XML_HTML_DOCUMENT_NODE|XML_DOCB_DOCUMENT_NODE {
                "#document";
            }
            when XML_DOCUMENT_FRAG_NODE {
                "#document-fragment";
            }
            #when XML_ELEMENT_NODE {
            #    $!name;
            #}
            default {
                self.ns && self.ns.name
                    ?? self.ns.name ~ ':' ~ self.localname
                    !! self.localname
            }
        }
    }

    method nodeName is aka<getName> {
        return self._name;
    }

    method attrs() {
        my $elem = _nc(XML::LibXML::Attr, self.properties);
        my @ret;
        while $elem {
            push @ret, $elem;
            $elem = _nc(XML::LibXML::Attr, $elem.next);
        }
        @ret
    }

    method remove-attr($name, :$ns) {
        #~ $ns ?? xmlUnsetNsProp(self, $ns, $name) !!
        xmlUnsetProp(self, $name)
    }

    # cw: Maybe move this to XML::LibXML::XPath?
    method !regns($ctxt, $ns_list) {
        given $ns_list {
            when Pair {
                $ctxt.register-namespace($_.key, $_.value);
            }
                
            when List {
                # If the first element is not a list, then assume it is
                # a namespace definition.
                given ($_[0]) {
                    when Str {
                        $ctxt.register-namespace($ns_list[0], $ns_list[1]);
                    }

                    when List {
                        for $ns_list -> $ns_def {
                            given $ns_def {
                                $ctxt.register-namespace($_[0], $_[1]) 
                                    when Array;

                                $ctxt.register-namespace($_.key, $_.value)
                                    when Pair;

                                $ctxt.register_namespace(
                                    $_<namespace>, $_<uri>
                                ) when Hash;    
                            }
                        }
                    }

                    default {
                        die "Invalid type [{$_.^name}] passed to namespace option";
                    }
                }
            }

            default {
                die "Invalid type [{$_.^name}] passed to namespace option";
            }
        }
    }

    method find($xpath, :$opts) is aka<findnodes> {
        my $ctxt = XML::LibXML::XPath.new(self.doc);
        $ctxt.setNode(self.getNode());

        # Used to handle namespace limitation of libxml2
        if $opts.defined {
            # cw: Process any other options we may need to hack
            #     libxml back into shape.
            self!regns($ctxt, $opts<namespaces>) 
                if $opts<namespaces>.defined;
        }

        my $comp = xmlXPathCompile($xpath);
        die "Invalid XPath expression '{$xpath}'" 
            unless $comp.defined; 

        my $res = xmlXPathCompiledEval($comp, $ctxt);
        return unless $res.defined;

        do given xmlXPathObjectType($res.type) {
            when XPATH_UNDEFINED {
                Nil
            }
            when XPATH_NODESET {
                my $set = $res.nodesetval;

                (^$set.nodeNr).map({
                    _nc(XML::LibXML::Node, $set.nodeTab[$_])
                }).cache if $set.defined;
            }
            when XPATH_BOOLEAN {
                so $res.boolval
            }
            when XPATH_NUMBER {
                $res.floatval
            }
            when XPATH_STRING {
                $res.stringval
            }
            default {
                fail "NodeSet type $_ NYI"
            }
        }
    }

    method isSameNode($n) {
        return False unless $n.defined;
        
        my $n1 = self ~~ Pointer ?? self !! self.getP;
        my $n2 =   $n ~~ Pointer ??   $n !!   $n.getP;
        return +$n1 == +$n2;
    }

    method getContent() {
        return xmlNodeGetContent(self.getNode);
    }

    multi method elems() {
        sub xmlChildElementCount(xmlNode) returns ulong is native('xml2') { * }
        xmlChildElementCount(self.getNode());
    }

    method hasChildNodes {
        self.childNodes.defined && self.childNodes.elems;
    }

    method push($child) is aka<appendChild> {
        sub xmlAddChild(xmlNode, xmlNode)  returns XML::LibXML::Node  is native('xml2') { * }
        xmlAddChild(self.getNode, $child.getNode);

        # cw: Set doc's internalSubset if appending a DTD node.
        DomSetIntSubset(self.doc, $child) 
            if $child.defined && $child.type == XML_DTD_NODE;
    }

    # subclasses can override this if they have their own Str method.
    multi method Str(:$level = 0, :$format = 1) {
        my $buffer = xmlBufferCreate(); # XXX free
        my $size   = xmlNodeDump($buffer, self.doc, self, $level, $format);
        $buffer.value;
    }

    method toString 
        is aka<to_literal>
        is aka<textContent>
        is aka<string_value>
    {
        # cw: Must use libxml2 to properly decode entities!
        sub xmlXPathCastNodeToString(xmlNode)   returns Str   is native('xml2') { * }
        sub xmlSubstituteEntitiesDefault(int32) returns int32 is native('xml2') { * }

        my $old = xmlSubstituteEntitiesDefault(0);
        xmlXPathCastNodeToString(self.getNode);
    }

    method parentNode() {
        return self.parent;
    }

    method setNodeName(Str $n) {
        sub xmlNodeSetName(xmlNode, Str)       is native('xml2') { * }

        #die "Bad name" if testNodeName($n);
        #xmlNodeSetName(self, $n);

        if testNodeName($n) {
            xmlNodeSetName(self.getNode(), $n);        
        } 
        else {
            die "Bad name";
        }
    }

    method setAttribute(Str $a, Str $v) {
        sub xmlSetProp(xmlNode, Str, Str)       is native('xml2') { * }

        if testNodeName($a) {
            # cw: Note, this method locks us into libxml2 versions of 2.6.21 and 
            #     later. libxml2 does -not- provide us a mechanism to test and 
            #     implement backwards compatibility.
            xmlSetProp(self.getNode, $a, $v);
        } 
        else {
            die "Bad name '$a'";
        }
    }

    method setAttributeNS(Str $namespace, Str $name, Str $val) {
        if !testNodeName($name) {
            die "Bad name '$name'";
            # cw: Yes, I know this looks weird, but is done incase we 
            #     .return from a CATCH{}
            return;
        }

        my ($prefix, $localname) = $name.split(':');

        if !$localname {
            $localname = $prefix;
            $prefix = Str;
        }
 
        my xmlNs $ns;
        my $attr_ns;
        if $namespace.defined {
            $attr_ns = $namespace.trim;
            if $attr_ns.chars {
                $ns = xmlSearchNsByHref(self.doc, self, $attr_ns);

                if $ns.defined && !$ns.uri {
                    my @all_ns := _nc(
                        CArray[xmlNsPtr],
                        xmlGetNsList(self.doc, self)
                    );

                    if (@all_ns.defined) {
                        my $i = 0;
                        repeat {
                            my $nsp = @all_ns[$i++];
                            $ns = _nc(xmlNs, $nsp);
                            last if $ns.uri && ($ns.uri eq $namespace);
                        } while ($ns);
                        #xmlFree($all_ns);
                    }
                }
            }

            if (!$ns.defined) {
                # create new ns
                if $prefix.defined {
                    my $attr_p = $prefix.subst(/s/, '');
                    if $attr_p.chars {
                        $ns = xmlNewNs(
                            self.getNode(), $attr_ns, $attr_p
                        );
                    } 
                    else {
                        $ns = xmlNs;
                    }
                }
            }
        }

        if $attr_ns.defined && $attr_ns.chars && ! $ns.defined {
            die "bad ns attribute!";
            return            
        }

        xmlSetNsProp(self.getNode(), $ns, $localname, $val);
    }

    method hasAttribute($a) {
        my $ret = domGetAttrNode(self.getNode(), $a);
        
        # cw: If we want to use xmlFree() then we might need to adopt this
        #     pattern for all unused values we get from libxml2
        my $retVal = $ret ?? True !! False;
        #xmlFree($ret)

        return $retVal;
    }

    method hasAttributeNS($_ns, Str $_name) {
        my ($ns, $name);
        $ns = $_ns.trim if $_ns.defined;
        $name = $_name.trim if $_name.defined;

        $ns = Str unless $ns.defined && $ns.chars;

        my $attr = _nc(
            xmlAttr,
            xmlHasNsProp(self.getNode(), $name, $ns)
        );

        return $attr.defined && $attr.type == XML_ATTRIBUTE_NODE;
    }

    method getAttribute(Str $a) {
        sub xmlGetNoNsProp(xmlNode, Str)  returns Str      is native('xml2') { * }

        my $name = $a.defined ?? $a.trim !! Nil;
        return unless $name;

        my $ret;
        unless (
            $ret = xmlGetNoNsProp(self.getNode(), $name)
        ) {
            my ($prefix, $localname) = $a.split(':');

            if !$localname {
                $localname = $prefix;
                $prefix = Str;
            }
            if $localname {
                my $ns = xmlSearchNs(self.doc, self, $prefix);
                if $ns {
                    $ret = xmlGetNsProp(
                        self.getNode(), $localname, $ns.uri
                    );
                }
            }
        }

        #my $retval = $ret.clone;
        #xmlFree($ret);

        return $ret;
    }

    method !getNamespaaceDeclURI($_name) {
        my $ret;
        my $ns = self.ns;
        while $ns.defined {
            if ($ns.name.defined || $ns.uri.defined) && $ns.name eq $_name {
                $ret = $ns.uri;
                last;
            } else {
                $ns = $ns.next;
            }
        }
        $ret;
    }

    method getAttributeNS($_uri, $_name, $_useEncoding = 0) {
        sub xmlGetProp(xmlNode, Str) returns Str is native('xml2') { * };

        my $name = $_name.defined ?? $_name.trim !! Nil;
        die "Invalid attribute name" unless $name.defined && $name.chars;

        my $ret;
        my $uri = $_uri.defined ?? $_uri.trim !! Nil;
        if $uri.defined && $uri eq XML_XMLNS_NS {
            $ret = self!getNamespaceDeclURI($name eq 'xmlns' ?? Nil !! $name);
        }
        else {
            my $node = self.getNode();
            $ret = $uri.defined && $uri.chars ??
                xmlGetNsProp($node, $name, $uri) 
                !!
                xmlGetProp($node, $name);
        }

        # cw: Encoding NYI.
        warn "useEncoding NYI" if $_useEncoding;

        $ret;
    }


    method getAttributeNode($a) {
        my $ret = domGetAttrNode(self.getNode, $a);
        #my $retVal = $ret.clone;
        #xmlFree($ret);

        # cw: Returns CStruct allocated from libxml2!
        return $ret.defined ?? nativecast(XML::LibXML::Attr, $ret) !! Nil;
    }

    # Bypass type checking on $ns since it can be Nil
    method getAttributeNodeNS($ns, Str $name) {
        my ($attr_ns, $attr_name);
        $attr_ns = $ns.trim if $ns.defined;
        $attr_name = $name.trim if $name.defined;

        return unless $attr_name ~~ Str && $attr_name.chars;

        $attr_ns = Str unless $attr_ns.defined && $attr_ns.chars;
        my $ret_p = xmlHasNsProp(
            self.getNode(), $attr_name, $attr_ns
        );
        my $ret = _nc(XML::LibXML::Attr, $ret_p);

        # cw: Deep XS code that has yet to be grokked.
        #my $retVal = PmmNodeToSv(
        #    $ret_p,
        #    PmmOWNERPO(PmmPROXYNODE(self))
        #);

        return $ret.defined ?? 
            $ret.type == XML_ATTRIBUTE_NODE ??
                $ret !! Nil
            !! Nil;
    }

    method setAttributeNode(xmlAttr $an) {
        unless $an {
            die "Lost attribute";
            # cw: If caught and .resume'd, execution may return here.
            return;
        }

        return unless $an.type == XML_ATTRIBUTE_NODE;

        if $an.doc =:= self.doc {
            domImportNode(self.doc, $an, 1, 1);
        }

        my $ret;
        $ret = domGetAttrNode(
            self.getNode(), $an.name
        );
        if $ret {
            return unless $ret !=:= $an;
            
            xmlReplaceNode(
                _nc(xmlNode, $ret), 
                _nc(xmlNode, $an)
            );
        } 
        else {
            xmlAddChild(
                self.getNodePtr, 
                $an.getAttrPtr
            );
        }

        # cw: ????
        #if ( attr->_private != NULL ) {
        #    PmmFixOwner( SvPROXYNODE(attr_node), PmmPROXYNODE(self) );
        #}

        return unless $ret;
        my $retVal = _nc(XML::LibXML::Node, $ret);

        # cw: ?????
        #PmmFixOwner( SvPROXYNODE(RETVAL), NULL );
        nativecast(XML::LibXML::Node, $ret);
    }

    #method setAttributeNodeNS(xmlAttr $an!) {
    method setAttributeNodeNS($an) {
        sub xmlReconciliateNs(xmlDoc, xmlNode) returns int32 is native('xml2') { * }

        if !$an.defined {
            die "lost attribute node";
            # cw: For .resume in CATCH{}
            return;
        }

        return unless $an.type == XML_ATTRIBUTE_NODE;

        #domImportNode(self.doc, $an, 1, 1) if $an.doc !=:= self.doc;
        #my xmlNs $ns = $an.ns;
        my $ns = $an.ns;
        my $ret = xmlHasNsProp(
            self, 
            $ns.defined ?? $ns.uri !! Str,
            $an.localname
        );

        if $ret.defined && $ret.type == XML_ATTRIBUTE_NODE {
            return if $ret =:= $an;
            xmlReplaceNode($ret, $an);
        } 
        else {
            xmlAddChild(
                self.getNodePtr, 
                $an.getNodePtr
            );
            xmlReconciliateNs(self.doc, self);
        }

        # cw: ??? XS
        #if ( attr->_private != NULL ) {
        #    PmmFixOwner( SvPROXYNODE(attr_node), PmmPROXYNODE(self) );
        #}

        return $ret;
    }

    method removeAttributeNode(xmlAttr $an!) {
        if !$an.defined {
            die "lost attribute node";
            # cw: For .resume in CATCH{}
            return;
        }

        return unless 
            $an.type == XML_ATTRIBUTE_NODE
            &&
            $an.parent !=:= self;

        xmlUnlinkNode(_nc(xmlNodePtr, $an));

        # cw: ????
        # $ret = PmmNodeToSv($ret_p, NUL)
        # PmmFixOwner( SvPROXYNODE($ret), NULL)

        return $an;
    }

    method removeAttributeNS($_nsUri, $_name) {
        sub xmlFreeProp(xmlAttrPtr) is native('xml2') { * }

        my $nsUri = $_nsUri.defined ?? $_nsUri.trim !! Str;
        my $name = $_name.defined ?? $_name.trim !! Nil;

        return unless $name.defined && $name.chars;

        $nsUri = Str unless $nsUri.chars;
        my xmlAttr $xattr = xmlHasNsProp(
            self.getNode(), $name, $nsUri
        );
        xmlUnlinkNode($xattr.getNodePtr) 
            if $xattr.defined && $xattr.type == XML_ATTRIBUTE_NODE;

        if ($xattr.defined && $xattr._private.defined) {
            # cw: ???? XS code
            # PmmFixOwner((ProxyNodePtr)xattr->_private, NULL);
        } 
        else {
            xmlFreeProp($xattr.getAttrPtr);
        }
    }

    method setNamespace($_uri, $_prefix = Nil, $flag = 1) {
        my $ret = 0;
        my $ns;

        if (! $_uri.defined && ! $_prefix.defined) {
            $ns = xmlSearchNs(self.doc, self.getNode(), Str);
            if ($ns.defined && $ns.uri.defined && $ns.uri.chars) {
                $ret = 0;
            } elsif $flag {
                xmlSetNs(self.getNode(), xmlNs);
                $ret = 1;
            } 
            else {
                $ret = 0;
            }
        } elsif $flag {
            $ns = xmlSearchNs(self.doc, self.getNode(), $_prefix);

            if ($ns.defined) {
                if $ns.uri eq $_uri {
                    $ret = 1;
                } 
                else {
                    $ns = xmlNewNs(self.getNode(), $_uri, $_prefix);
                }
            } 
            else {
                $ns = xmlNewNs(self.getNode(), $_uri, $_prefix);
            }
            
            $ret = $ns.defined;
        }

        xmlSetNs(self.getNode(), $ns) if $flag && $ns.defined;

        $ret;
    }

    method setData($value) 
        is aka<setValue>
        is aka<_setData>
    {
        domSetNodeValue(self.getNode(), $value);
    }

    method nodeValue() 
        is aka<getValue>
        is aka<getData>
    {
        domGetNodeValue(self);
    }

    method unbindNode() 
        is aka<unlink>
        is aka<unlinkNode>
    {
        DomReparentRemovedNode(self);
        xmlUnlinkNode(self.getNodePtr)
            if  self.type == XML_DOCUMENT_NODE       || 
                self.type == XML_DOCUMENT_FRAG_NODE;
    }

    method removeChild(XML::LibXML::Nodish:D: $old) {
        my $ret = domRemoveChild( self, $old );
        return unless $ret.defined;

        DomReparentRemovedNode($old);
        #RETVAL = PmmNodeToSv(ret, NULL);
        nqp::nativecallrefresh(self);
        $ret;        
    }

    # cw: To my eyes, $deep looks like it does nothing in the p5 
    #     version
    method cloneCommon($c) {
        unless self.type == XML_DTD_NODE {
            if self.doc.defined {
                xmlSetTreeDoc($c.getNodePtr, self.doc.getNodePtr);
            }
            my $newDoc = domNewDocFragment();
            xmlAddChild($c.getNodePtr, $newDoc.getNodePtr);
        }
    }

    method firstChild {
        _nc(XML::LibXML::Node, self.children);
    }

    method previousSibling {
        _nc(XML::LibXML::Node, self.prev);
    }

    method hasAttributes {
        return False 
            if self.type == XML_ATTRIBUTE_NODE || 
               self.type == XML_DTD_NODE;

        self.properties.defined
    }

    method removeChildNodes {
        my $frag = domNewDocFragment();
        my $elem = self.children.getNode;

        while ($elem) {
            xmlUnlinkNode($elem.getNodePtr);
            if $elem.type == any(XML_ATTRIBUTE_NODE, XML_DTD_NODE) {
                xmlFreeNode($elem.getNodePtr);
            } 
            else {
                if $frag.children.defined {
                    domAddNodeToList($elem, $frag.last.getNode, xmlNode);
                }
                else {
                    setObjAttr($frag, '$!children', $elem, :what(xmlNode));
                    setObjAttr($frag, '$!last', $elem, :what(xmlNode));
                    setObjAttr($elem, '$!paren', $frag);
                }
            }
            $elem = $elem.next.getNode;
        }
        nqp::nativecallrefresh(self);
    }

    method insertBefore($node, $refnode) {
        my $r = domInsertBefore(self, $node, $refnode);
        return unless $r.defined;

        DomSetIntSubset(self.doc, $r) if $r.type == XML_DTD_NODE;
        # Fix owner: $r and $self
    }

    method insertAfter($node, $refnode) {
        my $r = domInsertAfter(self, $node, $refnode);
        return unless $r.defined;

        DomSetIntSubset(self.doc, $r) if $r.type == XML_DTD_NODE;
        # Fix owner: $r and self
    }

    method replaceChild($node, $repnode) {
        if self.type == XML_DOCUMENT_NODE {
            given $node.type {
                when XML_ELEMENT_NODE {
                    warn "replaceChild with an element on a document node not supported yet!";
                    return;
                }

                when XML_DOCUMENT_FRAG_NODE {
                    warn "replaceChild with a document fragment node on a document node not supported yet!";
                    return;
                }

                when XML_TEXT_NODE | XML_CDATA_SECTION_NODE {
                    warn "replaceChild with a text node not supported on a document node!";
                    return;
                }
            }
        }

        my $repDoc = $repnode.doc;
        my $ret = domReplaceChild(self, $node, $repnode);
        return unless $ret.defined;

        DomReparentRemovedNode($ret);
        if ($node.type == XML_DTD_NODE) {
            DomSetIntSubset($repDoc, $node);
        }
        $ret;
    }

    method replaceNode($node) {
        return if domIsParent(self, $node);
        
        #owner = PmmOWNERPO(PmmPROXYNODE(self));
        my $oldDoc = self.doc;
        my $ret;
        if self.type != XML_ATTRIBUTE_NODE {
            # cw: -YYY- We may need to worry about self.parent
            $ret = domReplaceChild(
                self.parent.getNode, $node.getNode , self.getNode
            );
        }
        else {
            $ret = xmlReplaceNode( self, $node );
        }
        if  $ret.defined {
            DomReparentRemovedNode($ret);
            
            #RETVAL = PmmNodeToSv(ret, PmmOWNERPO(PmmPROXYNODE(ret)));
            if $node.type == XML_DTD_NODE {
                DomSetIntSubset($oldDoc, $node);
            }
            #if ( nNode->_private != NULL ) {
            #    PmmFixOwner(PmmPROXYNODE(nNode), owner);
            #}
        }
        else {
            # cw: Again, is this fatal, or should this be something 
            #     we can catch?
            warn "replacement failed";
            return;
        }
        $ret;
    }

    method addSibling($node) {
        sub xmlAddSibling(xmlNode, xmlNode) returns xmlNode is native('xml2') { * }
        sub xmlCopyNode(xmlNode, int32)     returns xmlNode is native('xml2') { * }

        if $node.type == XML_DOCUMENT_FRAG_NODE {
            # cw: This does NOT sound fatal.
            warn "Adding document fragments with addSibling not yet supported!";
            return;
        }
        #owner = PmmOWNERPO(PmmPROXYNODE(self));

        my $ret;
        if  self.type == XML_TEXT_NODE  && 
            $node.type == XML_TEXT_NODE &&
            self.name eq $node.name
        {
            # As a result of text merging, the added node may be freed.
            my $copy = xmlCopyNode($node, 0);
            $ret = xmlAddSibling(self.getNode, $copy);

            if $ret.defined {
                #RETVAL = PmmNodeToSv(ret, owner);

                # Unlink original node.
                xmlUnlinkNode($node.getNodePtr);
                DomReparentRemovedNode($node);
            }
            else {
                xmlFreeNode($copy);
                return;
            }
        }
        else {
            $ret = xmlAddSibling( self, $node );

            if $ret.defined {
                #RETVAL = PmmNodeToSv(ret, owner);
                if ($node.type == XML_DTD_NODE) {
                    DomSetIntSubset(self.doc, $node);
                }
                #PmmFixOwner(SvPROXYNODE(RETVAL), owner);
            }
            else {
                return;    
            }
        }

        $ret;
    }

}

class XML::LibXML::Node does XML::LibXML::Nodish {

    method name() {
        self._name();
    }

    method getBase {
        xmlNode;
    }
    
    #~ multi method Str() {
        #~ my $result = CArray[Str].new();
        #~ my $len    = CArray[int32].new();
        #~ $result[0] = "";
        #~ $len[0]    = 0;
        #~ xmlDocDumpMemory(self, $result, $len);
        #~ $result[0]
    #~ }

    #~ multi method Str(:$skip-xml-declaration!) {
        #self.list.grep({ !xmlIsBlankNode($_) })».Str.join
        #~ self.elems
            #~ ?? self.list.grep({ $_.type != XML_DTD_NODE && !xmlIsBlankNode($_) })».Str(:$skip-xml-declaration).join: ''
            #~ !! self.Str(:!format)
    #~ }


    method cloneNode {
        # P6 clone NYI, so we have to do it the hard way.
        # other nodes will almost certianly have to implement their
        # own versions that *must* call callwith at the end.
        my $c;
        # cw: Oh, I had no idea how ugly this was going to turn out.
        $c = XML::LibXML::New(
            :_private($._private),
            :type($.type),
            :localname($.localname),
            :children($.children),
            :last($.last),
            :parent($.parent),
            :next($.next),
            :prev($.prev),
            :doc($.doc),
            :ns($.ns),
            :value($.value),
            :properties($.properties),
            :nsDef($.nsDef),
            :psvi($.psvi),
            :line($.line),
            :extra($.extra)
        );
        return unless $c.defined;

        self.cloneCommon($c);
        $c;
    }
}

