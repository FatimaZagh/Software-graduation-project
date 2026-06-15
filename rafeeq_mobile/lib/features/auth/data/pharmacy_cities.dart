import 'package:latlong2/latlong.dart';

/// Primary map centers for pharmacy registration city dropdown.
class PharmacyCity {
  const PharmacyCity({required this.name, required this.center});

  final String name;
  final LatLng center;
}

const List<PharmacyCity> kPharmacyCities = [
  PharmacyCity(name: 'Nablus', center: LatLng(32.2211, 35.2544)),
  PharmacyCity(name: 'Jenin', center: LatLng(32.4644, 35.3000)),
  PharmacyCity(name: 'Ramallah', center: LatLng(31.9038, 35.2034)),
  PharmacyCity(name: 'Tulkarm', center: LatLng(32.3105, 35.0278)),
];

PharmacyCity pharmacyCityByName(String name) {
  return kPharmacyCities.firstWhere(
    (c) => c.name == name,
    orElse: () => kPharmacyCities.first,
  );
}
