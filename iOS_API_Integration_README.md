# Abandoned Explorer iOS App - API Integration

This document describes the changes made to integrate the iOS app with the backend API, removing all static data.

## Changes Made

### 1. Created APIService Layer
- **File**: `Services/APIService.swift`
- **Purpose**: Handles all network communication with the backend API
- **Features**:
  - Authentication (login/register)
  - Location management (CRUD operations)
  - User management
  - Error handling with proper error types
  - Combines framework for reactive programming

### 2. Updated Models
- **Location.swift**: Updated to match API response structure
  - Changed `id` from `UUID()` to `String` (matches database UUID format)
  - Updated property names to match API (`likeCount`, `bookmarkCount`, etc.)
  - Added custom `CodingKeys` for JSON serialization
  - Added computed properties for backwards compatibility

- **User.swift**: Updated to match API response structure
  - Changed `id` from `UUID()` to `String`
  - Removed local arrays, replaced with counts from API
  - Added custom `CodingKeys` for JSON serialization

### 3. Completely Rewrote DataManager
- **File**: `Services/DataManager.swift`
- **Changes**:
  - Removed all static sample data
  - Integrated with APIService for all data operations
  - Added authentication state management
  - Added proper error handling and loading states
  - Added methods for:
    - User authentication (login/register/logout)
    - Loading locations (all, nearby, user submissions, bookmarks)
    - Submitting new locations
    - Toggling likes and bookmarks

### 4. Updated All Views

#### AuthenticationView
- Integrated with DataManager for real authentication
- Added proper form validation
- Added loading states and error handling
- Combined login and register flows

#### FeedView
- Added loading states
- Added pull-to-refresh functionality
- Updated to handle empty states
- Fixed property references for new model structure

#### MapView
- Added automatic nearby location loading based on user location
- Added loading indicators
- Fixed property references

#### SubmitLocationView
- Updated to use API for location submission
- Improved form validation
- Added proper error handling

#### ProfileView
- Removed mock data
- Added separate API calls for user submissions and bookmarks
- Added loading states for all sections
- Added authentication checks

#### MainTabView
- Updated to use injected DataManager instead of creating its own

### 5. Added New Views
- **SettingsView**: Complete settings interface with logout functionality

### 6. Added Configuration
- **APIConfiguration.swift**: Easy switching between development and production APIs

## API Endpoints Used

The app now uses the following API endpoints:

### Authentication
- `POST /auth/register` - User registration
- `POST /auth/login` - User login

### Locations
- `GET /locations` - Get all locations
- `GET /locations/nearby` - Get nearby locations
- `GET /locations/:id` - Get specific location
- `POST /locations` - Submit new location
- `POST /locations/:id/like` - Toggle like
- `POST /locations/:id/bookmark` - Toggle bookmark

### User
- `GET /users/profile` - Get current user profile
- `GET /users/bookmarks` - Get user bookmarks
- `GET /users/submissions` - Get user submissions

## Key Features

1. **Complete API Integration**: No more static data - everything comes from the database
2. **Authentication Flow**: Full login/register with JWT token management
3. **Real-time Data**: All user interactions (likes, bookmarks) are synced with the API
4. **Location Submission**: Users can submit new locations that go through approval process
5. **Responsive UI**: Loading states, error handling, and empty states for better UX
6. **Offline Handling**: Proper error messages when API is unavailable

## Running the Application

1. **Start the API Server**:
   ```bash
   cd api
   npm install
   npm start
   ```

2. **Configure Database**: Make sure your MySQL database is running and configured according to the schema

3. **Build and Run iOS App**: The app will automatically connect to `http://localhost:3000/api` in debug mode

## Next Steps

1. **Image Upload**: Implement image upload functionality for location photos
2. **Push Notifications**: Add notifications for location approvals
3. **Caching**: Add local caching for better offline experience
4. **Error Recovery**: Add automatic retry mechanisms for failed requests
5. **Performance**: Add pagination for large data sets

## Development Notes

- The app uses Combine framework for reactive programming
- All network requests are properly typed with Codable
- Date handling uses ISO8601 format for consistency with the API
- Error handling provides user-friendly messages
- The app gracefully handles authentication state changes
