// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'widget.dart';

void main() {
  runApp(FlutterBlueApp());
}

class FlutterBlueApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.lightBlue,
      home: StreamBuilder<BluetoothState>(
          stream: FlutterBlue.instance.state,
          initialData: BluetoothState.unknown,
          builder: (c, snapshot) {
            final state = snapshot.data;
            if (state == BluetoothState.on) {
              return FindDevicesScreen();
            }
            return BluetoothOffScreen(state: state);
          }),
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key key, this.state}) : super(key: key);

  final BluetoothState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${state.toString().substring(15)}.',
              style: Theme.of(context)
                  .primaryTextTheme
                  .subhead
                  .copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class FindDevicesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Find Devices'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            FlutterBlue.instance.startScan(timeout: Duration(seconds: 2)),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              StreamBuilder<List<BluetoothDevice>>(
                stream: Stream.periodic(Duration(seconds: 1))
                    .asyncMap((_) => FlutterBlue.instance.connectedDevices),
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data
                      .map((d) => ListTile(
                    title: Text(d.name),
                    subtitle: Text(d.id.toString()),
                    trailing: StreamBuilder<BluetoothDeviceState>(
                      stream: d.state,
                      initialData: BluetoothDeviceState.disconnected,
                      builder: (c, snapshot) {
                        if (snapshot.data ==
                            BluetoothDeviceState.connected) {
                          return RaisedButton(
                            child: Text('OPEN'),
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (context) =>
                                        DeviceScreen(device: d))),
                          );
                        }
                        return Text(snapshot.data.toString());
                      },
                    ),
                  ))
                      .toList(),
                ),
              ),
              StreamBuilder<List<ScanResult>>(
                stream: FlutterBlue.instance.scanResults,
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data
                      .map(
                        (r) => ScanResultTile(
                      result: r,
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (context) {
                        r.device.connect();
                        return DeviceScreen(device: r.device);
                      })),
                    ),
                  )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data) {
            return FloatingActionButton(
              child: Icon(Icons.stop),
              onPressed: () => FlutterBlue.instance.stopScan(),
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
                child: Icon(Icons.search),
                onPressed: () => FlutterBlue.instance
                    .startScan(timeout: Duration(seconds: 4)));
          }
        },
      ),
    );
  }
}

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({Key key, this.device}) : super(key: key);

  final BluetoothDevice device;

  List<int> _getRandomBytes() {
    final math = Random();
    return [
      math.nextInt(255),
      math.nextInt(255),
      math.nextInt(255),
      math.nextInt(255)
    ];
  }

//  Widget _buildServiceTiles(List<BluetoothService> services) {
//    if (services.length > 0) {
//      return ServiceTile(
//        service: services.last,
//        characteristics: services.last.characteristics.first,
//      );
//    }
//    else
//      return Container();
//  }

  List<Widget> _buildServiceTiles(List<BluetoothService> services) {
    return services
        .map(
          (s) => ServiceTile(
        service: s,
        characteristicTiles: s.characteristics
            .map(
              (c) => CharacteristicTile(
              characteristic: c //,
//            onReadPressed: () => c.read(),
//            onWritePressed: () => c.write(_getRandomBytes()),
//            onNotificationPressed: () =>
//                c.setNotifyValue(!c.isNotifying),
//            descriptorTiles: c.descriptors
//                .map(
//                  (d) => DescriptorTile(
//                descriptor: d,
//                onReadPressed: () => d.read(),
//                onWritePressed: () => d.write(_getRandomBytes()),
//              ),
//            )
//                .toList(),
          ),
        )
            .toList(),
      ),
    )
        .toList();
  }

