# frozen_string_literal: true

require "socket"

RSpec.describe(Mooro::Server) do
  let(:host) { "127.0.0.1" }
  let(:port) { 10001 }

  around do |ex|
    server = described_class.new(4, host, port)
    server.start
    sleep(1)
    ex.run
    server.stop
  end

  it "accepts_connections" do
    client = TCPSocket.new(host, port, connect_timeout: 2)
    expect(client).to(be_a(TCPSocket))
    client.close
  end

  it "serves_response" do
    client = TCPSocket.new(host, port, connect_timeout: 2)
    res = client.gets.chomp
    expect(res).to(eq("Hello, World!"))
    client.close
  end
end
