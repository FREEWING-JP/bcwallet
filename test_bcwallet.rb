#!/usr/bin/env ruby

if ENV['CI'] then
  require 'coveralls'
  Coveralls.wear!
end

require 'tmpdir'
require 'timeout'
require 'minitest/autorun'
require './bcwallet'

class TestKey < MiniTest::Test
  def test_base58_encode
    assert_equal '2cFupjhnEsSn59qHXstmK2ffpLv2',
      Key.encode_base58(['73696d706c792061206c6f6e6720737472696e67'].pack('H*'))
  end

  def test_base58_decode
    assert_equal ['73696d706c792061206c6f6e6720737472696e67'].pack('H*'),
      Key.decode_base58('2cFupjhnEsSn59qHXstmK2ffpLv2')
  end

  def test_base58_encode_decode
    assert_equal 'foobarbazhoge', Key.decode_base58(Key.encode_base58('foobarbazhoge'))
  end

  def test_base58_encode_decode_when_begin_with_00
    assert_equal [0x00, 0x01, 0x02], Key.decode_base58(Key.encode_base58([0x00, 0x01, 0x02].pack('C*'))).unpack('C*')
  end

  def test_key_generation
    key = Key.new

    address_str = key.to_address_s
    private_key_str = key.to_private_key_s

    assert_match /[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]+/, address_str
    assert_match /[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]+/, private_key_str
  end
end

class TestBloomFilter < MiniTest::Test
  def test_murmur_hash
    bf = BloomFilter.new(1, 1, 1)
    assert_equal 0x2a2884ba, bf.hash(0xabcdef, "hogehoge")
    assert_equal 0xcdcbf1ad, bf.hash(0xabcdef, "foobarbaz")
    assert_equal 0xc28e9cab, bf.hash(0xabcdef, "abcdefghijklmnopqrstuvwxyz")
    assert_equal 0xfe1d612e, bf.hash(0xabcdef, "qwertyuiop")
  end
end

class TestMessage < MiniTest::Test
  def test_version_message_serialize
    m = Message.new
    b = m.serialize({
      command: :version,
      version: 31900,
      services: 1,
      timestamp: 1292899814,
      your_addr: nil,
      my_addr: nil,
      nonce: 1393780771635895773,
      agent: '',
      height: 98645,
      relay: true
    })

    assert_equal(b.unpack('C*'),
      [0x9C, 0x7C, 0x00, 0x00,
       0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
       0xE6, 0x15, 0x10, 0x4D, 0x00, 0x00, 0x00, 0x00,
       0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x20, 0x8D,
       0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x20, 0x8D,
       0xDD, 0x9D, 0x20, 0x2C, 0x3A, 0xB4, 0x57, 0x13,
       0x00,
       0x55, 0x81, 0x01, 0x00])
  end

  def test_version_message_deserialize
    b = [0x9C, 0x7C, 0x00, 0x00,
         0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
         0xE6, 0x15, 0x10, 0x4D, 0x00, 0x00, 0x00, 0x00,
         0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x20, 0x8D,
         0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x20, 0x8D,
         0xDD, 0x9D, 0x20, 0x2C, 0x3A, 0xB4, 0x57, 0x13,
         0x00,
         0x55, 0x81, 0x01, 0x00]

    m = Message.new
    msg = m.deserialize(:version, b.pack('C*'))

    assert_equal :version, msg[:command]
    assert_equal 31900, msg[:version]
    assert_equal 1, msg[:services]
    assert_equal 1292899814, msg[:timestamp]
    assert_equal nil, msg[:your_addr]
    assert_equal nil, msg[:my_addr]
    assert_equal 1393780771635895773, msg[:nonce]
    assert_equal '', msg[:agent]
    assert_equal 98645, msg[:height]
    assert_equal true, msg[:relay]
  end

  def test_inv_message_serialize
    m = Message.new
    b = m.serialize({
      command: :inv,
      inventory: [
        { type: Message::MSG_TX,
          hash: [ 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02 ].pack('C*') },
        { type: Message::MSG_BLOCK,
          hash: [ 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04 ].pack('C*') }
      ]
    })

    assert_equal b.unpack('C*'), [
        0x02,
        0x01, 0x00, 0x00, 0x00,
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02,
        0x02, 0x00, 0x00, 0x00,
        0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04
    ]
  end

  def test_inv_message_deserialize
    b = [
      0x02,
      0x01, 0x00, 0x00, 0x00,
      0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02,
      0x02, 0x00, 0x00, 0x00,
      0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04
    ].pack('C*')

    m = Message.new
    msg = m.deserialize(:inv, b)

    assert_equal msg[:command], :inv
    assert_equal msg[:inventory].length, 2
    assert_equal msg[:inventory][0][:type], Message::MSG_TX
    assert_equal(msg[:inventory][0][:hash],
      [ 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02 ].pack('C*'))
    assert_equal msg[:inventory][1][:type], Message::MSG_BLOCK
    assert_equal(msg[:inventory][1][:hash],
      [ 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04 ].pack('C*'))
  end
