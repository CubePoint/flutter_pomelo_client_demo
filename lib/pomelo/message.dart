import './utils.dart';

enum MessageType { REQUEST, NOTIFY, RESPONSE, PUSH }

const int MSG_FLAG_BYTES = 1; // 标志信息位 (type,compressRoute,compressGzip)
const int MSG_ID_MAX_BYTES = 5; // 最大id长度
const int MSG_ROUTE_CODE_BYTES = 2; // 路由code位
const int MSG_ROUTE_LEN_BYTES = 1; // 路由长度位

const int MSG_ROUTE_CODE_MAX = 0xffff; // 最大路由code值 (65535)

const int MSG_TYPE_MASK = 0x7;
const int MSG_COMPRESS_ROUTE_MASK = 0x1;
const int MSG_COMPRESS_GZIP_MASK = 0x1;
const int MSG_COMPRESS_GZIP_ENCODE_MASK = 1 << 4;

bool hasMsgId(MessageType type) {
  return type == MessageType.REQUEST || type == MessageType.RESPONSE;
}

bool hasMsgRoute(MessageType type) {
  return type == MessageType.REQUEST ||
      type == MessageType.NOTIFY ||
      type == MessageType.PUSH;
}

int getIntBytesLen(int i) {
  int len = 0;
  do {
    len += 1;
    i >>= 7;
  } while (i > 0);
  return len;
}

int encodeMsgFlag(List<int> buffer, int offset, MessageType type,
    bool isCompressRoute, bool isCompressGzip) {
  int typeInt = type.index;
  buffer[offset] = (typeInt << 1) | (isCompressRoute ? 1 : 0);

  if (isCompressGzip) {
    buffer[offset] = buffer[offset] | MSG_COMPRESS_GZIP_ENCODE_MASK;
  }

  return offset + MSG_FLAG_BYTES;
}

int encodeMsgId(List<int> buffer, int offset, int id) {
  do {
    int tmp = id % 128;
    int next = (id / 128).floor();

    if (next != 0) {
      tmp = tmp + 128;
    }
    buffer[offset++] = tmp;

    id = next;
  } while (id != 0);

  return offset;
}

int encodeMsgRoute(List<int> buffer, int offset, bool isCompressRoute,
    {List<int> routeBuffer, String route}) {
  if (isCompressRoute) {
    if (route == null) {
      throw 'route can not be null,isCompressRoute';
    }

    int routeCode = num.parse(route);
    if (routeCode > MSG_ROUTE_CODE_MAX) {
      throw 'route number is overflow';
    }

    buffer[offset++] = (routeCode >> 8) & 0xff;
    buffer[offset++] = routeCode & 0xff;
  } else {
    if (routeBuffer != null) {
      buffer[offset++] = routeBuffer.length & 0xff;
      buffer.setRange(offset, offset + routeBuffer.length, routeBuffer);
      offset += routeBuffer.length;
    } else {
      buffer[offset++] = 0;
    }
  }

  return offset;
}

int encodeMsgBody(List<int> buffer, int offset, List<int> bodyBuffer) {
  buffer.setRange(offset, offset + bodyBuffer.length, bodyBuffer);
  return offset + bodyBuffer.length;
}

class Message {
  int id;
  MessageType type;
  bool isCompressRoute;
  String route;
  List<int> bodyBuffer;
  bool isCompressGzip;

  List<int> messageBuffer;

  Message.byEncode(this.id, this.type, this.isCompressRoute,
      this.route, this.bodyBuffer, this.isCompressGzip) {
    // 计算包长度
    int msgLen = 0;
    List<int> routeBuffer;

    int idLen = hasMsgId(type) ? getIntBytesLen(id) : 0;
    msgLen += MSG_FLAG_BYTES + idLen;

    if (hasMsgRoute(type)) {
      if (route.isEmpty) {
        throw 'route can not be empty';
      }
      if (isCompressRoute) {
        msgLen += MSG_ROUTE_CODE_BYTES;
      } else {
        msgLen += MSG_ROUTE_LEN_BYTES;
        routeBuffer = Utils.strencode(route);
        if (routeBuffer.length > 255) {
          throw 'route maxlength is overflow';
        }
        msgLen += routeBuffer.length;
      }
    }

    msgLen += bodyBuffer != null ? bodyBuffer.length : 0;

    // 构造包
    List<int> result = List<int>(msgLen);
    int offset = 0;

    offset =
        encodeMsgFlag(result, offset, type, isCompressRoute, isCompressGzip);

    if (hasMsgId(type)) {
      offset = encodeMsgId(result, offset, id);
    }

    if (hasMsgRoute(type)) {
      offset = encodeMsgRoute(result, offset, isCompressRoute,
          routeBuffer: routeBuffer, route: route);
    }

    if (bodyBuffer != null) {
      offset = encodeMsgBody(result, offset, bodyBuffer);
    }
    
    this.messageBuffer = result;
  }

  Message.byDecode(this.messageBuffer) {
    int bufferLen = this.messageBuffer.length;
    int offset = 0;

    int flag = this.messageBuffer[offset++];
    this.type = MessageType.values[((flag >> 1) & MSG_TYPE_MASK)];
    this.isCompressRoute = (flag & MSG_COMPRESS_ROUTE_MASK) == 1;
    this.isCompressGzip = ((flag >> 4) & MSG_COMPRESS_GZIP_MASK) == 1;
    this.id = 0;

    // parse id
    if (hasMsgId(this.type)) {
      int m = 0;
      int i = 0;
      do {
        m = this.messageBuffer[offset];
        this.id += (m & 0x7f) << (7 * i);
        offset++;
        i++;
      } while (m >= 128);
    }

    // parse route
    if (hasMsgRoute(this.type)) {
      if (this.isCompressRoute) {
        this.route = ((this.messageBuffer[offset++]) << 8 | this.messageBuffer[offset++]).toString();
      } else {
        int routeLen = this.messageBuffer[offset++];
        if (routeLen > 0) {
          this.route = Utils.strdecode(this.messageBuffer.sublist(offset, offset + routeLen));
        } else {
          this.route = '';
        }
        offset += routeLen;
      }
    }

    // parse body
    int bodyLen = bufferLen - offset;
    this.bodyBuffer = this.messageBuffer.sublist(offset, offset + bodyLen);
  }


}
