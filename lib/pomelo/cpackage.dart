
enum CpackageType {
  UNKNOW,HANDSHAKE,HANDSHAKE_ACK,HEARTBEAT,DATA,KICK
}

const PKG_HEAD_BYTES = 4; // 包头长度位 (type,bodyLen)

class Cpackage {
  CpackageType type;
  List<int> bodyBuffer;

  List<int> cpackageBuffer;

  Cpackage(this.type,this.bodyBuffer,this.cpackageBuffer);

  Cpackage.byEncode(this.type, this.bodyBuffer) {
    int bodyLen = this.bodyBuffer != null ? this.bodyBuffer.length : 0;
    int typeInt = this.type.index;

    List<int> result = List<int>.filled(PKG_HEAD_BYTES + bodyLen, 0);
    int offset = 0;
    result[offset++] = typeInt & 0xff;
    result[offset++] = (bodyLen >> 16) & 0xff;
    result[offset++] = (bodyLen >> 8) & 0xff;
    result[offset++] = bodyLen & 0xff;

    if (this.bodyBuffer != null) {
      result.setRange(offset, offset + bodyLen, this.bodyBuffer);
    }

    this.cpackageBuffer = result;
  }

  static List<Cpackage> decodeAll(List<int> buffer) {
    List<Cpackage> resultList = [];
    int offset = 0;

    while (offset < buffer.length) {
      int typeInt = buffer[offset++];
      CpackageType type = CpackageType.values[typeInt];
      int length = ((buffer[offset++]) << 16 |
              (buffer[offset++]) << 8 |
              buffer[offset++]) >>
          0;
      List<int> bodyBuffer = buffer.sublist(offset, offset + length);
      List<int> cpackageBuffer = buffer.sublist(offset-PKG_HEAD_BYTES,offset+length);
      offset += length;

      resultList.add(Cpackage(type,bodyBuffer,cpackageBuffer));
    }

    return resultList;
  }
}
