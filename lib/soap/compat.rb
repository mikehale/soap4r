=begin
SOAP4R - Compatibility definitions.
Copyright (C) 2003  NAKAMURA, Hiroshi.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PRATICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 675 Mass
Ave, Cambridge, MA 02139, USA.
=end


STDERR.puts "Loading compatibility library..."


require 'xsd/qname'
require 'xsd/ns'
require 'xsd/charset'
require 'soap/mapping'
require 'soap/rpc/rpc'
require 'soap/rpc/element'
require 'soap/rpc/driver'
require 'soap/rpc/cgistub'
require 'soap/rpc/router'
require 'soap/rpc/standaloneServer'


module SOAP


module RPC
  RubyTypeNamespace = Mapping::RubyTypeNamespace
  RubyTypeInstanceNamespace = Mapping::RubyTypeInstanceNamespace
  RubyCustomTypeNamespace = Mapping::RubyCustomTypeNamespace
  ApacheSOAPTypeNamespace = Mapping::ApacheSOAPTypeNamespace

  DefaultMappingRegistry = Mapping::DefaultRegistry

  def self.obj2soap(*arg); Mapping.obj2soap(*arg); end
  def self.soap2obj(*arg); Mapping.soap2obj(*arg); end
  def self.ary2soap(*arg); Mapping.ary2soap(*arg); end
  def self.ary2md(*arg); Mapping.ary2md(*arg); end
  def self.fault2exception(*arg); Mapping.fault2exception(*arg); end

  def self.defined_methods(obj)
    if obj.is_a?(Module)
      obj.methods - Module.methods
    else
      obj.methods - Kernel.instance_methods(true)
    end
  end
end


NS = XSD::NS
Charset = XSD::Charset
RPCUtils = RPC
RPCServerException = RPC::ServerException
RPCRouter = RPC::Router


class StandaloneServer < RPC::StandaloneServer
  def initialize(*arg)
    super
    @router = @soaplet.app_scope_router
    methodDef if respond_to?('methodDef')
  end

  alias addServant add_servant
  alias addMethod add_method
  alias addMethodAs add_method_as
end


class CGIStub < RPC::CGIStub
  def initialize(*arg)
    super
    methodDef if respond_to?('methodDef')
  end

  alias addServant add_servant

  def addMethod(receiver, methodName, *paramArg)
    addMethodWithNSAs(@default_namespace, receiver, methodName, methodName, *paramArg)
  end

  def addMethodAs(receiver, methodName, methodNameAs, *paramArg)
    addMethodWithNSAs(@default_namespace, receiver, methodName, methodNameAs, *paramArg)
  end

  def addMethodWithNS(namespace, receiver, methodName, *paramArg)
    addMethodWithNSAs(namespace, receiver, methodName, methodName, *paramArg)
  end

  def addMethodWithNSAs(namespace, receiver, methodName, methodNameAs, *paramArg)
    add_method_with_namespace_as(namespace, receiver, methodName, methodNameAs, *paramArg)
  end
end


class Driver < RPC::Driver
  include Devel::Logger::Severity

  attr_accessor :logdev
  alias logDev= logdev=
  alias logDev logdev
  alias setWireDumpDev wiredump_dev=
  alias setDefaultEncodingStyle default_encodingstyle=
  alias mappingRegistry= mapping_registry=
  alias mappingRegistry mapping_registry

  def initialize(log, logid, namespace, endpoint_url, httpproxy = nil, soapaction = nil)
    super(endpoint_url, namespace, soapaction)
    @logdev = log
    @logid = logid
    @logid_prefix = "<#{ @logid }> "
    self.httpproxy = httpproxy if httpproxy
    log(SEV_INFO) { 'initialize: initializing SOAP driver...' }
  end

  def invoke(headers, body)
    log(SEV_INFO) { "invoke: invoking message '#{ body.type }'." }
    super
  end

  def call(name, *params)
    log(SEV_INFO) { "call: calling method '#{ name }'." }
    log(SEV_DEBUG) { "call: parameters '#{ params.inspect }'." }
    log(SEV_DEBUG) {
      params = Mapping.obj2soap(params, @mapping_registry).to_a
      "call: parameters '#{ params.inspect }'."
    }
    super
  end

  def addMethod(name, *params)
    addMethodWithSOAPActionAs(name, name, nil, *params)
  end

  def addMethodAs(name_as, name, *params)
    addMethodWithSOAPActionAs(name_as, name, nil, *params)
  end

  def addMethodWithSOAPAction(name, soapaction, *params)
    addMethodWithSOAPActionAs(name, name, soapaction, *params)
  end

  def addMethodWithSOAPActionAs(name_as, name, soapaction, *params)
    add_method_with_soapaction_as(name, name_as, soapaction, *params)
  end

  def setLogDev(logdev)
    self.logdev = logdev
  end

private

  def log(sev)
    @logdev.add(sev, nil, self.class) { @logid_prefix + yield } if @logdev
  end
end


module RPC
  class MappingRegistry < SOAP::Mapping::Registry
    def initialize(*arg)
      super
    end

    def add(obj_class, soap_class, factory, info = nil)
      if (info.size > 1)
	raise RuntimeError.new("Parameter signature changed.  [namespace, name] should be { :type => XSD::QName.new(namespace, name) } from 1.5.0.")
      end
      @map.add(obj_class, soap_class, factory, { :type => info[0] })
    end
    alias :set :add
  end

  class Router
    alias mappingRegistry mapping_registry
    alias mappingRegistry= mapping_registry=
  end
end


end
