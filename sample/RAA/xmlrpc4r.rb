#!/usr/bin/env ruby

# You need to install XML-RPC from RAA

require "xmlrpc/client"

server = XMLRPC::Client.new( "raa.ruby-lang.org", "/xmlrpc/1.0/" )
# server = XMLRPC::Client.new( "raa.ruby-lang.org", "/xmlrpc/1.0/", 80, "myProxyHostName", proxyHostPort )

ok, param = server.call2( "raa.getAllListings" )
p param

ok, param = server.call2( "raa.getProductTree" )
p param

klass = Struct.new( "Category", :major, :minor )
category = klass.new( "Library", "XML" )
ok, param = server.call2( "raa.getInfoFromCategory", category )
p param

ok, param = server.call2( "raa.getModifiedInfoSince", Time.at( Time.now.to_i - 24 * 3600 ))
p param

ok, param = server.call2( "raa.getInfoFromName", "XML-RPC" )
p param
