# P2P Sync Testing Guide

This guide explains how to test the P2P sync functionality in Simple Vault.

## Prerequisites

1. **Two devices** (or emulators) on the same local network
2. **Flutter development environment** set up
3. **Simple Vault app** installed on both devices

## Testing Setup

### Option 1: Two Physical Devices
1. Connect both devices to the same WiFi network
2. Install the app on both devices using:
   ```bash
   flutter install
   ```

### Option 2: Physical Device + Emulator
1. Connect your physical device to the same network as your computer
2. Run the app on your physical device
3. Start an Android emulator and run the app there
4. Make sure the emulator can access the local network

### Option 3: Two Emulators (Advanced)
1. Start two Android emulators
2. Configure network bridging between emulators
3. Run the app on both emulators

## How to Test P2P Sync

### 1. Access P2P Sync Feature

1. **Open Simple Vault** on both devices
2. **Authenticate** with your master password/biometrics
3. **Navigate to P2P Sync**:
   - Tap the **sync icon** (⟲) in the top app bar, OR
   - Tap the **menu button** (⋮) and select "P2P Sync"

### 2. Device Pairing Process

#### On Device A (Host):
1. Go to the **"Pair"** tab
2. Select **"Generate QR"** tab
3. Tap **"Generate QR Code"**
4. A QR code will appear with device information
5. Keep this screen open

#### On Device B (Client):
1. Go to the **"Pair"** tab  
2. Select **"Scan QR"** tab
3. Point the camera at Device A's QR code
4. The app will automatically detect and process the QR code
5. Wait for pairing confirmation

#### Expected Results:
- ✅ Both devices show "Pairing completed!" message
- ✅ Devices appear in each other's "Devices" tab
- ✅ Device status shows as "Paired"

### 3. Device Management Testing

1. Go to the **"Devices"** tab
2. You should see the paired device listed
3. **Test device actions**:
   - Tap the **menu button** (⋮) next to a device
   - Try **"Sync Now"** - should show sync progress
   - Try **"Rename"** - should allow changing device name
   - Try **"Sync History"** - should show sync activity
   - Try **"Unpair"** - should remove the device

### 4. Selective Sync Testing

1. Go to the **"Settings"** tab
2. **Configure vault sync**:
   - Toggle vaults on/off for each device
   - Change sync frequency settings
   - Enable/disable background sync
   - Configure conflict resolution

#### Test Scenarios:
- **Enable sync** for specific vaults only
- **Disable sync** for sensitive vaults
- **Change sync frequency** to manual/automatic
- **Toggle background sync** on/off

### 5. Sync Functionality Testing

#### Basic Sync Test:
1. **Create a password entry** on Device A
2. **Trigger manual sync** from Device Management
3. **Check Device B** - the entry should appear
4. **Modify the entry** on Device B
5. **Sync again** - changes should appear on Device A

#### Conflict Resolution Test:
1. **Modify the same entry** on both devices (while offline)
2. **Trigger sync** - should detect conflicts
3. **Resolve conflicts** using the conflict resolution UI
4. **Verify resolution** - both devices should have consistent data

## Expected Behavior

### ✅ Working Features:
- **Device Discovery**: Devices find each other on local network
- **QR Code Pairing**: Secure device pairing with QR codes
- **Device Management**: View, rename, and manage paired devices
- **Sync Status**: Real-time sync progress and status
- **Selective Sync**: Choose which vaults to sync
- **Conflict Resolution**: Handle sync conflicts gracefully

### 🔧 Current Limitations:
- **Network Discovery**: Uses HTTP-based discovery (simplified from mDNS)
- **Encryption**: Basic AES-256 encryption (production would use stronger key exchange)
- **Conflict Resolution**: Basic strategies implemented
- **Background Sync**: UI controls present but background processing may be limited

## Troubleshooting

### Common Issues:

#### "No devices found"
- ✅ Ensure both devices are on the same WiFi network
- ✅ Check firewall settings aren't blocking connections
- ✅ Try restarting the discovery process

#### "Pairing failed"
- ✅ Ensure QR code is clearly visible and not expired
- ✅ Check camera permissions are granted
- ✅ Try generating a new QR code

#### "Sync failed"
- ✅ Verify devices are still connected to the network
- ✅ Check if the target device is online
- ✅ Try manual sync from device management

#### "Connection timeout"
- ✅ Devices may be on different network segments
- ✅ Check router settings for device isolation
- ✅ Try moving devices closer to the router

## Testing Checklist

### Basic Functionality:
- [ ] App launches and shows P2P Sync option
- [ ] Can access P2P Sync screen with three tabs
- [ ] QR code generation works
- [ ] QR code scanning works
- [ ] Device pairing completes successfully
- [ ] Paired devices appear in device list

### Device Management:
- [ ] Can view paired devices
- [ ] Can rename devices
- [ ] Can view sync history
- [ ] Can unpair devices
- [ ] Sync status updates correctly

### Selective Sync:
- [ ] Can enable/disable vaults for sync
- [ ] Can change sync frequency
- [ ] Can toggle background sync
- [ ] Settings persist between app restarts

### Advanced Features:
- [ ] Conflict resolution UI appears for conflicts
- [ ] Can resolve conflicts manually
- [ ] Offline sync queuing works
- [ ] Sync resumes after network reconnection

## Development Testing

For developers wanting to test the implementation:

```bash
# Run with debug logging
flutter run --debug

# Check logs for P2P sync activity
flutter logs | grep -i "sync\|pair\|device"

# Test on multiple devices
flutter install -d device1
flutter install -d device2
```

## Security Testing

### Verify Security Features:
- [ ] QR codes expire after timeout
- [ ] Pairing requires physical access to both devices
- [ ] Sync data is encrypted in transit
- [ ] Device keys are stored securely
- [ ] Unpaired devices cannot access sync data

## Performance Testing

### Test Performance:
- [ ] Large vault sync performance
- [ ] Multiple device sync coordination
- [ ] Network interruption handling
- [ ] Battery usage during background sync

---

## Next Steps

After basic testing, consider:

1. **Production Deployment**: Add proper mDNS discovery
2. **Enhanced Security**: Implement proper key exchange protocols
3. **Background Sync**: Add proper background processing
4. **Cloud Backup**: Optional encrypted cloud backup integration
5. **Advanced Conflict Resolution**: More sophisticated merge strategies

## Support

If you encounter issues during testing:

1. Check the Flutter console for error messages
2. Verify network connectivity between devices
3. Ensure both devices have the latest app version
4. Try restarting both devices and the app

The P2P sync feature provides a solid foundation for secure, local device synchronization while maintaining Simple Vault's privacy-first approach.