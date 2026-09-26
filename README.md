# POV Hub - Remember & Record v1
**Free local test, no paywall**

This is the scaffold for the modular POV Hub we designed: one Live Activity that lives in Dynamic Island until YOU end it, with Memory Tag + Safety Cam ON by default.

### What this v1 does
- Mock streaming (replays a video as if it's glasses) so you can test without DAT approval
- Real DAT path ready - just flip `useMock = false` once you have glasses + SDK
- FrameRouter that fans out frames to active modules only (saves battery)
- MemoryTagModule - on-device Vision object detection, saves to SwiftData
- SafetyCamModule - rolling 30-min buffer, writes MP4 locally
- POVLiveActivityManager - manages Dynamic Island with thumbnail + status
- iOS app with toggles UI (matches the mockup)

### Free testing on iPhone 15 (no $99)

1. Open `POVHub.xcodeproj` in Xcode 15+
2. Bundle ID: change to `com.yourname.povhub.test123` unique
3. Signing & Capabilities > Team > Your Personal Team (free Apple ID)
4. iPhone Settings > Privacy & Security > Developer Mode > ON
5. Plug iPhone via USB > Select it > Run
6. App expires in 7 days, just Run again to re-sign

### To enable real glasses later
1. Apply for Meta Wearables DAT access at developers.meta.com (free)
2. Add SPM: `https://github.com/facebook/meta-wearables-dat-ios`
3. In `StreamingCoreFacade.swift` set `useMock = false`
4. Enable Developer Mode on glasses: Meta View > Devices > Settings > General > About > tap Version 5 times > Developer Mode ON

### Project structure
- `Shared/POVAttributes.swift` - ActivityKit model, must be <4KB
- `Core/FrameRouter.swift` - central dispatcher
- `Core/StreamingCoreFacade.swift` - DAT + Mock + iPhone camera fallback
- `Core/LiveActivityManager.swift` - owns Activity
- `Modules/MemoryTagModule.swift` - Vision + SwiftData
- `Modules/SafetyCamModule.swift` - AVFoundation rolling buffer
- `Widget/POVLiveActivityWidget.swift` - Dynamic Island UI
- `App/ContentView.swift` - Toggle UI

### Live Activity limits
- Active 8 hours max, then system auto-ends it. We show "Restart?" prompt.
- We use LOCAL updates (free account), not PUSH (needs paid account).

### Next steps
- Day 2: Add Live Share with local LiveKit server: `docker run --rm -p 7880:7880 -p 7881:7881 -p 7882:7882/udp livekit/livekit-server --dev`
- Day 3: Add Translate, Inspector toggles as separate modules.
