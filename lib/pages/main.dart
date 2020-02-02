import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pomelo_client_demo/utils/utils.dart';

import 'package:flutter_pomelo_client_demo/pomelo/index.dart';

final pomelo = new Pomelo();

class MainPage extends StatefulWidget {
  MainPage({Key key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool isConnect = false;
  bool isConnecting = false;
  Map initFormData = {
    'host': '',
    'port': '',
    'ssl': false,
    'reconnect': false,
  };
  Map<String, TextEditingController> initFormDataControl = {
    'host': TextEditingController(),
    'port': TextEditingController(),
  };
  Map requestFormData = {
    'route': '',
    'body': '{}',
  };
  Map<String, TextEditingController> requestFormDataControl = {
    'route': TextEditingController(),
    'body': TextEditingController(),
  };
  String requestResponseText = '';
  final listenerNameControl = TextEditingController();
  List listenerList = [];

  // action
  submitInitForm() async {
    print(jsonEncode(initFormData));
    // 验证表单
    if (initFormData['host'].length == 0) {
      await _alert("请输入host主机值！");
      return;
    }

    setState(() {
      isConnecting = true;
    });
    bool isOk = await _pomeloInit(initFormData);
    print(isOk);
    await _alert(isOk ? "连接成功！" : "连接失败！");
    setState(() {
      isConnecting = false;
      if (isOk) isConnect = true;
    });
  }

  disconnect() async {
    print("disconnect");
    await pomelo.disconnect();
    print("disconnect success");
  }

  submitRequestForm() async {
    print(jsonEncode(requestFormData));
    // 验证表单
    if (requestFormData['route'].length == 0) {
      await _alert("请输入route路由值！");
      return;
    }
    try {
      jsonDecode(requestFormData['body']);
    } catch (e) {
      await _alert("请输入正确的JOSN格式！");
      return;
    }

    Map res = await _pomeloRequest(requestFormData);
    setState(() {
      requestResponseText = jsonEncode(res);
    });
    print(jsonEncode(res));
  }

  addListener(String name) {
    Map listener = {'name': name, 'msg': ''};
    listenerList.add(listener);
    pomelo.onEvent(name, (data) {
      setState(() {
        listener['msg'] =
            '[${(new DateTime.now().toString()).substring(0, 19)}]: ${jsonEncode(data)}';
      });
    });
  }

  @override
  void initState() {
    super.initState();
    initFormDataControl.forEach((k, c) {
      c.text = initFormData[k];
      c.addListener(() {
        initFormData[k] = c.text;
      });
    });
    requestFormDataControl.forEach((k, c) {
      c.text = requestFormData[k];
      c.addListener(() {
        requestFormData[k] = c.text;
      });
    });

    // 添加默认监听事件
    // addListener("onTime");

    pomelo.onEvent('SocketCloseEvent', (data) {
      setState(() {
        isConnect = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      child: SingleChildScrollView(
        child: Stack(
          children: <Widget>[
            Container(
              color: HexColor('#f5f5f5'),
              height: hpx100(),
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    Container(height: wpx(60)),
                    _ctxBox(),
                    Container(height: wpx(120)),
                  ],
                ),
              ),
            ),
            _topStateBar(),
            _bomConsoleBtn(),
          ],
        ),
      ),
    );
  }

  Widget _ctxBox() {
    Widget initBlock() {
      return _makeRadiusBox(
        title: "初始化 (pomelo.init)",
        child: Column(
          children: <Widget>[
            Container(
              height: wpx(80),
              child: TextField(
                controller: initFormDataControl["host"],
                decoration: InputDecoration(
                  labelText: "host",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Container(
              height: wpx(80),
              margin: EdgeInsets.only(top: wpx(20)),
              child: TextField(
                controller: initFormDataControl["port"],
                decoration: InputDecoration(
                  labelText: "port",
                  border: OutlineInputBorder(),
                ),
                inputFormatters: <TextInputFormatter>[
                  WhitelistingTextInputFormatter.digitsOnly
                ],
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            Container(
              height: wpx(80),
              child: CheckboxListTile(
                title: Text(
                  'ssl',
                  style: TextStyle(
                    color: HexColor('#333333'),
                    fontSize: wpx(30),
                  ),
                ),
                value: initFormData["ssl"],
                onChanged: (bool value) {
                  setState(() {
                    initFormData["ssl"] = value;
                  });
                },
              ),
            ),
            Container(
              height: wpx(80),
              child: CheckboxListTile(
                title: Text(
                  'reconnect',
                  style: TextStyle(
                    color: HexColor('#333333'),
                    fontSize: wpx(30),
                  ),
                ),
                value: initFormData["reconnect"],
                onChanged: (bool value) {
                  setState(() {
                    initFormData["reconnect"] = value;
                  });
                },
              ),
            ),
            isConnect
                ? _makeDelBtn(
                    btnText: "断开",
                    onBtn: disconnect,
                  )
                : _makeSubmitBtn(
                    submitText: "连接",
                    disabled: isConnecting,
                    onSubmit: submitInitForm,
                  ),
          ],
        ),
      );
    }

    Widget requestBlock() {
      if (!isConnect) {
        return Container();
      } else {
        return _makeRadiusBox(
          title: "请求 (pomelo.request)",
          child: Column(
            children: <Widget>[
              Container(
                height: wpx(80),
                child: TextField(
                  controller: requestFormDataControl["route"],
                  decoration: InputDecoration(
                    labelText: "route",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                height: wpx(20),
              ),
              Container(
                height: wpx(180),
                child: TextField(
                  maxLines: 4,
                  controller: requestFormDataControl["body"],
                  decoration: InputDecoration(
                    labelText: "body (json)",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              _makeSubmitBtn(
                submitText: "发送",
                onSubmit: submitRequestForm,
              ),
              _makeTextBox(text: requestResponseText),
            ],
          ),
        );
      }
    }

    Widget listenerBlock() {
      List listW = listenerList
          .asMap()
          .map((index, item) {
            return MapEntry(
              index,
              _makeRadiusBox(
                title: '监听事件 (${item['name']})',
                child: Column(
                  children: <Widget>[_makeTextBox(text: item['msg'])],
                ),
              ),
            );
          })
          .values
          .toList();

      return Wrap(
        runSpacing: wpx(20),
        children: listW,
      );
    }

    Widget addListenerBtn() {
      return Container(
        width: wpx(690),
        child: _makeSubmitBtn(
          submitText: '添加事件监听',
          onSubmit: () async {
            bool confirm = await showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text('添加事件监听'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        height: wpx(80),
                        child: TextField(
                          controller: listenerNameControl,
                          decoration: InputDecoration(
                            labelText: "name",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: <Widget>[
                    FlatButton(
                      child: Text("取消"),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    FlatButton(
                      child: Text("确定"),
                      onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                    ),
                  ],
                );
              },
            );
            if (confirm != null && confirm) {
              print(listenerNameControl.text);
              addListener(listenerNameControl.text);
            }
          },
        ),
      );
    }

    return Container(
      margin: EdgeInsets.all(wpx(30)),
      child: Column(
        children: <Widget>[
          initBlock(),
          SizedBox(height: wpx(30)),
          requestBlock(),
          SizedBox(height: wpx(30)),
          listenerBlock(),
          SizedBox(height: wpx(30)),
          addListenerBtn(),
        ],
      ),
    );
  }

  Widget _topStateBar() {
    String text = isConnect ? "已连接" : "未连接";
    Color color = isConnect ? Colors.blueAccent : Colors.redAccent;

    return Container(
      child: Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: wpx100(),
          height: wpx(60),
          decoration: BoxDecoration(color: color, boxShadow: [
            BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.1),
                offset: Offset(0, wpx(2)),
                blurRadius: wpx(10),
                spreadRadius: wpx(2))
          ]),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: HexColor('#ffffff'),
                fontSize: wpx(24),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bomConsoleBtn() {
    return Container(
      child: Positioned(
        right: wpx(50),
        bottom: wpx(50),
        child: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text('提示'),
                  content: SingleChildScrollView(
                    child: Text(pomelo.getDebugLog().join('\n')),
                  ),
                  actions: <Widget>[
                    FlatButton(
                      child: Text("确定"),
                      onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                    ),
                  ],
                );
              },
            );
          },
          child: Container(
            padding:
                EdgeInsets.symmetric(vertical: wpx(10), horizontal: wpx(30)),
            decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(wpx(10)),
                boxShadow: [
                  BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.1),
                      offset: Offset(0, wpx(2)),
                      blurRadius: wpx(10),
                      spreadRadius: wpx(2))
                ]),
            child: Text(
              "console",
              style: TextStyle(
                  color: HexColor('#ffffff'),
                  fontSize: wpx(30),
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  _alert(String text) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('提示'),
          content: Text(text),
          actions: <Widget>[
            FlatButton(
              child: Text("确定"),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }
}

// public widget
Widget _makeRadiusBox({String title, Widget child}) {
  Widget titlebar() {
    return Container(
      height: wpx(80),
      padding: EdgeInsets.fromLTRB(wpx(20), wpx(16), 0, 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: HexColor('#e1e1e5'),
            width: wpx(1),
          ),
        ),
      ),
      child: SizedBox.expand(
        child: Text(
          title,
          style: TextStyle(
            color: HexColor('#333333'),
            fontSize: wpx(28),
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

  Widget ctxbox({Widget child}) {
    return Container(
      padding: EdgeInsets.all(wpx(20)),
      child: child,
    );
  }

  return Container(
    width: wpx(690),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(wpx(20)),
        boxShadow: [
          BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.1),
              offset: Offset(0, wpx(2)),
              blurRadius: wpx(10),
              spreadRadius: wpx(2))
        ]),
    child: Column(
      children: <Widget>[
        titlebar(),
        ctxbox(child: child),
      ],
    ),
  );
}

Widget _makeSubmitBtn(
    {String submitText, bool disabled = false, Function onSubmit}) {
  return Container(
    margin: EdgeInsets.only(top: wpx(20)),
    width: wpx100(),
    height: wpx(80),
    child: RaisedButton(
      onPressed: (!disabled)
          ? () {
              if (onSubmit != null) onSubmit();
            }
          : null,
      color: Colors.blueAccent,
      child: Text(
        submitText,
        style: TextStyle(
          color: HexColor('#ffffff'),
          fontSize: wpx(28),
        ),
      ),
    ),
  );
}

Widget _makeDelBtn({String btnText, Function onBtn}) {
  return Container(
    margin: EdgeInsets.only(top: wpx(20)),
    width: wpx100(),
    height: wpx(80),
    child: RaisedButton(
      onPressed: () {
        if (onBtn != null) onBtn();
      },
      color: Colors.redAccent,
      child: Text(
        btnText,
        style: TextStyle(
          color: HexColor('#ffffff'),
          fontSize: wpx(28),
        ),
      ),
    ),
  );
}

Widget _makeTextBox({String text}) {
  return Container(
    margin: EdgeInsets.only(top: wpx(20)),
    padding: EdgeInsets.all(wpx(20)),
    width: wpx100(),
    decoration: BoxDecoration(
        color: HexColor('#eeeeee'),
        borderRadius: BorderRadius.circular(wpx(10))),
    child: Text(
      text,
      style: TextStyle(
        color: HexColor('#333333'),
        fontSize: wpx(26),
      ),
    ),
  );
}

// public action
_pomeloInit(initFormData) async {
  String host = initFormData["host"];
  int port = int.tryParse(initFormData["port"]) ?? null;
  bool ssl = initFormData["ssl"];
  bool reconnect = initFormData["reconnect"];

  return await pomelo.init(
      host: host, port: port, ssl: ssl, reconnect: reconnect, debug: true);
}

_pomeloRequest(requestFormData) async {
  String route = requestFormData["route"];
  Map body = jsonDecode(requestFormData["body"]);

  return await pomelo.request(route, body);
}
