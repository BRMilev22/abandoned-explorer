#!/usr/bin/env python3
"""
Abandoned Buildings Scraper for Overpass API
Scrapes abandoned, ruined, and disused buildings from OpenStreetMap via Overpass API
and stores them directly in MySQL database.
"""

import os
import json
import time
import logging
from datetime import datetime
from typing import List, Dict, Optional, Tuple
import requests
import mysql.connector
from mysql.connector import Error
import overpy
from geopy.geocoders import Nominatim
from geopy.exc import GeocoderTimedOut, GeocoderServiceError
from tqdm import tqdm

# Load configuration
from config import DATABASE_CONFIG, SCRAPER_CONFIG, TARGET_CITIES, BOUNDING_BOXES, COUNTRY_BOUNDING_BOXES, BULGARIAN_CITIES

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('overpass_scraper.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class OverpassScraper:
    """Scraper for abandoned buildings from Overpass API"""
    
    def __init__(self):
        """Initialize the scraper with database and API connections"""
        self.api = overpy.Overpass()
        self.geolocator = Nominatim(user_agent=SCRAPER_CONFIG['user_agent'])
        
        # Database configuration
        self.db_config = DATABASE_CONFIG
        
        # Rate limiting
        self.request_delay = SCRAPER_CONFIG['request_delay']
        
        # Performance options
        self.fast_mode = True  # Skip reverse geocoding for bulk operations
        
        # Categories mapping for abandoned buildings
        self.building_categories = {
            'abandoned': {'id': 1, 'name': 'Abandoned Building', 'icon': 'building'},
            'ruins': {'id': 2, 'name': 'Ruins', 'icon': 'building.columns'},
            'disused': {'id': 3, 'name': 'Disused Building', 'icon': 'building.2'},
            'demolished': {'id': 4, 'name': 'Demolished', 'icon': 'xmark.square'},
            'derelict': {'id': 5, 'name': 'Derelict', 'icon': 'building.slash'}
        }
        
        # Danger levels
        self.danger_levels = {
            'low': {'id': 1, 'name': 'Low Risk', 'color': '#4CAF50', 'risk_level': 1},
            'medium': {'id': 2, 'name': 'Medium Risk', 'color': '#FF9800', 'risk_level': 2},
            'high': {'id': 3, 'name': 'High Risk', 'color': '#F44336', 'risk_level': 3},
            'extreme': {'id': 4, 'name': 'Extreme Risk', 'color': '#9C27B0', 'risk_level': 4}
        }
        
        # Initialize database (must be done after categories and danger levels are defined)
        self.init_database()

    def init_database(self):
        """Initialize the MySQL database and create necessary tables"""
        try:
            # Create database if it doesn't exist
            connection = mysql.connector.connect(
                host=self.db_config['host'],
                user=self.db_config['user'],
                password=self.db_config['password']
            )
            cursor = connection.cursor()
            cursor.execute(f"CREATE DATABASE IF NOT EXISTS `{self.db_config['database']}` "
                         "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
            cursor.close()
            connection.close()
            
            # Connect to the database
            self.connection = mysql.connector.connect(**self.db_config)
            self.cursor = self.connection.cursor()
            
            logger.info(f"Connected to database: {self.db_config['database']}")
            
            # Create tables
            self.create_tables()
            
        except Error as e:
            logger.error(f"Database connection error: {e}")
            raise

    def create_tables(self):
        """Create necessary tables for storing scraped data"""
        
        # Categories table
        categories_table = """
        CREATE TABLE IF NOT EXISTS `categories` (
            `id` int(11) NOT NULL PRIMARY KEY,
            `name` varchar(100) NOT NULL,
            `icon` varchar(50) NOT NULL,
            `created_at` timestamp DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        """
        
        # Danger levels table
        danger_levels_table = """
        CREATE TABLE IF NOT EXISTS `danger_levels` (
            `id` int(11) NOT NULL PRIMARY KEY,
            `name` varchar(50) NOT NULL,
            `color` varchar(7) NOT NULL,
            `risk_level` int(11) NOT NULL,
            `created_at` timestamp DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        """
        
        # Main locations table
        locations_table = """
        CREATE TABLE IF NOT EXISTS `locations` (
            `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
            `osm_id` varchar(50) UNIQUE NOT NULL,
            `osm_type` enum('node', 'way', 'relation') NOT NULL,
            `title` varchar(255) NOT NULL,
            `description` text,
            `latitude` decimal(10,8) NOT NULL,
            `longitude` decimal(11,8) NOT NULL,
            `address` text,
            `category_id` int(11) DEFAULT NULL,
            `danger_level_id` int(11) DEFAULT NULL,
            `building_type` varchar(100),
            `original_tags` json,
            `scraped_at` timestamp DEFAULT CURRENT_TIMESTAMP,
            `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_coordinates` (`latitude`, `longitude`),
            INDEX `idx_osm` (`osm_id`, `osm_type`),
            INDEX `idx_category` (`category_id`),
            INDEX `idx_danger_level` (`danger_level_id`),
            FOREIGN KEY (`category_id`) REFERENCES `categories`(`id`),
            FOREIGN KEY (`danger_level_id`) REFERENCES `danger_levels`(`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        """
        
        # Tags table for storing location tags
        tags_table = """
        CREATE TABLE IF NOT EXISTS `location_tags` (
            `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
            `location_id` int(11) NOT NULL,
            `tag_key` varchar(100) NOT NULL,
            `tag_value` varchar(255) NOT NULL,
            INDEX `idx_location` (`location_id`),
            INDEX `idx_tag` (`tag_key`, `tag_value`),
            FOREIGN KEY (`location_id`) REFERENCES `locations`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        """
        
        # Execute table creation
        tables = [categories_table, danger_levels_table, locations_table, tags_table]
        
        for table_sql in tables:
            try:
                self.cursor.execute(table_sql)
                logger.info("Table created successfully")
            except Error as e:
                logger.error(f"Error creating table: {e}")
        
        # Insert categories and danger levels
        self.insert_categories_and_levels()
        self.connection.commit()

    def insert_categories_and_levels(self):
        """Insert predefined categories and danger levels"""
        
        # Insert categories
        for key, cat in self.building_categories.items():
            try:
                self.cursor.execute(
                    "INSERT IGNORE INTO categories (id, name, icon) VALUES (%s, %s, %s)",
                    (cat['id'], cat['name'], cat['icon'])
                )
            except Error as e:
                logger.error(f"Error inserting category {key}: {e}")
        
        # Insert danger levels
        for key, level in self.danger_levels.items():
            try:
                self.cursor.execute(
                    "INSERT IGNORE INTO danger_levels (id, name, color, risk_level) VALUES (%s, %s, %s, %s)",
                    (level['id'], level['name'], level['color'], level['risk_level'])
                )
            except Error as e:
                logger.error(f"Error inserting danger level {key}: {e}")

    def build_overpass_query(self, bbox: Tuple[float, float, float, float] = None, 
                           area_name: str = None) -> str:
        """Build Overpass QL query for abandoned buildings"""
        
        if bbox:
            # Bounding box format: (south, west, north, east)
            geo_filter = f"({bbox[0]},{bbox[1]},{bbox[2]},{bbox[3]})"
            
            # Complete Overpass QL query for bounding box
            overpass_query = f"""
[out:json][timeout:300][maxsize:1073741824];
(
  // 1 - General "abandoned" flag
  nwr["abandoned"="yes"]{geo_filter};
  
  // 2 - Historic ruins
  nwr["historic"="ruins"]{geo_filter};
  
  // 3 - Alternative ruins tag
  nwr["ruins"="yes"]{geo_filter};
  nwr["building"="ruins"]{geo_filter};
  
  // 4 - Anything explicitly marked "disused"
  nwr["disused"="yes"]{geo_filter};
  
  // 5 - Disused buildings
  nwr["disused:building"]{geo_filter};
  
  // 6 - Building state tags
  nwr["building:state"~"abandoned|ruins|disused"]{geo_filter};
  
  // 7 - Demolished buildings
  nwr["demolished:building"]{geo_filter};
  nwr["was:building"]{geo_filter};
);
out center;
"""
        elif area_name:
            # NEW APPROACH: Use geocoding to get coordinates, then create bounding box
            # This is much more reliable than area queries
            try:
                geolocator = Nominatim(user_agent="abandoned-explorer-scraper")
                
                logger.info(f"Geocoding city: {area_name}")
                location = geolocator.geocode(area_name, timeout=10)
                
                if not location:
                    logger.error(f"Could not geocode city: {area_name}")
                    return self.build_overpass_query()  # Fallback to global query
                
                lat, lon = location.latitude, location.longitude
                logger.info(f"Found coordinates: {lat:.6f}, {lon:.6f}")
                
                # Create bounding box around city center (roughly 15km radius)
                offset = 0.135  # approximately 15km at Bulgarian latitudes
                bbox = (lat - offset, lon - offset, lat + offset, lon + offset)
                
                logger.info(f"Using bounding box: {bbox}")
                
                # Use the bounding box approach which we know works
                return self.build_overpass_query(bbox=bbox)
                
            except Exception as e:
                logger.error(f"Geocoding failed for {area_name}: {e}")
                logger.info("Falling back to global query without geographic constraints")
                return self.build_overpass_query()  # Fallback to global query
        else:
            # Fallback query without geographic constraints (not recommended)
            overpass_query = """
[out:json][timeout:300][maxsize:1073741824];
(
  nwr["abandoned"="yes"];
  nwr["historic"="ruins"];
  nwr["ruins"="yes"];
  nwr["building"="ruins"];
  nwr["disused"="yes"];
  nwr["disused:building"];
);
out center;
"""
        
        return overpass_query

    def execute_query(self, query: str) -> List[Dict]:
        """Execute Overpass API query and return results"""
        try:
            logger.info("Executing Overpass API query...")
            result = self.api.query(query)
            
            # Show what we got from the API
            total_elements = len(result.nodes) + len(result.ways) + len(result.relations)
            logger.info(f"Raw API results: {len(result.nodes)} nodes, {len(result.ways)} ways, {len(result.relations)} relations")
            logger.info(f"Processing {total_elements} elements..." + (" (fast mode - no geocoding)" if self.fast_mode else ""))
            
            locations = []
            processed = 0
            
            # Process nodes
            for node in result.nodes:
                try:
                    location = self.process_osm_element(node, 'node')
                    if location:
                        locations.append(location)
                    processed += 1
                    
                    # Progress update for large datasets
                    if processed % 200 == 0:
                        logger.info(f"Progress: {processed}/{total_elements} elements processed ({len(locations)} valid locations)")
                        
                except Exception as e:
                    logger.warning(f"Error processing node {node.id}: {e}")
            
            # Process ways
            for way in result.ways:
                try:
                    location = self.process_osm_element(way, 'way')
                    if location:
                        locations.append(location)
                    processed += 1
                    
                    # Progress update for large datasets
                    if processed % 200 == 0:
                        logger.info(f"Progress: {processed}/{total_elements} elements processed ({len(locations)} valid locations)")
                        
                except Exception as e:
                    logger.warning(f"Error processing way {way.id}: {e}")
            
            # Process relations
            for relation in result.relations:
                try:
                    location = self.process_osm_element(relation, 'relation')
                    if location:
                        locations.append(location)
                    processed += 1
                    
                    # Progress update for large datasets
                    if processed % 200 == 0:
                        logger.info(f"Progress: {processed}/{total_elements} elements processed ({len(locations)} valid locations)")
                        
                except Exception as e:
                    logger.warning(f"Error processing relation {relation.id}: {e}")
            
            logger.info(f"Successfully processed {len(locations)} out of {total_elements} elements")
            return locations
            
        except Exception as e:
            logger.error(f"Error executing Overpass query: {e}")
            return []

    def process_osm_element(self, element, osm_type: str) -> Optional[Dict]:
        """Process individual OSM element and extract relevant data"""
        try:
            # Get coordinates
            if osm_type == 'node':
                lat, lon = float(element.lat), float(element.lon)
            elif osm_type == 'way':
                # For ways, use center coordinates if available, otherwise calculate centroid
                if hasattr(element, 'center_lat') and hasattr(element, 'center_lon'):
                    lat, lon = float(element.center_lat), float(element.center_lon)
                elif hasattr(element, 'nd') and element.nd:
                    # Use centroid of way
                    lats = [float(nd.lat) for nd in element.nd if hasattr(nd, 'lat')]
                    lons = [float(nd.lon) for nd in element.nd if hasattr(nd, 'lon')]
                    if not lats or not lons:
                        logger.debug(f"Way {element.id}: no valid node coordinates")
                        return None
                    lat, lon = sum(lats) / len(lats), sum(lons) / len(lons)
                else:
                    logger.debug(f"Way {element.id}: no center coordinates and no nodes")
                    return None
            elif osm_type == 'relation':
                # For relations, use center coordinates if available
                if hasattr(element, 'center_lat') and hasattr(element, 'center_lon'):
                    lat, lon = float(element.center_lat), float(element.center_lon)
                else:
                    logger.debug(f"Relation {element.id}: no center coordinates")
                    return None
            else:
                logger.debug(f"Unknown element type: {osm_type}")
                return None
            
            # Extract tags
            tags = element.tags
            
            # Determine category and danger level
            category_id = self.determine_category(tags)
            danger_level_id = self.determine_danger_level(tags)
            
            # Generate title and description
            title = self.generate_title(tags)
            description = self.generate_description(tags)
            
            # Get address
            address = self.get_address(lat, lon)
            
            location = {
                'osm_id': f"{osm_type[0]}{element.id}",  # n123, w456, r789
                'osm_type': osm_type,
                'title': title,
                'description': description,
                'latitude': lat,
                'longitude': lon,
                'address': address,
                'category_id': category_id,
                'danger_level_id': danger_level_id,
                'building_type': tags.get('building', tags.get('disused:building', 'unknown')),
                'original_tags': json.dumps(tags)
            }
            
            return location
            
        except Exception as e:
            logger.error(f"Error processing OSM element: {e}")
            return None

    def determine_category(self, tags: Dict) -> int:
        """Determine building category based on OSM tags"""
        if tags.get('building') in ['ruins', 'historic']:
            return self.building_categories['ruins']['id']
        elif tags.get('historic') == 'ruins':
            return self.building_categories['ruins']['id']
        elif tags.get('building') == 'abandoned':
            return self.building_categories['abandoned']['id']
        elif 'disused:building' in tags:
            return self.building_categories['disused']['id']
        elif 'demolished:building' in tags:
            return self.building_categories['demolished']['id']
        elif tags.get('abandoned') == 'yes':
            return self.building_categories['abandoned']['id']
        else:
            return self.building_categories['abandoned']['id']  # Default

    def determine_danger_level(self, tags: Dict) -> int:
        """Determine danger level based on building condition and type"""
        # High risk indicators
        if any(tag in tags for tag in ['ruins', 'collapsed', 'demolished']):
            return self.danger_levels['high']['id']
        
        # Medium risk indicators
        if any(tag in tags for tag in ['abandoned', 'disused:building']):
            return self.danger_levels['medium']['id']
        
        # Check building type for inherent dangers
        building_type = tags.get('building', '').lower()
        if building_type in ['industrial', 'factory', 'power_plant', 'warehouse']:
            return self.danger_levels['high']['id']
        elif building_type in ['hospital', 'school', 'office']:
            return self.danger_levels['medium']['id']
        
        return self.danger_levels['low']['id']  # Default

    def generate_title(self, tags: Dict) -> str:
        """Generate a meaningful title for the location"""
        name = tags.get('name', '')
        if name:
            return f"Abandoned {name}"
        
        building_type = tags.get('building', tags.get('disused:building', ''))
        if building_type and building_type != 'yes':
            return f"Abandoned {building_type.replace('_', ' ').title()}"
        
        historic = tags.get('historic', '')
        if historic:
            return f"{historic.replace('_', ' ').title()}"
        
        return "Abandoned Building"

    def generate_description(self, tags: Dict) -> str:
        """Generate description based on available tags"""
        description_parts = []
        
        # Building type
        building_type = tags.get('building', tags.get('disused:building', ''))
        if building_type and building_type != 'yes':
            description_parts.append(f"Building type: {building_type.replace('_', ' ').title()}")
        
        # Historical significance
        if 'historic' in tags:
            description_parts.append(f"Historic site: {tags['historic'].replace('_', ' ').title()}")
        
        # Condition
        if 'abandoned' in tags:
            description_parts.append("Status: Abandoned")
        elif 'disused:building' in tags:
            description_parts.append("Status: Disused")
        elif tags.get('building') == 'ruins':
            description_parts.append("Status: Ruins")
        
        # Additional info
        if 'start_date' in tags:
            description_parts.append(f"Built: {tags['start_date']}")
        if 'end_date' in tags:
            description_parts.append(f"Abandoned: {tags['end_date']}")
        
        return ". ".join(description_parts) if description_parts else "Abandoned building discovered via OpenStreetMap data."

    def get_address(self, lat: float, lon: float) -> str:
        """Get human-readable address using reverse geocoding"""
        # In fast mode, skip reverse geocoding to dramatically speed up bulk operations
        if self.fast_mode:
            return f"{lat:.6f}, {lon:.6f}"
            
        try:
            # Much faster rate limiting (0.1 seconds instead of 1 second)
            # Nominatim can handle this rate for reasonable volumes
            time.sleep(0.1)  
            location = self.geolocator.reverse((lat, lon), timeout=5)  # Shorter timeout too
            return location.address if location else f"{lat:.6f}, {lon:.6f}"
        except (GeocoderTimedOut, GeocoderServiceError) as e:
            # Don't log every geocoding failure to reduce noise
            return f"{lat:.6f}, {lon:.6f}"
        except Exception as e:
            return f"{lat:.6f}, {lon:.6f}"

    def save_to_database(self, locations: List[Dict]):
        """Save scraped locations to MySQL database"""
        logger.info(f"Saving {len(locations)} locations to database...")
        
        saved_count = 0
        skipped_count = 0
        
        for location in tqdm(locations, desc="Saving to database"):
            try:
                # Check if location already exists
                self.cursor.execute(
                    "SELECT id FROM locations WHERE osm_id = %s",
                    (location['osm_id'],)
                )
                
                if self.cursor.fetchone():
                    skipped_count += 1
                    continue
                
                # Insert location
                insert_query = """
                INSERT INTO locations 
                (osm_id, osm_type, title, description, latitude, longitude, address, 
                 category_id, danger_level_id, building_type, original_tags)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """
                
                values = (
                    location['osm_id'],
                    location['osm_type'],
                    location['title'],
                    location['description'],
                    location['latitude'],
                    location['longitude'],
                    location['address'],
                    location['category_id'],
                    location['danger_level_id'],
                    location['building_type'],
                    location['original_tags']
                )
                
                self.cursor.execute(insert_query, values)
                saved_count += 1
                
            except Error as e:
                logger.error(f"Error saving location {location['osm_id']}: {e}")
                continue
        
        self.connection.commit()
        logger.info(f"Saved {saved_count} new locations, skipped {skipped_count} existing")

    def scrape_by_bbox(self, south: float, west: float, north: float, east: float):
        """Scrape abandoned buildings within a bounding box"""
        logger.info(f"Scraping bounding box: {south}, {west}, {north}, {east}")
        
        query = self.build_overpass_query(bbox=(south, west, north, east))
        locations = self.execute_query(query)
        
        if locations:
            self.save_to_database(locations)
        
        time.sleep(self.request_delay)

    def scrape_by_city(self, city_name: str):
        """Scrape abandoned buildings in a specific city"""
        logger.info(f"Scraping city: {city_name}")
        
        query = self.build_overpass_query(area_name=city_name)
        locations = self.execute_query(query)
        
        if locations:
            self.save_to_database(locations)
        
        time.sleep(self.request_delay)

    def scrape_by_country(self, country_name: str):
        """Scrape abandoned buildings in an entire country"""
        country_key = country_name.lower()
        
        # Special handling for Bulgaria - use city-by-city approach
        if country_key == 'bulgaria':
            self.scrape_bulgaria_cities()
            return
        
        # For other countries, use bounding box approach
        if country_key not in COUNTRY_BOUNDING_BOXES:
            available_countries = list(COUNTRY_BOUNDING_BOXES.keys())
            logger.error(f"Country '{country_name}' not available. Available countries: {available_countries}")
            return
        
        bbox = COUNTRY_BOUNDING_BOXES[country_key]
        logger.info(f"Scraping entire country: {country_name}")
        logger.info(f"Using bounding box: {bbox} (covers {country_name})")
        
        # For large areas like entire countries, we might want to increase the timeout
        original_delay = self.request_delay
        self.request_delay = max(self.request_delay, 3.0)  # At least 3 seconds for country queries
        
        try:
            query = self.build_overpass_query(bbox=bbox)
            locations = self.execute_query(query)
            
            if locations:
                self.save_to_database(locations)
                logger.info(f"✅ Successfully scraped {len(locations)} locations from {country_name}")
            else:
                logger.warning(f"No abandoned buildings found in {country_name}")
        except Exception as e:
            logger.error(f"Error scraping {country_name}: {e}")
        finally:
            # Restore original delay
            self.request_delay = original_delay
        
        time.sleep(5)  # Extra delay after country-wide scraping

    def scrape_bulgaria_cities(self):
        """Scrape abandoned buildings in Bulgaria using city-by-city approach"""
        logger.info("🇧🇬 Starting comprehensive Bulgaria scraping (city-by-city)")
        logger.info(f"📍 Will scrape {len(BULGARIAN_CITIES)} Bulgarian cities/towns")
        
        total_locations = 0
        successful_cities = 0
        failed_cities = 0
        
        start_time = time.time()
        
        for i, city in enumerate(BULGARIAN_CITIES, 1):
            try:
                logger.info(f"📍 [{i}/{len(BULGARIAN_CITIES)}] Scraping {city}...")
                
                # Get count before scraping this city
                self.cursor.execute("SELECT COUNT(*) FROM locations")
                count_before = self.cursor.fetchone()[0]
                
                # Scrape the city
                query = self.build_overpass_query(area_name=city)
                locations = self.execute_query(query)
                
                if locations:
                    self.save_to_database(locations)
                    
                    # Get count after scraping
                    self.cursor.execute("SELECT COUNT(*) FROM locations")
                    count_after = self.cursor.fetchone()[0]
                    
                    new_locations = count_after - count_before
                    total_locations += new_locations
                    successful_cities += 1
                    
                    if new_locations > 0:
                        logger.info(f"✅ {city}: Found {new_locations} new locations (Total: {count_after})")
                    else:
                        logger.info(f"ℹ️  {city}: No new locations found")
                else:
                    logger.info(f"ℹ️  {city}: No abandoned buildings found")
                    successful_cities += 1
                
                # Progress update every 10 cities
                if i % 10 == 0:
                    elapsed = time.time() - start_time
                    avg_time_per_city = elapsed / i
                    estimated_remaining = (len(BULGARIAN_CITIES) - i) * avg_time_per_city
                    
                    logger.info(f"📊 Progress: {i}/{len(BULGARIAN_CITIES)} cities completed")
                    logger.info(f"⏱️  Estimated time remaining: {estimated_remaining/60:.1f} minutes")
                    logger.info(f"📈 Total locations found so far: {total_locations}")
                
                # Small delay between cities
                time.sleep(self.request_delay)
                
            except Exception as e:
                failed_cities += 1
                logger.error(f"❌ Error scraping {city}: {e}")
                continue
        
        # Final statistics
        elapsed_total = time.time() - start_time
        
        # Get final database statistics
        self.cursor.execute("SELECT COUNT(*) FROM locations")
        final_total = self.cursor.fetchone()[0]
        
        logger.info("🎉 " + "="*60)
        logger.info("✅ BULGARIA SCRAPING COMPLETED!")
        logger.info("="*64)
        logger.info(f"⏱️  Total time: {elapsed_total/60:.1f} minutes")
        logger.info(f"📍 Cities processed: {successful_cities} successful, {failed_cities} failed")
        logger.info(f"📊 New locations found: {total_locations}")
        logger.info(f"💾 Total locations in database: {final_total}")
        
        # Category breakdown
        self.cursor.execute("""
            SELECT c.name, COUNT(*) as count 
            FROM locations l 
            JOIN categories c ON l.category_id = c.id 
            GROUP BY c.name 
            ORDER BY count DESC
        """)
        categories = self.cursor.fetchall()
        
        logger.info("📈 Breakdown by category:")
        for category_name, count in categories:
            logger.info(f"   🏗️  {category_name}: {count}")
        
        time.sleep(2)  # Brief pause after completion

    def close(self):
        """Close database connections"""
        if hasattr(self, 'cursor'):
            self.cursor.close()
        if hasattr(self, 'connection'):
            self.connection.close()
        logger.info("Database connections closed")


def main():
    """Main function to run the scraper"""
    scraper = OverpassScraper()
    
    try:
        logger.info("Starting abandoned buildings scraping...")
        
        # Scrape target cities
        for city in TARGET_CITIES:
            try:
                logger.info(f"Scraping {city}...")
                scraper.scrape_by_city(city)
                time.sleep(5)  # Longer delay between cities
            except Exception as e:
                logger.error(f"Error scraping {city}: {e}")
                continue
        
        # Example: scrape specific bounding boxes
        # for name, bbox in BOUNDING_BOXES.items():
        #     logger.info(f"Scraping bounding box: {name}")
        #     scraper.scrape_by_bbox(*bbox)
        #     time.sleep(5)
        
        logger.info("Scraping completed successfully!")
        
    except KeyboardInterrupt:
        logger.info("Scraping interrupted by user")
    except Exception as e:
        logger.error(f"Scraping failed: {e}")
    finally:
        scraper.close()


if __name__ == "__main__":
    main() 