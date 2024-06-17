# WatchDrop - The world's first(?) file extractor for watchOS
### I am warning you now, this app is horrible. It's extremely glitchy and basically the bare minimum in terms of functionality for something like this. Myself and ChatGPT threw this together in a rush to do something after WWDC24.
**Why does this exist...?**

It has basically one practical use. Since watchOS IPSW files are hard to come by beyond once a year, I wanted a way to get select system files off of the watch. Sandboxed apps on iOS and its derivatives (iPadOS, visionOS, tvOS, and of course watchOS) are allowed to read files from the /System/Library directory, and I wanted a simple way to take advantage of that.

This pretty much is for researching different watchOS versions that you aren't able to easily acquire an IPSW file for, but can sideload an app onto, like beta software or just later x.y(.z) releases of watchOS.

**So how does it work?**

SwiftUI, the Watch Connectivity framework, patience, and suffering.

**Wow! This sounds great! I wanna use it!**

What's wrong with you?

Just build the Xcode project, you'll be fine. This was made with the Xcode 15 Beta and iOS 18 SDK, although you 100% could likely get this to work on older iOS versions, I simply don't care.
