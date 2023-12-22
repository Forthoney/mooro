# frozen_string_literal: true

require "socket"
require "stringio"

RSpec.describe(Mooro::Server) do
  let(:host) { "127.0.0.1" }
  let(:port) { 8080 }
  let(:client) { TCPSocket.new(host, port, connect_timeout: 2) }

  context "with single connection" do
    subject(:server) { described_class.new(2, host, port) }

    it "accept connections" do
      server.start
      sleep(1)

      expect(client).to(be_a(TCPSocket))
      client.close

      server.stop
    end

    it "serve response" do
      server.start
      sleep(1)

      expect(client.gets.chomp).to(eq("Hello, World!"))
      client.close

      server.stop
    end
  end

  context "with request" do
    subject(:server) { repeat_server.new(2, host, port) }

    let(:repeat_server) do
      Class.new(described_class) do
        def serve(socket)
          socket.puts("repeat: #{socket.gets}")
        end
      end
    end

    it "reads request" do
      server.start
      sleep(1)

      client.puts("foobar")
      expect(client.gets.chomp).to(eq("repeat: foobar"))

      server.stop
    end
  end

  # Mocking with Ractors is really difficult
  # The test below does not work due to StringIO not being moveable,
  # and even if it is moveable, we cannot access its contents to check if the server did its job
  #
  # context "with mocked connections" do
  #   let(:socket) { double(:socket) }
  #   let(:client) { StringIO.new }
  #
  #   it "serves" do
  #     expect(TCPServer).to(receive(:open).with(host, port).and_yield(socket))
  #     allow(socket).to(receive_messages(accept: client, addr: port))
  #
  #     server.start
  #     sleep(1)
  #     server.stop
  #
  #     expect(socket).to(have_received(:puts).with("Hello, World!"))
  #   end
  # end
end
