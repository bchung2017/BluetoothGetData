// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

class ScanResultTile extends StatelessWidget {
  const ScanResultTile({Key key, this.result, this.onTap}) : super(key: key);

  final ScanResult result;
  final VoidCallback onTap;

  Widget _buildTitle(BuildContext context) {
    if (result.device.name.length > 0) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            result.device.name,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            result.device.id.toString(),
            style: Theme.of(context).textTheme.caption,
          )
        ],
      );
    } else {
      return Text(result.device.id.toString());
    }
  }

  Widget _buildAdvRow(BuildContext context, String title, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.caption),
          SizedBox(
            width: 12.0,
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .caption
                  .apply(color: Colors.black),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  String getNiceHexArray(List<int> bytes) {
    return '[${bytes.map((i) => i.toRadixString(16).padLeft(2, '0')).join(', ')}]'
        .toUpperCase();
  }

  String getNiceManufacturerData(Map<int, List<int>> data) {
    if (data.isEmpty) {
      return null;
    }
    List<String> res = [];
    data.forEach((id, bytes) {
      res.add(
          '${id.toRadixString(16).toUpperCase()}: ${getNiceHexArray(bytes)}');
    });
    return res.join(', ');
  }

  String getNiceServiceData(Map<String, List<int>> data) {
    if (data.isEmpty) {
      return null;
    }
    List<String> res = [];
    data.forEach((id, bytes) {
      res.add('${id.toUpperCase()}: ${getNiceHexArray(bytes)}');
    });
    return res.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: _buildTitle(context),
      leading: Text(result.rssi.toString()),
      trailing: RaisedButton(
        child: Text('CONNECT'),
        color: Colors.black,
        textColor: Colors.white,
        onPressed: (result.advertisementData.connectable) ? onTap : null,
      ),
      children: <Widget>[
        _buildAdvRow(
            context, 'Complete Local Name', result.advertisementData.localName),
        _buildAdvRow(context, 'Tx Power Level',
            '${result.advertisementData.txPowerLevel ?? 'N/A'}'),
        _buildAdvRow(
            context,
            'Manufacturer Data',
            getNiceManufacturerData(
                result.advertisementData.manufacturerData) ??
                'N/A'),
        _buildAdvRow(
            context,
            'Service UUIDs',
            (result.advertisementData.serviceUuids.isNotEmpty)
                ? result.advertisementData.serviceUuids.join(', ').toUpperCase()
                : 'N/A'),
        _buildAdvRow(context, 'Service Data',
            getNiceServiceData(result.advertisementData.serviceData) ?? 'N/A'),
      ],
    );
  }
}

class ServiceTile extends StatelessWidget {
  final BluetoothService service;
  final List<CharacteristicTile> characteristicTiles;

  const ServiceTile({Key key, this.service, this.characteristicTiles})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (characteristicTiles.length > 0 && service.uuid.toString().toUpperCase().substring(4, 8)=="0001") {
      return ExpansionTile(
        initiallyExpanded: true,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Service'),
            Text('0x${service.uuid.toString().toUpperCase().substring(4, 8)}',
                style: Theme.of(context)
                    .textTheme
                    .body1
                    .copyWith(color: Theme.of(context).textTheme.caption.color))
          ],
        ),
        children: characteristicTiles,
      );
    } else {
      print("Searching for Characteristics, could not find 0x0001");
      return Container();
    }
  }
}

List<List<num>> data = new List();
int rowNumber = 0;

class CharacteristicTile extends StatelessWidget {
  final BluetoothCharacteristic characteristic;
  final List<DescriptorTile> descriptorTiles;
  final VoidCallback onReadPressed;
  final VoidCallback onWritePressed;
  final VoidCallback onNotificationPressed;

  //Parameters for reading data
  final sensorNumber = 8; //The number of sensors within each packet, assuming each sensor uses two array elements, or 2 bytes of data
  final rowLength = 7;    //The length of each row in the table to be displayed
  final dataBuffer = 3;   //The number of elements to skip at the beginning of each packet of data (usually contains info like packet length and packet number, but no actual sensor data)
  final packetNumber = 2;
  final dataByteSize = 2;


