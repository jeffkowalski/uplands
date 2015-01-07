require 'serialport'

class Dirtmon
  attr_reader :options, :quit

  def initialize options
    @options = options
    @port = '/dev/ttyUSB0'
    @baud_rate = 57600
    @data_bits = 8
    @stop_bits = 1
    @parity    = SerialPort::NONE
    #ob->handshake("none") || $log->logdie ("failed setting handshake")
  end

  def self.run! options
    Dirtmon.new(options).run!
  end

  def run!
    puts 'dirtmon starting'
    SerialPort.open(@port, @baud_rate, @data_bits, @stop_bits, @parity) do |sp|
      sp.puts '1i 212g' # node 1 in group 212
      while !quit
        puts 'dirtmon listening'
        while message = sp.gets.chomp
          # byte -> 0  1  2  3  4  5  6   7   8  9  10  11  12
          #         ====  ----------  - --- ---  -----  ------
          # eg   -> OK 2  2  0  0  0  2 115 117  0   0   0   0
          #  long ping;      // 32-bit counter
          #  byte id :7;     // identity, should be different for each node
          #  byte boost :1;  // whether compiled for boost chip or not
          #  byte vcc1;      // VCC before transmit, 1.0V = 0 .. 6.0V = 250
          #  byte vcc2;      // battery voltage (BOOST=1), or VCC after transmit (BOOST=0)
          #  word sensor;    // sensor1
          #  word sensor;    // sensor2
          if message =~ /^OK 2/
            rec = message.split(' ').map{ |v| v.to_i }
            ping  = rec[2] + rec[3] * 256 + rec[4] * 256 * 256 + rec[5] * 256 * 256 * 256
            id    = rec[6]
            vcc1  = rec[7] / 250.0 * 5.0 + 1.0
            vcc2  = rec[8] / 250.0 * 5.0 + 1.0
            sensor1 = rec[9] + rec[10] * 256
            sensor2 = rec[11] + rec[12] * 256
            puts ['dirtmon', ping, id, vcc1, vcc2, sensor1, sensor2].join(' ')
            # $xively.put "dirtmon1.vcc1", vcc1
            # $xively.put "dirtmon1.vcc2", vcc2
            # $xively.put "dirtmon1.moisture1", sensor1
            # $xively.put "dirtmon1.moisture2", sensor2
            $moisture = ((1023 - sensor1) + (1023 - sensor2)) / 2
            $voltage  = (vcc1 + vcc2) / 2.0
            $dirtmon_timestamp = Time.now
          end
        end
        sleep 1
      end
    end
    puts 'dirtmon exiting'
  end
end

Dirtmon.run!(nil)
