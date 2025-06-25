# Sequence Diagrams - Abandoned Buildings App

This document contains sequence diagrams for the key user flows in the Abandoned Buildings Exploration mobile application.

## 1. User Authentication Flow

### User Registration

```mermaid
sequenceDiagram
    participant U as User
    participant A as iOS App
    participant API as Backend API
    participant DB as Database
    
    U->>A: Enter registration details
    A->>A: Validate input locally
    
    alt Valid input
        A->>API: POST /api/auth/register
        Note over A,API: {username, email, password, age}
        
        API->>API: Validate request data
        API->>API: Hash password (bcrypt)
        
        alt Valid data & unique user
            API->>DB: INSERT INTO users
            DB-->>API: User created with ID
            API->>API: Generate JWT token
            API-->>A: 201 Created + {token, user}
            A->>A: Store token in UserDefaults
            A->>A: Update DataManager state
            A-->>U: Show success & navigate to main app
        else User exists or invalid data
            API-->>A: 400 Bad Request + error
            A-->>U: Show error message
        end
    else Invalid input
        A-->>U: Show validation errors
    end
```

### User Login

```mermaid
sequenceDiagram
    participant U as User
    participant A as iOS App
    participant API as Backend API
    participant DB as Database
    
    U->>A: Enter login credentials
    A->>API: POST /api/auth/login
    Note over A,API: {username/email, password}
    
    API->>DB: SELECT user by username/email
    DB-->>API: User data or null
    
    alt User exists
        API->>API: Compare password hash
        alt Password valid
            API->>API: Generate JWT token
            API-->>A: 200 OK + {token, user}
            A->>A: Store token in UserDefaults
            A->>A: Update DataManager.currentUser
            A->>A: Check admin status
            A-->>U: Navigate to main app
        else Invalid password
            API-->>A: 401 Unauthorized
            A-->>U: Show "Invalid credentials"
        end
    else User not found
        API-->>A: 401 Unauthorized
        A-->>U: Show "Invalid credentials"
    end
```

## 2. Location Discovery Flow

### Loading Feed Locations

```mermaid
sequenceDiagram
    participant U as User
    participant FV as FeedView
    participant DM as DataManager
    participant API as APIService
    participant BE as Backend API
    participant DB as Database
    participant IC as ImageCache
    
    U->>FV: Open Feed tab
    FV->>DM: loadFeedLocations()
    
    alt Not loading and authenticated
        DM->>API: getFeedLocations()
        API->>BE: GET /api/locations/feed
        Note over API,BE: Authorization: Bearer {token}
        
        BE->>BE: Extract user ID from token
        BE->>DB: Complex query with likes/bookmarks check
        Note over BE,DB: JOIN locations, categories, danger_levels<br/>CHECK likes/bookmarks for current user
        
        DB-->>BE: Location data with user interactions
        BE->>DB: SELECT images for each location
        DB-->>BE: Image URLs
        BE-->>API: 200 OK + {locations, has_more}
        
        API->>API: Decode AbandonedLocation objects
        API-->>DM: LocationsResponse
        
        DM->>DM: Update locations array
        DM->>IC: preloadImages(for: locations)
        
        loop For each image URL
            IC->>IC: Download and cache image
        end
        
        DM-->>FV: Locations updated
        FV->>FV: Refresh UI with new data
        FV-->>U: Display feed with images
    else Already loading or not authenticated
        DM-->>FV: No action taken
    end
```

### Loading Nearby Locations (Map)

```mermaid
sequenceDiagram
    participant U as User
    participant MV as MapView
    participant LM as LocationManager
    participant DM as DataManager
    participant API as APIService
    participant BE as Backend API
    participant DB as Database
    
    U->>MV: Open Map tab
    MV->>LM: Request location permission
    LM-->>MV: Location updated
    
    MV->>DM: loadNearbyLocations(lat, lng)
    DM->>API: getNearbyLocations(lat, lng, radius)
    API->>BE: GET /api/locations/nearby
    Note over API,BE: ?latitude=X&longitude=Y&radius=Z
    
    BE->>DB: ST_Distance_Sphere query
    Note over BE,DB: SELECT * FROM locations<br/>WHERE ST_Distance_Sphere(...) <= radius<br/>AND is_approved = TRUE
    
    DB-->>BE: Nearby locations
    BE-->>API: 200 OK + locations
    API-->>DM: LocationsResponse
    
    DM->>DM: Filter approved locations
    DM-->>MV: Updated locations
    
    MV->>MV: Update map annotations
    MV-->>U: Show locations on map
```

## 3. Location Interaction Flow

### Like/Unlike Location

