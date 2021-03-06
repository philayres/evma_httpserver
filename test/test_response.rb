require 'test/unit'
require 'evma_httpserver'

begin
  once = false
  require 'eventmachine'
rescue LoadError => e
  raise e if once
  once = true
  require 'rubygems'
  retry
end


#--------------------------------------

module EventMachine

  # This is a test harness wired into the HttpResponse class so we
  # can test it without requiring any actual network communication.
  #
  class HttpResponse
    attr_reader :output_data
    attr_reader :closed_after_writing

    def send_data data
      @output_data ||= ""
      @output_data << data
    end
    def close_connection_after_writing
      @closed_after_writing = true
    end
  end
end

#--------------------------------------


class TestHttpResponse < Test::Unit::TestCase

  def test_properties
    a = EventMachine::HttpResponse.new
    a.status = 200
    a.content = "Some content"
    a.headers["Content-Type"] = "text/xml"
  end

  def test_header_sugarings
    a = EventMachine::HttpResponse.new
    a.content_type "text/xml"
    a.set_cookie "a=b"
    a.headers["X-bayshore"] = "aaaa"

    assert_equal({
      "Content-Type" => "text/xml",
      "Set-Cookie" => ["a=b"],
      "X-bayshore" => "aaaa"
    }, a.headers)
  end

  def test_send_response
    a = EventMachine::HttpResponse.new
    a.status = 200
    a.send_response
    assert_equal([
           "HTTP/1.1 200 OK\r\n",
           "Content-Length: 0\r\n",
           "\r\n"
    ].join, a.output_data)
    assert_equal( true, a.closed_after_writing )
  end

  def test_send_response_1
    a = EventMachine::HttpResponse.new
    a.status = 200
    a.content_type "text/plain"
    a.content = "ABC"
    a.send_response
    assert_equal([
           "HTTP/1.1 200 OK\r\n",
           "Content-Length: 3\r\n",
           "Content-Type: text/plain\r\n",
           "\r\n",
           "ABC"
    ].join, a.output_data)
    assert( a.closed_after_writing )
  end

  def test_send_response_no_close
    a = EventMachine::HttpResponse.new
    a.status = 200
    a.content_type "text/plain"
    a.content = "ABC"
    a.keep_connection_open
    a.send_response
    assert_equal([
           "HTTP/1.1 200 OK\r\n",
           "Content-Length: 3\r\n",
           "Content-Type: text/plain\r\n",
           "\r\n",
           "ABC"
    ].join, a.output_data)
    assert( ! a.closed_after_writing )
  end

  def test_send_response_multiple_times
    a = EventMachine::HttpResponse.new
    a.status = 200
    a.send_response
    assert_raise( RuntimeError ) {
      a.send_response
    }
  end

  def test_send_headers
    a = EventMachine::HttpResponse.new
    a.status = 200
    a.send_headers
    assert_equal([
           "HTTP/1.1 200 OK\r\n",
           "Content-Length: 0\r\n",
           "\r\n"
    ].join, a.output_data)
    assert( ! a.closed_after_writing )
    assert_raise( RuntimeError ) {
      a.send_headers
    }
  end

  def test_send_chunks
    a = EventMachine::HttpResponse.new
    a.chunk "ABC"
    a.chunk "DEF"
    a.chunk "GHI"
    a.keep_connection_open
    a.send_response
    assert_equal([
           "HTTP/1.1 200 OK\r\n",
           "Transfer-Encoding: chunked\r\n",
           "\r\n",
           "3\r\n",
           "ABC\r\n",
           "3\r\n",
           "DEF\r\n",
           "3\r\n",
           "GHI\r\n",
           "0\r\n",
           "\r\n"
    ].join, a.output_data)
    assert( !a.closed_after_writing )
  end

  def test_send_chunks_with_close
    a = EventMachine::HttpResponse.new
    a.chunk "ABC"
    a.chunk "DEF"
    a.chunk "GHI"
    a.send_response
    assert_equal([
           "HTTP/1.1 200 OK\r\n",
           "Transfer-Encoding: chunked\r\n",
           "\r\n",
           "3\r\n",
           "ABC\r\n",
           "3\r\n",
           "DEF\r\n",
           "3\r\n",
           "GHI\r\n",
           "0\r\n",
           "\r\n"
    ].join, a.output_data)
    assert( a.closed_after_writing )
  end

end
