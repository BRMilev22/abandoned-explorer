"""
Configuration settings for Overpass Scraper
"""

import os

# Database Configuration
DATABASE_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'user': os.getenv('DB_USER', 'root'),
    'password': os.getenv('DB_PASSWORD', ''),
    'database': 'scraped-overpass-turbo',
    'charset': 'utf8mb4'
}

# Scraper Settings
SCRAPER_CONFIG = {
    'request_delay': float(os.getenv('SCRAPER_DELAY', '2.0')),  # Seconds between requests
    'geocoding_timeout': int(os.getenv('GEOCODING_TIMEOUT', '10')),  # Timeout for geocoding
    'user_agent': 'abandoned_explorer_scraper/1.0'
}

# Target cities for scraping (known for abandoned buildings)
TARGET_CITIES = [
    "Detroit, Michigan, USA",
    "Pripyat, Ukraine", 
    "Buffalo, New York, USA",
    "Cleveland, Ohio, USA",
    "Birmingham, Alabama, USA",
    "Youngstown, Ohio, USA",
    "Flint, Michigan, USA",
    "Camden, New Jersey, USA",
    "Gary, Indiana, USA",
    "East St. Louis, Illinois, USA",
    "Stockton, California, USA",
    "Reading, Pennsylvania, USA",
    
    # Bulgarian cities (comprehensive coverage)
    "Sofia, Bulgaria",
    "Plovdiv, Bulgaria", 
    "Varna, Bulgaria",
    "Burgas, Bulgaria",
    "Ruse, Bulgaria",
    "Stara Zagora, Bulgaria",
    "Pleven, Bulgaria",
    "Dobrich, Bulgaria",
    "Sliven, Bulgaria",
    "Pernik, Bulgaria",
    "Haskovo, Bulgaria",
    "Yambol, Bulgaria",
    "Pazardzhik, Bulgaria",
    "Blagoevgrad, Bulgaria",
    "Veliko Tarnovo, Bulgaria"
]

# Example bounding boxes for major areas
BOUNDING_BOXES = {
    'detroit_metro': (42.2, -83.3, 42.5, -82.9),  # Detroit metro area
    'rust_belt_ohio': (41.3, -81.8, 41.6, -81.5),  # Cleveland area
    'pripyat_zone': (51.3, 30.0, 51.5, 30.2),     # Chernobyl exclusion zone
    
    # Bulgarian regions
    'sofia_region': (42.5, 23.1, 42.9, 23.5),     # Sofia and surrounding area
    'plovdiv_region': (42.0, 24.5, 42.3, 25.0),   # Plovdiv region
    'varna_region': (43.1, 27.7, 43.3, 28.0),     # Varna coastal area
    'burgas_region': (42.3, 27.3, 42.7, 27.7),    # Burgas coastal area
    'ruse_region': (43.7, 25.8, 44.0, 26.2),      # Ruse and Danube area
}

# Country bounding boxes for nationwide scraping
COUNTRY_BOUNDING_BOXES = {
    # Bulgaria - entire country coverage
    'bulgaria': (41.2, 22.4, 44.2, 28.6),         # South, West, North, East
    
    # Other countries (examples)
    'ukraine': (44.4, 22.1, 52.4, 40.2),          # Ukraine
    'romania': (43.6, 20.3, 48.3, 29.7),          # Romania
    'serbia': (42.2, 18.8, 46.2, 23.0),           # Serbia
    'greece': (34.8, 19.4, 41.7, 29.6),           # Greece
}

