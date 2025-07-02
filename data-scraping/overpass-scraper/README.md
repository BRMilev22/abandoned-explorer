# 🏗️ Overpass Scraper for Abandoned Buildings

> **Python scraper that extracts abandoned, ruined, and disused buildings from OpenStreetMap via the Overpass API and stores them in MySQL database**

This scraper connects to the [Overpass API](http://overpass-turbo.eu/) (which powers overpass-turbo.eu) to systematically collect data about abandoned buildings worldwide, automatically categorizes them, and stores the data in a structured MySQL database ready for analysis or integration with mapping applications.

## 🌟 Features

- **🔍 Smart Building Detection** - Finds abandoned, ruined, disused, and demolished buildings using multiple OSM tag patterns
- **📊 Automatic Categorization** - Classifies buildings by type and assigns danger levels based on condition
- **🗺️ Geographic Flexibility** - Supports both city-based and bounding box queries
- **📍 Address Resolution** - Uses reverse geocoding to get human-readable addresses
- **💾 MySQL Integration** - Stores data in organized tables with proper indexing
- **⚡ Rate Limiting** - Respectful API usage with configurable delays
- **📈 Progress Tracking** - Real-time progress bars and comprehensive logging
- **🔄 Duplicate Prevention** - Avoids inserting duplicate locations

## 📁 Database Schema

The scraper creates a dedicated database `scraped-overpass-turbo` with the following structure:

### Tables

#### `categories`
- Building categories (Abandoned, Ruins, Disused, Demolished, Derelict)
- Icons for UI display

#### `danger_levels`
- Risk assessment levels (Low, Medium, High, Extreme)
- Color coding for visualization

#### `locations`
- Main table storing building data
- Geographic coordinates with spatial indexing
- OSM metadata and original tags
- Categorization and address information

#### `location_tags`
- Detailed tag storage for advanced filtering
- Key-value pairs from OpenStreetMap

## 🚀 Quick Start

### Prerequisites

- Python 3.8+
- MySQL 8.0+
- Active internet connection

### Installation

1. **Navigate to the scraper directory:**
```bash
cd data-scraping/overpass-scraper
```

2. **Install dependencies:**
```bash
pip install -r requirements.txt
```

3. **Configure database settings:**
Edit `config.py` to match your MySQL setup:
```python
DATABASE_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': 'your_password',
    'database': 'scraped-overpass-turbo',
    'charset': 'utf8mb4'
}
```

4. **Run the scraper:**
```bash
python overpass_scraper.py         # Full scraping (all target cities)
python run_examples.py             # Interactive examples menu
python scrape_bulgaria.py          # 🇧🇬 Scrape entire Bulgaria
```

## ⚙️ Configuration

### Database Settings
Modify `DATABASE_CONFIG` in `config.py`:
```python
DATABASE_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '',
    'database': 'scraped-overpass-turbo',
    'charset': 'utf8mb4'
}
```

### Scraper Settings
Adjust `SCRAPER_CONFIG` for performance tuning:
```python
SCRAPER_CONFIG = {
    'request_delay': 1.0,      # Seconds between API requests
    'geocoding_timeout': 10,   # Timeout for address lookup
    'user_agent': 'abandoned_explorer_scraper/1.0'
}
```

### Target Locations
Customize `TARGET_CITIES` list:
```python
TARGET_CITIES = [
    "Detroit, Michigan, USA",
    "Pripyat, Ukraine",
    "Your City, Country"
]
```

## 🛠️ Usage Examples

### Basic City Scraping
```python
from overpass_scraper import OverpassScraper

scraper = OverpassScraper()
scraper.scrape_by_city("Detroit, Michigan, USA")
scraper.close()
```

### 🇧🇬 Scrape All of Bulgaria
```python
# Scrape the entire country of Bulgaria
scraper = OverpassScraper()
scraper.scrape_by_country("Bulgaria")
scraper.close()
```

**Or use the dedicated script:**
```bash
python3 scrape_bulgaria.py
```

### Bounding Box Scraping
```python
# Scrape specific geographic area
# Format: (south, west, north, east)
detroit_bbox = (42.2, -83.3, 42.5, -82.9)
scraper.scrape_by_bbox(*detroit_bbox)
```

### Country-Wide Scraping
```python
# Available countries: Bulgaria, Ukraine, Romania, Serbia, Greece
scraper.scrape_by_country("Bulgaria")  # Scrapes entire country
```

### Custom Query
```python
# Run your own Overpass QL query
custom_query = '''
[out:json][timeout:300];
(
  way["building"="abandoned"](bbox);
);
out geom;
'''
locations = scraper.execute_query(custom_query)
scraper.save_to_database(locations)
```

## 🏷️ Building Types Detected

The scraper automatically detects buildings tagged with:

- `building=abandoned`
- `building=ruins`
- `abandoned=yes`
- `disused:building=*`
- `historic=ruins`
- `demolished:building=*`

## 📊 Categories & Risk Levels

### Building Categories
1. **Abandoned Building** - Recently abandoned structures
2. **Ruins** - Historical ruins and ancient structures
3. **Disused Building** - No longer in use but intact
4. **Demolished** - Partially demolished structures
5. **Derelict** - Severely deteriorated buildings

### Danger Levels
1. **Low Risk** (🟢) - Stable structures, minimal danger
2. **Medium Risk** (🟡) - Some structural concerns
3. **High Risk** (🔴) - Dangerous conditions, unstable
4. **Extreme Risk** (🟣) - Severely hazardous, avoid entry

## 📈 Data Output

### Sample Location Record
```json
{
  "osm_id": "w123456789",
  "osm_type": "way",
  "title": "Abandoned Factory Building",
  "description": "Building type: Factory. Status: Abandoned. Built: 1950",
  "latitude": 42.3314,
  "longitude": -83.0458,
  "address": "123 Industrial St, Detroit, MI 48201, USA",
  "category_id": 1,
  "danger_level_id": 3,
  "building_type": "factory",
  "original_tags": "{\"building\":\"factory\",\"abandoned\":\"yes\"}"
}
```

## 🔧 Database Queries

### Find High-Risk Buildings
```sql
SELECT l.title, l.address, dl.name as danger_level
FROM locations l
JOIN danger_levels dl ON l.danger_level_id = dl.id
WHERE dl.risk_level >= 3
ORDER BY dl.risk_level DESC;
```

### Buildings by Category
```sql
SELECT c.name, COUNT(*) as count
FROM locations l
JOIN categories c ON l.category_id = c.id
GROUP BY c.name
ORDER BY count DESC;
```

### Recent Discoveries
```sql
SELECT title, address, scraped_at
FROM locations
WHERE scraped_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
ORDER BY scraped_at DESC;
```

## 📝 Logging

The scraper creates detailed logs in `overpass_scraper.log`:

- API request timing
- Data processing statistics
- Database insertion results
- Error details and recovery

## ⚠️ Responsible Usage

- **Rate Limiting**: Built-in delays respect Overpass API limits
- **Data Accuracy**: OpenStreetMap data quality varies by region
- **Legal Compliance**: Respect local laws regarding abandoned property
- **Safety First**: Never enter dangerous buildings without proper equipment

## 🐛 Troubleshooting

### Common Issues

**Database Connection Failed**
```bash
# Check MySQL service
sudo service mysql start

# Verify credentials in config.py
```

**No Results Found**
```bash
# Try broader geographic area
# Check internet connection
# Verify OpenStreetMap has data for your region
```

**Geocoding Timeouts**
```bash
# Increase geocoding_timeout in config.py
# Check internet connectivity
```

## 🔮 Data Integration

The scraped data can be easily integrated with:

- **Mapping Applications** - Import coordinates for visualization
- **Urban Planning Tools** - Analyze abandonment patterns
- **Historical Research** - Track building lifecycle data
- **Photography Projects** - Plan urban exploration routes

## 📜 License

This scraper respects:
- [OpenStreetMap License](https://www.openstreetmap.org/copyright)
- [Overpass API Terms](https://overpass-api.de/)
- [Nominatim Usage Policy](https://operations.osmfoundation.org/policies/nominatim/)

## 🤝 Contributing

To extend the scraper:

1. Add new building type detection patterns
2. Implement additional categorization logic
3. Create export formats (GeoJSON, KML, etc.)
4. Add data validation and cleanup

## 📞 Support

For issues or questions:
- Check the log file for detailed error information
- Verify your database configuration
- Ensure all dependencies are properly installed
- Test with a small geographic area first

---

**Happy exploring! 🏚️✨** 