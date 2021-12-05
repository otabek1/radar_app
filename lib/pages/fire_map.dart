// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geoflutterfire/geoflutterfire.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:radar_app/pages/test_page.dart';

class FireMap extends StatefulWidget {
  @override
  State createState() => FireMapState();
}

class FireMapState extends State<FireMap> {
  GoogleMapController? mapController;
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  Set<Marker> markers = {};
  Set<Circle> circles = {};
  MarkerId? selectedMarker;
  LatLng? markerPosition;
  Position? _currentPosition;
  final Geolocator geolocator = Geolocator();
  double zoom = 16.0;
  List<BitmapDescriptor?> _markerIcons = [];
  int counter = 0;
  var distance = 0.0;
  static const int _badZone = 200;
  static const int _goodZone = 100;
  static const int _veryGoodZone = 30;

  @override
  void dispose() {
    mapController!.dispose();
    super.dispose();
  }

  @override
  void initState() {
    _createMarkerImage("assets/cctv.png");
    _createMarkerImage("assets/electric_car.png");
    _createMarkerImage("assets/speed-radar-dark.png");
    _createMarkerImage("assets/raid.png");
    _createMarkerImage("assets/gai.png");
    super.initState();
  }

  void _createMarkerImage(String asset) async {
    ByteData data = await rootBundle.load(asset);
    Codec codec =
        await instantiateImageCodec(data.buffer.asUint8List(), targetWidth: 96);
    FrameInfo fi = await codec.getNextFrame();
    var bytes;
    await fi.image
        .toByteData(format: ImageByteFormat.png)
        .then((value) => bytes = value!.buffer.asUint8List());
    setState(() {
      _markerIcons.add(BitmapDescriptor.fromBytes(bytes));
    });
  }

