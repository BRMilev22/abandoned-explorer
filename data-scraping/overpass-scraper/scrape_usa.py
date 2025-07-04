#!/usr/bin/env python3
"""
Dedicated script for scraping abandoned buildings in the USA
This script will systematically collect abandoned buildings across all states,
processing cities in small batches to avoid API overload.
"""

import sys
import time
import logging
from datetime import datetime
import json
from typing import List, Dict
from overpass_scraper import OverpassScraper

# US States and their major cities (limited to top cities per state to avoid API overload)
US_STATES = {
    "Alabama": ["Birmingham", "Montgomery", "Huntsville", "Mobile"],
    "Alaska": ["Anchorage", "Fairbanks", "Juneau"],
    "Arizona": ["Phoenix", "Tucson", "Mesa", "Chandler"],
    "Arkansas": ["Little Rock", "Fort Smith", "Fayetteville"],
    "California": ["Los Angeles", "San Francisco", "San Diego", "Sacramento"],
    "Colorado": ["Denver", "Colorado Springs", "Aurora", "Fort Collins"],
    "Connecticut": ["Bridgeport", "New Haven", "Hartford", "Stamford"],
    "Delaware": ["Wilmington", "Dover", "Newark"],
    "Florida": ["Miami", "Orlando", "Tampa", "Jacksonville"],
    "Georgia": ["Atlanta", "Savannah", "Augusta", "Columbus"],
    "Hawaii": ["Honolulu", "Hilo", "Kailua"],
    "Idaho": ["Boise", "Nampa", "Meridian"],
    "Illinois": ["Chicago", "Aurora", "Rockford", "Joliet"],
    "Indiana": ["Indianapolis", "Fort Wayne", "Evansville"],
    "Iowa": ["Des Moines", "Cedar Rapids", "Davenport"],
    "Kansas": ["Wichita", "Overland Park", "Kansas City"],
    "Kentucky": ["Louisville", "Lexington", "Bowling Green"],
    "Louisiana": ["New Orleans", "Baton Rouge", "Shreveport"],
    "Maine": ["Portland", "Lewiston", "Bangor"],
    "Maryland": ["Baltimore", "Frederick", "Rockville"],
    "Massachusetts": ["Boston", "Worcester", "Springfield"],
    "Michigan": ["Detroit", "Grand Rapids", "Warren"],
    "Minnesota": ["Minneapolis", "Saint Paul", "Rochester"],
    "Mississippi": ["Jackson", "Gulfport", "Southaven"],
    "Missouri": ["Kansas City", "St. Louis", "Springfield"],
    "Montana": ["Billings", "Missoula", "Great Falls"],
    "Nebraska": ["Omaha", "Lincoln", "Bellevue"],
    "Nevada": ["Las Vegas", "Reno", "Henderson"],
    "New Hampshire": ["Manchester", "Nashua", "Concord"],
    "New Jersey": ["Newark", "Jersey City", "Paterson"],
    "New Mexico": ["Albuquerque", "Las Cruces", "Santa Fe"],
    "New York": ["New York City", "Buffalo", "Rochester"],
    "North Carolina": ["Charlotte", "Raleigh", "Greensboro"],
    "North Dakota": ["Fargo", "Bismarck", "Grand Forks"],
    "Ohio": ["Columbus", "Cleveland", "Cincinnati"],
    "Oklahoma": ["Oklahoma City", "Tulsa", "Norman"],
    "Oregon": ["Portland", "Salem", "Eugene"],
    "Pennsylvania": ["Philadelphia", "Pittsburgh", "Allentown"],
    "Rhode Island": ["Providence", "Warwick", "Cranston"],
    "South Carolina": ["Columbia", "Charleston", "North Charleston"],
    "South Dakota": ["Sioux Falls", "Rapid City", "Aberdeen"],
    "Tennessee": ["Nashville", "Memphis", "Knoxville"],
    "Texas": ["Houston", "Dallas", "Austin", "San Antonio"],
    "Utah": ["Salt Lake City", "West Valley City", "Provo"],
    "Vermont": ["Burlington", "South Burlington", "Rutland"],
    "Virginia": ["Virginia Beach", "Richmond", "Norfolk"],
    "Washington": ["Seattle", "Spokane", "Tacoma"],
    "West Virginia": ["Charleston", "Huntington", "Morgantown"],
    "Wisconsin": ["Milwaukee", "Madison", "Green Bay"],
    "Wyoming": ["Cheyenne", "Casper", "Laramie"]
}

