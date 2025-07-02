#!/usr/bin/env python3
"""
Dedicated script for scraping all abandoned buildings in Bulgaria
This script will systematically collect abandoned buildings across the entire country.
"""

import sys
import time
import logging
from datetime import datetime
from overpass_scraper import OverpassScraper

def main():
    """Main function to scrape all of Bulgaria"""
    
    print("🇧🇬 " + "="*60)
    print("🏚️  BULGARIA ABANDONED BUILDINGS SCRAPER")
    print("="*64)
    print()
    print("This script will scrape ALL abandoned buildings in Bulgaria.")
    print("🏙️  Method: City-by-city systematic coverage (110+ Bulgarian cities)")
    print("⚠️  WARNING: This comprehensive scan will take 15-25 minutes")
    print("📊 Expected results: 500-2000+ locations (depending on OSM data)")
    print("📈 Progress: Real-time updates every 10 cities")
    print("💾 All data will be saved to 'scraped-overpass-turbo' database")
    print()
    
    # Ask for confirmation
    response = input("Do you want to proceed? (y/N): ").strip().lower()
    if response not in ['y', 'yes']:
        print("Operation cancelled.")
        return
    
    # Set up logging for this run
    log_filename = f"bulgaria_scrape_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_filename),
            logging.StreamHandler()
        ]
    )
    
    logger = logging.getLogger(__name__)
    
    print(f"📝 Logging to: {log_filename}")
    print("🚀 Starting Bulgaria scraping...")
    print()
    
    start_time = datetime.now()
    
    scraper = OverpassScraper()
    try:
        # Scrape the entire country of Bulgaria
        scraper.scrape_by_country("Bulgaria")
        
        end_time = datetime.now()
        duration = end_time - start_time
        
        # Get final statistics
        scraper.cursor.execute("SELECT COUNT(*) FROM locations")
        total_locations = scraper.cursor.fetchone()[0]
        
        scraper.cursor.execute("""
            SELECT c.name, COUNT(*) as count 
            FROM locations l 
            JOIN categories c ON l.category_id = c.id 
            GROUP BY c.name 
            ORDER BY count DESC
        """)
        categories = scraper.cursor.fetchall()
        
        print()
        print("🎉 " + "="*50)
        print("✅ BULGARIA SCRAPING COMPLETED!")
        print("="*54)
        print(f"⏱️  Duration: {duration}")
        print(f"📊 Total locations in database: {total_locations}")
        print()
        print("📈 Breakdown by category:")
        for category_name, count in categories:
            print(f"   🏗️  {category_name}: {count}")
        
        print()
        print(f"📝 Detailed log saved to: {log_filename}")
        print("💾 Data saved to MySQL database: scraped-overpass-turbo")
        print()
        print("🔍 You can now:")
        print("   • Query the database for analysis")
        print("   • Export data to other formats")
        print("   • Integrate with mapping applications")
        print("   • Run additional country scraping")
        
    except KeyboardInterrupt:
        print("\n⏹️  Scraping interrupted by user")
        logger.info("Bulgaria scraping interrupted by user")
    except Exception as e:
        print(f"\n❌ Error during scraping: {e}")
        logger.error(f"Bulgaria scraping failed: {e}")
    finally:
        scraper.close()
        print("\n👋 Database connections closed")

if __name__ == "__main__":
    main() 