```mermaid
sequenceDiagram
    participant U as User
    participant DV as LocationDetailView
    participant DM as DataManager
    participant API as APIService
    participant BE as Backend API
    participant DB as Database
    
    U->>DV: Tap like button
    DV->>DV: Optimistic UI update
    Note over DV: isLiked = !isLiked<br/>likeCount += isLiked ? 1 : -1
    
    DV->>DM: toggleLike(locationId)
    DM->>API: likeLocation(locationId)
    API->>BE: POST /api/locations/{id}/like
    Note over API,BE: Authorization: Bearer {token}
    
    BE->>BE: Extract user ID from token
    BE->>DB: SELECT existing like
    DB-->>BE: Like record or null
    
    alt Like exists (unlike)
        BE->>DB: DELETE FROM likes
        BE->>DB: UPDATE locations SET likes_count = likes_count - 1
        DB-->>BE: Success
        BE-->>API: {isLiked: false, likeCount: newCount}
    else Like doesn't exist (like)
        BE->>DB: INSERT INTO likes
        BE->>DB: UPDATE locations SET likes_count = likes_count + 1
        DB-->>BE: Success
        BE-->>API: {isLiked: true, likeCount: newCount}
    end
    
    API-->>DM: LikeResponse
    DM->>DM: Update location in locations array
    DM-->>DV: State updated via syncWithDataManager()
    
    alt API call failed
        DV->>DV: Revert optimistic update
        DV-->>U: Show error state
    else Success
        DV-->>U: Confirmed state with animation
    end
```

### Bookmark/Unbookmark Location

```mermaid
sequenceDiagram
    participant U as User
    participant DV as LocationDetailView
    participant DM as DataManager
    participant API as APIService
    participant BE as Backend API
    participant DB as Database
    
    U->>DV: Tap bookmark button
    DV->>DV: Optimistic UI update
    Note over DV: isBookmarked = !isBookmarked<br/>bookmarkCount += isBookmarked ? 1 : -1
    
    DV->>DM: toggleBookmark(locationId)
    DM->>API: bookmarkLocation(locationId)
    API->>BE: POST /api/locations/{id}/bookmark
    
    BE->>DB: Check existing bookmark
    
    alt Bookmark exists (remove)
        BE->>DB: DELETE FROM bookmarks
        BE->>DB: UPDATE locations SET bookmarks_count = bookmarks_count - 1
        BE-->>API: {isBookmarked: false, bookmarkCount: newCount}
        API-->>DM: BookmarkResponse
        DM->>DM: Remove from userBookmarks array
    else Bookmark doesn't exist (add)
        BE->>DB: INSERT INTO bookmarks
        BE->>DB: UPDATE locations SET bookmarks_count = bookmarks_count + 1
        BE-->>API: {isBookmarked: true, bookmarkCount: newCount}
        API-->>DM: BookmarkResponse
        DM->>DM: Refresh userBookmarks
    end
    
    DM->>DM: Update location in locations array
    DM-->>DV: State synced
    DV-->>U: Updated UI state
```

## 4. Location Submission Flow

### Submit New Location

```mermaid
sequenceDiagram
    participant U as User
    participant SV as SubmitLocationView
    participant DM as DataManager
    participant API as APIService
    participant BE as Backend API
    participant DB as Database
    participant FS as File System
    
    U->>SV: Fill location form + select images
    U->>SV: Tap Submit
    
    SV->>SV: Validate form data
    
    alt Valid form
        SV->>SV: Show loading state
        SV->>DM: submitLocation(data, images)
        
        DM->>API: submitLocation(locationData)
        API->>BE: POST /api/locations/submit
        Note over API,BE: {title, description, latitude, longitude,<br/>address, category, dangerLevel, tags}
        
        BE->>BE: Validate location data
        BE->>DB: INSERT INTO locations (is_approved = FALSE)
        DB-->>BE: New location ID
        
        alt Images provided
            BE-->>API: {locationId, success: true}
            API->>DM: LocationSubmissionResponse
            
            DM->>API: uploadImages(locationId, images)
            API->>BE: POST /api/upload/images (multipart)
            Note over API,BE: Multipart form with image files
            
            BE->>FS: Save images to local storage
            FS-->>BE: File paths
            
            loop For each uploaded image
                BE->>DB: INSERT INTO location_images
            end
            
            BE-->>API: {imageUrls: [...]}
            API-->>DM: ImageUploadResponse
        else No images
            BE-->>API: {locationId, success: true}
            API-->>DM: LocationSubmissionResponse
        end
        
        DM->>DM: Refresh user submissions
        DM-->>SV: Submission complete
        
        SV->>SV: Reset form
        SV-->>U: Show success message + navigate back
        
    else Invalid form
        SV-->>U: Show validation errors
    end
```

## 5. Admin Operations Flow

### Admin Approve/Reject Location