  @override
  build(context) {
    StreamSubscription<Position> positionStream = Geolocator.getPositionStream(
            intervalDuration: const Duration(seconds: 20))
        .listen((Position position) async {
      if (_currentPosition != null) {
        distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            _currentPosition!.latitude,
            _currentPosition!.longitude);
      }
      print("before if $distance");
      if (distance > 100) {
        print("distance large");
        setState(() {
          _currentPosition = position;

          print("setstate");
        });
      }
      if (distance > 100) {
        print("second dis");

        _getRadars();
        _getCrashes();
      }
      if (mapController != null) {
        if (await mapController!.getZoomLevel() != zoom) {
          return;
        } else {
          print("object");

          zoom = await mapController!.getZoomLevel();
          mapController!
              .animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: zoom,
          )));
        }
      }
    });
    return Scaffold(
        body: Stack(children: [
      GoogleMap(
        initialCameraPosition:
            CameraPosition(target: LatLng(22.34, 11.22), zoom: 22.0),
        onMapCreated: _onMapCreated,
        markers: markers,
        circles: circles,
        myLocationEnabled:
            true, // Add little blue dot for device location, requires permission from user
        mapType: MapType.normal,
        compassEnabled: true,
        zoomGesturesEnabled: true,
      ),
      Positioned(
        bottom: 20,
        left: 20,
        child: FloatingActionButton(
            onPressed: () async {
              var location = _animateToUser();
            },
            child: Icon(Icons.pin_drop)),
      ),
      Positioned(
        bottom: 20,
        left: MediaQuery.of(context).size.width / 2 - 20,
        child: FloatingActionButton(
          onPressed: _addItem,
          child: Icon(Icons.add),
        ),
      ),
    ]));
  }

  Future<void> _getCrashes() async {
    print("getcrashes called");
    var crashes = await getCrashData(_currentPosition!);
    crashes.listen((event) {
      print("len of crashes ${event.length}");

      if (event.length > _badZone) {
        setState(() {
          circles.clear();
          circles.add(Circle(
              circleId: CircleId("bad"),
              center: LatLng( 
                  _currentPosition!.latitude, _currentPosition!.longitude),
              radius: 3000,
              fillColor: Colors.red[200]!,
              strokeColor: Colors.transparent));
        });
      } else if (event.length > _goodZone) {
        setState(() {
          circles.clear();
          circles.add(Circle(
              circleId: CircleId("good"),
              center: LatLng(
                  _currentPosition!.latitude, _currentPosition!.longitude),
              radius: 3000,
              fillColor: Colors.yellow[200]!,
              strokeColor: Colors.transparent));
        });
      } else if (event.length > _veryGoodZone) {
        setState(() {
          circles.clear();
          circles.add(Circle(
              circleId: CircleId("verygood"),
              center: LatLng(
                  _currentPosition!.latitude, _currentPosition!.longitude),
              radius: 3000,
              fillColor: Colors.green[200]!,
              strokeColor: Colors.transparent));
        });
      } else if (event.length >= 0) {
        setState(() {
          circles.clear();
          print("brilliant");
          circles.add(Circle(
              circleId: CircleId("brialliant"),
              center: LatLng(
                  _currentPosition!.latitude, _currentPosition!.longitude),
              radius: 3000,
              fillColor: Colors.greenAccent[100]!,
              strokeColor: Colors.transparent));
        });
      }
    });
  }

  Future<void> _getRadars() async {
    print("get radars called");
    var results = await getRadarData(_currentPosition!);
    results.listen((event) {
      print("len ${event.length}");
      event.forEach((element) {
        var data = element.data() as Map<String, dynamic>;
        _add(data["position"]["geopoint"], data["type"],
            data["position"]["geohash"]);
      });
    });
  }

  void _add(GeoPoint point, String type, String hash) async {
    var title;
    var type_int;
    switch (type) {
      case "camera":
        title = "Kamera";
        type_int = 0;
        break;
      case "radar":
        title = "Radar";
        type_int = 1;
        break;
      case "car_radar":
        title = "Haraktlanuvchi Radar";
        type_int =  2;
        break;
      case "raid":
        title = "Reyd";
        type_int = 3;
        break;
      case "gai":
        title = "Gai";
        type_int = 4;
        break;
      default:
    }
    // print("lat ${point.latitude}, long ${point.longitude}");
    // print("add marker called");
    final MarkerId markerId = MarkerId(hash);

    final Marker marker = Marker(
      markerId: markerId,
      position: LatLng(point.latitude, point.longitude),
      infoWindow: InfoWindow(title: title, snippet: ""),
      icon: _markerIcons[type_int]!,
    );
    setState(() {
      markers.add(marker);
    });
    // print("marker length ${markers.length}");
  }

  // get data from firebase

  void _addItem() {
    String controlType = "";

    // show dialog with column of buttons
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text(
              "Qanday nazorat \n qo'shmoqchisiz?",
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            content: // column with two buttons
                SizedBox(
              height: 260,
              child: Column(
                children: [
                  SizedBox(
                    width: 200,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.radar),
                      onPressed: () {
                        setState(() {
                          controlType = "radar";
                        });
                        uploadItem(_currentPosition!, controlType);
                        _animateToUser();
                        Navigator.pop(context);
                      },
                      label: const Text("FotoRadar"),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.electric_car),
                      onPressed: () {
                        setState(() {
                          controlType = "car_radar";
                        });
                        uploadItem(_currentPosition!, controlType);
                        _animateToUser();
                        Navigator.pop(context);
                      },
                      label: const Text("Yo'ldagi Radar"),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.emoji_people),
                      onPressed: () {
                        setState(() {
                          controlType = "gai";
                        });
                        uploadItem(_currentPosition!, controlType);
                        _animateToUser();
                        Navigator.pop(context);
                      },
                      label: const Text("GAI"),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.groups),
                      onPressed: () {
                        setState(() {
                          controlType = "raid";
                        });
                        uploadItem(_currentPosition!, controlType);
                        _animateToUser();
                        Navigator.pop(context);
                      },
                      label: const Text("Reyd"),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.taxi_alert),
                      onPressed: () {
                        setState(() {
                          controlType = "crash";
                        });
                        uploadItem(_currentPosition!, controlType);
                        _animateToUser();
                        Navigator.pop(context);
                      },
                      label: const Text("Avtohalokat"),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }

  Future<Position> _determinePosition() async {
    print("location called");

    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best);
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    // mapController!.setMapStyle(
    //     '[{"featureType": "poi","stylers": [{"visibility": "off"}]}]');
    _animateToUser();
  }

  _animateToUser() async {
    var location = await _determinePosition();
    setState(() {
      _currentPosition = location;
    });

    await _getRadars();
    await _getCrashes();
    print("location ${_currentPosition.toString()}");
    mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          zoom: 16.0,
        ),
      ),
    );
  }
}
