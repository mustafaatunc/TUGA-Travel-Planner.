import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/place_model.dart';

class CityData {
  static List<TuristikYer> get popularCities {
    return _rawCities.map((data) {
      return TuristikYer(
        id: (data['isim'] as String).toLowerCase().replaceAll(' ', '_'),
        isim: data['isim'],
        aciklama: data['aciklama'],
        konum: LatLng(data['lat'], data['lng']),
        resimUrl: data['resimUrl'],
        kategori: Kategori.fromString(data['kategori']),
        rating: 4.5,
      );
    }).toList();
  }

  static const List<Map<String, dynamic>> _rawCities = [
    // --- TÜRKİYE ---
    {
      'isim': 'İstanbul',
      'aciklama': 'Türkiye',
      'lat': 41.0082,
      'lng': 28.9784,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?w=800&q=80',
    },
    {
      'isim': 'Ankara',
      'aciklama': 'Türkiye',
      'lat': 39.9334,
      'lng': 32.8597,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1589030343991-69ea1433b941?w=800&q=80',
    },
    {
      'isim': 'İzmir',
      'aciklama': 'Türkiye',
      'lat': 38.4237,
      'lng': 27.1428,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1589553416260-f586c8f1514f?w=800&q=80',
    },
    {
      'isim': 'Antalya',
      'aciklama': 'Türkiye',
      'lat': 36.8969,
      'lng': 30.7133,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1542051841857-5f90071e7989?w=800&q=80',
    },
    {
      'isim': 'Bursa',
      'aciklama': 'Türkiye',
      'lat': 40.1885,
      'lng': 29.0610,
      'kategori': 'tarihi',
      'resimUrl':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c2/Green_Tomb_in_Bursa_02.jpg/800px-Green_Tomb_in_Bursa_02.jpg',
    },
    {
      'isim': 'Adana',
      'aciklama': 'Türkiye',
      'lat': 37.0000,
      'lng': 35.3213,
      'kategori': 'modern',
      'resimUrl':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/0/07/Ta%C5%9Fk%C3%B6pr%C3%BC_Adana.jpg/800px-Ta%C5%9Fk%C3%B6pr%C3%BC_Adana.jpg',
    },
    {
      'isim': 'Gaziantep',
      'aciklama': 'Türkiye',
      'lat': 37.0662,
      'lng': 37.3833,
      'kategori': 'tarihi',
      'resimUrl':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6d/Gaziantep_Castle.jpg/800px-Gaziantep_Castle.jpg',
    },
    {
      'isim': 'Konya',
      'aciklama': 'Türkiye',
      'lat': 37.8746,
      'lng': 32.4932,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1634906233484-2bde3595f994?w=800&q=80',
    },
    {
      'isim': 'Trabzon',
      'aciklama': 'Türkiye',
      'lat': 41.0027,
      'lng': 39.7168,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1626189376692-0b8c634d2e0d?w=800&q=80',
    },
    {
      'isim': 'Muğla',
      'aciklama': 'Türkiye',
      'lat': 37.2153,
      'lng': 28.3636,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1601662998399-528574d6c442?w=800&q=80',
    },
    {
      'isim': 'Eskişehir',
      'aciklama': 'Türkiye',
      'lat': 39.7667,
      'lng': 30.5256,
      'kategori': 'modern',
      'resimUrl':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2b/Eskisehir_Porsuk.jpg/800px-Eskisehir_Porsuk.jpg',
    },
    {
      'isim': 'Mardin',
      'aciklama': 'Türkiye',
      'lat': 37.3129,
      'lng': 40.7340,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1612436442656-78cb964724b7?w=800&q=80',
    },
    {
      'isim': 'Şanlıurfa',
      'aciklama': 'Türkiye',
      'lat': 37.1674,
      'lng': 38.7955,
      'kategori': 'tarihi',
      'resimUrl':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d3/Balikligol_Urfa.jpg/800px-Balikligol_Urfa.jpg',
    },
    {
      'isim': 'Kayseri',
      'aciklama': 'Türkiye',
      'lat': 38.7205,
      'lng': 35.4826,
      'kategori': 'modern',
      'resimUrl':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/Erciyes_Mountain.jpg/800px-Erciyes_Mountain.jpg',
    },
    {
      'isim': 'Samsun',
      'aciklama': 'Türkiye',
      'lat': 41.2867,
      'lng': 36.3300,
      'kategori': 'modern',
      'resimUrl':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/9/92/Bandirma_Vapuru_Samsun.jpg/800px-Bandirma_Vapuru_Samsun.jpg',
    },
    {
      'isim': 'Balıkesir',
      'aciklama': 'Türkiye',
      'lat': 39.6484,
      'lng': 27.8826,
      'kategori': 'doga',
      'resimUrl':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/Cunda_Island_Ayvalik.jpg/800px-Cunda_Island_Ayvalik.jpg',
    },
    {
      'isim': 'Çanakkale',
      'aciklama': 'Türkiye',
      'lat': 40.1553,
      'lng': 26.4142,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1605199650428-c11961a86851?w=800&q=80',
    },
    {
      'isim': 'Nevşehir', // Kapadokya
      'aciklama': 'Kapadokya',
      'lat': 38.6247,
      'lng': 34.7142,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1567899378494-47b22a2ae96a?w=800&q=80',
    },
    {
      'isim': 'Denizli',
      'aciklama': 'Türkiye',
      'lat': 37.7765,
      'lng': 29.0864,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1527838832700-5059252407fa?w=800&q=80',
    },
    {
      'isim': 'Van',
      'aciklama': 'Türkiye',
      'lat': 38.4891,
      'lng': 43.4089,
      'kategori': 'doga',
      'resimUrl':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/9/99/Akdamar_Island_Van.jpg/800px-Akdamar_Island_Van.jpg',
    },
    {
      'isim': 'Bodrum',
      'aciklama': 'Muğla',
      'lat': 37.0344,
      'lng': 27.4305,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1596313364230-22c608f5d082?w=800&q=80',
    },
    {
      'isim': 'Marmaris',
      'aciklama': 'Muğla',
      'lat': 36.8550,
      'lng': 28.2742,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1629729806486-1e434f467554?w=800&q=80',
    },
    {
      'isim': 'Alanya',
      'aciklama': 'Antalya',
      'lat': 36.5444,
      'lng': 31.9954,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1629828762744-8488e0261179?w=800&q=80',
    },
    {
      'isim': 'Kaş',
      'aciklama': 'Antalya',
      'lat': 36.2018,
      'lng': 29.6377,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1622370773030-a434c34a368c?w=800&q=80',
    },

    // --- AVRUPA ---
    {
      'isim': 'Paris',
      'aciklama': 'Fransa',
      'lat': 48.8566,
      'lng': 2.3522,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=800&q=80',
    },
    {
      'isim': 'Lyon',
      'aciklama': 'Fransa',
      'lat': 45.7640,
      'lng': 4.8357,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1626079979707-88484a8a9930?w=800&q=80',
    },
    {
      'isim': 'Marsilya',
      'aciklama': 'Fransa',
      'lat': 43.2965,
      'lng': 5.3698,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1558189606-2187b415a995?w=800&q=80',
    },
    {
      'isim': 'Nice',
      'aciklama': 'Fransa',
      'lat': 43.7102,
      'lng': 7.2620,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1541071476-b6058e0a2948?w=800&q=80',
    },
    {
      'isim': 'Londra',
      'aciklama': 'İngiltere',
      'lat': 51.5074,
      'lng': -0.1278,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=800&q=80',
    },
    {
      'isim': 'Manchester',
      'aciklama': 'İngiltere',
      'lat': 53.4808,
      'lng': -2.2426,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1589410111532-6a84ebfa240e?w=800&q=80',
    },
    {
      'isim': 'Liverpool',
      'aciklama': 'İngiltere',
      'lat': 53.4084,
      'lng': -2.9916,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1596716021677-6f8d070b42f6?w=800&q=80',
    },
    {
      'isim': 'Edinburgh',
      'aciklama': 'İskoçya',
      'lat': 55.9533,
      'lng': -3.1883,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1506377295352-e3154d43ea9e?w=800&q=80',
    },
    {
      'isim': 'Roma',
      'aciklama': 'İtalya',
      'lat': 41.9028,
      'lng': 12.4964,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=800&q=80',
    },
    {
      'isim': 'Milano',
      'aciklama': 'İtalya',
      'lat': 45.4642,
      'lng': 9.1900,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1540562621901-2a5b6c073868?w=800&q=80',
    },
    {
      'isim': 'Venedik',
      'aciklama': 'İtalya',
      'lat': 45.4408,
      'lng': 12.3155,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1514890547357-a9ee288728e0?w=800&q=80',
    },
    {
      'isim': 'Floransa',
      'aciklama': 'İtalya',
      'lat': 43.7696,
      'lng': 11.2558,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1533602525547-07444c11867c?w=800&q=80',
    },
    {
      'isim': 'Napoli',
      'aciklama': 'İtalya',
      'lat': 40.8518,
      'lng': 14.2681,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1589133465494-1a921d743a6d?w=800&q=80',
    },
    {
      'isim': 'Madrid',
      'aciklama': 'İspanya',
      'lat': 40.4168,
      'lng': -3.7038,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1543783207-ec64e4d95325?w=800&q=80',
    },
    {
      'isim': 'Barselona',
      'aciklama': 'İspanya',
      'lat': 41.3851,
      'lng': 2.1734,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1583422409516-2895a77efded?w=800&q=80',
    },
    {
      'isim': 'Valensiya',
      'aciklama': 'İspanya',
      'lat': 39.4699,
      'lng': -0.3763,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1563806495679-661da34237d0?w=800&q=80',
    },
    {
      'isim': 'Sevilla',
      'aciklama': 'İspanya',
      'lat': 37.3891,
      'lng': -5.9845,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1559563220-41804c107530?w=800&q=80',
    },
    {
      'isim': 'Berlin',
      'aciklama': 'Almanya',
      'lat': 52.5200,
      'lng': 13.4050,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1560969184-10fe8719e047?w=800&q=80',
    },
    {
      'isim': 'Münih',
      'aciklama': 'Almanya',
      'lat': 48.1351,
      'lng': 11.5820,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1595867865324-42b78d2b28c3?w=800&q=80',
    },
    {
      'isim': 'Hamburg',
      'aciklama': 'Almanya',
      'lat': 53.5511,
      'lng': 9.9937,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1597067828062-ee23b379659b?w=800&q=80',
    },
    {
      'isim': 'Frankfurt',
      'aciklama': 'Almanya',
      'lat': 50.1109,
      'lng': 8.6821,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1558299839-444747716db2?w=800&q=80',
    },
    {
      'isim': 'Amsterdam',
      'aciklama': 'Hollanda',
      'lat': 52.3676,
      'lng': 4.9041,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1534351590666-13e3e96b5017?w=800&q=80',
    },
    {
      'isim': 'Rotterdam',
      'aciklama': 'Hollanda',
      'lat': 51.9244,
      'lng': 4.4777,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1549488340-9a4d8727187c?w=800&q=80',
    },
    {
      'isim': 'Brüksel',
      'aciklama': 'Belçika',
      'lat': 50.8503,
      'lng': 4.3517,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1563721345-4200778f6922?w=800&q=80',
    },
    {
      'isim': 'Brugge',
      'aciklama': 'Belçika',
      'lat': 51.2093,
      'lng': 3.2247,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1533633355050-42299723de38?w=800&q=80',
    },
    {
      'isim': 'Zürih',
      'aciklama': 'İsviçre',
      'lat': 47.3769,
      'lng': 8.5417,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1515488764276-beab7607c1e6?w=800&q=80',
    },
    {
      'isim': 'Cenevre',
      'aciklama': 'İsviçre',
      'lat': 46.2044,
      'lng': 6.1432,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1559059734-d035412966b9?w=800&q=80',
    },
    {
      'isim': 'Viyana',
      'aciklama': 'Avusturya',
      'lat': 48.2082,
      'lng': 16.3738,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1516550893923-42d28e5677af?w=800&q=80',
    },
    {
      'isim': 'Salzburg',
      'aciklama': 'Avusturya',
      'lat': 47.8095,
      'lng': 13.0550,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1516489370008-62d49915330e?w=800&q=80',
    },
    {
      'isim': 'Prag',
      'aciklama': 'Çekya',
      'lat': 50.0755,
      'lng': 14.4378,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1541849546-2165492d06d6?w=800&q=80',
    },
    {
      'isim': 'Budapeşte',
      'aciklama': 'Macaristan',
      'lat': 47.4979,
      'lng': 19.0402,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1565426873118-a17ed65d7429?w=800&q=80',
    },
    {
      'isim': 'Varşova',
      'aciklama': 'Polonya',
      'lat': 52.2297,
      'lng': 21.0122,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1588698948197-009774640429?w=800&q=80',
    },
    {
      'isim': 'Krakow',
      'aciklama': 'Polonya',
      'lat': 50.0647,
      'lng': 19.9450,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1605206941865-68ae2f57b6f3?w=800&q=80',
    },
    {
      'isim': 'Atina',
      'aciklama': 'Yunanistan',
      'lat': 37.9838,
      'lng': 23.7275,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1603565816030-6b389eeb23cb?w=800&q=80',
    },
    {
      'isim': 'Selanik',
      'aciklama': 'Yunanistan',
      'lat': 40.6401,
      'lng': 22.9444,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1627915993512-40432a5146c6?w=800&q=80',
    },
    {
      'isim': 'Lizbon',
      'aciklama': 'Portekiz',
      'lat': 38.7223,
      'lng': -9.1393,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1555881400-74d7acaacd81?w=800&q=80',
    },
    {
      'isim': 'Porto',
      'aciklama': 'Portekiz',
      'lat': 41.1579,
      'lng': -8.6291,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1563273941-86a029ee6289?w=800&q=80',
    },
    {
      'isim': 'Kopenhag',
      'aciklama': 'Danimarka',
      'lat': 55.6761,
      'lng': 12.5683,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1513622470522-26c3c8a854bc?w=800&q=80',
    },
    {
      'isim': 'Stockholm',
      'aciklama': 'İsveç',
      'lat': 59.3293,
      'lng': 18.0686,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1533659228519-75a805eb1384?w=800&q=80',
    },
    {
      'isim': 'Oslo',
      'aciklama': 'Norveç',
      'lat': 59.9139,
      'lng': 10.7522,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1595168430630-67c7e3f43695?w=800&q=80',
    },
    {
      'isim': 'Helsinki',
      'aciklama': 'Finlandiya',
      'lat': 60.1699,
      'lng': 24.9384,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1558277258-29007d4b413e?w=800&q=80',
    },
    {
      'isim': 'Dublin',
      'aciklama': 'İrlanda',
      'lat': 53.3498,
      'lng': -6.2603,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1564959130747-897fb406b9dc?w=800&q=80',
    },
    {
      'isim': 'Dubrovnik',
      'aciklama': 'Hırvatistan',
      'lat': 42.6507,
      'lng': 18.0944,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1555993539-1732b0258235?w=800&q=80',
    },
    {
      'isim': 'Split',
      'aciklama': 'Hırvatistan',
      'lat': 43.5081,
      'lng': 16.4402,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1580918076632-4754593922cc?w=800&q=80',
    },
    {
      'isim': 'Saraybosna',
      'aciklama': 'Bosna Hersek',
      'lat': 43.8563,
      'lng': 18.4131,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1604576358893-9c8491a13b43?w=800&q=80',
    },
    {
      'isim': 'Belgrad',
      'aciklama': 'Sırbistan',
      'lat': 44.7866,
      'lng': 20.4489,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1563829024888-876a91173873?w=800&q=80',
    },
    {
      'isim': 'Bükreş',
      'aciklama': 'Romanya',
      'lat': 44.4268,
      'lng': 26.1025,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1596482173163-954933a0104f?w=800&q=80',
    },
    {
      'isim': 'Sofya',
      'aciklama': 'Bulgaristan',
      'lat': 42.6977,
      'lng': 23.3219,
      'kategori': 'tarihi',
      'resimUrl':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4b/Alexander_Nevsky_Cathedral%2C_Sofia.jpg/800px-Alexander_Nevsky_Cathedral%2C_Sofia.jpg',
    },
    {
      'isim': 'Kiev',
      'aciklama': 'Ukrayna',
      'lat': 50.4501,
      'lng': 30.5234,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1561542320-9a18cd340469?w=800&q=80',
    },
    {
      'isim': 'Moskova',
      'aciklama': 'Rusya',
      'lat': 55.7558,
      'lng': 37.6173,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1520106212299-d99c443e4568?w=800&q=80',
    },
    {
      'isim': 'Saint Petersburg',
      'aciklama': 'Rusya',
      'lat': 59.9343,
      'lng': 30.3351,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1556610961-2fecc5927173?w=800&q=80',
    },

    // --- ABD & KANADA ---
    {
      'isim': 'New York',
      'aciklama': 'ABD',
      'lat': 40.7128,
      'lng': -74.0060,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1496442226666-8d4a0e62e6e9?w=800&q=80',
    },
    {
      'isim': 'Los Angeles',
      'aciklama': 'ABD',
      'lat': 34.0522,
      'lng': -118.2437,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1534190760961-74e8c1c5c3da?w=800&q=80',
    },
    {
      'isim': 'Chicago',
      'aciklama': 'ABD',
      'lat': 41.8781,
      'lng': -87.6298,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1494522855154-9297ac14b55f?w=800&q=80',
    },
    {
      'isim': 'Miami',
      'aciklama': 'ABD',
      'lat': 25.7617,
      'lng': -80.1918,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1535498730771-e735b998cd64?w=800&q=80',
    },
    {
      'isim': 'San Francisco',
      'aciklama': 'ABD',
      'lat': 37.7749,
      'lng': -122.4194,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1501594907352-04cda38ebc29?w=800&q=80',
    },
    {
      'isim': 'Las Vegas',
      'aciklama': 'ABD',
      'lat': 36.1699,
      'lng': -115.1398,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1605833556294-ea5c7a74f57d?w=800&q=80',
    },
    {
      'isim': 'Washington DC',
      'aciklama': 'ABD',
      'lat': 38.9072,
      'lng': -77.0369,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1557160854-e1e89fdd3286?w=800&q=80',
    },
    {
      'isim': 'Boston',
      'aciklama': 'ABD',
      'lat': 42.3601,
      'lng': -71.0589,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1506096538059-455b722d71b3?w=800&q=80',
    },
    {
      'isim': 'Seattle',
      'aciklama': 'ABD',
      'lat': 47.6062,
      'lng': -122.3321,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1502175353174-a7a70e73b362?w=800&q=80',
    },
    {
      'isim': 'Toronto',
      'aciklama': 'Kanada',
      'lat': 43.6510,
      'lng': -79.3470,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1486325212027-8081e485255e?w=800&q=80',
    },
    {
      'isim': 'Vancouver',
      'aciklama': 'Kanada',
      'lat': 49.2827,
      'lng': -123.1207,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1560260312-bd24536761df?w=800&q=80',
    },
    {
      'isim': 'Montreal',
      'aciklama': 'Kanada',
      'lat': 45.5017,
      'lng': -73.5673,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1519178173668-2fc04a53313d?w=800&q=80',
    },

    // --- GÜNEY AMERİKA ---
    {
      'isim': 'Rio de Janeiro',
      'aciklama': 'Brezilya',
      'lat': -22.9068,
      'lng': -43.1729,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1483729558449-99ef09a8c325?w=800&q=80',
    },
    {
      'isim': 'Sao Paulo',
      'aciklama': 'Brezilya',
      'lat': -23.5505,
      'lng': -46.6333,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1578895210405-927510122d1e?w=800&q=80',
    },
    {
      'isim': 'Buenos Aires',
      'aciklama': 'Arjantin',
      'lat': -34.6037,
      'lng': -58.3816,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1612294037637-ec3acf504e9e?w=800&q=80',
    },
    {
      'isim': 'Lima',
      'aciklama': 'Peru',
      'lat': -12.0464,
      'lng': -77.0428,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1531968455001-5c5272a41129?w=800&q=80',
    },
    {
      'isim': 'Santiago',
      'aciklama': 'Şili',
      'lat': -33.4489,
      'lng': -70.6693,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1528154291023-a6525fabe5b4?w=800&q=80',
    },
    {
      'isim': 'Bogota',
      'aciklama': 'Kolombiya',
      'lat': 4.7110,
      'lng': -74.0721,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1596394516093-501ba68a0ba6?w=800&q=80',
    },
    {
      'isim': 'Meksiko',
      'aciklama': 'Meksika',
      'lat': 19.4326,
      'lng': -99.1332,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1585464231875-d9cae9f0d82b?w=800&q=80',
    },

    // --- ASYA & OKYANUSYA ---
    {
      'isim': 'Tokyo',
      'aciklama': 'Japonya',
      'lat': 35.6762,
      'lng': 139.6503,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800&q=80',
    },
    {
      'isim': 'Kyoto',
      'aciklama': 'Japonya',
      'lat': 35.0116,
      'lng': 135.7681,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=800&q=80',
    },
    {
      'isim': 'Osaka',
      'aciklama': 'Japonya',
      'lat': 34.6937,
      'lng': 135.5023,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1590253232296-6b2f674900a0?w=800&q=80',
    },
    {
      'isim': 'Seul',
      'aciklama': 'Güney Kore',
      'lat': 37.5665,
      'lng': 126.9780,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1538485399081-7191377e8241?w=800&q=80',
    },
    {
      'isim': 'Pekin',
      'aciklama': 'Çin',
      'lat': 39.9042,
      'lng': 116.4074,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=800&q=80',
    },
    {
      'isim': 'Şanghay',
      'aciklama': 'Çin',
      'lat': 31.2304,
      'lng': 121.4737,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1538428494232-9c0d8d3a50f6?w=800&q=80',
    },
    {
      'isim': 'Hong Kong',
      'aciklama': 'Çin',
      'lat': 22.3193,
      'lng': 114.1694,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1536599018102-9f80331440f1?w=800&q=80',
    },
    {
      'isim': 'Bangkok',
      'aciklama': 'Tayland',
      'lat': 13.7563,
      'lng': 100.5018,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1508009603885-50cf7c579365?w=800&q=80',
    },
    {
      'isim': 'Singapur',
      'aciklama': 'Singapur',
      'lat': 1.3521,
      'lng': 103.8198,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1525625293386-3f8f99389edd?w=800&q=80',
    },
    {
      'isim': 'Kuala Lumpur',
      'aciklama': 'Malezya',
      'lat': 3.1390,
      'lng': 101.6869,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=800&q=80',
    },
    {
      'isim': 'Dubai',
      'aciklama': 'BAE',
      'lat': 25.2048,
      'lng': 55.2708,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1512453979798-5ea936a7d40c?w=800&q=80',
    },
    {
      'isim': 'Yeni Delhi',
      'aciklama': 'Hindistan',
      'lat': 28.6139,
      'lng': 77.2090,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1587474262715-9aa64a841087?w=800&q=80',
    },
    {
      'isim': 'Mumbai',
      'aciklama': 'Hindistan',
      'lat': 19.0760,
      'lng': 72.8777,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1570168007204-dfb528c6958f?w=800&q=80',
    },
    {
      'isim': 'Sidney',
      'aciklama': 'Avustralya',
      'lat': -33.8688,
      'lng': 151.2093,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1506973035872-a4ec16b8e8d9?w=800&q=80',
    },
    {
      'isim': 'Melbourne',
      'aciklama': 'Avustralya',
      'lat': -37.8136,
      'lng': 144.9631,
      'kategori': 'modern',
      'resimUrl':
          'https://images.unsplash.com/photo-1514395462725-fb4566210144?w=800&q=80',
    },
    {
      'isim': 'Auckland',
      'aciklama': 'Yeni Zelanda',
      'lat': -36.8485,
      'lng': 174.7633,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1575351881847-b3bf188d9d0a?w=800&q=80',
    },

    // --- AFRİKA ---
    {
      'isim': 'Kahire',
      'aciklama': 'Mısır',
      'lat': 30.0444,
      'lng': 31.2357,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1539768942893-daf53e448371?w=800&q=80',
    },
    {
      'isim': 'Cape Town',
      'aciklama': 'Güney Afrika',
      'lat': -33.9249,
      'lng': 18.4241,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1580060839134-75a5edca2e99?w=800&q=80',
    },
    {
      'isim': 'Marakeş',
      'aciklama': 'Fas',
      'lat': 31.6295,
      'lng': -7.9811,
      'kategori': 'tarihi',
      'resimUrl':
          'https://images.unsplash.com/photo-1597211684694-8f238228653f?w=800&q=80',
    },
    {
      'isim': 'Nairobi',
      'aciklama': 'Kenya',
      'lat': -1.2921,
      'lng': 36.8219,
      'kategori': 'doga',
      'resimUrl':
          'https://images.unsplash.com/photo-1620215712170-c7526bb06123?w=800&q=80',
    },
  ];
}
