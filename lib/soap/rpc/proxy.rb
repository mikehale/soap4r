# SOAP4R - RPC Proxy library.
# Copyright (C) 2000, 2003-2005  NAKAMURA, Hiroshi <nahi@ruby-lang.org>.

# This program is copyrighted free software by NAKAMURA, Hiroshi.  You can
# redistribute it and/or modify it under the same terms of Ruby's license;
# either the dual license version in 2003, or any later version.


require 'soap/soap'
require 'soap/processor'
require 'soap/mapping'
require 'soap/rpc/rpc'
require 'soap/rpc/element'
require 'soap/streamHandler'
require 'soap/mimemessage'


module SOAP
module RPC


class Proxy
  include SOAP

public

  attr_accessor :soapaction
  attr_accessor :mandatorycharset
  attr_accessor :allow_unqualified_element
  attr_accessor :default_encodingstyle
  attr_accessor :generate_explicit_type
  attr_reader :headerhandler
  attr_reader :streamhandler

  attr_accessor :mapping_registry
  attr_accessor :literal_mapping_registry

  attr_reader :operation

  def initialize(endpoint_url, soapaction, options)
    @endpoint_url = endpoint_url
    @soapaction = soapaction
    @options = options
    @streamhandler = HTTPStreamHandler.new(
      @options["protocol.http"] ||= ::SOAP::Property.new)
    @operation = {}
    @mandatorycharset = nil
    @allow_unqualified_element = true
    @default_encodingstyle = nil
    @generate_explicit_type = true
    @headerhandler = Header::HandlerSet.new
    @mapping_registry = nil
    @literal_mapping_registry = ::SOAP::Mapping::WSDLLiteralRegistry.new
  end

  def inspect
    "#<#{self.class}:#{@endpoint_url}>"
  end

  def endpoint_url
    @endpoint_url
  end

  def endpoint_url=(endpoint_url)
    @endpoint_url = endpoint_url
    reset_stream
  end

  def reset_stream
    @streamhandler.reset(@endpoint_url)
  end

  def set_wiredump_file_base(wiredump_file_base)
    @streamhandler.wiredump_file_base = wiredump_file_base
  end

  def test_loopback_response
    @streamhandler.test_loopback_response
  end

  def add_rpc_operation(qname, soapaction, name, param_def, opt = {})
    opt[:request_qname] = qname
    opt[:request_style] ||= :rpc
    opt[:response_style] ||= :rpc
    opt[:request_use] ||= :encoded
    opt[:response_use] ||= :encoded
    @operation[name] = Operation.new(soapaction, param_def, opt)
  end

  def add_document_operation(soapaction, name, param_def, opt = {})
    opt[:request_style] ||= :document
    opt[:response_style] ||= :document
    opt[:request_use] ||= :literal
    opt[:response_use] ||= :literal
    @operation[name] = Operation.new(soapaction, param_def, opt)
  end

  # add_method is for shortcut of typical rpc/encoded method definition.
  alias add_method add_rpc_operation
  alias add_rpc_method add_rpc_operation
  alias add_document_method add_document_operation

  def invoke(req_header, req_body, opt = create_options)
    opt = create_options
    route(req_header, req_body, opt, opt)
  end

  def call(name, *params)
    unless op_info = @operation[name]
      raise MethodDefinitionError, "method: #{name} not defined"
    end
    req_header = create_request_header
    req_body = SOAPBody.new(
      op_info.request_body(params, @mapping_registry, @literal_mapping_registry)
    )
    reqopt = create_options({
      :soapaction => op_info.soapaction || @soapaction,
      :default_encodingstyle => op_info.request_default_encodingstyle})
    resopt = create_options({
      :default_encodingstyle => op_info.response_default_encodingstyle})
    env = route(req_header, req_body, reqopt, resopt)
    receive_headers(env.header)
    raise EmptyResponseError.new("empty response") unless env
    begin
      check_fault(env.body)
    rescue ::SOAP::FaultError => e
      Mapping.fault2exception(e)
    end
    op_info.response_obj(env.body, @mapping_registry, @literal_mapping_registry)
  end

  def route(req_header, req_body, reqopt, resopt)
    req_env = SOAPEnvelope.new(req_header, req_body)
    reqopt[:external_content] = nil
    conn_data = marshal(req_env, reqopt)
    if ext = reqopt[:external_content]
      mime = MIMEMessage.new
      ext.each do |k, v|
      	mime.add_attachment(v.data)
      end
      mime.add_part(conn_data.send_string + "\r\n")
      mime.close
      conn_data.send_string = mime.content_str
      conn_data.send_contenttype = mime.headers['content-type'].str
    end
    conn_data = @streamhandler.send(@endpoint_url, conn_data,
      reqopt[:soapaction])
    if conn_data.receive_string.empty?
      return nil
    end
    unmarshal(conn_data, resopt)
  end

  def check_fault(body)
    if body.fault
      raise SOAP::FaultError.new(body.fault)
    end
  end

