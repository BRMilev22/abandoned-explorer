#!/bin/bash

echo "🏗️ Setting up Overpass Scraper for Abandoned Buildings"
echo "======================================================="

# Create virtual environment
echo "📦 Creating virtual environment..."
python3 -m venv venv

# Activate virtual environment
echo "🔌 Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "⬇️ Installing Python dependencies..."
pip install -r requirements.txt

# Test installation
echo "🧪 Testing installation..."
python3 -c "from overpass_scraper import OverpassScraper; print('✅ Installation successful!')"

echo ""
echo "🎉 Setup complete! Here's how to use the scraper:"
echo ""
echo "1. Activate the virtual environment:"
echo "   source venv/bin/activate"
echo ""
echo "2. Configure your database in config.py"
echo ""
echo "3. Run the scraper:"
echo "   python3 overpass_scraper.py        # Full scraping"
echo "   python3 run_examples.py            # Interactive examples"
echo ""
echo "🇧🇬 Bulgarian cities have been added to the target list!"
echo ""
echo "Happy scraping! 🏚️✨" 