def scrape_state(scraper: OverpassScraper, state: str, cities: List[str], batch_size: int = 2) -> Dict:
    """
    Scrape a single state's cities in small batches
    
    Args:
        scraper: OverpassScraper instance
        state: Name of the state
        cities: List of cities to scrape
        batch_size: Number of cities to process in each batch
    
    Returns:
        Dict with statistics about the scraping results
    """
    logger = logging.getLogger(__name__)
    logger.info(f"🗺️ Processing state: {state}")
    
    state_stats = {
        "total_locations": 0,
        "cities_processed": 0,
        "cities_failed": 0,
        "city_stats": {}
    }
    
    # Process cities in small batches
    for i in range(0, len(cities), batch_size):
        batch = cities[i:i + batch_size]
        logger.info(f"📍 Processing batch of {len(batch)} cities: {', '.join(batch)}")
        
        for city in batch:
            try:
                # Add state name for better geocoding accuracy
                full_city_name = f"{city}, {state}, USA"
                logger.info(f"🏙️ Scraping city: {full_city_name}")
                
                # Get initial location count
                scraper.cursor.execute("SELECT COUNT(*) FROM locations")
                initial_count = scraper.cursor.fetchone()[0]
                
                # Scrape the city
                scraper.scrape_by_city(full_city_name)
                
                # Get final count and calculate difference
                scraper.cursor.execute("SELECT COUNT(*) FROM locations")
                final_count = scraper.cursor.fetchone()[0]
                locations_found = final_count - initial_count
                
                # Update statistics
                state_stats["total_locations"] += locations_found
                state_stats["cities_processed"] += 1
                state_stats["city_stats"][city] = locations_found
                
                logger.info(f"✅ Found {locations_found} locations in {city}")
                
            except Exception as e:
                logger.error(f"❌ Error processing {city}: {str(e)}")
                state_stats["cities_failed"] += 1
                state_stats["city_stats"][city] = -1  # Mark as failed
            
            # Add delay between cities to avoid API rate limits
            time.sleep(5)  # 5 second delay between cities
        
        # Add longer delay between batches
        if i + batch_size < len(cities):
            logger.info("😴 Taking a break between batches...")
            time.sleep(15)  # 15 second delay between batches
    
    return state_stats

def main():
    """Main function to scrape all US states"""
    
    print("🇺🇸 " + "="*60)
    print("🏚️  USA ABANDONED BUILDINGS SCRAPER")
    print("="*64)
    print()
    print("This script will scrape abandoned buildings across all US states.")
    print("🏙️  Method: State-by-state, city-by-city coverage")
    print("⚡  Processing: Small batches to avoid API overload")
    print("⏱️  Time: Several hours (depends on data availability)")
    print("📊 Progress: Real-time updates for each city")
    print("💾 All data saved to 'scraped-overpass-turbo' database")
    print()
    
    # Ask for confirmation
    response = input("Do you want to proceed? (y/N): ").strip().lower()
    if response not in ['y', 'yes']:
        print("Operation cancelled.")
        return
    
    # Set up logging
    log_filename = f"usa_scrape_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
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
    
    # Optional: Allow user to specify states to scrape
    print("\nDo you want to scrape specific states or all states?")
    print("1. All states")
    print("2. Select specific states")
    choice = input("Enter choice (1/2): ").strip()
    
    states_to_scrape = {}
    if choice == "2":
        print("\nAvailable states:")
        for i, state in enumerate(US_STATES.keys(), 1):
            print(f"{i}. {state}")
        print("\nEnter state numbers separated by commas (e.g., 1,5,12)")
        selections = input("States to scrape: ").strip()
        try:
            indices = [int(x.strip()) for x in selections.split(",")]
            states_to_scrape = {list(US_STATES.keys())[i-1]: US_STATES[list(US_STATES.keys())[i-1]] 
                              for i in indices if 0 < i <= len(US_STATES)}
        except:
            print("Invalid input. Defaulting to all states.")
            states_to_scrape = US_STATES
    else:
        states_to_scrape = US_STATES
    
    print(f"\n🎯 Will scrape {len(states_to_scrape)} states")
    start_time = datetime.now()
    
    scraper = OverpassScraper()
    stats = {}
    
    try:
        # Process each state
        for state, cities in states_to_scrape.items():
            print(f"\n{'='*60}")
            print(f"📍 Starting {state}")
            print(f"🏙️ Cities to process: {len(cities)}")
            print(f"{'='*60}")
            
            stats[state] = scrape_state(scraper, state, cities)
            
            # Print state summary
            print(f"\n📊 {state} Summary:")
            print(f"   Total locations: {stats[state]['total_locations']}")
            print(f"   Cities processed: {stats[state]['cities_processed']}")
            print(f"   Cities failed: {stats[state]['cities_failed']}")
            
            # Save progress after each state
            with open(f"usa_scrape_progress_{datetime.now().strftime('%Y%m%d')}.json", 'w') as f:
                json.dump(stats, f, indent=2)
        
        # Final summary
        end_time = datetime.now()
        duration = end_time - start_time
        
        print("\n🎉 " + "="*50)
        print("✅ USA SCRAPING COMPLETED!")
        print("="*54)
        print(f"⏱️  Total duration: {duration}")
        
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
        
        print(f"📊 Total locations in database: {total_locations}")
        print("\n📈 Breakdown by category:")
        for category_name, count in categories:
            print(f"   🏗️  {category_name}: {count}")
        
        print(f"\n📝 Detailed log saved to: {log_filename}")
        print("📊 Progress saved to: usa_scrape_progress_*.json")
        print("💾 Data saved to MySQL database: scraped-overpass-turbo")
        
    except KeyboardInterrupt:
        print("\n⏹️  Scraping interrupted by user")
        logger.info("USA scraping interrupted by user")
    except Exception as e:
        print(f"\n❌ Error during scraping: {e}")
        logger.error(f"USA scraping failed: {e}")
    finally:
        scraper.close()
        print("\n👋 Database connections closed")

if __name__ == "__main__":
    main() 