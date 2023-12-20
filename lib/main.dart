import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contact List Demo',
      home: ContactListScreen(),
    );
  }
}

class ContactListScreen extends StatefulWidget {
  @override
  _ContactListScreenState createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _requestPermissions();
    await _getContacts();
  }

  Future<void> _requestPermissions() async {
    await Permission.contacts.request();
    await Permission.location.request();
  }

  Future<void> _getContacts() async {
    if (await Permission.contacts.isGranted) {
      List<Contact> contacts = (await ContactsService.getContacts()).toList();
      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts;
      });
    } else {
      // Handle the case where the user denies access to contacts
      print('Permission denied for contacts');
    }
  }

  void _filterContacts(String query) {
    setState(() {
      _filteredContacts = _contacts
          .where((contact) => contact.displayName?.toLowerCase().contains(query.toLowerCase()) == true)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Contact List'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: _filterContacts,
              decoration: InputDecoration(
                labelText: 'Search contacts',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _buildContactList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContactList() {
    return ListView.builder(
      itemCount: _filteredContacts.length,
      itemBuilder: (context, index) {
        return Column(
          children: [
            ListTile(
              title: Text(_filteredContacts[index].displayName ?? ''),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      _makePhoneCall(_filteredContacts[index].phones?.isNotEmpty == true
                          ? _filteredContacts[index].phones!.first.value
                          : null);
                    },
                    child: Text(
                      _filteredContacts[index].phones?.isNotEmpty == true
                          ? _filteredContacts[index].phones!.first.value ?? ''
                          : 'No phone number',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      _showContactLocation(_filteredContacts[index]);
                    },
                    child: Text(
                      'Show Location',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      _viewContactCurrentLocation(_filteredContacts[index]);
                    },
                    child: Text(
                      'View Current Location',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(), // Add a Divider or SizedBox here
          ],
        );
      },
    );
  }

  void _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber != null && await canLaunch('tel:$phoneNumber')) {
      await launch('tel:$phoneNumber');
    } else {
      print('Could not launch phone call');
    }
  }

  void _showContactLocation(Contact contact) {
    if (contact.postalAddresses?.isNotEmpty == true) {
      final address = contact.postalAddresses!.first;
      if (address.street != null || address.city != null || address.region != null ||
          address.postcode != null || address.country != null) {
        _openMaps(
          street: address.street ?? '',
          city: address.city ?? '',
          region: address.region ?? '',
          postcode: address.postcode ?? '',
          country: address.country ?? '',
        );
      } else {
        print('Incomplete address information for this contact');
      }
    } else {
      print('No address available for this contact');
    }
  }

  void _viewContactCurrentLocation(Contact contact) {
    final phoneNumber = contact.phones?.isNotEmpty == true ? contact.phones!.first.value : null;
    if (phoneNumber != null) {
      _getCurrentLocation(phoneNumber);
    } else {
      print('No phone number available for this contact');
    }
  }

  Future<void> _getCurrentLocation(String phoneNumber) async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        print('Location permission denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      final LatLng location = LatLng(position.latitude, position.longitude);
      print('Current Location for $phoneNumber: $location');
      _launchMaps(location);
    } catch (e) {
      print('Error retrieving current location: $e');
    }
  }



  void _openMaps({
    required String street,
    required String city,
    required String region,
    required String postcode,
    required String country,
  }) async {
    try {
      final addressString = '$street, $city, $region, $postcode, $country';
      print('Full Address String: $addressString');

      final locations = await locationFromAddress(addressString);

      if (locations.isNotEmpty) {
        final LatLng location = LatLng(locations.first.latitude, locations.first.longitude);
        print('Location: $location');
        _launchMaps(location);
      } else {
        print('Could not get coordinates from the address');
      }
    } catch (e) {
      print('Error retrieving location: $e');
    }
  }

  void _launchMaps(LatLng location) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch maps');
    }
  }
}
