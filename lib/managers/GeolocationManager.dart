import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';


class GeoLocationUpdate {
  Position userLocation;

  GeoLocationUpdate({
    required this.userLocation,
  });
}


/// https://pub.dev/packages/geolocator
///
///
/// The table below outlines the accuracy options per platform:
///
/// Android	iOS
/// lowest	500m	3000m
/// low	500m	1000m
/// medium	100 - 500m	100m
/// high	0 - 100m	10m
/// best	0 - 100m	~0m
/// bestForNavigation	0 - 100m
///
class GeoLocationManager {
  static final GeoLocationManager _shared = GeoLocationManager._internal();

  bool _isLocationSettingsEnabled = false;
  bool _isListeningForLocationSettingsChange = false;
  bool _isListeningForGeoLocationChange = false;

  bool get isLocationSettingsEnabled => _isLocationSettingsEnabled;

  GeoLocationUpdate? _geoLocationUpdate;
  GeoLocationUpdate? get geoLocationUpdate => _geoLocationUpdate;

  final _onGeoLocationUpdate = StreamController<GeoLocationUpdate>.broadcast();
  Stream<GeoLocationUpdate> get onGeoLocationUpdate =>
      _onGeoLocationUpdate.stream;

  /// called when user changes location settings and re-enters app
  final _onLocationSettingsChange = StreamController<bool>.broadcast();
  Stream<bool> get onLocationSettingsChange => _onLocationSettingsChange.stream;

  late StreamSubscription onLocationSettingsChangeSubscription;
  late StreamSubscription onGeoLocationChangeSubscription;

  var logger = Logger(
    printer: PrettyPrinter(),
  );


  factory GeoLocationManager() {
    return _shared;
  }

  GeoLocationManager._internal();

  initialize() async {
    logger.d("initialize: ${_geoLocationUpdate}");
    if (_geoLocationUpdate != null) {
      logger.w("geo location initialize already has data. fast returning");
      return;
    }

    logger.d("initializing geo location manager");

    // TODO maybe startup geo location like iOS.  must be for a reason. verify I think this is similar now.
    _listenForLocationSettingsChange();

    /// put time sensitive operations above this since it takes a while.
    /// Added a try/catch here because this fails during startup
    try {
      var position = await _determinePosition();
      _sendLocationUpdate(position);

      _listenForPositionUpdates();
    } catch (e) {
      logger.d("Location service exception: $e");
      _isLocationSettingsEnabled = false;
    }
  }

  shutdown() async {
    _geoLocationUpdate = null;

    _isListeningForLocationSettingsChange = false;
    _isListeningForGeoLocationChange = false;

    if (onLocationSettingsChangeSubscription != null) {
      onLocationSettingsChangeSubscription.cancel();
    }

    if (onGeoLocationChangeSubscription != null) {
      onGeoLocationChangeSubscription.cancel();
    }
  }

  /// TODO: make this public and call each edit password screen init if geolocked
  Future<Position> _determinePosition() async {
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
    logger.d('permissions are granted.');
    return await Geolocator.getCurrentPosition();
  }

  ///
  /// https://pub.dev/packages/geolocator
  /// accuracy: the accuracy of the location data that your app wants to receive;
  /// distanceFilter: the minimum distance (measured in meters) a device must move horizontally before an update event is generated;
  /// timeLimit: the maximum amount of time allowed between location updates. When the time limit is passed a TimeOutException will be thrown and the stream will be cancelled. By default no limit is configured.
  ///
  /// TODO: add time limit to curtail computation efforts
  _listenForPositionUpdates() {
    if (_isListeningForGeoLocationChange) {
      logger.d("already listening to geoUpdate stream");
      return;
    }
    logger.d("debug: set listening for geoUpdate stream.");

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    );

    _isListeningForGeoLocationChange = true;

    onGeoLocationChangeSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      _isLocationSettingsEnabled = true;
      // logger.d("position stream: $position");

      _sendLocationUpdate(position);
    });
  }

  _sendLocationUpdate(Position position) {

    var geoLocationUpdate = GeoLocationUpdate(
      userLocation: position,
    );

    _geoLocationUpdate = geoLocationUpdate;

    _onGeoLocationUpdate.sink.add(geoLocationUpdate);
  }

  /// listen for Location Service setting enabled/disabled and react accordingly
  _listenForLocationSettingsChange() {
    if (_isListeningForLocationSettingsChange) {
      logger.d(
          "debug: _listenForLocationSettingsChange: Already listening for location settings changes.  Fast return");
      return;
    }

    logger.d("debug: set listening for location settings.");

    _isListeningForLocationSettingsChange = true;
    onLocationSettingsChangeSubscription =
        Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
      _isLocationSettingsEnabled = status == ServiceStatus.enabled;

      if (status == ServiceStatus.disabled) {
        logger.d("debug-geo: disable location functionality");
      } else if (status == ServiceStatus.enabled) {
        logger.d("debug-geo: enable location functionality");
      }

      _onLocationSettingsChange.sink.add(_isLocationSettingsEnabled);
    });
  }
}