//        service: s,
//        characteristicTiles: s.characteristics
//            .map(
//              (c) => CharacteristicTile(
//            characteristic: c,
//            onReadPressed: () => c.read(),
//            onWritePressed: () => c.write(_getRandomBytes()),
//            onNotificationPressed: () =>
//                c.setNotifyValue(!c.isNotifying),
//            descriptorTiles: c.descriptors
//                .map(
//                  (d) => DescriptorTile(
//                descriptor: d,
//                onReadPressed: () => d.read(),
//                onWritePressed: () => d.write(_getRandomBytes()),
//              ),
//            )
//                .toList(),
//          ),
//        )
//            .toList(),

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: <Widget>[
          StreamBuilder<BluetoothDeviceState>(
            stream: device.state,
            initialData: BluetoothDeviceState.connecting,
            builder: (c, snapshot) {
              VoidCallback onPressed;
              String text;
              switch (snapshot.data) {
                case BluetoothDeviceState.connected:
                  onPressed = () => device.disconnect();
                  text = 'DISCONNECT';
                  break;
                case BluetoothDeviceState.disconnected:
                  onPressed = () => device.connect();
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().substring(21).toUpperCase();
                  break;
              }
              return FlatButton(
                  onPressed: onPressed,
                  child: Text(
                    text,
                    style: Theme.of(context)
                        .primaryTextTheme
                        .button
                        .copyWith(color: Colors.white),
                  ));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothDeviceState>(
              stream: device.state,
              initialData: BluetoothDeviceState.connecting,
              builder: (c, snapshot) => ListTile(
                leading: (snapshot.data == BluetoothDeviceState.connected)
                    ? Icon(Icons.bluetooth_connected)
                    : Icon(Icons.bluetooth_disabled),
                title: Text(
                    'Device is ${snapshot.data.toString().split('.')[1]}.'),
                subtitle: Text('${device.id}'),
                trailing: StreamBuilder<bool>(
                  stream: device.isDiscoveringServices,
                  initialData: false,
                  builder: (c, snapshot) => IndexedStack(
                    index: snapshot.data ? 1 : 0,
                    children: <Widget>[
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: () => device.discoverServices(),
                      ),
                      IconButton(
                        icon: SizedBox(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.grey),
                          ),
                          width: 18.0,
                          height: 18.0,
                        ),
                        onPressed: null,
                      )
                    ],
                  ),
                ),
              ),
            ),
            StreamBuilder<int>(
              stream: device.mtu,
              initialData: 0,
              builder: (c, snapshot) => ListTile(
                title: Text('MTU Size'),
                subtitle: Text('${snapshot.data} bytes'),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => device.requestMtu(223),
                ),
              ),
            ),
            StreamBuilder<List<BluetoothService>>(
              stream: device.services,
              initialData: [],
              builder: (c, snapshot) {
                return Column(
                  children: _buildServiceTiles(snapshot.data),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


//import 'dart:async';
//import 'dart:math';
//
//
//import 'package:flutter/material.dart';
//import 'package:flutter_blue/flutter_blue.dart';
//import 'package:permissions_plugin/permissions_plugin.dart';
//import 'dart:math';
//import 'widget.dart';
//import 'package:intl/intl.dart';
//
//
////DateTime now = DateTime.now();
//
//void main() => runApp(new FlutterBlueApp());
//
//
//class FlutterBlueApp extends StatelessWidget {
//  @override
//  Widget build(BuildContext context) {
//    return MaterialApp(
//      color: Colors.lightBlue,
//      home: StreamBuilder<BluetoothState>(
//          stream: FlutterBlue.instance.state,
//          initialData: BluetoothState.unknown,
//          builder: (c, snapshot) {
//            final state = snapshot.data;
//            if (state == BluetoothState.on) {
//              return FindDevicesScreen();
//            }
//            return BluetoothOffScreen(state: state);
//          }),
//    );
//  }
//}
//
//class BluetoothOffScreen extends StatelessWidget {
//  const BluetoothOffScreen({Key key, this.state}) : super(key: key);
//
//  final BluetoothState state;
//
//  @override
//  Widget build(BuildContext context) {
//    return Scaffold(
//      backgroundColor: Colors.lightBlue,
//      body: Center(
//        child: Column(
//          mainAxisSize: MainAxisSize.min,
//          children: <Widget>[
//            Icon(
//              Icons.bluetooth_disabled,
//              size: 200.0,
//              color: Colors.white54,
//            ),
//            Text(
//              'Bluetooth Adapter is ${state.toString().substring(15)}.',
//              style: Theme.of(context)
//                  .primaryTextTheme
//                  .subhead
//                  .copyWith(color: Colors.white),
//            ),
//          ],
//        ),
//      ),
//    );
//  }
//}
//
//class FindDevicesScreen extends StatelessWidget {
//  @override
//  Widget build(BuildContext context) {
//    return Scaffold(
//      appBar: AppBar(
//        title: Text('Available Devices'),
//      ),
//      body: RefreshIndicator(
//        onRefresh: () =>
//            FlutterBlue.instance.startScan(timeout: Duration(seconds: 4)),
//        child: SingleChildScrollView(
//          child: Column(
//            children: <Widget>[
//              StreamBuilder<List<BluetoothDevice>>(
//                stream: Stream.periodic(Duration(seconds: 2))
//                    .asyncMap((_) => FlutterBlue.instance.connectedDevices),
//                initialData: [],
//                builder: (c, snapshot) => Column(
//                  children: snapshot.data
//                      .map((d) => ListTile(
//                    title: Text(d.name),
//                    subtitle: Text(d.id.toString()),
//                    trailing: StreamBuilder<BluetoothDeviceState>(
//                      stream: d.state,
//                      initialData: BluetoothDeviceState.disconnected,
//                      builder: (c, snapshot) {
//                        if (snapshot.data ==
//                            BluetoothDeviceState.connected) {
//                          return RaisedButton(
//                            child: Text('OPEN'),
//                            onPressed: () => Navigator.of(context).push(
//                                MaterialPageRoute(
//                                    builder: (context) =>
//                                        DeviceScreen(device: d))),
//                          );
//                        }
//                        return Text(snapshot.data.toString());
//                      },
//                    ),
//                  ))
//                      .toList(),
//                ),
//              ),
//              StreamBuilder<List<ScanResult>>(
//                stream: FlutterBlue.instance.scanResults,
//                initialData: [],
//                builder: (c, snapshot) => Column(
//                  children: snapshot.data
//                      .map(
//                        (r) => ScanResultTile(
//                      result: r,
//                      onTap: () => Navigator.of(context)
//                          .push(MaterialPageRoute(builder: (context) {
//                        r.device.connect();
//                        return DeviceScreen(device: r.device);
//                      })),
//                    ),
//                  )
//                      .toList(),
//                ),
//              ),
//            ],
//          ),
//        ),
//      ),
//      floatingActionButton: StreamBuilder<bool>(
//        stream: FlutterBlue.instance.isScanning,
//        initialData: false,
//        builder: (c, snapshot) {
//          if (snapshot.data) {
//            return FloatingActionButton(
//              child: Icon(Icons.stop),
//              onPressed: () => FlutterBlue.instance.stopScan(),
//              backgroundColor: Colors.red,
//            );
//          } else {
//            return FloatingActionButton(
//                child: Icon(Icons.search),
//                onPressed: () => FlutterBlue.instance
//                    .startScan(timeout: Duration(seconds: 4)));
//          }
//        },
//      ),
//    );
//  }
//}
//
//class DeviceScreen extends StatelessWidget {
//
//  const DeviceScreen({Key key, this.device}) : super(key: key);
//  final BluetoothDevice device;
//
////
////
////    var characteristics = service.characteristics;
////    for(BluetoothCharacteristic c in characteristics) {
////      List<int> value = await c.read();
////      print(value);
////    }
////    final mtu_reading = await device.mtu.first;
////  }
//
//  List<int> _getRandomBytes() {
//    final math = Random();
//    return [
//      math.nextInt(255),
//      math.nextInt(255),
//      math.nextInt(255),
//      math.nextInt(255)
//    ];
//  }
//
//
//  List<Widget> _buildServiceTiles(List<BluetoothService> services) {
//    return services
//        .map(
//          (s) =>
//          ServiceTile(
//            service: s,
//            characteristicTiles: s.characteristics
//                .map(
//                  (c) =>
//                  CharacteristicTile(
//                    characteristic: c,
//                    onReadPressed: () => c.read(),
//                    onWritePressed: () => c.write(_getRandomBytes()),
//                    onNotificationPressed: () =>
//                        c.setNotifyValue(!c.isNotifying),
//                    descriptorTiles: c.descriptors
//                        .map(
//                          (d) =>
//                          DescriptorTile(
//                            descriptor: d,
//                            onReadPressed: () => d.read(),
//                            onWritePressed: () => d.write(_getRandomBytes()),
//                          ),
//                    )
//                        .toList(),
//                  ),
//            )
//                .toList(),
//          ),
//    )
//        .toList();
//  }
//
////s
//
//  @override
//  Widget build(BuildContext context) {
//    return Scaffold(
//        appBar: AppBar(
//          title: Text(device.name),
//          actions: <Widget>[
//            StreamBuilder<BluetoothDeviceState>(
//              stream: device.state,
//              initialData: BluetoothDeviceState.connecting,
//              builder: (c, snapshot) {
//                VoidCallback onPressed;
//                String text;
//                switch (snapshot.data) {
//                  case BluetoothDeviceState.connected:
//                    onPressed = () => device.disconnect();
//                    text = 'DISCONNECT';
//                    break;
//                  case BluetoothDeviceState.disconnected:
//                    onPressed = () => device.connect();
//                    text = 'CONNECT';
//                    break;
//                  default:
//                    onPressed = null;
//                    text = snapshot.data.toString().substring(21).toUpperCase();
//                    break;
//                }
//                return FlatButton(
//                    onPressed: onPressed,
//                    child: Text(
//                      text,
//                      style: Theme
//                          .of(context)
//                          .primaryTextTheme
//                          .button
//                          .copyWith(color: Colors.white),
//                    ));
//              },
//            )
//          ],
//        ),
//        body: SingleChildScrollView(
//    child: Column(
//          children: <Widget>[
//            StreamBuilder<BluetoothDeviceState>(
//              stream: device.state,
//              initialData: BluetoothDeviceState.connecting,
//              builder: (c, snapshot) => ListTile(
//                leading: (snapshot.data == BluetoothDeviceState.connected)
//                    ? Icon(Icons.bluetooth_connected)
//                    : Icon(Icons.bluetooth_disabled),
//                title: Text(
//                    'Device is ${snapshot.data.toString().split('.')[1]}.'),
//                subtitle: Text('${device.id}'),
//                trailing: StreamBuilder<bool>(
//                  stream: device.isDiscoveringServices,
//                  initialData: false,
//                  builder: (c, snapshot) => IndexedStack(
//                    index: snapshot.data ? 1 : 0,
//                    children: <Widget>[
//                      IconButton(
//                        icon: Icon(Icons.refresh),
//                        onPressed: () => device.discoverServices(),
//                      ),
//                      IconButton(
//                        icon: SizedBox(
//                          child: CircularProgressIndicator(
//                            valueColor: AlwaysStoppedAnimation(Colors.grey),
//                          ),
//                          width: 18.0,
//                          height: 18.0,
//                        ),
//                        onPressed: null,
//                      )
//                    ],
//                  ),
//                ),
//              ),
//            ),
//            StreamBuilder<int>(
//              stream: device.mtu,
//              initialData: 0,
//              builder: (c, snapshot) => ListTile(
//                title: Text('MTU Size'),
//                subtitle: Text('${snapshot.data} bytes'),
//                trailing: IconButton(
//                  icon: Icon(Icons.edit),
//                  onPressed: () => device.requestMtu(223),
//                ),
//              ),
//            ),
//            StreamBuilder<List<BluetoothService>>(
//              stream: device.services,
//              initialData: [],
//              builder: (c, snapshot) {
//                return Column (
//                  children : _buildServiceTiles(snapshot.data)
//                );
//            /*    if (snapshot.hasData) {
//                  return Column(
//                      children: _buildServiceTiles(snapshot.data)
////                    children: <List<ServiceTile>> [
////                      snapshot.data != null ? _buildServiceTiles(snapshot.data) : Container(),
////                    ],
//                  );
//                };
//                return Column();*/
//              },
//            ),
//          ],
//        ),
//
//          /*  child: DataTable(
//              columns: [
//                DataColumn(label: Text('Axis')),
//                DataColumn(label: Text('Data Value'))
//              ],
//              rows: [
//                DataRow(cells: [
//                  DataCell(Text('X-Axis')),
//                  DataCell(WeekCountdown()),
//                ]),
//                DataRow(cells: [
//                  DataCell(Text('Y-Axis')),
//                  DataCell(WeekCountdown()),
//                ]),
//              ],
//            )*/
//
//
//
//        )
//    );
//  }
//}
//
//
//
//
///*
//TIMER CODE
//
//class WeekCountdown extends StatefulWidget {
//  @override
//  State<StatefulWidget> createState() => _WeekCountdownState();
//}
//
//class _WeekCountdownState extends State<WeekCountdown> {
//  Timer _timer;
//  DateTime _currentTime;
//
//  @override
//  void initState() {
//    super.initState();
//    _currentTime = DateTime.now();
//    _timer = Timer.periodic(Duration(seconds: 1), _onTimeChange);
//  }
//
//  @override
//  void dispose() {
//    _timer.cancel();
//    super.dispose();
//  }
//
//  void _onTimeChange(Timer timer) {
//    setState(() {
//      _currentTime = DateTime.now();
//    });
//  }
//
//  @override
//  Widget build(BuildContext context) {
//    final startOfNextWeek = calculateStartOfNextWeek(_currentTime);
//    final remaining = startOfNextWeek.difference(_currentTime);
//
//    final days = remaining.inDays;
//    final hours = remaining.inHours - remaining.inDays * 24;
//    final minutes = remaining.inMinutes - remaining.inHours * 60;
//    final seconds = remaining.inSeconds / 37;
//
//    final formattedRemaining = '$seconds';
//
//    return Text(formattedRemaining);
//  }
//}
//
//DateTime calculateStartOfNextWeek(DateTime time) {
//  final daysUntilNextWeek = 8 - time.weekday;
//  return DateTime(time.year, time.month, time.day + daysUntilNextWeek);
//}
//
//
//}
//*/
//
//
//
//
////        child: Column(
////          children: <Widget>[
////            StreamBuilder<BluetoothDeviceState>(
////              stream: device.state,
////              initialData: BluetoothDeviceState.connecting,
////              builder: (c, snapshot) => ListTile(
////                leading: (snapshot.data == BluetoothDeviceState.connected)
////                    ? Icon(Icons.bluetooth_connected)
////                    : Icon(Icons.bluetooth_disabled),
////                title: Text(
////                    'Device is ${snapshot.data.toString().split('.')[1]}.'),
////                subtitle: Text('${device.id}'),
////                trailing: StreamBuilder<bool>(
////                  stream: device.isDiscoveringServices,
////                  initialData: false,
////                  builder: (c, snapshot) => IndexedStack(
////                    index: snapshot.data ? 1 : 0,
////                    children: <Widget>[
////                      IconButton(
////                        icon: Icon(Icons.refresh),
////                        onPressed: () => device.discoverServices(),
////                      ),
////                      IconButton(
////                        icon: SizedBox(
////                          child: CircularProgressIndicator(
////                            valueColor: AlwaysStoppedAnimation(Colors.grey),
////                          ),
////                          width: 18.0,
////                          height: 18.0,
////                        ),
////                        onPressed: null,
////                      )
////                    ],
////                  ),
////                ),
////              ),
////            ),
////            StreamBuilder<int>(
////              stream: device.mtu,
////              initialData: 0,
////              builder: (c, snapshot) => ListTile(
////                title: Text('MTU Size'),
////                subtitle: Text('${snapshot.data} bytes'),
////                trailing: IconButton(
////                  icon: Icon(Icons.edit),
////                  onPressed: () => device.requestMtu(223),
////                ),
////              ),
////            ),
////            StreamBuilder<List<BluetoothService>>(
////              stream: device.services,
////              initialData: [],
////              builder: (c, snapshot) {
////                if (snapshot.hasData) {
////                  return Column(
////                      children: _buildServiceTiles(snapshot.data)
//////                    children: <List<ServiceTile>> [
//////                      snapshot.data != null ? _buildServiceTiles(snapshot.data) : Container(),
//////                    ],
////                  );
////                };
////                return Column();
////              },
////            ),
////          ],
////        ),
//
//
//
///*
//class MyApp extends StatelessWidget {
//  @override
//  Widget build(BuildContext context) {
//    return new MaterialApp(
//      debugShowCheckedModeBanner: false,
//      home: new ListDisplay(),
//    );
//  }
//}
//
//
//class ListDisplay extends StatelessWidget {
//  @override
//  String data1 = 12345141.toString();
//  Widget build(BuildContext context) {
//    return new Scaffold(
//      appBar: new AppBar (title: new Text('Dynamic Demo'),),
//      body: new Text(data1),
//    );
//  }
//}
//*/