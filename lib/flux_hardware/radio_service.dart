import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:crypto/crypto.dart';

part 'radio_service.g.dart';

@HiveType(typeId: 0)
class RadioStation {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final String url;
  @HiveField(2)
  final String country;
  @HiveField(3)
  final String language;
  @HiveField(4)
  final String genre;
  @HiveField(5)
  final int bitrate;
  @HiveField(6)
  final String favicon;
  @HiveField(7)
  final String? uuid;

  RadioStation({
    required this.name,
    required this.url,
    required this.country,
    required this.language,
    required this.genre,
    required this.bitrate,
    required this.favicon,
    this.uuid,
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    return RadioStation(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      country: json['country'] ?? '',
      language: json['language'] ?? '',
      genre: json['tags'] ?? '',
      bitrate: json['bitrate'] ?? 128,
      favicon: json['favicon'] ?? '',
      uuid: json['stationuuid'] ?? json['uuid'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'country': country,
      'language': language,
      'genre': genre,
      'bitrate': bitrate,
      'favicon': favicon,
      'uuid': uuid,
    };
  }

  String get id {
    if (uuid != null && uuid!.isNotEmpty) return uuid!;
    return sha256.convert(utf8.encode(url)).toString().substring(0, 16);
  }
}

class RadioService {
  static const List<String> _baseUrls = [
    'https://de1.api.radio-browser.info',
    'https://at1.api.radio-browser.info',
    'https://fr1.api.radio-browser.info',
    'https://nl1.api.radio-browser.info',
  ];
  static String _baseUrl = _baseUrls[0];
  static const String _streemaUrl = 'https://streema.com/radios/country/';
  static const Duration _requestTimeout = Duration(seconds: 10);

  static final List<RadioStation> _staticTanzaniaStations = [
    RadioStation(
      name: 'Clouds FM',
      url: 'http://173.249.21.17:8000/cloudsfm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Entertainment, Music',
      bitrate: 128,
      favicon: 'https://cmg.co.tz/wp-content/uploads/2021/05/Clouds-FM-Logo.png',
    ),
    RadioStation(
      name: 'Wasafi FM',
      url: 'https://stream.wasafifm.co.tz/radio/8000/radio.mp3',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Entertainment, Music',
      bitrate: 128,
      favicon: 'https://wasafifm.co.tz/wp-content/uploads/2023/07/wasafi-fm-logo.png',
    ),
    RadioStation(
      name: 'Radio One Stereo',
      url: 'http://41.222.181.187:8000/radioone',
      country: 'Tanzania',
      language: 'sw',
      genre: 'News, Talk',
      bitrate: 128,
      favicon: 'https://www.ippmedia.com/sites/default/files/styles/medium/public/radio-one-logo.jpg',
    ),
    RadioStation(
      name: 'E-FM Radio',
      url: 'http://197.250.35.210:8000/efm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Music, Sports',
      bitrate: 128,
      favicon: 'https://efm.co.tz/wp-content/uploads/2019/08/efm-logo.png',
    ),
    RadioStation(
      name: 'Radio Free Africa',
      url: 'http://41.222.176.162:8000/rfa',
      country: 'Tanzania',
      language: 'sw',
      genre: 'News, Music',
      bitrate: 128,
      favicon: 'https://radiofreeafrica.co.tz/wp-content/uploads/2020/06/RFA-Logo.png',
    ),
    RadioStation(
      name: 'TBC Taifa',
      url: 'http://41.59.225.234:8000/tbctaifa',
      country: 'Tanzania',
      language: 'sw',
      genre: 'News, National',
      bitrate: 128,
      favicon: 'https://www.tbc.go.tz/images/logo.png',
    ),
    RadioStation(
      name: 'BBC Swahili',
      url: 'https://www.radiofeeds.co.uk/bbcswahili.asp',
      country: 'Tanzania',
      language: 'sw',
      genre: 'News',
      bitrate: 128,
      favicon: 'https://www.bbc.co.uk/favicon.ico',
    ),
    RadioStation(
      name: 'East African Radio',
      url: 'http://41.222.181.187:8000/eastafricanradio',
      country: 'Tanzania',
      language: 'en',
      genre: 'Music, Culture',
      bitrate: 128,
      favicon: 'https://www.ippmedia.com/sites/default/files/styles/medium/public/ear-logo.jpg',
    ),
    RadioStation(
      name: 'TBC International',
      url: 'http://41.59.225.234:8000/tbcinternational',
      country: 'Tanzania',
      language: 'en',
      genre: 'News, International',
      bitrate: 128,
      favicon: 'https://www.tbc.go.tz/images/logo.png',
    ),
    RadioStation(
      name: 'TBC FM',
      url: 'http://41.59.225.234:8000/tbcfm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Entertainment, Music',
      bitrate: 128,
      favicon: 'https://www.tbc.go.tz/images/logo.png',
    ),
    RadioStation(
      name: 'Info Radio',
      url: 'http://173.249.21.17:8000/inforadio',
      country: 'Tanzania',
      language: 'sw',
      genre: 'News, Info',
      bitrate: 128,
      favicon: 'https://inforadio.co.tz/wp-content/uploads/2021/05/Info-Radio-Logo.png',
    ),
    RadioStation(
      name: 'Kings FM',
      url: 'http://41.78.163.74:8000/kingsfm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Music, Talk',
      bitrate: 128,
      favicon: 'https://kingsfm.co.tz/wp-content/uploads/2020/06/kingsfm.png',
    ),
    RadioStation(
      name: 'Nuru FM',
      url: 'http://41.78.163.78:8000/nurufm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Gospel, Religious',
      bitrate: 128,
      favicon: 'https://nurufm.co.tz/wp-content/uploads/2020/06/nurufm.png',
    ),
    RadioStation(
      name: 'Ebony FM',
      url: 'http://41.78.163.74:8000/ebonyfm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Music, Entertainment',
      bitrate: 128,
      favicon: 'https://ebonyfm.co.tz/wp-content/uploads/2020/06/ebonyfm.png',
    ),
    RadioStation(
      name: 'Radio Kwizera',
      url: 'http://stream.radiokwizera.org:8000/stream',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Community, News',
      bitrate: 64,
      favicon: 'https://radiokwizera.org/wp-content/uploads/2020/06/kwizera.png',
    ),
    RadioStation(
      name: 'Safina FM',
      url: 'http://173.249.21.17:8000/safinafm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Religious',
      bitrate: 128,
      favicon: 'https://safinafm.co.tz/wp-content/uploads/2020/09/safina-logo.png',
    ),
    RadioStation(
      name: 'Boresha Radio',
      url: 'http://41.78.163.78:8000/boresha',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Education, Health',
      bitrate: 128,
      favicon: 'https://boresha.co.tz/wp-content/uploads/2020/06/boresha.png',
    ),
    RadioStation(
      name: 'Ghetto Radio',
      url: 'http://41.78.163.74:8000/ghettoradio',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Hip Hop, Youth',
      bitrate: 128,
      favicon: 'https://ghettoradio.co.tz/wp-content/uploads/2020/06/ghetto.png',
    ),
    RadioStation(
      name: 'Times FM',
      url: 'http://41.78.163.78:8000/timesfm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Entertainment, Music',
      bitrate: 128,
      favicon: 'https://timesfm.co.tz/wp-content/uploads/2019/02/Times-FM-Logo.png',
    ),
    RadioStation(
      name: 'Magic FM',
      url: 'http://41.222.181.187:8000/magicfm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Talk, Music',
      bitrate: 128,
      favicon: 'https://www.ippmedia.com/sites/default/files/styles/medium/public/magic-fm-logo.jpg',
    ),
    RadioStation(
      name: 'Choice FM',
      url: 'http://41.222.181.187:8000/choicefm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Music, Entertainment',
      bitrate: 128,
      favicon: 'https://www.ippmedia.com/sites/default/files/styles/medium/public/choice-fm-logo.jpg',
    ),
    RadioStation(
      name: 'Radio Maria Tanzania',
      url: 'http://dreamsiteradiocp2.com:8024/stream',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Religious',
      bitrate: 64,
      favicon: 'https://www.radiomaria.org/wp-content/uploads/tanzania.png',
    ),
    RadioStation(
      name: 'Bethel Radio',
      url: 'http://173.249.21.17:8000/bethelradio',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Religious, Gospel',
      bitrate: 128,
      favicon: 'https://bethelradio.co.tz/wp-content/uploads/2021/05/Bethel-Radio-Logo.png',
    ),
    RadioStation(
      name: 'Coconut FM',
      url: 'http://41.78.163.74:8000/coconut',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Entertainment, Zanzibar',
      bitrate: 128,
      favicon: 'https://coconut.co.tz/wp-content/uploads/2020/06/coconut.png',
    ),
    RadioStation(
      name: 'Chuchu FM',
      url: 'http://41.78.163.78:8000/chuchu',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Talk, Zanzibar',
      bitrate: 128,
      favicon: 'https://chuchufm.co.tz/wp-content/uploads/2020/06/chuchu.png',
    ),
    RadioStation(
      name: 'Zenj FM',
      url: 'http://41.78.163.74:8000/zenjfm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Music, Zanzibar',
      bitrate: 128,
      favicon: 'https://zenjfm.co.tz/wp-content/uploads/2020/06/zenjfm.png',
    ),
    RadioStation(
      name: 'Morning Star Radio',
      url: 'http://173.249.21.17:8000/morningstar',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Religious',
      bitrate: 128,
      favicon: 'https://morningstar.co.tz/wp-content/uploads/2021/05/Morning-Star-Logo.png',
    ),
    RadioStation(
      name: 'Radio Adhana',
      url: 'http://41.78.163.78:8000/adhana',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Islamic',
      bitrate: 128,
      favicon: 'https://radioadhana.co.tz/wp-content/uploads/2020/06/adhana.png',
    ),
    RadioStation(
      name: 'Radio Kheri',
      url: 'http://41.78.163.74:8000/kheri',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Islamic',
      bitrate: 128,
      favicon: 'https://radiokheri.co.tz/wp-content/uploads/2020/06/kheri.png',
    ),
    RadioStation(
      name: 'Radio Tumaini',
      url: 'http://41.222.176.162:8000/tumaini',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Religious, Catholic',
      bitrate: 128,
      favicon: 'https://radiotumaini.co.tz/wp-content/uploads/2020/06/tumaini.png',
    ),
    RadioStation(
      name: 'Habari Njema',
      url: 'http://41.78.163.78:8000/habarinjema',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Gospel',
      bitrate: 128,
      favicon: 'https://habarinjema.co.tz/wp-content/uploads/2020/06/habarinjema.png',
    ),
    RadioStation(
      name: 'Kahama FM',
      url: 'http://41.78.163.74:8000/kahamafm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Regional',
      bitrate: 128,
      favicon: 'https://kahamafm.co.tz/wp-content/uploads/2020/06/kahamafm.png',
    ),
    RadioStation(
      name: 'Spice FM',
      url: 'http://41.78.163.78:8000/spicefm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Music, Talk',
      bitrate: 128,
      favicon: 'https://spicefm.co.tz/wp-content/uploads/2020/06/spicefm.png',
    ),
    RadioStation(
      name: 'Triple A FM',
      url: 'http://41.78.163.74:8000/triplea',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Regional, Arusha',
      bitrate: 128,
      favicon: 'https://triplea.co.tz/wp-content/uploads/2020/06/triplea.png',
    ),
    RadioStation(
      name: 'TK FM',
      url: 'http://41.78.163.78:8000/tkfm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Regional, Tanga',
      bitrate: 128,
      favicon: 'https://tkfm.co.tz/wp-content/uploads/2020/06/tkfm.png',
    ),
    RadioStation(
      name: 'Sibuka FM',
      url: 'http://41.78.163.74:8000/sibuka',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Music, Culture',
      bitrate: 128,
      favicon: 'https://sibuka.co.tz/wp-content/uploads/2020/06/sibuka.png',
    ),
    RadioStation(
      name: 'Upendo FM',
      url: 'http://41.59.201.21:8000/upendofm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Gospel, Religious',
      bitrate: 128,
      favicon: 'https://upendofm.co.tz/wp-content/uploads/2021/05/cropped-Upendo-FM-Logo.png',
    ),
    RadioStation(
      name: 'CG FM',
      url: 'http://173.249.21.17:8000/cgfm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'News, Entertainment',
      bitrate: 128,
      favicon: 'https://cgfm.co.tz/wp-content/uploads/2020/09/cgfm-logo.png',
    ),
    RadioStation(
      name: 'Abood FM',
      url: 'http://41.59.192.155:8000/aboodfm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'General',
      bitrate: 128,
      favicon: 'https://aboodmedia.co.tz/wp-content/uploads/2020/06/aboodfm.png',
    ),
    RadioStation(
      name: 'Uhuru FM',
      url: 'http://41.222.176.162:8000/uhurufm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'News, Talk',
      bitrate: 128,
      favicon: 'https://uhurufm.co.tz/wp-content/uploads/2020/06/Uhuru-FM-Logo.png',
    ),
    RadioStation(
      name: 'Kiss FM',
      url: 'http://41.59.192.203:8000/kissfm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Music, Entertainment',
      bitrate: 128,
      favicon: 'https://kissfm.co.tz/wp-content/uploads/2020/06/kissfm.png',
    ),
    RadioStation(
      name: 'Pride FM',
      url: 'http://41.78.163.74:8000/pridefm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'General',
      bitrate: 128,
      favicon: 'https://pridefm.co.tz/wp-content/uploads/2020/06/pridefm.png',
    ),
    RadioStation(
      name: 'Passion FM',
      url: 'http://41.59.192.203:8000/passionfm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Music, Talk',
      bitrate: 128,
      favicon: 'https://passionfm.co.tz/wp-content/uploads/2020/06/passionfm.png',
    ),
    RadioStation(
      name: 'Kwanza TV',
      url: 'http://173.249.21.17:8000/kwanzatv',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Entertainment',
      bitrate: 128,
      favicon: 'https://kwanzatv.co.tz/wp-content/uploads/2020/09/kwanza-logo.png',
    ),
    RadioStation(
      name: 'Bomba FM',
      url: 'http://41.78.163.78:8000/bombafm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Music, Youth',
      bitrate: 128,
      favicon: 'https://bombafm.co.tz/wp-content/uploads/2020/06/bombafm.png',
    ),
  ];

  static final List<RadioStation> _staticKenyaStations = [
    RadioStation(
      name: 'Classic 105',
      url: 'https://stream.radiojambo.co.ke/classic105',
      country: 'Kenya',
      language: 'en',
      genre: 'Adult Contemporary',
      bitrate: 128,
      favicon: 'https://classic105.s3.amazonaws.com/wp-content/uploads/2016/05/classic-105-logo.png',
    ),
    RadioStation(
      name: 'Radio Jambo',
      url: 'https://stream.radiojambo.co.ke/radiojambo',
      country: 'Kenya',
      language: 'sw',
      genre: 'Talk, Sports',
      bitrate: 128,
      favicon: 'https://radiojambo.co.ke/static/images/logo.png',
    ),
    RadioStation(
      name: 'Kiss 100',
      url: 'https://stream.radiojambo.co.ke/kiss100',
      country: 'Kenya',
      language: 'en',
      genre: 'Top 40, Pop',
      bitrate: 128,
      favicon: 'https://kiss100.co.ke/static/images/logo.png',
    ),
    RadioStation(
      name: 'Capital FM',
      url: 'https://icecast.capitalfm.co.ke/capitalfm',
      country: 'Kenya',
      language: 'en',
      genre: 'Rock, Pop, Jazz',
      bitrate: 128,
      favicon: 'https://www.capitalfm.co.ke/wp-content/themes/capital-fm/images/logo.png',
    ),
    RadioStation(
      name: 'Homeboyz Radio',
      url: 'https://stream.radiojambo.co.ke/homeboyz',
      country: 'Kenya',
      language: 'en',
      genre: 'Hip Hop, R&B',
      bitrate: 128,
      favicon: 'https://hbr.co.ke/static/images/logo.png',
    ),
    RadioStation(
      name: 'NRG Radio',
      url: 'https://stream.nrg.radio/nrg',
      country: 'Kenya',
      language: 'en',
      genre: 'Top 40, EDM',
      bitrate: 128,
      favicon: 'https://nrg.radio/wp-content/uploads/2018/02/nrg-logo.png',
    ),
    RadioStation(
      name: 'Milele FM',
      url: 'http://41.203.220.138:8000/milele',
      country: 'Kenya',
      language: 'sw',
      genre: 'Entertainment',
      bitrate: 128,
      favicon: 'https://www.milelefm.co.ke/wp-content/uploads/2018/07/milele-logo.png',
    ),
    RadioStation(
      name: 'Radio Citizen',
      url: 'https://rms.co.ke/radiocitizen',
      country: 'Kenya',
      language: 'sw',
      genre: 'News, Talk',
      bitrate: 128,
      favicon: 'https://rms.co.ke/wp-content/uploads/2018/04/citizen-radio.png',
    ),
    RadioStation(
      name: 'Hot 96',
      url: 'https://rms.co.ke/hot96',
      country: 'Kenya',
      language: 'en',
      genre: 'Urban, Hip Hop',
      bitrate: 128,
      favicon: 'https://rms.co.ke/wp-content/uploads/2018/04/hot96.png',
    ),
    RadioStation(
      name: 'Inooro FM',
      url: 'https://rms.co.ke/inoorofm',
      country: 'Kenya',
      language: 'ki',
      genre: 'Vernacular',
      bitrate: 128,
      favicon: 'https://rms.co.ke/wp-content/uploads/2018/04/inooro-fm.png',
    ),
    RadioStation(
      name: 'Kameme FM',
      url: 'http://41.203.220.138:8000/kameme',
      country: 'Kenya',
      language: 'ki',
      genre: 'Vernacular',
      bitrate: 128,
      favicon: 'https://www.kameme.co.ke/wp-content/uploads/2018/07/kameme-logo.png',
    ),
    RadioStation(
      name: 'Ramogi FM',
      url: 'https://rms.co.ke/ramogifm',
      country: 'Kenya',
      language: 'luo',
      genre: 'Vernacular',
      bitrate: 128,
      favicon: 'https://rms.co.ke/wp-content/uploads/2018/04/ramogi-fm.png',
    ),
    RadioStation(
      name: 'Spice FM Kenya',
      url: 'https://stream.standardmedia.co.ke/spicefm',
      country: 'Kenya',
      language: 'en',
      genre: 'Soul, R&B',
      bitrate: 128,
      favicon: 'https://www.spicefm.co.ke/img/logo.png',
    ),
    RadioStation(
      name: 'Vybez Radio',
      url: 'https://stream.standardmedia.co.ke/vybezradio',
      country: 'Kenya',
      language: 'en',
      genre: 'Reggae',
      bitrate: 128,
      favicon: 'https://www.vybezradio.co.ke/img/logo.png',
    ),
    RadioStation(
      name: 'Radio Maisha',
      url: 'https://stream.standardmedia.co.ke/radiomaisha',
      country: 'Kenya',
      language: 'sw',
      genre: 'News, Entertainment',
      bitrate: 128,
      favicon: 'https://www.radiomaisha.co.ke/img/logo.png',
    ),
    RadioStation(
      name: 'Milele FM',
      url: 'http://41.203.220.138:8000/milele',
      country: 'Kenya',
      language: 'sw',
      genre: 'Entertainment',
      bitrate: 128,
      favicon: 'https://www.milelefm.co.ke/wp-content/uploads/2018/07/milele-logo.png',
    ),
    RadioStation(
      name: 'Radio 47',
      url: 'http://41.203.220.138:8000/radio47',
      country: 'Kenya',
      language: 'sw',
      genre: 'News, Talk',
      bitrate: 128,
      favicon: 'https://radio47.co.ke/wp-content/uploads/2023/03/Radio47-Logo.png',
    ),
    RadioStation(
      name: 'Sound City Kenya',
      url: 'http://41.203.220.138:8000/soundcity',
      country: 'Kenya',
      language: 'en',
      genre: 'Music, Urban',
      bitrate: 128,
      favicon: 'https://soundcity.co.ke/wp-content/uploads/2021/05/soundcity-logo.png',
    ),
    RadioStation(
      name: 'Muuga FM',
      url: 'https://rms.co.ke/muugafm',
      country: 'Kenya',
      language: 'meru',
      genre: 'Vernacular',
      bitrate: 128,
      favicon: 'https://rms.co.ke/wp-content/uploads/2018/04/muuga-fm.png',
    ),
    RadioStation(
      name: 'Chamgei FM',
      url: 'https://rms.co.ke/chamgeifm',
      country: 'Kenya',
      language: 'kalenjin',
      genre: 'Vernacular',
      bitrate: 128,
      favicon: 'https://rms.co.ke/wp-content/uploads/2018/04/chamgei-fm.png',
    ),
    RadioStation(
      name: 'Egesa FM',
      url: 'https://rms.co.ke/egesafm',
      country: 'Kenya',
      language: 'gusii',
      genre: 'Vernacular',
      bitrate: 128,
      favicon: 'https://rms.co.ke/wp-content/uploads/2018/04/egesa-fm.png',
    ),
    RadioStation(
      name: 'Mulembe FM',
      url: 'https://rms.co.ke/mulembefm',
      country: 'Kenya',
      language: 'luhya',
      genre: 'Vernacular',
      bitrate: 128,
      favicon: 'https://rms.co.ke/wp-content/uploads/2018/04/mulembe-fm.png',
    ),
    RadioStation(
      name: 'Wimwaro FM',
      url: 'https://rms.co.ke/wimwarofm',
      country: 'Kenya',
      language: 'embu',
      genre: 'Vernacular',
      bitrate: 128,
      favicon: 'https://rms.co.ke/wp-content/uploads/2018/04/wimwaro-fm.png',
    ),
    RadioStation(
      name: 'Musyi FM',
      url: 'https://rms.co.ke/musyifm',
      country: 'Kenya',
      language: 'kamba',
      genre: 'Vernacular',
      bitrate: 128,
      favicon: 'https://rms.co.ke/wp-content/uploads/2018/04/musyi-fm.png',
    ),
    RadioStation(
      name: 'Bahari FM',
      url: 'https://rms.co.ke/baharifm',
      country: 'Kenya',
      language: 'sw',
      genre: 'Coast',
      bitrate: 128,
      favicon: 'https://rms.co.ke/wp-content/uploads/2018/04/bahari-fm.png',
    ),
    RadioStation(
      name: 'Ghetto Radio 89.5',
      url: 'http://41.215.166.226:8000/ghetto',
      country: 'Kenya',
      language: 'sw, sheng',
      genre: 'Reggae, Urban',
      bitrate: 128,
      favicon: 'https://ghettoradio.co.ke/wp-content/uploads/2018/05/ghetto-logo.png',
    ),
    RadioStation(
      name: 'Family Radio 316',
      url: 'https://stream.radio316.co.ke/stream',
      country: 'Kenya',
      language: 'en',
      genre: 'Christian, Gospel',
      bitrate: 128,
      favicon: 'https://radio316.co.ke/wp-content/uploads/2018/05/radio316-logo.png',
    ),
    RadioStation(
      name: 'Hope FM',
      url: 'http://41.215.166.226:8000/hopefm',
      country: 'Kenya',
      language: 'en, sw',
      genre: 'Christian',
      bitrate: 128,
      favicon: 'https://hopefm.co.ke/wp-content/uploads/2018/05/hopefm-logo.png',
    ),
    RadioStation(
      name: 'Kass FM',
      url: 'http://41.215.166.226:8000/kassfm',
      country: 'Kenya',
      language: 'kalenjin',
      genre: 'Vernacular',
      bitrate: 128,
      favicon: 'https://kassfm.co.ke/wp-content/uploads/2018/05/kassfm-logo.png',
    ),
    RadioStation(
      name: 'Radio Taifa',
      url: 'http://41.215.166.226:8000/taifa',
      country: 'Kenya',
      language: 'sw',
      genre: 'National',
      bitrate: 128,
      favicon: 'https://www.kbc.co.ke/wp-content/uploads/2018/05/kbc-logo.png',
    ),
    RadioStation(
      name: 'Coro FM',
      url: 'http://41.215.166.226:8000/coro',
      country: 'Kenya',
      language: 'ki',
      genre: 'Vernacular',
      bitrate: 128,
      favicon: 'https://www.kbc.co.ke/wp-content/uploads/2018/05/coro-logo.png',
    ),
    RadioStation(
      name: 'English Service (KBC)',
      url: 'http://41.215.166.226:8000/english',
      country: 'Kenya',
      language: 'en',
      genre: 'National',
      bitrate: 128,
      favicon: 'https://www.kbc.co.ke/wp-content/uploads/2018/05/kbc-logo.png',
    ),
    RadioStation(
      name: 'X FM Kenya',
      url: 'https://stream.radiojambo.co.ke/xfm',
      country: 'Kenya',
      language: 'en',
      genre: 'Rock',
      bitrate: 128,
      favicon: 'https://xfm.co.ke/static/images/logo.png',
    ),
    RadioStation(
      name: 'East FM',
      url: 'https://stream.radiojambo.co.ke/eastfm',
      country: 'Kenya',
      language: 'hi',
      genre: 'Asian, Music',
      bitrate: 128,
      favicon: 'https://eastfm.co.ke/static/images/logo.png',
    ),
  ];

  static final List<RadioStation> _staticUgandaStations = [
    RadioStation(
      name: 'Capital FM Uganda',
      url: 'https://stream.capitalradio.co.ug/capitalfm',
      country: 'Uganda',
      language: 'en',
      genre: 'Top 40, Pop',
      bitrate: 128,
      favicon: 'https://capitalradio.co.ug/wp-content/uploads/2018/05/capital-logo.png',
    ),
    RadioStation(
      name: 'CBS Radio Buganda',
      url: 'http://41.220.128.140:8000/cbs888',
      country: 'Uganda',
      language: 'lg',
      genre: 'Vernacular, News',
      bitrate: 128,
      favicon: 'https://cbsradio.co.ug/wp-content/uploads/2018/05/cbs-logo.png',
    ),
    RadioStation(
      name: 'Galaxy FM',
      url: 'https://stream.galaxyfm.co.ug/stream',
      country: 'Uganda',
      language: 'en, lg',
      genre: 'Urban, Entertainment',
      bitrate: 128,
      favicon: 'https://galaxyfm.co.ug/wp-content/uploads/2018/05/galaxy-logo.png',
    ),
    RadioStation(
      name: 'Radio Simba',
      url: 'http://41.220.128.140:8000/simba',
      country: 'Uganda',
      language: 'lg',
      genre: 'Entertainment, Comedy',
      bitrate: 128,
      favicon: 'https://radiosimba.ug/wp-content/uploads/2018/05/simba-logo.png',
    ),
    RadioStation(
      name: 'Sanyu FM',
      url: 'https://stream.sanyufm.com/sanyufm',
      country: 'Uganda',
      language: 'en',
      genre: 'Adult Contemporary',
      bitrate: 128,
      favicon: 'https://sanyufm.com/wp-content/uploads/2018/05/sanyu-logo.png',
    ),
  ];

  static final List<RadioStation> _staticRwandaStations = [
    RadioStation(
      name: 'Radio Rwanda',
      url: 'https://stream.rba.co.rw/radiorwanda',
      country: 'Rwanda',
      language: 'rw',
      genre: 'National, News',
      bitrate: 128,
      favicon: 'https://rba.co.rw/img/logo_radio_rwanda.png',
    ),
    RadioStation(
      name: 'Flash FM Rwanda',
      url: 'http://41.216.115.165:8000/flashfm',
      country: 'Rwanda',
      language: 'rw, fr, en',
      genre: 'Talk, Music',
      bitrate: 128,
      favicon: 'https://flash.rw/wp-content/uploads/2018/05/flash-logo.png',
    ),
    RadioStation(
      name: 'Kiss FM Rwanda',
      url: 'https://stream.kissfm.rw/kissfm',
      country: 'Rwanda',
      language: 'rw, en',
      genre: 'Top 40, Urban',
      bitrate: 128,
      favicon: 'https://kissfm.rw/wp-content/uploads/2018/05/kiss-logo.png',
    ),
    RadioStation(
      name: 'KT Radio',
      url: 'http://41.216.115.165:8000/ktradio',
      country: 'Rwanda',
      language: 'rw, en',
      genre: 'News, Talk',
      bitrate: 128,
      favicon: 'https://ktradio.rw/wp-content/uploads/2018/05/kt-logo.png',
    ),
  ];

  static List<RadioStation> getStaticTanzaniaStations() {
    return List.unmodifiable(_staticTanzaniaStations);
  }

  static List<RadioStation> getStaticKenyaStations() {
    return List.unmodifiable(_staticKenyaStations);
  }

  Future<List<RadioStation>> searchStations({
    String? name,
    String? country,
    String? countrycode,
    String? language,
    String? tag,
    int? bitrateMin,
    int? bitrateMax,
    bool hasGeoInfo = false,
    String? order = 'votes',
    bool reverse = true,
    int limit = 50,
    double? lat,
    double? lon,
    double? radius,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{};
    if (name != null) queryParams['name'] = name;
    if (country != null) queryParams['country'] = country;
    if (countrycode != null) queryParams['countrycode'] = countrycode;
    if (language != null) queryParams['language'] = language;
    if (tag != null) queryParams['tag'] = tag;
    if (bitrateMin != null) queryParams['bitrateMin'] = bitrateMin.toString();
    if (bitrateMax != null) queryParams['bitrateMax'] = bitrateMax.toString();
    if (hasGeoInfo) queryParams['hasGeoInfo'] = 'true';
    if (lat != null) queryParams['lat'] = lat.toString();
    if (lon != null) queryParams['lon'] = lon.toString();
    if (radius != null) queryParams['radius'] = radius.toString();
    if (order != null) queryParams['order'] = order;
    queryParams['reverse'] = reverse.toString();
    queryParams['limit'] = limit.toString();
    queryParams['offset'] = offset.toString();
    queryParams['hidebroken'] = 'true';

    // Try multiple mirrors in parallel or sequence for reliability
    for (final baseUrl in _baseUrls) {
      try {
        final uri = Uri.parse(
          '$baseUrl/json/stations/search',
        ).replace(queryParameters: queryParams);
        final response = await http.get(uri).timeout(_requestTimeout);

        if (response.statusCode == 200) {
          _baseUrl = baseUrl; // Update to currently working mirror
          final List<dynamic> data = json.decode(response.body);
          return data.map((json) => RadioStation.fromJson(json)).toList();
        }
      } catch (e) {
        debugPrint('Mirror $baseUrl failed: $e');
        continue;
      }
    }
    throw Exception('Failed to load stations from all mirrors');
  }

  Future<List<String>> getCountries() async {
    for (final baseUrl in _baseUrls) {
      try {
        final uri = Uri.parse('$baseUrl/json/countries');
        final response = await http.get(uri).timeout(_requestTimeout);
        if (response.statusCode == 200) {
          _baseUrl = baseUrl;
          final List<dynamic> data = json.decode(response.body);
          return data.map((json) => json['name'] as String).toList();
        }
      } catch (e) {
        continue;
      }
    }
    throw Exception('Failed to load countries from mirrors');
  }

  Future<List<String>> getTags({int limit = 500}) async {
    final queryParams = {
      'hidebroken': 'true',
      'order': 'stationcount',
      'reverse': 'true',
    };
    for (final baseUrl in _baseUrls) {
      try {
        final uri = Uri.parse('$baseUrl/json/tags').replace(queryParameters: queryParams);
        final response = await http.get(uri).timeout(_requestTimeout);
        if (response.statusCode == 200) {
          _baseUrl = baseUrl;
          final List<dynamic> data = json.decode(response.body);
          return data.take(limit).map((json) => json['name'] as String).toList();
        }
      } catch (e) {
        continue;
      }
    }
    return ['Pop', 'Rock', 'Jazz', 'News', 'Classical', 'Dance'];
  }

  /// Generates a Streema search URL for global aggregation
  String getStreemaSearchUrl(String query) {
    final encodedQuery = Uri.encodeComponent(query);
    return 'https://streema.com/radios/search/?q=$encodedQuery';
  }

  Future<List<String>> getLanguages() async {
    for (final baseUrl in _baseUrls) {
      try {
        final uri = Uri.parse('$baseUrl/json/languages');
        final response = await http.get(uri).timeout(_requestTimeout);
        if (response.statusCode == 200) {
          _baseUrl = baseUrl;
          final List<dynamic> data = json.decode(response.body);
          return data.map((json) => json['name'] as String).toList();
        }
      } catch (e) {
        continue;
      }
    }
    throw Exception('Failed to load languages');
  }

  Future<List<RadioStation>> getTopStations({int limit = 250, int? bitrateMin}) async {
    return searchStations(limit: limit, order: 'votes', reverse: true, bitrateMin: bitrateMin);
  }

  Future<List<RadioStation>> getTrendingStations({int limit = 250, int? bitrateMin}) async {
    return searchStations(limit: limit, order: 'clicktrend', reverse: true, bitrateMin: bitrateMin);
  }

  Future<List<RadioStation>> getStationsByCountry(String country, {int limit = 250, int? bitrateMin}) async {
    return searchStations(country: country, limit: limit, order: 'votes', reverse: true, bitrateMin: bitrateMin);
  }

  Future<List<RadioStation>> getStationsByGenre(String genre, {int limit = 250, int? bitrateMin}) async {
    return searchStations(tag: genre, limit: limit, order: 'votes', reverse: true, bitrateMin: bitrateMin);
  }

  Future<List<RadioStation>> getStationsByLanguage(String language, {int limit = 100, int? bitrateMin}) async {
    return searchStations(language: language, limit: limit, order: 'votes', reverse: true, bitrateMin: bitrateMin);
  }

  Future<List<RadioStation>> getMusicStations({int limit = 100}) async {
    final musicGenres = ['pop', 'rock', 'jazz', 'classical', 'electronic', 'hip hop', 'country', 'reggae'];
    final int limitPerGenre = (limit / musicGenres.length).round();
    
    final futures = musicGenres.map((genre) => searchStations(
      tag: genre, 
      limit: limitPerGenre, 
      order: 'votes', 
      reverse: true,
    ));

    final results = await Future.wait(futures);
    final List<RadioStation> allStations = results.expand((stations) => stations).toList();
    
    return allStations.take(limit).toList();
  }

  Future<List<RadioStation>> getNewsStations({int limit = 100}) async {
    return searchStations(tag: 'news', limit: limit, order: 'votes', reverse: true);
  }

  Future<List<RadioStation>> getSportsStations({int limit = 100}) async {
    return searchStations(tag: 'sports', limit: limit, order: 'votes', reverse: true);
  }

  Future<List<RadioStation>> getTalkStations({int limit = 100}) async {
    final talkTags = ['talk', 'comedy', 'business', 'tech', 'politics'];
    final int limitPerTag = (limit / talkTags.length).round();

    final futures = talkTags.map((tag) => searchStations(
      tag: tag, 
      limit: limitPerTag, 
      order: 'votes', 
      reverse: true,
    ));

    final results = await Future.wait(futures);
    final List<RadioStation> allStations = results.expand((stations) => stations).toList();
    
    return allStations.take(limit).toList();
  }

  Future<List<RadioStation>> getLiveStations({int limit = 200}) async {
    return searchStations(tag: 'live', limit: limit, order: 'votes', reverse: true);
  }

  Future<List<RadioStation>> getGlobalAmFmStations({int limit = 500}) async {
    final int quarterLimit = (limit / 4).round();
    final int eighthLimit = (limit / 8).round();

    final futures = [
      searchStations(tag: 'am', limit: quarterLimit, order: 'clicktrend', reverse: true, hasGeoInfo: false),
      searchStations(tag: 'fm', limit: quarterLimit, order: 'clicktrend', reverse: true, hasGeoInfo: false),
      searchStations(country: 'United States', tag: 'fm', limit: quarterLimit, order: 'votes', reverse: true),
      searchStations(country: 'United Kingdom', tag: 'fm', limit: eighthLimit, order: 'votes', reverse: true),
      searchStations(country: 'Germany', tag: 'fm', limit: eighthLimit, order: 'votes', reverse: true),
    ];

    final results = await Future.wait(futures);
    final List<RadioStation> allStations = results.expand((stations) => stations).toList();

    // Remove duplicates and limit results
    final uniqueStations = <String, RadioStation>{};
    for (final station in allStations) {
      final key = '${station.name}_${station.url}';
      if (!uniqueStations.containsKey(key)) {
        uniqueStations[key] = station;
      }
    }

    return uniqueStations.values.take(limit).toList();
  }

  Future<List<RadioStation>> getStationsByLocation({double? lat, double? lon, double radius = 100, int limit = 50}) async {
    return searchStations(lat: lat, lon: lon, radius: radius, limit: limit, order: 'distance', reverse: false);
  }

  Future<List<RadioStation>> getKenyaStations({int limit = 250, int? bitrateMin}) async {
    try {
      final results = await Future.wait([
        searchStations(country: 'Kenya', limit: limit, order: 'clickcount', reverse: true, bitrateMin: bitrateMin),
        searchStations(countrycode: 'KE', limit: limit, order: 'votes', reverse: true, bitrateMin: bitrateMin),
      ]);

      final List<RadioStation> allStations = [...results[0], ...results[1]];
      final Map<String, RadioStation> uniqueStations = {};
      
      for (final s in _staticKenyaStations) {
        uniqueStations[s.url] = s;
      }
      
      for (final s in allStations) {
        if (!uniqueStations.containsKey(s.url)) {
          uniqueStations[s.url] = s;
        }
      }
      
      return uniqueStations.values.take(limit).toList();
    } catch (e) {
      debugPrint('Kenya search failed: $e');
      return getStaticKenyaStations();
    }
  }

  Future<List<RadioStation>> getTanzaniaStations({int limit = 250, int? bitrateMin}) async {
    try {
      // Perform two searches: one by country name and one by country code to maximize results
      final results = await Future.wait([
        searchStations(country: 'Tanzania', limit: limit, order: 'clickcount', reverse: true, bitrateMin: bitrateMin),
        searchStations(countrycode: 'TZ', limit: limit, order: 'votes', reverse: true, bitrateMin: bitrateMin),
      ]);

      final List<RadioStation> allStations = [...results[0], ...results[1]];
      
      // De-duplicate stations by URL or UUID
      final Map<String, RadioStation> uniqueStations = {};
      
      // Add static stations first to ensure they are present and prioritized
      for (final s in _staticTanzaniaStations) {
        uniqueStations[s.url] = s;
      }
      
      for (final s in allStations) {
        if (!uniqueStations.containsKey(s.url)) {
          uniqueStations[s.url] = s;
        }
      }
      
      final sortedList = uniqueStations.values.toList();
      // Sort by votes/clicks if possible, but keep unique
      return sortedList.take(limit).toList();
    } catch (e) {
      debugPrint('Search failed, using static list: $e');
      return getStaticTanzaniaStations();
    }
  }

  Future<List<RadioStation>> getUgandaStations({int limit = 250, int? bitrateMin}) async {
    try {
      final results = await Future.wait([
        searchStations(country: 'Uganda', limit: limit, order: 'clickcount', reverse: true, bitrateMin: bitrateMin),
        searchStations(countrycode: 'UG', limit: limit, order: 'votes', reverse: true, bitrateMin: bitrateMin),
      ]);
      final List<RadioStation> allStations = [...results[0], ...results[1]];
      final Map<String, RadioStation> uniqueStations = {};
      for (final s in _staticUgandaStations) {
        uniqueStations[s.url] = s;
      }
      for (final s in allStations) {
        if (!uniqueStations.containsKey(s.url)) {
          uniqueStations[s.url] = s;
        }
      }
      return uniqueStations.values.take(limit).toList();
    } catch (e) {
      debugPrint('Uganda search failed: $e');
      return _staticUgandaStations;
    }
  }

  Future<List<RadioStation>> getRwandaStations({int limit = 250, int? bitrateMin}) async {
    try {
      final results = await Future.wait([
        searchStations(country: 'Rwanda', limit: limit, order: 'clickcount', reverse: true, bitrateMin: bitrateMin),
        searchStations(countrycode: 'RW', limit: limit, order: 'votes', reverse: true, bitrateMin: bitrateMin),
      ]);
      final List<RadioStation> allStations = [...results[0], ...results[1]];
      final Map<String, RadioStation> uniqueStations = {};
      for (final s in _staticRwandaStations) {
        uniqueStations[s.url] = s;
      }
      for (final s in allStations) {
        if (!uniqueStations.containsKey(s.url)) {
          uniqueStations[s.url] = s;
        }
      }
      return uniqueStations.values.take(limit).toList();
    } catch (e) {
      debugPrint('Rwanda search failed: $e');
      return _staticRwandaStations;
    }
  }

  Future<List<RadioStation>> getNearbyStations({required double lat, required double lon, int limit = 50}) async {
    return getStationsByLocation(lat: lat, lon: lon, limit: limit);
  }

  Future<bool> reportStation(String uuid) async {
    try {
      final uri = Uri.parse('$_baseUrl/json/report/$uuid');
      final response = await http.get(uri).timeout(_requestTimeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Failed to report station: $e');
      return false;
    }
  }

  Future<void> clickStation(String uuid) async {
    try {
      final uri = Uri.parse('$_baseUrl/json/url/$uuid');
      await http.get(uri).timeout(_requestTimeout);
    } catch (e) {
      // Ignore click tracking errors
    }
  }

  /// Note: Streema doesn't have a public API for direct station fetching in the same format.
  /// This method is a placeholder or for potential future scraping/integration.
  String getStreemaCountryUrl(String countryName) {
    final slug = countryName.toLowerCase().replaceAll(' ', '_');
    return '$_streemaUrl$slug';
  }
}