private

  def create_request_header
    headers = @headerhandler.on_outbound
    if headers.empty?
      nil
    else
      h = ::SOAP::SOAPHeader.new
      headers.each do |header|
        h.add(header.elename.name, header)
      end
      h
    end
  end

  def receive_headers(headers)
    @headerhandler.on_inbound(headers) if headers
  end

  def marshal(env, opt)
    send_string = Processor.marshal(env, opt)
    StreamHandler::ConnectionData.new(send_string)
  end

  def unmarshal(conn_data, opt)
    contenttype = conn_data.receive_contenttype
    if /#{MIMEMessage::MultipartContentType}/i =~ contenttype
      opt[:external_content] = {}
      mime = MIMEMessage.parse("Content-Type: " + contenttype,
	conn_data.receive_string)
      mime.parts.each do |part|
	value = Attachment.new(part.content)
	value.contentid = part.contentid
	obj = SOAPAttachment.new(value)
	opt[:external_content][value.contentid] = obj if value.contentid
      end
      opt[:charset] = @mandatorycharset ||
	StreamHandler.parse_media_type(mime.root.headers['content-type'].str)
      env = Processor.unmarshal(mime.root.content, opt)
    else
      opt[:charset] = @mandatorycharset ||
	::SOAP::StreamHandler.parse_media_type(contenttype)
      env = Processor.unmarshal(conn_data.receive_string, opt)
    end
    env
  end

  def create_header(headers)
    header = SOAPHeader.new()
    headers.each do |content, mustunderstand, encodingstyle|
      header.add(SOAPHeaderItem.new(content, mustunderstand, encodingstyle))
    end
    header
  end

  def create_options(hash = nil)
    opt = {}
    opt[:default_encodingstyle] = @default_encodingstyle
    opt[:allow_unqualified_element] = @allow_unqualified_element
    opt[:generate_explicit_type] = @generate_explicit_type
    opt.update(hash) if hash
    opt
  end

  class Operation
    attr_reader :soapaction
    attr_reader :request_style
    attr_reader :response_style
    attr_reader :request_use
    attr_reader :response_use

    def initialize(soapaction, param_def, opt)
      @soapaction = soapaction
      @request_style = opt[:request_style]
      @response_style = opt[:response_style]
      @request_use = opt[:request_use]
      @response_use = opt[:response_use]
      check_style(@request_style)
      check_style(@response_style)
      check_use(@request_use)
      check_use(@response_use)
      if @request_style == :rpc
        @rpc_request_qname = opt[:request_qname]
        if @rpc_request_qname.nil?
          raise MethodDefinitionError.new("rpc_request_qname must be given")
        end
        @rpc_method_factory =
          RPC::SOAPMethodRequest.new(@rpc_request_qname, param_def, @soapaction)
      else
        @doc_request_qnames = []
        @doc_response_qnames = []
        param_def.each do |inout, paramname, typeinfo|
          klass, nsdef, namedef = typeinfo
          if namedef.nil?
            raise MethodDefinitionError.new("qname must be given")
          end
          case inout
          when SOAPMethod::IN
            @doc_request_qnames << XSD::QName.new(nsdef, namedef)
          when SOAPMethod::OUT
            @doc_response_qnames << XSD::QName.new(nsdef, namedef)
          else
            raise MethodDefinitionError.new(
              "illegal inout definition for document style: #{inout}")
          end
        end
      end
    end

    def request_default_encodingstyle
      (@request_use == :encoded) ? EncodingNamespace : LiteralNamespace
    end

    def response_default_encodingstyle
      (@response_use == :encoded) ? EncodingNamespace : LiteralNamespace
    end

    def request_body(values, mapping_registry, literal_mapping_registry)
      if @request_style == :rpc
        request_rpc(values, mapping_registry)
      else
        request_doc(values, literal_mapping_registry)
      end
    end

    def response_obj(body, mapping_registry, literal_mapping_registry)
      if @response_style == :rpc
        response_rpc(body, mapping_registry)
      else
        response_doc(body, literal_mapping_registry)
      end
    end

  private

    def check_style(style)
      unless [:rpc, :document].include?(style)
        raise MethodDefinitionError.new("unknown style: #{style}")
      end
    end

    def check_use(use)
      unless [:encoded, :literal].include?(use)
        raise MethodDefinitionError.new("unknown use: #{use}")
      end
    end

    def request_rpc(values, mapping_registry)
      if @request_use == :encoded
        request_rpc_enc(values, mapping_registry)
      else
        request_rpc_lit(values, mapping_registry)
      end
    end

    def request_doc(values, mapping_registry)
      if @request_use == :encoded
        request_doc_enc(values, mapping_registry)
      else
        request_doc_lit(values, mapping_registry)
      end
    end

    def request_rpc_enc(values, mapping_registry)
      method = @rpc_method_factory.dup
      names = method.input_params
      obj = create_request_obj(names, values)
      soap = Mapping.obj2soap(obj, mapping_registry, @rpc_request_qname)
      method.set_param(soap)
      method
    end

    def request_rpc_lit(values, mapping_registry)
      method = @rpc_method_factory.dup
      params = {}
      idx = 0
      method.input_params.each do |name|
        params[name] = SOAPElement.from_obj(values[idx])
        idx += 1
      end
      method.set_param(params)
      method
    end

    def request_doc_enc(values, mapping_registry)
      (0...values.size).collect { |idx|
        mapping_registry.obj2soap(values[idx], @doc_request_qnames[idx])
      }
    end

    def request_doc_lit(values, mapping_registry)
      (0...values.size).collect { |idx|
        item = values[idx]
        qname = @doc_request_qnames[idx]
        ele = SOAPElement.from_obj(item, qname.namespace)
        ele.elename = qname
        ele
      }
    end

    def response_rpc(body, mapping_registry)
      if @response_use == :encoded
        response_rpc_enc(body, mapping_registry)
      else
        response_rpc_lit(body, mapping_registry)
      end
    end

    def response_doc(body, mapping_registry)
      if @response_use == :encoded
        return *response_doc_enc(body, mapping_registry)
      else
        return *response_doc_lit(body, mapping_registry)
      end
    end

    def response_rpc_enc(body, mapping_registry)
      ret = nil
      if body.response
        ret = Mapping.soap2obj(body.response, mapping_registry)
      end
      if body.outparams
        outparams = body.outparams.collect { |outparam|
          Mapping.soap2obj(outparam)
        }
        [ret].concat(outparams)
      else
        ret
      end
    end

    def response_rpc_lit(body, mapping_registry)
      body.root_node.collect { |key, value|
        value.respond_to?(:to_obj) ? value.to_obj : value.data
      }
    end

    def response_doc_enc(body, mapping_registry)
      body.collect { |key, value|
        Mapping.soap2obj(value, mapping_registry)
      }
    end

    def response_doc_lit(body, mapping_registry)
      body.collect { |key, value|
        value.respond_to?(:to_obj) ? value.to_obj : value.data
      }
    end

    def create_request_obj(names, params)
      o = Object.new
      for idx in 0 ... params.length
        o.instance_variable_set('@' + names[idx], params[idx])
      end
      o
    end
  end
end


end
end