end

class TestBCWallet < MiniTest::Test
  HANDSHAKES = [
    # version
    0x0b, 0x11, 0x09, 0x07, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6f, 0x6e, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x66, 0x00, 0x00, 0x00, 0x11, 0x20, 0xd9, 0xde, 0x72, 0x11, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x2f, 0x76, 0x41, 0x56, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff,
    0x77, 0x48, 0xc0, 0x53, 0xdb, 0xe8, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x47, 0x9d,
    0xc7, 0x8a, 0x2c, 0xb2, 0xd1, 0x17, 0x63, 0x4f, 0x10, 0x2f, 0x53, 0x61, 0x74, 0x6f, 0x73, 0x68,
    0x69, 0x3a, 0x30, 0x2e, 0x31, 0x31, 0x2e, 0x30, 0x2f, 0x01, 0x00, 0x00, 0x00, 0x01,

    # verack
    0x0b, 0x11, 0x09, 0x07, 0x76, 0x65, 0x72, 0x61, 0x63, 0x6b, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x5d, 0xf6, 0xe0, 0xe2,

    # ping
    0x0b, 0x11, 0x09, 0x07, 0x70, 0x69, 0x6e, 0x67, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x08, 0x00, 0x00, 0x00, 0x3b, 0x7b, 0xb8, 0xb4, 0x71, 0x44, 0x02, 0x13, 0x0d, 0xa2, 0xac, 0xee ]

  BLOCKS = [
    # genesis block (merkleblock)
    0x0b, 0x11, 0x09, 0x07, 0x6d, 0x65, 0x72, 0x6b, 0x6c, 0x65, 0x62, 0x6c, 0x6f, 0x63, 0x6b, 0x00,
    0x77, 0x00, 0x00, 0x00, 0xd7, 0xba, 0xe3, 0xf8, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3b, 0xa3, 0xed, 0xfd,
    0x7a, 0x7b, 0x12, 0xb2, 0x7a, 0xc7, 0x2c, 0x3e, 0x67, 0x76, 0x8f, 0x61, 0x7f, 0xc8, 0x1b, 0xc3,
    0x88, 0x8a, 0x51, 0x32, 0x3a, 0x9f, 0xb8, 0xaa, 0x4b, 0x1e, 0x5e, 0x4a, 0xda, 0xe5, 0x49, 0x4d,
    0xff, 0xff, 0x00, 0x1d, 0x1a, 0xa4, 0xae, 0x18, 0x01, 0x00, 0x00, 0x00, 0x01, 0x3b, 0xa3, 0xed,
    0xfd, 0x7a, 0x7b, 0x12, 0xb2, 0x7a, 0xc7, 0x2c, 0x3e, 0x67, 0x76, 0x8f, 0x61, 0x7f, 0xc8, 0x1b,
    0xc3, 0x88, 0x8a, 0x51, 0x32, 0x3a, 0x9f, 0xb8, 0xaa, 0x4b, 0x1e, 0x5e, 0x4a, 0x01, 0x00,

    # #1 block (merkleblock)
    0x0b, 0x11, 0x09, 0x07, 0x6d, 0x65, 0x72, 0x6b, 0x6c, 0x65, 0x62, 0x6c, 0x6f, 0x63, 0x6b, 0x00,
    0x77, 0x00, 0x00, 0x00, 0x6c, 0xd4, 0xd0, 0x39, 0x01, 0x00, 0x00, 0x00, 0x43, 0x49, 0x7f, 0xd7,
    0xf8, 0x26, 0x95, 0x71, 0x08, 0xf4, 0xa3, 0x0f, 0xd9, 0xce, 0xc3, 0xae, 0xba, 0x79, 0x97, 0x20,
    0x84, 0xe9, 0x0e, 0xad, 0x01, 0xea, 0x33, 0x09, 0x00, 0x00, 0x00, 0x00, 0xba, 0xc8, 0xb0, 0xfa,
    0x92, 0x7c, 0x0a, 0xc8, 0x23, 0x42, 0x87, 0xe3, 0x3c, 0x5f, 0x74, 0xd3, 0x8d, 0x35, 0x48, 0x20,
    0xe2, 0x47, 0x56, 0xad, 0x70, 0x9d, 0x70, 0x38, 0xfc, 0x5f, 0x31, 0xf0, 0x20, 0xe7, 0x49, 0x4d,
    0xff, 0xff, 0x00, 0x1d, 0x03, 0xe4, 0xb6, 0x72, 0x01, 0x00, 0x00, 0x00, 0x01, 0xba, 0xc8, 0xb0,
    0xfa, 0x92, 0x7c, 0x0a, 0xc8, 0x23, 0x42, 0x87, 0xe3, 0x3c, 0x5f, 0x74, 0xd3, 0x8d, 0x35, 0x48,
    0x20, 0xe2, 0x47, 0x56, 0xad, 0x70, 0x9d, 0x70, 0x38, 0xfc, 0x5f, 0x31, 0xf0, 0x01, 0x00 ]

  def test_invalid_arguments
    Dir.mktmpdir do |dir|
      key_file_name = "#{dir}/keys"
      data_file_name = "#{dir}/data"

      assert_output nil, /Usage\: ruby bcwallet\.rb/ do
        BCWallet.new([''], key_file_name, data_file_name).run
      end

      assert_output nil, /bcwallet\.rb: invalid command/ do
        BCWallet.new(['foo'], key_file_name, data_file_name).run
      end

      assert_output nil, /bcwallet.rb: missing arguments/ do
        BCWallet.new(['export'], key_file_name, data_file_name).run
      end

      assert_output nil, /bcwallet\.rb: an address named foo doesn't exist/ do
        BCWallet.new(
          ['send', 'foo', 'n2eMqTT929pb1RDNuqEnxdaLau1rxy3efi', '1.00'],
          key_file_name, data_file_name).run
      end
    end
  end

  def test_generate_list
    Dir.mktmpdir do |dir|
      key_file_name = "#{dir}/keys"
      data_file_name = "#{dir}/data"

      assert_output /No addresses available/, nil do
        BCWallet.new(['list'], key_file_name, data_file_name).run
      end

      assert_output /new Bitcoin address "peryaudo" generated/ do
        BCWallet.new(['generate', 'peryaudo'], key_file_name, data_file_name).run
      end

      assert_output nil, /the name "peryaudo" already exists/ do
        BCWallet.new(['generate', 'peryaudo'], key_file_name, data_file_name).run
      end

      assert_output /peryaudo/ do
        BCWallet.new(['list'], key_file_name, data_file_name).run
      end
    end
  end

  def test_export
    Dir.mktmpdir do |dir|
      key_file_name = "#{dir}/keys"
      data_file_name = "#{dir}/data"

      assert_output /new Bitcoin address "peryaudo" generated/ do
        BCWallet.new(['generate', 'peryaudo'], key_file_name, data_file_name).run
      end

      $stdin = StringIO.new('yes', 'r')

      assert_output nil, /Are you sure you want to export private key for "peryaudo"/ do
        BCWallet.new(['export', 'peryaudo'], key_file_name, data_file_name).run
      end
    end
  end

  def test_balance
    Dir.mktmpdir do |dir|
      key_file_name = "#{dir}/keys"
      data_file_name = "#{dir}/data"

      assert_output /new Bitcoin address "peryaudo" generated/ do
        BCWallet.new(['generate', 'peryaudo'], key_file_name, data_file_name).run
      end

      stream = StringIO.new((HANDSHAKES + BLOCKS).pack('C*'))
      def stream.write(str)
        str.length
      end

      TCPSocket.stub :open, stream do
        timeout 10 do
          assert_output /peryaudo: 0\.00000000 BTC/, nil do
            BCWallet.new(['balance'], key_file_name, data_file_name).run
          end
        end

      end

      assert_output /merkleblock/, nil do
        BCWallet.new(
          ['block', '000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943'],
          key_file_name, data_file_name).run
      end
    end
  end

  def test_send
    # TODO(peryaudo): do real checks to ensure sending functionality is working

    Dir.mktmpdir do |dir|
      key_file_name = "#{dir}/keys"
      data_file_name = "#{dir}/data"

      assert_output /new Bitcoin address "peryaudo" generated/ do
        BCWallet.new(['generate', 'peryaudo'], key_file_name, data_file_name).run
      end

      $stream = StringIO.new((HANDSHAKES + BLOCKS).pack('C*'))
      def $stream.write(str)
        str.length
      end

      $stdin = StringIO.new
      def $stdin.gets
        $stream = StringIO.new(HANDSHAKES.pack('C*'))
        return 'yes'
      end

      TCPSocket.stub :open, $stream do
        timeout 10 do
          assert_output nil, /you don't have enough balance to pay/ do
            BCWallet.new(
              ['send', 'peryaudo', 'n2eMqTT929pb1RDNuqEnxdaLau1rxy3efi', '1.00'],
              key_file_name, data_file_name).run
          end
        end
      end

      $stream = StringIO.new((HANDSHAKES + BLOCKS).pack('C*'))
      def $stream.write(str)
        str.length
      end

      TCPSocket.stub :open, $stream do
        timeout 10 do
          assert_output nil, nil do
            BCWallet.new(
              ['send', 'peryaudo', 'n2eMqTT929pb1RDNuqEnxdaLau1rxy3efi', '0.00'],
              key_file_name, data_file_name).run
          end
        end
      end
    end
  end
end