# Comprehensive list of Bulgarian cities for systematic coverage
BULGARIAN_CITIES = [
    # Major cities (over 100,000 people)
    "Sofia, Bulgaria",
    "Plovdiv, Bulgaria", 
    "Varna, Bulgaria",
    "Burgas, Bulgaria",
    "Ruse, Bulgaria",
    "Stara Zagora, Bulgaria",
    "Pleven, Bulgaria",
    "Dobrich, Bulgaria",
    "Sliven, Bulgaria",
    "Pernik, Bulgaria",
    
    # Regional centers (50,000-100,000 people)
    "Haskovo, Bulgaria",
    "Yambol, Bulgaria",
    "Pazardzhik, Bulgaria",
    "Blagoevgrad, Bulgaria",
    "Veliko Tarnovo, Bulgaria",
    "Gabrovo, Bulgaria",
    "Asenovgrad, Bulgaria",
    "Vidin, Bulgaria",
    "Vratsa, Bulgaria",
    "Kyustendil, Bulgaria",
    "Kazanlak, Bulgaria",
    "Kardzhali, Bulgaria",
    "Montana, Bulgaria",
    "Dimitrovgrad, Bulgaria",
    "Targovishte, Bulgaria",
    "Lovech, Bulgaria",
    "Silistra, Bulgaria",
    "Razgrad, Bulgaria",
    "Gorna Oryahovitsa, Bulgaria",
    "Smolyan, Bulgaria",
    "Petrich, Bulgaria",
    "Sandanski, Bulgaria",
    "Samokov, Bulgaria",
    "Sevlievo, Bulgaria",
    "Lom, Bulgaria",
    "Karlovo, Bulgaria",
    "Velingrad, Bulgaria",
    "Nova Zagora, Bulgaria",
    "Troyan, Bulgaria",
    "Aytos, Bulgaria",
    "Botevgrad, Bulgaria",
    "Gotse Delchev, Bulgaria",
    "Peshtera, Bulgaria",
    "Harmanli, Bulgaria",
    "Karnobat, Bulgaria",
    "Svilengrad, Bulgaria",
    "Panagyurishte, Bulgaria",
    "Chirpan, Bulgaria",
    "Popovo, Bulgaria",
    "Rakovski, Bulgaria",
    "Radomir, Bulgaria",
    "Novi Pazar, Bulgaria",
    "Berkovitsa, Bulgaria",
    "Kostinbrod, Bulgaria",
    "Ihtiman, Bulgaria",
    "Radnevo, Bulgaria",
    "Provadiya, Bulgaria",
    "Isperih, Bulgaria",
    "Balchik, Bulgaria",
    "Kavarna, Bulgaria",
    "Byala, Bulgaria",
    "Nessebar, Bulgaria",
    "Sozopol, Bulgaria",
    "Primorsko, Bulgaria",
    "Tsarevo, Bulgaria",
    "Pomorie, Bulgaria",
    "Obzor, Bulgaria",
    "Bansko, Bulgaria",
    "Razlog, Bulgaria",
    "Melnik, Bulgaria",
    "Belogradchik, Bulgaria",
    "Chiprovtsi, Bulgaria",
    "Koprivshtitsa, Bulgaria",
    "Arbanasi, Bulgaria",
    "Bozhentsi, Bulgaria",
    "Etropole, Bulgaria",
    "Teteven, Bulgaria",
    "Apriltsi, Bulgaria",
    "Kalofer, Bulgaria",
    "Sopot, Bulgaria",
    "Kotel, Bulgaria",
    "Zheravna, Bulgaria",
    "Borovets, Bulgaria",
    "Pamporovo, Bulgaria",
    "Chepelare, Bulgaria",
    "Devin, Bulgaria",
    "Dospat, Bulgaria",
    "Ardino, Bulgaria",
    "Krumovgrad, Bulgaria",
    "Ivaylovgrad, Bulgaria",
    "Zlatograd, Bulgaria",
    "Madan, Bulgaria",
    "Rudozem, Bulgaria",
    "Nedelino, Bulgaria",
    "Batak, Bulgaria",
    "Rakitovo, Bulgaria",
    "Belovo, Bulgaria",
    "Kostenets, Bulgaria",
    "Dolna Banya, Bulgaria",
    "Elin Pelin, Bulgaria",
    "Slivnitsa, Bulgaria",
    "Dragoman, Bulgaria",
    "Tran, Bulgaria",
    "Breznik, Bulgaria",
    "Godech, Bulgaria",
    "Svoge, Bulgaria",
    "Mezdra, Bulgaria",
    "Roman, Bulgaria",
    "Knezha, Bulgaria",
    "Lukovit, Bulgaria",
    "Ugarchin, Bulgaria",
    "Yablanitsa, Bulgaria",
    "Byala Slatina, Bulgaria",
    "Oryahovo, Bulgaria",
    "Kozloduy, Bulgaria",
    "Hayredin, Bulgaria",
    "Valchedram, Bulgaria",
    "Kula, Bulgaria",
    "Bregovo, Bulgaria",
    "Chuprene, Bulgaria",
    "Makresh, Bulgaria",
    "Varshets, Bulgaria",
    "Georgi Damyanovo, Bulgaria",
    "Miziya, Bulgaria",
    "Yakimovo, Bulgaria",
    "Medkovets, Bulgaria",
    "Novo Selo, Bulgaria"
] 