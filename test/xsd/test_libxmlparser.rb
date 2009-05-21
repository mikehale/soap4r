require 'test/unit'
require 'soap/rpc/driver'
require 'webrick'
require 'logger'
require File.join(File.dirname(File.expand_path(__FILE__)), '..', 'testutil.rb')


module SOAP


class TestLibxml < Test::Unit::TestCase
  Port = 17171

  def setup
    @logger = Logger.new(STDERR)
    @logger.level = Logger::Severity::ERROR
    @url = "http://localhost:#{Port}/"
    @server = @client = nil
    @server_thread = nil
    setup_server
    setup_client
  end

  def teardown
    teardown_client if @client
    teardown_server if @server
  end

  def setup_server
    @server = WEBrick::HTTPServer.new(
      :BindAddress => "0.0.0.0",
      :Logger => @logger,
      :Port => Port,
      :AccessLog => [],
      :DocumentRoot => File.dirname(File.expand_path(__FILE__))
    )
    @server.mount(
      '/',
      WEBrick::HTTPServlet::ProcHandler.new(method(:do_server_proc).to_proc)
    )
    @server_thread = TestUtil.start_server_thread(@server)
  end

  def setup_client
    @client = SOAP::RPC::Driver.new(@url, '')
    @client.add_method("do_server_proc")
  end

  def teardown_server
    @server.shutdown
    @server_thread.kill
    @server_thread.join
  end

  def teardown_client
    @client.reset_stream
  end

  def do_server_proc(req, res)
    res['content-type'] = 'text/xml'
    res.body = %(<?xml version="1.0" encoding="utf-8" ?>
    <env:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <env:Body>
        <n1:do_server_proc xmlns:n1="urn:foo" env:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <return xsi:nil="true"/>
        </n1:do_server_proc>
      </env:Body>
    </env:Envelope>)
  end

  def test_libxml
    @client.wiredump_dev = STDOUT
    @client.do_server_proc
  end
end


end
