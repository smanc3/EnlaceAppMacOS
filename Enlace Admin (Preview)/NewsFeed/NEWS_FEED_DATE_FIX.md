# News Feed Date Display Fix

## Issue
The news feed is displaying the current date/time for posts instead of the date they were created. This happens because:

1. In `NewsFeedPost` initialization, we fall back to the current date if no date fields are found in the record
2. When creating new posts in `createNewPost()`, we only set `datePosted` but not `datePublished` 
3. When publishing scheduled posts in `publishNow()`, we only update `datePosted` but not `datePublished`

## Solution

### 1. Fix `createNewPost()`
Change from:
```swift
newsPost["datePosted"] = Date()
```

To:
```swift
let creationDate = Date()
newsPost["datePosted"] = creationDate
newsPost["datePublished"] = creationDate
```

### 2. Fix `publishNow()`
Change from:
```swift
record["datePosted"] = Date()
```

To:
```swift
let publishDate = Date()
record["datePosted"] = publishDate
record["datePublished"] = publishDate
```

### 3. Fix existing records
Run a migration to add `datePublished` to any posts that only have `datePosted`:

```swift
private func fixExistingRecords() {
    for post in posts {
        let record = post.record
        if record["datePublished"] == nil && record["datePosted"] != nil {
            let postedDate = record["datePosted"] as! Date
            record["datePublished"] = postedDate
            database.save(record) { _, _ in }
        }
    }
}
```

Call this function after loading posts to fix existing data.

## How to validate the fix
After implementing these changes, newly created or published posts should display their actual creation/publication date rather than the current date when viewing them in the news feed. 