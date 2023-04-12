# KeySay

<img src="KeySay/1024.png" width="256" height="256" alt="KeySay icon">

1. This app announces change of keyboard layout with Text To Speech and System Beep
2. Also it reminds current keyboard layout after 10 seconds without kepresses
2. And also it play different keyclick sound for different keyboard layouts

Currently it is setup for Rus and ABC keyboard layouts, but it can be easily customized in code.

## Use

Build in XCode

Archive and Export locally (so it is signed locally)

Add KeySay.app to the Universal Access (Apple menu > System Settings, click Privacy & Security, then click Accessibility on the right. (You may need to scroll down.) Click the Add button at the bottom of the list of apps and choose KeySay. You can turn permission on or off for any app in the list.

Then doublick click the app.

To quit app - use termial command

`killall KeySay`

## Troubleshooting

- (to do) 
- sometimes it may not get access to keyboard events after enabling, so I had to sleep and wake for it to start clicks
- you may need to adjust keyboard layout IDs and voice in code to ones used on your system 

## License

You can do whatever you want with this code except use it for profit (including building apps with similar functionality),
please also make attribution and link to the original repository.

Let's keep it free as in beer.

Also there is no guarantee of any kind, use at your own risk.

##Keisai Eisen

Keisai Eisen (渓斎 英泉, 1790–1848) was a Japanese ukiyo-e artist who specialised in bijin-ga (pictures of beautiful women). His best works, including his ōkubi-e ("large head pictures"), are considered to be masterpieces of the "decadent" Bunsei Era (1818–1830).
[More info on Wikipedia](https://en.wikipedia.org/wiki/Keisai_Eisen)