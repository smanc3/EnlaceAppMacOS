# News Feed Date Fix

## Summary of the Issue
Posts in the news feed are showing the current date/time instead of when they were posted.

## Technical Cause
1. PDF documents used as news feed items have only `dateUploaded` but are missing both `datePosted` and `datePublished` fields.
2. The app loads PDF documents as fallback when no NewsFeedItem records exist.
3. When creating the NewsFeedPost objects, the system checks for datePosted and datePublished, and if not found, falls back to current date.

## Applied Fixes

1. We've created the "News Date Tool" in the admin panel that:
   - Analyzes the database for items missing date fields
   - Adds the missing date fields to both NewsFeedItem and PDFDocumentItem records
   - Repairs existing records by copying dates from dateUploaded to datePosted/datePublished

2. We've updated the NewsFeedPopupView.swift to use DateFixHelper when creating new posts.

## How to Fix Existing Posts

1. Click on the "News Date Tool" in the left sidebar
2. Make sure "Also fix PDF documents" is enabled
3. Click "Fix All Posts" 
4. Wait for the process to complete
5. Check the log for details of what was fixed

## Debugging Help

If posts still show the current date:

1. Check console logs for lines like:
   ```
   ⚠️ Post 'Title': Missing date fields! Using current date as fallback.
   ⚠️ Available fields: recordNameMirror, title, pdfFile, dateUploaded
   ```

2. Run the "Fix All Posts" tool again with detailed logging

3. If problems persist, check if NewsFeedPost.init(record:) is populating datePosted correctly:
   ```swift
   // The init method should be checking both date fields:
   if let datePosted = record["datePosted"] as? Date {
       self.datePosted = datePosted
   } else if let datePublished = record["datePublished"] as? Date {
       self.datePosted = datePublished
   } else {
       // Only use current date if no date field exists
       self.datePosted = Date()
   }
   ```

4. For PDFs, ensure fetchNewsFeedWithFallback is adding both date fields.

## Permanent Fixes

1. In NewsFeedManagementView, update createNewPost to use:
   ```swift
   NewsFeedDateFixer.fixNewPostDates(newsPost: newsPost)
   ```

2. In publishNow, replace datePosted assignment with:
   ```swift
   NewsFeedDateFixer.fixPublishDates(record: record)
   ```

3. When converting PDF documents to news feed items, ensure both date fields are copied from dateUploaded.

## Future Improvements

1. Consider consolidating all PDF documents into proper NewsFeedItem records
2. Add validation to ensure necessary date fields are always present
3. Improve error handling to capture and report missing fields 