```mermaid
sequenceDiagram
    participant A as Admin User
    participant APV as AdminPanelView
    participant DM as DataManager
    participant API as APIService
    participant BE as Backend API
    participant DB as Database
    
    A->>APV: Open Admin Panel
    APV->>DM: loadPendingLocations()
    DM->>API: getPendingLocations()
    API->>BE: GET /api/admin/pending-locations
    Note over API,BE: Authorization: Bearer {admin_token}
    
    BE->>BE: Verify admin status
    BE->>DB: SELECT admin user check
    
    alt User is admin
        BE->>DB: SELECT pending locations (is_approved = FALSE)
        DB-->>BE: Pending locations with full data
        BE-->>API: {locations: [...]}
        API-->>DM: LocationsResponse
        DM-->>APV: Update pending locations
        APV-->>A: Show pending locations list
        
        A->>APV: Tap Approve on location
        APV->>DM: approveLocation(locationId)
        DM->>API: approveLocation(locationId)
        API->>BE: POST /api/admin/locations/{id}/approve
        
        BE->>DB: UPDATE locations SET is_approved = TRUE
        DB-->>BE: Success
        BE-->>API: {success: true, message: "Location approved"}
        API-->>DM: AdminActionResponse
        
        DM->>DM: Remove from pendingLocations
        DM->>DM: Add to main locations (if in feed range)
        DM-->>APV: Refresh pending list
        APV-->>A: Updated list without approved location
        
    else User not admin
        BE-->>API: 403 Forbidden
        API-->>DM: Error
        DM-->>APV: Show error
        APV-->>A: "Access denied"
    end
```

## 6. Profile and Bookmarks Flow

### Load User Profile Data

```mermaid
sequenceDiagram
    participant U as User
    participant PV as ProfileView
    participant DM as DataManager
    participant API as APIService
    participant BE as Backend API
    participant DB as Database
    participant IC as ImageCache
    
    U->>PV: Open Profile tab
    PV->>DM: loadCurrentUser()
    PV->>DM: loadUserSubmissions()
    PV->>DM: loadUserBookmarks()
    
    par Load User Profile
        DM->>API: getCurrentUser()
        API->>BE: GET /api/users/profile
        BE->>DB: Complex user stats query
        Note over BE,DB: JOIN users with counts of<br/>submissions, bookmarks, likes
        DB-->>BE: User data with statistics
        BE-->>API: {user: {...}}
        API-->>DM: User object
        DM->>DM: Update currentUser
    
    and Load User Submissions
        DM->>API: getUserSubmissions()
        API->>BE: GET /api/users/submissions
        BE->>DB: SELECT user's submitted locations
        BE->>DB: SELECT images for each location
        DB-->>BE: Submissions with images
        BE-->>API: {submissions: [...]}
        API-->>DM: LocationsResponse
        DM->>DM: Update userSubmissions
        DM->>IC: preloadImages(submissions)
    
    and Load User Bookmarks
        DM->>API: getUserBookmarks()
        API->>BE: GET /api/users/bookmarks
        BE->>DB: SELECT bookmarked locations with user context
        Note over BE,DB: JOIN bookmarks with locations<br/>CHECK is_liked for current user
        BE->>DB: SELECT images for each location
        DB-->>BE: Bookmarks with full location data
        BE-->>API: {bookmarks: [...]}
        API-->>DM: LocationsResponse  
        DM->>DM: Update userBookmarks
        DM->>IC: preloadImages(bookmarks)
    end
    
    DM-->>PV: All data loaded
    PV-->>U: Display complete profile
```

## 7. Error Handling Patterns

### Network Error Recovery

```mermaid
sequenceDiagram
    participant U as User
    participant V as Any View
    participant DM as DataManager
    participant API as APIService
    participant BE as Backend API
    
    V->>DM: Request data
    DM->>API: API call
    API->>BE: HTTP Request
    
    alt Network timeout/error
        BE-->>API: Network Error
        API->>API: Retry logic (exponential backoff)
        
        alt Retry successful
            API->>BE: Retry request
            BE-->>API: Success response
            API-->>DM: Data
            DM-->>V: Update UI
        else All retries failed
            API-->>DM: APIError
            DM->>DM: Set errorMessage
            DM-->>V: Error state
            V-->>U: Show error message + retry button
            
            U->>V: Tap retry
            V->>DM: Retry original request
        end
    
    else Server error (500)
        BE-->>API: 500 Internal Server Error
        API-->>DM: Server error
        DM-->>V: Error state
        V-->>U: "Server temporarily unavailable"
    
    else Authentication error (401)
        BE-->>API: 401 Unauthorized
        API->>API: Clear stored token
        API-->>DM: Auth error
        DM->>DM: Reset to unauthenticated state
        DM-->>V: Redirect to login
        V-->>U: Show login screen
    end
```

## Key Design Patterns

### 1. Optimistic UI Updates
- User interactions (like/bookmark) update UI immediately
- API call happens in background
- Revert changes if API call fails

### 2. Data Synchronization
- DataManager maintains single source of truth
- Views observe DataManager published properties
- API responses update DataManager state

### 3. Image Caching
- Images are cached locally using ImageCache
- Preloading happens when data is fetched
- CachedAsyncImage provides instant display

### 4. Error Propagation
- API errors bubble up through DataManager
- Views observe errorMessage for user feedback
- Retry mechanisms for transient failures

### 5. Admin Security
- JWT tokens contain user role information
- Admin endpoints verify user permissions
- Client-side admin features hidden for non-admins
