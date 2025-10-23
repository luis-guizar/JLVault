# App Icon & Name Setup Guide

## ✅ App Name Changed
The app will now display as **"Simple Vault"** on your phone (instead of "simple_vault").

## 🎨 Setting Up the App Icon

### Option 1: Quick Setup (Using Online Tool)
1. Go to https://icon.kitchen or https://www.appicon.co/
2. Choose a lock icon or upload your own design
3. Set the background color to blue (#1976D2)
4. Download the icon pack
5. Save one of the icons as `icon.png` in the `assets` folder
6. Make sure it's at least 1024x1024 pixels

### Option 2: Simple Icon (Using Material Icons)
1. Go to https://fonts.google.com/icons?icon.set=Material+Icons
2. Search for "lock" and download the icon
3. Use any image editor to:
   - Create a 1024x1024 image
   - Add a blue background (#1976D2)
   - Place the white lock icon in the center
4. Save as `assets/icon.png`

### Option 3: Quick PNG Icon
Create or download a 1024x1024 PNG image with a lock symbol and save it as:
`c:\Users\lopez\simple_vault\assets\icon.png`

## 🚀 Generate the Icons

Once you have `assets/icon.png`, run these commands:

```powershell
cd c:\Users\lopez\simple_vault
flutter pub run flutter_launcher_icons
```

This will automatically generate all the required icon sizes for Android and iOS.

## 📱 Rebuild and Install

After generating icons:

```powershell
flutter clean
flutter pub get
flutter run
```

The app will now show with your custom icon and the name "Simple Vault"!

## 🎨 Icon Specifications
- **Size**: 1024x1024 pixels minimum
- **Format**: PNG with transparency
- **Recommended**: Simple, recognizable design that works at small sizes
- **Suggested colors**: Blue (#1976D2) background with white/light icon
