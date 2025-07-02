#!/usr/bin/env python3
"""
Example usage scripts for the Overpass Scraper
Demonstrates different ways to scrape abandoned buildings
"""

import sys
import time
from overpass_scraper import OverpassScraper
from config import TARGET_CITIES, BOUNDING_BOXES, COUNTRY_BOUNDING_BOXES

def scrape_single_city():
    """Example: Scrape a single city"""
    print("🏙️ Scraping a single city...")
    
    scraper = OverpassScraper()
    try:
        # Scrape Detroit for abandoned buildings
        scraper.scrape_by_city("Detroit, Michigan, USA")
        print("✅ Detroit scraping completed!")
        
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        scraper.close()

def scrape_multiple_cities():
    """Example: Scrape multiple cities from config"""
    print("🌍 Scraping multiple cities...")
    
    scraper = OverpassScraper()
    try:
        # Use first 3 cities from config to avoid long runtime
        cities_subset = TARGET_CITIES[:3]
        
        for city in cities_subset:
            print(f"📍 Scraping {city}...")
            scraper.scrape_by_city(city)
            time.sleep(3)  # Be respectful to the API
            
        print("✅ Multiple cities scraping completed!")
        
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        scraper.close()

def scrape_bounding_box():
    """Example: Scrape using geographic bounding box"""
    print("📦 Scraping with bounding box...")
    
    scraper = OverpassScraper()
    try:
        # Detroit metro area bounding box
        detroit_bbox = BOUNDING_BOXES['detroit_metro']
        print(f"📍 Scraping Detroit metro area: {detroit_bbox}")
        
        scraper.scrape_by_bbox(*detroit_bbox)
        print("✅ Bounding box scraping completed!")
        
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        scraper.close()

def scrape_bulgaria():
    """Example: Scrape all abandoned buildings in Bulgaria"""
    print("🇧🇬 Scraping entire Bulgaria...")
    
    scraper = OverpassScraper()
    try:
        print("🏙️  Method: City-by-city coverage (110+ Bulgarian cities)")
        print("📍 This will systematically scrape ALL Bulgarian cities")
        print("⚠️  This will take 15-25 minutes with real-time progress")
        print("📈 Progress updates every 10 cities")
        print()
        
        scraper.scrape_by_country("Bulgaria")
        print("✅ Bulgaria scraping completed!")
        
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        scraper.close()

def custom_query_example():
    """Example: Run a custom Overpass QL query"""
    print("🔧 Running custom query...")
    
    scraper = OverpassScraper()
    try:
        # Custom query for abandoned buildings in a specific area
        custom_query = '''
        [out:json][timeout:300];
        (
          // Abandoned buildings in Detroit area
          way["building"="abandoned"](42.2, -83.3, 42.5, -82.9);
          relation["building"="abandoned"](42.2, -83.3, 42.5, -82.9);
          node["building"="abandoned"](42.2, -83.3, 42.5, -82.9);
          
          // Historic ruins in the same area  
          way["historic"="ruins"](42.2, -83.3, 42.5, -82.9);
          relation["historic"="ruins"](42.2, -83.3, 42.5, -82.9);
          node["historic"="ruins"](42.2, -83.3, 42.5, -82.9);
        );
        out geom;
        '''
        
        print("🔍 Executing custom Overpass query...")
        locations = scraper.execute_query(custom_query)
        
        if locations:
            print(f"📊 Found {len(locations)} locations")
            scraper.save_to_database(locations)
            print("✅ Custom query completed!")
        else:
            print("ℹ️ No locations found with custom query")
            
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        scraper.close()

def test_database_connection():
    """Example: Test database connection and show stats"""
    print("🔗 Testing database connection...")
    
    try:
        scraper = OverpassScraper()
        
        # Query some basic stats
        scraper.cursor.execute("SELECT COUNT(*) as total FROM locations")
        total = scraper.cursor.fetchone()[0]
        
        scraper.cursor.execute("""
            SELECT c.name, COUNT(*) as count 
            FROM locations l 
            JOIN categories c ON l.category_id = c.id 
            GROUP BY c.name
        """)
        categories = scraper.cursor.fetchall()
        
        print("📊 Database Statistics:")
        print(f"   Total locations: {total}")
        print("   By category:")
        for cat_name, count in categories:
            print(f"     - {cat_name}: {count}")
            
        scraper.close()
        print("✅ Database connection test completed!")
        
    except Exception as e:
        print(f"❌ Database error: {e}")

def main():
    """Main function with interactive menu"""
    print("🏗️ Overpass Scraper Examples")
    print("=" * 40)
    
    options = {
        '1': ('Test database connection', test_database_connection),
        '2': ('Scrape single city (Detroit)', scrape_single_city),
        '3': ('Scrape multiple cities (first 3 from config)', scrape_multiple_cities),
        '4': ('Scrape bounding box (Detroit metro)', scrape_bounding_box),
        '5': ('🇧🇬 Scrape entire Bulgaria', scrape_bulgaria),
        '6': ('Run custom query', custom_query_example),
        '7': ('Exit', sys.exit)
    }
    
    while True:
        print("\nChoose an option:")
        for key, (description, _) in options.items():
            print(f"  {key}. {description}")
        
        choice = input("\nEnter your choice (1-7): ").strip()
        
        if choice in options:
            if choice == '7':
                print("👋 Goodbye!")
                break
            
            print(f"\n🚀 Running: {options[choice][0]}")
            print("-" * 40)
            
            try:
                options[choice][1]()
            except KeyboardInterrupt:
                print("\n⏹️ Operation cancelled by user")
            except Exception as e:
                print(f"\n❌ Unexpected error: {e}")
                
            input("\nPress Enter to continue...")
        else:
            print("❌ Invalid choice. Please try again.")

if __name__ == "__main__":
    main() 