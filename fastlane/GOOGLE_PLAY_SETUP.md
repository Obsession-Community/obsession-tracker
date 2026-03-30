# Google Play Service Account Setup

## Steps to Create Service Account

### 1. Go to Google Play Console
Visit: https://play.google.com/console

Select the account where **Obsession Tracker** is published.

### 2. Navigate to API Access
Settings (gear icon) → **API access**

### 3. Link Google Cloud Project (if first time)
- Click **"Link to a Google Cloud project"**
- Choose existing or create new
- Click **"Link project"**

### 4. Create Service Account
1. Click **"Create new service account"**
2. Follow link to Google Cloud Console
3. Click **"+ CREATE SERVICE ACCOUNT"**
4. Fill in:
   - **Name**: `obsession-tracker-fastlane`
   - **ID**: (auto-generated)
   - **Description**: `Fastlane deployment for Obsession Tracker`
5. Click **"Create and Continue"**
6. Skip role selection (set in Play Console)
7. Click **"Done"**

### 5. Create JSON Key
1. Find the service account in the list
2. Click three dots (⋮) → **"Manage keys"**
3. Click **"Add Key"** → **"Create new key"**
4. Select **"JSON"**
5. Click **"Create"**
6. **Save the downloaded JSON file**

### 6. Grant Permissions in Play Console
1. Return to Play Console → Settings → API access
2. Find your service account
3. Click **"Grant access"**
4. Set permissions:
   - **App access**: Select "Obsession Tracker"
   - **Account permissions**:
     - ✓ View app information and download bulk reports
     - ✓ Manage store presence
     - ✓ Manage production releases
     - ✓ Manage testing track releases
5. Click **"Apply"**
6. Click **"Invite user"**

## Installation

```bash
# Copy the downloaded JSON file to fastlane directory
cp ~/Downloads/obsession-tracker-*.json fastlane/google-play-key.json

# Update .env file
echo "GOOGLE_PLAY_JSON_KEY_PATH=./fastlane/google-play-key.json" >> fastlane/.env

# Test the connection
fastlane android metadata
```

## Usage

After setup, you can upload Android metadata and builds:

```bash
# Upload metadata and screenshots
fastlane android metadata

# Upload to internal testing
fastlane android beta

# Release to production
fastlane android release
```

## Troubleshooting

**"Access not configured"**
- Make sure you granted permissions in Play Console (Step 6)
- Wait 5-10 minutes for permissions to propagate

**"App not found"**
- Verify the app exists in Google Play Console
- Check that the service account has access to the correct app

**"Invalid JSON key"**
- Ensure the file is valid JSON
- Check that it's the service account key, not OAuth credentials