  const CharacteristicTile(
      {Key key,
        this.characteristic,
        this.descriptorTiles,
        this.onReadPressed,
        this.onWritePressed,
        this.onNotificationPressed})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    //characteristic.setNotifyValue(true);
    return StreamBuilder<List<int>>(
      stream: characteristic.value,
      initialData: characteristic.lastValue,
      builder: (c, snapshot) {
        //Get the data, calculate raw values for each axis and map to degrees
        final sensorData = snapshot.data;
        int largeByteIndex;
        int smallByteIndex;
        int largeByte;
        int smallByte;
        List<double>formattedData = new List();

          if (characteristic.uuid.toString().toUpperCase().substring(4, 8) == "0003" && sensorData.length > 0) {


            //Format raw data into values
            for(int i = dataBuffer; i < sensorData.length-1; i += dataByteSize) {
              largeByteIndex =  i;
              smallByteIndex = largeByteIndex+1;
              largeByte = sensorData[largeByteIndex];
              smallByte = sensorData[smallByteIndex];
              formattedData.add((largeByte*256 + smallByte)*0.00390625);
            }

            //Load formatted data into formatted List
            for (int i = 0; i < (sensorNumber/rowLength); i++) {
              List<num> rowData = new List.filled(rowLength-1, 0, growable: false);
              rowData[0] = rowNumber++;
              for (int h = 1; h < rowLength-1; h++) {
                if(formattedData.isNotEmpty) {
                  rowData[h] = formattedData.first;
                  formattedData.removeAt(0);
                }
                else
                  rowData[h] = 0;
              }
              data.add(rowData);
            }

            if (sensorData[1] == packetNumber) {
              data.clear();
              rowNumber=0;
            }

            //Clear data array and re-populate it with new stream
//            if (sensorData[1] == packetNumber) {
//              data.clear();
//              rowNumber = 0;
//              return
//                Column(
//                    children:
//                    <Widget>[DataTable(
//                      dataRowHeight: 50,
//                      columnSpacing: 20,
//                      columns: [
//                        DataColumn(label: Text('')),
//                        DataColumn(label: Text('1')),
//                        DataColumn(label: Text('2')),
//                        DataColumn(label: Text('3')),
//                        DataColumn(label: Text('4')),
//                        DataColumn(label: Text('5')),
//                        DataColumn(label: Text('6')),
//                      ],
//                      rows: data.map((rowData) =>
//                          DataRow(
//                            cells:
//                            rowData.map((values) =>
//                                DataCell(Text(values.toStringAsFixed(2))),
//                            ).toList(),
//                          )
//                      ).toList(),
//                    )
//                    ]
//                );
//
//            }

//            else
              return
                  Container();
//                Column(
//                    children:
//                    <Widget>[DataTable(
//                      dataRowHeight: 50,
//                      columnSpacing: 20,
//                      columns: [
//                        DataColumn(label: Text('')),
//                        DataColumn(label: Text('1')),
//                        DataColumn(label: Text('2')),
//                        DataColumn(label: Text('3')),
//                        DataColumn(label: Text('4')),
//                        DataColumn(label: Text('5')),
//                        DataColumn(label: Text('6')),
//                      ],
//                      rows: data.map((rowData) =>
//                          DataRow(
//                            cells:
//                            rowData.map((values) =>
//                                DataCell(Text(values.toStringAsFixed(2))),
//                            ).toList(),
//                          )
//                      ).toList(),
//                    )
//                    ]
//                );


            //30 rows needed

          }


          else {
          if (characteristic.uuid.toString().toUpperCase().substring(4, 8) ==
              "0003") {
            return Column(
                children: [
                  FlatButton(
                    onPressed: onNotificationPressed,
                    color: Colors.green,
                    child: Text(
                      "Sync Data",
                    ),
                  ),
                ]
            );
          }
          else
            return
              Container();
        }
      },
    );
  }
}

class DescriptorTile extends StatelessWidget {
  final BluetoothDescriptor descriptor;
  final VoidCallback onReadPressed;
  final VoidCallback onWritePressed;

  const DescriptorTile(
      {Key key, this.descriptor, this.onReadPressed, this.onWritePressed})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Descriptor'),
          Text('0x${descriptor.uuid.toString().toUpperCase().substring(4, 8)}',
              style: Theme.of(context)
                  .textTheme
                  .body1
                  .copyWith(color: Theme.of(context).textTheme.caption.color))
        ],
      ),
      subtitle: StreamBuilder<List<int>>(
        stream: descriptor.value,
        initialData: descriptor.lastValue,
        builder: (c, snapshot) => Text(snapshot.data.toString()),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            icon: Icon(
              Icons.file_download,
              color: Theme.of(context).iconTheme.color.withOpacity(0.5),
            ),
            onPressed: onReadPressed,
          ),
          IconButton(
            icon: Icon(
              Icons.file_upload,
              color: Theme.of(context).iconTheme.color.withOpacity(0.5),
            ),
            onPressed: onWritePressed,
          )
        ],
      ),
    );
  }
}

class AdapterStateTile extends StatelessWidget {
  const AdapterStateTile({Key key, @required this.state}) : super(key: key);

  final BluetoothState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.redAccent,
      child: ListTile(
        title: Text(
          'Bluetooth adapter is ${state.toString().substring(15)}',
          style: Theme.of(context).primaryTextTheme.subhead,
        ),
        trailing: Icon(
          Icons.error,
          color: Theme.of(context).primaryTextTheme.subhead.color,
        ),
      ),
    );
  }
}
