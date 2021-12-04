import 'package:flutter/material.dart';
import 'package:geoflutterfire/geoflutterfire.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../data.dart' as data;

// Init firestore and geoFlutterFire
final geo = Geoflutterfire();
final _firestore = FirebaseFirestore.instance;

class TestPage extends StatelessWidget {
  const TestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    //return a scaffold with a centered button
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Page'),
      ),
      body: Center(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                child: const Text('Upload'),
                onPressed: () {
                  // _uploadData();
                },
              ),
              ElevatedButton(
                child: const Text('Download'),
                onPressed: () {
                  getDataLength();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void getDataLength() {
  print("GET LEGNTH");
  var collectionReference = _firestore.collection('crashes');
  collectionReference
      .get()
      .then((value) => print("crashessss ${value.docs.length}"));
  collectionReference = _firestore.collection('items');
  collectionReference
      .get()
      .then((value) => print("items ${value.docs.length}"));
}

var previousItem;
void uploadItem(Position position, String type) {
  if (previousItem != null) {
    var distance = Geolocator.distanceBetween(position.latitude,
        position.longitude, previousItem.latitude, previousItem.longitude);
    print(distance);
    if (distance < 100) {
      return;
    }
  }
  print('uploading item: $type');
  var doc;
  GeoFirePoint point = geo.point(
    latitude: position.latitude,
    longitude: position.longitude,
  );
  if (type == "crash") {
    doc = {
      "position": point.data,
      "id": Timestamp.now().toString(),
    };
    _firestore.collection("crashes").add(doc!);
  } else if (type.isNotEmpty) {
    doc = {"type": type, "position": point.data};

    _firestore.collection("items").add(doc!);
  }
  previousItem = position;
}

void _uploadData() async {
  print("uploading data");
  // var crashes = [];
  print("crash length=" + data.crashes.length.toString());
  for (var i = 0; i < data.crashes.length; i++) {
    GeoFirePoint point = geo.point(
        latitude: double.parse(data.crashes[i]["lat"].toString()),
        longitude: double.parse(data.crashes[i]["long"].toString()));
    var doc = {
      "position": point.data,
      "id": data.crashes[i]["id"],
      "accident_type": data.crashes[i]["accident_type"],
      "violation": data.crashes[i]["violation"],
    };
    print(i);
    _firestore.collection("crashes").add(doc);
  }

//   var locations = [];
//   // loop through locations
//   for (var i = 0; i < data.data.length; i++) {
//     GeoFirePoint myLocation = geo.point(
//         latitude: double.parse(data.data[i]["lat"]!),
//         longitude: double.parse(data.data[i]["long"]!));
//     var doc = {"type": data.data[i]["type"]!, "position": myLocation.data};
//     _firestore.collection('items').add(doc);
//   }

//   // print(locations.toString());
}

Future<Stream> getCrashData(Position position) async {
  print("downloading data");
  GeoFirePoint center =
      geo.point(latitude: position.latitude, longitude: position.longitude);
  print("looooooo ${position.toString()}");
  var collectionReference = _firestore.collection('crashes');
  double radius = 5;
  String field = 'position';

  Stream<List<DocumentSnapshot>> stream = geo
      .collection(collectionRef: collectionReference)
      .within(center: center, radius: radius, field: field, strictMode: true);

  // stream.listen((event) {
  //   // print("length of download ${event.length}");
  //   // event.forEach((element) {
  //   //   print(element.data());
  //   // });
  // });
  return stream;
}

Future<Stream> getRadarData(Position position) async {
  print("getData");
// Create a geoFirePoint
  GeoFirePoint center =
      geo.point(latitude: position.latitude, longitude: position.longitude);

// get the collection reference or query
  var collectionReference = _firestore.collection('items');

  double radius = 20;
  String field = 'position';

  Stream<List<DocumentSnapshot>> stream = geo
      .collection(collectionRef: collectionReference)
      .within(center: center, radius: radius, field: field, strictMode: true);
  return stream;
}
