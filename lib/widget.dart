// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'dart:math';

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

List<List<double>> data = new List();
double x;

class CharacteristicTile extends StatelessWidget {
  final BluetoothCharacteristic characteristic;
  final List<DescriptorTile> descriptorTiles;
  final VoidCallback onReadPressed;
  final VoidCallback onWritePressed;
  final VoidCallback onNotificationPressed;

  //Parameters for reading data
  final sensorNumber = 8; //The number of sensors within each packet, assuming each sensor uses two array elements, or 2 bytes of data
  final rowLength = 4;    //The length of each row in the table to be displayed
  final dataBuffer = 3;   //The number of elements to skip at the beginning of each packet of data (usually contains info like packet length and packet number, but no actual sensor data)
  final packetNumber = 2;


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

          if (characteristic.uuid.toString().toUpperCase().substring(4, 8) == "0003" && sensorData.length > 0) {
            if (sensorData[1] == packetNumber) {

              //Clear data array and re-populate it with new stream
              data.clear();
              for (int i = 0; i < (sensorNumber/rowLength); i++) {
                List<double> rowData = new List.filled(rowLength, 0, growable: false);
                for (int h = 0; h < rowLength; h++) {
                  //First get the beginning index of each row with sensorDataIndex
                  //Then calculate the temeperature values using formula: (x1*256 + x2)*0.00390625

                  int largeByteIndex = dataBuffer+i*sensorNumber+2*h;
                  int smallByteIndex = largeByteIndex+1;
                  if(smallByteIndex > sensorData.length-1)
                    break;
                  int largeByte = sensorData[largeByteIndex];
                  int smallByte = sensorData[smallByteIndex];

                  rowData[h] = (largeByte*256 + smallByte)*0.00390625;
                }
                data.add(rowData);
              }

              //Add values to formatted array with Row labels
            }

            int i = 0;
            List<double> values = new List();
            for(i = 0; i < 36; i+=2) {
              values.add((sensorData[i]*256 + sensorData[i+1])*0.00390625);
            }

            for(; i < 45; i +=2) {
              values.add(0.0+(sensorData[i]*256 + sensorData[i+1]));
            }

            for(; i < 51; i +=2) {
              values.add(0.0+(sensorData[i]*256 + sensorData[i+1]));
            }

            values.add(0.0+(sensorData[52]*256 + sensorData[53]));

            values.add(0.0+(sensorData[54]*256 + sensorData[55]));


            //30 rows needed
            return
                    Column(
                        children:
                        <Widget>[DataTable(
                          dataRowHeight: 50,
                          headingRowHeight: 50,
                          columns: [
                            DataColumn(label: Text('1')),
                            DataColumn(label: Text('2')),
                            DataColumn(label: Text('3')),
                            DataColumn(label: Text('4')),
                          ],
                          rows: [
                            DataRow(
                                cells: [
                                  DataCell(Text('Temperature')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                ]
                            ),
                            //TEMPERATURE
                            DataRow(
                              cells: [
                                DataCell(Text(values[0].toStringAsFixed(2))),
                                DataCell(Text(values[1].toStringAsFixed(2))),
                                DataCell(Text(values[2].toStringAsFixed(2))),
                                DataCell(Text(values[3].toStringAsFixed(2))),
                              ]
                            ),
                            DataRow(
                                cells: [
                                  DataCell(Text(values[4].toStringAsFixed(2))),
                                  DataCell(Text(values[5].toStringAsFixed(2))),
                                  DataCell(Text(values[6].toStringAsFixed(2))),
                                  DataCell(Text(values[7].toStringAsFixed(2))),
                                ]
                            ),
                            DataRow(
                                cells: [
                                  DataCell(Text(values[8].toStringAsFixed(2))),
                                  DataCell(Text(values[9].toStringAsFixed(2))),
                                  DataCell(Text(values[10].toStringAsFixed(2))),
                                  DataCell(Text(values[11].toStringAsFixed(2))),
                                ]
                            ),
                            DataRow(
                                cells: [
                                  DataCell(Text(values[12].toStringAsFixed(2))),
                                  DataCell(Text(values[13].toStringAsFixed(2))),
                                  DataCell(Text(values[14].toStringAsFixed(2))),
                                  DataCell(Text(values[15].toStringAsFixed(2))),
                                ]
                            ),
                            DataRow(
                                cells: [
                                  DataCell(Text(values[16].toStringAsFixed(2))),
                                  DataCell(Text(values[17].toStringAsFixed(2))),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                ]
                            ),
                            DataRow(
                                cells: [
                                  DataCell(Text('Pressure')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                ]
                            ),
                            //PRESSURE
                            DataRow(
                                cells: [
                                  DataCell(Text((values[18]*85/4095).toStringAsFixed(2))),
                                  DataCell(Text(pressureCalibration(values[19]).toStringAsFixed(2))),
                                  DataCell(Text((values[20]*85/4095).toStringAsFixed(2))),
                                  DataCell(Text((values[21]*85/4095).toStringAsFixed(2))),
                                ]
                            ),
                            DataRow(
                                cells: [
                                  DataCell(Text((values[22]*85/4095).toStringAsFixed(2))),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                ]
                            ),
                            DataRow(
                                cells: [
                                  DataCell(Text('IMU')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                ]
                            ),
                            //IMU
                            DataRow(
                                cells: [
                                  DataCell(Text(values[23].toStringAsFixed(2))),
                                  DataCell(Text(values[24].toStringAsFixed(2))),
                                  DataCell(Text(values[25].toStringAsFixed(2))),
                                  DataCell(Text('')),
                                ]
                            ),
                            DataRow(
                                cells: [
                                  DataCell(Text('Battery')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                ]
                            ),
                            //BATTERY
                            DataRow(
                                cells: [
                                  DataCell(Text((values[26]/1880*3.3).toStringAsFixed(2))),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                ]
                            ),
                            DataRow(
                                cells: [
                                  DataCell(Text('Steps')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                ]
                            ),
                            //BATTERY
                            DataRow(
                                cells: [
                                  DataCell(Text((values[27]).toStringAsFixed(2))),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  //DataCell(Text('')),
                                ]
                            ),
                          ]
                        )
                        ]
                    );
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
              Container
                ();
        }
      },
    );
  }
}

pressureCalibration(double value) {
  return 4.2988*pow(e, 0.0348*value*85/4095);
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
