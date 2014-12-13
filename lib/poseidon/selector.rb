module Poseidon
  class Selector
    include Socket::Constants

    attr_reader :connected, :completed_receives
    def initialize
      @streams = {}
      @streams_inverted = {}

      @completed_sends = []
      @completed_receives = []
      @connected = []
      @disconnected = []
    end

    def connect(broker_id, host, port)
      sock = Socket.new(AF_INET, SOCK_STREAM, 0)
      sockaddr = Socket.sockaddr_in(port, host)
      begin
        sock.connect_nonblock(sockaddr)
      rescue IO::WaitWritable
        p $!
      end

      @streams[broker_id] = Stream.new(sock, sockaddr)
      @streams_inverted[@streams[broker_id]] = broker_id
    end

    def disconnect(broker_id)
      connection = @socks.delete(broker_id)
      if connection
        @socks_inverted.delete(connection)
        connection.close
      end
    end

    def wakeup
    end

    def close
    end

    def poll(network_sends)
      clear

      #puts "NETWORK SENDS"
      #pp network_sends

      requests_to_write = {}
      network_sends.each do |send|
        stream = @streams[send.destination]
        stream << send
      end

      writes = @streams.values.select(&:write?)
      can_read, can_write, = IO.select(@streams.values, writes, nil, 30)
      #pp can_read
      #pp can_write
      if can_write
        can_write.each do |writable|
          case writable.handle_write
          when :connected
            @connected << @streams_inverted[writable]
          else
            p "Meh"
          end
        end
      end

      if can_read
        pp "CAN READ"
        can_read.each do |readable|
          completed = readable.handle_read
          @completed_receives += completed.map { |buffer| NetworkReceive.new(@streams_inverted[readable], buffer) }
        end
      end
    end

    def completed_sends
    end

    def disconnected
    end

    private
    def clear
      @connected = []
      @completed_receives = []
    end
  end
end
