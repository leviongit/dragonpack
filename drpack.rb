class String
  if !method_defined?(:unpack1)
    def unpack1(fmt)
      unpack(fmt)[0]
    end
  end
end

module MsgPack
  class << self
    def read(str)
      _read(str.dup)
    end

    def _read(str)
      check_len!(str, 1)

      tagv = str.slice!(0).ord

      # positive fixint | 0xxxxxxx
      return tagv if (tagv >> 7) == 0
      # negative fixint | 111xxxxx
      return -(tagv & 0x1f) if (tagv >> 5) == 0b0111

      # fixstr | 101xxxx
      return readstr(str, tagv & 0x1f) if (tagv >> 5) == 0b101
      # fixmap | 1000xxxx
      return readmap(str, tagv & 0xf) if (tagv >> 4) == 0b1000
      # fixary | 1001xxxx
      return readary(str, tagv & 0xf) if (tagv >> 4) == 0b1001

      return case tagv
      when 0xc0
        nil
      when 0xc2
        false
      when 0xc3
        true
      when 0xc4
        # bin8
        l = readuint8(str)
        readbin(str, l)
      when 0xc5
        # bin16
        l = readuint16(str)
        readbin(str, l)
      when 0xc6
        # bin32
        l = readuint32(str)
        readbin(str, l)
      when 0xc7
        # ext8
        l = readuint8(str)
        readext(str, l)
      when 0xc8
        # ext16
        l = readuint16(str)
        readext(str, l)
      when 0xc9
        # ext32
        l = readuint32(str)
        readext(str, l)
      when 0xca
        # float32
        readnbytes!(str, 4).unpack1("g")
      when 0xcb
        # float64
        readnbytes!(str, 8).unpack1("G")
      when 0xcc
        # uint8
        readuint8(str)
      when 0xcd
        # uint16
        readuint16(str)
      when 0xce
        # uint32
        readuint32(str)
      when 0xcf
        # uint64
        readuint64(str)
      when 0xd0
        # int8
        readint8(str)
      when 0xd1
        # int16
        readint16(str)
      when 0xd2
        # int32
        readint32(str)
      when 0xd3
        # int64
        readint64(str)
      when 0xd4
        # fixext1
        readext(str, 1)
      when 0xd5
        # fixext2
        readext(str, 2)
      when 0xd6
        # fixext4
        d = readext(str, 4)
        d[0] == -1 ? Time.at(d[1]) : d
      when 0xd7
        # fixext8
        readext(str, 8)
      when 0xd8
        # fixext16
        readext(str, 16)
      when 0xd9
        # str8
        l = readuint8(str)
        readstr(str, l)
      when 0xda
        # str16
        l = readuint16(str)
        readstr(str, l)
      when 0xdb
        # str32
        l = readuint32(str)
        readstr(str, l)
      when 0xdc
        # ary16
        l = readuint16(str)
        readary(str, l)
      when 0xdd
        # ary32
        l = readuint32(str)
        readary(str, l)
      when 0xde
        # map16
        l = readuint16(str)
        readmap(str, l)
      when 0xdf
        # map32
        l = readuint32(str)
        readmap(str, l)
      else
        _readextra(str)
      end
    end

    def _readextra(str)
      raise(
        NotImplementedError,
        <<~S
          please override `_readextra` to allow for reading data after the `#{str[0].inspect}` data tag
        S
      )
    end

    def readuint8(str)
      ds = readnbytes!(str, 1)
      ds.unpack1("C")
    end

    def readuint16(str)
      ds = readnbytes!(str, 2)
      ds.unpack1("n")
    end

    def readuint32(str)
      ds = readnbytes!(str, 4)
      ds.unpack1("N")
    end

    def readuint64(str)
      ds = readnbytes!(str, 8)
      ds.unpack1("Q>")
    end

    def readint8(str)
      ds = readnbytes!(str, 1)
      ds.unpack1("c")
    end

    def readint16(str)
      ds = readnbytes!(str, 2)
      ds.unpack1("s>")
    end

    def readint32(str)
      ds = readnbytes!(str, 4)
      ds.unpack1("l>")
    end

    def readint64(str)
      ds = readnbytes!(str, 8)
      ds.unpack1("q>")
    end

    def readbin(str, num)
      bs = readnbytes!(str, num)
      bs.unpack1("C*")
    end

    def readary(str, num)
      ary = []
      i = 0

      while i < num
        ary << _read(str)
        i += 1
      end

      ary
    end

    def readmap(str, num)
      hsh = {}
      i = 0

      while i < num
        key = _read(str)
        value = _read(str)
        hsh[key] = value

        i += 1
      end

      hsh
    end

    def readstr(str, num)
      ss = readnbytes!(str, num)
      ss
    end

    def readext(str, num)
      t = readint8(str)
      ds = readnbytes!(str, num)

      [t, ds]
    end

    def check_len!(str, len)
      raise ArgumentError, "passed string is not at least #{len} bytes long" if str.length < len
      str
    end

    def readnbytes(str, n)
      str.slice!(0, n)
    end

    def readnbytes!(str, n)
      ss = str.slice!(0, n)
      check_len!(ss, n)
    end
  end
end
